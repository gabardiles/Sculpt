import Foundation
import Supabase

// Encodable payloads for inserts/updates. The Postgrest encoder is configured
// with convertToSnakeCase, so camelCase fields map to snake_case columns.

private struct IdRow: Decodable { let id: String }

extension Repository {

    // MARK: - Onboarding

    struct OnboardingInput {
        var name: String
        var gender: Gender
        var age: Int?
        var heightCm: Double?
        var weightKg: Double?
    }

    /// Mirrors completeOnboarding() in actions.ts.
    func completeOnboarding(userId: String, input: OnboardingInput) async throws -> AppTheme {
        // Men get Spartan + Strong & Built; women/unspecified get Sculpt + Lean & Sculpted.
        let theme: AppTheme = input.gender == .male ? .spartan : .sculpt
        let template = input.gender == .male ? "Strong & Built" : "Lean & Sculpted"

        struct ProfileUpdate: Encodable {
            var name: String; var gender: String; var age: Int?
            var heightCm: Double?; var theme: String
        }
        try await client.from("profiles").update(ProfileUpdate(
            name: input.name, gender: input.gender.rawValue, age: input.age,
            heightCm: input.heightCm, theme: theme.rawValue
        )).eq("id", value: userId).execute()

        if let w = input.weightKg, w > 0, w <= 400 {
            _ = try? await logBodyWeight(userId: userId, weight: w, date: Fmt.todayISO())
        }

        // Clone the suggested template if she has no active program yet.
        let existing: [IdRow] = try await client.from("programs")
            .select("id").eq("user_id", value: userId).eq("active", value: true)
            .limit(1).execute().value
        if existing.isEmpty {
            _ = try? await cloneTemplateProgram(userId: userId, templateName: template)
        }
        return theme
    }

    @discardableResult
    func cloneTemplateProgram(userId: String, templateName: String) async throws -> Bool {
        let templates: [ProgramFetch] = try await client.from("programs")
            .select("*, program_weeks(*), program_days(*, program_exercises(*, exercise:exercises(*)))")
            .is("user_id", value: nil)
            .eq("name", value: templateName)
            .limit(1).execute().value
        guard let t = templates.first?.flatten() else { return false }

        struct ProgramInsert: Encodable {
            var userId: String; var name: String; var weeks: Int
            var daysPerWeek: Int; var active: Bool; var scheduleMode: String
        }
        let prog: IdRow = try await client.from("programs").insert(ProgramInsert(
            userId: userId, name: t.program.name, weeks: t.program.weeks,
            daysPerWeek: t.program.daysPerWeek, active: true,
            scheduleMode: t.program.scheduleMode.rawValue
        )).select("id").single().execute().value

        if !t.weekPlan.isEmpty {
            struct WeekInsert: Encodable {
                var programId: String; var weekIndex: Int; var intensity: String
                var label: String?; var note: String?
            }
            let weeks = t.weekPlan.map {
                WeekInsert(programId: prog.id, weekIndex: $0.weekIndex,
                           intensity: $0.intensity.rawValue, label: $0.label, note: $0.note)
            }
            try await client.from("program_weeks").insert(weeks).execute()
        }

        struct DayInsert: Encodable {
            var programId: String; var dayIndex: Int; var name: String
            var weekIndex: Int?; var weekday: Int?; var sessionType: String; var content: String?
        }
        struct PEInsert: Encodable {
            var programDayId: String; var exerciseId: String; var sort: Int
            var sets: Int; var scheme: String?
        }
        for d in t.days {
            let newDay: IdRow = try await client.from("program_days").insert(DayInsert(
                programId: prog.id, dayIndex: d.day.dayIndex, name: d.day.name,
                weekIndex: d.day.weekIndex, weekday: d.day.weekday,
                sessionType: d.day.sessionType.rawValue, content: d.day.content
            )).select("id").single().execute().value
            if !d.exercises.isEmpty {
                let pes = d.exercises.map {
                    PEInsert(programDayId: newDay.id, exerciseId: $0.exerciseId,
                             sort: $0.sort, sets: $0.sets, scheme: $0.scheme)
                }
                try await client.from("program_exercises").insert(pes).execute()
            }
        }
        return true
    }

    // MARK: - Workout completion (PB detection + feed)

    struct WorkoutEntry { var exerciseId: String; var weightKg: Double?; var reps: Int?; var sets: Int? }

