import SwiftUI

/// The Goals tab — up to three active goals chased at a time, each with a
/// progress ring, plus achieved goals and a create sheet.
/// Mirrors src/app/(app)/goals/page.tsx + src/components/goals/GoalsClient.tsx.
struct GoalsView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.palette) private var palette
    @StateObject private var vm = GoalsViewModel()
    @State private var adding = false

    var body: some View {
        ZStack {
            SculptBackground()
            ScrollView {
                if vm.loading && vm.rows.isEmpty {
                    ScreenSkeleton().transition(.opacity)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        if vm.active.isEmpty { emptyState } else { activeList }
                        if vm.canAdd { addButton }
                        if !vm.achieved.isEmpty { achievedSection }
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                    .transition(.opacity)
                }
            }
            .animation(Motion.content, value: vm.loading)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $adding) {
            GoalFormSheet(library: vm.prExercises) { type, target, exerciseId, deadline in
                await vm.create(type: type, target: target, exerciseId: exerciseId, deadline: deadline)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow("Goals")
            Text("Three at a time").font(.sans(26, weight: .light)).tracking(0.5)
        }
    }

    private var emptyState: some View {
        Text("No goals yet — pick one thing worth chasing.")
            .font(.sans(14, weight: .light))
            .foregroundStyle(palette.inkSoft)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, 24)
    }

    private var activeList: some View {
        VStack(spacing: 12) {
            ForEach(vm.active) { g in
                GlassCard {
                    HStack(spacing: 16) {
                        ProgressRing(progress: g.progress, size: 64,
                                     label: "\(Int((g.progress * 100).rounded()))%")
                        VStack(alignment: .leading, spacing: 2) {
                            Eyebrow(typeTitle(g.type))
                            Text(g.label).font(.sans(16, weight: .light)).lineLimit(1)
                            MonoText(detailLine(g), size: 12).foregroundStyle(palette.inkSoft)
                        }
                        Spacer(minLength: 0)
                        VStack(spacing: 8) {
                            if g.progress >= 1 {
                                Button { Task { await vm.markAchieved(g.id) } } label: {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 17, weight: .regular))
                                        .foregroundStyle(palette.sageDeep)
                                        .frame(width: 40, height: 40)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Mark \(g.label) achieved")
                            }
                            Button { Task { await vm.delete(g.id) } } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(palette.inkSoft.opacity(0.8))
                                    .frame(width: 40, height: 40)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete goal \(g.label)")
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var addButton: some View {
        HStack {
            Spacer()
            PillButton(title: "New goal", kind: .ghost, fullWidth: false, icon: "plus") {
                adding = true
            }
            Spacer()
        }
    }

    private var achievedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Achieved")
            VStack(spacing: 8) {
                ForEach(vm.achieved) { g in
                    GlassCard(style: .done) {
                        HStack {
                            Text("\(typeTitle(g.type)) · \(g.label)")
                                .font(.sans(14, weight: .light))
                            Spacer()
                            MonoText("\(g.target) ✓", size: 12).foregroundStyle(palette.sageDeep)
                        }
                        .padding(.vertical, 12).padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private func detailLine(_ g: GoalsViewModel.GoalRowItem) -> String {
        var s = "\(g.current) → \(g.target)"
        if let d = g.deadline { s += " · by \(Fmt.day(d))" }
        return s
    }

    private func typeTitle(_ type: GoalType) -> String {
        switch type {
        case .bodyWeight:   return "Body weight"
        case .exercisePR:   return "Exercise PR"
        case .consistency:  return "Consistency"
        case .fitnessScore: return "Fitness score"
        }
    }
}

/// The "New goal" sheet — type picker, target, optional exercise & deadline.
private struct GoalFormSheet: View {
    let library: [Exercise]
    let onSubmit: (_ type: GoalType, _ target: Double, _ exerciseId: String?, _ deadline: String?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var type: GoalType = .bodyWeight
    @State private var target = ""
    @State private var exerciseId: String?
    @State private var useDeadline = false
    @State private var deadline = Date()
    @State private var busy = false

    private let types: [GoalType] = [.bodyWeight, .exercisePR, .consistency, .fitnessScore]

    private var hint: String {
        switch type {
        case .bodyWeight:   return "Target weight in kg"
        case .exercisePR:   return "Target weight in kg"
        case .consistency:  return "Workouts per week, for 4 weeks"
        case .fitnessScore: return "Target score, 1–10"
        }
    }

    private func title(_ t: GoalType) -> String {
        switch t {
        case .bodyWeight:   return "Body weight"
        case .exercisePR:   return "Exercise PR"
        case .consistency:  return "Consistency"
        case .fitnessScore: return "Fitness score"
        }
    }

    private var canSubmit: Bool {
        guard parsedTarget != nil else { return false }
        if type == .exercisePR { return exerciseId != nil }
        return true
    }

    private var parsedTarget: Double? {
        Double(target.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SculptBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        typePicker
                        if type == .exercisePR { exercisePicker }
                        field("Target") {
                            TextField(hint, text: $target)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .fieldStyle(palette)
                        }
                        Toggle(isOn: $useDeadline) {
                            Text("Deadline").font(.sans(14, weight: .light))
                        }
                        .tint(palette.blushDeep)
                        if useDeadline {
                            DatePicker("By", selection: $deadline, displayedComponents: .date)
                                .font(.sans(14, weight: .light))
                                .tint(palette.blushDeep)
                        }
                        PillButton(title: busy ? "Saving…" : "Set goal") { submit() }
                            .disabled(busy || !canSubmit)
                    }
                    .padding(20)
                }
            }
            .foregroundStyle(palette.ink)
            .navigationTitle("New goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(palette.inkSoft)
                }
            }
        }
    }

    private var typePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Type")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(types, id: \.self) { t in
                    Button { type = t } label: {
                        Text(title(t))
                            .font(.sans(13, weight: .light))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(type == t ? palette.ink : palette.inkSoft)
                            .background(
                                Capsule().fill(type == t ? palette.blush.opacity(0.4) : palette.surfaceSoft)
                            )
                            .overlay(
                                Capsule().strokeBorder(type == t ? palette.blushDeep : palette.edge)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var exercisePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Exercise")
            Menu {
                ForEach(library) { ex in
                    Button(ex.name) { exerciseId = ex.id }
                }
            } label: {
                HStack {
                    Text(library.first { $0.id == exerciseId }?.name ?? "Pick an exercise")
                        .font(.sans(15, weight: .light))
                        .foregroundStyle(exerciseId == nil ? palette.inkSoft : palette.ink)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12)).foregroundStyle(palette.inkSoft)
                }
                .padding(.vertical, 14).padding(.horizontal, 16)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.edge))
            }
        }
    }

    @ViewBuilder private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) { Eyebrow(label); content() }
    }

    private func submit() {
        guard let value = parsedTarget else { return }
        busy = true
        let deadlineISO: String? = useDeadline ? Self.isoDay(deadline) : nil
        let pickedExercise = type == .exercisePR ? exerciseId : nil
        Task {
            await onSubmit(type, value, pickedExercise, deadlineISO)
            busy = false
            dismiss()
        }
    }

    private static func isoDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: date)
    }
}
