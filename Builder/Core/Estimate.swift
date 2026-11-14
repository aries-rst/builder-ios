import Foundation

private func rxm(_ pat: String, _ s: String) -> [String]? {
    guard let re = try? NSRegularExpression(pattern: pat), let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) else { return nil }
    return (0..<m.numberOfRanges).map { i in let r = m.range(at: i); return r.location == NSNotFound ? "" : (s as NSString).substring(with: r) }
}
// ---------- прайс Ташкента ----------
func tasPrice(_ pk: String) -> Double {
    for x in D.a("TAS") { if let a = x as? Arr, a.s(0) == pk { return num(a.at(1)) } }
    if let g = rxm("^blk_([a-z]+)", pk) { let mat = g[1]; if mat == "brick" { return 1000 }; let M = D.WMAT.oo(mat)
        let last = pk.components(separatedBy: "_").last ?? ""; var t = Double(last) ?? 0; if t == 0 { t = 0.3 }
        let m3 = num(D.o("TAS_M3")[mat]); return (M != nil && m3 != 0) ? Double(mround(m3 * M!.n("L") * M!.n("H") * t / 100)) * 100 : 0 }
    if let g = rxm("^op_(win|door)_([a-z]+)_[a-z]+_(\\d)_(\\d+)x(\\d+)", pk) {
        let ww: Double = Double(g[4]) ?? 0; let hh: Double = Double(g[5]) ?? 0; let A: Double = max(0.5, ww * hh / 1e6)
        let isWin = g[1] == "win"; let tab: Obj = isWin ? D.o("TAS_WIN") : D.o("TAS_DOOR")
        var base: Double = num(tab[g[2]], 900000); if base == 0 { base = 900000 }
        let gks: [String: Double] = ["1": 0.9, "2": 1.0, "3": 1.15]; let gk: Double = gks[g[3]] ?? 1.0
        let mul: Double = isWin ? gk : 1.0
        let v: Double = base * A * mul / 1000
        return Double(mround(v)) * 1000 }
    if let g = rxm("^pk_ПК (\\d+)\\.(\\d+)", pk) { let a: Double = Double(g[1]) ?? 0; let b: Double = Double(g[2]) ?? 0; var x: Double = a / 10; x = x * b; x = x / 10; x = x * 230000; x = x / 1000; return Double(mround(x)) * 1000 }
    if let g = rxm("^pb_\\d?ПБ (\\d+)", pk) { let a: Double = Double(g[1]) ?? 0; var x: Double = a / 10; x = x * 45000; x = x / 1000; return Double(mround(x)) * 1000 }
    if let g = rxm("^fbs_(\\d+)\\.(\\d+)", pk) { let a: Double = Double(g[1]) ?? 0; let b: Double = Double(g[2]) ?? 0; var x: Double = (a / 10) * (b / 10); x = x * 0.6; x = x * 560000; x = x / 1000; return Double(mround(x)) * 1000 }
    if rxm("^rebar(\\d+)", pk) != nil { return 9000 }
    if let g = rxm("^conc_M(\\d+)", pk) { return 540000 + ((Double(g[1]) ?? 0) - 200) * 1100 }
    if pk.hasPrefix("mWpGlue_") { return 35000 }
    return 0
}
private let TAS_LOCAL = try! NSRegularExpression(pattern: "^(sand|gravel|mPlSand|mTSand|cement50|mPlCem|conc_|mTConc|mTBrick|mFBrick|blk_brick|blk_gas|blk_foam|blk_keram|fbs_|pk_|pb_|soil|tiles|curb|dig|mBc_clay|mBc_slag|mBc_saw|mPlClay|mGanch|mPlLime|mWhQuick|mWhLime|mWhSalt|s_ring|s_lid|mTBlock|e_conn|w_conn|g_conn|s_conn)")
/// Региональные поправки отключены: приложение для всего СНГ, цены задаёт пользователь.
func regK() -> Double { 1.0 }
func impK(_ pk: String) -> Double { 1.0 }
func rateOf(_ c: String) -> Double { let v = num(D.o("RATES")[c]); return v == 0 ? 1 : v }
/// Сумма в сумах → валюта cur с разумным округлением.
func cnv(_ uzs: Double, _ cur: String? = nil) -> Double { let cur = cur ?? St.cur; let v = uzs / rateOf(cur)
    if cur == "UZS" { return Double(mround(v / 100)) * 100 }
    if v >= 100 { return Double(mround(v)) }
    if v >= 1 { return Double(mround(v * 10)) / 10 }
    return Double(mround(v * 100)) / 100
}
/// Пересчитать цены проекта в текущую валюту, если проект сохранён в другой.
func syncCur(_ p: Obj) { guard let from = p.str("cur") else { p["cur"] = St.cur; return }; if from == St.cur { return }
    let P = p.o("prices"); for k in P.keys { if let v = P[k] as? Double, v > 0 { P[k] = cnv(v * rateOf(from), St.cur) } }; p["cur"] = St.cur }
