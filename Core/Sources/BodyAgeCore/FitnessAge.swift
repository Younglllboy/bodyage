import Foundation

public enum AgeBoundary: Equatable, Sendable { case younger, within, older }

public struct AgePosition: Sendable {
    public let years: Double
    public let boundary: AgeBoundary
    public var label: String {
        switch boundary {
        case .younger: return "≤25"
        case .older: return "≥75"
        case .within: return String(Int(years.rounded()))
        }
    }
}

public struct FitnessAgeResult: Sendable {
    public let position: AgePosition
    public let vo2Max: Double
    public let observedDays: Int
    public let latestSample: Date
    // A chosen perturbation experiment, NOT a confidence/prediction interval.
    public let sensitivityLow: AgePosition
    public let sensitivityHigh: AgePosition
}

public struct AgeAssessment: Sendable {
    public let result: FitnessAgeResult?
    public let explanation: String
}

public enum FitnessAge {
    public static let version = "FRIEND-2015-P50 / interpolation-v1"
    // FRIEND (2015), Table 3, 50th percentiles. NOT Table 4 means.
    // https://pmc.ncbi.nlm.nih.gov/articles/PMC4919021/#T3
    public static let maleMedians = [48.0, 42.4, 37.8, 32.6, 28.2, 24.4]
    public static let femaleMedians = [37.6, 30.2, 26.7, 23.4, 20.0, 18.3]
    // Group midpoints are an explicit engineering assumption, not fitted ages.
    public static let ages = [24.5, 34.5, 44.5, 54.5, 64.5, 74.5]
    public static let sensitivityDelta = 3.5

    public static func position(vo2Max: Double, sex: ReferenceSex) -> AgePosition? {
        guard vo2Max.isFinite, vo2Max > 0, sex != .unspecified else { return nil }
        let medians = sex == .male ? maleMedians : femaleMedians
        if vo2Max > medians[0] { return AgePosition(years: ages[0], boundary: .younger) }
        if vo2Max < medians[5] { return AgePosition(years: ages[5], boundary: .older) }
        for index in 0..<5 where vo2Max <= medians[index] && vo2Max >= medians[index + 1] {
            let fraction = (medians[index] - vo2Max) / (medians[index] - medians[index + 1])
            return AgePosition(years: ages[index] + 10 * fraction, boundary: .within)
        }
        return nil
    }

    public static func assess(profile: Profile, snapshot: Snapshot,
                              calendar: Calendar = .current) -> AgeAssessment {
        guard (20...79).contains(profile.age) else {
            return AgeAssessment(result: nil, explanation: "常模仅涵盖实际年龄 20–79 岁。仍可查看各项健康记录。")
        }
        guard profile.referenceSex != .unspecified else {
            return AgeAssessment(result: nil, explanation: "请在设置中选择研究的生理性别常模；不选择时仍可查看健康记录。")
        }
        guard !profile.referenceNotApplicable else {
            return AgeAssessment(result: nil, explanation: "你已标记常模不适用，年龄换算已暂停。仍可查看健康记录。")
        }
        let now = snapshot.fetchedAt
        let cutoff = calendar.date(byAdding: .day, value: -28, to: now)!
        let candidates = snapshot[.vo2Max].filter {
            $0.latestSample >= cutoff && $0.latestSample <= now &&
            $0.value.isFinite && (14...65).contains($0.value)
        }
        // Re-aggregate to ensure callers cannot inflate coverage with repeated days.
        let grouped = Dictionary(grouping: candidates) { calendar.startOfDay(for: $0.date) }
        let daily = grouped.values.compactMap { Statistics.median($0.map(\.value)) }
        guard daily.count >= 3, let vo2 = Statistics.median(daily),
              let latest = candidates.map(\.latestSample).max() else {
            return AgeAssessment(result: nil, explanation: "近 28 天需至少 3 个不同日期的 Apple Watch VO₂max 记录。当前 \(daily.count)/3 天；未读取到不等于未授权。")
        }
        let freshness = calendar.date(byAdding: .day, value: -14, to: now)!
        guard latest >= freshness else {
            return AgeAssessment(result: nil, explanation: "VO₂max 最近记录已超过 14 天，暂不显示当前年龄参考。")
        }
        guard let point = position(vo2Max: vo2, sex: profile.referenceSex),
              let low = position(vo2Max: vo2 + sensitivityDelta, sex: profile.referenceSex),
              let high = position(vo2Max: vo2 - sensitivityDelta, sex: profile.referenceSex) else {
            return AgeAssessment(result: nil, explanation: "当前数据不适合换算。")
        }
        return AgeAssessment(result: FitnessAgeResult(position: point, vo2Max: vo2,
            observedDays: daily.count, latestSample: latest, sensitivityLow: low, sensitivityHigh: high),
            explanation: "仅代表心肺体能常模中的对应年龄，不是全身生物年龄。")
    }
}
