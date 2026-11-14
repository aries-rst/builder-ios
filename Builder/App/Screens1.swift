import SwiftUI
import UniformTypeIdentifiers

struct Splash: View {
    var body: some View {
        Centered { Txt("🏗️", 72); Txt(T("appTitle"), 34, C.accent, bold: true).padding(.top, 16); Txt(T("subtitle"), 15, align: .center).padding(.top, 8)
            Txt("ARESTI Labs", 14, C.muted, bold: true).padding(.top, 48) }
    }
}
func setLang(_ c: String) { St.lang = c; Store.set("lang", c); Store.loadLang(); UI.tick += 1 }
func setCur(_ c: String) { St.cur = c; Store.set("cur", c); syncCur(St.project); upd() }
struct LangPick: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        Centered { Txt("🌐", 56); Txt("Выберите язык\nChoose language\nTilni tanlang", 16, align: .center).padding(16)
            ForEach(Array(D.a("LANGS").enumerated()), id: \.offset) { _, l in let r = l as! Arr; Btn(r.s(1)) { setLang(r.s(0)); go("curpick") } } }
    }
}
struct CurPick: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        Centered { Txt("💱", 56); Txt(T("chooseCur"), 18, align: .center).padding(12)
            Chips { ForEach(Array(D.a("CUR").enumerated()), id: \.offset) { _, c0 in let c = c0 as! Arr; Chip("\(c.s(0)) \(c.s(1))", St.cur == c.s(0)) { setCur(c.s(0)) } } }
            Hint(T("currencyNote")); Btn(T("next") + " →") { Store.set("cur", St.cur); go("home") } }
    }
}

struct Home: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        Page {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) { Txt(T("appTitle"), 28, C.accent, bold: true); Txt(T("subtitle"), 14, C.muted) }.frame(maxWidth: .infinity, alignment: .leading)
                if !Store.hist.isEmpty { IconBtn("↶") { Store.undo() } }; IconBtn("📁") { go("projects") }; IconBtn("⚙️") { go("settings") }
            }.padding(.leading, 16).padding(.trailing, 4).padding(.top, 16)
            Sec(pad: 12) { Stat("📁 " + T("pjTitle"), (Store.list().first { ($0["id"] as? String) == Store.pid }.map { Store.title($0) } ?? "") + " ›") }.onTapGesture { go("projects") }
            Btn(T("hlTitle")) { go("help") }; Btn("📚 " + T("tpTitle"), false) { go("templates") }
            Txt(T("modules"), 15, bold: true).padding(.leading, 16).padding(.top, 16).padding(.bottom, 4)
            ForEach(Array(D.a("MODS").enumerated()), id: \.offset) { i, m0 in
                let m = m0 as! Arr
                HStack(spacing: 12) {
                    Txt(m.s(0), 28)
                    VStack(alignment: .leading, spacing: 0) { Txt("\(i + 1). \(T(m.s(1)))", 15, bold: true); Txt(T(m.s(2)), 13, C.muted) }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(14).background(C.card).cornerRadius(14).padding(.horizontal, 16).padding(.vertical, 5).contentShape(Rectangle()).onTapGesture { go(m.s(3), m.s(1)) }
            }
            Btn(T("glTitle"), false) { go("gloss") }
            CrossPromoRow()
        }
    }
}

struct Settings: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        Page {
            TopBar(T("settings"), { go("home") })
            Sec(T("language")) { Chips { ForEach(Array(D.a("LANGS").enumerated()), id: \.offset) { _, l in let r = l as! Arr; Chip(r.s(1), St.lang == r.s(0)) { setLang(r.s(0)) } } } }
            Sec(T("currency")) { Chips { ForEach(Array(D.a("CUR").enumerated()), id: \.offset) { _, c0 in let c = c0 as! Arr; Chip("\(c.s(0)) \(c.s(1))", St.cur == c.s(0)) { setCur(c.s(0)) } } }; Hint(T("currencyNote")) }
            Sec {
                OBtn("📏 " + T("szTitle"), full: true) { go("sizes") }; OBtn("🧮 " + T("rtTitle"), full: true) { go("rates") }
                OBtn(T("resetProject"), C.warn, full: true) { St.project = attach(defProject()); upd(); toast(t("resetDone")) }
            }
            Sec("⭐ " + T("pmTitle")) {
                if Premium.on() { Txt(T("pmActive"), 15, C.ok, bold: true) }
                else {
                    ForEach(["pmF1", "pmF2", "pmF3", "pmF4"], id: \.self) { Txt("✓ " + T($0), 14) }
                    OBtn(T("pmBuy") + (Premium.price.map { " · " + $0 } ?? ""), full: true) { Premium.buy() }
                }
                OBtn(T("pmRestore"), C.muted, full: true) { Premium.restore(true) }
            }
        }
    }
}

