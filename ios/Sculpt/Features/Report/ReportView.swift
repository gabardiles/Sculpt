import SwiftUI

/// The Fitness Report tab — an AI coach's read of your physique photos.
///
/// "Analyze my photos" calls the `fitness-report` Edge Function (Claude vision)
/// which scores the latest progress photos and stores a report; this screen
/// then displays it. The report profile setup feeds the scoring. Reports made
/// on the shared backend (web app) also render here in full.
/// Mirrors src/components/report/ReportClient.tsx.
struct ReportView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.palette) private var palette
    @StateObject private var vm = ReportViewModel()
    @State private var setupOpen = false

    /// Web METRIC_LABEL — friendlier names for the known metric keys.
    private static let metricLabels: [String: String] = [
        "conditioning": "Leanness & conditioning",
        "core": "Core & midsection",
        "upper": "Upper body",
        "lower": "Lower body",
        "arms": "Arms",
        "proportion": "Posture & proportion",
    ]

    var body: some View {
        ZStack {
            SculptBackground()
            ScrollView {
                if vm.loading && vm.latest == nil && vm.profile == nil {
                    ProgressView().tint(palette.blushDeep).padding(.top, 120)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        intro
                        if vm.needsSetup {
                            setupPrompt
                        } else {
                            analyzeCard
                            if let r = vm.latest {
                                report(r)
                            } else {
                                noReportYet
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                }
            }
        }
        .foregroundStyle(palette.ink)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $setupOpen) {
            ReportSetupSheet(
                profile: vm.profile,
                latestWeight: vm.latestWeight
            ) { gender, heightCm, goalNote, weight in
                await vm.saveProfile(gender: gender, heightCm: heightCm,
                                     goalNote: goalNote, weight: weight)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow("Fitness report")
                Text("Your progress").font(.sans(26, weight: .light)).tracking(0.5)
            }
            Spacer()
            if !vm.needsSetup {
                Button { setupOpen = true } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(palette.inkSoft)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit your details")
            }
        }
    }

    private var intro: some View {
        Text("A coach's read of your training photos — scored, honest, kind. Guidance, not medical advice.")
            .font(.sans(14, weight: .light))
            .foregroundStyle(palette.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "Analyze my photos" — runs the fitness-report Edge Function on the latest
    /// progress photos and refreshes with the new score.
    private var analyzeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle().fill(palette.blush.opacity(0.3)).frame(width: 48, height: 48)
                        Image(systemName: "sparkles")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(palette.blushDeep)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.latest == nil ? "Analyze your photos" : "Fresh read")
                            .font(.sans(15, weight: .light))
                        Text("Score your latest progress photos against your goal. Private to you.")
                            .font(.sans(13, weight: .light))
                            .foregroundStyle(palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if let e = vm.generateError {
                    Text(e).font(.sans(13, weight: .light)).foregroundStyle(palette.blushDeep)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PillButton(title: vm.generating
                           ? "Analyzing…"
                           : (vm.latest == nil ? "Analyze my photos" : "Re-analyze my photos")) {
                    Task { await vm.generate() }
                }
                .disabled(vm.generating)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }

    // MARK: - Empty states

    private var setupPrompt: some View {
        GlassCard {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(palette.blush.opacity(0.3)).frame(width: 56, height: 56)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(palette.blushDeep)
                }
                Text("Set up your report").font(.sans(18, weight: .light)).padding(.top, 4)
                Text("A few details so the scoring fits your goal. Takes a moment, edit anytime.")
                    .font(.sans(14, weight: .light))
                    .foregroundStyle(palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                PillButton(title: "Get started") { setupOpen = true }
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    private var noReportYet: some View {
        GlassCard {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(palette.blush.opacity(0.3)).frame(width: 56, height: 56)
                    Image(systemName: "camera")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(palette.blushDeep)
                }
                Text("No report yet").font(.sans(18, weight: .light)).padding(.top, 4)
                Text("Add a progress photo, then tap Analyze — your coach reads it and scores your training development here.")
                    .font(.sans(14, weight: .light))
                    .foregroundStyle(palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    // MARK: - The report

    @ViewBuilder private func report(_ r: FitnessReport) -> some View {
        if !r.assessable {
            unreadableCard(r)
        } else {
            overallCard(r)
            breakdown(r)
            if !r.strengths.isEmpty { strengths(r) }
            if !r.focusAreas.isEmpty || r.nextLevelAdvice != nil { whereToPush(r) }
        }
    }

    private func unreadableCard(_ r: FitnessReport) -> some View {
        GlassCard {
            VStack(spacing: 8) {
                Text("Couldn't read that one").font(.sans(18, weight: .light))
                Text(r.summary?.isEmpty == false
                     ? r.summary!
                     : "Add a clear, well-lit photo showing your full physique and try again.")
                    .font(.sans(14, weight: .light))
                    .foregroundStyle(palette.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    private func overallCard(_ r: FitnessReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 20) {
                    ProgressRing(progress: r.overallScore / 10, size: 72,
                                 label: String(format: "%.1f", r.overallScore))
                    VStack(alignment: .leading, spacing: 2) {
                        Eyebrow(r.level ?? "Your level")
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.1f", r.overallScore))
                                .font(.sans(28, weight: .light)).tracking(0.5)
                            Text("/10").font(.sans(16, weight: .light))
                                .foregroundStyle(palette.inkSoft)
                        }
                        if let next = r.nextLevel {
                            MonoText("Next: \(next)", size: 11)
                                .tracking(1.2)
                                .foregroundStyle(palette.inkSoft)
                        }
                    }
                    Spacer(minLength: 0)
                }
                if let summary = r.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.sans(14, weight: .light))
                        .foregroundStyle(palette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                MonoText("\(Fmt.day(r.createdAt)) · \(r.photoCount) \(r.photoCount == 1 ? "photo" : "photos")", size: 11)
                    .tracking(1.2)
                    .foregroundStyle(palette.inkSoft.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private func breakdown(_ r: FitnessReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("The breakdown")
            GlassCard {
                VStack(spacing: 0) {
                    ForEach(Array(r.metrics.enumerated()), id: \.element.id) { index, m in
                        if index > 0 {
                            Divider().overlay(palette.edge)
                        }
                        DotScale(
                            label: Self.metricLabels[m.key] ?? m.label,
                            score: m.score,
                            comment: m.comment
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
            }
        }
    }

    private func strengths(_ r: FitnessReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Strengths")
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(r.strengths.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(palette.sageDeep)
                                .padding(.top, 2)
                            Text(s).font(.sans(14, weight: .light))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
    }

    private func whereToPush(_ r: FitnessReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Where to push")
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(r.focusAreas.enumerated()), id: \.offset) { _, s in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(palette.blushDeep)
                                .padding(.top, 2)
                            Text(s).font(.sans(14, weight: .light))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let advice = r.nextLevelAdvice, !advice.isEmpty {
                        if !r.focusAreas.isEmpty {
                            Divider().overlay(palette.edge).padding(.vertical, 2)
                        }
                        (
                            Text("To reach \(r.nextLevel ?? "the next level"): ")
                                .font(.sans(14, weight: .medium))
                                .foregroundColor(palette.ink)
                            + Text(advice)
                                .font(.sans(14, weight: .light))
                                .foregroundColor(palette.inkSoft)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
        }
    }

}

// MARK: - DotScale

/// A 0–10 score as a row of ten segments: segments up to the score fill with
/// the accent, the score's own segment is ringed, the value sits at the end.
/// Mirrors src/components/report/DotScale.tsx.
struct DotScale: View {
    let label: String
    let score: Double
    var comment: String?
    @Environment(\.palette) private var palette

    private var filled: Int { Int(score.rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label).font(.sans(14)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                (
                    Text(String(format: "%.1f", score)).font(.mono(12))
                        .foregroundColor(palette.inkSoft)
                    + Text("/10").font(.mono(12))
                        .foregroundColor(palette.inkSoft.opacity(0.6))
                )
            }
            HStack(spacing: 3) {
                ForEach(1...10, id: \.self) { n in
                    Capsule()
                        .fill(n <= filled ? palette.blushDeep : palette.ink.opacity(0.12))
                        .frame(height: 8)
                        .overlay(
                            Capsule().strokeBorder(
                                n == filled ? palette.blushDeep.opacity(0.4) : .clear,
                                lineWidth: 2
                            )
                        )
                }
            }
            if let comment, !comment.isEmpty {
                Text(comment)
                    .font(.sans(12, weight: .light))
                    .foregroundStyle(palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Setup sheet

/// "Your details" — goal aesthetic (gender), height, optional weight & focus
/// note. Saves via saveFitnessProfile; the weight is shared with the diary.
private struct ReportSetupSheet: View {
    let profile: Profile?
    let latestWeight: Double?
    let onSave: (_ gender: Gender, _ heightCm: Double?, _ goalNote: String?, _ weight: Double?) async -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var gender: Gender?
    @State private var height = ""
    @State private var weight = ""
    @State private var goalNote = ""
    @State private var busy = false

    init(profile: Profile?,
         latestWeight: Double?,
         onSave: @escaping (_ gender: Gender, _ heightCm: Double?, _ goalNote: String?, _ weight: Double?) async -> Void) {
        self.profile = profile
        self.latestWeight = latestWeight
        self.onSave = onSave
        _gender = State(initialValue: profile?.gender)
        _height = State(initialValue: profile?.heightCm.map { numString($0) } ?? "")
        _weight = State(initialValue: latestWeight.map { numString($0) } ?? "")
        _goalNote = State(initialValue: profile?.goalNote ?? "")
    }

    private var canSave: Bool { gender != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                SculptBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        genderPicker
                        HStack(spacing: 12) {
                            field("Height (cm)") {
                                TextField("175", text: $height)
                                    .keyboardType(.decimalPad)
                                    .fieldStyle(palette)
                            }
                            field("Weight (kg)") {
                                TextField("70", text: $weight)
                                    .keyboardType(.decimalPad)
                                    .fieldStyle(palette)
                            }
                        }
                        field("Your dream focus (optional)") {
                            TextField("e.g. a visible six-pack", text: $goalNote)
                                .fieldStyle(palette)
                        }
                        PillButton(title: busy ? "Saving…" : "Save") { submit() }
                            .disabled(busy || !canSave)
                        Text("Private to you. Weight is shared with your weight diary.")
                            .font(.sans(12, weight: .light))
                            .foregroundStyle(palette.inkSoft)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                }
            }
            .foregroundStyle(palette.ink)
            .navigationTitle("Your details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(palette.inkSoft)
                }
            }
        }
    }

    private var genderPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow("Your goal aesthetic")
            VStack(spacing: 8) {
                aestheticRow(.female, "Lean & toned (women's)")
                aestheticRow(.male, "Athletic & strong (men's)")
                aestheticRow(.unspecified, "Balanced athletic")
            }
        }
    }

    private func aestheticRow(_ g: Gender, _ title: String) -> some View {
        Button { gender = g } label: {
            HStack {
                Text(title).font(.sans(15, weight: .light))
                Spacer()
                if gender == g {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.blushDeep)
                }
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
            .foregroundStyle(gender == g ? palette.ink : palette.inkSoft)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(gender == g ? palette.blush.opacity(0.4) : palette.surfaceSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(gender == g ? palette.blushDeep : palette.edge)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private func field<C: View>(_ label: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) { Eyebrow(label); content() }
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func submit() {
        guard let gender else { return }
        busy = true
        let h = Double(height.replacingOccurrences(of: ",", with: "."))
        let w = Double(weight.replacingOccurrences(of: ",", with: "."))
        let note = goalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await onSave(gender, h, note.isEmpty ? nil : note, w)
            busy = false
            dismiss()
        }
    }
}

/// Formats a Double for a text field — trims a trailing ".0".
private func numString(_ value: Double) -> String {
    value == value.rounded() ? String(Int(value)) : String(value)
}
