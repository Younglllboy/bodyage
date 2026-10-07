import Foundation
import HealthKit

private enum ReadError: LocalizedError {
    case unavailable, timeout, truncated
    var errorDescription: String? {
        switch self {
        case .unavailable: return "此设备无法访问健康数据。"
        case .timeout: return "读取超时，请解锁手表后重试。"
        case .truncated: return "记录量超过安全上限，本次未使用截断数据。"
        }
    }
}

// HK callbacks and timeout can race. Resume each continuation exactly once.
private final class QueryCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[HKSample], Error>?
    init(_ continuation: CheckedContinuation<[HKSample], Error>) { self.continuation = continuation }
    @discardableResult
    func finish(_ result: Result<[HKSample], Error>) -> Bool {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return false }
        pending.resume(with: result)
        return true
    }
}

@MainActor
final class HealthKitReader {
    private let store = HKHealthStore()
    private let queryLimit = 20_000
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        Set(Metric.allCases.map { sampleType($0) as HKObjectType })
    }

    func authorize() async throws {
        guard isAvailable else { throw ReadError.unavailable }
        // Success means the permission flow finished, NOT that every read type was granted.
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetch(now: Date = Date()) async throws -> Snapshot {
        guard isAvailable else { throw ReadError.unavailable }
        let calendar = Calendar.current
        // Extra day supplies the beginning of the earliest noon-to-noon sleep window.
        let start = calendar.date(byAdding: .day, value: -29,
                                  to: calendar.startOfDay(for: now))!
        var values: [Metric: [DailyValue]] = [:]
        var issues: [String] = []
        // Sequential queries avoid several large HK result arrays resident at once.
        for metric in Metric.allCases {
            do {
                let raw = try await samples(type: sampleType(metric), start: start, end: now)
                let watch = raw.filter(Self.isWatchSample)
                let readings: [Reading]
                if metric == .sleepHours {
                    let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                        HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                        HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                        HKCategoryValueSleepAnalysis.asleepREM.rawValue]
                    readings = watch.compactMap { sample in
                        guard let sample = sample as? HKCategorySample, asleep.contains(sample.value)
                        else { return nil }
                        return Reading(id: sample.uuid.uuidString, start: sample.startDate,
                                       end: sample.endDate, value: 1)
                    }
                } else {
                    let unit = quantityUnit(metric)
                    readings = watch.compactMap { sample in
                        guard let sample = sample as? HKQuantitySample else { return nil }
                        return Reading(id: sample.uuid.uuidString, start: sample.startDate,
                            end: sample.endDate, value: sample.quantity.doubleValue(for: unit))
                    }
                }
                switch metric {
                case .sleepHours: values[metric] = Aggregation.sleep(readings, now: now)
                case .exerciseMinutes: values[metric] = Aggregation.exercise(readings, now: now)
                default: values[metric] = Aggregation.dailyMedians(readings, now: now)
                }
                if !raw.isEmpty && watch.isEmpty {
                    issues.append("\(metric.title)：未找到可确认来自 Apple Watch 的系统记录。")
                }
            } catch {
                // A failure clears this metric; never carry forward a previously visible value.
                values[metric] = []
                issues.append("\(metric.title)：\(error.localizedDescription)")
            }
        }
        return Snapshot(fetchedAt: now, values: values, issues: issues)
    }

    private static func isWatchSample(_ sample: HKSample) -> Bool {
        let source = sample.sourceRevision
        let fromApple = source.source.bundleIdentifier.hasPrefix("com.apple.")
        let product = source.productType?.lowercased() ?? ""
        let device = sample.device?.model?.lowercased() ?? ""
        let userEntered = (sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber)?.boolValue ?? false
        // Conservative provenance check; unknown origin is not silently promoted to Watch data.
        return fromApple && (product.hasPrefix("watch") || device.contains("watch")) && !userEntered
    }

    private func sampleType(_ metric: Metric) -> HKSampleType {
        switch metric {
        case .sleepHours: return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        case .vo2Max: return HKObjectType.quantityType(forIdentifier: .vo2Max)!
        case .restingHeartRate: return HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        case .hrv: return HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        case .respiratoryRate: return HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        case .exerciseMinutes: return HKObjectType.quantityType(forIdentifier: .appleExerciseTime)!
        }
    }

    private func quantityUnit(_ metric: Metric) -> HKUnit {
        switch metric {
        case .vo2Max: return HKUnit(from: "ml/kg*min")
        case .restingHeartRate, .respiratoryRate: return HKUnit.count().unitDivided(by: .minute())
        case .hrv: return .secondUnit(with: .milli)
        case .exerciseMinutes: return .minute()
        case .sleepHours: return .hour()
        }
    }

    private func samples(type: HKSampleType, start: Date, end: Date) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let completion = QueryCompletion(continuation)
            let limit = queryLimit
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]) {
                    _, result, error in
                    if let error { completion.finish(.failure(error)); return }
                    let samples = result ?? []
                    if samples.count >= limit { completion.finish(.failure(ReadError.truncated)); return }
                    completion.finish(.success(samples))
                }
            store.execute(query)
            let store = store
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                if completion.finish(.failure(ReadError.timeout)) { store.stop(query) }
            }
        }
    }
}
