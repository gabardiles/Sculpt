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
    @Published var generating = false
    @Published var generateError: String?

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

    /// Generate a fresh report from the latest photos via the Edge Function.
    func generate() async {
        guard !generating else { return }
        generating = true; generateError = nil
        let res = await repo.generateFitnessReport()
        if res.ok {
            await load()
        } else {
            generateError = friendly(res.error)
        }
        generating = false
    }

    private func friendly(_ code: String?) -> String {
        switch code {
        case "needs_setup": return "Add your details first — tap the pencil."
        case "needs_photo": return "Add a progress photo first (Photos tab)."
        case "not_configured": return "Photo analysis isn't enabled on the server yet."
        case "analysis_failed": return "Couldn't read that — try a clearer, well-lit full-body photo."
        default: return "Something went wrong. Try again in a moment."
        }
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
