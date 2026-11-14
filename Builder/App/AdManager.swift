import SwiftUI
import UIKit
import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// Реклама выключена на время тестирования (как на Android). Для релиза: ADS_ENABLED = true.
enum AdManager {
    static let ADS_ENABLED = false
    static let APP_ID = "ca-app-pub-9638598348702189~5806661646"
    static let BANNER_ID = "ca-app-pub-9638598348702189/2138879376"
    static let INTERSTITIAL_ID = "ca-app-pub-9638598348702189/9696650243"
    static let REWARDED_ID = "ca-app-pub-9638598348702189/1396643347"
    static let INTER_GAP: TimeInterval = 180
    static let NO_BANNER: Set<String> = ["splash", "plot", "rooms", "view3d", "staking"]
    private static var started = false
    private static var inter: InterstitialAd?
    private static var rewarded: RewardedAd?
    private static var lastInter = Date()
    private static var delegate = FSDelegate()

    static func noAds() -> Bool { Premium.on() }
    static func active() -> Bool { ADS_ENABLED && started && !noAds() }

    static func topVC() -> UIViewController? {
        guard var vc = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first?.rootViewController else { return nil }
        while let p = vc.presentedViewController { vc = p }; return vc
    }
    /// Запуск: согласие (UMP) → ATT → SDK
    static func initialize() {
        if !ADS_ENABLED { return }
        Task { @MainActor in
            let params = RequestParameters()
            do { try await ConsentInformation.shared.requestConsentInfoUpdate(with: params)
                 if let vc = topVC() { try await ConsentForm.loadAndPresentIfRequired(from: vc) } } catch {}
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined { _ = await ATTrackingManager.requestTrackingAuthorization() }
            if ConsentInformation.shared.canRequestAds { start() }
        }
    }
    private static func start() {
        if started { return }; started = true
        MobileAds.shared.start(completionHandler: nil); loadInter(); loadRewarded(); UI.tick += 1
    }
    private static func loadInter() {
        if noAds() { return }
        InterstitialAd.load(with: INTERSTITIAL_ID, request: Request()) { ad, _ in inter = ad }
    }
    private static func loadRewarded() { RewardedAd.load(with: REWARDED_ID, request: Request()) { ad, _ in rewarded = ad } }

    /// Межстраничная — при возврате на главную, не чаще INTER_GAP
    static func maybeInterstitial() {
        if !active() { return }
        guard let ad = inter, let vc = topVC() else { loadInter(); return }
        if Date().timeIntervalSince(lastInter) < INTER_GAP { return }
        delegate.onDismiss = { inter = nil; lastInter = Date(); loadInter() }; ad.fullScreenContentDelegate = delegate
        lastInter = Date(); ad.present(from: vc)
    }
    /// Ролик за вознаграждение: onReward вызывается, если досмотрели (без рекламы — сразу)
    static func showRewarded(_ onReward: @escaping () -> Void) {
        if !ADS_ENABLED { onReward(); return }
        guard let ad = rewarded, let vc = topVC() else { loadRewarded(); toast(t("adNotReady")); return }
        delegate.onDismiss = { rewarded = nil; loadRewarded() }; ad.fullScreenContentDelegate = delegate
        ad.present(from: vc) { onReward(); UI.tick += 1 }
    }
    /// Кнопка «Конфиденциальность» (UMP)
    static func privacyRequired() -> Bool { ADS_ENABLED && ConsentInformation.shared.privacyOptionsRequirementStatus == .required }
    static func showPrivacy() { guard let vc = topVC() else { return }; Task { @MainActor in try? await ConsentForm.presentPrivacyOptionsForm(from: vc) } }
}
final class FSDelegate: NSObject, FullScreenContentDelegate {
    var onDismiss: () -> Void = {}
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { onDismiss() }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) { onDismiss() }
}

struct AdBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let w = UIScreen.main.bounds.width
        let v = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: w))
        v.adUnitID = AdManager.BANNER_ID; v.rootViewController = AdManager.topVC(); v.load(Request()); return v
    }
    func updateUIView(_ v: BannerView, context: Context) {}
}
struct AdBanner: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        if AdManager.active() && !AdManager.NO_BANNER.contains(UI.screen) { AdBannerView().frame(height: 60) }
    }
}
