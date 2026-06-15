import SwiftUI

// MARK: - Today card

/// Compact Green Days card for the Today screen — today's verdict, the live
/// streak and a tap-through to the full calendar.
struct GreenDaysCard: View {
    @ObservedObject var vm: ActivityViewModel
    @Environment(\.palette) private var palette

    var body: some View {
        NavigationLink { GreenDaysView(vm: vm) } label: {
            GlassCard(style: vm.todayState == .none ? .normal : .done) {
                HStack(spacing: 16) {
                    DayDot(state: vm.todayState, size: 52)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").foregroundStyle(streakTint)
                            MonoText("\(vm.summary.currentStreak)", size: 22, weight: .medium)
                            Text(vm.summary.currentStreak == 1 ? "day streak" : "day streak")
                                .font(.sans(13)).foregroundStyle(palette.inkSoft)
                        }
                        Text(subtitle).font(.sans(13, weight: .light)).foregroundStyle(palette.inkSoft)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        MonoText("\(vm.summary.totalPoints)", size: 16, weight: .medium)
                        Text(vm.summary.levelName).font(.sans(11)).foregroundStyle(palette.inkSoft)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(palette.inkSoft)
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }

    private var streakTint: Color { vm.summary.currentStreak > 0 ? palette.blushDeep : palette.inkSoft.opacity(0.4) }

    private var subtitle: String {
        switch vm.todayState {
        case .gold: return "Gold day — trained and \(Fmt.steps(vm.stepGoal)) steps ✦"
        case .green: return vm.workoutDoneToday ? "Green — trained today" : "Green — \(Fmt.steps(vm.todaySteps)) steps"
        case .none:
            if !vm.healthConnected { return "Train or walk to earn today" }
            let left = max(0, vm.stepGoal - vm.todaySteps)
            return left > 0 ? "\(Fmt.steps(left)) steps to green" : "Train or walk to earn today"
        }
    }
}

// MARK: - Full screen

/// Standalone entry (You tab) that owns its own view-model.
struct GreenDaysScreen: View {
    @StateObject private var vm = ActivityViewModel()
    var body: some View { GreenDaysView(vm: vm) }
}

struct GreenDaysView: View {
    @ObservedObject var vm: ActivityViewModel
    @Environment(\.palette) private var palette
    @State private var showGoal = false

    var body: some View {
        Screen(title: "Green Days") {
            hero
            todayRing
            stats
            HeatGrid(vm: vm)
            MilestoneBadges(longest: vm.summary.longestStreak)
            if vm.hasFriends { leaderboard }
            goalRow
            if !vm.healthConnected { connectHealth }
        }
        .task { await vm.load() }
        .refreshable { await vm.refresh() }
    }

    private var hero: some View {
        GlassCard(style: .spotlight) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").font(.system(size: 28))
                        .foregroundStyle(vm.summary.currentStreak > 0 ? palette.blushDeep : palette.inkSoft.opacity(0.4))
                    MonoText("\(vm.summary.currentStreak)", size: 48, weight: .light)
                }
                Text(vm.summary.currentStreak == 1 ? "day streak" : "day streak")
                    .font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
                // Level progress
                VStack(spacing: 6) {
                    HStack {
                        Text(vm.summary.levelName).font(.sans(13, weight: .medium))
                        Spacer()
                        if let next = vm.summary.nextLevelName {
                            MonoText("\(vm.summary.pointsIntoLevel)/\(vm.summary.pointsForLevelSpan) → \(next)", size: 11)
                                .foregroundStyle(palette.inkSoft)
                        } else {
                            Text("Top tier").font(.sans(11)).foregroundStyle(palette.inkSoft)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(palette.edge)
                            Capsule().fill(palette.blushDeep)
                                .frame(width: max(6, geo.size.width * vm.summary.levelProgress))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
    }

    private var todayRing: some View {
        GlassCard {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: vm.stepProgress, size: 70, lineWidth: 7,
                                 label: vm.healthConnected ? "\(Int(vm.stepProgress * 100))%" : "—")
                }
                VStack(alignment: .leading, spacing: 6) {
                    checkRow(done: vm.workoutDoneToday, label: "Train", detail: vm.workoutDoneToday ? "done" : "not yet")
                    checkRow(done: vm.todaySteps >= vm.stepGoal && vm.healthConnected,
                             label: "\(Fmt.steps(vm.stepGoal)) steps",
                             detail: vm.healthConnected ? "\(Fmt.steps(vm.todaySteps)) today" : "connect Health")
                }
                Spacer()
                DayDot(state: vm.todayState, size: 44)
            }
            .padding(18)
        }
    }

    private func checkRow(done: Bool, label: String, detail: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? palette.sageDeep : palette.inkSoft.opacity(0.4))
            Text(label).font(.sans(15, weight: .light))
            Spacer(minLength: 8)
            Text(detail).font(.sans(12)).foregroundStyle(palette.inkSoft)
        }
    }

    private var stats: some View {
        GlassCard {
            HStack {
                stat("\(vm.summary.currentStreak)", "current")
                Spacer(); stat("\(vm.summary.longestStreak)", "best")
                Spacer(); stat("\(vm.summary.greenDays)", "green")
                Spacer(); stat("\(vm.summary.goldDays)", "gold")
            }
            .padding(16)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            MonoText(value, size: 22, weight: .light)
            Text(label).font(.sans(11)).foregroundStyle(palette.inkSoft)
        }
    }

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Friends · last 30 days")
            GlassCard {
                VStack(spacing: 0) {
                    ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { i, row in
                        if i > 0 { Divider().background(palette.edge) }
                        HStack(spacing: 12) {
                            MonoText("\(i + 1)", size: 14).foregroundStyle(palette.inkSoft).frame(width: 22)
                            DayDot(state: row.state, size: 20)
                            Text(row.name).font(.sans(15, weight: row.isMe ? .medium : .light))
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill").font(.system(size: 11)).foregroundStyle(palette.blushDeep)
                                MonoText("\(row.streak)", size: 14)
                            }
                            MonoText("\(row.points)", size: 12).foregroundStyle(palette.inkSoft).frame(width: 48, alignment: .trailing)
                        }
                        .padding(.vertical, 12).padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private var goalRow: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily step goal").font(.sans(15, weight: .light))
                    MonoText("\(Fmt.steps(vm.stepGoal)) steps", size: 12).foregroundStyle(palette.inkSoft)
                }
                Spacer()
                Stepper("", value: Binding(
                    get: { vm.stepGoal },
                    set: { newValue in Task { await vm.setStepGoal(newValue) } }
                ), in: 1_000...40_000, step: 1_000)
                .labelsHidden()
            }
            .padding(16)
        }
    }

    private var connectHealth: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Connect Apple Health").font(.sans(16, weight: .light))
                Text("Let Sculpt read your daily steps to earn green days on rest days too.")
                    .font(.sans(13, weight: .light)).foregroundStyle(palette.inkSoft)
                PillButton(title: "Connect Health", icon: "heart.fill") {
                    Task {
                        _ = await HealthKitManager.shared.requestAuthorization()
                        await vm.load()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
        }
    }
}

