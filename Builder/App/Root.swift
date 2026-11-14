import SwiftUI

struct Root: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let screen = UI.screen; let rtl = RTL_LANGS.contains(St.lang)
        ZStack(alignment: .bottom) {
            C.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                Group {
                    switch screen {
                    case "splash": Splash(); case "lang": LangPick(); case "curpick": CurPick(); case "home": Home(); case "settings": Settings()
                    case "projects": Projects(); case "templates": Templates(); case "help": Help(); case "gloss": Gloss(); case "rates": Rates(); case "sizes": Sizes(); case "price": PriceList()
                    case "plot": PlotScreen(); case "fence": FenceScreen(); case "found": NeedB { FoundScreen() }; case "walls": NeedB { WallsScreen() }; case "roof": NeedB { RoofScreen() }
                    case "finish": NeedB { FinishScreen() }; case "eng": NeedB(true) { EngScreen() }; case "extra": NeedB { ExtraScreen() }; case "estimate": EstimateScreen(); case "schedule": ScheduleScreen()
                    case "rooms": NeedB(true) { RoomsScreen() }; case "view3d": View3DScreen(); case "staking": NeedB { StakingScreen() }
                    default: Home()
                    }
                }.id(screen).frame(maxWidth: .infinity, maxHeight: .infinity)
                if screen != "splash" { AdBanner() }
            }
            PaywallOverlay()
            if let m = UI.msg {
                Txt(m, 14).padding(.horizontal, 16).padding(.vertical, 10).background(C.field).cornerRadius(12).padding(.bottom, 70).padding(.horizontal, 24)
                    .task(id: "\(m)\(u.tick)") { try? await Task.sleep(nanoseconds: 2_200_000_000); if UI.msg == m { UI.msg = nil; UI.tick += 1 } }
                    .allowsHitTesting(false)
            }
        }
        .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
        .preferredColorScheme(.dark)
        .gesture(DragGesture(minimumDistance: 30).onEnded { v in
            if v.startLocation.x < 24 && v.translation.width > 80, let b = backOf(screen) { go(b, (screen == "rates" || screen == "sizes") ? nil : UI.extra) } })
        .task(id: screen) { if screen == "splash" { try? await Task.sleep(nanoseconds: 1_500_000_000); if UI.screen == "splash" { go(Store.get("lang") != nil ? "home" : "lang") } } }
    }
}

/// Нужна хотя бы одна постройка
struct NeedB<Content: View>: View {
    @ObservedObject var u = UIS.shared
    var utilOnly = false; let content: Content
    init(_ utilOnly: Bool = false, @ViewBuilder _ content: () -> Content) { self.utilOnly = utilOnly; self.content = content() }
    var body: some View {
        let bs = buildings().filter { !utilOnly || !["poly", "open"].contains($0.o("walls")["mat"] as? String ?? "") }
        if bs.isEmpty {
            VStack(spacing: 0) { TopBar("", { go("home") }); Centered { Txt("🏗️", 56); Txt(T("noBText"), 17, align: .center).padding(.vertical, 8); Btn("📐 " + T("noBGo")) { go("plot") } } }
        } else {
            let _ = { let p = St.project; if !bs.contains(where: { num($0["id"]) == num(p["bSel"]) }) { p["bSel"] = bs[0]["id"] } }()
            content
        }
    }
}
/// текущее здание
func curB() -> Obj { let p = St.project; return buildings().first { num($0["id"]) == num(p["bSel"]) } ?? buildings()[0] }
