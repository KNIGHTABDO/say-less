import SwiftUI
import UIKit
import SayLessEngine

/// Which half of the table. `me` is the bottom half; `them` is the top half, rotated 180°.
enum Side: String, Codable, CaseIterable {
    case me, them
    var other: Side { self == .me ? .them : .me }
}

/// One postcard: something one person said, and its translation for the other person.
struct Card: Identifiable, Codable, Equatable {
    enum Stage: String, Codable { case listening, hearing, translating, done, failed }

    var id = UUID()
    var speaker: Side
    var from: String          // language codes
    var to: String
    var original = ""
    var translated = ""
    var stage: Stage = .listening
    var date = Date()
    var tilt: Double = .random(in: -3...3)
    var seed: UInt64 = .random(in: 1...UInt64(Int32.max))
    var ms = 0

    var fromLanguage: Language { Language.named(from) ?? Language.all[0] }
    var toLanguage: Language { Language.named(to) ?? Language.all[0] }
}

/// Status of one model pack on disk.
struct PackState: Equatable {
    var installed = false
    var progress: Double?     // non-nil while downloading
    var status = ""
    var error: String?
    /// Measured download speed in MB/s while downloading (nil until there is a reading).
    var mbps: Double?
}

@MainActor
@Observable
final class AppModel {
    // MARK: Preferences (persisted)
    var myLanguage: String { didSet { save("myLanguage", myLanguage) } }
    var theirLanguage: String { didSet { save("theirLanguage", theirLanguage) } }
    var destinations: [String] { didSet { save("destinations", destinations) } }
    var voiceOn: Bool { didSet { save("voiceOn", voiceOn) } }
    var onboarded: Bool { didSet { save("onboarded", onboarded) } }
    var saveHistory: Bool { didSet { save("saveHistory", saveHistory) } }
    var cardTextScale: Double { didSet { save("cardTextScale", cardTextScale) } }
    var appearance: Int { didSet { save("appearance", appearance) } }   // 0 system, 1 daylight, 2 night train

    // MARK: Live state
    var cards: [Card] = []
    var live: [Side: Card] = [:]
    var level: Float = 0
    var packs: [PackInstaller.Pack: PackState] = [:]
    var notice: String?
    var crashNote: String?
    let demo: Bool

    let engine = Engine()
    let history = Shoebox()
    private let recorder = Recorder()
    private let player = Player()
    private var lastAudio: [UUID: (samples: [Float], rate: Int)] = [:]
    private var partialTask: Task<Void, Never>?
    private var busy = false

    var me: Language { Language.named(myLanguage) ?? Language.all[0] }
    var them: Language { Language.named(theirLanguage) ?? Language.all[1] }
    func language(_ side: Side) -> Language { side == .me ? me : them }

    var ready: Bool { demo || (packs[.speech]?.installed == true && packs[.translation]?.installed == true) }
    var installing: Bool { packs.values.contains { $0.progress != nil } }

    init(demo: Bool = DemoMode.isOn) {
        let d = UserDefaults.standard
        self.demo = demo
        let home = Locale.current.language.languageCode?.identifier ?? "en"
        myLanguage = d.string(forKey: "myLanguage") ?? (Language.named(home) != nil ? home : "en")
        theirLanguage = d.string(forKey: "theirLanguage") ?? (home == "es" ? "en" : "es")
        destinations = d.stringArray(forKey: "destinations") ?? []
        voiceOn = d.object(forKey: "voiceOn") as? Bool ?? true
        onboarded = d.bool(forKey: "onboarded")
        saveHistory = d.object(forKey: "saveHistory") as? Bool ?? true
        cardTextScale = d.object(forKey: "cardTextScale") as? Double ?? 1
        appearance = d.integer(forKey: "appearance")
        if demo {
            DemoMode.apply(to: self)
        } else {
            if let stage = Breadcrumbs.unfinishedStage() {
                crashNote = "Last time the app closed while \(Self.describe(stage))."
                if stage == "load-voice" { voiceOn = false; crashNote! += " Voice is off for now; you can turn it back on in Settings." }
                Breadcrumbs.note("previous run died during \(stage)")
            }
            Breadcrumbs.rotate()
            refreshPacks()
        }
    }

    private func save(_ key: String, _ value: Any) { UserDefaults.standard.set(value, forKey: key) }

    static func describe(_ stage: String) -> String {
        switch stage {
        case "load-speech": "loading speech recognition"
        case "load-translation": "loading the translator"
        case "load-voice": "loading the voice"
        default: stage.replacingOccurrences(of: "-", with: " ")
        }
    }

    // MARK: - Packs

