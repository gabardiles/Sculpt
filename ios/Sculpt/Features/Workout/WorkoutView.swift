import SwiftUI
import PhotosUI

/// The session screen — tap to expand, log KG/REP/SET, mark Done (rest timer
/// kicks in), Finish with a feel rating, then the sage celebration + share.
/// Mirrors src/components/workout/WorkoutClient.tsx.
struct WorkoutView: View {
    @StateObject private var vm: WorkoutViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var expanded: String?
    @State private var videoFor: WorkoutViewModel.WorkoutExercise?
    @State private var feelOpen = false
    @State private var feel: Int?
    @State private var saving = false
    @State private var celebrating = false
    @State private var restUntil: Date?
    @State private var restNext: String?
    @State private var shareItem: PhotosPickerItem?
    @State private var shared = false
    @State private var sharing = false
    /// When she opened the session — used to log a Health workout on finish.
    @State private var sessionStart = Date()
    /// Live scroll offset (≤ 0 once scrolled), driving the collapsing hero.
    @State private var scrollY: CGFloat = 0

    private let bannerHeight: CGFloat = 220
    private let scrollSpace = "workoutScroll"

    /// How far we've scrolled past the top, clamped to ≥ 0.
    private var scrolled: CGFloat { max(0, -scrollY) }
    /// Hero fades over the first ~150pt and blurs out as content rises over it.
    private var heroOpacity: Double { Double(max(0, 1 - scrolled / 150)) }
    private var heroBlur: CGFloat { min(20, scrolled / 7) }

    init(day: DayWithExercises, phase: Phase, program: ProgramWithDays?) {
        _vm = StateObject(wrappedValue: WorkoutViewModel(day: day, program: program))
    }

