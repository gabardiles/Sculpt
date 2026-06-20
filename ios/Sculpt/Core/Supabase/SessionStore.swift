import Foundation
import Supabase

/// Owns auth state for the whole app. Mirrors the web middleware: signed-out →
/// login, signed-in but no name → onboarding, otherwise → the app.
@MainActor
final class SessionStore: ObservableObject {
    enum Phase: Equatable {
        case loading
        case signedOut
        case onboarding(userId: String)
        case ready(Profile)
    }

    @Published var phase: Phase = .loading
    @Published var profile: Profile?

    private let client = Supa.shared.client
    private var watchTask: Task<Void, Never>?

    func start() {
        // Instant launch: if we have a cached profile, route straight into the
        // app — no spinner, no waiting on the network. refresh() below validates
        // the session in the background and flips to .signedOut if it's invalid.
        if let cached = DiskCache.load(Profile.self, key: "profile") {
            profile = cached
            phase = (cached.name?.isEmpty == false) ? .ready(cached) : .onboarding(userId: cached.id)
        }

        watchTask?.cancel()
        watchTask = Task { [weak self] in
            guard let self else { return }
            // React to sign-in / sign-out for the app's lifetime.
            for await change in client.auth.authStateChanges {
                if change.event == .signedOut {
                    self.phase = .signedOut
                    self.profile = nil
                } else if change.session != nil {
                    await self.refresh()
                }
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let session = try await client.auth.session
            await loadProfile(userId: session.user.id.uuidString)
        } catch {
            phase = .signedOut
        }
    }

    func loadProfile(userId: String) async {
        do {
            let rows: [Profile] = try await client
                .from("profiles").select().eq("id", value: userId).limit(1).execute().value
            let p = rows.first
            self.profile = p
            if let p { DiskCache.save(p, key: "profile") } // for the next instant launch
            // Web onboarding gate: a profile with no name hasn't onboarded.
            if let p, let name = p.name, !name.isEmpty {
                phase = .ready(p)
            } else {
                phase = .onboarding(userId: userId)
            }
        } catch {
            phase = .onboarding(userId: userId)
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
        DiskCache.clearAll()
        SharedStore.writeNextSession(nil)
        phase = .signedOut
        profile = nil
    }
}
