import Foundation

/// строка отделки/монтажа: группа, ключ материала, количество, единица, пояснение
final class FL { let g: String; let k: String; let v: Double; let u: String; let x: String?
    init(_ g: String, _ k: String, _ v: Double, _ u: String, _ x: String? = nil) { self.g = g; self.k = k; self.v = v; self.u = u; self.x = x } }
final class FLBox { var a: [FL]; init(_ a: [FL]) { self.a = a } }
func szj(_ k: String, _ sep: String = "×") -> String { SZ(k).map { fmt($0, 10) }.joined(separator: sep) }
func fv(_ s: String) -> Double { Double(s) ?? 0 }

@discardableResult func FIN(_ b: Obj) -> Obj {
    let d = obj(("wpType", "fleece"), ("wpW", 0.53), ("wpL", 10.05), ("wpRap", 0.0), ("base", "slab"), ("lagS", "50x150"), ("lagStep", 0.6), ("tStep", 1.0), ("tType", "brick"), ("tH", 0.6),
                ("tolL", 2.0), ("bcT", 25.0), ("bcTol", 1.0), ("bcIns", "none"), ("bcInsT", 150.0), ("lmL", 3.0), ("pType", "gyp"), ("pCeilT", 10.0), ("pCeilType", "gyp"), ("pFacT", 15.0), ("bag", 30.0))
    return keep(b, "fin", assign(d, deep(D.FIN_DEF.oo(b.s("kind")) ?? D.FIN_DEF.o("house")) as? Obj))
}
let PL_CEM = ["bath", "wash", "boiler", "garage", "stall", "poultry", "workshop", "storage"]
func plType(_ q: Obj, _ n: Obj) -> String { q.str("plT") ?? (PL_CEM.contains(q.s("type")) ? "cem" : n.s("pType")) }
func plMm(_ q: Obj, _ n: Obj) -> Double { q.n("plMm") != 0 ? q.n("plMm") : (PL_CEM.contains(q.s("type")) ? max(n.n("pT"), 20) : n.n("pT")) }

struct LagInfo { var A: Double; var sc: Double; var lc: Double; var rows: Double; var per: Double; var len: Double; var cnt: Double; var lw: Double; var lh: Double; var V: Double; var onGround: Bool }
func lagInfo(_ b: Obj, _ n: Obj) -> LagInfo {
    let wt = b.oo("walls")?.nz("t", 0.3) ?? 0.3; let A = inArea(b, wt); let sc = max(0.5, (isShaped(b) ? roofSpan(b) : min(b.n("w"), b.n("d"))) - 2 * wt); let lc = A / sc
    let rows = (sc / n.n("lagStep")).rounded(.up) + 1; let per = (lc / n.n("tStep")).rounded(.up) + 1
    let ls = n.s("lagS").split(separator: "x", omittingEmptySubsequences: false).map { s -> Double in let v = Double(s) ?? 0; return (v == 0 ? 50 : v) / 1000 }; let lw = ls[0]; let lh = ls.count > 1 ? ls[1] : 0.05
    let len = rows * lc * 1.05
    return LagInfo(A: A, sc: sc, lc: lc, rows: rows, per: per, len: len, cnt: rows * per, lw: lw, lh: lh, V: len * lw * lh, onGround: b.oo("basement")?.b("on") != true)
}
func lagNonBoard(_ b: Obj, _ n: Obj) -> Double {
    let L = lagInfo(b, n); if !eq(n["base"], "joist") { return 0 }; let rs: [Obj]? = (b["rooms"] as? Arr)?.objs
    if let rs = rs, rs.contains(where: { lvEq($0["lv"], 0.0) }) && notFalse(n["byRooms"]) { return rs.filter { lvEq($0["lv"], 0.0) && roomF($0) != "board" }.reduce(0) { $0 + rA($1) } }
    return eq(n["ff"], "board") ? 0 : L.A
}
func bcOn(_ b: Obj, _ n: Obj) -> Bool { n["bc"] != nil ? truthy(n["bc"]) : eq(b.oo("walls")?["slab"], "wood") }