struct JSONDoc: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }
    var text: String
    init(_ t: String) { text = t }
    init(configuration: ReadConfiguration) throws { text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self) }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: Data(text.utf8)) }
}
struct Projects: View {
    @ObservedObject var u = UIS.shared
    @State private var delAsk: String? = nil; @State private var exporting = false; @State private var importing = false
    var body: some View {
        let l = Store.list().sorted { $0.n("upd") > $1.n("upd") }
        let df = DateFormatter(); let _ = { df.dateStyle = .short; df.timeStyle = .none }()
        Page {
            TopBar(T("pjTitle"), { go("home") })
            ForEach(Array(l.enumerated()), id: \.offset) { _, m in
                let id = m.s("id"); let act = id == Store.pid
                Sec(border: act) {
                    TextIn(T("pjName"), Store.title(m)) { Store.rename(id, $0) }
                    Hint("\(sotStr(m.n("sot"))) · \(fmt(m.n("nb"))) \(T("pjBuildings")) · \(T("pjUpdated")) \(df.string(from: Date(timeIntervalSince1970: m.n("upd") / 1000)))" + (act ? " · " + T("pjActive") : ""), act ? C.accent : C.muted)
                    HStack(spacing: 6) {
                        if !act { OBtn("📂 " + T("pjOpen")) { Store.open(id) } }
                        OBtn("⧉ " + T("pjCopy")) { if let p = Store.load(id) { Store.newProject(false, p) } }
                        if l.count > 1 { OBtn(delAsk == id ? "✕ " + T("pjDelSure") : "✕ " + T("pjDel"), C.warn) { if delAsk == id { Store.delete(id); delAsk = nil; UI.tick += 1 } else { delAsk = id } } }
                    }
                }
            }
            Sec(T("pjNew")) {
                HStack(spacing: 6) { OBtn("🏠 " + T("pjNewEmpty")) { Store.newProject(false) }; OBtn("🏡 " + T("pjNewDemo")) { Store.newProject(true) } }
                OBtn("📚 \(T("tpTitle")) (\(TPL().count))", full: true) { go("templates") }; Hint(T("pjHint"))
            }
            Btn(T("pjExport"), false) { exporting = true }
            Btn(T("pjImport"), false) { importing = true }
        }
        .fileExporter(isPresented: $exporting, document: JSONDoc(Json.str(St.project)), contentType: .json, defaultFilename: Store.list().first { ($0["id"] as? String) == Store.pid }.map { Store.title($0) } ?? "project") { r in if case .success = r { toast("✓") } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText, .data]) { r in
            if case .success(let url) = r {
                let ok = url.startAccessingSecurityScopedResource(); defer { if ok { url.stopAccessingSecurityScopedResource() } }
                if let d = try? Data(contentsOf: url), Store.importJson(String(decoding: d, as: UTF8.self)) {} else { toast(t("pjBadFile")) }
            }
        }
    }
}