/// Цена позиции: своя цена пользователя, а если её нет — цена из прайс-листа в текущей валюте.
func priceOf(_ pk: String) -> Double { let v = num(St.project.o("prices")[pk]); return v > 0 ? v : cnv(tasPrice(pk) * impK(pk)) }
@discardableResult func tasApply(_ all: Bool) -> Int { let P = St.project.o("prices"); var n = 0
    for l in estimateLines() { let v = cnv(tasPrice(l.pk) * impK(l.pk)); if v > 0 && (all || !(num(P[l.pk]) > 0)) { P[l.pk] = v; n += 1 } }; return n }

// ---------- работы ----------
let WSEC: [String: String] = ["dig": "mFound", "found": "mFound", "mason": "mWalls", "slab": "mWalls", "win": "mWalls", "door": "mWalls", "roof": "mRoof", "elec": "mEng", "plumb": "mEng", "heat": "mEng", "fence": "mFence", "land": "mExtra"]
let WWT: [String: Double] = ["dig": 1, "found": 4, "mason": 5, "slab": 1, "roof": 1, "plaster": 0.8, "lining": 0.8, "paint": 0.4, "wp": 0.5, "lime": 0.2, "ceil": 0.8, "screed": 0.4, "floor": 0.5,
    "tile": 1.5, "lag": 0.8, "bc": 0.5, "win": 3, "door": 3, "idoor": 3, "stairs": 40, "facade": 0.8, "elec": 1, "plumb": 3, "heat": 0.4, "fence": 1, "land": 0.3]
func WORKS() -> [[String]] { D.a("WORKS").compactMap { ($0 as? Arr).map { a in (0..<a.count).map { a.s($0) } } } }
func workQty() -> [String: Double] {
    let p = St.project; var q = [String: Double](); for w in WORKS() { q[w[0]] = 0 }
    func ad(_ k: String, _ v: Double) { q[k] = (q[k] ?? 0) + v }
    for b in buildings() { let f = calcFound(b); ad("dig", f.n("dig") + (calcBasement(b)?.n("dig") ?? 0)); ad("found", f.n("V") + (eq(b.o("f")["type"], "fbs") ? f.n("fbsW") / 2.4 : 0))
        let W = b.o("walls"); if !["poly", "open"].contains(W.s("mat")) { ad("mason", calcWalls(b).n("vol")); ad("slab", calcSlabs(b).n("area")) }
        if !eq(b["kind"], "greenhouse") { ad("roof", calcRoof(b).n("area"))
            if !eq(b["kind"], "gazebo") && !eq(W["mat"], "open") { let fi = calcFin(b); let n = FIN(b)
                if eq(n["wb"], "plaster") { ad("plaster", fi.n("wall")) }; if eq(n["cb"], "plaster") { ad("plaster", fi.n("ceil")) }
                if let aw = fi.oo("aw") { ad("paint", aw.n("paint")); ad("wp", aw.n("wallpaper")); ad("lime", aw.n("lime")); ad("lining", aw.n("vag")) }
                else if !eq(n["wb"], "vag") && !eq(n["wb"], "none") { if eq(n["wf"], "paint") { ad("paint", fi.n("wall")) }; if eq(n["wf"], "wallpaper") { ad("wp", fi.n("wall")) }; if eq(n["wf"], "lime") { ad("lime", fi.n("wall")) } }
                if ["gkl", "vag"].contains(n.s("wb")) { ad("lining", fi.n("wall")) }
                if ["plaster", "gkl"].contains(n.s("cb")) { if eq(n["cf"], "paint") { ad("paint", fi.n("ceil")) }; if eq(n["cf"], "lime") { ad("lime", fi.n("ceil")) } }
                if !["plaster", "none"].contains(n.s("cb")) { ad("ceil", fi.n("ceil")) }
                let O = opsMount(b); ad("win", O.win.n); ad("door", O.door.n); ad("idoor", O.inner.n); if eq(n["base"], "joist") { ad("lag", lagInfo(b, n).A) }
                if bcOn(b, n) { ad("bc", inArea(b, W.nz("t", 0.3)) * b.n("floors")) }; ad("stairs", Double(stairsOf(b).count)); if ["paint", "ins"].contains(n.s("fac")) { ad("paint", fi.n("facade")) }
                if n.n("scr") > 0 { ad("screed", max(0, fi.n("floor") - (eq(n["base"], "joist") ? lagInfo(b, n).A : 0))) }; if !eq(n["ff"], "none") && !eq(n["ff"], "tile") { ad("floor", fi.n("floor")) }
                ad("tile", (eq(n["ff"], "tile") ? fi.n("floor") : 0) + n.n("wetF") + n.n("wetW")); if !eq(n["fac"], "none") { ad("facade", fi.n("facade")) } } } }
    for b in buildings() where !["poly", "open"].contains(b.o("walls").s("mat")) { let e = ENG(b); let r = calcEng(b); if e.b("elec") { ad("elec", r.n("sock") + r.n("lights") + r.n("switches")) }
        ad("plumb", (e.s("water") != "none" ? r.n("wp") : 0) + (e.s("sewer") != "none" ? r.n("s110") + r.n("s50") : 0)); if e.s("heat") != "none" { ad("heat", r.n("heatA")) } }
    q["fence"] = p["fence"] != nil ? calcFence().n("L") + Double(FN().a("items").count) * 3 : 0
    let s = siteStats(); q["land"] = s.zone("path") + s.zone("paving") + s.zone("lawn"); return q
}
final class WRow { let k: String; let lbl: String; let u: String; let q: Double; let w: Obj; let v: Double; let auto: Bool; let sec: String?; let other: Bool
    init(_ k: String, _ lbl: String, _ u: String, _ q: Double, _ w: Obj, _ v: Double, _ auto: Bool, _ sec: String? = nil, _ other: Bool = false) { self.k = k; self.lbl = lbl; self.u = u; self.q = q; self.w = w; self.v = v; self.auto = auto; self.sec = sec; self.other = other } }
