import SwiftUI

struct AgeOverview: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Page {
            Eyebrow(text: "心肺体能参考")
            if let result = model.assessment?.result, !model.isLoading {
                let display = AgePresentation(position: result.position, chronologicalAge: model.profile.age)
                let accent = (display.difference ?? 0) > 0 ? Palette.amber : Palette.mint
                NavigationLink(value: AppRoute.ageDetail) {
                    VStack(spacing: 2) {
                        AgeBloom(label: display.ageLabel)
                        Text(display.differenceLabel)
                            .font(.system(.title3, design: .rounded, weight: .bold)).monospacedDigit()
                            .foregroundStyle(accent)
                            .padding(.horizontal, 16).padding(.vertical, 5)
                            .background(accent.opacity(0.12), in: Capsule())
                        Text("对比实际 \(model.profile.age) 岁")
                            .font(.caption2).foregroundStyle(Palette.secondary).padding(.top, 3)
                    }.frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(SpringPress())
                .accessibilityLabel("心肺体能参考年龄 \(display.ageLabel) 岁，\(display.differenceLabel)，实际年龄 \(model.profile.age) 岁")
                .accessibilityHint("查看估算依据")
            } else {
                NavigationLink(value: AppRoute.ageDetail) {
                    VStack(spacing: 4) {
                        AgeBloom(label: "—")
                        if model.isLoading { ProgressView().tint(Palette.mint) }
                        Text(status).font(.caption).foregroundStyle(Palette.mint)
                        Text("轻点查看").font(.caption2).foregroundStyle(Palette.secondary)
                    }.frame(maxWidth: .infinity).contentShape(Rectangle())
                }.buttonStyle(SpringPress())
            }
            HStack(spacing: 8) {
                NavigationLink(value: AppRoute.health) {
                    homeTile("健康", symbol: "square.grid.2x2.fill", color: Palette.lilac)
                }
                NavigationLink(value: AppRoute.settings) {
                    homeTile("更多", symbol: "ellipsis", color: Palette.amber)
                }
            }.buttonStyle(SpringPress())
        }.navigationTitle("身体年龄")
    }

    private var status: String {
        if model.isLoading { return "正在更新" }
        if model.needsAgeReview { return "核对一下年龄" }
        if model.profile.referenceNotApplicable { return "换算已暂停" }
        return "等待更多记录"
    }

    private func homeTile(_ title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(title).foregroundStyle(Palette.ink)
        }
        .font(.system(.caption, design: .rounded, weight: .semibold))
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct AgeDetailView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Page {
            if let snapshot = model.snapshot, let readout = CardioReadout(snapshot: snapshot) {
                Panel {
                    Eyebrow(text: "来自你的心肺体能")
                    Text(String(format: "%.1f", readout.value))
                        .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .foregroundStyle(Palette.mint)
                    SmallNote(text: "VO₂max · mL/kg/min")
                    SmallNote(text: "\(readout.days) 个采样日 · 最近 \(readout.latest.formatted(.dateTime.month().day()))")
                }
            }
            if model.assessment?.result == nil {
                Panel {
                    Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(Palette.amber)
                    Text(model.isLoading ? "正在读取" : "暂未生成").font(.headline)
                    SmallNote(text: model.needsAgeReview ? "请核对实际周岁。" :
                        model.assessment?.explanation ?? "读取后再来看一看。")
                }
                NavigationLink(value: AppRoute.profile) {
                    MenuRow(title: "个人设置", symbol: "person.crop.circle", color: Palette.lilac)
                }
            }
            NavigationLink(value: AppRoute.sensitivity) {
                MenuRow(title: "有多大波动？", symbol: "waveform.path", color: Palette.blue)
            }
            NavigationLink(value: AppRoute.method) {
                MenuRow(title: "这个年龄是什么？", symbol: "sparkles", color: Palette.lilac)
            }
            NavigationLink(value: AppRoute.dataStatus) {
                MenuRow(title: "数据状态", symbol: "clock", color: Palette.amber)
            }
            SmallNote(text: "不是全身生物年龄或医学诊断。")
        }.buttonStyle(SpringPress()).navigationTitle("年龄详情")
    }
}

// Display observed VO2 even when age conversion is unavailable (for example no reference group).
struct CardioReadout {
    let value: Double
    let days: Int
    let latest: Date
    init?(snapshot: Snapshot) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: snapshot.fetchedAt)!
        let values = snapshot[.vo2Max].filter {
            $0.latestSample >= cutoff && $0.latestSample <= snapshot.fetchedAt &&
            $0.value.isFinite && (14...65).contains($0.value)
        }
        guard let value = Statistics.median(values.map(\.value)),
              let latest = values.map(\.latestSample).max() else { return nil }
        self.value = value
        self.latest = latest
        self.days = values.count
    }
}

struct SensitivityView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Page {
            Image(systemName: "waveform.path").font(.largeTitle).foregroundStyle(Palette.blue)
            if let result = model.assessment?.result {
                Text("\(result.sensitivityLow.label)–\(result.sensitivityHigh.label)")
                    .font(.system(.title, design: .rounded, weight: .semibold)).minimumScaleFactor(0.7)
                Eyebrow(text: "岁 · 扰动示例")
                Panel {
                    SmallNote(text: "假设 VO₂max 上下变化 3.5，年龄换算也会变化。")
                    SmallNote(text: "这是敏感性演示，不是置信区间。实际误差可能更大。")
                }
            } else { SmallNote(text: "生成参考年龄后可查看。") }
        }.navigationTitle("估算波动")
    }
}
