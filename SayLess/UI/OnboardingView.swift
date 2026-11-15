import SwiftUI
import SayLessEngine

/// "Dear me…": a postcard to yourself that does the real setup.
/// 1. the ink writes the opening; 2. destinations become stamps; 3. permission + packing;
/// 4. the card flips and the first real translation comes back; 5. postmark, and you're in.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var step = Step.writing
    @State private var line1: CGFloat = 0
    @State private var line2: CGFloat = 0
    @State private var picked: [String] = []
    @State private var flipped = false
    @State private var first = ""
    @State private var stamped = false

    enum Step: Int { case writing, stamps, permission, packing, done }

    private var firstLanguage: Language? { picked.first.flatMap(Language.named) }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)
            letter
                .padding(.horizontal, 22)
                .rotationEffect(.degrees(-1.6))
            Spacer(minLength: 8)
            controls
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
        }
        .background(alignment: .top) { hero }
        .task { await write() }
        .onChange(of: model.packs[.translation]?.installed) { _, installed in
            if installed == true, step == .packing { Task { await firstTranslation() } }
        }
    }

    // MARK: The painting behind the card

    @Environment(\.colorScheme) private var scheme
    @State private var drift = false

    /// A painted coastline at the top of the table that fades into the linen. It drifts slowly while you write.
    private var hero: some View {
        Image("OnboardingHero")
            .resizable()
            .scaledToFill()
            .frame(height: 420)
            .scaleEffect(drift ? 1.06 : 1, anchor: .center)
            .offset(y: drift ? -6 : 0)
            .clipped()
            .mask(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.55),
                                         .init(color: .clear, location: 1)], startPoint: .top, endPoint: .bottom))
            .opacity(scheme == .dark ? 0.55 : 0.95)
            .saturation(scheme == .dark ? 0.7 : 1)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) { drift = true } }
    }

    // MARK: The postcard

    private var letter: some View {
        ZStack {
            front
                .opacity(flipped ? 0 : 1)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: 330, alignment: .topLeading)
        .cardStock(seed: 42, lifted: true)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: flipped)
    }

    private var front: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Dear me,")
                        .font(Fonts.hand(44))
                        .mask(alignment: .leading) { Rectangle().scaleEffect(x: line1, y: 1, anchor: .leading) }
                    Text("on this trip I'll be talking in…")
                        .font(Fonts.hand(25))
                        .mask(alignment: .leading) { Rectangle().scaleEffect(x: line2, y: 1, anchor: .leading) }
                }
                .foregroundStyle(Palette.ink)
                Spacer(minLength: 6)
                stampCorner
            }
            Text(first.isEmpty ? picked.compactMap { Language.named($0)?.nativeName }.joined(separator: ", ") : first)
                .font(Fonts.card(first.isEmpty ? 28 : 24))
                .foregroundStyle(Palette.sea)
                .environment(\.layoutDirection, !first.isEmpty && firstLanguage?.rtl == true ? .rightToLeft : .leftToRight)
                .contentTransition(.interpolate)
                .animation(.smooth, value: picked)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Text("— \(model.me.nativeName)")
                    .font(Fonts.hand(22))
                    .foregroundStyle(Palette.fadedInk)
                    .opacity(line2 > 0.99 ? 1 : 0)
            }
        }
        .padding(22)
    }

    private var stampCorner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Palette.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: 58, height: 68)
                .opacity(picked.isEmpty ? 1 : 0)
            ForEach(Array(picked.enumerated()), id: \.element) { i, code in
                if let lang = Language.named(code) {
                    StampView(language: lang, size: 50)
                        .rotationEffect(.degrees(Double((i * 37) % 13) - 6))
                        .offset(x: CGFloat(-i) * 16, y: CGFloat(i) * 9)
                        .transition(.asymmetric(insertion: .scale(scale: 2.4).combined(with: .opacity), removal: .opacity))
                }
            }
            if stamped {
                Postmark(top: "SAY LESS", date: .now, size: 70)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -46, y: 30)
                    .transition(.scale(scale: 2).combined(with: .opacity))
            }
        }
        .frame(width: 70, height: 80)
    }

    private var back: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(first.isEmpty ? "Packing your bags" : "Your first postcard")
                .font(Fonts.hand(32))
                .foregroundStyle(Palette.ink)
            if first.isEmpty {
                PackTags()
                Text("About 2.8 GB, downloaded once. Everything stays on this phone. Wi‑Fi is best.")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundStyle(Palette.fadedInk)
            } else {
                Text(first)
                    .font(Fonts.card(30))
                    .foregroundStyle(Palette.ink)
                    .environment(\.layoutDirection, firstLanguage?.rtl == true ? .rightToLeft : .leftToRight)
                    .transition(.blurReplace)
                Text("That was translated on your phone, offline.")
                    .font(.system(size: 13, design: .serif).italic())
                    .foregroundStyle(Palette.fadedInk)
            }
            Spacer(minLength: 0)
        }
        .padding(22)
        .animation(.smooth(duration: 0.6), value: first)
    }

    // MARK: Controls under the card

    @ViewBuilder
    private var controls: some View {
        switch step {
        case .writing:
            Color.clear.frame(height: 120)
        case .stamps:
            VStack(spacing: 16) {
                HStack {
                    Text("I speak")
                        .font(Fonts.hand(24))
                        .foregroundStyle(Palette.ink)
                    Menu {
                        ForEach(Language.all) { lang in
                            Button(lang.nativeName) { model.myLanguage = lang.code; picked.removeAll { $0 == lang.code } }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(model.me.nativeName).font(Fonts.label(15))
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.interactive(), in: .capsule)
                    }
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: [GridItem(.fixed(64)), GridItem(.fixed(64))], spacing: 14) {
                        ForEach(Language.all.filter { $0.code != model.myLanguage }) { lang in
                            Button { toggle(lang) } label: {
                                StampView(language: lang, size: 50, faded: !picked.contains(lang.code))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(picked.contains(lang.code) ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                }
                .frame(height: 150)
                primary(picked.isEmpty ? "Tap the stamps of where you're going" : "Seal it") {
                    withAnimation(.card) { step = .permission }
                }
                .disabled(picked.isEmpty)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .permission:
            VStack(spacing: 14) {
                Text("P.S. I only listen while you hold the button. Nothing you say leaves this phone.")
                    .font(Fonts.card(18))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                primary("Let it listen") {
                    Task {
                        _ = await Recorder.requestPermission()
                        startPacking()
                    }
                }
                Button("Not now") { startPacking() }
                    .font(Fonts.label(15))
                    .foregroundStyle(Palette.fadedInk)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        case .packing, .done:
            VStack(spacing: 12) {
                primary(first.isEmpty ? "Start while it packs" : "Start talking") { finish() }
                if first.isEmpty {
                    Text("You can start now. Talking works once the ears and translator are packed.")
                        .font(.system(size: 13, design: .serif).italic())
                        .foregroundStyle(Palette.fadedInk)
                        .multilineTextAlignment(.center)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Fonts.label(17))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(Palette.terracotta)
        .controlSize(.large)
    }

    // MARK: Flow

    private func write() async {
        guard step == .writing else { return }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeInOut(duration: 1.1)) { line1 = 1 }
        try? await Task.sleep(for: .milliseconds(1100))
        withAnimation(.easeInOut(duration: 1.6)) { line2 = 1 }
        try? await Task.sleep(for: .milliseconds(1500))
        withAnimation(.card) { step = .stamps }
    }

    private func toggle(_ lang: Language) {
        withAnimation(.stamp) {
            if let i = picked.firstIndex(of: lang.code) {
                picked.remove(at: i)
            } else if picked.count < 6 {
                picked.append(lang.code)
                Haptics.stamp()
            }
        }
    }

    private func startPacking() {
        model.destinations = picked
        if let first = picked.first { model.theirLanguage = first }
        withAnimation(.card) { step = .packing }
        flipped = true
        Haptics.move()
        model.installAll()
        if model.packs[.translation]?.installed == true || model.demo { Task { await firstTranslation() } }
    }

    private func firstTranslation() async {
        guard first.isEmpty, let lang = firstLanguage else { return }
        let sentence = "Dear me, I can't wait for this trip."
        if model.demo {
            first = DemoMode.fakeTranslation(sentence, to: lang.code)
        } else if let out = try? await model.engine.translate(sentence, to: lang) {
            first = out.text
        } else {
            return
        }
        // Let it be read on the back, then turn the card over and postmark the front, where it stays.
        try? await Task.sleep(for: .milliseconds(2200))
        flipped = false
        try? await Task.sleep(for: .milliseconds(750))
        withAnimation(.stamp) { stamped = true }
        Haptics.stamp()
        withAnimation(.card) { step = .done }
    }

    private func finish() {
        Haptics.move()
        withAnimation(.settle) { model.onboarded = true }
    }
}

/// Luggage tags for the three packs, filling in as they download.
struct PackTags: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tag(.translation, "Translator", "Hunyuan MT · 1.1 GB")
            tag(.speech, "Ears", "Whisper large v3 · 630 MB")
            tag(.voice, "Voice", "Qwen3 TTS · 1 GB")
        }
    }

    private func tag(_ pack: PackInstaller.Pack, _ name: String, _ detail: String) -> some View {
        let state = model.packs[pack] ?? PackState()
        return Button {
            guard state.error != nil, !state.installed else { return }
            Haptics.move()
            Task { await model.install(pack) }
        } label: { tagRow(state, name, detail) }
        .buttonStyle(.plain)
        .disabled(state.error == nil || state.installed)
    }

    private func tagRow(_ state: PackState, _ name: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: state.installed ? "checkmark.seal.fill" : state.error != nil ? "exclamationmark.triangle" : "shippingbox")
                .foregroundStyle(state.installed ? Palette.olive : state.error != nil ? Palette.terracotta : Palette.fadedInk)
                .frame(width: 22)
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name).font(Fonts.label(15)).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(state.installed ? "packed" : state.progress.map { "\(Int($0 * 100))%" } ?? (state.error != nil ? "tap to retry" : "waiting"))
                        .font(Fonts.label(12))
                        .foregroundStyle(Palette.fadedInk)
                        .monospacedDigit()
                }
                GeometryReader { geo in
                    Capsule().fill(Palette.ink.opacity(0.08))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Palette.sea)
                                .frame(width: geo.size.width * (state.installed ? 1 : state.progress ?? 0))
                        }
                }
                .frame(height: 4)
                Text(state.status.isEmpty ? detail : state.status)
                    .font(.system(size: 11, design: .serif).italic())
                    .foregroundStyle(Palette.fadedInk)
            }
        }
        .animation(.smooth, value: state)
    }
}
