import SwiftUI
import SayLessEngine

/// Small deterministic random generator so procedural textures don't shimmer between redraws.
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    init(_ seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// The table: woven linen in soft daylight with a vignette. Drawn once, procedurally.
struct LinenTable: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Palette.table(scheme)
            Canvas(rendersAsynchronously: true) { ctx, size in
                var rng = SeededRandom(7)
                let threadColor = scheme == .dark ? Color.white : Color(red: 0.45, green: 0.36, blue: 0.25)
                // Weft and warp: thin uneven threads.
                var y: CGFloat = 0
                while y < size.height {
                    let a = Double.random(in: 0.02...0.07, using: &rng)
                    let h = CGFloat.random(in: 0.6...1.6, using: &rng)
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: h)), with: .color(threadColor.opacity(a)))
                    y += CGFloat.random(in: 2.2...3.6, using: &rng)
                }
                var x: CGFloat = 0
                while x < size.width {
                    let a = Double.random(in: 0.015...0.05, using: &rng)
                    let w = CGFloat.random(in: 0.6...1.4, using: &rng)
                    ctx.fill(Path(CGRect(x: x, y: 0, width: w, height: size.height)), with: .color(threadColor.opacity(a)))
                    x += CGFloat.random(in: 2.4...3.8, using: &rng)
                }
                // Slubs: short thicker bits of thread.
                for _ in 0..<Int(size.width * size.height / 900) {
                    let p = CGPoint(x: .random(in: 0...size.width, using: &rng), y: .random(in: 0...size.height, using: &rng))
                    let len = CGFloat.random(in: 4...14, using: &rng)
                    let horizontal = Bool.random(using: &rng)
                    let r = horizontal ? CGRect(x: p.x, y: p.y, width: len, height: 1.2) : CGRect(x: p.x, y: p.y, width: 1.2, height: len)
                    ctx.fill(Path(roundedRect: r, cornerRadius: 0.6), with: .color(threadColor.opacity(.random(in: 0.04...0.1, using: &rng))))
                }
            }
            // Daylight from the top left, vignette at the edges.
            RadialGradient(colors: [.white.opacity(scheme == .dark ? 0.06 : 0.22), .clear],
                           center: UnitPoint(x: 0.2, y: 0.15), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [.clear, Palette.tableShade(scheme).opacity(0.55)],
                           center: .center, startRadius: 260, endRadius: 720)
        }
        .drawingGroup()
        .ignoresSafeArea()
    }
}

/// Card stock with a deckle (torn, uneven) edge.
struct DeckleShape: Shape {
    var seed: UInt64 = 1
    var roughness: CGFloat = 1.6