    /// Mirrors completeWorkout() in actions.ts.
    func completeWorkout(userId: String, programDayId: String, phase: WeekIntensity,
                         cycle: Int, feel: Int, entries: [WorkoutEntry]) async throws {
        // PB detection must look at history BEFORE this session is written.
        let weighted = entries.filter { $0.weightKg != nil }
        var prBefore: [String: Double] = [:]
        if !weighted.isEmpty {
            struct PrevSet: Decodable { var exerciseId: String; var weightKg: Double? }
            let prev: [PrevSet] = try await client.from("set_logs")
                .select("exercise_id, weight_kg, workout_log:workout_logs!inner(user_id)")
                .eq("workout_log.user_id", value: userId)
                .in("exercise_id", values: weighted.map(\.exerciseId))
                .execute().value
            for row in prev {
                guard let w = row.weightKg else { continue }
                if w > (prBefore[row.exerciseId] ?? 0) { prBefore[row.exerciseId] = w }
            }
        }

        struct LogInsert: Encodable {
            var userId: String; var programDayId: String; var weekPhase: String
            var cycleNumber: Int; var feelRating: Int
        }
        let log: IdRow = try await client.from("workout_logs").insert(LogInsert(
            userId: userId, programDayId: programDayId, weekPhase: phase.rawValue,
            cycleNumber: cycle, feelRating: feel
        )).select("id").single().execute().value

        if !entries.isEmpty {
            struct SetInsert: Encodable {
                var workoutLogId: String; var exerciseId: String; var weightKg: Double?
                var reps: Int?; var sets: Int?
            }
            let sets = entries.map {
                SetInsert(workoutLogId: log.id, exerciseId: $0.exerciseId,
                          weightKg: $0.weightKg, reps: $0.reps, sets: $0.sets)
            }
            try await client.from("set_logs").insert(sets).execute()
        }

        // Share the win with friends — completion + any new PBs only.
        let dayRows: [DayNameRow] = try await client.from("program_days")
            .select("name").eq("id", value: programDayId).limit(1).execute().value
        let dayName = dayRows.first?.name ?? "a workout"

        struct FeedInsert: Encodable {
            var userId: String; var type: String; var body: String; var metadata: JSONValue
        }
        var feedRows: [FeedInsert] = [
            FeedInsert(userId: userId, type: "workout", body: "Completed \(dayName)",
                       metadata: .object([
                        "day_name": .string(dayName), "phase": .string(phase.rawValue),
                        "cycle": .number(Double(cycle)), "exercises": .number(Double(entries.count)),
                       ]))
        ]

        let pbEntries = weighted.filter { e in
            guard let before = prBefore[e.exerciseId], let w = e.weightKg else { return false }
            return w > before
        }
        if !pbEntries.isEmpty {
            struct ExRow: Decodable { var id: String; var name: String; var unit: String }
            let exNames: [ExRow] = try await client.from("exercises")
                .select("id, name, unit").in("id", values: pbEntries.map(\.exerciseId)).execute().value
            let byId = Dictionary(uniqueKeysWithValues: exNames.map { ($0.id, $0) })
            for e in pbEntries {
                guard let ex = byId[e.exerciseId], ex.unit == "kg", let w = e.weightKg else { continue }
                feedRows.append(FeedInsert(
                    userId: userId, type: "pb",
                    body: "New PB — \(ex.name) \(Fmt.kg(w)) kg",
                    metadata: .object([
                        "exercise_id": .string(e.exerciseId),
                        "exercise_name": .string(ex.name),
                        "weight_kg": .number(w),
                    ])))
            }
        }
        try await client.from("feed_posts").insert(feedRows).execute()
    }

    // MARK: - Program flow

    func closeWeek(userId: String, cycle: Int, phase: WeekIntensity) async throws {
        struct ClosureUpsert: Encodable { var userId: String; var cycleNumber: Int; var weekPhase: String }
        try await client.from("week_closures")
            .upsert(ClosureUpsert(userId: userId, cycleNumber: cycle, weekPhase: phase.rawValue),
                    onConflict: "user_id,cycle_number,week_phase")
            .execute()
    }

    func resetCycle(userId: String, programId: String, nextCycle: Int) async throws {
        struct FloorUpdate: Encodable { var cycleFloor: Int }
        try await client.from("programs").update(FloorUpdate(cycleFloor: nextCycle))
            .eq("id", value: programId).eq("user_id", value: userId).execute()
    }

