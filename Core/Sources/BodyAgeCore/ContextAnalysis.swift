import Foundation

public struct MetricSummary: Sendable, Identifiable {
    public var id: Metric { metric }
    public let metric: Metric
    public let current: Double?
    public let baseline: Double?
    public let currentDays: Int
    public let baselineDays: Int
    public let latestSample: Date?
    public let isStale: Bool
    public let recent: [DailyValue]
    public var change: Double? {
        guard currentDays >= 3, baselineDays >= 7, !isStale,
              let current, let baseline else { return nil }
        return current - baseline
    }
}

public enum ContextAnalysis {
    public static func summarize(_ metric: Metric, snapshot: Snapshot,
                                 calendar: Calendar = .current) -> MetricSummary {
        let today = calendar.startOfDay(for: snapshot.fetchedAt)
        // Ordinary metrics: 7 complete calendar days, excluding today.
        // Sleep: 7 complete noon windows, which may include this morning after noon.
        var end = today
        if metric == .sleepHours, calendar.component(.hour, from: snapshot.fetchedAt) >= 12 {
            end = calendar.date(byAdding: .day, value: 1, to: today)!
        }
        let recentStart = calendar.date(byAdding: .day, value: -7, to: end)!
        let baselineStart = calendar.date(byAdding: .day, value: -28, to: end)!
        let valid = snapshot[metric].filter { $0.value.isFinite && $0.latestSample <= snapshot.fetchedAt }
        let recent = valid.filter { $0.date >= recentStart && $0.date < end }.sorted { $0.date < $1.date }
        let older = valid.filter { $0.date >= baselineStart && $0.date < recentStart }
        let latest = recent.map(\.latestSample).max()
        let staleBefore = calendar.date(byAdding: .day, value: -3, to: snapshot.fetchedAt)!
        return MetricSummary(metric: metric, current: Statistics.median(recent.map(\.value)),
            baseline: Statistics.median(older.map(\.value)), currentDays: recent.count,
            baselineDays: older.count, latestSample: latest,
            isStale: latest.map { $0 < staleBefore } ?? true, recent: recent)
    }

    // Descriptive integration only: no illness classifier, readiness score, or age weights.
    public static func narrative(snapshot: Snapshot, calendar: Calendar = .current) -> String {
        let contextual: [Metric] = [.restingHeartRate, .hrv, .respiratoryRate, .sleepHours, .exerciseMinutes]
        let summaries = contextual.map { summarize($0, snapshot: snapshot, calendar: calendar) }
        let available = summaries.filter { $0.currentDays >= 3 && !$0.isStale }.count
        let comparable = summaries.filter { $0.change != nil }.count
        if available == 0 { return "正在建立健康概览。佩戴记录不足、历史不可用或读取权限受限，都可能使指标暂缺。" }
        if comparable < 2 { return "已有 \(available)/5 项近期指标。个人历史还不足以比较变化；这些记录不会被换算成加减年龄。" }
        let descriptions = summaries.compactMap { summary -> String? in
            guard let change = summary.change else { return nil }
            let unit = summary.metric == .hrv ? "ms" : summary.metric.unit
            let roundedChange = (change * 10).rounded() / 10
            if roundedChange == 0 { return "\(summary.metric.title)与基线接近" }
            let amount = String(format: "%.1f", abs(roundedChange))
            return "\(summary.metric.title)\(roundedChange > 0 ? "增加" : "减少") \(amount) \(unit)"
        }
        return "与此前 21 天相比：" + descriptions.joined(separator: "；") +
            "。这是已记录数据的变化，不代表身体变老或变年轻。"
    }
}
