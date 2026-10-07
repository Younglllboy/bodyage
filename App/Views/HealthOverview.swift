import SwiftUI

struct HealthOverview: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var typeSize
    private let metrics: [Metric] = [.sleepHours, .restingHeartRate, .hrv, .respiratoryRate, .exerciseMinutes, .vo2Max]
    var body: some View {
        Page {
            Eyebrow(text: "点开一块，看看身体的日常")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                     count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 8) {
                ForEach(metrics) { metric in
                    NavigationLink(value: metric == .vo2Max ? AppRoute.ageDetail : .metric(metric)) {
                        tile(metric)
                    }.buttonStyle(SpringPress())
                }
            }
            NavigationLink(value: AppRoute.dataStatus) {
                MenuRow(title: "数据状态", symbol: "clock", color: Palette.amber)
            }.buttonStyle(SpringPress())
        }.navigationTitle("健康拼图")
    }

    private func tile(_ metric: Metric) -> some View {
        let value: Double? = {
            guard let snapshot = model.snapshot else { return nil }
            if metric == .vo2Max { return CardioReadout(snapshot: snapshot)?.value }
            return ContextAnalysis.summarize(metric, snapshot: snapshot).current
        }()
        let stale: Bool = {
            guard let snapshot = model.snapshot else { return false }
            if metric == .vo2Max {
                guard let latest = CardioReadout(snapshot: snapshot)?.latest else { return false }
                return latest < Calendar.current.date(byAdding: .day, value: -14, to: snapshot.fetchedAt)!
            }
            return ContextAnalysis.summarize(metric, snapshot: snapshot).isStale && value != nil
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: metric.symbol).foregroundStyle(metric.accent)
                Spacer(minLength: 0)
                Text(stale ? "较旧" : metric.shortTitle).font(.caption2).foregroundStyle(Palette.secondary)
            }
            Text(value.map { metric.formatted($0) } ?? "—")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .monospacedDigit().foregroundStyle(Palette.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(metric == .vo2Max ? "VO₂max · 28天" : "\(metric.shortTitle) · 7天")
                .font(.caption2).foregroundStyle(metric.accent)
        }
        .padding(10).frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        .background(LinearGradient(colors: [metric.accent.opacity(0.15), Palette.card],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(metric.accent.opacity(0.13)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title)，\(value.map { metric.formatted($0) + metric.unit } ?? "暂无记录")\(stale ? "，记录较旧" : "")")
        .accessibilityHint("查看详情")
    }
}

// Resolve by metric from the live model; never retain a stale health snapshot in a route.
struct MetricDetail: View {
    @EnvironmentObject private var model: AppModel
    let metric: Metric
    var body: some View {
        Page {
            if let snapshot = model.snapshot {
                let summary = ContextAnalysis.summarize(metric, snapshot: snapshot)
                VStack(spacing: 4) {
                    Image(systemName: metric.symbol).font(.title2).foregroundStyle(metric.accent)
                    Text(summary.current.map { metric.formatted($0) } ?? "—")
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                    Eyebrow(text: metric.unit)
                }.padding(.top, 4)
                Panel {
                    HStack {
                        Eyebrow(text: "近 7 天")
                        Spacer()
                        Text("\(summary.currentDays)/7 天").font(.caption2).foregroundStyle(metric.accent)
                    }
                    Sparkline(values: summary.recent, color: metric.accent)
                    if let change = summary.change {
                        let rounded = (change * 10).rounded() / 10
                        SmallNote(text: "较基线 \(rounded > 0 ? "+" : "")\(String(format: "%.1f", rounded == 0 ? 0 : rounded)) \(metric.unit)")
                    } else {
                        SmallNote(text: summary.isStale && summary.current != nil ? "记录较旧，暂停比较" : "个人基线待积累")
                    }
                }
            } else {
                SmallNote(text: model.isLoading ? "正在更新…" : "暂未读取到记录")
            }
            NavigationLink(value: AppRoute.history(metric)) {
                MenuRow(title: "每日记录", symbol: "calendar", color: metric.accent)
            }
            NavigationLink(value: AppRoute.metricInfo(metric)) {
                MenuRow(title: "怎么看？", symbol: "questionmark", color: metric.accent)
            }
        }.buttonStyle(SpringPress()).navigationTitle(metric.title)
    }
}

struct MetricHistory: View {
    @EnvironmentObject private var model: AppModel
    let metric: Metric
    var body: some View {
        Page {
            Eyebrow(text: "\(metric.title) · \(metric.unit)")
            if let snapshot = model.snapshot {
                let summary = ContextAnalysis.summarize(metric, snapshot: snapshot)
                if summary.recent.isEmpty { SmallNote(text: "还没有可显示的记录。") }
                ForEach(summary.recent.reversed()) { day in
                    HStack {
                        Text(day.date.formatted(.dateTime.month().day())).foregroundStyle(Palette.secondary)
                        Spacer()
                        Text(metric.formatted(day.value)).monospacedDigit().foregroundStyle(metric.accent)
                    }.font(.system(.body, design: .rounded)).padding(12)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: 17))
                }
                SmallNote(text: "仅显示有记录的日期。缺测不记零。")
            } else { SmallNote(text: "读取后再来看一看。") }
        }.navigationTitle("每日记录")
    }
}

struct MetricInfo: View {
    @EnvironmentObject private var model: AppModel
    let metric: Metric
    var body: some View {
        Page {
            Image(systemName: metric.symbol).font(.largeTitle).foregroundStyle(metric.accent)
            Panel { SmallNote(text: explanation) }
            if let snapshot = model.snapshot {
                let summary = ContextAnalysis.summarize(metric, snapshot: snapshot)
                SmallNote(text: "近期 \(summary.currentDays)/7 天 · 基线 \(summary.baselineDays)/21 天")
            }
            SmallNote(text: "至少 3 个近期日、7 个基线日，且最近记录不超过 3 天才比较。变化不等于健康变好或变差。")
        }.navigationTitle("怎么看？")
    }
    private var explanation: String {
        switch metric {
        case .restingHeartRate: return "静息心率的每日中位数。训练、睡眠和药物都可能影响它。"
        case .hrv: return "手表记录的 SDNN。采样时机影响较大，不与 RMSSD 混用，也不是越高越好。"
        case .respiratoryRate: return "实际采样时段的呼吸频率，可能主要来自睡眠，不代表全天连续监测。"
        case .sleepHours: return "实际睡眠区间去重，排除清醒和卧床。按中午到次日中午汇总，窗口结束后显示；漏记会影响时长。"
        case .exerciseMinutes: return "完整日期内已记录的运动分钟。不是全天运动量保证，也不直接等于 WHO 中高强度运动分钟。"
        case .vo2Max: return "手表估算的心肺体能，不是实验室直接测量。"
        }
    }
}
