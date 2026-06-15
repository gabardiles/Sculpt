import Foundation
import SwiftUI

/// Loads and shapes the friends feed — the Swift mirror of
/// src/app/(app)/friends/page.tsx + the client state in FriendsClient.tsx.
///
/// One load joins feed posts → author names → cheers → comments into a flat
/// list of `FeedItem`s the view renders directly. Cheers and comments are
/// mutated optimistically so taps feel instant, matching the web client.
@MainActor
final class FriendsViewModel: ObservableObject {

    /// One row of the feed, with everything the card needs pre-joined.
    struct FeedItem: Identifiable {
        let id: String
        let userId: String
        let authorName: String
        let mine: Bool
        let type: FeedPostType
        let body: String?
        let storagePath: String?
        let metadata: JSONValue?
        let createdAt: String
        var cheeredByMe: Bool
        var cheerNames: [String]
        var comments: [CommentItem]

        var phase: String? { metadata?["phase"]?.stringValue }
        var dayName: String? { metadata?["day_name"]?.stringValue }

        /// "You & Mia" / "Mia, Ada +3" — matches the web cheer label.
        var cheerLabel: String {
            if cheerNames.isEmpty { return "Cheer" }
            if cheerNames.count <= 2 { return cheerNames.joined(separator: " & ") }
            return "\(cheerNames.prefix(2).joined(separator: ", ")) +\(cheerNames.count - 2)"
        }
    }

    struct CommentItem: Identifiable {
        let id: String
        let authorName: String
        let body: String
        let mine: Bool
        /// Optimistic comments carry a temporary id and can't be deleted yet.
        var pending: Bool = false
    }

    struct FriendItem: Identifiable {
        let id: String
        let name: String
    }

    @Published var items: [FeedItem] = []
    @Published var friends: [FriendItem] = []
    @Published var myCode: String = ""
    @Published var loading = false
    @Published var loaded = false

    /// A short-lived realtime bubble (cheer / message / comment on your posts).
    @Published var toast: String?

    private(set) var userId: String?
    /// Signed URLs for photo posts, keyed by storage path.
    @Published var photoURLs: [String: URL] = [:]

    private let repo = Repository.shared

    // MARK: - Load

    func load() async {
        loading = true
        defer { loading = false; loaded = true }

        guard let uid = await repo.currentUserId() else { return }
        userId = uid

        do {
            // Posts + friends in parallel.
            async let postsTask = repo.getFeed()
            async let friendsTask = repo.getFriends(uid)
            let posts = try await postsTask
            let friendProfiles = try await friendsTask

            // Names: me + everyone who could appear (post authors, friends,
            // cheerers, commenters). RLS lets friends read each other.
            let postIds = posts.map(\.id)
            async let cheersTask = repo.getCheers(postIds: postIds)
            async let commentsTask = repo.getComments(postIds: postIds)
            let cheers = try await cheersTask
            let comments = try await commentsTask

            var ids = Set<String>([uid])
            posts.forEach { ids.insert($0.userId) }
            friendProfiles.forEach { ids.insert($0.id) }
            cheers.forEach { ids.insert($0.userId) }
            comments.forEach { ids.insert($0.userId) }

            let profiles = try await repo.getProfilesByIds(Array(ids))
            var nameById: [String: String] = [:]
            for p in profiles { nameById[p.id] = p.name ?? "Someone" }
            func display(_ id: String) -> String {
                id == uid ? "You" : (nameById[id] ?? "Someone")
            }

            // My friend code — prefer the profile lookup, fall back to session.
            myCode = profiles.first { $0.id == uid }?.friendCode ?? myCode

            friends = friendProfiles
                .map { FriendItem(id: $0.id, name: $0.name ?? "Someone") }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            // Group cheers + comments by post.
            var cheerNamesByPost: [String: [String]] = [:]
            var cheeredByMe: Set<String> = []
            for c in cheers {
                cheerNamesByPost[c.postId, default: []].append(display(c.userId))
                if c.userId == uid { cheeredByMe.insert(c.postId) }
            }
            var commentsByPost: [String: [CommentItem]] = [:]
            for c in comments {
                commentsByPost[c.postId, default: []].append(
                    CommentItem(id: c.id, authorName: display(c.userId),
                                body: c.body, mine: c.userId == uid)
                )
            }

            items = posts.map { p in
                FeedItem(
                    id: p.id, userId: p.userId, authorName: display(p.userId),
                    mine: p.userId == uid, type: p.type, body: p.body,
                    storagePath: p.storagePath, metadata: p.metadata,
                    createdAt: p.createdAt,
                    cheeredByMe: cheeredByMe.contains(p.id),
                    cheerNames: cheerNamesByPost[p.id] ?? [],
                    comments: commentsByPost[p.id] ?? []
                )
            }

            await loadPhotoURLs(for: posts)
        } catch {
            // Best-effort: a failed load leaves whatever we had (often empty).
        }
    }

