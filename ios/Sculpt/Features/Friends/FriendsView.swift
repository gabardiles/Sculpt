import SwiftUI
import PhotosUI

/// The Friends feed — a stream of wins (workouts, PBs, photos, messages) from
/// you and your friends. Cheer with a heart, comment, post a message or a gym
/// photo, and manage friends by 6-char code in a sheet. Realtime cheers pop a
/// small toast (best-effort).
///
/// Mirrors src/components/friends/FriendsClient.tsx and the data shaping in
/// src/app/(app)/friends/page.tsx. All loading + mutation lives in
/// FriendsViewModel; this file is just the UI.
struct FriendsView: View {
    @StateObject private var vm = FriendsViewModel()
    @Environment(\.palette) private var palette
    @EnvironmentObject var session: SessionStore

    @State private var message = ""
    @State private var posting = false
    @State private var photoItem: PhotosPickerItem?
    @State private var manageOpen = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Screen {
                header
                composer
                feed
            }
            if let toast = vm.toast {
                toastBubble(toast)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.standard, value: vm.toast)
        .task {
            if !vm.loaded { await vm.load() }
            vm.startRealtime()
        }
        .onDisappear { vm.stopRealtime() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $manageOpen) { manageSheet }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task { await postPhoto(item); photoItem = nil }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow("Friends")
                Text("The feed").font(.sans(28, weight: .light)).tracking(1)
                Text("Wins only — workouts, PBs, gym photos. Never your weight or progress photos.")
                    .font(.sans(14, weight: .light))
                    .foregroundStyle(palette.inkSoft)
            }
            Spacer(minLength: 0)
            Button { manageOpen = true } label: {
                Image(systemName: "person.2")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(palette.inkSoft)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(palette.surface))
                    .overlay(Circle().strokeBorder(palette.edge))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Friends and invites")
        }
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Say something nice…", text: $message, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.sans(14))
                    .fieldStyle(palette)
                Button { Task { await postMessage() } } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(palette.onAccent)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(palette.blush))
                }
                .buttonStyle(.plain)
                .disabled(posting || trimmedMessage.isEmpty)
                .opacity(posting || trimmedMessage.isEmpty ? 0.4 : 1)
                .accessibilityLabel("Send message")
            }
            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                    Text(posting ? "Posting…" : "Share a gym photo")
                        .font(.sans(16, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(palette.ink)
                .background(Capsule().fill(palette.surface))
                .overlay(Capsule().strokeBorder(palette.edge))
            }
            .disabled(posting)
        }
        .padding(.top, 4)
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Feed

    @ViewBuilder private var feed: some View {
        if vm.items.isEmpty {
            Text(vm.friends.isEmpty
                 ? "Add a friend with her code — tap the people icon above to start."
                 : "Quiet for now. Your next workout will show up here.")
                .font(.sans(14, weight: .light))
                .foregroundStyle(palette.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        } else {
            VStack(spacing: 12) {
                ForEach(vm.items) { item in
                    FeedCard(vm: vm, item: item,
                             photoURL: item.storagePath.flatMap { vm.photoURLs[$0] })
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Toast

    private func toastBubble(_ text: String) -> some View {
        GlassCard {
            HStack(spacing: 10) {
                Text("👏").font(.system(size: 20))
                Text(text).font(.sans(14, weight: .light))
                    .lineLimit(2)
                    .foregroundStyle(palette.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12).padding(.horizontal, 16)
        }
        .onTapGesture { vm.toast = nil }
    }

    // MARK: - Manage sheet (code, add, friends list)

    private var manageSheet: some View {
        FriendsManageSheet(vm: vm)
            .environment(\.palette, palette)
    }

    // MARK: - Actions

    private func postMessage() async {
        guard !trimmedMessage.isEmpty, !posting else { return }
        posting = true
        let body = message
        message = ""
        await vm.postMessage(body)
        posting = false
    }

    private func postPhoto(_ item: PhotosPickerItem) async {
        guard !posting else { return }
        posting = true
        defer { posting = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let caption = trimmedMessage.isEmpty ? nil : message
        message = ""
        await vm.postPhoto(data, caption: caption)
    }
}

// MARK: - Feed card

/// One post. Workouts and PBs are a compact single row; messages and photos get
/// the full card with a body, optional photo, cheer bar and comment thread.
private struct FeedCard: View {
    @ObservedObject var vm: FriendsViewModel
    let item: FriendsViewModel.FeedItem
    let photoURL: URL?
    @Environment(\.palette) private var palette

    var body: some View {
        if item.type == .workout || item.type == .pb {
            GlassCard(style: item.type == .workout ? .done : .normal) {
                compactRow.padding(.vertical, 12).padding(.horizontal, 16)
            }
        } else {
            GlassCard {
                fullCard.padding(16)
            }
        }
    }

    // MARK: compact (workout / pb)

    private var compactRow: some View {
        HStack(spacing: 10) {
            Image(systemName: item.type == .workout ? "checkmark" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 15, weight: item.type == .workout ? .bold : .semibold))
                .foregroundStyle(item.type == .workout ? palette.sageDeep : palette.blushDeep)
            (Text(item.authorName).font(.sans(14, weight: .medium))
             + Text(" ")
             + Text(compactBody).font(.sans(14, weight: .light)))
                .lineLimit(1)
            if let phase = item.phase {
                MonoText(phase.uppercased(), size: 11).foregroundStyle(palette.inkSoft)
            }
            MonoText(Fmt.day(item.createdAt), size: 11).foregroundStyle(palette.inkSoft)
            Spacer(minLength: 0)
            cheerButton(compact: true)
        }
    }

    private var compactBody: String {
        if item.type == .workout { return item.dayName ?? item.body ?? "" }
        return item.body ?? ""
    }

    // MARK: full (message / photo)

    private var fullCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.authorName).font(.sans(14, weight: .medium))
                Spacer()
                MonoText(Fmt.day(item.createdAt), size: 11).foregroundStyle(palette.inkSoft)
            }

            if item.type == .message, let body = item.body {
                Text("“\(body)”")
                    .font(.sans(14, weight: .light))
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if item.type == .photo {
                if let url = photoURL {
                    RemoteImage(url)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if let body = item.body, !body.isEmpty {
                    Text(body).font(.sans(14, weight: .light)).foregroundStyle(palette.ink)
                }
            }

            HStack {
                cheerButton(compact: false)
                Spacer()
                if item.mine && (item.type == .message || item.type == .photo) {
                    Button { Task { await vm.deletePost(item) } } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.inkSoft)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Delete post")
                }
            }

            CommentThread(vm: vm, item: item, photoURL: photoURL)
        }
    }

    // MARK: cheer

    private func cheerButton(compact: Bool) -> some View {
        Button { Task { await vm.toggleCheer(item) } } label: {
            HStack(spacing: compact ? 6 : 8) {
                Image(systemName: item.cheeredByMe ? "heart.fill" : "heart")
                    .font(.system(size: compact ? 18 : 20, weight: .regular))
                    .foregroundStyle(item.cheeredByMe ? palette.blushDeep : palette.inkSoft)
                if compact {
                    if !item.cheerNames.isEmpty {
                        Text(item.cheerLabel)
                            .font(.sans(12, weight: .medium))
                            .foregroundStyle(palette.blushDeep)
                            .lineLimit(1)
                    }
                } else {
                    Text(item.cheerLabel)
                        .font(.sans(14, weight: item.cheerNames.isEmpty ? .light : .medium))
                        .foregroundStyle(item.cheerNames.isEmpty ? palette.inkSoft : palette.blushDeep)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, compact ? 2 : 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.cheeredByMe ? "Remove cheer" : "Cheer")
    }
}

// MARK: - Comments

private struct CommentThread: View {
    @ObservedObject var vm: FriendsViewModel
    let item: FriendsViewModel.FeedItem
    let photoURL: URL?
    @Environment(\.palette) private var palette

    @State private var open = false
    @State private var text = ""
    @State private var busy = false

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(palette.edge)

            if !item.comments.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(item.comments) { c in
                        HStack(alignment: .top, spacing: 8) {
                            (Text(c.authorName).font(.sans(14, weight: .medium))
                             + Text(" ")
                             + Text(c.body).font(.sans(14, weight: .light)))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if c.mine && !c.pending {
                                Button { Task { await vm.deleteComment(c, from: item) } } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13))
                                        .foregroundStyle(palette.inkSoft)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete comment")
                            }
                        }
                    }
                }
            }

            if open {
                HStack(spacing: 8) {
                    commentAnchor
                    TextField("Comment on \(item.authorName)'s \(item.type == .photo ? "photo" : "post")…",
                              text: $text)
                        .font(.sans(14))
                        .fieldStyle(palette)
                    Button { Task { await submit() } } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.onAccent)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(palette.blush))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy || trimmed.isEmpty)
                    .opacity(busy || trimmed.isEmpty ? 0.4 : 1)
                    .accessibilityLabel("Send comment")
                }
            } else {
                Button { open = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left").font(.system(size: 13))
                        Text(item.comments.isEmpty ? "Comment" : "Add a comment")
                            .font(.sans(13, weight: .light))
                    }
                    .foregroundStyle(palette.inkSoft)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder private var commentAnchor: some View {
        if item.type == .photo, let url = photoURL {
            RemoteImage(url)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            Image(systemName: "bubble.left")
                .font(.system(size: 15))
                .foregroundStyle(palette.inkSoft)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(palette.surfaceSoft))
        }
    }

    private func submit() async {
        guard !trimmed.isEmpty, !busy else { return }
        busy = true
        let body = text
        text = ""
        await vm.addComment(to: item, body: body)
        busy = false
    }
}

