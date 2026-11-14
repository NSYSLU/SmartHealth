import Foundation
import HealthKit

struct HealthKitMetricValue: Sendable { let title: String; let value: String; let unit: String; let icon: String; let color: String }
enum HealthDataRange: String, CaseIterable, Identifiable { case today = "今天", week = "本周", month = "本月"; var id: String { rawValue } }

@MainActor
final class HealthKitService {
    private let store = HKHealthStore()
    private let definitions: [(HKQuantityTypeIdentifier, String, HKUnit, HKStatisticsOptions, String, String)] = [
        (.stepCount, "步数", .count(), .cumulativeSum, "figure.walk", "#32A87D"), (.heartRate, "心率", HKUnit(from: "count/min"), .discreteAverage, "heart.fill", "#E66A6A"), (.activeEnergyBurned, "活跃能量", .kilocalorie(), .cumulativeSum, "flame.fill", "#E88B43"), (.basalEnergyBurned, "基础能量", .kilocalorie(), .cumulativeSum, "bolt.fill", "#E88B43"), (.distanceWalkingRunning, "步行距离", .meter(), .cumulativeSum, "figure.walk.motion", "#4B9ED8"), (.distanceCycling, "骑行距离", .meter(), .cumulativeSum, "figure.outdoor.cycle", "#32A87D"), (.flightsClimbed, "爬楼层数", .count(), .cumulativeSum, "stairs", "#8D6CCF"), (.appleExerciseTime, "锻炼时间", .minute(), .cumulativeSum, "figure.run", "#E88B43"), (.appleStandTime, "站立时间", .minute(), .cumulativeSum, "figure.stand", "#32A87D"), (.walkingSpeed, "步行速度", HKUnit(from: "m/s"), .discreteAverage, "speedometer", "#4B9ED8"), (.walkingStepLength, "步幅", .meter(), .discreteAverage, "shoeprints.fill", "#4B9ED8"), (.bodyMass, "体重", .gramUnit(with: .kilo), .discreteMostRecent, "scalemass.fill", "#8D6CCF"), (.bodyTemperature, "体温", .degreeCelsius(), .discreteMostRecent, "thermometer.medium", "#E66A6A"), (.respiratoryRate, "呼吸频率", HKUnit(from: "count/min"), .discreteAverage, "lungs.fill", "#4B9ED8"), (.oxygenSaturation, "血氧", .percent(), .discreteAverage, "drop.fill", "#4B9ED8"), (.bloodGlucose, "血糖", HKUnit(from: "mg/dL"), .discreteMostRecent, "drop.triangle.fill", "#E66A6A"), (.bloodPressureSystolic, "收缩压", .millimeterOfMercury(), .discreteMostRecent, "heart.text.square.fill", "#E66A6A"), (.bloodPressureDiastolic, "舒张压", .millimeterOfMercury(), .discreteMostRecent, "heart.text.square", "#E66A6A"), (.dietaryWater, "饮水", .literUnit(with: .milli), .cumulativeSum, "drop.fill", "#4B9ED8"), (.dietaryCaffeine, "咖啡因", .gramUnit(with: .milli), .cumulativeSum, "cup.and.saucer.fill", "#8D6CCF"), (.dietaryProtein, "蛋白质", .gram(), .cumulativeSum, "fork.knife", "#E88B43"), (.dietaryEnergyConsumed, "摄入能量", .kilocalorie(), .cumulativeSum, "fork.knife.circle.fill", "#E88B43")
    ]

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAccess() async throws {
        guard isAvailable else { throw HealthKitError.unavailable }
        let readTypes = Set(definitions.compactMap { HKObjectType.quantityType(forIdentifier: $0.0) })
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func todayMetrics(range: HealthDataRange = .today) async throws -> [HealthKitMetricValue] {
        guard isAvailable else { throw HealthKitError.unavailable }
        return try await withThrowingTaskGroup(of: HealthKitMetricValue?.self) { group in
            for definition in definitions { group.addTask { [store] in guard let type = HKObjectType.quantityType(forIdentifier: definition.0), let number = try await Self.statistics(store: store, type: type, unit: definition.2, options: definition.3, range: range) else { return nil }; return HealthKitMetricValue(title: definition.1, value: String(format: "%.1f", number), unit: Self.unitText(for: definition.0, range: range), icon: definition.4, color: definition.5) } }
            var values: [HealthKitMetricValue] = []; for try await value in group { if let value { values.append(value) } }; return values
        }
    }

    private nonisolated static func statistics(store: HKHealthStore, type: HKQuantityType, unit: HKUnit, options: HKStatisticsOptions, range: HealthDataRange) async throws -> Double? {
        let start: Date = { switch range { case .today: return Calendar.current.startOfDay(for: .now); case .week: return Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now; case .month: return Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now } }()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, result, error in
                if error != nil { continuation.resume(returning: nil); return }
                let quantity = options.contains(.discreteAverage) ? result?.averageQuantity() : (options.contains(.discreteMostRecent) ? result?.mostRecentQuantity() : result?.sumQuantity())
                continuation.resume(returning: quantity?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private nonisolated static func unitText(for identifier: HKQuantityTypeIdentifier, range: HealthDataRange) -> String { let base: String; switch identifier { case .heartRate, .respiratoryRate: base = "次/分钟"; case .activeEnergyBurned, .basalEnergyBurned, .dietaryEnergyConsumed: base = "千卡"; case .distanceWalkingRunning, .distanceCycling, .walkingStepLength: base = "米"; case .bodyMass: base = "千克"; case .bodyTemperature: base = "°C"; case .oxygenSaturation: base = "%"; case .bloodPressureSystolic, .bloodPressureDiastolic, .bloodGlucose: base = "mg/dL"; case .dietaryWater: base = "毫升"; case .dietaryCaffeine, .dietaryProtein: base = "克"; case .appleExerciseTime, .appleStandTime: base = "分钟"; default: base = "次" }; return "\(base) · \(range.rawValue)" }
}

enum HealthKitError: LocalizedError {
    case unavailable
    var errorDescription: String? { "此设备暂不支持 Apple 健康" }
}
