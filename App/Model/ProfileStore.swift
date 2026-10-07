import Foundation

struct SavedProfile: Codable {
    var profile: Profile
    var confirmedAt: Date
}

enum ProfileStore {
    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile.json")
    }
    static func load() -> SavedProfile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SavedProfile.self, from: data)
    }
    static func save(_ profile: Profile) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(SavedProfile(profile: profile, confirmedAt: Date()))
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        var file = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try file.setResourceValues(values)
    }
    static func delete() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