    var body: some View {
        ZStack(alignment: .top) {
            SculptBackground()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        offsetReader
                        // Hero scrolls with the list but fades + blurs out as it
                        // goes — in-flow so it can't bleed through the cards.
                        banner
                            .blur(radius: heroBlur)
                            .opacity(heroOpacity)
                        progressBlock.padding(.horizontal, 20).padding(.top, 14)
                        if let content = vm.fixedInfo?.content, !content.isEmpty {
                            GlassCard {
                                Text(content).font(.sans(14, weight: .light))
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(16)
                            }
                            .padding(.horizontal, 20).padding(.top, 16)
                        }
                        exerciseList.padding(20)
                    }
                    .padding(.bottom, 120)
                }
                .coordinateSpace(name: scrollSpace)
                .scrollTargetBehavior(.viewAligned)
                .onPreferenceChange(ScrollOffsetKey.self) { scrollY = $0 }
                // Tapping (or auto-advancing to) an exercise snaps it to the top.
                .onChange(of: expanded) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(id, anchor: .top) }
                }
            }
            if let until = restUntil {
                RestTimer(until: until, nextName: restNext) {
                    restUntil = nil
                    LocalNotifications.shared.cancelRestEnd()
                    RestActivityController.shared.end()
                }
                .padding(.top, 8)
            }
            finishFooter
            if celebrating { celebration }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load(); restoreDraft() }
        .onChange(of: vm.entries) { _, new in WorkoutDraft.save(dayId: vm.day.day.id, entries: new) }
        // Sheets start their own environment branch too — carry the theme in.
        .sheet(item: $videoFor) { ex in instructionSheet(ex).environment(\.palette, palette) }
        .sheet(isPresented: $feelOpen) { feelSheet.environment(\.palette, palette) }
    }

    // MARK: header

    /// Reports the scroll content's top edge into `scrollY` (≤ 0 once scrolled).
    private var offsetReader: some View {
        GeometryReader { geo in
            Color.clear.preference(key: ScrollOffsetKey.self,
                                   value: geo.frame(in: .named(scrollSpace)).minY)
        }
        .frame(height: 0)
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(vm.fixedInfo != nil
                        ? "\(vm.fixedInfo!.sessionLabel) · \(vm.fixedInfo!.intensityLabel) WEEK"
                        : "Day \(vm.day.day.dayIndex) · \(vm.phase.rawValue.uppercased()) WEEK")
                Text(vm.day.day.name).font(.sans(32, weight: .light)).tracking(0.5)
            }
            .padding(20)
            MonoText(vm.fixedInfo != nil
                     ? "WEEK \(vm.cycle)/\(vm.fixedInfo!.totalWeeks) · \(vm.fixedInfo!.intensityLabel)"
                     : "CYCLE \(vm.cycle) · WEEK \(vm.weekIndex) · \(vm.phase.rawValue.uppercased())",
                     size: 11)
                .padding(.vertical, 6).padding(.horizontal, 12)
                .background(Capsule().fill(.ultraThinMaterial))
                .padding(.horizontal, 16).padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(height: bannerHeight)
        .background(
            ZStack {
                LinearGradient(colors: [palette.blush.opacity(0.5), palette.bg], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
            }
            // NB: must NOT .ignoresSafeArea here — inside an in-flow ScrollView
            // header it collapses the banner's measured height and the content
            // below slides up under the title. The top gradient is handled by
            // SculptBackground bleeding through the status-bar area instead.
        )
    }

    private var progressBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !vm.exercises.isEmpty {
                MonoText("\(RepTargets.repTarget(.strength, .squat, vm.repPhase)) reps · 3 sets · \(vm.doneCount)/\(vm.exercises.count) done", size: 12)
                    .foregroundStyle(palette.inkSoft)
                ProgressView(value: Double(vm.doneCount), total: Double(max(1, vm.exercises.count)))
                    .tint(palette.sage)
            } else {
                MonoText("Follow the session below, then finish to log it.", size: 12)
                    .foregroundStyle(palette.inkSoft)
            }
            if let r = vm.rationale {
                Text(r).font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
            }
            if vm.alreadyDone {
                Text("Already logged this week — logging again adds a second session.")
                    .font(.sans(12)).foregroundStyle(palette.sageDeep)
            }
        }
    }

    // MARK: exercises

    private var exerciseList: some View {
        VStack(spacing: 12) {
            ForEach(vm.exercises) { ex in
                let isNext = ex.id == vm.nextUpId
                let done = vm.entries[ex.id]?.done ?? false
                GlassCard(style: done ? .done : (isNext ? .spotlight : .normal)) {
                    VStack(spacing: 0) {
                        Button { withAnimation(.easeInOut(duration: 0.25)) { expanded = expanded == ex.id ? nil : ex.id } } label: { row(ex, done: done, isNext: isNext) }
                            .buttonStyle(.plain)
                        if expanded == ex.id {
                            logPanel(ex, done: done)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .id(ex.id)
            }
        }
        .scrollTargetLayout()   // snap the scroll to whole exercise cards
    }

    private func row(_ ex: WorkoutViewModel.WorkoutExercise, done: Bool, isNext: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(done ? palette.sage : palette.surfaceSoft)
                    .frame(width: 28, height: 28)
                if done { Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white) }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isNext && !done {
                        Text("NEXT").font(.mono(10, weight: .medium))
                            .padding(.vertical, 2).padding(.horizontal, 6)
                            .background(Capsule().fill(palette.blushDeep)).foregroundStyle(palette.onAccent)
                    }
                    Text(ex.name).font(.sans(16)).lineLimit(1)
                }
                MonoText(lastLine(ex), size: 11).foregroundStyle(palette.inkSoft)
            }
            Spacer()
            Button { videoFor = ex } label: {
                Image(systemName: "play.circle").font(.system(size: 20, weight: .light)).foregroundStyle(palette.inkSoft)
            }.buttonStyle(.plain)
        }
        .padding(.vertical, 14).padding(.horizontal, 18)
        .contentShape(Rectangle())
    }

    private func lastLine(_ ex: WorkoutViewModel.WorkoutExercise) -> String {
        var s = ex.muscleGroup.uppercased()
        if let w = ex.lastWeight {
            s += " · LAST: \(Fmt.kg(w)) \(ex.unit.rawValue)"
            if ex.unit == .kg, let r = ex.lastReps { s += " × \(r) × \(ex.lastSets ?? ex.sets)" }
            if let lp = ex.lastPhase { s += " (\(lp.rawValue) wk)" }
        }
        return s
    }

    private func logPanel(_ ex: WorkoutViewModel.WorkoutExercise, done: Bool) -> some View {
        let binding = Binding(
            get: { vm.entries[ex.id] ?? .init(weight: "", reps: "", sets: "", done: false) },
            set: { vm.entries[ex.id] = $0 })
        return VStack(spacing: 12) {
            Divider().overlay(palette.edge)
            HStack(spacing: 8) {
                numField(ex.unit == .s ? "SEC" : "KG", text: binding.weight)
                if ex.unit == .kg { numField("REP", text: binding.reps) }
                numField("SET", text: binding.sets)
            }
            if let scheme = ex.scheme {
                MonoText(scheme, size: 12).foregroundStyle(palette.inkSoft)
            } else {
                MonoText("target \(RepTargets.repTarget(ex.repProfile, ex.movementPattern, vm.repPhase))\(ex.unit == .s ? " hold" : " reps")", size: 12)
                    .foregroundStyle(palette.inkSoft)
            }
            if let bump = vm.suggestBump(ex) {
                MonoText(bump, size: 12, weight: .medium).foregroundStyle(palette.sageDeep)
            }
            if done {
                PillButton(title: "Undo", kind: .ghost, icon: "xmark") { vm.entries[ex.id]?.done = false }
            } else {
                PillButton(title: "Done", kind: .sage, icon: "checkmark") { markDone(ex) }
            }
        }
        .padding(.vertical, 14).padding(.horizontal, 18)
    }

    private func numField(_ label: String, text: Binding<String>) -> some View {
        VStack(spacing: 4) {
            Eyebrow(label)
            TextField("—", text: text)
                .keyboardType(.decimalPad).multilineTextAlignment(.center)
                .font(.mono(24, weight: .light))
                .frame(height: 56).frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(palette.edge))
        }
    }

    private func markDone(_ ex: WorkoutViewModel.WorkoutExercise) {
        Haptics.success()
        let next = vm.exercises.first { $0.id != ex.id && !(vm.entries[$0.id]?.done ?? false) }
        // Smooth morph: the card fills green and its log panel collapses while the
        // next card expands — a soft spring instead of an instant blink.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            vm.entries[ex.id]?.done = true
            expanded = next?.id
        }
        if next != nil {
            restNext = next?.name
            let until = Date().addingTimeInterval(Double(RepTargets.restSeconds[vm.repPhase] ?? 90))
            restUntil = until
            // Buzz when rest ends even if she's left the app mid-session.
            LocalNotifications.shared.scheduleRestEnd(at: until, nextName: next?.name)
            // Live Activity: rest timer on the Lock Screen / Dynamic Island.
            RestActivityController.shared.start(dayName: vm.day.day.name, endDate: until,
                                                nextExercise: next?.name ?? "Next set")
        }
    }

    // MARK: footer

    private var finishFooter: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                // Bail: themed surface circle, brand-tinted X.
                Button { leave() } label: {
                    Image(systemName: "xmark").font(.system(size: 17, weight: .medium))
                        .foregroundStyle(palette.blushDeep)
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(palette.surfaceStrong))
                        .overlay(Circle().strokeBorder(palette.blushDeep.opacity(0.25)))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                }
                // Primary CTA: the strong brand color per theme, always prominent.
                Button { feel = nil; feelOpen = true } label: {
                    Text(vm.exercises.isEmpty ? "Finish workout" : "Finish workout · \(vm.doneCount)/\(vm.exercises.count)")
                        .font(.sans(16, weight: .semibold))
                        .foregroundStyle(palette.onAccent)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .background(Capsule().fill(palette.blushDeep))
                        .shadow(color: palette.blushDeep.opacity(0.35), radius: 10, y: 4)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 12).padding(.top, 28)
            // Scrim so cards scrolling under the floating bar stay legible.
            .background(
                LinearGradient(colors: [palette.bg.opacity(0), palette.bg.opacity(0.9), palette.bg],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            )
        }
    }

    // MARK: sheets

    private func instructionSheet(_ ex: WorkoutViewModel.WorkoutExercise) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(ex.name).font(.sans(22, weight: .light))
                if let urlStr = ex.instructionUrl, let url = URL(string: urlStr) {
                    Link(destination: url) {
                        HStack { Image(systemName: "play.rectangle"); Text("Watch the form video") }
                            .padding(12).frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 14).fill(palette.surface))
                    }
                }
                HStack {
                    tag(ex.muscleGroup, fill: palette.blush.opacity(0.4))
                    if let eq = ex.equipment { tag(eq, fill: palette.surface) }
                }
                if let cue = ex.cue {
                    Text(cue).font(.sans(15, weight: .light)).foregroundStyle(palette.inkSoft)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        }
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func tag(_ text: String, fill: Color) -> some View {
        MonoText(text.uppercased(), size: 11).padding(.vertical, 5).padding(.horizontal, 12)
            .background(Capsule().fill(fill))
    }

    private var feelSheet: some View {
        VStack(spacing: 0) {
            Eyebrow("Session complete").padding(.top, 28)
            Text("How did it feel?").font(.sans(24, weight: .light)).padding(.top, 8)
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { n in
                    Button { feel = n } label: {
                        Text("\(n)").font(.mono(15))
                            .frame(width: 48, height: 48)
                            .background(Circle().fill(feel == n ? palette.blush : palette.surfaceSoft))
                            .foregroundStyle(feel == n ? palette.onAccent : palette.inkSoft)
                            .overlay(Circle().strokeBorder(feel == n ? palette.blushDeep : palette.edge))
                            .scaleEffect(feel == n ? 1.1 : 1)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.top, 28)
            HStack { Text("rough"); Spacer(); Text("unstoppable") }
                .font(.sans(11)).foregroundStyle(palette.inkSoft).padding(.horizontal, 8).padding(.top, 6)
            PillButton(title: saving ? "Saving…" : "Save session") { Task { await save() } }
                .disabled(feel == nil || saving)
                .padding(.top, 28)
            Spacer()
        }
        .padding(24)
        .background(palette.bg.ignoresSafeArea())
        .presentationDetents([.height(360)])
    }

    private var celebration: some View {
        ZStack {
            palette.bg.opacity(0.97).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(palette.sage).frame(width: 96, height: 96)
                    Image(systemName: "checkmark").font(.system(size: 40, weight: .bold)).foregroundStyle(.white)
                }
                Text("\(vm.day.day.name) — done").font(.sans(24, weight: .light))
                if shared {
                    Text("Shared with your friends ✓").font(.sans(14, weight: .medium)).foregroundStyle(palette.sageDeep)
                } else {
                    Text(vm.sharePrompt).font(.sans(14, weight: .light)).multilineTextAlignment(.center)
                        .foregroundStyle(palette.inkSoft).padding(.horizontal, 24)
                    PhotosPicker(selection: $shareItem, matching: .images) {
                        HStack { Image(systemName: "camera"); Text(sharing ? "Posting…" : "Snap it for the feed") }
                            .font(.sans(16, weight: .medium)).foregroundStyle(palette.onAccent)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Capsule().fill(palette.blush))
                    }
                    .padding(.horizontal, 32)
                    Button("Not today") { leave() }
                        .font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
                }
            }
        }
        .onChange(of: shareItem) { _, item in if let item { Task { await share(item) } } }
    }

    // MARK: actions

    private func restoreDraft() {
        if let saved = WorkoutDraft.load(dayId: vm.day.day.id) {
            for (id, e) in saved where vm.entries[id] != nil { vm.entries[id] = e }
        }
    }

    private func save() async {
        guard let feel else { return }
        saving = true
        if await vm.save(feel: feel) {
            feelOpen = false; celebrating = true
            Haptics.celebrate()
            LocalNotifications.shared.cancelRestEnd()
            RestActivityController.shared.end()
            LocalNotifications.shared.bumpAfterWorkout()
            // Mirror the session into Apple Health (best-effort, opt-in). The
            // first finished workout is when we ask for Health permission.
            if !HealthKitManager.shared.enabled {
                _ = await HealthKitManager.shared.requestAuthorization()
            }
            await HealthKitManager.shared.saveStrengthWorkout(start: sessionStart, end: Date())
            // Light up today on the Green Days calendar.
            if let userId = await Repository.shared.currentUserId() {
                try? await Repository.shared.markWorkoutDone(userId: userId)
            }
        }
        saving = false
    }

    private func share(_ item: PhotosPickerItem) async {
        sharing = true
        if let data = try? await item.loadTransferable(type: Data.self),
           let userId = await Repository.shared.currentUserId() {
            try? await Repository.shared.createFeedPhoto(userId: userId, data: data, caption: "\(vm.day.day.name) — done ✓")
            shared = true
            try? await Task.sleep(for: .seconds(1.2))
            leave()
        }
        sharing = false
    }

    private func leave() {
        LocalNotifications.shared.cancelRestEnd()
        RestActivityController.shared.end()
        dismiss()
    }
}

/// Tracks the workout scroll view's top-edge offset for the collapsing hero.
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}