typealias FinAdd = (String, String, Double, String, String?) -> Void
func woodLines(_ b: Obj, _ n: Obj, _ add: FinAdd) {
    let m3 = t("uM3"); let kg = t("uKg"); let m = t("m"); let pc = t("uPcs"); let bg = t("uBags"); let m2 = t("m2")
    if eq(n["base"], "joist") { let L = lagInfo(b, n); let tH = n.n("tH")
        add("nLag", "mLag", fv(fmt(L.len, 1)), m, "\(mround(L.lw * 1000))×\(mround(L.lh * 1000)) мм · \(fmt(L.rows)) \(t("lagRows")) · \(fmt(L.V, 2)) \(m3)")
        add("nLag", "mAntisep", fv(fmt(L.len * 2 * (L.lw + L.lh) * 0.3, 1)), t("uL"), nil)
        let nb = lagNonBoard(b, n); if nb > 0 { let z = SZm("osb"); add("nLag", "mLagOsb", (nb * 1.05 / (z[0] * z[1])).rounded(.up), pc, "\(fmt(nb, 1)) \(m2) · \(szj("osb"))") }
        if L.onGround { let c = L.cnt; let d = "\(fmt(c)) \(t("tumbN")) · \(fmt(tH, 2)) \(m)"
            switch n.s("tType") {
            case "brick": let V = c * 0.25 * 0.25 * tH * 0.25; add("nLag", "mTBrick", (c * 2 * (tH / 0.077).rounded(.up) * 1.05).rounded(.up), pc, "\(d) · 250×250"); add("nLag", "mPlCem", (V * RT("mortCem") / 50).rounded(.up), bg, nil); add("nLag", "mPlSand", fv(fmt(V * RT("mortSand"), 2)), m3, nil)
            case "conc": add("nLag", "mTConc", fv(fmt(c * 0.3 * 0.3 * tH * 1.05, 2)), m3, "\(d) · 300×300"); add("nLag", "mTRebar", fv(fmt(c * 4 * (tH + 0.1) * 0.617, 1)), kg, "Ø10")
            case "block": add("nLag", "mTBlock", c * 2 * (tH / 0.2).rounded(.up), pc, "\(d) · 390×190×188")
            default: break
            }
            add("nLag", "mTSand", fv(fmt(c * 0.45 * 0.45 * 0.15, 2)), m3, nil)
            if n.n("tolL") > 0 { let a = c * 0.35 * 0.35 * n.n("tolL") * 1.15; add("nLag", "mTol", (a / 10).rounded(.up), pc, "\(fmt(a, 1)) \(m2) · \(t("lmL").lowercased()): \(fmt(n.n("tolL")))") } } }
    if bcOn(b, n) { let A = inArea(b, b.oo("walls")?.nz("t", 0.3) ?? 0.3) * b.n("floors"); if A > 0 {
        add("nBlackC", "mBcBoard", fv(fmt(A * 1.1, 1)), m2, "\(fmt(n.n("bcT"))) мм · \(fmt(A * 1.1 * n.n("bcT") / 1000, 2)) \(m3)")
        if eq(b.oo("walls")?["slab"], "wood") { let sl = calcSlabs(b); if sl.n("beams") != 0 { add("nBlackC", "mCranial", fv(fmt(sl.n("beams") * sl.n("beamLen") * 2 * 1.05, 0)), m, "50×50") } }
        if n.n("bcTol") > 0 { let a = A * 1.15 * n.n("bcTol"); add("nBlackC", "mTol", (a / 10).rounded(.up), pc, "\(fmt(a, 1)) \(m2)") }
        if n.s("bcIns") != "none" { add("nBlackC", "mBc_" + n.s("bcIns"), fv(fmt(A * n.n("bcInsT") / 1000 * 1.1, 2)), m3, "\(fmt(n.n("bcInsT"))) мм") } } }
}
final class OM { var n = 0.0; var P = 0.0; var w = 0.0 }
final class OpsM { let win = OM(); let door = OM(); let inner = OM() }
func opsMount(_ b: Obj) -> OpsM {
    let O = OpsM()
    for o in (b.oo("walls")?.aa("openings") ?? arr()).objs { let q = o.n("q"); if q == 0 { continue }
        if eq(o["type"], "door") { O.door.n += q; O.door.P += q * (2 * o.n("h") + o.n("w")) } else { O.win.n += q; O.win.P += q * 2 * (o.n("w") + o.n("h")); O.win.w += q * (o.n("w") + 0.1) } }
    for l in levels(b) { for o in (planOf(b, l)?.aa("ops")?.objs ?? []) {
        if eq(o["on"], "i") { O.inner.n += 1; O.inner.P += 2 * o.n("h") + o.n("w") } else if eq(l, "a") && eq(o["type"], "win") { O.win.n += 1; O.win.P += 2 * (o.n("w") + o.n("h")); O.win.w += o.n("w") + 0.1 } } }
    return O
}
func opsLines(_ b: Obj, _ n: Obj, _ add: FinAdd) {
    let O = opsMount(b); let m = t("m"); let pc = t("uPcs"); let wt = b.oo("walls")?.nz("t", 0.3) ?? 0.3; let ext = O.win.P + O.door.P; let all = ext + O.inner.P; if all == 0 { return }
    let fvv = n.nz("foamV", 750); let sv = n.nz("sealV", 300)
    add("nOps", "mFoam", (all * RT("foamMl") / fvv).rounded(.up), pc, "\(fmt(fvv)) мл · \(fmt(all, 1)) \(m) \(t("opSeam"))")
    add("nOps", "mSealant", ((O.win.P * 2 + O.door.P) * RT("sealMl") / sv).rounded(.up), pc, "\(fmt(sv)) мл · \(fmt(O.win.P * 2 + O.door.P, 1)) \(m)")
    add("nOps", "mAnchor", (ext / RT("anchorStep")).rounded(.up), pc, nil)
    if notFalse(n["opTape"]) && ext != 0 { add("nOps", "mPsul", fv(fmt(ext * 1.05, 1)), m, nil); add("nOps", "mVapTape", fv(fmt(ext * 1.05, 1)), m, nil) }
    if notFalse(n["opSill"]) && O.win.n != 0 { add("nOps", "mSill", fv(fmt(O.win.w, 1)), m, "\(fmt(O.win.n)) \(t("uPcs")) · \(mround((wt * 0.6 + 0.05) * 1000)) мм"); add("nOps", "mDrip", fv(fmt(O.win.w, 1)), m, "\(fmt(O.win.n)) \(t("uPcs"))") }
}
func wpRolls(_ P: Double, _ h: Double, _ n: Obj) -> Double { let cut = h + n.n("wpRap") / 100 + 0.05; let spr = max(1.0, (n.n("wpL") / cut).rounded(.down)); return ((P / n.n("wpW")).rounded(.up) / spr).rounded(.up) }
func wpLines(_ add: FinAdd, _ A: Double, _ rolls: Double, _ n: Obj) {
    let pc = t("uPcs"); let rap = n.n("wpRap") != 0 ? " · " + (t("wpRap").split(separator: ",", omittingEmptySubsequences: false).first.map(String.init) ?? "").lowercased() + " " + fmt(n.n("wpRap")) + " см" : ""
    add("nWalls", "mWp", rolls, pc, "\(t(D.o("WPT").s(n.s("wpType"), "wpFleece"))) · \(fmt(n.n("wpW"), 2))×\(fmt(n.n("wpL"), 2)) м\(rap) · \(fmt(A, 1)) \(t("m2"))")
    add("nWalls", "mWpGlue_" + n.s("wpType"), (A / RT("wpGlueM2")).rounded(.up), pc, nil); if eq(n["wpType"], "glass") { add("nWalls", "mPaint", (A * RT("paint") / 10).rounded(.up), pc, t("wpGlassP")) }
}

