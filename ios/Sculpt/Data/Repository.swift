import Foundation
import Supabase

/// The app's data layer. Reads mirror src/lib/data.ts; writes mirror
/// src/lib/actions.ts. Everything goes through Supabase with RLS — the same
/// guarantees the web app relies on. Each member touches only her own rows.
@MainActor
final class Repository {
    static let shared = Repository()
    let client = Supa.shared.client

    func currentUserId() async -> String? {
        try? await client.auth.session.user.id.uuidString
    }

    // MARK: - Reads

    func getProfile(_ userId: String) async throws -> Profile? {
        let rows: [Profile] = try await client.from("profiles")
            .select().eq("id", value: userId).limit(1).execute().value
        return rows.first
    }

    func getActiveProgram(_ userId: String) async throws -> ProgramWithDays? {
        // One round-trip: program + weeks + days + exercises nested.
        let rows: [ProgramFetch] = try await client.from("programs")
            .select("*, program_weeks(*), program_days(*, program_exercises(*, exercise:exercises(*)))")
            .eq("user_id", value: userId)
            .eq("active", value: true)
            .order("created_at", ascending: false)
            .limit(1)
            .execute().value
        return rows.first?.flatten()
    }

    func getCycleLogs(_ userId: String, dayIds: [String]) async throws -> [CycleLogRow] {
        guard !dayIds.isEmpty else { return [] }
        return try await client.from("workout_logs")
            .select("program_day_id, week_phase, cycle_number, completed_at, feel_rating")
            .eq("user_id", value: userId)
            .in("program_day_id", values: dayIds)
            .order("completed_at")
            .execute().value
    }

    func getWeekClosures(_ userId: String) async throws -> [WeekClosure] {
        try await client.from("week_closures")
            .select("cycle_number, week_phase")
            .eq("user_id", value: userId)
            .execute().value
    }

    func getGoals(_ userId: String) async throws -> [Goal] {
        try await client.from("goals")
            .select("*, exercise:exercises(*)")
            .eq("user_id", value: userId)
            .order("created_at")
            .execute().value
    }

    func getQuoteOfTheDay() async throws -> Quote? {
        let quotes: [Quote] = try await client.from("quotes").select().execute().value
        guard !quotes.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let sorted = quotes.sorted { $0.id < $1.id }
        return sorted[day % sorted.count]
    }

    func getSetHistory(_ userId: String, exerciseIds: [String]) async throws -> [SetHistoryRow] {
        guard !exerciseIds.isEmpty else { return [] }
        return try await client.from("set_logs")
            .select("exercise_id, weight_kg, reps, sets, workout_log:workout_logs!inner(week_phase, cycle_number, completed_at, user_id)")
            .eq("workout_log.user_id", value: userId)
            .in("exercise_id", values: exerciseIds)
            .execute().value
    }

    func getBodyWeights(_ userId: String) async throws -> [BodyWeight] {
        try await client.from("body_weight")
            .select().eq("user_id", value: userId)
            .order("date", ascending: true)
            .execute().value
    }

    func getProgressPhotos(_ userId: String) async throws -> [ProgressPhoto] {
        try await client.from("progress_photos")
            .select().eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute().value
    }

    func getExerciseLibrary(_ userId: String) async throws -> [Exercise] {
        // Global library + the member's own custom moves (RLS handles the rest).
        try await client.from("exercises")
            .select().or("is_global.eq.true,created_by.eq.\(userId)")
            .order("name")
            .execute().value
    }

    func getLatestFitnessReport(_ userId: String) async throws -> FitnessReport? {
        let rows: [FitnessReport] = try await client.from("fitness_reports")
            .select().eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .limit(1).execute().value
        return rows.first
    }

    // MARK: - Friends feed

    func getFeed() async throws -> [FeedPost] {
        // RLS returns the member's posts + her friends' wins only.
        try await client.from("feed_posts")
            .select().order("created_at", ascending: false)
            .limit(60).execute().value
    }

    func getProfilesByIds(_ ids: [String]) async throws -> [Profile] {
        guard !ids.isEmpty else { return [] }
        return try await client.from("profiles")
            .select("id, name, friend_code, theme")
            .in("id", values: ids).execute().value
    }

    func getCheers(postIds: [String]) async throws -> [Cheer] {
        guard !postIds.isEmpty else { return [] }
        return try await client.from("feed_cheers")
            .select("post_id, user_id")
            .in("post_id", values: postIds).execute().value
    }

    func getComments(postIds: [String]) async throws -> [FeedComment] {
        guard !postIds.isEmpty else { return [] }
        return try await client.from("feed_comments")
            .select("id, post_id, user_id, body, created_at")
            .in("post_id", values: postIds)
            .order("created_at").execute().value
    }

    func getFriends(_ userId: String) async throws -> [Profile] {
        // Both directions of the mutual friendship.
        let rows: [FriendRow] = try await client.from("friends")
            .select("user_id, friend_id")
            .or("user_id.eq.\(userId),friend_id.eq.\(userId)")
            .execute().value
        let ids = Set(rows.flatMap { [$0.userId, $0.friendId] }).subtracting([userId])
        return try await getProfilesByIds(Array(ids))
    }

    // MARK: - Storage

    func signedURL(bucket: String, path: String, expiresIn: Int = 3600) async -> URL? {
        try? await client.storage.from(bucket).createSignedURL(path: path, expiresIn: expiresIn)
    }

    func downloadImage(bucket: String, path: String) async -> Data? {
        try? await client.storage.from(bucket).download(path: path)
    }
}

// Lightweight rows used only by the feed.
struct Cheer: Codable, Sendable { var postId: String; var userId: String }
struct FeedComment: Codable, Identifiable, Sendable {
    var id: String; var postId: String; var userId: String; var body: String; var createdAt: String
}
private struct FriendRow: Codable { var userId: String; var friendId: String }