struct Templates: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let f = UI.tf; let infos = TPL().map { ($0, tplInfo($0)) }
        let RN = ["GABLE": "roofGable", "SHED": "roofShed", "HIP": "roofHip", "MANSARD": "roofMans", "FLAT": "roofFlat"]
        Page {
            TopBar(T("tpTitle"), { go("projects") })
            Sec { Txt(T("tpIntro"), 14); Chips { ForEach(Array(D.a("TPLF").enumerated()), id: \.offset) { _, x in let r = x as! Arr; Chip(T(r.s(1)), f == r.s(0)) { UI.tf = r.s(0) } } } }
            let shown = infos.filter { tplPass(f, $0.1) }
            if shown.isEmpty { HintOut(T("tpNone")) }
            ForEach(Array(shown.enumerated()), id: \.offset) { _, e in
                let Tp = e.0, I = e.1; let W = Tp.n(2), Dd = Tp.n(3)
                Sec {
                    HStack(alignment: .top, spacing: 12) {
                        TplPreview(I: I, W: W, Dd: Dd)
                        VStack(alignment: .leading, spacing: 2) {
                            Txt(tr3(Tp.at(1)), 16, bold: true)
                            Txt(tplDesc(Tp, I, W, Dd, RN), 13, C.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    OBtn("🏗️ " + T("tpUse"), full: true) { Store.newFromTpl(Tp) }
                }
            }
        }
    }
    func tplDesc(_ Tp: Arr, _ I: TplInfo, _ W: Double, _ Dd: Double, _ RN: [String: String]) -> String {
        var s = "\(T("tpPlot")): \(fmt(W))×\(fmt(Dd)) \(T("m")) · \(sotStr(I.sot))"
        if let h = I.h {
            s += "\n\(itemName(h)): \(fmt(h.n("w")))×\(fmt(h.n("d"))) \(T("m")) · \(T("floors").lowercased()) \(fmt(h.n("floors")))" + (I.att ? " + " + T("tpAtt") : "") + (I.base ? " + " + T("tpBase") : "") + " · " + T(RN[h.s("roof")] ?? "roofGable").lowercased()
        }
        if !I.others.isEmpty { s += "\n" + I.others.map { itemName($0) }.joined(separator: ", ") }
        return s
    }
}
struct TplPreview: View {
    let I: TplInfo; let W: Double; let Dd: Double
    var body: some View {
        let k = min(150 / W, 110 / Dd)
        Canvas { ctx, size in
            let s = size.width / CGFloat(W * k + 8)
            func X(_ x: Double) -> CGFloat { CGFloat((4 + x * k)) * s }
            func Y(_ y: Double) -> CGFloat { CGFloat((4 + (Dd - y) * k)) * s }
            ctx.fill(Path(CGRect(x: X(0), y: Y(Dd), width: CGFloat(W * k) * s, height: CGFloat(Dd * k) * s)), with: .color(Color(hex: 0x365314)))
            func poly(_ ps: [Pt], _ c: Color) {
                var p = Path(); for (i, q) in ps.enumerated() { if i == 0 { p.move(to: CGPoint(x: X(q.x), y: Y(q.y))) } else { p.addLine(to: CGPoint(x: X(q.x), y: Y(q.y))) } }; p.closeSubpath()
                ctx.fill(p, with: .color(c)); ctx.stroke(p, with: .color(Color(hex: 0x111111)), lineWidth: 1)
            }
            for z in I.p.a("items").objs where eq(z["cat"], "z") {
                let c: Color; switch z.s("kind") { case "tree": c = Color(hex: 0x15803D); case "garden": c = Color(hex: 0x713F12); case "lawn": c = Color(hex: 0x4D7C0F); default: c = Color(hex: 0x78716C) }
                if z.s("kind") == "tree" { let r = CGFloat(z.n("w") / 2 * k) * s; ctx.fill(Path(ellipseIn: CGRect(x: X(z.n("cx")) - r, y: Y(z.n("cy")) - r, width: 2 * r, height: 2 * r)), with: .color(c)) } else { poly(G.corners(z), c) }
            }
            for b in I.p.a("items").objs where eq(b["cat"], "b") { poly(G.corners(b), b.oo("shape")?.b("full") == true ? Color(hex: 0x949FB8, alpha: 0.25) : (b === I.h ? C.accent : Color(hex: 0xFDBA74))) }
        }.frame(width: CGFloat(W * k + 8), height: CGFloat(Dd * k + 8)).background(Color(hex: 0x1A2E05)).cornerRadius(8)
    }
}

struct Help: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        Page {
            TopBar(T("hlTitle"), { go("home") }); Sec { Txt(T("hlIntro"), 15) }
            ForEach(Array(D.a("HELP").enumerated()), id: \.offset) { i, h0 in let h = h0 as! Arr
                Sec("\(i + 1). \(h.s(0)) \(tr3(h.at(1)))") { Txt(tr3(h.at(2)), 14) } }
            Btn(T("glTitle"), false) { go("gloss") }
        }
    }
}
func glTitle(_ k: String, _ g: Arr) -> String {
    let n = g.arr(0)!
    let v: String = St.lang == "uzc" ? cyr(n.s(2)) : (li() == 0 ? (D.o("GLT")[k] as? String ?? n.s(0)) : (isExt() ? xl(n.s(1)) : n.s(li())))
    return v.prefix(1).uppercased() + v.dropFirst()
}
struct Gloss: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        Page {
            TopBar(T("glTitle"), { go("home") }); HintOut(T("glHint"))
            ForEach(Array(D.o("GLOSS").entries.enumerated()), id: \.offset) { _, e in let g = e.1 as! Arr; Sec(glTitle(e.0, g)) { Txt(tr3(g.at(1)), 14) } }
        }
    }
}

