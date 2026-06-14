import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

/// Apple Health integration — writes each completed session as a strength
/// workout and mirrors body-weight entries into Health (and can read the
/// latest weight back). Entirely optional and best-effort: if the member
/// declines, or HealthKit is unavailable, every call simply no-ops.
///
/// Xcode setup: add the **HealthKit** capability to the target (project.yml
/// already lists the entitlement) — the Info.plist usage strings are in place.
@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()

    #if canImport(HealthKit)
    private let store = HKHealthStore()
    private var bodyMass: HKQuantityType { HKQuantityType(.bodyMass) }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Whether the member opted into Health sync (default off — ask once).
    var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "sculpt-health") }
        set { UserDefaults.standard.set(newValue, forKey: "sculpt-health") }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let share: Set<HKSampleType> = [HKWorkoutType.workoutType(), bodyMass]
        let read: Set<HKObjectType> = [bodyMass]
        do {
            try await store.requestAuthorization(toShare: share, read: read)
            enabled = true
            return true
        } catch { return false }
    }

    /// Log a completed strength session to Health.
    func saveStrengthWorkout(start: Date, end: Date) async {
        guard enabled, isAvailable else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        // HKWorkoutBuilder is the modern, sample-friendly path.
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // Best-effort — a failed Health write never blocks the session log.
        }
    }

    /// Mirror a body-weight entry into Health.
    func saveBodyMass(kg: Double, date: Date) async {
        guard enabled, isAvailable, kg > 0 else { return }
        let qty = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: bodyMass, quantity: qty, start: date, end: date)
        try? await store.save(sample)
    }

    /// Read the most recent body-weight Health has, in kg.
    func latestBodyMass() async -> Double? {
        guard enabled, isAvailable else { return nil }
        return await withCheckedContinuation { cont in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let q = HKSampleQuery(sampleType: bodyMass, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                cont.resume(returning: kg)
            }
            store.execute(q)
        }
    }
    #else
    var isAvailable: Bool { false }
    var enabled: Bool { get { false } set {} }
    func requestAuthorization() async -> Bool { false }
    func saveStrengthWorkout(start: Date, end: Date) async {}
    func saveBodyMass(kg: Double, date: Date) async {}
    func latestBodyMass() async -> Double? { nil }
    #endif
}
