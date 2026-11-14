import SwiftUI
import StoreKit

/// Premium: разовая покупка (non-consumable) в App Store.
enum Premium {
    static let PRODUCT_ID = "com.ariesrst.builder.app.premium"
    /// Бесплатно — 2 проекта
    static let FREE_PROJECTS = 2
    private static var product: Product?
    static var price: String?
    static func on() -> Bool { Store.get("premium") == "1" }
    private static func set(_ v: Bool) { Store.set("premium", v ? "1" : nil); UI.tick += 1 }

    static func initApp() {
        Task { @MainActor in
            await query(); await refresh(false)
            for await r in Transaction.updates { if case .verified(let t) = r, t.productID == PRODUCT_ID { set(t.revocationDate == nil); await t.finish() } }
        }
    }
    @MainActor private static func query() async {
        if let p = try? await Product.products(for: [PRODUCT_ID]).first { product = p; price = p.displayPrice; UI.tick += 1 }
    }
    /// Проверка уже купленного
    @MainActor private static func refresh(_ showMsg: Bool) async {
        var own = false
        for await r in Transaction.currentEntitlements { if case .verified(let t) = r, t.productID == PRODUCT_ID, t.revocationDate == nil { own = true } }
        if own { set(true) } else if on() { set(false) }
        if showMsg { toast(t(own ? "pmRestored" : "pmNothing")) }
    }
    static func restore(_ showMsg: Bool = false) { Task { @MainActor in if showMsg { try? await AppStore.sync() }; await refresh(showMsg) } }
    static func buy() {
        Task { @MainActor in
            if product == nil { await query() }
            guard let p = product else { toast(t("pmUnavailable")); return }
            if let r = try? await p.purchase(), case .success(let v) = r, case .verified(let t) = v { set(true); await t.finish() }
        }
    }
    /// Платная функция: Premium — сразу; иначе окно «купить или посмотреть рекламу»
    static func gate(_ feature: String, _ allowAd: Bool = true, _ action: @escaping () -> Void) {
        if on() { action() } else { UI.paywall = feature; UI.paywallAd = allowAd ? action : nil; UI.tick += 1 }
    }
    static func canAddProject() -> Bool { on() || Store.list().count < FREE_PROJECTS }
}

/// Окно Premium поверх экрана
struct PaywallOverlay: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        if let f = UI.paywall {
            ZStack {
                Color.black.opacity(0.7).ignoresSafeArea().onTapGesture { UI.paywall = nil; UI.tick += 1 }
                VStack(alignment: .leading, spacing: 4) {
                    Txt("⭐ " + T("pmTitle"), 20, C.accent, bold: true)
                    Txt(T(["limit": "pmWhyLimit", "pdf": "pmWhyPdf", "csv": "pmWhyCsv"][f] ?? "pmWhy")).padding(.vertical, 8)
                    ForEach(["pmF1", "pmF2", "pmF3", "pmF4"], id: \.self) { Txt("✓ " + T($0), 14).padding(.vertical, 2) }
                    Gap(10)
                    Txt(T("pmBuy") + (Premium.price.map { " · " + $0 } ?? ""), 15, C.onAccent, bold: true, align: .center).padding(13).frame(maxWidth: .infinity).background(C.accent).cornerRadius(24)
                        .onTapGesture { Premium.buy(); UI.paywall = nil; UI.tick += 1 }
                    if let act = UI.paywallAd { OBtn("🎬 " + T("pmWatchAd"), full: true) { UI.paywall = nil; UI.paywallAd = nil; AdManager.showRewarded(act) }.padding(.top, 2) }
                    OBtn(T("dlCancel"), C.muted, full: true) { UI.paywall = nil; UI.paywallAd = nil; UI.tick += 1 }
                }.padding(18).background(C.card).cornerRadius(16).padding(20)
            }
        }
    }
}
