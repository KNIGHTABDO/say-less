import SwiftUI
import UIKit
import SayLessEngine

/// The card stock every postcard is printed on: fibred paper, deckle edge, a real shadow.
struct CardStock: ViewModifier {
    var seed: UInt64
    var lifted = false

    func body(content: Content) -> some View {
        content
            .background {
                PaperFill(seed: seed)
                    .clipShape(DeckleShape(seed: seed))
            }
            .compositingGroup()
            .shadow(color: .black.opacity(lifted ? 0.28 : 0.18), radius: lifted ? 18 : 5, x: 0, y: lifted ? 14 : 3)
    }
}

extension View {
    func cardStock(seed: UInt64, lifted: Bool = false) -> some View { modifier(CardStock(seed: seed, lifted: lifted)) }
}

/// A finished postcard. Front: the translation, big. Back (long-press): the original, a
/// pronunciation guide, and buttons to hear it again, slower, or copy it.
struct PostcardView: View {
    let card: Card
    var flipped = false
    var lifted = false
    var scale: Double = 1
    var stampOnAppear = false
    var onReplay: (Bool) -> Void = { _ in }

    var body: some View {
        ZStack {
            front
                .opacity(flipped ? 0 : 1)
            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .cardStock(seed: card.seed, lifted: lifted)
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
    }

    private var rtl: Bool { card.toLanguage.rtl }

    private var front: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text("from \(card.fromLanguage.nativeName)")
                    .font(Fonts.hand(21))
                    .foregroundStyle(Palette.fadedInk)
                Spacer(minLength: 8)
                ZStack {
                    StampView(language: card.fromLanguage, size: 40)
                        .rotationEffect(.degrees(Double(card.seed % 7) - 3))
                    PostmarkStamp(date: card.date, animate: stampOnAppear)
                        .offset(x: -44, y: 14)
                }
            }
            Text(card.translated)
                .font(Fonts.card(30 * scale))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(rtl ? .trailing : .leading)
                .frame(maxWidth: .infinity, alignment: rtl ? .trailing : .leading)
                .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
                .minimumScaleFactor(0.45)
                .lineLimit(8)
                .textSelection(.enabled)
            Rectangle().fill(Palette.ink.opacity(0.1)).frame(height: 0.7)
            Text(card.original)
                .font(.system(size: 14 * scale, design: .serif).italic())
                .foregroundStyle(Palette.fadedInk)
                .lineLimit(2)
        }
        .padding(20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.translated). Said in \(card.fromLanguage.englishName): \(card.original)")
        .accessibilityHint("Long-press to flip the card")
    }

    private var back: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("They said, in \(card.fromLanguage.englishName)")
                .font(Fonts.label(12))
                .textCase(.uppercase)
                .foregroundStyle(Palette.fadedInk)
            Text(card.original)
                .font(Fonts.card(21 * scale))
                .foregroundStyle(Palette.ink)
                .environment(\.layoutDirection, card.fromLanguage.rtl ? .rightToLeft : .leftToRight)
                .minimumScaleFactor(0.5)
            if let guide = pronunciation {
                Text(guide)
                    .font(.system(size: 15 * scale, design: .serif).italic())
                    .foregroundStyle(Palette.sea)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            HStack(spacing: 10) {
                InkButton(title: "Slower", symbol: "tortoise") { onReplay(true) }
                InkButton(title: "Again", symbol: "speaker.wave.2") { onReplay(false) }
                InkButton(title: "Copy", symbol: "doc.on.doc") {
                    UIPasteboard.general.string = card.translated
                    Haptics.select()
                }
            }
        }
        .padding(20)
    }

    /// How to say the translation, in Latin letters, for scripts the reader may not know.
    private var pronunciation: String? {
        let code = card.to
        guard !["en", "es", "fr", "de", "it", "pt", "nl", "pl", "tr", "vi", "id", "ms", "sv", "da", "no", "fi", "cs", "ro", "hu", "tl", "sw", "ja"].contains(code),
              let latin = card.translated.applyingTransform(.toLatin, reverse: false),
              latin != card.translated else { return nil }
        return latin
    }
}