struct WT { var tot: Double; var rows: [WRow] }
func workTotal(_ matSec: OD) -> WT? {
    let E = St.project.o("est"); if !eq(E["workMode"], "items") { return nil }; let q = workQty(); let works = E.o("works"); var tot = 0.0; let rk = regK(); var rows = [WRow]()
    let pct = E.n("work") / 100; func sec(_ k: String) -> String { t(WSEC[k] ?? "mFinish") }
    var wsum = OD()
    for w in WORKS() { let k = w[0]; if (q[k] ?? 0) > 0 { wsum[sec(k)] = (wsum[sec(k)] ?? 0) + WWT[k]! * q[k]! } }
    for w in WORKS() { let k = w[0]; let lbl = w.count > 1 ? w[1] : ""; let u = w.count > 2 ? w[2] : ""; let qk = q[k] ?? 0; if qk <= 0 { continue }
        let wo = assign(obj(("mode", "rate"), ("rate", 0.0), ("sum", 0.0)), works.oo(k)); works[k] = wo; let S2 = sec(k)
        var ws = wsum[S2] ?? 0; if ws == 0 { ws = 1 }
        let auto = (matSec[S2] ?? 0) * pct * rk * WWT[k]! * qk / ws; let own = eq(wo["mode"], "rate") ? qk * wo.n("rate") : wo.n("sum"); let v = own > 0 ? own : auto
        tot += v; rows.append(WRow(k, lbl, u, qk, wo, v, !(own > 0))) }
    for S2 in matSec.keys { let m = matSec[S2]!; if (wsum[S2] ?? 0) == 0 && m > 0 { let v = m * pct * rk; tot += v; rows.append(WRow("other_\(S2)", "eOtherWork", "", 0, obj(("mode", "auto")), v, true, S2, true)) } }
    return WT(tot: tot, rows: rows)
}

