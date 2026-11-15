import SwiftUI
import SayLessEngine

/// The table, split across the fold. The top half is turned 180° for the person opposite;
/// in each half's own coordinates the fold is at the top and that person's hand is at the bottom.
struct ConversationView: View {
    @Environment(AppModel.self) private var model
    @State private var rackSide: Side? = DemoMode.isOn && DemoMode.screen == "rack" ? .them : nil
    @State private var showSettings = DemoMode.isOn && DemoMode.screen == "settings"
    /// Whose words are being typed. The composer is always upright at the bottom, above the keyboard.
    @State private var typingSide: Side? = DemoMode.isOn && DemoMode.screen == "typing" ? .me : nil
    @State private var draft = DemoMode.isOn && DemoMode.screen == "typing" ? "Where can I buy a train ticket?" : ""

    var body: some View {
        ZStack {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    HalfView(side: .them, edgeInset: geo.safeAreaInsets.top, rackSide: $rackSide,
                             showSettings: $showSettings, typingSide: $typingSide)
                        .rotationEffect(.degrees(180))
                    Fold()
                    HalfView(side: .me, edgeInset: geo.safeAreaInsets.bottom, rackSide: $rackSide,
                             showSettings: $showSettings, typingSide: $typingSide)
                }
                .ignoresSafeArea()   // the table never squeezes for the keyboard; the composer rises instead
            }
            .ignoresSafeArea(.keyboard)

            if let side = typingSide {
                // Tap anywhere on the table to put the keyboard away.
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .contentShape(.rect)
                    .onTapGesture { close() }
                    .transition(.opacity)
                    .accessibilityLabel("Close keyboard")
                    .accessibilityAddTraits(.isButton)
                VStack {
                    Spacer()
                    Composer(side: side, draft: $draft, onSend: { send(side) }, onClose: close)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.card, value: typingSide)
        .onChange(of: typingSide) { old, new in
            // Each person gets their own composer: don't show one side's unsent words to the other.
            if let old, let new, old != new { draft = "" }
        }
        .sheet(item: $rackSide) { side in
            RackView(side: side)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func send(_ side: Side) {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.send(text, from: side)
        draft = ""
        close()
    }

    private func close() {
        typingSide = nil
        Haptics.select()
    }
}

extension Side: Identifiable { var id: String { rawValue } }

/// The typing card: big, upright, always above the keyboard, with what you wrote in full view.
struct Composer: View {
    @Environment(AppModel.self) private var model
    let side: Side
    @Binding var draft: String
    let onSend: () -> Void
    let onClose: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        let lang = model.language(side)
        let target = model.language(side.other)
        let empty = draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                StampView(language: lang, size: 30)
                Text("\(lang.englishName) → \(target.englishName)")
                    .font(Fonts.label(15))
                    .foregroundStyle(Palette.fadedInk)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Palette.ink.opacity(0.07)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Hide keyboard")
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("", text: $draft,
                          prompt: Text("Type in \(lang.englishName)…").foregroundStyle(Palette.fadedInk), axis: .vertical)
                    .font(Fonts.card(24))
                    .foregroundStyle(Palette.ink)
                    .tint(Palette.terracotta)
                    .lineLimit(1...6)
                    .focused($focused)
                    .submitLabel(.send)
                    .onSubmit(onSend)
                    .environment(\.layoutDirection, lang.rtl ? .rightToLeft : .leftToRight)
                    .frame(minHeight: 44)
                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(empty ? Palette.ink.opacity(0.25) : Palette.terracotta))
                }
                .buttonStyle(.plain)
                .disabled(empty)
                .accessibilityLabel("Translate")
            }
        }
        .padding(18)
        .cardStock(seed: 77, lifted: true)
        .task {
            // Focus after the slide-in settles; focusing mid-transition is often ignored.
            try? await Task.sleep(for: .milliseconds(150))
            focused = true
        }
    }
}