// MARK: - Pieces

/// A single day's verdict as a filled dot. Gold gets a subtle ring + star.
struct DayDot: View {
    let state: ActivityDay.State
    var size: CGFloat = 28
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Circle().fill(fill)
            Circle().strokeBorder(stroke, lineWidth: state == .gold ? 2 : 1)
            if state == .gold {
                Image(systemName: "star.fill").font(.system(size: size * 0.34))
                    .foregroundStyle(palette.onAccent)
            } else if state == .green {
                Image(systemName: "checkmark").font(.system(size: size * 0.36, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }

    private var fill: Color {
        switch state {
        case .gold: return palette.blush
        case .green: return palette.sageDeep
        case .none: return palette.edge.opacity(0.6)
        }
    }
    private var stroke: Color {
        switch state {
        case .gold: return palette.blushDeep
        case .green: return palette.sageDeep
        case .none: return palette.edge
        }
    }
}

/// GitHub-style heat grid: 12 weeks of days, columns are weeks, rows weekdays.
struct HeatGrid: View {
    @ObservedObject var vm: ActivityViewModel
    @Environment(\.palette) private var palette
    private let weeks = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Last \(weeks) weeks")
            GlassCard {
                HStack(alignment: .top, spacing: 5) {
                    ForEach(columns.indices, id: \.self) { c in
                        VStack(spacing: 5) {
                            ForEach(0..<7, id: \.self) { r in
                                cell(columns[c][r])
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(16)
            }
        }
    }

    @ViewBuilder private func cell(_ date: Date?) -> some View {
        let side: CGFloat = 13
        if let date, date <= Date() {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color(for: date))
                .frame(width: side, height: side)
        } else {
            Color.clear.frame(width: side, height: side)
        }
    }

    private func color(for date: Date) -> Color {
        let key = GreenDays.iso(date)
        let state = key == Fmt.todayISO() ? vm.todayState : (stateByDate[key] ?? .none)
        switch state {
        case .gold: return palette.blush
        case .green: return palette.sageDeep
        case .none: return palette.edge.opacity(0.55)
        }
    }

    private var stateByDate: [String: ActivityDay.State] {
        Dictionary(vm.days.map { ($0.date, $0.state) }, uniquingKeysWith: { a, _ in a })
    }

    /// Columns of 7 days, the last column ending on (or spanning) today.
    private var columns: [[Date?]] {
        let cal = GreenDays.calendarUTC
        let today = cal.startOfDay(for: Date())
        // Monday-based weekday index (0 = Mon … 6 = Sun).
        let wd = (cal.component(.weekday, from: today) + 5) % 7
        guard let gridEnd = cal.date(byAdding: .day, value: 6 - wd, to: today) else { return [] }
        var grid: [[Date?]] = []
        for w in stride(from: weeks - 1, through: 0, by: -1) {
            var col: [Date?] = []
            for d in 0..<7 {
                let offset = -(w * 7) + d - 6
                col.append(cal.date(byAdding: .day, value: offset, to: gridEnd))
            }
            grid.append(col)
        }
        return grid
    }
}

/// Streak milestone badges — lit once the longest streak reaches them.
struct MilestoneBadges: View {
    let longest: Int
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Milestones")
            GlassCard {
                HStack {
                    ForEach(GreenDays.milestones, id: \.self) { m in
                        let earned = longest >= m
                        VStack(spacing: 5) {
                            ZStack {
                                Circle().fill(earned ? palette.blush.opacity(0.5) : palette.edge.opacity(0.5))
                                Image(systemName: earned ? "flame.fill" : "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(earned ? palette.blushDeep : palette.inkSoft.opacity(0.5))
                            }
                            .frame(width: 38, height: 38)
                            MonoText("\(m)", size: 12).foregroundStyle(earned ? palette.ink : palette.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
            }
        }
    }
}
