import SwiftUI
import SayLessEngine

@main
struct SayLessApp: App {
    var body: some Scene {
        WindowGroup { BenchView() }
    }
}

/// First-build bench: installs the packs and runs typed text through the translator,
/// so the models can be checked on the iPhone before the Postcards UI lands.
struct BenchView: View {
    @State private var engine = Engine()
    @State private var log: [String] = []
    @State private var progress: Double = 0
    @State private var busy = false
    @State private var input = "Where is the train station?"
    @State private var target = "es"

    var body: some View {
        NavigationStack {
            List {
                Section("Packs") {
                    Button("Install translation (~1.1 GB)") { run { try await PackInstaller.installTranslation(gpu: true, progress: setProgress, status: say) } }
                    Button("Install speech (~630 MB)") { run { try await PackInstaller.installSpeech(progress: setProgress) } }
                    Button("Install voice (~1 GB)") { run { try await PackInstaller.installVoice(progress: setProgress) } }
                    if busy { ProgressView(value: progress) }
                }
                Section("Translate") {
                    TextField("Text", text: $input, axis: .vertical)
                    Picker("To", selection: $target) {
                        ForEach(Language.all, id: \.code) { Text($0.nativeName).tag($0.code) }
                    }
                    Button("Translate") {
                        run {
                            let lang = Language.named(target)!
                            let out = try await engine.translate(input, to: lang)
                            say("\(out.text)  · \(out.ms) ms, \(String(format: "%.1f", out.tokensPerSecond)) tok/s")
                        }
                    }
                }
                Section("Log") {
                    ForEach(Array(log.enumerated().reversed()), id: \.offset) { Text($0.element).font(.footnote.monospaced()) }
                    Text("Free memory: \(MemoryProbe.availableMB()) MB").font(.footnote)
                }
            }
            .navigationTitle("Say Less")
            .onAppear {
                if let stage = Breadcrumbs.unfinishedStage() { say("Last run stopped during \(stage)") }
            }
        }
    }

    private func say(_ s: String) { Task { @MainActor in log.append(s) } }
    private func setProgress(_ p: Double) { Task { @MainActor in progress = p } }

    private func run(_ work: @escaping () async throws -> Void) {
        busy = true; progress = 0
        Task {
            do { try await work() } catch { say("Error: \(error.localizedDescription)") }
            busy = false
        }
    }
}