func ratesGroups() -> [(String, [(String, Arr)])] {
    var grp: [(String, [(String, Arr)])] = []
    for (k, v) in D.RDEF.entries { let a = v as! Arr; let g = a.s(0); if let i = grp.firstIndex(where: { $0.0 == g }) { grp[i].1.append((k, a)) } else { grp.append((g, [(k, a)])) } }
    return grp
}
struct Rates: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let P = St.project.o("rates"); let grp = ratesGroups()
        let focus = ["found": "mFound", "walls": "mWalls", "roof": "mRoof", "finish": "mFinish", "fence": "mFence", "eng": "mEng"][UI.extra ?? ""]
        let order = grp.enumerated().sorted { ($0.element.0 == focus ? 0 : 1, $0.offset) < ($1.element.0 == focus ? 0 : 1, $1.offset) }.map { $0.element }
        Page {
            TopBar(T("rtTitle"), { go(UI.extra ?? "settings") }); HintOut(T("rtHint"))
            ForEach(Array(order.enumerated()), id: \.offset) { _, go1 in
                Sec(T(go1.0)) {
                    ForEach(Array(go1.1.enumerated()), id: \.offset) { _, kv in
                        let k = kv.0, v = kv.1; let def = num(v.at(1)); let changed = P[k] != nil && num(P[k]) != def
                        HStack(alignment: .bottom, spacing: 6) {
                            NumField(tr3(v.at(2)), RT(k), zero: true) { P[k] = $0 }
                            VStack(alignment: .leading, spacing: 0) {
                                Txt("\(T("rtDef")): \(fmt(def, 4))", 11, changed ? C.accent : C.muted)
                                if changed { Txt("↺ " + T("rtReset"), 12, C.accent).onTapGesture { P[k] = nil; upd() } }
                            }.frame(width: 90, alignment: .leading).padding(.bottom, 10)
                        }
                    }
                }
            }
            Btn("↺ " + T("rtResetAll"), false) { St.project["rates"] = obj(); upd() }
        }
    }
}
struct Sizes: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let P = St.project.o("sizes")
        let Ls: [String: [String]] = ["ru": ["Д — длина", "Ш — ширина", "В/Т — высота или толщина"], "en": ["L — length", "W — width", "H/T — height or thickness"], "uz": ["U — uzunlik", "E — eni", "B/Q — balandlik yoki qalinlik"]]
        let Ltxt = (Ls[St.lang == "uzc" ? "uz" : St.lang] ?? ["L", "W", "H/T"]).joined(separator: " · ")
        let LB = ["Д": ["Д", "L", "U"], "Ш": ["Ш", "W", "E"], "В": ["В", "H", "B"], "Т": ["Т", "T", "Q"]]
        Page {
            TopBar(T("szTitle"), { go(UI.extra ?? "settings") }); HintOut(T("szHint") + "\n" + Ltxt)
            ForEach(Array(D.SZDEF.entries.enumerated()), id: \.offset) { _, e in
                let k = e.0; let v = e.1 as! Obj; let cur = SZ(k)
                Sec(tr3(v["n"])) {
                    Chips { ForEach(Array(v.a("pre").enumerated()), id: \.offset) { _, pr0 in
                        let pr = (pr0 as! Arr).nums; Chip(pr.map { fmt($0, 10) }.joined(separator: "×"), pr == cur) { P[k] = Arr(pr.map { $0 as Any? }) } } }
                    HStack(spacing: 4) {
                        ForEach(Array(v.a("l").enumerated()), id: \.offset) { i, lb0 in
                            let lb = lb0 as! String; let base = (LB[lb] ?? [lb, lb, lb])[li()]
                            NumField((St.lang == "uzc" ? cyr(base) : base) + (St.lang == "ru" ? ", мм" : ", mm"), cur[i]) { var a = SZ(k); a[i] = $0; P[k] = Arr(a.map { $0 as Any? }) }
                        }
                    }
                    if k == "lam" {
                        HStack { NumField(T("szPack"), packSize()) { P["lamPack"] = ($0).rounded(.toNearestOrAwayFromZero) }
                            Txt("= \(fmt(cur[0] * cur[1] / 1e6 * packSize(), 3)) \(T("m2"))", 13, C.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8) }
                    }
                }
            }
        }
    }
}

