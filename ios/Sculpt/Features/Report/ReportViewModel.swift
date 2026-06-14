import Foundation

/// Loads the latest saved fitness report + the profile details that feed the
/// setup form. AI generation is deferred to a server function, so this view
/// model only reads an existing report and saves the report profile.
/// Mirrors src/app/(app)/report/page.tsx + ReportClient.tsx (display + setup).
@MainActor
final class ReportViewModel: ObservableObject {
    @Published var loading = true
    @Published var latest: FitnessReport?
    @Published var profile: Profile?
    @Published var latestWeight: Double?

    /// No goal aesthetic chosen yet → first-run setup prompt.
    var needsSetup: Bool { profile?.gender == nil }

    private let repo = Repository.shared
    private var userId: String?

    func load() async {
        loading = true
        guard let uid = await repo.currentUserId() else { loading = false; return }
        userId = uid
        do {
            async let reportA = repo.getLatestFitnessReport(uid)
            async let profileA = repo.getProfile(uid)
            async let bwA = repo.getBodyWeights(uid)
            self.latest = try await reportA
            self.profile = try await profileA
            self.latestWeight = try await bwA.last?.weightKg
        } catch {
            // Degrade gracefully.
        }
        loading = false
    }

    func saveProfile(gender: Gender, heightCm: Double?, goalNote: String?, weight: Double?) async {
        guard let uid = userId else { return }
        try? await repo.saveFitnessProfile(
            userId: uid, gender: gender, heightCm: heightCm,
            goalNote: goalNote, weight: weight
        )
        await load()
    }
}
