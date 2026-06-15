import Foundation
import Supabase

// Green Days data layer — the `activity_days` table plus the friends leaderboard.
// Writes are partial upserts: stepping never clobbers a workout flag and vice
// versa (PostgREST only updates the columns present in the payload).

extension Repository {

    private static func sinceISO(_ days: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: d)
    }

    // MARK: - Reads

    /// The member's own activity rows over the trailing window.
    func getActivity(_ userId: String, sinceDays: Int = 120) async throws -> [ActivityDay] {
        try await client.from("activity_days")
            .select("user_id, date, steps, step_goal, workout_done")
            .eq("user_id", value: userId)
            .gte("date", value: Self.sinceISO(sinceDays))
            .order("date", ascending: true)
            .execute().value
    }

    /// Own + friends' rows (RLS scopes it) for the leaderboard.
    func getFriendsActivity(sinceDays: Int = 30) async throws -> [ActivityDay] {
        try await client.from("activity_days")
            .select("user_id, date, steps, step_goal, workout_done")
            .gte("date", value: Self.sinceISO(sinceDays))
            .execute().value
    }

    // MARK: - Writes

    private struct StepUpsert: Encodable {
        var userId: String; var date: String; var steps: Int; var stepGoal: Int
    }
    private struct WorkoutUpsert: Encodable {
        var userId: String; var date: String; var workoutDone: Bool
    }

    /// Record a day's step total (and the goal that applied).
    func syncSteps(userId: String, date: String, steps: Int, stepGoal: Int) async throws {
        try await client.from("activity_days")
            .upsert(StepUpsert(userId: userId, date: date, steps: steps, stepGoal: stepGoal),
                    onConflict: "user_id,date")
            .execute()
    }

    /// Backfill many days of steps at once (used the first time Health connects).
    func bulkSyncSteps(userId: String, steps: [String: Int], stepGoal: Int) async throws {
        guard !steps.isEmpty else { return }
        let rows = steps.map { StepUpsert(userId: userId, date: $0.key, steps: $0.value, stepGoal: stepGoal) }
        try await client.from("activity_days").upsert(rows, onConflict: "user_id,date").execute()
    }

    /// Flag today (or any day) as a training day for the streak layer.
    func markWorkoutDone(userId: String, date: String = Fmt.todayISO()) async throws {
        try await client.from("activity_days")
            .upsert(WorkoutUpsert(userId: userId, date: date, workoutDone: true),
                    onConflict: "user_id,date")
            .execute()
    }

    /// One-time backfill: mark every past training day so the calendar isn't
    /// empty for members who logged workouts before Green Days shipped.
    func backfillWorkoutDays(userId: String, sinceDays: Int = 120) async throws {
        struct LogDate: Decodable { var completedAt: String }
        let logs: [LogDate] = try await client.from("workout_logs")
            .select("completed_at")
            .eq("user_id", value: userId)
            .gte("completed_at", value: Self.sinceISO(sinceDays))
            .execute().value
        let dates = Set(logs.map { String($0.completedAt.prefix(10)) })
        guard !dates.isEmpty else { return }
        let rows = dates.map { WorkoutUpsert(userId: userId, date: $0, workoutDone: true) }
        try await client.from("activity_days").upsert(rows, onConflict: "user_id,date").execute()
    }

    // MARK: - Step goal (lives on the profile, read by both clients)

    func setStepGoal(userId: String, goal: Int) async throws {
        struct Up: Encodable { var stepGoal: Int }
        try await client.from("profiles").update(Up(stepGoal: goal)).eq("id", value: userId).execute()
    }
}
