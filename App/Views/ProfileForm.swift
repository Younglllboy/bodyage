import SwiftUI

struct ProfileForm: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isOnboarding: Bool
    @State private var edited = Profile()
    @State private var step = 0
    @State private var prepared = false

    var body: some View {
        Page {
            if isOnboarding && step == 0 {
                Image(systemName: "sparkles").font(.system(size: 46)).foregroundStyle(Palette.mint).padding(.top, 8)
                Text("认识此刻的你").font(.system(.title3, design: .rounded, weight: .semibold))
                SmallNote(text: "看看体能参考年龄，探索身体的日常。")
                SmallNote(text: "不是全身生物年龄或医学诊断。")
                Button("开始") { advance() }.buttonStyle(.borderedProminent)
            } else if step == 1 {
                Eyebrow(text: isOnboarding ? "1 / 2 · 关于你" : "个人资料")
                Picker("实际周岁", selection: $edited.age) {
                    ForEach(18...100, id: \.self) { Text("\($0) 岁").tag($0) }
                }.frame(height: 76)
                Picker("研究常模", selection: $edited.referenceSex) {
                    ForEach(ReferenceSex.allCases, id: \.self) { Text($0.title).tag($0) }
                }.frame(height: 76)
                SmallNote(text: "按生理性别常模比较；可不选择。")
                Button("下一步") { advance() }.buttonStyle(.borderedProminent)
            } else {
                Eyebrow(text: "2 / 2 · 由你掌控")
                Toggle("暂停年龄换算", isOn: $edited.referenceNotApplicable).font(.caption)
                SmallNote(text: "孕期、心肺疾病或影响心率的药物使用者，请暂停。")
                NavigationLink(value: AppRoute.eligibility) {
                    MenuRow(title: "适用范围", symbol: "info.circle", color: Palette.amber)
                }.buttonStyle(SpringPress())
                SmallNote(text: "只读取健康记录，在手表处理。")
                Button(isOnboarding ? "保存并授权" : "保存") {
                    Task {
                        await model.saveProfile(edited, requestAccess: isOnboarding)
                        if !isOnboarding && model.errorMessage == nil { dismiss() }
                    }
                }.buttonStyle(.borderedProminent).disabled(model.isLoading)
                Button("上一步") { step = 1 }.buttonStyle(.plain).font(.caption)
            }
        }
        .onAppear {
            guard !prepared else { return }
            edited = model.profile
            step = isOnboarding ? 0 : 1
            prepared = true
        }
        .navigationTitle(isOnboarding ? "你好，Aevum" : "我的资料")
    }

    private func advance() {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { step += 1 }
    }
}
