import SwiftUI

enum AppRoute: Hashable {
    case health, metric(Metric), history(Metric), metricInfo(Metric)
    case ageDetail, sensitivity, method, references
    case settings, profile, privacy, dataStatus, eligibility
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @State private var path: [AppRoute] = []
    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if model.hasProfile { AgeOverview() }
                else { ProfileForm(isOnboarding: true) }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(route).foregroundStyle(Palette.ink).background(Palette.background)
            }
        }
        .foregroundStyle(Palette.ink).privacySensitive()
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.isDemo {
                Text("演示 · 非本人数据").font(.caption2).foregroundStyle(Palette.amber)
                    .frame(maxWidth: .infinity).padding(.vertical, 2).background(.black)
            }
        }
        .onChange(of: model.hasProfile) { _, _ in path.removeAll() }
        .alert("暂时无法完成", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } })) {
                Button("知道了") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
    }

    @ViewBuilder private func destination(_ route: AppRoute) -> some View {
        switch route {
        case .health: HealthOverview()
        case .metric(let metric): MetricDetail(metric: metric)
        case .history(let metric): MetricHistory(metric: metric)
        case .metricInfo(let metric): MetricInfo(metric: metric)
        case .ageDetail: AgeDetailView()
        case .sensitivity: SensitivityView()
        case .method: MethodView()
        case .references: ReferencesView()
        case .settings: SettingsView()
        case .profile: ProfileForm(isOnboarding: false)
        case .privacy: PrivacyView()
        case .dataStatus: DataStatusView()
        case .eligibility: EligibilityView()
        }
    }
}
