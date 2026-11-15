import SwiftUI
import SayLessEngine

/// The table, split across the fold. The top half is turned 180° for the person opposite;
/// in each half's own coordinates the fold is at the top and that person's hand is at the bottom.
struct ConversationView: View {
    @Environment(AppModel.self) private var model
    @State private var rackSide: Side?
    @State private var showSettings = DemoMode.isOn && DemoMode.screen == "settings"

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                HalfView(side: .them, edgeInset: geo.safeAreaInsets.top, rackSide: $rackSide, showSettings: $showSettings)
                    .rotationEffect(.degrees(180))
                Fold()
                HalfView(side: .me, edgeInset: geo.safeAreaInsets.bottom, rackSide: $rackSide, showSettings: $showSettings)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $rackSide) { side in
            RackView(side: side)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

extension Side: Identifiable { var id: String { rawValue } }

/// One person's half of the table: their language, their stack of cards, their talk button.
struct HalfView: View {
    @Environment(AppModel.self) private var model
    let side: Side
    let edgeInset: CGFloat
    @Binding var rackSide: Side?
    @Binding var showSettings: Bool
    @State private var typing = false
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        let lang = model.language(side)
        VStack(spacing: 14) {
            HStack {
                Button {
                    rackSide = side
                    Haptics.select()
                } label: {
                    HStack(spacing: 8) {
                        StampView(language: lang, size: 22)
                        Text(lang.nativeName).font(Fonts.label(15))
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(Palette.ink)
                    .padding(.leading, 6)
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
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 40, height: 40)
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
                    if typing {
                        TextField("Type in \(lang.englishName)", text: $draft, axis: .vertical)
                            .font(Fonts.card(18))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1...3)
                            .focused($fieldFocused)
                            .submitLabel(.send)
                            .onSubmit(send)
                            .padding(.horizontal, 20)
                            .frame(minHeight: 60)
                            .glassEffect(.regular, in: .capsule)
                        Button(action: send) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.tint(Palette.stamp(lang)).interactive(), in: .circle)
                        .accessibilityLabel("Translate")
                    } else {
                        TalkCapsule(side: side)
                    }
                    Button {
                        withAnimation(.card) { typing.toggle() }
                        fieldFocused = typing
                        Haptics.select()
                    } label: {
                        Image(systemName: typing ? "mic" : "keyboard")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Palette.ink)
                            .frame(width: 60, height: 60)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .accessibilityLabel(typing ? "Speak instead" : "Type instead")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, max(edgeInset, 12) + 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func send() {
        model.send(draft, from: side)
        draft = ""
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
        .foregroundStyle(holding ? .white : Palette.ink)
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

/// A blank card that says hello in this person's language until the first message arrives.
struct EmptyCard: View {
    let language: Language

    var body: some View {
        VStack(spacing: 10) {
            Text(language.hello)
                .font(Fonts.card(34))
                .foregroundStyle(Palette.fadedInk)
                .environment(\.layoutDirection, language.rtl ? .rightToLeft : .leftToRight)
            Image(systemName: "hand.point.down")
                .font(.system(size: 20))
                .foregroundStyle(Palette.fadedInk.opacity(0.7))
                .symbolEffect(.bounce, options: .repeat(.periodic(delay: 2.5)))
        }
        .frame(maxWidth: .infinity, minHeight: 170)
        .background {
            DeckleShape(seed: 21)
                .stroke(Palette.ink.opacity(0.18), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
        }
        .rotationEffect(.degrees(-1.2))
        .padding(.top, 20)
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
                .fill(LinearGradient(colors: [.black.opacity(0.0), .black.opacity(0.08), .white.opacity(0.18), .black.opacity(0.0)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(height: 6)
            HStack(spacing: 10) {
                if let line = statusLine {
                    Text(line)
                        .font(Fonts.label(12))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassEffect(.regular, in: .capsule)
                        .transition(.blurReplace)
                        .id(line)
                }
                Spacer()
                Button {
                    withAnimation(.card) { model.swapSides() }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .accessibilityLabel("Swap languages")
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 44)
        .animation(.smooth, value: statusLine)
        .task(id: model.notice) {
            guard model.notice != nil else { return }
            try? await Task.sleep(for: .seconds(4))
            withAnimation { model.notice = nil }
        }
    }

    private var statusLine: String? {
        if let n = model.notice { return n }
        let order: [(PackInstaller.Pack, String)] = [(.translation, "translator"), (.speech, "ears"), (.voice, "voice")]
        for (pack, name) in order {
            if let p = model.packs[pack]?.progress {
                return "Packing the \(name) · \(Int(p * 100))%"
            }
        }
        if !model.ready { return "Some packs are missing. Open Settings." }
        return nil
    }
}
