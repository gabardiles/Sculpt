import Foundation

/// Loads goals + the context needed to score them, and handles create / delete /
/// mark-achieved. Mirrors src/app/(app)/goals/page.tsx and GoalsClient.tsx.
@MainActor
final class GoalsViewModel: ObservableObject {
    @Published var loading = true
    @Published var rows: [GoalRowItem] = []
    @Published var library: [Exercise] = []

    /// A scored, display-ready goal — combines the raw row with GoalMath output.
    struct GoalRowItem: Identifiable {
        let id: String
        let type: GoalType
        let label: String
        let progress: Double
        let current: String
        let target: String
        let achieved: Bool
        let deadline: String?
    }

    var active: [GoalRowItem] { rows.filter { !$0.achieved } }
    var achieved: [GoalRowItem] { rows.filter { $0.achieved } }
    var canAdd: Bool { active.count < 3 }

    /// Exercises pickable for a PR goal — weight-based moves only.
    var prExercises: [Exercise] { library.filter { $0.unit == .kg } }

    private let repo = Repository.shared
    private var userId: String?

    func load() async {
        loading = true
        guard let uid = await repo.currentUserId() else { loading = false; return }
        userId = uid
        do {
            async let goalsA = repo.getGoals(uid)
            async let libraryA = repo.getExerciseLibrary(uid)
            async let bwA = repo.getBodyWeights(uid)
            async let reportA = repo.getLatestFitnessReport(uid)

            let goals = try await goalsA
            self.library = try await libraryA
            let bodyWeights = try await bwA
            let report = try await reportA

            // PR context: best weight ever logged per exercise referenced by a goal.
            let exerciseIds = Array(Set(goals.compactMap(\.exerciseId)))
            let history = (try? await repo.getSetHistory(uid, exerciseIds: exerciseIds)) ?? []
            var prByExercise: [String: Double] = [:]
            for s in history {
                guard let w = s.weightKg else { continue }
                if w > (prByExercise[s.exerciseId] ?? 0) { prByExercise[s.exerciseId] = w }
            }

            let ctx = GoalContext(
                latestBodyWeight: bodyWeights.last?.weightKg,
                prByExercise: prByExercise,
                // workout dates drive the consistency goal; goals page keeps it light.
                workoutDates: [],
                latestFitnessScore: (report?.assessable == true) ? report?.overallScore : nil
            )

            rows = goals.map { g in
                let p = GoalMath.compute(g, ctx)
                return GoalRowItem(
                    id: g.id, type: g.type, label: GoalMath.label(g),
                    progress: p.progress, current: p.current, target: p.target,
                    // Treat a hit goal as achieved for display, like the web auto-check.
                    achieved: g.achieved || p.hit, deadline: g.deadline
                )
            }
        } catch {
            // Degrade gracefully — keep whatever loaded.
        }
        loading = false
    }

    func create(type: GoalType, target: Double, exerciseId: String?, deadline: String?) async {
        guard let uid = userId else { return }
        try? await repo.createGoal(
            userId: uid, type: type, target: target, baseline: nil,
            exerciseId: exerciseId, deadline: deadline
        )
        await load()
    }

    func delete(_ id: String) async {
        try? await repo.deleteGoal(id)
        await load()
    }

    func markAchieved(_ id: String) async {
        try? await repo.markGoalAchieved(id)
        await load()
    }
}
