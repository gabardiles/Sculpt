import Foundation

/// Loads the active program + the exercise library and exposes the editor
/// actions (swap / remove / add / create / switch). Every mutation reloads so
/// the UI reflects the new server state. Mirrors src/components/program/ProgramClient.tsx.
@MainActor
final class ProgramViewModel: ObservableObject {
    @Published var loading = true
    @Published var program: ProgramWithDays?
    @Published var library: [Exercise] = []
    @Published var busy = false

    private let repo = Repository.shared
    private var userId: String?

    /// Hardcoded — matches the web templates list.
    let templates = ["Lean & Sculpted", "Strong & Built", "Hybrid Athlete"]

    /// Templates other than the one currently active — the "switch" options.
    var otherTemplates: [String] {
        guard let name = program?.program.name else { return [] }
        return templates.filter { $0 != name }
    }

    var phase: Phase { program?.program.scheduleMode == .fixed ? .hard : .light }

    func load() async {
        loading = true
        guard let uid = await repo.currentUserId() else { loading = false; return }
        userId = uid
        do {
            async let prog = repo.getActiveProgram(uid)
            async let lib = repo.getExerciseLibrary(uid)
            self.program = try await prog
            self.library = try await lib
        } catch {
            // Degrade gracefully — keep whatever loaded.
        }
        loading = false
    }

    // MARK: - Swap

    /// The guardrail: only same movement pattern + same primary muscle group.
    /// Same training role (rep profile) comes first — a heavy compound and a
    /// pump finisher are not real substitutes even when the muscle matches.
    func swapOptions(for exercise: Exercise) -> (sameTier: [Exercise], otherTier: [Exercise]) {
        let compatible = library.filter {
            $0.id != exercise.id &&
            $0.movementPattern == exercise.movementPattern &&
            $0.muscleGroup == exercise.muscleGroup
        }
        return (
            sameTier: compatible.filter { $0.repProfile == exercise.repProfile },
            otherTier: compatible.filter { $0.repProfile != exercise.repProfile }
        )
    }

    /// Library entries not already in the day, filtered by the search query,
    /// capped at 30 — same as the web `addOptions`.
    func addOptions(for day: DayWithExercises, search: String) -> [Exercise] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let inDay = Set(day.exercises.compactMap { $0.exercise?.id })
        return library
            .filter { !inDay.contains($0.id) }
            .filter {
                q.isEmpty ||
                $0.name.lowercased().contains(q) ||
                $0.muscleGroup.contains(q) ||
                $0.movementPattern.rawValue.contains(q)
            }
            .prefix(30)
            .map { $0 }
    }

    // MARK: - Actions (each reloads after mutating)

    func swap(programExerciseId: String, to newId: String) async {
        guard !busy else { return }
        busy = true
        try? await repo.swapExercise(programExerciseId: programExerciseId, newExerciseId: newId)
        await load()
        busy = false
    }

    func remove(programExerciseId: String) async {
        guard !busy else { return }
        busy = true
        try? await repo.removeExercise(programExerciseId: programExerciseId)
        await load()
        busy = false
    }

    func add(to day: DayWithExercises, exerciseId: String) async {
        guard !busy else { return }
        busy = true
        let nextSort = (day.exercises.map { $0.sort }.max() ?? 0) + 1
        try? await repo.addExercise(programDayId: day.day.id, exerciseId: exerciseId, sort: nextSort)
        await load()
        busy = false
    }

    /// Returns nil on success, or an error string for the form to show.
    func createCustom(name: String, muscleGroup: String, movementPattern: String,
                      repProfile: String, equipment: String?, youTube: String?) async -> String? {
        guard let uid = userId else { return "Not signed in." }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return "Name your exercise." }
        guard !muscleGroup.isEmpty, !movementPattern.isEmpty, !repProfile.isEmpty else {
            return "Pick a muscle, movement and training role."
        }
        busy = true
        defer { busy = false }
        do {
            try await repo.createCustomExercise(
                userId: uid, name: trimmedName, muscleGroup: muscleGroup,
                movementPattern: movementPattern, repProfile: repProfile,
                equipment: equipment?.nilIfBlank, instructionUrl: youTube?.nilIfBlank)
            await load()
            return nil
        } catch {
            return "Couldn't save that — try again."
        }
    }

    func switchTo(template: String) async {
        guard let uid = userId, !busy else { return }
        busy = true
        _ = try? await repo.switchProgram(userId: uid, templateName: template)
        await load()
        busy = false
    }
}

private extension String {
    /// Trimmed, or nil when empty — keeps optional columns clean.
    var nilIfBlank: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
