import SwiftUI
import SayLessEngine

/// The souvenir-shop postcard rack: turn it with a finger, tap a card to choose that language.
struct RackView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let side: Side
    @State private var focused: String?
    @State private var query = ""

    private var current: String { side == .me ? model.myLanguage : model.theirLanguage }

    private var languages: [Language] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Language.all }
        return Language.all.filter {
            $0.englishName.localizedCaseInsensitiveContains(q) || $0.nativeName.localizedCaseInsensitiveContains(q) || $0.code == q.lowercased()
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(side == .me ? "I speak…" : "They speak…")
                .font(Fonts.hand(38))
                .foregroundStyle(Palette.onTable)
                .padding(.top, 28)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 6) {
                    ForEach(languages) { lang in
                        RackCard(language: lang, selected: lang.code == current)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .rotation3DEffect(.degrees(phase.value * -42), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                                    .scaleEffect(1 - abs(phase.value) * 0.14)
                                    .opacity(1 - abs(phase.value) * 0.4)
                            }
                            .onTapGesture { choose(lang) }
                            .id(lang.code)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 100, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $focused, anchor: .center)
            .onChange(of: focused) { Haptics.select() }
            .frame(height: 290)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.onTableSoft)
                TextField("Find a language", text: $query)
                    .font(Fonts.card(18))
                    .foregroundStyle(Palette.onTable)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 18)
            .frame(height: 50)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 24)

            if let lang = focused.flatMap(Language.named) {
                Button {
                    choose(lang)
                } label: {
                    Text("Choose \(lang.englishName)")
                        .font(Fonts.label(17))
                        .padding(.horizontal, 26)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.stamp(lang))
                .contentTransition(.interpolate)
                .animation(.smooth, value: focused)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { LinenTable() }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = current }
    }

    private func choose(_ lang: Language) {
        if side == .me {
            if lang.code == model.theirLanguage { model.theirLanguage = model.myLanguage }
            model.myLanguage = lang.code
        } else {
            if lang.code == model.myLanguage { model.myLanguage = model.theirLanguage }
            model.theirLanguage = lang.code
            if !model.destinations.contains(lang.code) { model.destinations.append(lang.code) }
        }
        Haptics.stamp()
        dismiss()
    }
}

/// One postcard on the rack: the language in its own script, a hello, and whether it can speak aloud.
struct RackCard: View {
    let language: Language
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(language.englishName.uppercased())
                    .font(Fonts.label(12))
                    .tracking(1.2)
                    .foregroundStyle(Palette.fadedInk)
                Spacer()
                StampView(language: language, size: 46)
                    .rotationEffect(.degrees(3))
            }
            Spacer(minLength: 0)
            Text(language.nativeName)
                .font(Fonts.card(30))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(language.hello)
                .font(Fonts.card(18).italic())
                .foregroundStyle(Palette.sea)
                .lineLimit(1)
            Label(language.hasVoice ? "Speaks aloud" : "Read only", systemImage: language.hasVoice ? "speaker.wave.2" : "text.alignleft")
                .font(Fonts.label(13))
                .foregroundStyle(Palette.fadedInk)
        }
        .padding(16)
        .frame(width: 180, height: 250)
        .cardStock(seed: language.code.unicodeScalars.reduce(UInt64(1)) { $0 &* 31 &+ UInt64($1.value) }, lifted: selected)
        .overlay {
            if selected {
                DeckleShape(seed: 3).stroke(Palette.terracotta, lineWidth: 2.5).padding(-4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