/// The postmark lands with a thud the first time a card arrives.
struct PostmarkStamp: View {
    var date: Date
    var animate: Bool
    @State private var landed = false

    var body: some View {
        Postmark(top: "SAY LESS", date: date, size: 52)
            .rotationEffect(.degrees(-14))
            .scaleEffect(landed ? 1 : 1.9)
            .opacity(landed ? 1 : 0)
            .onAppear {
                guard animate else { landed = true; return }
                withAnimation(.stamp.delay(0.22)) { landed = true }
            }
    }
}

struct InkButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(Fonts.label(13))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().strokeBorder(Palette.ink.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// The card on top of the speaker's own stack while they talk. Words settle from blur into ink
/// as they are recognised; the translation fills in underneath before the card crosses the fold.
struct LiveCard: View {
    let card: Card
    var scale: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(stageLabel)
                    .font(Fonts.hand(22))
                    .foregroundStyle(Palette.terracotta)
                    .contentTransition(.opacity)
                Spacer()
                StampView(language: card.fromLanguage, size: 34, faded: true)
            }
            if card.original.isEmpty {
                Text("…")
                    .font(Fonts.card(28 * scale))
                    .foregroundStyle(Palette.fadedInk)
                    .phaseAnimator([0.3, 1]) { v, p in v.opacity(p) } animation: { _ in .easeInOut(duration: 0.7) }
            } else {
                InkWords(text: card.original, font: Fonts.card(26 * scale))
            }
            if !card.translated.isEmpty {
                Rectangle().fill(Palette.ink.opacity(0.1)).frame(height: 0.7)
                Text(card.translated)
                    .font(Fonts.card(19 * scale))
                    .foregroundStyle(Palette.sea)
                    .environment(\.layoutDirection, card.toLanguage.rtl ? .rightToLeft : .leftToRight)
                    .contentTransition(.opacity)
                    .lineLimit(4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .cardStock(seed: card.seed, lifted: true)
        .animation(.smooth(duration: 0.45), value: card.original)
        .animation(.smooth(duration: 0.3), value: card.translated)
        .animation(.smooth, value: card.stage)
        .accessibilityElement(children: .combine)
    }

    private var stageLabel: String {
        switch card.stage {
        case .listening: "listening…"
        case .hearing: "writing it down…"
        case .translating: "translating…"
        case .done: "sent"
        case .failed: "couldn't catch that"
        }
    }
}

/// Words that arrive one by one, each settling from a soft blur into ink.
struct InkWords: View {
    let text: String
    let font: Font

    var body: some View {
        let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        WordFlow(spacing: 7, lineSpacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                Text(word)
                    .font(font)
                    .foregroundStyle(Palette.ink)
                    .transition(.blurReplace)
            }
        }
        .animation(.smooth(duration: 0.5), value: words.count)
    }
}

/// Left-to-right wrapping layout for words of different widths.
struct WordFlow: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let r = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? r.maxWidth, height: r.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let r = arrange(width: bounds.width, subviews: subviews)
        for i in subviews.indices {
            subviews[i].place(at: CGPoint(x: bounds.minX + r.points[i].x, y: bounds.minY + r.points[i].y),
                              proposal: ProposedViewSize(r.sizes[i]))
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (points: [CGPoint], sizes: [CGSize], height: CGFloat, maxWidth: CGFloat) {
        var points: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, maxWidth: CGFloat = 0
        for view in subviews {
            var size = view.sizeThatFits(.unspecified)
            if size.width > width { size = view.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            sizes.append(size)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxWidth = max(maxWidth, x - spacing)
        }
        return (points, sizes, y + lineHeight, maxWidth)
    }
}