    func swapExercise(programExerciseId: String, newExerciseId: String) async throws {
        struct Upd: Encodable { var exerciseId: String }
        try await client.from("program_exercises").update(Upd(exerciseId: newExerciseId))
            .eq("id", value: programExerciseId).execute()
    }

    func removeExercise(programExerciseId: String) async throws {
        try await client.from("program_exercises").delete().eq("id", value: programExerciseId).execute()
    }

    func addExercise(programDayId: String, exerciseId: String, sort: Int) async throws {
        struct Ins: Encodable { var programDayId: String; var exerciseId: String; var sort: Int; var sets: Int }
        try await client.from("program_exercises")
            .insert(Ins(programDayId: programDayId, exerciseId: exerciseId, sort: sort, sets: 3))
            .execute()
    }

    func createCustomExercise(userId: String, name: String, muscleGroup: String,
                              movementPattern: String, repProfile: String,
                              equipment: String?, instructionUrl: String?) async throws {
        struct Ins: Encodable {
            var name: String; var muscleGroup: String; var movementPattern: String
            var repProfile: String; var unit: String; var equipment: String?
            var instructionUrl: String?; var isGlobal: Bool; var createdBy: String
        }
        try await client.from("exercises").insert(Ins(
            name: name, muscleGroup: muscleGroup, movementPattern: movementPattern,
            repProfile: repProfile, unit: repProfile == "timed" ? "s" : "kg",
            equipment: equipment, instructionUrl: instructionUrl,
            isGlobal: false, createdBy: userId
        )).execute()
    }

    // MARK: - Weight, goals

    func logBodyWeight(userId: String, weight: Double, date: String) async throws {
        struct Up: Encodable { var userId: String; var date: String; var weightKg: Double }
        try await client.from("body_weight")
            .upsert(Up(userId: userId, date: date, weightKg: weight), onConflict: "user_id,date")
            .execute()
        // Mirror into Apple Health (best-effort, opt-in — no-ops if declined).
        let day = Fmt.parseISO(date) ?? Date()
        await HealthKitManager.shared.saveBodyMass(kg: weight, date: day)
    }

    func createGoal(userId: String, type: GoalType, target: Double, baseline: Double?,
                    exerciseId: String?, deadline: String?) async throws {
        struct Ins: Encodable {
            var userId: String; var type: String; var targetValue: Double
            var baselineValue: Double?; var exerciseId: String?; var deadline: String?
        }
        try await client.from("goals").insert(Ins(
            userId: userId, type: type.rawValue, targetValue: target,
            baselineValue: baseline,
            exerciseId: type == .exercisePR ? exerciseId : nil, deadline: deadline
        )).execute()
    }

    func deleteGoal(_ id: String) async throws {
        try await client.from("goals").delete().eq("id", value: id).execute()
    }

