import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Page {
            NavigationLink(value: AppRoute.profile) {
                MenuRow(title: "我的资料", symbol: "person.crop.circle", color: Palette.lilac,
                        detail: "实际年龄 \(model.profile.age) 岁")
            }.disabled(model.isLoading)
            NavigationLink(value: AppRoute.dataStatus) {
                MenuRow(title: "数据与刷新", symbol: "arrow.clockwise", color: Palette.blue)
            }
            NavigationLink(value: AppRoute.method) {
                MenuRow(title: "读懂年龄", symbol: "sparkles", color: Palette.mint)
            }
            NavigationLink(value: AppRoute.privacy) {
                MenuRow(title: "隐私与授权", symbol: "lock.shield", color: Palette.amber)
            }
            Eyebrow(text: "AEVUM / 1.0")
        }.buttonStyle(SpringPress()).navigationTitle("更多")
    }
}

struct MethodView: View {
    var body: some View {
        Page {
            Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(Palette.mint)
            Panel {
                Text("体能的年龄坐标").font(.headline)
                SmallNote(text: "用近 28 天 VO₂max 的日中位数，再取中位数，与 FRIEND 年龄常模比较。")
                SmallNote(text: "差值 = 显示的参考年龄 − 实际年龄。它不是衰老速度。")
            }
            SmallNote(text: "不是全身生物年龄，尚未经临床验证。睡眠等指标用于观察状态，不加减岁数。")
            NavigationLink(value: AppRoute.eligibility) {
                MenuRow(title: "适用范围", symbol: "person.crop.circle.badge.questionmark", color: Palette.amber)
            }
            NavigationLink(value: AppRoute.references) {
                MenuRow(title: "研究来源", symbol: "book.closed", color: Palette.lilac)
            }
        }.buttonStyle(SpringPress()).navigationTitle("读懂年龄")
    }
}

struct EligibilityView: View {
    var body: some View {
        Page {
            Panel {
                Text("20–79 岁").font(.system(.title2, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.amber)
                SmallNote(text: "美国成人心肺体能常模；按研究中的生理性别分组，不代表性别认同。可不选择常模。")
            }
            Panel {
                Text("这些情况请暂停").font(.caption)
                SmallNote(text: "孕期、已知心肺疾病、服用影响心率的药物，或不适合此参考人群。可在个人设置中暂停年龄换算。")
            }
            SmallNote(text: "边界显示 ≤25 / ≥75，仅是常模端点，此时不显示精确年龄差。不要据此诊断或调整用药。")
        }.navigationTitle("适用范围")
    }
}

struct ReferencesView: View {
    var body: some View {
        Page {
            Panel {
                Text("FRIEND · 2015").font(.headline).foregroundStyle(Palette.mint)
                SmallNote(text: "Kaminsky 等，表 3 的第 50 百分位。插值换算是本应用的工程近似。")
                SmallNote(text: "DOI: 10.1016/j.mayocp.2015.07.026")
            }
            Panel {
                Text("测量误差 · 2025").font(.caption).foregroundStyle(Palette.blue)
                SmallNote(text: "Lambe 等，Apple Watch VO₂max 验证。")
                SmallNote(text: "DOI: 10.1371/journal.pone.0323741")
            }
            SmallNote(text: "完整方法与文献见源码包的科学说明。")
        }.navigationTitle("研究来源")
    }
}

struct DataStatusView: View {
    @EnvironmentObject private var model: AppModel
    var body: some View {
        Page {
            if model.isLoading { ProgressView("读取中").tint(Palette.mint) }
            else if let snapshot = model.snapshot {
                Panel {
                    Eyebrow(text: "最近读取")
                    Text(snapshot.fetchedAt.formatted(.dateTime.hour().minute()))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                    SmallNote(text: "\(snapshot.values.values.filter { !$0.isEmpty }.count)/6 类指标有记录")
                }
                ForEach(snapshot.issues, id: \.self) { SmallNote(text: $0) }
            } else { SmallNote(text: "还没有可用快照") }
            Button {
                Task { await model.refresh(force: true) }
            } label: {
                Label("刷新一下", systemImage: "arrow.clockwise").frame(maxWidth: .infinity, minHeight: 34)
            }.buttonStyle(.borderedProminent).disabled(model.isLoading || model.isDemo)
            SmallNote(text: "缺测可能来自权限、佩戴或历史不足。年龄需 3 个 VO₂max 采样日，最近不超过 14 天。")
            NavigationLink(value: AppRoute.privacy) {
                MenuRow(title: "检查授权", symbol: "heart.text.clipboard", color: Palette.coral)
            }.buttonStyle(SpringPress())
        }.navigationTitle("数据状态")
    }
}

struct PrivacyView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmReset = false
    var body: some View {
        Page {
            Image(systemName: "lock.shield.fill").font(.largeTitle).foregroundStyle(Palette.amber)
            Text("留在你的手腕上").font(.headline)
            SmallNote(text: "健康记录只读、仅在内存处理。不上传，不写回健康 App。个人设置保存在手表上。")
            Button("健康数据授权") { Task { await model.authorizeAndRefresh() } }
                .buttonStyle(.borderedProminent).disabled(model.isLoading || model.isDemo)
            SmallNote(text: "已拒绝的权限需在手表系统健康/隐私设置中更改。空数据不等于拒绝授权。")
            Button("清除本地设置", role: .destructive) { confirmReset = true }
                .buttonStyle(.bordered).disabled(model.isLoading || model.isDemo)
        }
        .navigationTitle("隐私")
        .confirmationDialog("清除设置？系统健康记录和授权会保留。", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("清除", role: .destructive) { model.reset() }
            Button("取消", role: .cancel) { }
        }
    }
}
