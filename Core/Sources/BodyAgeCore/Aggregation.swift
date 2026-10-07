import Foundation

public enum Aggregation {
    // UUID deduplication is separate from overlap handling: different UUIDs may overlap.
    public static func clean(_ readings: [Reading], now: Date) -> [Reading] {
        var seen = Set<String>()
        return readings.filter {
            $0.value.isFinite && $0.value >= 0 && $0.start <= $0.end &&
            $0.end <= now && seen.insert($0.id).inserted
        }
    }

    public static func dailyMedians(_ readings: [Reading], now: Date,
                                    calendar: Calendar = .current) -> [DailyValue] {
        let groups = Dictionary(grouping: clean(readings, now: now).filter { $0.value > 0 }) {
            calendar.startOfDay(for: $0.end)
        }
        return groups.compactMap { day, items in
            guard let value = Statistics.median(items.map(\.value)),
                  let latest = items.map(\.end).max() else { return nil }
            return DailyValue(date: day, value: value, latestSample: latest)
        }.sorted { $0.date < $1.date }
    }

    public static func unionDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var result: TimeInterval = 0
        for interval in sorted.dropFirst() {
            if interval.start <= current.end {
                current = DateInterval(start: current.start, end: max(current.end, interval.end))
            } else {
                result += current.duration
                current = interval
            }
        }
        return result + current.duration
    }

    // Noon-to-noon windows keep most overnight sleep together. Daytime sleep is included.
    // A window is emitted only after it ends. Never count inBed/awake in the adapter.
    public static func sleep(_ readings: [Reading], now: Date, days: Int = 28,
                             calendar: Calendar = .current) -> [DailyValue] {
        guard days > 0,
              let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)
        else { return [] }
        let lastEnd = todayNoon <= now ? todayNoon : calendar.date(byAdding: .day, value: -1, to: todayNoon)!
        let samples = clean(readings, now: now)
        return (0..<days).reversed().compactMap { offset in
            let end = calendar.date(byAdding: .day, value: -offset, to: lastEnd)!
            let start = calendar.date(byAdding: .day, value: -1, to: end)!
            let overlaps = samples.filter { $0.start < end && $0.end > start }
            let intervals = overlaps.map {
                DateInterval(start: max(start, $0.start), end: min(end, $0.end))
            }
            let seconds = unionDuration(intervals)
            guard seconds > 0, let latest = overlaps.map(\.end).max() else { return nil }
            return DailyValue(date: calendar.startOfDay(for: end), value: seconds / 3600,
                              latestSample: min(latest, end))
        }
    }

    // Cumulative Apple Exercise Time: integrate max rate across overlapping samples.
    // This avoids double-counting overlapping Watch records. Partial intervals assume
    // uniform distribution, so these are observed minutes, not exact Activity-ring totals.
    // Sort event boundaries and scan active rates; one exercise minute per elapsed minute maximum.
    public static func exercise(_ readings: [Reading], now: Date, days: Int = 28,
                                calendar: Calendar = .current) -> [DailyValue] {
        guard days > 0 else { return [] }
        let today = calendar.startOfDay(for: now)
        let samples = clean(readings, now: now).filter { $0.end > $0.start }
        return (1...days).reversed().compactMap { offset in
            let start = calendar.date(byAdding: .day, value: -offset, to: today)!
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let overlaps = samples.filter { $0.start < end && $0.end > start }
            guard let latest = overlaps.map(\.end).max() else { return nil }
            var changes: [Date: [(String, Double?)]] = [:]
            for sample in overlaps {
                let rate = min(sample.value / sample.end.timeIntervalSince(sample.start), 1 / 60.0)
                changes[max(start, sample.start), default: []].append((sample.id, rate))
                changes[min(end, sample.end), default: []].append((sample.id, nil))
            }
            var active: [String: Double] = [:]
            var previous = start
            var total = 0.0
            for time in changes.keys.sorted() {
                total += time.timeIntervalSince(previous) * (active.values.max() ?? 0)
                for (id, rate) in changes[time]! { active[id] = rate }
                previous = time
            }
            return DailyValue(date: start, value: total, latestSample: min(latest, end))
        }
    }
}
