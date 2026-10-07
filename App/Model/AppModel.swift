import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var profile: Profile
    @Published private(set) var hasProfile: Bool
    @Published private(set) var isLoading = false
    @Published private(set) var snapshot: Snapshot?
    @Published var errorMessage: String?
    @Published private(set) var needsAgeReview = false
    let isDemo: Bool
    private let reader = HealthKitReader()
    private var lastAttempt: Date?

    init() {
        #if DEBUG
        isDemo = ProcessInfo.processInfo.arguments.contains("-demo")
        #else
        isDemo = false
        #endif
        let saved = ProfileStore.load()
        profile = saved?.profile ?? Profile()
        hasProfile = saved != nil
        if let saved {
            needsAgeReview = Date().timeIntervalSince(saved.confirmedAt) > 365 * 86400
        }
        #if DEBUG
        if isDemo {
            profile = Profile(age: 42, referenceSex: .male)
            hasProfile = true
            snapshot = DemoData.snapshot()
        }
        #endif
    }

    var assessment: AgeAssessment? {
        guard !needsAgeReview, let snapshot else { return nil }
        return FitnessAge.assess(profile: profile, snapshot: snapshot)
    }

    func saveProfile(_ edited: Profile, requestAccess: Bool) async {
        guard !isLoading else { return }
        do {
            if !isDemo { try ProfileStore.save(edited) }
            profile = edited
            hasProfile = true
            needsAgeReview = false
        } catch {
            errorMessage = "无法保存设置，请解锁手表后重试。"
            return
        }
        if requestAccess { await authorizeAndRefresh() }
    }

    func authorizeAndRefresh() async {
        guard !isLoading, !isDemo else { return }
        isLoading = true
        snapshot = nil
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await reader.authorize()
            snapshot = try await reader.fetch()
            lastAttempt = Date()
        } catch { errorMessage = error.localizedDescription }
    }

    func refresh(force: Bool = false) async {
        guard hasProfile, !isLoading, !isDemo else { return }
        if !force, let lastAttempt, Date().timeIntervalSince(lastAttempt) < 60 { return }
        isLoading = true
        snapshot = nil
        errorMessage = nil
        lastAttempt = Date()
        defer { isLoading = false }
        do { snapshot = try await reader.fetch() }
        catch { errorMessage = error.localizedDescription }
    }

    func conceal() {
        // No health cache on disk; also remove on-screen readings when the scene backgrounds.
        if !isDemo { snapshot = nil; lastAttempt = nil }
    }

    func reset() {
        guard !isLoading else { return }
        do {
            if !isDemo { try ProfileStore.delete() }
            snapshot = nil
            profile = Profile()
            hasProfile = false
            needsAgeReview = false
            errorMessage = nil
            lastAttempt = nil
        } catch { errorMessage = "无法清除本地设置，请解锁手表后重试。" }
    }
}
