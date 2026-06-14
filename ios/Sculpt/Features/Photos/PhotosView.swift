import SwiftUI
import PhotosUI

/// Progress photos — private, grouped by cycle. Add one via the PhotosPicker
/// (tagged with a cycle number + week label), tap to view full, delete from there.
/// Mirrors src/components/photos/PhotosClient.tsx.
struct PhotosView: View {
    @StateObject private var vm = PhotosViewModel()
    @Environment(\.palette) private var palette

    @State private var pickerItem: PhotosPickerItem?
    @State private var composing = false
    @State private var cycle = 1
    @State private var weekLabel = "W1"
    @State private var viewing: PhotosViewModel.PhotoCard?

    private let columns = [GridItem(.flexible(), spacing: 8),
                           GridItem(.flexible(), spacing: 8),
                           GridItem(.flexible(), spacing: 8)]

    var body: some View {
        Screen {
            Eyebrow("Progress")
            Text("Photos").font(.sans(28, weight: .light)).tracking(1)
            Text("One per week. Private — only you can see these.")
                .font(.sans(14, weight: .light))
                .foregroundStyle(palette.inkSoft)

            addBar

            if vm.photos.isEmpty {
                Text("No photos yet — week one starts the story.")
                    .font(.sans(14, weight: .light))
                    .foregroundStyle(palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 32)
            } else {
                ForEach(vm.grouped, id: \.cycle) { group in
                    cycleSection(group)
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $composing) { composeSheet }
        .sheet(item: $viewing) { card in viewerSheet(card) }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await vm.upload(item: item, cycle: cycle, weekLabel: weekLabel); pickerItem = nil }
        }
    }

    // MARK: add

    private var addBar: some View {
        PillButton(title: vm.uploading ? "Uploading…" : "Add photo · C\(cycle) \(weekLabel)",
                   icon: "camera") {
            composing = true
        }
        .disabled(vm.uploading)
    }

    private var composeSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            Eyebrow("New photo")
            Text("Tag it").font(.sans(24, weight: .light))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Cycle")
                    Stepper(value: $cycle, in: 1...99) {
                        MonoText("C\(cycle)", size: 18)
                    }
                    .fieldStyle(palette)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Week")
                    TextField("W1", text: $weekLabel)
                        .multilineTextAlignment(.center)
                        .font(.mono(18))
                        .fieldStyle(palette)
                }
                .frame(width: 110)
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack { Image(systemName: "camera"); Text("Choose photo") }
                    .font(.sans(16, weight: .medium)).foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Capsule().fill(palette.blush))
            }
            .onChange(of: pickerItem) { _, item in if item != nil { composing = false } }

            Spacer()
        }
        .padding(24)
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.height(320)])
    }

    // MARK: grid

    private func cycleSection(_ group: PhotosViewModel.CycleGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Cycle \(group.cycle)")
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(group.photos) { card in
                    photoCell(card)
                }
            }
        }
    }

    private func photoCell(_ card: PhotosViewModel.PhotoCard) -> some View {
        Button { viewing = card } label: {
            ZStack(alignment: .bottomLeading) {
                thumbnail(card)
                MonoText(card.photo.weekLabel, size: 11)
                    .foregroundStyle(.white)
                    .padding(.vertical, 3).padding(.horizontal, 8)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
    }

    private func thumbnail(_ card: PhotosViewModel.PhotoCard) -> some View {
        Group {
            if let url = card.url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: palette.surfaceSoft
                    }
                }
            } else {
                palette.surfaceSoft
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fill)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: viewer

    private func viewerSheet(_ card: PhotosViewModel.PhotoCard) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Eyebrow("Cycle \(card.photo.cycleNumber) · \(card.photo.weekLabel)")
                if let url = card.url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        default:
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(palette.surfaceSoft)
                                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                        }
                    }
                }
                HStack {
                    Spacer()
                    PillButton(title: "Delete", kind: .ghost, fullWidth: false, icon: "trash") {
                        Task { await vm.delete(card); viewing = nil }
                    }
                    .fixedSize()
                }
            }
            .padding(24)
        }
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.large])
    }
}

@MainActor
final class PhotosViewModel: ObservableObject {
    struct PhotoCard: Identifiable {
        let photo: ProgressPhoto
        var url: URL?
        var id: String { photo.id }
    }
    struct CycleGroup {
        let cycle: Int
        let photos: [PhotoCard]
    }

    @Published var photos: [PhotoCard] = []   // newest first
    @Published var uploading = false

    private let bucket = "progress-photos"

    /// Grouped by cycle, newest cycle first (photos keep newest-first order).
    var grouped: [CycleGroup] {
        var order: [Int] = []
        var map: [Int: [PhotoCard]] = [:]
        for card in photos {
            let c = card.photo.cycleNumber
            if map[c] == nil { order.append(c) }
            map[c, default: []].append(card)
        }
        return order
            .sorted(by: >)
            .map { CycleGroup(cycle: $0, photos: map[$0] ?? []) }
    }

    func load() async {
        guard let userId = await Repository.shared.currentUserId() else { return }
        guard let fetched = try? await Repository.shared.getProgressPhotos(userId) else { return }
        var cards: [PhotoCard] = []
        for photo in fetched {
            let url = await Repository.shared.signedURL(bucket: bucket, path: photo.storagePath)
            cards.append(PhotoCard(photo: photo, url: url))
        }
        photos = cards
    }

    func upload(item: PhotosPickerItem, cycle: Int, weekLabel: String) async {
        guard let userId = await Repository.shared.currentUserId() else { return }
        uploading = true
        defer { uploading = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let label = weekLabel.trimmingCharacters(in: .whitespaces).isEmpty ? "W1" : weekLabel
        try? await Repository.shared.uploadProgressPhoto(
            userId: userId, data: data, cycle: cycle, weekLabel: label)
        await load()
    }

    func delete(_ card: PhotoCard) async {
        try? await Repository.shared.deleteProgressPhoto(
            id: card.photo.id, storagePath: card.photo.storagePath)
        await load()
    }
}
