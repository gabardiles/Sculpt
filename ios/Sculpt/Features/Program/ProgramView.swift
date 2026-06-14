import SwiftUI

/// The Program editor — lists the program's days with their exercises, lets you
/// swap (guarded to the same movement + muscle, same-role first), remove, add
/// from the library, create your own exercise, and switch templates. Rep targets
/// show per phase. Mirrors src/components/program/ProgramClient.tsx.
struct ProgramView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.palette) private var palette
    @StateObject private var vm = ProgramViewModel()

    @State private var editing = false
    @State private var helpOpen = false
    @State private var createOpen = false

    // Sheet routing
    @State private var swapFor: SwapTarget?
    @State private var addFor: DayWithExercises?
    @State private var switchTarget: String?

    /// What the swap sheet needs — the row id plus the exercise being replaced.
    struct SwapTarget: Identifiable {
        let programExerciseId: String
        let exercise: Exercise
        var id: String { programExerciseId }
    }

    var body: some View {
        ZStack {
            SculptBackground()
            ScrollView {
                if vm.loading && vm.program == nil {
                    ProgressView().tint(palette.blushDeep).padding(.top, 120)
                } else if let program = vm.program {
                    VStack(alignment: .leading, spacing: 24) {
                        header(program)
                        phaseSections(program)
                        if !vm.otherTemplates.isEmpty { switchSection(program) }
                    }
                    .padding(20).padding(.bottom, 90)
                } else {
                    Text("No active program yet.")
                        .font(.sans(15, weight: .light))
                        .foregroundStyle(palette.inkSoft).padding(.top, 120)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(item: $swapFor) { swapSheet($0) }
        .sheet(item: $addFor) { addSheet($0) }
        .sheet(isPresented: $helpOpen) { helpSheet }
        .sheet(isPresented: $createOpen) { CreateExerciseSheet(vm: vm) }
        .sheet(item: switchSheetBinding) { switchSheet($0) }
    }

    // MARK: - Header

    private func header(_ program: ProgramWithDays) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Program")
                Text(program.program.name).font(.sans(30, weight: .light)).tracking(0.5)
                MonoText(headerLine(program), size: 12).tracking(1.4)
                    .foregroundStyle(palette.inkSoft)
            }
            Spacer()
            HStack(spacing: 4) {
                iconButton("questionmark.circle") { helpOpen = true }
                Button { editing.toggle() } label: {
                    Image(systemName: editing ? "checkmark" : "pencil")
                        .font(.system(size: 17, weight: editing ? .bold : .regular))
                        .foregroundStyle(editing ? palette.onAccent : palette.inkSoft)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(editing ? palette.blush : .clear))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func headerLine(_ program: ProgramWithDays) -> String {
        if program.program.scheduleMode == .fixed {
            return "FIXED · \(program.program.weeks) WEEKS"
        }
        return "\(program.days.count) DAYS · 3-WEEK WAVE"
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 18, weight: .light))
                .foregroundStyle(palette.inkSoft).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Phase sections

    /// The three-week wave, stacked. Exercise rows show in the light section
    /// (or whenever editing) so the same list isn't repeated three times.
    private func phaseSections(_ program: ProgramWithDays) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            ForEach(Array(RepTargets.phases.enumerated()), id: \.element) { wi, phase in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        MonoText("WEEK \(wi + 1) · \(phase.rawValue.uppercased())", size: 12)
                            .tracking(1.4)
                            .foregroundStyle(phase == .light ? palette.blushDeep : palette.inkSoft)
                        Spacer()
                        MonoText("\(RepTargets.repTarget(.strength, .squat, phase)) reps", size: 12)
                            .foregroundStyle(palette.inkSoft)
                    }
                    VStack(spacing: 10) {
                        ForEach(program.days) { day in
                            dayCard(day, showExercises: editing || wi == 0)
                        }
                    }
                }
            }
        }
    }

    private func dayCard(_ day: DayWithExercises, showExercises: Bool) -> some View {
        GlassCard {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow("Day \(day.day.dayIndex)")
                        Text(day.day.name).font(.sans(16, weight: .light))
                    }
                    Spacer()
                    MonoText("\(day.exercises.count) exercises", size: 12)
                        .foregroundStyle(palette.inkSoft)
                }
                .padding(.vertical, 14).padding(.horizontal, 18)

                if showExercises {
                    Divider().overlay(palette.edge)
                    VStack(spacing: 0) {
                        ForEach(day.exercises) { row in
                            exerciseRow(row)
                        }
                        if editing {
                            Button { addFor = day } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus").font(.system(size: 14))
                                    Text("Add exercise").font(.sans(14, weight: .light))
                                    Spacer()
                                }
                                .foregroundStyle(palette.blushDeep)
                                .padding(.vertical, 12).padding(.horizontal, 18)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func exerciseRow(_ row: ProgramExercise) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.exercise?.name ?? "Exercise").font(.sans(14, weight: .light)).lineLimit(1)
                if let scheme = row.scheme {
                    MonoText(scheme, size: 11).foregroundStyle(palette.inkSoft.opacity(0.8))
                }
            }
            Spacer()
            if let ex = row.exercise {
                if let eq = ex.equipment, !editing {
                    MonoText(eq.uppercased(), size: 11).foregroundStyle(palette.inkSoft.opacity(0.7))
                }
                if editing {
                    Button {
                        swapFor = SwapTarget(programExerciseId: row.id, exercise: ex)
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 15))
                            .foregroundStyle(palette.blushDeep).frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    Button {
                        Task { await vm.remove(programExerciseId: row.id) }
                    } label: {
                        Image(systemName: "trash").font(.system(size: 14))
                            .foregroundStyle(palette.inkSoft.opacity(0.8)).frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.busy)
                }
            }
        }
        .padding(.vertical, 6).padding(.horizontal, 18)
    }

    // MARK: - Switch program

    private func switchSection(_ program: ProgramWithDays) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Switch program")
            ForEach(vm.otherTemplates, id: \.self) { template in
                GlassCard {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15)).foregroundStyle(palette.inkSoft)
                        Text("Prefer \(template)? Switching replaces your current program — history stays.")
                            .font(.sans(12, weight: .light)).foregroundStyle(palette.inkSoft)
                        Spacer(minLength: 6)
                        Button("Switch") { switchTarget = template }
                            .font(.sans(12)).foregroundStyle(palette.inkSoft)
                            .padding(.vertical, 8).padding(.horizontal, 14)
                            .background(Capsule().fill(palette.surfaceSoft))
                            .overlay(Capsule().strokeBorder(palette.edge))
                    }
                    .padding(14)
                }
            }
        }
    }

    // MARK: - Sheets

    private func swapSheet(_ target: SwapTarget) -> some View {
        let options = vm.swapOptions(for: target.exercise)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Swap \(target.exercise.name)").font(.sans(22, weight: .light))
                MonoText("\(target.exercise.movementPattern.rawValue) · \(target.exercise.muscleGroup)".uppercased(),
                         size: 11).tracking(1.2).foregroundStyle(palette.inkSoft)

                if options.sameTier.isEmpty && options.otherTier.isEmpty {
                    Text("No equivalent alternatives in the library yet.")
                        .font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
                } else {
                    ForEach(options.sameTier) { e in
                        swapOptionButton(e, target: target, detail: e.equipment, dimmed: false)
                    }
                    if !options.otherTier.isEmpty {
                        MonoText("DIFFERENT INTENSITY", size: 11).tracking(1.2)
                            .foregroundStyle(palette.inkSoft.opacity(0.8)).padding(.top, 6)
                        ForEach(options.otherTier) { e in
                            swapOptionButton(e, target: target,
                                             detail: [e.repProfile.rawValue, e.equipment].compactMap { $0 }.joined(separator: " · "),
                                             dimmed: true)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func swapOptionButton(_ e: Exercise, target: SwapTarget, detail: String?, dimmed: Bool) -> some View {
        Button {
            Task {
                await vm.swap(programExerciseId: target.programExerciseId, to: e.id)
                swapFor = nil
            }
        } label: {
            GlassCard {
                HStack {
                    Text(e.name).font(.sans(14, weight: .light))
                    Spacer()
                    if let d = detail, !d.isEmpty {
                        MonoText(d.uppercased(), size: 11).foregroundStyle(palette.inkSoft)
                    }
                }
                .padding(.vertical, 14).padding(.horizontal, 16)
            }
            .opacity(dimmed ? 0.8 : 1)
        }
        .buttonStyle(.plain)
        .disabled(vm.busy)
    }

    private func addSheet(_ day: DayWithExercises) -> some View {
        AddExerciseSheet(vm: vm, day: day,
                         onCreateOwn: { addFor = nil; createOpen = true })
    }

    private var switchSheetBinding: Binding<IdentifiedString?> {
        Binding(
            get: { switchTarget.map(IdentifiedString.init) },
            set: { switchTarget = $0?.value })
    }

    private func switchSheet(_ wrapped: IdentifiedString) -> some View {
        let template = wrapped.value
        return VStack(alignment: .leading, spacing: 16) {
            Eyebrow("Switch program")
            Text("Replace \(vm.program?.program.name ?? "your program") with \(template)?")
                .font(.sans(20, weight: .light))
            Text("Your history is kept, but the new program starts from the beginning.")
                .font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
            Spacer()
            PillButton(title: vm.busy ? "Switching…" : "Yes, switch") {
                Task { await vm.switchTo(template: template); switchTarget = nil; editing = false }
            }
            .disabled(vm.busy)
            PillButton(title: "Cancel", kind: .ghost) { switchTarget = nil }
        }
        .padding(24)
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.height(340)])
    }

    private var helpSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How this works").font(.sans(22, weight: .light))
                helpBlock("Edit your program.",
                          "Tap the pencil up top. Every exercise gets a swap icon — you'll only ever be offered exercises that train the same muscle with the same movement, so the program stays balanced no matter what you change. Same-role options come first; machines and free weights are interchangeable.")
                helpBlock("Add or remove.",
                          "In edit mode each day has an \"Add exercise\" row and a trash icon on every exercise. Removing never deletes your logged history.")
                helpBlock("Your own exercises.",
                          "Missing something your gym has? Create it below — name it, say what it trains, and it joins your library (only you see it). Paste a YouTube link if you want the video behind the play button. Reps are automatic: the 3-week wave sets them from the training role you pick.")

                Eyebrow("Why swaps work").padding(.top, 4)
                Text(ProgramCopy.whySwaps).font(.sans(14, weight: .light))
                    .foregroundStyle(palette.inkSoft)

                PillButton(title: "Create your own exercise", kind: .ghost, icon: "plus") {
                    helpOpen = false; createOpen = true
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.large])
    }

    private func helpBlock(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.sans(15, weight: .medium))
            Text(body).font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
        }
    }
}

/// Small Identifiable wrapper so a plain String can drive `.sheet(item:)`.
struct IdentifiedString: Identifiable {
    let value: String
    var id: String { value }
    init(_ value: String) { self.value = value }
}