    func path(in rect: CGRect) -> Path {
        var rng = SeededRandom(seed)
        var p = Path()
        let step: CGFloat = 6
        func jitter() -> CGFloat { .random(in: -roughness...roughness, using: &rng) }
        let r: CGFloat = 5
        p.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        var x = rect.minX + r
        while x < rect.maxX - r { p.addLine(to: CGPoint(x: x, y: rect.minY + jitter())); x += step }
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        var y = rect.minY + r
        while y < rect.maxY - r { p.addLine(to: CGPoint(x: rect.maxX + jitter(), y: y)); y += step }
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        x = rect.maxX - r
        while x > rect.minX + r { p.addLine(to: CGPoint(x: x, y: rect.maxY + jitter())); x -= step }
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        y = rect.maxY - r
        while y > rect.minY + r { p.addLine(to: CGPoint(x: rect.minX + jitter(), y: y)); y -= step }
        p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

/// Paper fill: warm stock with faint fibres.
struct PaperFill: View {
    var seed: UInt64 = 1
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Palette.paper(scheme)
            Canvas { ctx, size in
                var rng = SeededRandom(seed &+ 99)
                for _ in 0..<Int(size.width * size.height / 260) {
                    let p = CGPoint(x: .random(in: 0...size.width, using: &rng), y: .random(in: 0...size.height, using: &rng))
                    let a = Angle.degrees(.random(in: 0...180, using: &rng))
                    let len = CGFloat.random(in: 2...7, using: &rng)
                    var path = Path()
                    path.move(to: p)
                    path.addLine(to: CGPoint(x: p.x + cos(a.radians) * len, y: p.y + sin(a.radians) * len))
                    ctx.stroke(path, with: .color(Palette.ink.opacity(.random(in: 0.02...0.06, using: &rng))), lineWidth: 0.5)
                }
            }
            LinearGradient(colors: [.white.opacity(0.35), .clear, Color.brown.opacity(0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// A perforated postage stamp in the language's colour, showing its name in its own script.
struct StampView: View {
    let language: Language
    var size: CGFloat = 54
    var faded = false

    var body: some View {
        let color = Palette.stamp(language)
        ZStack {
            PerforatedShape(hole: size * 0.045)
                .fill(Color(white: 0.98), style: FillStyle(eoFill: true))
                .clipped()
                .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
            RoundedRectangle(cornerRadius: 2)
                .fill(color.gradient)
                .padding(size * 0.1)
            VStack(spacing: 1) {
                Text(language.nativeName)
                    .font(.system(size: size * 0.2, weight: .bold, design: .serif))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                Text(language.code.uppercased())
                    .font(.system(size: size * 0.12, weight: .heavy, design: .rounded))
                    .opacity(0.75)
            }
            .foregroundStyle(.white)
            .padding(size * 0.16)
        }
        .frame(width: size, height: size * 1.18)
        .saturation(faded ? 0 : 1)
        .opacity(faded ? 0.5 : 1)
        .accessibilityLabel("\(language.englishName) stamp")
    }
}

/// Stamp outline with half-circle perforations along every edge.
struct PerforatedShape: Shape {
    var hole: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path(rect)
        let gap = hole * 2.6
        var x = rect.minX + gap / 2
        while x < rect.maxX {
            p.addEllipse(in: CGRect(x: x - hole, y: rect.minY - hole, width: hole * 2, height: hole * 2))
            p.addEllipse(in: CGRect(x: x - hole, y: rect.maxY - hole, width: hole * 2, height: hole * 2))
            x += gap
        }
        var y = rect.minY + gap / 2
        while y < rect.maxY {
            p.addEllipse(in: CGRect(x: rect.minX - hole, y: y - hole, width: hole * 2, height: hole * 2))
            p.addEllipse(in: CGRect(x: rect.maxX - hole, y: y - hole, width: hole * 2, height: hole * 2))
            y += gap
        }
        return p
    }
}

/// The round postmark: city ring, date and wavy cancellation lines.
struct Postmark: View {
    var top: String = "SAY LESS"
    var date: Date = .now
    var size: CGFloat = 76

    var body: some View {
        ZStack {
            Circle().strokeBorder(lineWidth: 2)
            Circle().strokeBorder(lineWidth: 1).padding(size * 0.14)
            CurvedText(text: top, radius: size * 0.40, fontSize: size * 0.11)
            Text(date, format: .dateTime.day().month(.abbreviated).year(.twoDigits))
                .font(.system(size: size * 0.12, weight: .bold, design: .monospaced))
                .textCase(.uppercase)
            WavyLines()
                .stroke(lineWidth: 1.6)
                .frame(width: size * 1.6, height: size * 0.5)
                .offset(x: size * 1.05)
        }
        .frame(width: size, height: size)
        .foregroundStyle(Palette.postmark.opacity(0.78))
        .blendMode(.multiply)
        .accessibilityHidden(true)
    }
}

struct WavyLines: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 0..<4 {
            let y0 = rect.minY + rect.height * CGFloat(i) / 3
            p.move(to: CGPoint(x: rect.minX, y: y0))
            var x = rect.minX
            while x <= rect.maxX {
                p.addLine(to: CGPoint(x: x, y: y0 + sin(x / 7) * 2.6))
                x += 2
            }
        }
        return p
    }
}

/// Text set along the top of a circle.
struct CurvedText: View {
    let text: String
    let radius: CGFloat
    let fontSize: CGFloat

    var body: some View {
        let chars = Array(text)
        let spread = Double(chars.count) * Double(fontSize) * 0.95 / Double(radius)   // radians covered
        ZStack {
            ForEach(chars.indices, id: \.self) { i in
                let t = chars.count > 1 ? Double(i) / Double(chars.count - 1) : 0.5
                let angle = -spread / 2 + spread * t
                Text(String(chars[i]))
                    .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                    .offset(y: -radius)
                    .rotationEffect(.radians(angle))
            }
        }
    }
}
