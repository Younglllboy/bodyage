import Foundation

public enum Metric: String, CaseIterable, Sendable, Identifiable {
    case vo2Max, restingHeartRate, hrv, respiratoryRate, sleepHours, exerciseMinutes
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .vo2Max: return "心肺体能"
        case .restingHeartRate: return "静息心率"
        case .hrv: return "心率变异性"
        case .respiratoryRate: return "呼吸频率"
        case .sleepHours: return "睡眠时长"
        case .exerciseMinutes: return "运动时间"
        }
    }
    public var unit: String {
        switch self {
        case .vo2Max: return "mL/kg/min"
        case .restingHeartRate: return "次/分"
        case .hrv: return "ms · SDNN"
        case .respiratoryRate: return "次/分"
        case .sleepHours: return "小时"
        case .exerciseMinutes: return "分钟/日"
        }
    }
}

public enum ReferenceSex: String, CaseIterable, Codable, Sendable {
    case unspecified, female, male
    public var title: String {
        switch self {
        case .unspecified: return "暂不选择"
        case .female: return "女性常模"
        case .male: return "男性常模"
        }
    }
}

public struct Profile: Codable, Equatable, Sendable {
    public var age: Int
    public var referenceSex: ReferenceSex
    public var referenceNotApplicable: Bool
    public init(age: Int = 35, referenceSex: ReferenceSex = .unspecified,
                referenceNotApplicable: Bool = false) {
        self.age = age
        self.referenceSex = referenceSex
        self.referenceNotApplicable = referenceNotApplicable
    }
}

public struct Reading: Sendable {
    public let id: String
    public let start: Date
    public let end: Date
    public let value: Double
    public init(id: String = UUID().uuidString, start: Date, end: Date, value: Double) {
        self.id = id; self.start = start; self.end = end; self.value = value
    }
}

public struct DailyValue: Sendable, Identifiable {
    public var id: Date { date }
    public let date: Date
    public let value: Double
    public let latestSample: Date
    public init(date: Date, value: Double, latestSample: Date) {
        self.date = date; self.value = value; self.latestSample = latestSample
    }
}

public struct Snapshot: Sendable {
    public let fetchedAt: Date
    public let values: [Metric: [DailyValue]]
    public let issues: [String]
    public init(fetchedAt: Date, values: [Metric: [DailyValue]], issues: [String] = []) {
        self.fetchedAt = fetchedAt; self.values = values; self.issues = issues
    }
    public subscript(metric: Metric) -> [DailyValue] { values[metric] ?? [] }
}

public enum Statistics {
    public static func median(_ values: [Double]) -> Double? {
        let ordered = values.filter(\.isFinite).sorted()
        guard !ordered.isEmpty else { return nil }
        let m = ordered.count / 2
        return ordered.count.isMultiple(of: 2) ? (ordered[m - 1] + ordered[m]) / 2 : ordered[m]
    }
}
