#if DEBUG
import Foundation

enum DemoData {
    static func snapshot(now: Date = Date()) -> Snapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var data: [Metric: [DailyValue]] = [:]
        for metric in Metric.allCases {
            data[metric] = (1...28).reversed().compactMap { day in
                if metric == .vo2Max && day % 3 != 0 { return nil }
                let date = calendar.date(byAdding: .day, value: -day, to: today)!
                let wave = sin(Double(day) * 0.8)
                let value: Double
                switch metric {
                case .vo2Max: value = 41.4 + wave * 0.5
                case .restingHeartRate: value = 58 + wave * 2
                case .hrv: value = 48 + wave * 7
                case .respiratoryRate: value = 14.5 + wave * 0.6
                case .sleepHours: value = 7.4 + wave * 0.6
                case .exerciseMinutes: value = 34 + wave * 14
                }
                return DailyValue(date: date, value: value, latestSample: date.addingTimeInterval(8 * 3600))
            }
        }
        return Snapshot(fetchedAt: now, values: data)
    }
}
#endif
