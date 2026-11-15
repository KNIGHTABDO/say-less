import SwiftUI
import UIKit
import SayLessEngine

/// Under the hood: how fast each stage ran, memory headroom, heat, and the breadcrumb log.
/// Also a bench to time the translator on typed text.
struct DiagnosticsView: View {
    @Environment(AppModel.self) private var model
    @State private var timings: [StageTiming] = []
    @State private var translator = "none"
    @State private var loaded: [Engine.Component: Bool] = [:]
    @State private var available = 0
    @State private var footprint = 0
    @State private var thermal = ProcessInfo.processInfo.thermalState
    @State private var crumbs = ""
    @State private var input = "Where is the train station, and how much is a ticket?"
    @State private var target = "es"
    @State private var result = ""
    @State private var busy = false

    var body: some View {
        List {
            Section("Phone") {
                LabeledContent("Memory left for the app", value: "\(available) MB")
                LabeledContent("App footprint", value: "\(footprint) MB")
                LabeledContent("Heat", value: thermalName)
                LabeledContent("Translator", value: translator)
                ForEach(Engine.Component.allCases, id: \.self) { c in
                    LabeledContent(c.rawValue.capitalized, value: loaded[c] == true ? "in memory" : "asleep")
                }
            }

            Section("Bench") {
                TextField("Text", text: $input, axis: .vertical)
                Picker("Into", selection: $target) {
                    ForEach(Language.all) { Text($0.englishName).tag($0.code) }
                }
                Button {
                    Task { await bench() }
                } label: {
                    HStack {
                        Text("Translate")
                        Spacer()
                        if busy { ProgressView() }
                    }
                }
                .disabled(busy || model.packs[.translation]?.installed != true)
                if !result.isEmpty { Text(result).font(.callout).textSelection(.enabled) }
            }

            Section("Last stages") {
                if timings.isEmpty { Text("Nothing yet").foregroundStyle(.secondary) }
                ForEach(Array(timings.suffix(30).reversed().enumerated()), id: \.offset) { _, t in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(t.stage).font(.subheadline)
                            if !t.detail.isEmpty { Text(t.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                        }
                        Spacer()
                        Text("\(t.ms) ms").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Text(crumbs.isEmpty ? "Empty" : crumbs)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                Button("Copy log", systemImage: "doc.on.doc") {
                    UIPasteboard.general.string = report
                    Haptics.select()
                }
            } header: {
                Text("Breadcrumbs")
            } footer: {
                Text("A short local log of model loads, used to recover after a crash. It never leaves the phone unless you copy it.")
            }
        }
        .navigationTitle("Diagnostics")
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private var thermalName: String {
        switch thermal {
        case .nominal: "cool"
        case .fair: "warm"
        case .serious: "hot, slowing down"
        case .critical: "very hot"
        @unknown default: "unknown"
        }
    }

    private var report: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let lines = timings.suffix(30).map { "\($0.stage) \($0.ms)ms \($0.detail)" }.joined(separator: "\n")
        return "Say Less \(v) · \(UIDevice.current.systemVersion) · avail \(available)MB · translator \(translator)\n\n\(lines)\n\n\(crumbs)"
    }

    private func refresh() async {
        let engine = model.engine
        timings = await engine.timings
        translator = await engine.activeTranslationName
        for c in Engine.Component.allCases { loaded[c] = await engine.isLoaded(c) }
        available = MemoryProbe.availableMB()
        footprint = MemoryProbe.footprintMB()
        thermal = ProcessInfo.processInfo.thermalState
        crumbs = Breadcrumbs.tail(60)
    }

    private func bench() async {
        guard let lang = Language.named(target) else { return }
        busy = true
        defer { busy = false }
        do {
            let out = try await model.engine.translate(input, to: lang)
            result = "\(out.text)\n\n\(out.tokens) tokens · \(out.ms) ms · \(String(format: "%.1f", out.tokensPerSecond)) tok/s"
        } catch {
            result = "Failed: \(error.localizedDescription)"
        }
        await refresh()
    }
}
