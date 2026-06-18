import SwiftUI

/// The "Start new training" wizard. A few quick choices → Claude builds a
/// sport/goal-specific strength & conditioning program → preview → "Start Day 1".
/// Committing archives the current program and makes this one active; with no
/// logs yet, the cycle engine derives it straight to Week 1 / Day 1.
struct StartOverView: View {
    let userId: String
    /// Called after a successful commit so the app can reload Today/Program.
    var onStarted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private enum Step: Int { case goal, route, logistics, preview }
    @State private var step: Step = .goal

    @State private var goal: String?
    @State private var route: String?
    @State private var sportOther = ""
    @State private var days = 4
    @State private var minutes = 60
    @State private var equipment = "Full gym"
    @State private var level = "Some"

    @State private var busy = false
    @State private var plan: GenProgram?
    @State private var error: String?

    private let goals = ["Build muscle", "Lose fat", "Get stronger", "Sport performance", "General health"]
    private let gymRoutes = ["Sculpt — Glutes & tone", "Strong & Built", "Hypertrophy", "Powerbuilding", "CrossFit", "AloFit"]
    private let sports = ["Boxing", "Padel", "BJJ", "Tennis", "Football", "Running", "Other"]
    private let equipmentOptions = ["Full gym", "Home", "Minimal"]
    private let levels = ["New", "Some", "Experienced"]

