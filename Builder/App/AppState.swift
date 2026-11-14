import SwiftUI

/// Счётчик обновлений интерфейса (аналог UI.tick на Android: модель — изменяемые словари, SwiftUI их не отслеживает).
final class UIS: ObservableObject { static let shared = UIS(); @Published var tick = 0; @Published var lock = false }

/// Состояние интерфейса: экран и пр.
enum UI {
    static var screen = "splash"
    static var extra: String? = nil
    static var msg: String? = nil
    static var tasMsg: String? = nil
    static var tf = "all"
    static var lv: Any? = 0.0
    static var paywall: String? = nil
    static var paywallAd: (() -> Void)? = nil
    static var room = 0.0
    static var sel = 0.0
    static var tick: Int { get { UIS.shared.tick } set { UIS.shared.tick = newValue } }
}
private let AD_EXIT: Set<String> = ["found", "walls", "roof", "finish", "eng", "extra", "fence", "estimate", "schedule", "plot", "rooms", "view3d", "staking", "price"]
func go(_ s: String, _ extra: String? = nil) {
    let from = UI.screen; UI.extra = extra; UI.screen = s; UI.tick += 1
    if s == "home" && AD_EXIT.contains(from) { AdManager.maybeInterstitial() }
}
func upd() { Store.save(); UI.tick += 1 }
func toast(_ s: String) { UI.msg = s; UI.tick += 1 }

/// Куда ведёт «назад» с каждого экрана
func backOf(_ s: String) -> String? {
    switch s {
    case "splash", "home", "lang": return nil
    case "curpick": return "lang"
    case "rates", "sizes": return UI.extra ?? "settings"
    case "price": return "estimate"
    case "templates": return "projects"
    default: return "home"
    }
}

// ---------------- Цвета ----------------
enum C {
    static let bg = Color(hex: 0x1E2328), card = Color(hex: 0x2A3038), field = Color(hex: 0x14181C), accent = Color(hex: 0xF59E0B)
    static let text = Color(hex: 0xF1F5F9), muted = Color(hex: 0x94A3B8), ok = Color(hex: 0x22C55E), warn = Color(hex: 0xEF4444), line = Color(hex: 0x334155), border = Color(hex: 0x475569)
    static let onAccent = Color(hex: 0x111827)
}
extension Color {
    init(hex: UInt32, alpha: Double = 1) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: alpha) }
}
func hexColor(_ s: String?) -> Color {
    var h = (s ?? "#888888").trimmingCharacters(in: .whitespaces); if h.hasPrefix("#") { h.removeFirst() }
    if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
    guard let v = UInt32(h.suffix(6), radix: 16) else { return .gray }
    return Color(hex: v)
}
