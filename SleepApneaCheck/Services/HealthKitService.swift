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
    @Published private(set) var latestOxygenSaturationDate: Date?
    @Published private(set) var errorMessage: String?

    private let healthStore = HKHealthStore()
    private let logger = Logger(subsystem: "com.naritamasayuki.sleepapneacheck", category: "HealthKitService")
    private static let authorizedKey = "healthkit_previously_authorized"

    init() {
        self.isAuthorized = UserDefaults.standard.bool(forKey: Self.authorizedKey)
    }

    /// 過去に連携済みであればアプリ起動時に自動で最新メトリクスを更新する
    func refreshIfPreviouslyAuthorized() async {
        guard isAvailable, isAuthorized else { return }
        await refreshLatestMetrics()
    }

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
            UserDefaults.standard.set(true, forKey: Self.authorizedKey)
            errorMessage = nil
            await refreshLatestMetrics()
        } catch {
            logger.error("HealthKit 権限リクエスト失敗: \(error.localizedDescription)")
            errorMessage = String(localized: "healthkit.auth_failed")
        }
    }

    /// 直近36時間の睡眠時間合計（重複区間マージ済み）と直近7日以内の最新血中酸素飽和度を取得する
    func refreshLatestMetrics() async {
        guard isAvailable else { return }
        async let sleepHours = fetchLatestSleepDurationHours()
        async let spo2 = fetchLatestOxygenSaturation()

        lastSleepDurationHours = await sleepHours
        let spo2Result = await spo2
        latestOxygenSaturationPercent = spo2Result?.percent
        latestOxygenSaturationDate = spo2Result?.date
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
                limit: HKObjectQueryNoLimit,
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

                // 睡眠中カテゴリ（inBed 以外）について、iPhone と Apple Watch 等の重複区間を結合してから合計する
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let intervals = categorySamples
                    .filter { asleepValues.contains($0.value) }
                    .map { ($0.startDate, $0.endDate) }
                    .sorted { $0.0 < $1.0 }

                var asleepSeconds: TimeInterval = 0
                var current: (Date, Date)?
                for interval in intervals {
                    if let cur = current, interval.0 <= cur.1 {
                        current = (cur.0, max(cur.1, interval.1))
                    } else {
                        if let cur = current {
                            asleepSeconds += cur.1.timeIntervalSince(cur.0)
                        }
                        current = interval
                    }
                }
                if let cur = current {
                    asleepSeconds += cur.1.timeIntervalSince(cur.0)
                }

                guard asleepSeconds > 0 else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: asleepSeconds / 3600.0)
            }
            healthStore.execute(query)
        }
    }

    /// 指定した録音時間帯（前後1時間の余裕を含む）の最低血中酸素飽和度を取得する
    func fetchLowestOxygenSaturation(from startDate: Date, to endDate: Date) async -> Double? {
        guard isAvailable, isAuthorized,
              let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            return nil
        }

        let windowStart = startDate.addingTimeInterval(-1800)
        let windowEnd = endDate.addingTimeInterval(1800)
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: spo2Type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { [weak self] _, samples, error in
                if let error {
                    self?.logger.warning("HealthKit セッション内SpO2取得失敗: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                let lowest = quantitySamples
                    .map { $0.quantity.doubleValue(for: HKUnit.percent()) * 100.0 }
                    .min()
                continuation.resume(returning: lowest)
            }
            healthStore.execute(query)
        }
    }

    private func fetchLatestOxygenSaturation() async -> (percent: Double, date: Date)? {
        guard let spo2Type = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) else {
            return nil
        }

        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -7, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: spo2Type,
                predicate: predicate,
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
                continuation.resume(returning: (percent, sample.endDate))
            }
            healthStore.execute(query)
        }
    }
}
