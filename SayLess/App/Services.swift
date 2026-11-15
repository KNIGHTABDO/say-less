import SwiftUI
import SayLessEngine

/// The shoebox: conversation history, stored only on this phone (Application Support, not backed up).
@MainActor
@Observable
final class Shoebox {
    private(set) var cards: [Card] = []
    private let url = EnginePaths.root.appending(path: "shoebox.json")

    init() {
        if let data = try? Data(contentsOf: url), let list = try? JSONDecoder().decode([Card].self, from: data) {
            cards = list
        }
    }

    func add(_ card: Card) {
        cards.append(card)
        if cards.count > 2000 { cards.removeFirst(cards.count - 2000) }
        persist()
    }

    func delete(_ card: Card) { cards.removeAll { $0.id == card.id }; persist() }
    func deleteAll() { cards.removeAll(); persist() }

    private func persist() {
        let snapshot = cards
        let url = url
        Task.detached(priority: .utility) {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: [.atomic, .completeFileProtection])
                EnginePaths.excludeFromBackup(url)
            }
        }
    }
}

/// Checks GitHub Releases for a newer build and hands it to SideStore.
@MainActor
@Observable
final class Updates {
    struct Release: Decodable {
        let tag_name: String
        let html_url: String
        let body: String?
        let assets: [Asset]
        struct Asset: Decodable { let name: String; let browser_download_url: String }
    }

    static let repo = "KNIGHTABDO/say-less"
    var latest: Release?
    var checking = false
    var error: String?

    var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }
    var isNewer: Bool {
        guard let tag = latest?.tag_name else { return false }
        return Self.compare(String(tag.drop { $0 == "v" }), current) == .orderedDescending
    }
    var ipaURL: URL? {
        latest?.assets.first { $0.name.hasSuffix(".ipa") }.flatMap { URL(string: $0.browser_download_url) }
    }
    /// SideStore install link; falls back to the release page.
    var installURL: URL? {
        if let ipa = ipaURL?.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
           let url = URL(string: "sidestore://install?url=\(ipa)") { return url }
        return latest.flatMap { URL(string: $0.html_url) }
    }

    func check() async {
        guard !checking, !DemoMode.isOn else { return }
        checking = true
        defer { checking = false }
        do {
            var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 15
            let (data, _) = try await URLSession.shared.data(for: req)
            latest = try JSONDecoder().decode(Release.self, from: data)
            error = nil
            UserDefaults.standard.set(Date(), forKey: "lastUpdateCheck")
        } catch {
            self.error = "Couldn't reach GitHub."
        }
    }

    /// At most once a day, quietly.
    func checkIfDue() async {
        let last = UserDefaults.standard.object(forKey: "lastUpdateCheck") as? Date ?? .distantPast
        if Date().timeIntervalSince(last) > 86_400 { await check() }
    }

    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: .numeric)
    }
}

/// Launch arguments for simulator screenshots: -SLDemo YES -SLScreen <name>.
enum DemoMode {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "SLDemo") }
    static var screen: String { UserDefaults.standard.string(forKey: "SLScreen") ?? "home" }

    @MainActor
    static func apply(to model: AppModel) {
        model.myLanguage = "en"
        model.theirLanguage = "ja"
        model.destinations = ["ja", "es", "fr"]
        model.onboarded = screen != "onboarding"
        for p in PackInstaller.Pack.allCases { model.packs[p] = PackState(installed: true) }
        model.cards = [
            Card(speaker: .them, from: "ja", to: "en", original: "こんにちは。何かお探しですか？", translated: "Hello. Are you looking for something?", stage: .done, tilt: -2.2, seed: 3),
            Card(speaker: .me, from: "en", to: "ja", original: "Where is the train station?", translated: "駅はどこですか？", stage: .done, tilt: 1.8, seed: 5),
            Card(speaker: .them, from: "ja", to: "en", original: "まっすぐ行って、二つ目の角を右です。", translated: "Go straight, then turn right at the second corner.", stage: .done, tilt: -0.8, seed: 9),
        ]
        if screen == "empty" {
            // First launch on the table: nothing said yet, models still downloading.
            model.cards = []
            model.packs[.translation] = PackState(progress: 0.17, mbps: 14)
            model.packs[.speech] = PackState(progress: 0.42, mbps: 9)
            model.packs[.voice] = PackState(progress: 0.05, mbps: 6)
        }
        if screen == "live" {
            model.live[.me] = Card(speaker: .me, from: "en", to: "ja", original: "Is it far from here", stage: .listening, seed: 11)
        }
    }

    static func samplePhrase(_ code: String) -> String {
        ["ja": "ありがとうございます", "es": "¿Cuánto cuesta?", "fr": "Merci beaucoup"][code] ?? "How much is a ticket to the old town?"
    }

    static func fakeTranslation(_ text: String, to code: String) -> String {
        ["ja": "旧市街までの切符はいくらですか？", "es": "¿Cuánto cuesta un billete al casco antiguo?", "fr": "Combien coûte un billet pour la vieille ville ?", "en": "Thank you very much."][code] ?? text
    }
}