    var body: some View {
        ZStack {
            SculptBackground()
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch step {
                        case .goal: goalStep
                        case .route: routeStep
                        case .logistics: logisticsStep
                        case .preview: previewStep
                        }
                        if let error {
                            Text(error).font(.sans(13)).foregroundStyle(palette.blushDeep)
                        }
                    }
                    .padding(24)
                }
            }
        }
    }

    // MARK: - Header (progress + back/cancel)

    private var header: some View {
        HStack {
            if step == .goal {
                Button("Cancel") { dismiss() }
            } else {
                Button { back() } label: { Label("Back", systemImage: "chevron.left").labelStyle(.titleAndIcon) }
            }
            Spacer()
            Text("Step \(step.rawValue + 1) of 4")
                .font(.sans(12, weight: .light)).foregroundStyle(palette.inkSoft)
        }
        .font(.sans(14, weight: .light))
        .foregroundStyle(palette.ink)
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 4)
    }

    // MARK: - Steps

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("What are you training for?", "Pick the one that fits best — we'll shape everything around it.")
            VStack(spacing: 8) {
                ForEach(goals, id: \.self) { g in
                    choice(g, selected: goal == g) { goal = g }
                }
            }
            PillButton(title: "Continue") { step = .route }
                .disabled(goal == nil)
        }
    }

    private var routeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepTitle("Pick your route", "Sculpt builds the gym work. For a sport, that's the S&C that makes you better at it.")
            Eyebrow("Gym")
            flow(gymRoutes)
            Eyebrow("Sport").padding(.top, 6)
            flow(sports)
            if route == "Other" {
                TextField("Which sport?", text: $sportOther).fieldStyle(palette).padding(.top, 4)
            }
            PillButton(title: "Continue") { step = .logistics }
                .disabled(route == nil || (route == "Other" && sportOther.trimmingCharacters(in: .whitespaces).isEmpty))
        }
    }

    private var logisticsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepTitle("How do you train?", "We'll fit the plan to your week and your gear.")
            picker("Days per week", options: (2...6).map(String.init), selected: String(days)) { days = Int($0) ?? 4 }
            picker("Session length", options: ["45", "60", "75"].map { "\($0) min" }, selected: "\(minutes) min") {
                minutes = Int($0.replacingOccurrences(of: " min", with: "")) ?? 60
            }
            picker("Equipment", options: equipmentOptions, selected: equipment) { equipment = $0 }
            picker("Experience", options: levels, selected: level) { level = $0 }
            PillButton(title: busy ? "Building your program…" : "Build my program") {
                Task { await generate() }
            }
            .disabled(busy)
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let plan {
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Your new program")
                    Text(plan.name).font(.sans(24, weight: .light)).foregroundStyle(palette.ink)
                    if let s = plan.summary, !s.isEmpty {
                        Text(s).font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
                    }
                }
                ForEach(plan.days) { day in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(day.name).font(.sans(16, weight: .regular)).foregroundStyle(palette.ink)
                                Spacer()
                                if let f = day.focus, !f.isEmpty {
                                    Text(f).font(.sans(12, weight: .light)).foregroundStyle(palette.inkSoft)
                                }
                            }
                            ForEach(day.exercises) { ex in
                                HStack(alignment: .firstTextBaseline) {
                                    Text(ex.name).font(.sans(14, weight: .light)).foregroundStyle(palette.ink)
                                    Spacer()
                                    Text("\(ex.sets ?? 3)×\(ex.reps ?? "")")
                                        .font(.mono(13, weight: .medium)).foregroundStyle(palette.inkSoft)
                                }
                            }
                        }
                        .padding(16)
                    }
                }
                HStack(spacing: 10) {
                    Button("Rebuild") { Task { await generate() } }
                        .font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
                        .disabled(busy)
                    PillButton(title: busy ? "Starting…" : "Start Day 1") { Task { await start() } }
                        .disabled(busy)
                }
            }
        }
    }

    // MARK: - Building blocks

    private func stepTitle(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.sans(22, weight: .light)).foregroundStyle(palette.ink)
            Text(sub).font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
        }
    }

    private func choice(_ label: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label).font(.sans(15, weight: .light))
                Spacer()
                if selected { Image(systemName: "checkmark").foregroundStyle(palette.blushDeep) }
            }
            .padding(.vertical, 12).padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selected ? palette.blush.opacity(0.3) : palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.edge))
        }
        .buttonStyle(.plain).foregroundStyle(palette.ink)
    }

    /// A wrapping set of small selectable pills (for routes/sports).
    private func flow(_ options: [String]) -> some View {
        let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(options, id: \.self) { o in
                pill(o, selected: route == o) { route = o }
            }
        }
    }

    private func pill(_ label: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.sans(13, weight: .light)).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? palette.blush.opacity(0.35) : palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(palette.edge))
        }
        .buttonStyle(.plain).foregroundStyle(palette.ink)
    }

    /// A labelled horizontal segmented picker built from pills.
    private func picker(_ label: String, options: [String], selected: String, _ pick: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(label)
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { o in
                    pickPill(o, selected: o == selected) { pick(o) }
                }
            }
        }
    }

    private func pickPill(_ label: String, selected: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.sans(13, weight: .light))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? palette.blush.opacity(0.35) : palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(palette.edge))
        }
        .buttonStyle(.plain).foregroundStyle(palette.ink)
    }

    // MARK: - Logic

    private var brief: Brief {
        let isOther = route == "Other"
        let sportRoute = sports.contains(route ?? "")
        let sport: String? = isOther ? sportOther.trimmingCharacters(in: .whitespaces)
            : (sportRoute ? route : nil)
        let routeLabel = isOther ? (sport?.isEmpty == false ? sport : "Sport") : route
        return Brief(goal: goal, route: routeLabel, sport: sport,
                     daysPerWeek: days, sessionMinutes: minutes,
                     equipment: equipment, level: level)
    }

    private func back() {
        error = nil
        switch step {
        case .goal: break
        case .route: step = .goal
        case .logistics: step = .route
        case .preview: step = .logistics
        }
    }

    private func generate() async {
        busy = true; error = nil
        let result = await Repository.shared.generateProgram(brief: brief)
        if let result, !result.days.isEmpty {
            plan = result; step = .preview
        } else {
            error = "Couldn't build a program just now. Check your connection and try again."
        }
        busy = false
    }

    private func start() async {
        guard let plan else { return }
        busy = true; error = nil
        let id = await Repository.shared.commitProgram(program: plan, brief: brief)
        busy = false
        if id != nil {
            onStarted()
            dismiss()
        } else {
            error = "Couldn't start the program. Try again."
        }
    }
}
