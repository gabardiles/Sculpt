import SwiftUI

/// The Today tab — greeting, the next session hero, the week's day list,
/// this-week numbers, the report shortcut, friends preview and goals rings.
/// Mirrors src/app/(app)/page.tsx.
struct DashboardView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.palette) private var palette
    @StateObject private var vm = DashboardViewModel()
    @StateObject private var activity = ActivityViewModel()
    /// The day being trained — presented as a full-screen takeover (no tab bar).
    @State private var workoutDay: DayWithExercises?

    var body: some View {
        ZStack {
            SculptBackground()
            ScrollView {
                if vm.loading && vm.program == nil {
                    ProgressView().tint(palette.blushDeep).padding(.top, 120)
                } else {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        nextUp
                        GreenDaysCard(vm: activity)
                        weekList
                        if vm.sessionsThisWeek > 0 { thisWeek }
                        if let r = vm.report, r.assessable { reportShortcut(r) }
                        if !vm.goalRows.isEmpty { goals }
                        if let q = vm.quote { quote(q) }
                    }
                    .padding(20).padding(.bottom, 90)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.load() }
        .task { await activity.load() }
        .refreshable { await vm.load(); await activity.refresh() }
        // A workout is a focused "now" mode — take over the whole screen (no tab
        // bar), then refresh Today so the finished day flips to done on dismiss.
        .fullScreenCover(item: $workoutDay, onDismiss: {
            Task { await vm.load(); await activity.refresh() }
        }) { day in
            WorkoutView(day: day, phase: vm.phase, program: vm.program)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Fmt.greeting(vm.profile?.name)).font(.sans(26, weight: .light)).tracking(0.5)
            MonoText(vm.headerLine, size: 12).tracking(1.4).foregroundStyle(palette.inkSoft)
        }
    }

    @ViewBuilder private var nextUp: some View {
        if let day = vm.nextDay {
            Button { workoutDay = day } label: {
                GlassCard(style: .spotlight) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow("Next up · Day \(day.day.dayIndex)")
                        HStack(alignment: .center) {
                            Text(day.day.name).font(.sans(30, weight: .light)).tracking(0.5)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(palette.onAccent)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(palette.blush))
                        }
                        MonoText("\(day.exercises.count) exercises · \(RepTargets.repTarget(.strength, .squat, vm.phase)) reps · 3 sets", size: 12)
                            .foregroundStyle(palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }
            }
            .buttonStyle(.plain)
        } else {
            GlassCard {
                VStack(spacing: 6) {
                    Text("Week complete").font(.sans(18, weight: .light))
                    Text("Everything done. Rest is part of the work.")
                        .font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
                }
                .frame(maxWidth: .infinity).padding(24)
            }
        }
    }

    @ViewBuilder private var weekList: some View {
        if !vm.weekDays.isEmpty {
            VStack(spacing: 8) {
                ForEach(vm.weekDays) { d in
                    Button {
                        workoutDay = vm.program?.days.first(where: { $0.day.id == d.id })
                    } label: {
                        GlassCard(style: d.done ? .done : .normal) {
                            HStack {
                                Image(systemName: d.done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(d.done ? palette.sageDeep : palette.inkSoft.opacity(0.5))
                                Text(d.name).font(.sans(16, weight: .light))
                                Spacer()
                                if !d.done {
                                    Image(systemName: "chevron.right").font(.system(size: 13))
                                        .foregroundStyle(palette.inkSoft)
                                }
                            }
                            .padding(.vertical, 14).padding(.horizontal, 18)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var thisWeek: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("This week")
            GlassCard {
                VStack(spacing: 12) {
                    HStack {
                        stat("\(vm.sessionsThisWeek)", "sessions")
                        Spacer()
                        stat(vm.weekVolume >= 1000 ? "\(Fmt.kg(vm.weekVolume / 1000))t" : "\(Int(vm.weekVolume))",
                             vm.weekVolume < 1000 ? "volume kg" : "volume")
                        Spacer()
                        stat(vm.avgFeel != nil ? String(format: "%.1f", vm.avgFeel!) : "—", "avg feel")
                    }
                    if vm.volumeSpark.count >= 2 {
                        Sparkline(values: vm.volumeSpark)
                        MonoText("volume · last \(vm.volumeSpark.count) sessions", size: 11)
                            .foregroundStyle(palette.inkSoft)
                    }
                }
                .padding(16)
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            MonoText(value, size: 24, weight: .light)
            Text(label).font(.sans(11)).foregroundStyle(palette.inkSoft)
        }
    }

    private func reportShortcut(_ r: FitnessReport) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Fitness report")
            NavigationLink { ReportView() } label: {
                GlassCard {
                    HStack(spacing: 16) {
                        ProgressRing(progress: r.overallScore / 10, size: 56,
                                     label: String(format: "%.1f", r.overallScore))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.level ?? "Your level").font(.sans(16, weight: .light))
                            MonoText("\(String(format: "%.1f", r.overallScore))/10 · \(Fmt.day(r.createdAt))", size: 12)
                                .foregroundStyle(palette.inkSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(palette.inkSoft)
                    }
                    .padding(16)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var goals: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Goals")
            GlassCard {
                HStack {
                    ForEach(vm.goalRows) { g in
                        VStack(spacing: 6) {
                            ProgressRing(progress: g.progress, size: 56,
                                         label: "\(Int(g.progress * 100))%")
                            Text(g.label).font(.sans(11)).foregroundStyle(palette.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
            }
        }
    }

    private func quote(_ q: Quote) -> some View {
        VStack(spacing: 4) {
            Text("“\(q.text)”").font(.sans(14, weight: .light)).italic()
                .multilineTextAlignment(.center).foregroundStyle(palette.inkSoft)
            if let a = q.author {
                Text("— \(a)").font(.sans(12)).foregroundStyle(palette.inkSoft.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity).padding(.top, 12)
    }
}