    func markGoalAchieved(_ id: String) async throws {
        struct Up: Encodable { var achieved: Bool; var achievedAt: String }
        try await client.from("goals")
            .update(Up(achieved: true, achievedAt: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: id).execute()
    }

    // MARK: - Photos

    func uploadProgressPhoto(userId: String, data: Data, cycle: Int, weekLabel: String) async throws {
        let path = "\(userId)/\(UUID().uuidString).jpg"
        let jpeg = ImageProcessing.downsampledJPEG(from: data)
        try await client.storage.from("progress-photos")
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
        struct Ins: Encodable { var userId: String; var cycleNumber: Int; var weekLabel: String; var storagePath: String }
        try await client.from("progress_photos")
            .insert(Ins(userId: userId, cycleNumber: cycle, weekLabel: weekLabel, storagePath: path))
            .execute()
    }

    func deleteProgressPhoto(id: String, storagePath: String) async throws {
        try await client.from("progress_photos").delete().eq("id", value: id).execute()
        try? await client.storage.from("progress-photos").remove(paths: [storagePath])
    }

    // MARK: - Admin

    /// Invite a member by email (admin only) via the `invite-user` Edge
    /// Function: creates the account + sends a sign-in email.
    func inviteUser(email: String) async -> (ok: Bool, emailSent: Bool, error: String?) {
        struct Body: Encodable { var email: String }
        struct Result: Decodable { var ok: Bool; var emailSent: Bool?; var error: String? }
        do {
            let result: Result = try await client.functions.invoke(
                "invite-user", options: FunctionInvokeOptions(body: Body(email: email))
            ) { data, _ in try JSONDecoder().decode(Result.self, from: data) }
            return (result.ok, result.emailSent ?? false, result.error)
        } catch {
            return (false, false, "network")
        }
    }

    // MARK: - Report

    /// Generate a fresh physique report by invoking the `fitness-report` Edge
    /// Function (Claude vision). Returns a coarse error code matching the web
    /// action: not_configured / needs_setup / needs_photo / analysis_failed.
    func generateFitnessReport() async -> (ok: Bool, error: String?) {
        struct Result: Decodable { var ok: Bool; var reportId: String?; var error: String? }
        do {
            let result: Result = try await client.functions.invoke(
                "fitness-report", options: FunctionInvokeOptions()
            ) { data, _ in try JSONDecoder().decode(Result.self, from: data) }
            return (result.ok, result.error)
        } catch {
            return (false, "network")
        }
    }

    func saveFitnessProfile(userId: String, gender: Gender, heightCm: Double?,
                            goalNote: String?, weight: Double?) async throws {
        struct Up: Encodable { var gender: String; var heightCm: Double?; var goalNote: String? }
        try await client.from("profiles")
            .update(Up(gender: gender.rawValue, heightCm: heightCm, goalNote: goalNote))
            .eq("id", value: userId).execute()
        if let w = weight, w > 0, w <= 400 {
            _ = try? await logBodyWeight(userId: userId, weight: w, date: Fmt.todayISO())
        }
    }

    // MARK: - Theme

    func setTheme(userId: String, theme: AppTheme) async throws {
        struct Up: Encodable { var theme: String }
        try await client.from("profiles").update(Up(theme: theme.rawValue)).eq("id", value: userId).execute()
    }

    /// Switch to the other template: archive the current program, clone fresh.
    func switchProgram(userId: String, templateName: String) async throws -> Bool {
        struct Up: Encodable { var active: Bool }
        try await client.from("programs").update(Up(active: false))
            .eq("user_id", value: userId).eq("active", value: true).execute()
        return try await cloneTemplateProgram(userId: userId, templateName: templateName)
    }

    // MARK: - Friends feed

    func addFriendByCode(_ code: String) async throws -> (ok: Bool, error: String?) {
        struct Result: Decodable { var ok: Bool; var error: String? }
        let r: Result = try await client.rpc("add_friend", params: ["code": code]).execute().value
        return (r.ok, r.error)
    }

    func removeFriend(userId: String, friendId: String) async throws {
        try await client.from("friends").delete()
            .or("and(user_id.eq.\(userId),friend_id.eq.\(friendId)),and(user_id.eq.\(friendId),friend_id.eq.\(userId))")
            .execute()
    }

    func createFeedMessage(userId: String, body: String) async throws {
        struct Ins: Encodable { var userId: String; var type: String; var body: String }
        try await client.from("feed_posts").insert(Ins(userId: userId, type: "message", body: body)).execute()
    }

    func createFeedPhoto(userId: String, data: Data, caption: String?) async throws {
        let path = "\(userId)/\(UUID().uuidString).jpg"
        let jpeg = ImageProcessing.downsampledJPEG(from: data)
        try await client.storage.from("feed-photos")
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg"))
        struct Ins: Encodable { var userId: String; var type: String; var body: String?; var storagePath: String }
        try await client.from("feed_posts")
            .insert(Ins(userId: userId, type: "photo", body: caption, storagePath: path)).execute()
    }

    func deleteFeedPost(id: String, storagePath: String?) async throws {
        try await client.from("feed_posts").delete().eq("id", value: id).execute()
        if let storagePath { try? await client.storage.from("feed-photos").remove(paths: [storagePath]) }
    }

    func toggleCheer(postId: String, userId: String, on: Bool) async throws {
        if on {
            struct Up: Encodable { var postId: String; var userId: String }
            try await client.from("feed_cheers")
                .upsert(Up(postId: postId, userId: userId), onConflict: "post_id,user_id").execute()
        } else {
            try await client.from("feed_cheers").delete()
                .eq("post_id", value: postId).eq("user_id", value: userId).execute()
        }
    }

    func addComment(postId: String, userId: String, body: String) async throws {
        struct Ins: Encodable { var postId: String; var userId: String; var body: String }
        try await client.from("feed_comments")
            .insert(Ins(postId: postId, userId: userId, body: String(body.prefix(280)))).execute()
    }

    func deleteComment(_ id: String) async throws {
        try await client.from("feed_comments").delete().eq("id", value: id).execute()
    }
}

private struct DayNameRow: Decodable { var name: String }