func calcFin(_ b: Obj) -> Obj {
    let n = FIN(b); let W = b.oo("walls") ?? obj(); let wt = W.nz("t", 0.3); let fl = b.n("floors"); let Hf = b.n("floorH"); let H = fl * Hf
    let iw = max(b.n("w") - 2 * wt, 0.5); let id = max(b.n("d") - 2 * wt, 0.5); let r = obj(); var L = [FL]()
    func addFn(_ g: String, _ k: String, _ v: Double, _ u: String, _ x: String?) { L.append(FL(g, k, v, u, x)) }
    func pcs(_ a: Double, _ key: String) -> Double { let z = SZm(key); return (a / (z[0] * z[1])).rounded(.up) }
    func bag(_ kg: Double, _ sz: Double) -> Double { (kg / sz).rounded(.up) }
    let m2 = t("m2"); let pc = t("uPcs"); let bg = t("uBags"); let mat = W.s("mat")
    func fin() -> Obj { r["list"] = FLBox(L); storeCalc(b, "fin", r); return r }
    if mat == "open" { let A = bArea(b); addFn("nGzFloor", "mDeck", fv(fmt(A * 1.1, 1)), m2, "\(fmt(pcs(A * 1.1, "deck"))) \(pc) \(szj("deck"))"); addFn("nGzFloor", "mJoist", fv(fmt(A / 0.6 * 1.05, 0)), t("m"), nil); return fin() }
    let open = W.a("openings").objs.reduce(0) { $0 + $1.n("w") * $1.n("h") * $1.n("q") }
    let inner = (notFalse(W["innerAuto"]) && !["poly", "open"].contains(mat)) ? partInfo(b).area / max(H, 0.1) : W.n("innerLen")
    r["floor"] = inArea(b, wt) * fl - stairsOpen(b); r["ceil"] = r["floor"]; r["wall"] = max(inPer(b, wt) * H - open + 2 * inner * H - n.n("wetW"), 0)
    let gable = notFalse(W["gables"]) ? gableArea(b) : 0.0; r["facade"] = max(bPer(b) * H + gable - open, 0)
    func whA(_ g: String, _ a: Double) { if a <= 0 { return }; let Ll = a * n.n("lmL") * RT("lmSol"); let q = Ll / 10 * RT("lmQ"); let quick = eq(n["lmT"], "quick"); let kg = quick ? q : q * 1.32
        inc(r, "whL", Ll); inc(r, "whA", a)
        addFn(g, quick ? "mWhQuick" : "mWhLime", (kg / 25).rounded(.up), bg, "\(fmt(a, 1)) \(m2) · \(t("lmL").lowercased()): \(fmt(n.n("lmL"))) · \(fmt(kg, 0)) кг · 25 кг/\(bg)")
        addFn(g, "mWhSalt", fv(fmt(Ll / 10 * RT("lmSalt") / 1000, 1)), t("uKg"), "\(fmt(Ll, 0)) л") }
    func plA(_ g: String, _ a: Double, _ mm: Double, _ ty: String) { if a <= 0 { return }
        if ["cs", "cl", "lime", "clay"].contains(ty) { let V = a * mm / 1000 * (1 + RT("plMortRes") / 100); let d = "\(fmt(a, 1)) \(m2) · \(fmt(mm)) мм · \(fmt(V, 2)) \(t("uM3"))"; let m3 = t("uM3")
            if ty == "cs" { addFn(g, "mPlCem", (V * RT("pcsCem") / 50).rounded(.up), bg, d + " · \(t(D.o("PLT_N").s("cs")))"); addFn(g, "mPlSand", fv(fmt(V * RT("pcsSand"), 2)), m3, d) }
            if ty == "cl" { addFn(g, "mPlCem", (V * RT("pclCem") / 50).rounded(.up), bg, d + " · \(t(D.o("PLT_N").s("cl")))"); addFn(g, "mPlLime", (V * RT("pclLime") / 25).rounded(.up), bg, fmt(V * RT("pclLime"), 0) + " кг · 25 кг/" + bg); addFn(g, "mPlSand", fv(fmt(V * RT("pclSand"), 2)), m3, d) }
            if ty == "lime" { addFn(g, "mPlLime", (V * RT("plLime") / 25).rounded(.up), bg, d + " · " + fmt(V * RT("plLime"), 0) + " кг · 25 кг/" + bg); addFn(g, "mPlSand", fv(fmt(V * RT("plLSand"), 2)), m3, d) }
            if ty == "clay" { addFn(g, "mPlClay", fv(fmt(V * RT("pcClay"), 2)), m3, d); addFn(g, "mPlSand", fv(fmt(V * RT("pcCSand"), 2)), m3, d) }
            return }
        let kg = a * mm * (ty == "cem" ? RT("cemRate") : ty == "ganch" ? RT("ganchRate") : RT("gypRate"))
        addFn(g, ty == "cem" ? "mPlasterC" : ty == "ganch" ? "mGanch" : "mPlasterG", (kg / n.n("bag")).rounded(.up), bg, "\(fmt(a, 1)) \(m2) · \(fmt(mm)) мм · \(fmt(kg, 0)) кг · \(fmt(n.n("bag"))) кг/\(bg)") }
    r["cPer"] = inPer(b, wt) * fl
    do { var dc = OD(); for l in levels(b) { for o in (planOf(b, l)?.aa("ops")?.objs ?? []) where eq(o["on"], "i") { let k = fmt(o.n("w")) + "×" + fmt(o.n("h")); dc[k] = (dc[k] ?? 0) + 1 } }
        for k in dc.keys { addFn("nDoorsIn", "mInDoor", dc[k]!, pc, k) } }
    for st in stairsOf(b) { let I = stInfo(b, st); let ln = hypot2(st.n("L"), I.H); addFn("nStairs", "mStep", Double(I.n), pc, "\(fmt(st.n("w")))×\(fmt(I.g + 0.03, 2)) \(t("m"))")
        addFn("nStairs", "mStringer", 2.0, pc, "\(fmt(ln, 2)) \(t("m"))"); addFn("nStairs", "mRail", fv(fmt(ln + 0.3, 1)), t("m"), nil) }
    do { var aw = OD(); let P = planOf(b, "a"); if let P = P, levels(b).contains(where: { eq($0, "a") }) { for o in P.a("ops").objs where eq(o["on"], "o") && eq(o["type"], "win") { let k = fmt(o.n("w")) + "×" + fmt(o.n("h")); aw[k] = (aw[k] ?? 0) + 1 } }
        for k in aw.keys { addFn("nAtticWin", "mRoofWin", aw[k]!, pc, k) } }
    let RM = notFalse(n["byRooms"]) && !["poly", "open"].contains(mat) && !ensureRooms(b).isEmpty
    var rmFloor: (() -> Void)? = nil
    if RM { var aw = OD(); for k in ["lime", "paint", "wallpaper", "tile", "vag", "concrete"] { aw[k] = 0 }; var af = OD(); for k in ["laminate", "tile", "board", "lino", "screed"] { af[k] = 0 }
        var per = 0.0; var pg = OD(); var wpR = 0.0; r["cPer"] = 0.0; let lv = levels(b); let rl = arr(); r["rooms"] = rl
        for q in b.a("rooms").objs where lv.contains(where: { lvEq($0, q["lv"]) }) { let h = lvH(b, q["lv"]); let pw = rP(q) * h; let fa = rA(q); let wf = roomW(q); let ff = roomF(q)
            aw[wf] = (aw[wf] ?? 0) + pw; if wf == "wallpaper" { wpR += wpRolls(rP(q), h, n) }; inc(r, "cPer", rP(q))
            if ["paint", "wallpaper", "tile", "lime"].contains(wf) { let k = plType(q, n) + "|" + fmt(plMm(q, n), 10); pg[k] = (pg[k] ?? 0) + pw }
            af[ff] = (af[ff] ?? 0) + fa; if ff != "tile" { per += rP(q) }; rl.add(arr(q, fa, pw)) }
        aw["paint"] = max(aw["paint"]! - open, 0)
        let awO = Obj(); for k in aw.keys { awO[k] = aw[k]! }; r["aw"] = awO; let afO = Obj(); for k in af.keys { afO[k] = af[k]! }; r["af"] = afO
        r["wall"] = aw.sum; r["floor"] = af.sum; r["ceil"] = r["floor"]
        let base = aw["paint"]! + aw["wallpaper"]! + aw["tile"]! + aw["lime"]!; let pf = aw["paint"]! + aw["wallpaper"]!
        if eq(n["wb"], "plaster") && base != 0 { let ks = pg.keys.enumerated().sorted { pg[$0.element]! != pg[$1.element]! ? pg[$0.element]! > pg[$1.element]! : $0.offset < $1.offset }.map { $0.element }
            if let k0 = ks.first { pg[k0] = max(pg[k0]! - open, 0) }
            for k in ks { let parts = k.components(separatedBy: "|"); plA("nWalls", pg[k]!, Double(parts[1]) ?? 0, parts[0]) }; addFn("nWalls", "mBeacon", (base / 4).rounded(.up), pc, nil) }
        if eq(n["wb"], "gkl") && base != 0 { addFn("nWalls", "mGklSheets", pcs(base * 1.1, "gkl"), pc, szj("gkl")); addFn("nWalls", "mProfile", (base * 2.9 / 3).rounded(.up), pc, nil); addFn("nWalls", "mScrew", (base * RT("gklScrew")).rounded(.up), pc, nil) }
        if pf != 0 { addFn("nWalls", "mPutty", bag(pf * RT("putty"), 20), bg, nil); addFn("nWalls", "mPrimer", (pf * RT("primer") / 10).rounded(.up), pc, nil) }
        if aw["lime"]! != 0 { whA("nWalls", aw["lime"]!) }
        if aw["paint"]! != 0 { addFn("nWalls", "mPaint", (aw["paint"]! * RT("paint") / 10).rounded(.up), pc, fmt(aw["paint"]!, 1) + " " + m2) }
        if aw["wallpaper"]! != 0 { wpLines(addFn, aw["wallpaper"]!, (wpR * (1 + RT("wpRes") / 100)).rounded(.up), n) }
        if aw["vag"]! != 0 { let v = aw["vag"]!; addFn("nWalls", "mVag", fv(fmt(v * 1.1, 1)), m2, "\(fmt(pcs(v * 1.1, "vag"))) \(pc) \(szj("vag"))"); addFn("nWalls", "mBatten", fv(fmt(v * 2, 0)), t("m"), nil) }
        if aw["tile"]! != 0 { let a = aw["tile"]!; let tr = 1 + RT("tileRes") / 100; addFn("nWet", "mTileW", fv(fmt(a * tr, 1)), m2, "\(fmt(pcs(a * tr, "tileW"))) \(pc) \(szj("tileW"))")
            addFn("nWet", "mTileGlue", bag(a * RT("tileGlue"), 25), bg, nil); addFn("nWet", "mGrout", fv(fmt(a * RT("grout"), 1)), t("uKg"), nil); addFn("nWet", "mWaterproof", fv(fmt(a * 0.3 * RT("waterproof"), 1)), t("uKg"), nil) }
        rmFloor = { let scrA = r.n("floor") - af["board"]! - lagNonBoard(b, n); if n.n("scr") > 0 && scrA > 0 { addFn("nFloor", "mScreed", bag(scrA * n.n("scr") * RT("screed"), 50), bg, nil) }
            if af["laminate"]! != 0 { let z = SZm("lam"); let pa = z[0] * z[1] * packSize(); addFn("nFloor", "mLam", (af["laminate"]! * (1 + RT("lamRes") / 100) / pa).rounded(.up), pc, fmt(af["laminate"]!, 1) + " " + m2 + " · " + szj("lam")); addFn("nFloor", "mUnderlay", fv(fmt(af["laminate"]! * 1.05, 1)), m2, nil) }
            if af["tile"]! != 0 { let a = af["tile"]!; let tr = 1 + RT("tileRes") / 100; addFn("nFloor", "mTile", fv(fmt(a * tr, 1)), m2, "\(fmt(pcs(a * tr, "tileF"))) \(pc) \(szj("tileF"))"); addFn("nFloor", "mTileGlue", bag(a * RT("tileGlue"), 25), bg, nil); addFn("nFloor", "mGrout", fv(fmt(a * RT("grout"), 1)), t("uKg"), nil) }
            if af["lino"]! != 0 { addFn("nFloor", "mLino", fv(fmt(af["lino"]! * 1.05, 1)), m2, nil) }
            if af["board"]! != 0 { let a = af["board"]!; let z = SZm("board"); addFn("nFloor", "mBoard", fv(fmt(a * 1.1, 1)), m2, "\(fmt(pcs(a * 1.1, "board"))) \(pc) \(szj("board")) · \(fmt(a * 1.1 * z[2], 2)) \(t("uM3"))"); addFn("nFloor", "mJoist", fv(fmt(a / 0.6 * 1.05, 0)), t("m"), nil) }
            if per != 0 { addFn("nFloor", "mSkirt", (per / 2.5).rounded(.up), pc, nil) } } }
    let A = r.n("wall"); let wb = n.s("wb"); let wf = n.s("wf")
    if !RM {
        if wb == "plaster" { plA("nWalls", A, n.n("pT"), n.s("pType")); addFn("nWalls", "mBeacon", (A / 4).rounded(.up), pc, nil) }
        if wb == "gkl" { addFn("nWalls", "mGklSheets", pcs(A * 1.1, "gkl"), pc, szj("gkl")); addFn("nWalls", "mProfile", (A * 2.9 / 3).rounded(.up), pc, nil); addFn("nWalls", "mScrew", (A * RT("gklScrew")).rounded(.up), pc, nil) }
        if wb == "vag" { addFn("nWalls", "mVag", fv(fmt(A * 1.1, 1)), m2, "\(fmt(pcs(A * 1.1, "vag"))) \(pc) \(szj("vag"))"); addFn("nWalls", "mBatten", fv(fmt(A * 2, 0)), t("m"), nil) }
        if wf == "lime" && wb != "vag" && wb != "none" { whA("nWalls", A) }
        if wb != "vag" && wb != "none" && !["none", "lime"].contains(wf) { addFn("nWalls", "mPutty", bag(A * RT("putty"), 20), bg, nil); addFn("nWalls", "mPrimer", (A * RT("primer") / 10).rounded(.up), pc, nil) }
        if wf == "paint" && wb != "vag" { addFn("nWalls", "mPaint", (A * RT("paint") / 10).rounded(.up), pc, nil) }
        if wf == "wallpaper" && wb != "vag" { let rl = wpRolls(A / Hf / max(1, fl), Hf, n) * fl; wpLines(addFn, A, (rl * (1 + RT("wpRes") / 100)).rounded(.up), n) }
    }
    let C = r.n("ceil"); let cp = r.n("cPer"); let cb = n.s("cb"); let cf = n.s("cf")
    switch cb {
    case "plaster": plA("nCeil", C, n.n("pCeilT"), n.s("pCeilType")); if !["none", "lime"].contains(cf) { addFn("nCeil", "mPutty", bag(C * RT("putty"), 20), bg, nil); addFn("nCeil", "mPrimer", (C * RT("primer") / 10).rounded(.up), pc, nil) }
    case "gkl": addFn("nCeil", "mGklSheets", pcs(C * 1.1, "gkl"), pc, szj("gkl")); addFn("nCeil", "mProfile", ((C * 3.3 + 2 * (iw + id) * fl) / 3).rounded(.up), pc, nil); addFn("nCeil", "mScrew", (C * 35).rounded(.up), pc, nil); if !["none", "lime"].contains(cf) { addFn("nCeil", "mPutty", bag(C * RT("putty"), 20), bg, nil) }
    case "vag": addFn("nCeil", "mVag", fv(fmt(C * 1.1, 1)), m2, "\(fmt(pcs(C * 1.1, "vag"))) \(pc) \(szj("vag"))"); addFn("nCeil", "mBatten", fv(fmt(C * 2, 0)), t("m"), nil)
    case "stretch": addFn("nCeil", "mStretch", fv(fmt(C, 1)), m2, fmt(cp, 1) + " " + t("m") + " " + t("mBaguette"))
    case "pvc": addFn("nCeil", "mPvcP", pcs(C * 1.1, "pvcP"), pc, szj("pvcP")); addFn("nCeil", "mStartProf", (cp * 1.05 / 3).rounded(.up), pc, "3 м"); addFn("nCeil", "mBatten", fv(fmt(C * 2, 0)), t("m"), nil); addFn("nCeil", "mScrew", (C * 15).rounded(.up), pc, nil)
    case "mdf": addFn("nCeil", "mMdfP", pcs(C * 1.1, "mdfP"), pc, szj("mdfP")); addFn("nCeil", "mBatten", fv(fmt(C * 2, 0)), t("m"), nil); addFn("nCeil", "mClips", (C * 12).rounded(.up), pc, nil); addFn("nCeil", "mCeilSkirt", (cp * 1.05 / 2.6).rounded(.up), pc, "2,6 м")
    case "deco": addFn("nCeil", "mDecoT", pcs(C * 1.1, "decoT"), pc, szj("decoT")); addFn("nCeil", "mCeilGlue", fv(fmt(C / 4, 1)), t("uKg"), nil); addFn("nCeil", "mCeilSkirt", (cp * 1.05 / 2).rounded(.up), pc, "2 м")
    case "arm": addFn("nCeil", "mArmT", pcs(C * 1.05, "armT"), pc, szj("armT")); addFn("nCeil", "mArmMain", (C * 0.84 / 3.7).rounded(.up), pc, "3,7 м"); addFn("nCeil", "mArmCross", (C * 1.67 / 1.2).rounded(.up), pc, "1,2 м")
        addFn("nCeil", "mArmCross", (C * 0.83 / 0.6).rounded(.up), pc, "0,6 м"); addFn("nCeil", "mArmAngle", (cp / 3).rounded(.up), pc, "3 м"); addFn("nCeil", "mArmHang", (C * 0.7).rounded(.up), pc, nil)
    case "rack": addFn("nCeil", "mRackP", pcs(C * 1.05, "rackP"), pc, szj("rackP")); addFn("nCeil", "mRackStr", fv(fmt(C * 1.1, 0)), t("m"), nil); addFn("nCeil", "mArmAngle", (cp / 3).rounded(.up), pc, "3 м"); addFn("nCeil", "mArmHang", (C * 0.7).rounded(.up), pc, nil)
    default: break
    }
    if cf == "lime" && ["plaster", "gkl"].contains(cb) { whA("nCeil", C) }
    if cf == "paint" && ["plaster", "gkl"].contains(cb) { addFn("nCeil", "mPaint", (C * RT("paint") / 10).rounded(.up), pc, nil) }
    if RM { rmFloor!() } else { let F = r.n("floor"); let ff = n.s("ff"); let Fm = max(F - (ff == "tile" ? 0 : n.n("wetF")), 0); let tr = 1 + RT("tileRes") / 100
        do { let Fs = max(0.0, F - (eq(n["base"], "joist") ? lagInfo(b, n).A : 0)); if n.n("scr") > 0 && Fs > 0 { addFn("nFloor", "mScreed", bag(Fs * n.n("scr") * RT("screed"), 50), bg, nil) } }
        if ff == "laminate" { let z = SZm("lam"); let pa = z[0] * z[1] * packSize(); addFn("nFloor", "mLam", (Fm * (1 + RT("lamRes") / 100) / pa).rounded(.up), pc, fmt(pa, 3) + " " + m2 + " · " + szj("lam")); addFn("nFloor", "mUnderlay", fv(fmt(Fm * 1.05, 1)), m2, nil) }
        if ff == "tile" { addFn("nFloor", "mTile", fv(fmt(Fm * tr, 1)), m2, "\(fmt(pcs(Fm * tr, "tileF"))) \(pc) \(szj("tileF"))"); addFn("nFloor", "mTileGlue", bag(Fm * RT("tileGlue"), 25), bg, nil); addFn("nFloor", "mGrout", fv(fmt(Fm * RT("grout"), 1)), t("uKg"), nil) }
        if ff == "lino" { addFn("nFloor", "mLino", fv(fmt(Fm * 1.05, 1)), m2, nil) }
        if ff == "board" { let z = SZm("board"); addFn("nFloor", "mBoard", fv(fmt(Fm * 1.1, 1)), m2, "\(fmt(pcs(Fm * 1.1, "board"))) \(pc) \(szj("board")) · \(fmt(Fm * 1.1 * z[2], 2)) \(t("uM3"))"); addFn("nFloor", "mJoist", fv(fmt(Fm / 0.6 * 1.05, 0)), t("m"), nil) }
        if ff != "none" && ff != "tile" { addFn("nFloor", "mSkirt", ((2 * (iw + id) * fl + 2 * inner) / 2.5).rounded(.up), pc, nil) }
        let wF = n.n("wetF"); let wW = n.n("wetW"); let T = wF + wW
        if T > 0 { if wF != 0 { addFn("nWet", "mTile", fv(fmt(wF * tr, 1)), m2, "\(fmt(pcs(wF * tr, "tileF"))) \(pc) \(szj("tileF"))") }; if wW != 0 { addFn("nWet", "mTileW", fv(fmt(wW * tr, 1)), m2, "\(fmt(pcs(wW * tr, "tileW"))) \(pc) \(szj("tileW"))") }
            addFn("nWet", "mTileGlue", bag(T * RT("tileGlue"), 25), bg, nil); addFn("nWet", "mGrout", fv(fmt(T * RT("grout"), 1)), t("uKg"), nil); addFn("nWet", "mWaterproof", fv(fmt((wF + wW * 0.3) * RT("waterproof"), 1)), t("uKg"), nil) } }
    let Fa = r.n("facade"); let pFT = n.n("pFacT")
    switch n.s("fac") {
    case "paint": let ty = n.str("pFacType") ?? "cem"
        if ty != "cem" { plA("nFacade", Fa, pFT, ty) } else { addFn("nFacade", "mFPlaster", (Fa * pFT * RT("cemRate") / n.n("bag")).rounded(.up), bg, "\(fmt(pFT)) мм · \(fmt(Fa * pFT * RT("cemRate"), 0)) кг · \(fmt(n.n("bag"))) кг/\(bg)") }
        addFn("nFacade", "mPrimer", (Fa * RT("primer") / 10).rounded(.up), pc, nil); addFn("nFacade", "mFPaint", (Fa * RT("facPaint") / 10).rounded(.up), pc, nil)
    case "ins": addFn("nFacade", "mIns", fv(fmt(Fa * n.n("insT") / 1000 * 1.05, 2)), t("uM3"), "\(fmt(pcs(Fa * 1.05, "ins"))) \(pc) \(fmt(SZ("ins")[0], 10))×\(fmt(SZ("ins")[1], 10))×\(fmt(n.n("insT"), 10))")
        addFn("nFacade", "mInsGlue", bag(Fa * RT("insGlue"), 25), bg, nil); addFn("nFacade", "mDowel", (Fa * RT("dowels")).rounded(.up), pc, nil)
        addFn("nFacade", "mMesh", (Fa * 1.15 / 50).rounded(.up), pc, nil); addFn("nFacade", "mDeco", bag(Fa * RT("deco"), 25), bg, nil); addFn("nFacade", "mFPaint", (Fa * RT("facPaint") / 10).rounded(.up), pc, nil)
    case "siding": addFn("nFacade", "mSiding", fv(fmt(Fa * 1.1, 1)), m2, "\(fmt(pcs(Fa * 1.1, "siding"))) \(pc) \(szj("siding"))"); addFn("nFacade", "mBatten", fv(fmt(Fa * 2, 0)), t("m"), nil)
    case "brick": addFn("nFacade", "mFBrick", (Fa * 51 * 1.05).rounded(.up), pc, nil); addFn("nFacade", "wCement", bag(Fa * 0.025 * 300, 50), bg, nil); addFn("nFacade", "mTies", (Fa * 4).rounded(.up), pc, nil)
    default: break
    }
    woodLines(b, n, addFn); opsLines(b, n, addFn)
    return fin()
}
