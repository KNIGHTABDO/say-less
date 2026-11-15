import SwiftUI
import SayLessEngine

/// Postcards palette. Two moods: "Daylight" (sun on linen) and "Night train" (dark table, warm lamp).
enum Palette {
    static func table(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.115, green: 0.105, blue: 0.098) : Color(red: 0.91, green: 0.87, blue: 0.80)
    }
    static func tableShade(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.07, green: 0.065, blue: 0.06) : Color(red: 0.78, green: 0.72, blue: 0.63)
    }
    static func paper(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.93, green: 0.89, blue: 0.81) : Color(red: 0.985, green: 0.965, blue: 0.925)
    }
    /// Ink is for paper only (cards, stamps). Text on the table or on glass uses `onTable`/`onTableSoft`.
    static let ink = Color(red: 0.17, green: 0.15, blue: 0.14)
    /// Secondary ink on paper. 0.72 keeps 4.5:1 on card stock (checked in scripts/contrast.py).
    static let fadedInk = Color(red: 0.17, green: 0.15, blue: 0.14).opacity(0.72)
    /// Text straight on the table: ink in daylight, warm cream at night.
    static let onTable = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.95, green: 0.92, blue: 0.86, alpha: 1)
        : UIColor(red: 0.17, green: 0.15, blue: 0.14, alpha: 1) })
    static let onTableSoft = Color(UIColor { $0.userInterfaceStyle == .dark
        ? UIColor(red: 0.95, green: 0.92, blue: 0.86, alpha: 0.74)
        : UIColor(red: 0.17, green: 0.15, blue: 0.14, alpha: 0.78) })
    static let terracotta = Color(red: 0.80, green: 0.36, blue: 0.27)
    static let sea = Color(red: 0.20, green: 0.42, blue: 0.55)
    static let olive = Color(red: 0.45, green: 0.48, blue: 0.27)
    static let postmark = Color(red: 0.22, green: 0.24, blue: 0.36)

    static func stamp(_ lang: Language) -> Color {
        Color(hue: lang.hue, saturation: 0.55, brightness: 0.72)
    }
}

enum Fonts {
    /// Card text: big clean serif that reads upside down across a table, in every script.
    static func card(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    /// Decoration only: "Dear…", signatures, postmarks.
    static func hand(_ size: CGFloat) -> Font { .custom("SnellRoundhand-Bold", size: size) }
    static func label(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
}

/// Shared haptics so every gesture feels the same.
@MainActor
enum Haptics {
    static let thud = UIImpactFeedbackGenerator(style: .heavy)
    static let slide = UIImpactFeedbackGenerator(style: .soft)
    static let tick = UISelectionFeedbackGenerator()
    static var enabled: Bool { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }

    static func stamp() { guard enabled else { return }; thud.impactOccurred(intensity: 1) }
    static func move() { guard enabled else { return }; slide.impactOccurred(intensity: 0.6) }
    static func select() { guard enabled else { return }; tick.selectionChanged() }
}

extension Animation {
    static let card = Animation.spring(response: 0.42, dampingFraction: 0.82)
    static let stamp = Animation.spring(response: 0.28, dampingFraction: 0.55)
    static let settle = Animation.spring(response: 0.6, dampingFraction: 0.9)
}
