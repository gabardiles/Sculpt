import SwiftUI

/// The weight diary — log today's body weight, see the 7-day average headline,
/// an 8-week trend Sparkline, and the recent entries list.
/// Mirrors src/app/(app)/weight/page.tsx.
struct WeightView: View {
    @StateObject private var vm = WeightViewModel()
    @Environment(\.palette) private var palette

    @State private var input = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Screen {
            Eyebrow("Weight diary")
            Text("Body weight").font(.sans(28, weight: .light)).tracking(1)

            heroCard
            logCard

            if vm.recent.isEmpty {
                Text("Nothing logged yet — your first entry starts the trend.")
                    .font(.sans(14, weight: .light))
                    .foregroundStyle(palette.inkSoft)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
            } else {
                recentSection
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
    }

    // MARK: hero

    private var heroCard: some View {
        GlassCard(style: .spotlight) {
            VStack(spacing: 12) {
                Eyebrow("7-day average")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    MonoText(vm.weeklyAvg != nil ? Fmt.kg(vm.weeklyAvg) : "—", size: 44, weight: .light)
                    Text("kg").font(.sans(18, weight: .light)).foregroundStyle(palette.inkSoft)
                }
                if vm.weeklyTrend.count >= 2 {
                    Sparkline(values: vm.weeklyTrend, height: 48)
                        .padding(.horizontal, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
    }

    // MARK: log

    private var logCard: some View {
        GlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    TextField(vm.todayPlaceholder, text: $input)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.mono(20, weight: .light))
                        .focused($fieldFocused)
                        .fieldStyle(palette)
                    PillButton(title: vm.todayRow != nil ? "Update" : "Log",
                               fullWidth: false) {
                        Task { await log() }
                    }
                    .fixedSize()
                    .disabled(parsed == nil || vm.saving)
                }
                if let row = vm.todayRow {
                    HStack(spacing: 4) {
                        Text("Logged today:").font(.sans(12, weight: .light))
                        MonoText("\(Fmt.kg(row.weightKg)) kg", size: 12)
                    }
                    .foregroundStyle(palette.inkSoft)
                }
            }
            .padding(16)
        }
    }

    // MARK: recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Recent")
            VStack(spacing: 6) {
                ForEach(vm.recent) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(Fmt.day(row.date))
                            .font(.sans(14, weight: .light))
                            .foregroundStyle(palette.inkSoft)
                        Spacer()
                        MonoText("\(Fmt.kg(row.weightKg)) kg", size: 14)
                    }
                }
            }
        }
    }

    // MARK: actions

    /// Accepts both comma and dot decimals.
    private var parsed: Double? {
        let normalized = input.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalized.isEmpty, let v = Double(normalized), v > 0 else { return nil }
        return v
    }

    private func log() async {
        guard let weight = parsed else { return }
        if await vm.log(weight: weight) {
            input = ""
            fieldFocused = false
        }
    }
}

@MainActor
final class WeightViewModel: ObservableObject {
    @Published var rows: [BodyWeight] = []   // ascending by date
    @Published var saving = false

    private let dayMs: TimeInterval = 86_400

    /// The 7-day average is the headline — daily fluctuation discourages.
    var weeklyAvg: Double? {
        let cutoff = isoDay(daysAgo: 7)
        let lastWeek = rows.filter { $0.date >= cutoff }
        guard !lastWeek.isEmpty else { return nil }
        return lastWeek.reduce(0) { $0 + $1.weightKg } / Double(lastWeek.count)
    }

    /// Weekly averages for the last 8 weeks (oldest → newest), for the Sparkline.
    var weeklyTrend: [Double] {
        var out: [Double] = []
        let now = Date()
        for w in stride(from: 7, through: 0, by: -1) {
            let end = now.addingTimeInterval(-Double(w) * 7 * dayMs)
            let start = end.addingTimeInterval(-7 * dayMs)
            let inWeek = rows.filter { r in
                guard let t = Fmt.parseISO(r.date) else { return false }
                return t > start && t <= end
            }
            if !inWeek.isEmpty {
                out.append(inWeek.reduce(0) { $0 + $1.weightKg } / Double(inWeek.count))
            }
        }
        return out
    }

    /// Most recent 7 entries, newest first.
    var recent: [BodyWeight] {
        Array(rows.reversed().prefix(7))
    }

    var todayRow: BodyWeight? {
        rows.first { $0.date == Fmt.todayISO() }
    }

    var todayPlaceholder: String {
        if let row = todayRow { return Fmt.kg(row.weightKg) }
        return "62,4"
    }

    func load() async {
        guard let userId = await Repository.shared.currentUserId() else { return }
        if let fetched = try? await Repository.shared.getBodyWeights(userId) {
            rows = fetched
        }
    }

    /// Logs (or updates) today's weight. Returns true on success.
    func log(weight: Double) async -> Bool {
        guard let userId = await Repository.shared.currentUserId() else { return false }
        saving = true
        defer { saving = false }
        do {
            try await Repository.shared.logBodyWeight(userId: userId, weight: weight, date: Fmt.todayISO())
            await load()
            return true
        } catch {
            return false
        }
    }

    private func isoDay(daysAgo days: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: Date().addingTimeInterval(-Double(days) * dayMs))
    }
}
