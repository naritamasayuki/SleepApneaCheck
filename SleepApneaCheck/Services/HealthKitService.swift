import Foundation
import HealthKit
import os

/// Apple ヘルスケア（HealthKit）から直近の睡眠時間および血中酸素飽和度（SpO2）を読み込むサービス
@MainActor
final class HealthKitService: ObservableObject {
    @Published private(set) var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var lastSleepDurationHours: Double?
    @Published private(set) var latestOxygenSaturationPercent: Double?
    @Published private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()
    private let logger = Logger(subsystem: "com.naritamasayuki.sleepapneacheck", category: "HealthKitService")

    /// HealthKit の読み取り権限をリクエストし、最新データを取得する
    func requestAuthorizationAndRefresh() async {
        guard isAvailable else {
            errorMessage = String(localized: "healthkit.unavailable")
            return
        }

        var readTypes = Set<HKObjectType>()
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleepType)
        }
        if let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            readTypes.insert(spo2Type)
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            errorMessage = nil
            await refreshLatestMetrics()
        } catch {
            logger.error("HealthKit 権限リクエスト失敗: \(error.localizedDescription)")
            errorMessage = String(localized: "healthkit.auth_failed")
        }
    }

    /// 直近48時間の睡眠時間合計と最新の血中酸素飽和度を取得する
    func refreshLatestMetrics() async {
        guard isAvailable else { return }
        async let sleepHours = fetchLatestSleepDurationHours()
        async let spo2 = fetchLatestOxygenSaturation()

        lastSleepDurationHours = await sleepHours
        latestOxygenSaturationPercent = await spo2
    }

    private func fetchLatestSleepDurationHours() async -> Double? {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -36, to: endDate) ?? endDate
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                if let error {
                    self?.logger.warning("HealthKit 睡眠データ取得失敗: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                // 睡眠中カテゴリ（inBed 以外）の合計時間を算出
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let asleepSeconds = categorySamples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                guard asleepSeconds > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: asleepSeconds / 3600.0)
            }
            healthStore.execute(query)
        }
    }

    private func fetchLatestOxygenSaturation() async -> Double? {
        guard let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: spo2Type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { [weak self] _, samples, error in
                if let error {
                    self?.logger.warning("HealthKit SpO2 取得失敗: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let percent = sample.quantity.doubleValue(for: HKUnit.percent()) * 100.0
                continuation.resume(returning: percent)
            }
            healthStore.execute(query)
        }
    }
}