// ---------- смета ----------
private let FIN_MAP: [String: String] = ["wCement": "cement50", "mJoist": "joist", "mBatten": "batten"]
func estimateLines() -> [Line] {
    let p = St.project; var L = [Line](); let m2 = t("m2"); let m3 = t("uM3"); let pc = t("uPcs"); let kg = t("uKg"); let bg = t("uBags"); let mm = t("m")
    func add(_ g: String, _ sec: String, _ pk: String, _ label: String, _ qty: Double, _ unit: String) { if qty > 0 { L.append(Line(g, pk, label, qty, unit, sec)) } }
    for b in buildings() { let g = itemName(b)
        let f = calcFound(b); let F = b.o("f"); let sF = t("mFound"); let gr = F.s("grade")
        if eq(F["mix"], "self") { add(g, sF, "cement50", t("eCement"), f.n("cement"), bg); add(g, sF, "sand", t("eSand"), f.n("sandMix"), m3); add(g, sF, "gravel", t("eGravel"), f.n("gravelMix"), m3) }
        else { add(g, sF, "conc_\(gr)", t("eConcrete") + " " + gr, f.n("V"), m3) }
        if eq(F["type"], "fbs") { add(g, sF, "fbs_" + F.s("fbs"), "ФБС \(F.s("fbs")) (ГОСТ 13579-2018)", f.n("fbsOut"), pc); add(g, sF, "fbs_" + F.s("fbsIn"), "ФБС \(F.s("fbsIn")) (ГОСТ 13579-2018)", f.n("fbsIn"), pc); add(g, sF, "cement50", t("eCement"), f.n("mortarBags"), bg) }
        let rd = jsn(F.n("rd")); add(g, sF, "rebar\(rd)", t("eRebar") + " Ø" + rd, f.n("mainKg"), kg); add(g, sF, "rebar8", t("eRebar") + " Ø8", f.n("clampKg"), kg); add(g, sF, "wire", t("fWire"), f.n("wire"), kg)
        add(g, sF, "board", t("eBoard"), f.n("formM3"), m3); add(g, sF, "sand", t("eSand"), f.n("bedSand"), m3); add(g, sF, "gravel", t("eGravel"), f.n("bedGravel"), m3); add(g, sF, "dig", t("eDig"), f.n("dig"), m3)
        add(g, sF, "tol", t("mTol"), f.n("tolRolls"), pc)
        let W = b.o("walls"); let sW = t("mWalls"); let mat = W.s("mat")
        if mat == "poly" { let G2 = ghCalc(b); add(g, sW, "poly", t("ghSheets"), G2.sheets, pc); add(g, sW, "pipe4020", t("ghFrame"), G2.frame, mm); add(g, sW, "screwThermo", t("ghScrews"), G2.screws, pc) }
        else if mat == "open" { add(g, sW, "timber", t("gzPosts"), 4 * 0.15 * 0.15 * (b.n("floorH") + 0.1), m3) }
        else { let w = calcWalls(b); let m = MI(W) ?? D.WMAT.o("gas"); let sl = calcSlabs(b)
            if !m.s("frame").isEmpty { for x in w.a("fItems").objs { add(g, sW, x.s("pk"), t(x.s("k")) + (x.s("pk").hasPrefix("sandwich") ? " \(fmt(W.n("t") * 1000)) mm" : ""), x.n("q"), t(x.s("u"))) } }
            else { add(g, sW, "blk_\(mat)" + (mat == "brick" ? "_" + W.s("bf") + "_" + W.s("bt") : "") + "_" + jsn(W.n("t")), "\(tr3(m["n"])) \(fmt(W.n("t") * 100, 1)) см", w.n("count"), pc)
                if m.b("glue") { add(g, sW, "glue25", t("wGlue"), w.n("glueBags"), bg) }
                if w.n("clay") != 0 { add(g, sW, "clay", t("eClay"), w.n("clay"), m3) } else if w.n("mortar") != 0 { add(g, sW, "cement50", t("eCement"), w.n("cementBags"), bg); add(g, sW, "sand", t("eSand"), w.n("sand"), m3) } }
            for o in W.a("openings").objs { let d = opDef(o); add(g, sW, "op_\(o.s("type"))_\(d.s("mat"))_\(d.s("col"))_\(jsn(d.n("glz")))_\(mround(o.n("w") * 1000))x\(mround(o.n("h") * 1000))", opName(o), o.n("q"), pc) }
            for (k, v) in w.o("lintels").entries { add(g, sW, "pb_\(k)", "\(k) (ГОСТ 948-2016)", num(v), pc) }; add(g, sW, "conc_M200", t("eConcrete") + " M200", w.n("lintelMono"), m3)
            if sl["mark"] != nil && sl.n("pcs") != 0 { add(g, sW, "pk_" + sl.s("mark"), sl.s("mark") + " (ГОСТ 9561-2016)", sl.n("pcs"), pc) }; add(g, sW, "conc_M250", t("eConcrete") + " M250", sl.n("monoV"), m3)
            add(g, sW, "timber", t("eTimber"), sl.n("timber"), m3); if sl.n("V") != 0 { add(g, sW, "conc_M250", t("eConcrete") + " M250", sl.n("V"), m3); add(g, sW, "rebar12", t("eRebar") + " Ø12", sl.n("rebarKg"), kg) }
            if W.b("belt") { add(g, sW, "conc_M200", t("eConcrete") + " M200", w.n("beltV"), m3); add(g, sW, "rebar12", t("eRebar") + " Ø12", w.n("beltRebarKg"), kg) }
            add(g, sW, "rebar8", t("eRebar") + " Ø8", w.n("reinfM") * 0.395, kg); add(g, sW, "meshMas", t("wMesh"), w.n("meshM2"), m2); add(g, sW, "jute", t("wJute"), w.n("jute"), mm) }
        if !eq(b["kind"], "greenhouse") { let r = calcRoof(b); let R = RF(b); let sR = t("mRoof"); let cov = R.s("cover"); let cv = D.COVERS.oo(cov) ?? obj(); let cc = R.oo("cc")
            let ck = "cov_\(cov)" + (cov == "custom" ? "_" + (cc?.s("name") ?? "") : ""); let cn = (cov == "custom" && cc != nil && !cc!.s("name").isEmpty) ? cc!.s("name") : tr3(cv["n"])
            add(g, sR, "flatRoll", t("rFlatRoll"), r.n("flatRolls"), pc)
            if r.n("sheetArea") != 0 { add(g, sR, ck, cn, r.n("sheetArea"), m2) } else { add(g, sR, ck, cn, r.n("sheets"), pc) }
            if r.n("packs") != 0 { add(g, sR, "cov_soft", tr3(cv["n"]), r.n("packs"), pc); add(g, sR, "osb", t("rOSB"), r.n("osb"), pc); add(g, sR, "underlay", t("rUnder"), r.n("under"), pc) }
            add(g, sR, "timber", t("eTimber"), r.n("timber"), m3); add(g, sR, "membrane", t("rMembrane"), r.n("membrane"), pc); add(g, sR, "vapor", t("rVapor"), r.n("vapor"), pc)
            add(g, sR, "wool", t("rWool"), r.n("wool"), m3); add(g, sR, "ridge", t("rRidge"), r.n("ridge"), pc); add(g, sR, "valley", t("rValley"), r.n("valleyPcs"), pc); add(g, sR, "screwRoof", t("rScrews"), r.n("screws"), pc)
            add(g, sR, "gutter", t("rGutter"), r.n("gutter"), pc); add(g, sR, "downpipe", t("rPipe"), r.n("pipes") * r.n("pipeLen"), mm) }
        for l in basementLines(b) { add(g, t("mFound"), l.pk, l.label, l.qty, l.unit) }
        for l in extraLines(b) { add(g, t("mExtra"), l.pk, l.label, l.qty, l.unit) }
        for (k, s2) in [("found", "mFound"), ("walls", "mWalls"), ("roof", "mRoof"), ("finish", "mFinish"), ("eng", "mEng"), ("extra", "mExtra")] { for l in extrasLines(b, k) { add(g, t(s2), l.pk, l.label, l.qty, l.unit) } }
        if !["poly", "open"].contains(b.o("walls").s("mat")) { let sE = t("mEng"); for l in engLines(b) { add(g, sE, l.pk, l.label, l.qty, l.unit) } }
        if !eq(b["kind"], "greenhouse") { let fi = calcFin(b); let sN = t("mFinish"); let list = (fi["list"] as? FLBox)?.a ?? []
            for l in list { let sz = ["mInDoor", "mStep", "mStringer", "mRoofWin"].contains(l.k) && !(l.x ?? "").isEmpty
                add(g, sN, (FIN_MAP[l.k] ?? l.k) + (sz ? "_" + l.x! : ""), t(l.k) + (sz ? " " + l.x! : ""), l.v, l.u) } }
    }
    if p["fence"] != nil { let gF = t("mFence"); for l in fenceLines() { add(gF, gF, l.pk, l.label, l.qty, l.unit) } }
    let s = siteStats(); let gL = t("eLand")
    add(gL, gL, "tiles", t("sTiles"), s.tiles, m2); add(gL, gL, "curb", t("sCurb"), s.curb, mm); add(gL, gL, "sand", t("eSand"), s.bSand, m3); add(gL, gL, "gravel", t("eGravel"), s.bGravel, m3)
    add(gL, gL, "seed", t("sSeed"), s.seed, kg); add(gL, gL, "soil", t("sSoil"), s.soil, m3)
    let its = items(); let pcs = t("uPcs")
    func cnt(_ k: String) -> Double { Double(its.filter { eq($0["kind"], k) }.count) }
    func ar(_ k: String) -> Double { its.filter { eq($0["kind"], k) }.reduce(0) { $0 + $1.n("w") * $1.n("d") } }
    add(gL, gL, "z_tandoor", t("zTandoor"), cnt("tandoor"), pcs); add(gL, gL, "z_fbrick", t("zFBrick"), cnt("hearth") * 120 + (ar("bbq") * 180).rounded(.up), pcs)
    add(gL, gL, "z_ring", t("zRing"), cnt("hearth"), pcs); add(gL, gL, "z_grate", t("zGrate"), cnt("bbq"), pcs); add(gL, gL, "clay", t("eClay"), cnt("hearth") * 0.05 + ar("bbq") * 0.08, m3)
    add(gL, gL, "timber", t("zSupaWood"), ar("supa") * 0.06, m3)
    return L
}
final class Agg { let pk: String; let label: String; let unit: String; var qty: Double; init(_ pk: String, _ l: String, _ u: String, _ q: Double) { self.pk = pk; label = l; unit = u; qty = q } }
final class Est { let L: [Line]; let agg: [Agg]; let mat: Double; let logi: Double; let work: Double; let res: Double; let total: Double; let living: Double; let WT: WT?
    init(_ L: [Line], _ agg: [Agg], _ mat: Double, _ logi: Double, _ work: Double, _ res: Double, _ total: Double, _ living: Double, _ WT: WT?) { self.L = L; self.agg = agg; self.mat = mat; self.logi = logi; self.work = work; self.res = res; self.total = total; self.living = living; self.WT = WT }
    func price(_ pk: String) -> Double { priceOf(pk) } }
