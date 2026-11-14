import SwiftUI

/// Реклама выключена (как на Android на время тестирования). Включение — отдельным шагом:
/// ADS_ENABLED = true + реальная реализация на GoogleMobileAds (пакет уже подключён) и ATT.
enum AdManager {
    static let ADS_ENABLED = false
    static let APP_ID = "ca-app-pub-9638598348702189~5806661646"
    static let BANNER_ID = "ca-app-pub-9638598348702189/2138879376"
    static let INTERSTITIAL_ID = "ca-app-pub-9638598348702189/9696650243"
    static let REWARDED_ID = "ca-app-pub-9638598348702189/1396643347"
    static let NO_BANNER: Set<String> = ["splash", "plot", "rooms", "view3d", "staking"]
    static func noAds() -> Bool { Premium.on() }
    static func active() -> Bool { ADS_ENABLED && !noAds() }
    static func maybeInterstitial() { if !active() { return } }
    /// Ролик за вознаграждение: onReward вызывается, если досмотрели (пока рекламы нет — сразу)
    static func showRewarded(_ onReward: @escaping () -> Void) { if !ADS_ENABLED { onReward() } else { toast(t("adNotReady")) } }
}
struct AdBanner: View { var body: some View { EmptyView() } }
