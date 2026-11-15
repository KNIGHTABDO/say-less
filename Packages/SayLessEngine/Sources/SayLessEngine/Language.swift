import Foundation

/// A language the app can offer. `code` is the Whisper/ISO code used everywhere in the app.
public struct Language: Identifiable, Hashable, Codable, Sendable {
    public let code: String
    /// English name, used verbatim in the Hy-MT prompt ("Translate ... into Spanish").
    public let englishName: String
    /// Name in its own script, shown on the stamp.
    public let nativeName: String
    /// A short greeting in the language, used on postcards and in onboarding.
    public let hello: String
    /// Stamp colour hue (0...1).
    public let hue: Double
    /// Qwen3-TTS language id when a voice exists, nil = "read only".
    public let voice: String?
    /// Right-to-left script.
    public let rtl: Bool

    public var id: String { code }
    public var hasVoice: Bool { voice != nil }

    public init(_ code: String, _ englishName: String, _ nativeName: String, _ hello: String, hue: Double, voice: String? = nil, rtl: Bool = false) {
        self.code = code
        self.englishName = englishName
        self.nativeName = nativeName
        self.hello = hello
        self.hue = hue
        self.voice = voice
        self.rtl = rtl
    }

    public static func named(_ code: String) -> Language? { all.first { $0.code == code } }

    /// Languages covered end to end in v0.1: Whisper (STT) ∩ Hy-MT (translation).
    /// Voice = Qwen3-TTS 0.6B (10 languages); the rest are "read only" for now.
    public static let all: [Language] = [
        Language("en", "English", "English", "Hello", hue: 0.58, voice: "english"),
        Language("es", "Spanish", "Español", "Hola", hue: 0.03, voice: "spanish"),
        Language("fr", "French", "Français", "Bonjour", hue: 0.62, voice: "french"),
        Language("de", "German", "Deutsch", "Hallo", hue: 0.11, voice: "german"),
        Language("it", "Italian", "Italiano", "Ciao", hue: 0.30, voice: "italian"),
        Language("pt", "Portuguese", "Português", "Olá", hue: 0.36, voice: "portuguese"),
        Language("ja", "Japanese", "日本語", "こんにちは", hue: 0.97, voice: "japanese"),
        Language("zh", "Chinese", "中文", "你好", hue: 0.01, voice: "chinese"),
        Language("ko", "Korean", "한국어", "안녕하세요", hue: 0.66, voice: "korean"),
        Language("ru", "Russian", "Русский", "Здравствуйте", hue: 0.55, voice: "russian"),
        Language("ar", "Arabic", "العربية", "مرحبا", hue: 0.40, rtl: true),
        Language("tr", "Turkish", "Türkçe", "Merhaba", hue: 0.99),
        Language("th", "Thai", "ไทย", "สวัสดี", hue: 0.78),
        Language("vi", "Vietnamese", "Tiếng Việt", "Xin chào", hue: 0.08),
        Language("id", "Indonesian", "Bahasa Indonesia", "Halo", hue: 0.47),
        Language("ms", "Malay", "Bahasa Melayu", "Helo", hue: 0.50),
        Language("tl", "Filipino", "Filipino", "Kumusta", hue: 0.14),
        Language("hi", "Hindi", "हिन्दी", "नमस्ते", hue: 0.07),
        Language("bn", "Bengali", "বাংলা", "নমস্কার", hue: 0.33),
        Language("ur", "Urdu", "اردو", "السلام علیکم", hue: 0.42, rtl: true),
        Language("ta", "Tamil", "தமிழ்", "வணக்கம்", hue: 0.85),
        Language("te", "Telugu", "తెలుగు", "నమస్కారం", hue: 0.88),
        Language("mr", "Marathi", "मराठी", "नमस्कार", hue: 0.05),
        Language("gu", "Gujarati", "ગુજરાતી", "નમસ્તે", hue: 0.16),
        Language("fa", "Persian", "فارسی", "سلام", hue: 0.45, rtl: true),
        Language("he", "Hebrew", "עברית", "שלום", hue: 0.60, rtl: true),
        Language("pl", "Polish", "Polski", "Cześć", hue: 0.95),
        Language("cs", "Czech", "Čeština", "Ahoj", hue: 0.64),
        Language("nl", "Dutch", "Nederlands", "Hallo", hue: 0.09),
        Language("uk", "Ukrainian", "Українська", "Привіт", hue: 0.15),
        Language("kk", "Kazakh", "Қазақ тілі", "Сәлеметсіз бе", hue: 0.52),
        Language("mn", "Mongolian", "Монгол", "Сайн байна уу", hue: 0.70),
        Language("km", "Khmer", "ខ្មែរ", "សួស្តី", hue: 0.75),
        Language("my", "Burmese", "မြန်မာ", "မင်္ဂလာပါ", hue: 0.20),
    ]
}