    func refreshPacks() {
        let m = InstalledManifest.load()
        packs[.speech, default: PackState()].installed = m.hasSpeech
        packs[.translation, default: PackState()].installed = m.hasTranslation
        packs[.voice, default: PackState()].installed = m.hasVoice
    }

    /// Installs whatever is missing: translation first (the first real translation needs only it), then speech, then voice.
    /// Installs whatever is missing, all packs at once (each on several connections).
    func installAll(includeVoice: Bool = true) {
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.install(.translation) }
                group.addTask { await self.install(.speech) }
                if includeVoice { group.addTask { await self.install(.voice) } }
            }
        }
    }

    /// Approximate bytes per pack, for the speed reading.
    private func packBytes(_ pack: PackInstaller.Pack) -> Double {
        let r = ModelRegistry.bundled
        switch pack {
        case .speech: return Double(r.speech.downloadMB) * 1e6
        case .translation: return Double(r.translation.first?.bytes ?? 1_133_080_448)
        case .voice: return Double(r.voice.downloadMB) * 1e6
        }
    }

    /// Progress across every pack that is downloading right now, weighted by size.
    var overallProgress: Double {
        let busy = packs.filter { $0.value.progress != nil }
        let total = busy.keys.reduce(0) { $0 + packBytes($1) }
        guard total > 0 else { return 0 }
        return busy.reduce(0) { $0 + packBytes($1.key) * ($1.value.progress ?? 0) } / total
    }

    private var meters: [PackInstaller.Pack: (time: Date, fraction: Double)] = [:]

    private func record(_ pack: PackInstaller.Pack, _ p: Double) {
        packs[pack]?.progress = p
        let now = Date()
        guard let last = meters[pack] else { meters[pack] = (now, p); return }
        let dt = now.timeIntervalSince(last.time)
        guard dt >= 1 else { return }
        let rate = max(0, p - last.fraction) * packBytes(pack) / dt / 1e6
        let old = packs[pack]?.mbps
        packs[pack]?.mbps = old.map { $0 * 0.6 + rate * 0.4 } ?? rate
        meters[pack] = (now, p)
    }

    private func updateIdleTimer() {
        UIApplication.shared.isIdleTimerDisabled = installing
    }

    func install(_ pack: PackInstaller.Pack) async {
        if demo || packs[pack]?.installed == true || packs[pack]?.progress != nil { return }
        packs[pack, default: PackState()].progress = 0
        packs[pack]?.error = nil
        packs[pack]?.mbps = nil
        meters[pack] = nil
        updateIdleTimer()   // keep the screen on: iOS pauses downloads soon after it locks
        defer { updateIdleTimer() }
        let progress: @Sendable (Double) -> Void = { p in Task { @MainActor in self.record(pack, p) } }
        let status: @Sendable (String) -> Void = { s in Task { @MainActor in self.packs[pack]?.status = s } }
        do {
            switch pack {
            case .speech:
                status("Downloading Whisper")
                try await PackInstaller.installSpeech(progress: progress)
                status("Warming up")
                try await engine.ensure(.speech)     // caches the tokenizer while online
            case .translation:
                try await PackInstaller.installTranslation(gpu: true, progress: progress, status: status)
            case .voice:
                status("Downloading voice")
                try await PackInstaller.installVoice(progress: progress)
            }
            packs[pack]?.status = ""
        } catch {
            packs[pack]?.error = error.localizedDescription
            Breadcrumbs.note("install \(pack.rawValue) failed: \(error.localizedDescription)")
        }
        packs[pack]?.progress = nil
        packs[pack]?.mbps = nil
        refreshPacks()
    }

    func remove(_ pack: PackInstaller.Pack) {
        Task {
            await engine.unloadAll()
            PackInstaller.remove(pack)
            refreshPacks()
        }
    }

    // MARK: - Talking

    func swapSides() {
        let a = myLanguage
        myLanguage = theirLanguage
        theirLanguage = a
        Haptics.move()
    }

    func beginTalking(_ side: Side) {
        guard live[side] == nil, !busy else { return }
        stopAudio()
        var card = Card(speaker: side, from: language(side).code, to: language(side.other).code)
        card.stage = .listening
        withAnimation(.card) { live[side] = card }
        Haptics.move()
        if demo { return }
        guard ready else { notice = "The models are still downloading."; live[side] = nil; return }
        do {
            recorder.onLevel = { [weak self] l in
                Task { @MainActor in guard let self else { return }; self.level = self.level * 0.6 + l * 0.4 }
            }
            try recorder.start()
        } catch {
            notice = "Microphone unavailable: \(error.localizedDescription)"
            live[side] = nil
            return
        }
        // Words appear while you speak: re-read the growing buffer about once a second.
        partialTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1100))
                guard let self, !Task.isCancelled, self.recorder.isRecording else { return }
                let audio = self.recorder.snapshot()
                guard audio.count > 16000 * 3 / 4 else { continue }
                if let text = try? await self.engine.transcribe(audio, language: card.from), !Task.isCancelled,
                   self.live[side]?.stage == .listening, !text.isEmpty {
                    self.live[side]?.original = text
                }
            }
        }
    }

    func endTalking(_ side: Side) {
        guard var card = live[side] else { return }
        partialTask?.cancel()
        level = 0
        if demo { finishDemo(side); return }
        let audio = recorder.stop()
        guard audio.count > 16000 / 3 else {
            withAnimation(.card) { live[side] = nil }
            return
        }
        busy = true
        card.stage = .hearing
        live[side] = card
        Task {
            defer { busy = false }
            let start = Date()
            do {
                let text = try await engine.transcribe(audio, language: card.from)
                guard !text.isEmpty else { withAnimation(.card) { live[side] = nil }; return }
                card.original = text
                card.stage = .translating
                live[side] = card
                let out = try await engine.translate(text, to: card.toLanguage) { partial in
                    Task { @MainActor in self.live[side]?.translated = partial }
                }
                card.translated = out.text
                card.ms = Int(Date().timeIntervalSince(start) * 1000)
                deliver(card, from: side)
                if voiceOn, let voice = card.toLanguage.voice {
                    let id = card.id
                    let spoken = try await engine.speak(out.text, voiceID: voice)
                    lastAudio[id] = (spoken.samples, spoken.sampleRate)
                    player.play(spoken.samples, sampleRate: spoken.sampleRate)
                }
            } catch {
                card.stage = .failed
                card.translated = error.localizedDescription
                withAnimation(.card) { live[side] = nil }
                notice = error.localizedDescription
            }
        }
    }

    /// Typed input (or a re-send), same pipeline without speech recognition.
    func send(_ text: String, from side: Side) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy else { return }
        var card = Card(speaker: side, from: language(side).code, to: language(side.other).code, original: text, stage: .translating)
        withAnimation(.card) { live[side] = card }
        if demo { card.translated = DemoMode.fakeTranslation(text, to: card.to); deliver(card, from: side); return }
        busy = true
        Task {
            defer { busy = false }
            let start = Date()
            do {
                let out = try await engine.translate(text, to: card.toLanguage) { partial in
                    Task { @MainActor in self.live[side]?.translated = partial }
                }
                card.translated = out.text
                card.ms = Int(Date().timeIntervalSince(start) * 1000)
                deliver(card, from: side)
                if voiceOn, let voice = card.toLanguage.voice {
                    let spoken = try await engine.speak(out.text, voiceID: voice)
                    lastAudio[card.id] = (spoken.samples, spoken.sampleRate)
                    player.play(spoken.samples, sampleRate: spoken.sampleRate)
                }
            } catch {
                withAnimation(.card) { live[side] = nil }
                notice = error.localizedDescription
            }
        }
    }

    private func deliver(_ card: Card, from side: Side) {
        var done = card
        done.stage = .done
        withAnimation(.card) {
            live[side] = nil
            cards.append(done)
        }
        Haptics.stamp()
        if saveHistory && !demo { history.add(done) }
    }

    private func finishDemo(_ side: Side) {
        guard var card = live[side] else { return }
        card.original = card.original.isEmpty ? DemoMode.samplePhrase(card.from) : card.original
        card.translated = DemoMode.fakeTranslation(card.original, to: card.to)
        deliver(card, from: side)
    }

    // MARK: - Cards

    func replay(_ card: Card, slower: Bool = false) {
        if let clip = lastAudio[card.id] {
            player.play(clip.samples, sampleRate: clip.rate, rate: slower ? 0.7 : 1)
            return
        }
        guard !demo, voiceOn, let voice = card.toLanguage.voice else { return }
        Task {
            if let spoken = try? await engine.speak(card.translated, voiceID: voice) {
                lastAudio[card.id] = (spoken.samples, spoken.sampleRate)
                player.play(spoken.samples, sampleRate: spoken.sampleRate, rate: slower ? 0.7 : 1)
            }
        }
    }

    func dismiss(_ card: Card) {
        withAnimation(.card) { cards.removeAll { $0.id == card.id } }
        lastAudio[card.id] = nil
    }

    func clearTable() {
        withAnimation(.settle) { cards.removeAll() }
        lastAudio.removeAll()
    }

    func stopAudio() { player.stop() }

    /// The phone is getting low on memory: drop the models not in use.
    func memoryWarning() {
        Breadcrumbs.note("memory warning avail=\(MemoryProbe.availableMB())MB")
        Task { await engine.unload(.voice) }
    }
}