    /// Resolve signed URLs for photo posts so AsyncImage can render them.
    private func loadPhotoURLs(for posts: [FeedPost]) async {
        let paths = posts.compactMap { $0.type == .photo ? $0.storagePath : nil }
        for path in paths where photoURLs[path] == nil {
            if let url = await repo.signedURL(bucket: "feed-photos", path: path) {
                photoURLs[path] = url
            }
        }
    }

    // MARK: - Composer

    func postMessage(_ body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let uid = userId else { return }
        try? await repo.createFeedMessage(userId: uid, body: String(trimmed.prefix(200)))
        await load()
    }

    func postPhoto(_ data: Data, caption: String?) async {
        guard let uid = userId else { return }
        let cap = caption?.trimmingCharacters(in: .whitespacesAndNewlines)
        try? await repo.createFeedPhoto(userId: uid, data: data,
                                        caption: (cap?.isEmpty == false) ? cap : nil)
        await load()
    }

    func deletePost(_ item: FeedItem) async {
        items.removeAll { $0.id == item.id }
        try? await repo.deleteFeedPost(id: item.id, storagePath: item.storagePath)
    }

    // MARK: - Friends

    /// Returns an error string to show, or nil on success.
    func addFriend(code: String) async -> String? {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return nil }
        do {
            let res = try await repo.addFriendByCode(trimmed)
            if res.ok { await load(); return nil }
            return res.error ?? "Couldn't add that code."
        } catch {
            return "Couldn't add that code."
        }
    }

    func removeFriend(_ friend: FriendItem) async {
        guard let uid = userId else { return }
        friends.removeAll { $0.id == friend.id }
        try? await repo.removeFriend(userId: uid, friendId: friend.id)
        await load()
    }

    // MARK: - Cheers (optimistic)

    func toggleCheer(_ item: FeedItem) async {
        guard let uid = userId, let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let next = !items[idx].cheeredByMe
        items[idx].cheeredByMe = next
        items[idx].cheerNames.removeAll { $0 == "You" }
        if next { items[idx].cheerNames.append("You") }
        try? await repo.toggleCheer(postId: item.id, userId: uid, on: next)
    }

    // MARK: - Comments (optimistic)

    func addComment(to item: FeedItem, body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let uid = userId,
              let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let tmpId = "tmp-\(UUID().uuidString)"
        items[idx].comments.append(
            CommentItem(id: tmpId, authorName: "You", body: trimmed, mine: true, pending: true)
        )
        do {
            try await repo.addComment(postId: item.id, userId: uid, body: trimmed)
            // Reconcile the optimistic comment with the server's real row.
            await load()
        } catch {
            if let i = items.firstIndex(where: { $0.id == item.id }) {
                items[i].comments.removeAll { $0.id == tmpId }
            }
        }
    }

    func deleteComment(_ comment: CommentItem, from item: FeedItem) async {
        guard !comment.pending,
              let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].comments.removeAll { $0.id == comment.id }
        try? await repo.deleteComment(comment.id)
    }

    // MARK: - Realtime (best-effort)

    private var realtimeTask: Task<Void, Never>?

    /// Subscribe to Supabase Realtime so a friend's cheer/message/comment on
    /// *your* posts pops a small toast — the native echo of CheerListener.tsx.
    ///
    /// TODO: The realtime-v2 channel API surface differs across supabase-swift
    /// 2.x minor releases (channel(_:) → .onPostgresChange(...) → subscribe()).
    /// To avoid pinning to an API that may not match the resolved package
    /// version at build time, this is kept as a stub. Wire it up against the
    /// project's actual supabase-swift version, e.g.:
    ///
    ///   let channel = repo.client.realtimeV2.channel("live-cheers")
    ///   let inserts = channel.postgresChange(InsertAction.self, table: "feed_cheers")
    ///   await channel.subscribe()
    ///   for await change in inserts { /* decode payload, showToast(...) */ }
    ///
    /// then filter to rows where the affected post belongs to `userId` and the
    /// actor isn't `userId`, mirroring the web's RLS-backed checks.
    func startRealtime() {
        // No-op for now — see TODO above. The feed still updates on
        // `.refreshable` and after every local action via `load()`.
    }

    func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(for: .seconds(4))
            if toast == text { toast = nil }
        }
    }
}
