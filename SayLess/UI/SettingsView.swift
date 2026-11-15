import SwiftUI
import SayLessEngine

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(Updates.self) private var updates
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("haptics") private var haptics = true
    @State private var rack: Side?
    @State private var confirmDelete = false
    @State private var removing: PackInstaller.Pack?
    @State private var sizes: [PackInstaller.Pack: Int64] = [:]

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    languageRow("I speak", model.me, .me)
                    languageRow("They speak", model.them, .them)
                    if !model.destinations.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(model.destinations, id: \.self) { code in
                                    if let lang = Language.named(code) {
                                        Button {
                                            if code == model.myLanguage { model.myLanguage = model.theirLanguage }
                                            model.theirLanguage = code
                                            Haptics.stamp()
                                        } label: {
                                            StampView(language: lang, size: 40, faded: code != model.theirLanguage)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button("Remove from trip", systemImage: "minus.circle", role: .destructive) {
                                                model.destinations.removeAll { $0 == code }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Languages")
                } footer: {
                    Text("Your trip's stamps. Tap one to talk with someone who speaks it.")
                }

                Section("Talking") {
                    Toggle("Read translations aloud", isOn: $model.voiceOn)
                    Toggle("Haptics", isOn: $haptics)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Card text")
                            Spacer()
                            Text("Aa").font(Fonts.card(17 * model.cardTextScale)).foregroundStyle(.secondary)
                        }
                        Slider(value: $model.cardTextScale, in: 0.8...1.5, step: 0.05)
                    }
                    Picker("Look", selection: $model.appearance) {
                        Text("Follow the phone").tag(0)
                        Text("Daylight").tag(1)
                        Text("Night train").tag(2)
                    }
                }

                Section {
                    packRow(.translation, "Translator", "Hunyuan MT, 33 languages")
                    packRow(.speech, "Ears", "Whisper large v3 turbo")
                    packRow(.voice, "Voice", "Qwen3 TTS, 10 languages")
                } header: {
                    Text("Packs on this phone")
                } footer: {
                    Text("Models are downloaded once from Hugging Face and run entirely on this iPhone. They are not backed up to iCloud.")
                }

                Section {
                    Toggle("Keep a shoebox of cards", isOn: $model.saveHistory)
                    NavigationLink {
                        ShoeboxView()
                    } label: {
                        LabeledContent("Open the shoebox", value: "\(model.history.cards.count)")
                    }
                    Button("Empty the shoebox", role: .destructive) { confirmDelete = true }
                        .disabled(model.history.cards.isEmpty)
                } header: {
                    Text("History")
                } footer: {
                    Text("The shoebox lives only on this phone, encrypted while it's locked.")
                }

                Section("Privacy") {
                    privacyLine("mic", "The microphone is on only while you hold the button.")
                    privacyLine("iphone", "Speech, translation and voice all run on this phone. Nothing you say is uploaded.")
                    privacyLine("person.crop.circle.badge.xmark", "No account, no analytics, no ads, no tracking.")
                    privacyLine("network", "The internet is used only to download the packs and to check GitHub for updates.")
                }

                Section("Updates") {
                    LabeledContent("This version", value: updates.current)
                    if updates.isNewer, let tag = updates.latest?.tag_name {
                        Button {
                            if let url = updates.installURL { openURL(url) }
                        } label: {
                            Label("Install \(tag) with SideStore", systemImage: "arrow.down.circle.fill")
                        }
                        if let notes = updates.latest?.body, !notes.isEmpty {
                            Text(notes).font(.footnote).foregroundStyle(.secondary).lineLimit(6)
                        }
                    } else {
                        Button {
                            Task { await updates.check() }
                        } label: {
                            HStack {
                                Text(updates.latest == nil ? "Check for updates" : "Up to date. Check again")
                                Spacer()
                                if updates.checking { ProgressView() }
                            }
                        }
                        if let error = updates.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
                    }
                }

                Section {
                    NavigationLink("Diagnostics") { DiagnosticsView() }
                    Button("Write the first postcard again") {
                        dismiss()
                        model.onboarded = false
                    }
                } footer: {
                    Text("Say Less · made for the road")
                        .font(Fonts.hand(18))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 18)
                }
            }
            .scrollContentBackground(.hidden)
            .background { LinenTable().ignoresSafeArea() }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .sheet(item: $rack) { RackView(side: $0) }
            .confirmationDialog("Empty the shoebox?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete all \(model.history.cards.count) cards", role: .destructive) { model.history.deleteAll() }
            } message: {
                Text("This can't be undone.")
            }
            .confirmationDialog("Remove this pack?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    if let p = removing { model.remove(p); sizes[p] = 0 }
                }
            } message: {
                Text("You can download it again later.")
            }
            .task { await measure() }
            .onChange(of: PackInstaller.Pack.allCases.map { model.packs[$0]?.installed == true }) { Task { await measure() } }
        }
        .tint(Palette.terracotta)
    }

    private func languageRow(_ title: String, _ lang: Language, _ side: Side) -> some View {
        Button {
            rack = side
        } label: {
            HStack {
                Text(title).foregroundStyle(.primary)
                Spacer()
                Text(lang.nativeName).foregroundStyle(.secondary)
                StampView(language: lang, size: 28)
            }
        }
    }

    private func packRow(_ pack: PackInstaller.Pack, _ name: String, _ detail: String) -> some View {
        let state = model.packs[pack] ?? PackState()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                    Text(state.status.isEmpty ? detail : state.status).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let p = state.progress {
                    Text("\(Int(p * 100))%").monospacedDigit().foregroundStyle(.secondary)
                } else if state.installed {
                    Text(ByteCountFormatter.string(fromByteCount: sizes[pack] ?? 0, countStyle: .file))
                        .foregroundStyle(.secondary)
                    Button("Remove", systemImage: "trash") { removing = pack }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                } else {
                    Button(state.error == nil ? "Get" : "Retry") { Task { await model.install(pack) } }
                        .buttonStyle(.glass)
                }
            }
            if let p = state.progress { ProgressView(value: p) }
            if let error = state.error { Text(error).font(.caption).foregroundStyle(.red) }
        }
    }

    private func privacyLine(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text).font(.subheadline)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Palette.sea)
        }
    }

    private func measure() async {
        let result = await Task.detached(priority: .utility) {
            Dictionary(uniqueKeysWithValues: PackInstaller.Pack.allCases.map { ($0, PackInstaller.diskUsage($0)) })
        }.value
        sizes = result
    }
}