func labMap(_ Ls: [Line]) -> [String: (String, String)] { var lab: [String: (String, String)] = [:]; for l in Ls where lab[l.pk] == nil { lab[l.pk] = (l.label, l.unit) }; return lab }
struct PriceList: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let GG: [(String, String)] = [("g1", "tgFound"), ("g2", "tgWalls"), ("g3", "tgRoof"), ("g4", "tgFin"), ("g5", "tgOps"), ("g6", "tgElec"), ("g7", "tgWater"), ("g8", "tgHeat"), ("g9", "tgSite")]
        let Ls = estimateLines(); let lab = labMap(Ls)
        func nm(_ k: String) -> String { lab[k]?.0 ?? D.o("TAS_L").aa(k).map { tr3($0) } ?? (D.TR.has(k) ? t(k) : k) }
        func nf(_ v: Double) -> String { let m = money(v); if let i = m.lastIndex(of: " ") { return String(m[m.startIndex..<i]) }; return m }
        let tas = D.a("TAS").compactMap { $0 as? Arr }
        let dyn = Array(NSOrderedSet(array: Ls.map { $0.pk })).compactMap { $0 as? String }.filter { k in !tas.contains { $0.s(0) == k } && tasPrice(k) > 0 }
        Page {
            TopBar(T("tasTitle"), { go("estimate") })
            Sec {
                Txt(T("tasIntro").replacingOccurrences(of: "{d}", with: "\(D.all["TAS_DATE"] ?? "")"), 14)
                HStack(spacing: 6) {
                    OBtn(T("tasFill")) { UI.tasMsg = t("tasDone").replacingOccurrences(of: "{n}", with: String(tasApply(false))); upd() }
                    OBtn(T("tasAll")) { UI.tasMsg = t("tasDone").replacingOccurrences(of: "{n}", with: String(tasApply(true))); upd() }
                }
                Hint(T("locNote"))
                if let m = UI.tasMsg { Hint(m, C.accent) }
            }
            if !dyn.isEmpty { Sec(T("tasProj")) { ForEach(dyn, id: \.self) { k in Stat("\(lab[k]!.0) (\(lab[k]!.1))", "≈ " + nf(cnv(tasPrice(k)))) }; Hint(T("tasDyn")) } }
            ForEach(GG, id: \.0) { (g, lk) in
                Sec(T(lk)) { ForEach(Array(tas.filter { $0.s(3) == g }.enumerated()), id: \.offset) { _, x in
                    let k = x.s(0); Stat(nm(k) + (lab[k].map { " (\($0.1))" } ?? ""), (num(x.at(2)) != 0 ? "✓ " : "≈ ") + nf(cnv(num(x.at(1))))) } }
            }
            Sec(T("tasRules")) { Hint(T("tasRulesT")) }
            HintOut("⚠️ " + T("tasNote"))
        }
    }
}
