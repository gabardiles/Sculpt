import Foundation

/// Drives the Green Days layer: syncs steps from Apple Health, derives the
/// member's streak/points picture, and builds the friends leaderboard.
@MainActor
final class ActivityViewModel: ObservableObject {
    @Published var loading = true
    @Published var days: [ActivityDay] = []
    @Published var summary = GreenSummary()
    @Published var todaySteps = 0
    @Published var workoutDoneToday = false
    @Published var stepGoal = GreenDays.defaultStepGoal
    @Published var leaderboard: [LeaderRow] = []

    struct LeaderRow: Identifiable {
        let id: String
        let name: String
        let isMe: Bool
        let streak: Int
        let points: Int
        let state: ActivityDay.State
    }

    private let repo = Repository.shared
    private let stepBackfillKey = "sculpt-green-steps-backfilled"
    private let workoutBackfillKey = "sculpt-green-workouts-backfilled"

    var todayState: ActivityDay.State {
        ActivityDay(userId: nil, date: Fmt.todayISO(), steps: todaySteps,
                    stepGoal: stepGoal, workoutDone: workoutDoneToday).state
    }
    var stepProgress: Double { stepGoal > 0 ? min(1, Double(todaySteps) / Double(stepGoal)) : 0 }
    var healthConnected: Bool { HealthKitManager.shared.enabled }
    var hasFriends: Bool { leaderboard.count > 1 }

    func load() async {
        guard let userId = await repo.currentUserId() else { loading = false; return }
        hydrate(userId: userId)
        if let p = try? await repo.getProfile(userId), let g = p.stepGoal { stepGoal = g }
        await backfillIfNeeded(userId: userId)
        await syncTodaySteps(userId: userId)
        await reload(userId: userId)
        loading = false
    }

    /// Light refresh used after completing a workout, etc.
    func refresh() async {
        guard let userId = await repo.currentUserId() else { return }
        await syncTodaySteps(userId: userId)
        await reload(userId: userId)
    }

    func setStepGoal(_ goal: Int) async {
        let clamped = max(1_000, min(40_000, goal))
        stepGoal = clamped
        guard let userId = await repo.currentUserId() else { return }
        try? await repo.setStepGoal(userId: userId, goal: clamped)
        await syncTodaySteps(userId: userId)   // re-stamp today's goal
        await reload(userId: userId)
    }

    // MARK: - Internals

    private func reload(userId: String) async {
        if let rows = try? await repo.getActivity(userId) {
            days = rows
            summary = GreenDays.summary(rows)
            let today = rows.first { $0.date == Fmt.todayISO() }
            workoutDoneToday = today?.workoutDone ?? false
            if let s = today?.steps, s > todaySteps { todaySteps = s }
            persist(userId: userId)
        }
        await loadLeaderboard(me: userId)
    }

    private func syncTodaySteps(userId: String) async {
        guard HealthKitManager.shared.enabled else { return }
        let steps = await HealthKitManager.shared.todaySteps()
        todaySteps = steps
        try? await repo.syncSteps(userId: userId, date: Fmt.todayISO(), steps: steps, stepGoal: stepGoal)
    }

    private func backfillIfNeeded(userId: String) async {
        let defaults = UserDefaults.standard
        // Training history → calendar, for everyone (independent of Health).
        if !defaults.bool(forKey: workoutBackfillKey) {
            try? await repo.backfillWorkoutDays(userId: userId)
            defaults.set(true, forKey: workoutBackfillKey)
        }
        // Step history → calendar, only once Health is connected.
        if HealthKitManager.shared.enabled, !defaults.bool(forKey: stepBackfillKey) {
            let history = await HealthKitManager.shared.dailySteps(lastDays: 34)
            try? await repo.bulkSyncSteps(userId: userId, steps: history, stepGoal: stepGoal)
            defaults.set(true, forKey: stepBackfillKey)
        }
    }

    private func loadLeaderboard(me: String) async {
        guard let rows = try? await repo.getFriendsActivity(sinceDays: 30) else { return }
        let byUser = Dictionary(grouping: rows, by: { $0.userId ?? "" })
        guard byUser.count > 1 else { leaderboard = []; return }   // solo → no board
        let profiles = (try? await repo.getProfilesByIds(Array(byUser.keys))) ?? []
        let names = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0.name ?? "Friend") })
        let today = Fmt.todayISO()
        leaderboard = byUser.map { uid, urows in
            let s = GreenDays.summary(urows, today: today)
            let state = urows.first { $0.date == today }?.state ?? .none
            return LeaderRow(id: uid, name: uid == me ? "You" : (names[uid] ?? "Friend"),
                             isMe: uid == me, streak: s.currentStreak, points: s.totalPoints, state: state)
        }
        .sorted { ($0.streak, $0.points) > ($1.streak, $1.points) }
    }

    // MARK: - Cache (instant paint)

    private func hydrate(userId: String) {
        guard days.isEmpty, let cached = DiskCache.load([ActivityDay].self, key: "activity:\(userId)") else { return }
        days = cached
        summary = GreenDays.summary(cached)
        if let today = cached.first(where: { $0.date == Fmt.todayISO() }) {
            workoutDoneToday = today.workoutDone
            todaySteps = today.steps
            stepGoal = today.stepGoal
        }
        loading = false
    }

    private func persist(userId: String) {
        DiskCache.save(days, key: "activity:\(userId)")
    }
}