/// One person's half of the table: their language, their stack of cards, their talk button.
struct HalfView: View {
    @Environment(AppModel.self) private var model
    let side: Side
    let edgeInset: CGFloat
    @Binding var rackSide: Side?
    @Binding var showSettings: Bool
    @Binding var typingSide: Side?

    var body: some View {
        let lang = model.language(side)
        VStack(spacing: 14) {
            HStack {
                Button {
                    rackSide = side
                    Haptics.select()
                } label: {
                    HStack(spacing: 8) {
                        StampView(language: lang, size: 26)
                        Text(lang.nativeName).font(Fonts.label(16))
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(Palette.onTable)
                    .padding(.leading, 8)
                    .padding(.trailing, 14)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityLabel("\(side == .me ? "Your" : "Their") language: \(lang.englishName). Change")

                Spacer()

                if side == .me {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Palette.onTable)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Settings")
                }
            }
            .padding(.top, 10)

            CardStack(side: side)
                .frame(maxHeight: .infinity)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    TalkCapsule(side: side)
                    Button {
                        typingSide = side
                        Haptics.select()
                    } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(Palette.onTable)
                            .frame(width: 60, height: 60)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel("Type instead")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, max(edgeInset, 12) + 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Hold to talk. Liquid Glass capsule in the speaker's stamp colour, breathing with their voice.
struct TalkCapsule: View {
    @Environment(AppModel.self) private var model
    let side: Side
    @State private var holding = false

    var body: some View {
        let lang = model.language(side)
        let tint = Palette.stamp(lang)
        HStack(spacing: 10) {
            Image(systemName: holding ? "waveform" : "mic.fill")
                .font(.system(size: 19, weight: .semibold))
                .symbolEffect(.variableColor.iterative, isActive: holding)
                .contentTransition(.symbolEffect(.replace))
            Text(lang.nativeName)
                .font(Fonts.label(17))
                .lineLimit(1)
        }
        .foregroundStyle(holding ? .white : Palette.onTable)
        .frame(maxWidth: .infinity, minHeight: 60)
        .background {
            Capsule()
                .fill(tint.gradient)
                .opacity(holding ? 1 : 0)
        }
        .overlay {
            Capsule()
                .strokeBorder(tint.opacity(0.55), lineWidth: 2 + CGFloat(model.level) * 9)
                .blur(radius: 3)
                .scaleEffect(1 + CGFloat(model.level) * 0.06)
                .opacity(holding ? 1 : 0)
        }
        .glassEffect(.regular.tint(tint.opacity(0.15)).interactive(), in: .capsule)
        .scaleEffect(holding ? 1.04 : 1)
        .animation(.stamp, value: holding)
        .contentShape(.capsule)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard !holding else { return }
                    holding = true
                    model.beginTalking(side)
                }
                .onEnded { _ in
                    holding = false
                    model.endTalking(side)
                }
        )
        .accessibilityLabel("Hold to talk in \(lang.englishName)")
        .accessibilityAddTraits(.isButton)
    }
}

/// Cards this person can read (the other person's words, translated), newest on top,
/// with their own live card above everything while they talk.
struct CardStack: View {
    @Environment(AppModel.self) private var model
    let side: Side

    var body: some View {
        let received = Array(model.cards.filter { $0.speaker == side.other }.suffix(4))
        ZStack(alignment: .top) {
            if received.isEmpty && model.live[side] == nil {
                EmptyCard(language: model.language(side))
                    .transition(.opacity)
            }
            ForEach(Array(received.enumerated()), id: \.element.id) { index, card in
                StackedCard(card: card, depth: received.count - 1 - index)
                    .transition(.asymmetric(
                        insertion: .offset(y: -360).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                        removal: .offset(y: 700).combined(with: .opacity)))
            }
            if let live = model.live[side] {
                LiveCard(card: live, scale: model.cardTextScale)
                    .rotationEffect(.degrees(live.tilt * 0.4))
                    .zIndex(10)
                    .transition(.asymmetric(
                        insertion: .offset(y: 260).combined(with: .opacity),
                        removal: .offset(y: -420).combined(with: .opacity).combined(with: .scale(scale: 0.92))))
            }
        }
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// A plain postcard that says hello in this person's language until the first message arrives.
struct EmptyCard: View {
    @Environment(AppModel.self) private var model
    let language: Language

    var body: some View {
        VStack(spacing: 12) {
            Text(language.hello)
                .font(Fonts.card(36))
                .foregroundStyle(Palette.ink)
                .environment(\.layoutDirection, language.rtl ? .rightToLeft : .leftToRight)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(model.ready ? "Hold the button and speak" : "Getting ready…")
                .font(Fonts.label(15))
                .foregroundStyle(Palette.fadedInk)
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .cardStock(seed: 21)
        .rotationEffect(.degrees(-1.2))
        .padding(.top, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(language.englishName). Hold the button below and speak.")
    }
}

/// One card in a stack. Long-press flips it; flick it up across the fold to hear it again;
/// swipe it down off the table to put it away (it stays in the shoebox).
struct StackedCard: View {
    @Environment(AppModel.self) private var model
    let card: Card
    let depth: Int
    @State private var drag: CGSize = .zero
    @State private var flipped = false

    var body: some View {
        PostcardView(card: card, flipped: flipped, lifted: drag != .zero, scale: model.cardTextScale,
                     stampOnAppear: card.date.timeIntervalSinceNow > -2) { slower in
            model.replay(card, slower: slower)
        }
        .rotationEffect(.degrees(card.tilt + Double(drag.width) / 22))
        .scaleEffect(pow(0.95, Double(depth)), anchor: .top)
        .offset(y: -CGFloat(depth) * 12)
        .offset(drag)
        .opacity(depth > 2 ? 0 : 1 - Double(depth) * 0.1)
        .brightness(-Double(depth) * 0.03)
        .zIndex(Double(-depth))
        .allowsHitTesting(depth == 0)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                withAnimation(.card) { flipped.toggle() }
                Haptics.move()
            }
        )
        .gesture(
            DragGesture(minimumDistance: 14)
                .onChanged { drag = $0.translation }
                .onEnded { value in
                    let dy = value.predictedEndTranslation.height
                    if dy > 260 {
                        Haptics.move()
                        model.dismiss(card)
                    } else if dy < -220 {
                        Haptics.stamp()
                        model.replay(card)
                        withAnimation(.card) { drag = .zero }
                    } else {
                        withAnimation(.card) { drag = .zero }
                    }
                }
        )
        .accessibilityAction(named: "Play again") { model.replay(card) }
        .accessibilityAction(named: "Play slower") { model.replay(card, slower: true) }
        .accessibilityAction(named: "Put away") { model.dismiss(card) }
    }
}

/// The fold between the two halves: a crease, the swap button, and any download in progress.
struct Fold: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.10), .white.opacity(0.10), .black.opacity(0.0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: 6)
            HStack(spacing: 10) {
                if let line = statusLine {
                    Text(line)
                        .font(Fonts.label(15))
                        .foregroundStyle(Palette.onTable)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .transition(.blurReplace)
                        .contentTransition(.numericText())
                }
                Spacer()
                Button {
                    withAnimation(.card) { model.swapSides() }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.onTable)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Swap languages")
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 50)
        .animation(.smooth, value: statusLine)
        .task(id: model.notice) {
            guard model.notice != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation { model.notice = nil }
        }
    }

    private var statusLine: String? {
        if let n = model.notice { return n }
        let busy = model.packs.values.filter { $0.progress != nil }
        if !busy.isEmpty {
            let p = model.overallProgress
            let speed = busy.compactMap(\.mbps).reduce(0, +)
            let rate = speed >= 0.5 ? " · \(Int(speed.rounded())) MB/s" : ""
            return "Downloading models · \(Int(p * 100))%\(rate)"
        }
        if !model.ready { return "Some models are missing. Open Settings." }
        return nil
    }
}