// MARK: - Manage sheet

/// Your friend code (tap to copy), add-by-code, and the friends list with a
/// remove action. The web app keeps all of this tucked in one sheet.
private struct FriendsManageSheet: View {
    @ObservedObject var vm: FriendsViewModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var adding = false
    @State private var addError: String?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Friends").font(.sans(24, weight: .light))
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.sans(15)).foregroundStyle(palette.inkSoft)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Your code")
                    Button { copyCode() } label: {
                        HStack(spacing: 8) {
                            MonoText(vm.myCode.isEmpty ? "——————" : vm.myCode, size: 24)
                                .tracking(4)
                                .foregroundStyle(palette.ink)
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 15))
                                .foregroundStyle(copied ? palette.sageDeep : palette.inkSoft)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy your friend code")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Friend's code", text: $code)
                            .font(.mono(14))
                            .tracking(4)
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: code) { _, new in
                                code = String(new.uppercased().prefix(6))
                            }
                            .fieldStyle(palette)
                        PillButton(title: "Add", fullWidth: false, icon: "person.badge.plus") {
                            Task { await add() }
                        }
                        .fixedSize()
                        .disabled(adding || code.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if let addError {
                        Text(addError)
                            .font(.sans(12)).foregroundStyle(palette.blushDeep)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }

                if !vm.friends.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(vm.friends) { friend in
                            GlassCard {
                                HStack {
                                    Text(friend.name).font(.sans(14))
                                    Spacer()
                                    Button { Task { await vm.removeFriend(friend) } } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 15))
                                            .foregroundStyle(palette.inkSoft)
                                            .frame(width: 40, height: 40)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove \(friend.name)")
                                }
                                .padding(.vertical, 6).padding(.horizontal, 16)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func copyCode() {
        guard !vm.myCode.isEmpty else { return }
        UIPasteboard.general.string = vm.myCode
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }

    private func add() async {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !adding else { return }
        adding = true
        addError = nil
        let err = await vm.addFriend(code: trimmed)
        if err == nil { code = "" }
        addError = err
        adding = false
    }
}