func estimate() -> Est {
    let p = St.project; _ = p.o("prices"); let E = keep(p, "est", obj(("work", 40.0), ("reserve", 10.0), ("logi", 8.0), ("region", "tash"), ("tab", "sum")))
    let L = estimateLines(); var aggKeys = [String](); var aggD = [String: Agg]()
    for l in L { let k = l.pk + "|" + l.unit; if let a = aggD[k] { a.qty += l.qty } else { aggKeys.append(k); aggD[k] = Agg(l.pk, l.label, l.unit, l.qty) } }
    let mat = L.reduce(0) { $0 + $1.qty * priceOf($1.pk) }; var matSec = OD(); for l in L { matSec[l.sec!] = (matSec[l.sec!] ?? 0) + l.qty * priceOf(l.pk) }
    let WT = workTotal(matSec); let work = WT?.tot ?? (mat * E.n("work") / 100 * regK()); let logi = mat * E.n("logi") / 100; let res = (mat + logi + work) * E.n("reserve") / 100
    let living = buildings().filter { ["house", "kitchen"].contains($0.s("kind")) }.reduce(0) { $0 + inArea($1, $1.o("walls").nz("t", 0.3)) * $1.n("floors") }
    return Est(L, aggKeys.map { aggD[$0]! }, mat, logi, work, res, mat + logi + work + res, living, WT)
}
func qfmt(_ q: Double) -> String { q >= 100 ? fmt(q, 0) : q >= 10 ? fmt(q, 1) : fmt(q, 2) }
/// Формат денег как в Android: разряды через пробел, десятичная запятая для малых сумм.
func money(_ v: Double) -> String {
    var s: String
    if abs(v) < 1000 && abs(v - Double(mround(v))) > 0.004 { s = String(format: "%.2f", v).replacingOccurrences(of: ".", with: ",") }
    else { let n = mround(v); let neg = n < 0; var d = String(abs(n)); var out = ""; while d.count > 3 { out = " " + d.suffix(3) + out; d = String(d.dropLast(3)) }; s = (neg ? "-" : "") + d + out }
    let c = D.a("CUR").compactMap { $0 as? Arr }.first(where: { $0.s(0) == St.cur })
    return s + " " + (c?.at(1).map { "\($0)" } ?? "")
}
