import SwiftUI

/// The "Add to <day>" sheet — a searchable list of library exercises not yet in
/// the day, capped at 30, with a "create your own" escape hatch. Mirrors the
/// add sheet in src/components/program/ProgramClient.tsx.
struct AddExerciseSheet: View {
    @ObservedObject var vm: ProgramViewModel
    let day: DayWithExercises
    let onCreateOwn: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Add to \(day.day.name)").font(.sans(22, weight: .light))

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14)).foregroundStyle(palette.inkSoft)
                    TextField("Search the library", text: $search)
                        .font(.sans(15, weight: .light))
                        .autocorrectionDisabled()
                }
                .padding(.vertical, 12).padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.edge))

                let options = vm.addOptions(for: day, search: search)
                if options.isEmpty {
                    Text("Nothing else in the library matches.")
                        .font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
                } else {
                    ForEach(options) { e in
                        Button {
                            Task { await vm.add(to: day, exerciseId: e.id); dismiss() }
                        } label: {
                            GlassCard {
                                HStack {
                                    Text(e.name).font(.sans(14, weight: .light))
                                    Spacer()
                                    MonoText([e.movementPattern.rawValue, e.equipment].compactMap { $0 }.joined(separator: " · ").uppercased(),
                                             size: 11).foregroundStyle(palette.inkSoft)
                                }
                                .padding(.vertical, 14).padding(.horizontal, 16)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(vm.busy)
                    }
                }

                Button(action: onCreateOwn) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus").font(.system(size: 14))
                        Text("Not in the list? Create your own").font(.sans(14, weight: .light))
                    }
                    .foregroundStyle(palette.blushDeep)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }
}

/// "Your own exercise" — name, muscle, movement, training role, optional
/// equipment and YouTube link. The training role sets reps automatically; the
/// YouTube link is passed raw to instructionUrl. Mirrors the create form in
/// src/components/program/ProgramClient.tsx.
struct CreateExerciseSheet: View {
    @ObservedObject var vm: ProgramViewModel
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var muscleGroup: String?
    @State private var movementPattern: String?
    @State private var repProfile: String?
    @State private var equipment = ""
    @State private var videoUrl = ""
    @State private var error: String?

    private let muscleGroups = ["glutes", "hamstrings", "quads", "back", "chest",
                                "shoulders", "arms", "core", "calves"]
    private let patterns = ["hinge", "squat", "lunge", "thrust", "abduction",
                            "push", "pull", "core", "accessory"]
    /// label shown for each rep profile — same copy as the web select.
    private let profiles: [(value: String, label: String)] = [
        ("strength", "Heavy — 10–12 / 6–8 / 4–6 reps"),
        ("pump", "Pump — 15–20 / 12–15 / 10–12 reps"),
        ("timed", "Timed hold — 30 / 40 / 45 s"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your own exercise").font(.sans(22, weight: .light))

                TextField("Exercise name", text: $name).fieldStyle(palette)

                HStack(spacing: 10) {
                    picker("Muscle", options: muscleGroups, selection: $muscleGroup)
                    picker("Movement", options: patterns, selection: $movementPattern)
                }

                roleMenu

                TextField("Equipment (optional) — e.g. machine, dumbbells", text: $equipment)
                    .fieldStyle(palette)
                TextField("YouTube link (optional) — paste it here", text: $videoUrl)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .fieldStyle(palette)

                if let error {
                    Text(error).font(.sans(12)).foregroundStyle(palette.blushDeep)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                PillButton(title: vm.busy ? "Saving…" : "Save to my library") { save() }
                    .disabled(vm.busy)

                Text("Only you see your own exercises. Find them when swapping or adding.")
                    .font(.sans(12, weight: .light)).foregroundStyle(palette.inkSoft)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.large])
    }

    private func picker(_ placeholder: String, options: [String], selection: Binding<String?>) -> some View {
        Menu {
            ForEach(options, id: \.self) { o in
                Button(o.capitalized) { selection.wrappedValue = o }
            }
        } label: {
            HStack {
                Text(selection.wrappedValue?.capitalized ?? placeholder)
                    .font(.sans(15, weight: .light))
                    .foregroundStyle(selection.wrappedValue == nil ? palette.inkSoft : palette.ink)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11)).foregroundStyle(palette.inkSoft)
            }
            .padding(.vertical, 14).padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.edge))
        }
    }

    private var roleMenu: some View {
        Menu {
            ForEach(profiles, id: \.value) { p in
                Button(p.label) { repProfile = p.value }
            }
        } label: {
            HStack {
                Text(profiles.first { $0.value == repProfile }?.label
                     ?? "Training role — sets your reps automatically")
                    .font(.sans(15, weight: .light)).lineLimit(1)
                    .foregroundStyle(repProfile == nil ? palette.inkSoft : palette.ink)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11)).foregroundStyle(palette.inkSoft)
            }
            .padding(.vertical, 14).padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.edge))
        }
    }

    private func save() {
        error = nil
        guard let muscleGroup, let movementPattern, let repProfile else {
            error = "Pick a muscle, movement and training role."
            return
        }
        Task {
            let result = await vm.createCustom(
                name: name, muscleGroup: muscleGroup, movementPattern: movementPattern,
                repProfile: repProfile, equipment: equipment, youTube: videoUrl)
            if let result { error = result } else { dismiss() }
        }
    }
}
