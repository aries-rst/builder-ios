import Foundation

/// число как в JS String(x) (для ключей цен)
func jsn(_ x: Double) -> String { fmt(x, 10) }
func newUid(_ i: Int = 0) -> String { String(Int(Date().timeIntervalSince1970 * 1000), radix: 36) + (i > 0 ? String(i) : "") }

func fenceDef() -> Obj { obj(("on", true), ("edges", nil), ("h", 2.0), ("type", "prof"), ("post", "p60"), ("step", 2.5), ("found", "conc"), ("fb", 0.3), ("fh", 0.6), ("color", "green"), ("gap", 30.0),
    ("mesh", 2.5), ("profT", 0.45), ("brickT", 0.12), ("cols", false),
    ("cu", obj(("name", ""), ("unit", "pcs"), ("w", 120.0), ("h", 2000.0), ("th", 20.0), ("gap", 20.0), ("rails", true))), ("cp", obj(("name", ""), ("size", "60×60"))),
    ("items", arr(obj(("k", "gate"), ("kind", "swing"), ("edge", 0.0), ("pos", 4.0), ("w", 3.5)), obj(("k", "wicket"), ("edge", 0.0), ("pos", 8.5), ("w", 1.0))))) }
@discardableResult func FN() -> Obj {
    let p = St.project; let d = fenceDef(); let f = keep(p, "fence", d)
    keep(f, "cu", fenceDef().o("cu")); keep(f, "cp", fenceDef().o("cp"))
    for (i, o) in f.a("items").objs.enumerated() where !truthy(o["uid"]) { o["uid"] = newUid() + String(i) }
    let n = plot().count; let e = f["edges"] as? Arr; if e == nil || e!.count != n { f["edges"] = Arr((0..<n).map { _ in true }) }
    return f
}
final class FSeg { let i: Int; let a: Double; let b: Double; let ux: Double; let uy: Double; let p0: Pt; let op: Obj?
    init(_ i: Int, _ a: Double, _ b: Double, _ ux: Double, _ uy: Double, _ p0: Pt, _ op: Obj? = nil) { self.i = i; self.a = a; self.b = b; self.ux = ux; self.uy = uy; self.p0 = p0; self.op = op } }
func fenceSegs() -> [FSeg] {
    let f = FN(); let poly = plot(); var segs = [FSeg](); let E = f.a("edges")
    for (i, a) in poly.enumerated() { if !truthy(E.at(i)) { continue }
        let b = poly[(i + 1) % poly.count]; let len = G.dist(a, b); let ux = (b[0] - a[0]) / len; let uy = (b[1] - a[1]) / len
        var ops = [(Obj, Double, Double)](); for o in f.a("items").objs where Int(num(o["edge"])) == i { let s = max(0.0, min(len - o.n("w"), o.n("pos"))); ops.append((o, s, s + o.n("w"))) }
        ops = ops.enumerated().sorted { $0.element.1 != $1.element.1 ? $0.element.1 < $1.element.1 : $0.offset < $1.offset }.map { $0.element }
        var cur = 0.0; for (o, s, e) in ops { if s > cur + 0.05 { segs.append(FSeg(i, cur, s, ux, uy, a)) }; segs.append(FSeg(i, s, e, ux, uy, a, o)); cur = max(cur, e) }
        if len > cur + 0.05 { segs.append(FSeg(i, cur, len, ux, uy, a)) } }
    return segs
}
func calcFence() -> Obj {
    let f = FN(); let segs = fenceSegs(); let fen = segs.filter { $0.op == nil }; let ops = segs.filter { $0.op != nil }; let r = obj()
    let L = fen.reduce(0) { $0 + $1.b - $1.a }; let H = f.n("h"); let dep = H > 1.8 ? 1.2 : 1.0; r["L"] = L; r["H"] = H; let type = f.s("type")
    let heavy = ["brick", "block"].contains(type); var posts = fen.reduce(0) { $0 + (($1.b - $1.a) / f.n("step")).rounded(.up) + 1 }
    posts = max(posts - Double(segs.count) + Double(fen.count), 2); r["gatePosts"] = Double(ops.count) * 2
    if type == "concrete" { r["sections"] = fen.reduce(0) { $0 + (($1.b - $1.a) / 2).rounded(.up) }; r["cPanels"] = r.n("sections") * (H / 0.5).rounded(.up); r["cPosts"] = r.n("sections") + Double(fen.count); posts = 0 }
    if heavy { let isBr = type == "brick"; let bz = isBr ? D.BFMT.o("1NF") : obj(("L", 0.39), ("H", 0.188), ("D", 0.19)); let th = isBr ? f.n("brickT") : 0.19
        let perM3 = 1 / ((bz.n("L") + 0.01) * (bz.n("H") + 0.01) * ((isBr ? bz.n("D") : th) + 0.01))
        r["wallV"] = L * H * th; r["units"] = (r.n("wallV") * perM3 * 1.05).rounded(.up); r["pillars"] = (L / 3).rounded(.up) + Double(fen.count); r["pillarUnits"] = (r.n("pillars") * 0.38 * 0.38 * (H + 0.2) * perM3 * 1.05).rounded(.up); r["caps"] = r["pillars"]
        r["mortar"] = (r.n("wallV") + r.n("pillars") * 0.38 * 0.38 * H) * 0.23; r["cementBags"] = (r.n("mortar") * RT("mortCem") / 50).rounded(.up); r["sand"] = r.n("mortar") * RT("mortSand"); posts = 0 }
    if f.b("cols") && !heavy && type != "concrete" { r["pillars"] = posts; r["pillarUnits"] = (posts * 0.38 * 0.38 * (H + 0.2) * 394 * 1.05).rounded(.up); r["caps"] = posts; r["mortar"] = posts * 0.38 * 0.38 * H * 0.23
        r["cementBags"] = (r.n("mortar") * RT("mortCem") / 50).rounded(.up); r["sand"] = r.n("mortar") * RT("mortSand") }
    r["posts"] = posts; r["postLen"] = H + dep; let rows: Double = H > 1.8 ? 3 : 2; r["rows"] = rows; let cu = f.o("cu")
    if ["prof", "euro", "board"].contains(type) || (type == "custom" && cu.b("rails")) { r["railM"] = L * rows * 1.05 }
    if type == "custom" { switch cu.s("unit") { case "pcs": r["cuQty"] = (L / ((cu.n("w") + cu.n("gap")) / 1000)).rounded(.up) * max(1.0, (H / (cu.n("h") / 1000)).rounded(.up)); case "m2": r["cuQty"] = L * H * 1.05; default: r["cuQty"] = L * 1.05 } }
    if type == "prof" { r["sheets"] = (L / 1.15).rounded(.up); r["sheetArea"] = r.n("sheets") * 1.2 * H; r["screws"] = (r.n("sheetArea") * RT("fenceScrews")).rounded(.up) }
    if type == "euro" { r["planks"] = (L / (0.118 + f.n("gap") / 1000)).rounded(.up); r["screws"] = r.n("planks") * rows * 2 }
    if type == "board" { let bz = SZm("board"); r["boards"] = (L / (bz[1] + f.n("gap") / 1000)).rounded(.up); r["boardV"] = r.n("boards") * H * bz[1] * bz[2]; r["anti"] = (L * H * 2 * 0.2).rounded(.up) }
    if type == "mesh" { r["rolls"] = (L * 1.05 / 10).rounded(.up); r["wire"] = L * 3 * 1.05 }
    if type == "panel3d" { r["panels"] = (L / 2.5).rounded(.up); r["clips"] = r.n("panels") * 4 }
    if eq(f["found"], "conc") && posts != 0 { r["holeV"] = (posts + r.n("gatePosts")) * Double.pi * 0.125 * 0.125 * dep * 1.1 }
    if eq(f["found"], "strip") || heavy { r["stripV"] = L * f.n("fb") * f.n("fh") * 1.05; r["stripRebar"] = L * 4 * 1.1 * 0.888; r["stripForm"] = 2 * L * (f.n("fh") + 0.1); r["dig"] = L * (f.n("fb") + 0.2) * f.n("fh") }
    let its = f.a("items").objs; let gates = its.filter { eq($0["k"], "gate") && !eq($0["mode"], "custom") }; let wk = its.filter { eq($0["k"], "wicket") && !eq($0["mode"], "custom") }
    r["frame"] = gates.reduce(0) { acc, g in let w = g.n("w"); return acc + (eq(g["kind"], "slide") ? 2 * (w * 1.5 + H) + w * 1.5 : 2 * (2 * (w / 2 + H)) + w) } + wk.reduce(0) { $0 + 2 * ($1.n("w") + H) + $1.n("w") }
    r["infill"] = gates.reduce(0) { $0 + $1.n("w") * H } + wk.reduce(0) { $0 + $1.n("w") * H }; r["hinges"] = Double(gates.filter { !eq($0["kind"], "slide") }.count) * 4 + Double(wk.count) * 2; r["locks"] = Double(gates.count + wk.count)
    let sl = gates.filter { eq($0["kind"], "slide") }; r["kits"] = Double(sl.count); r["channel"] = sl.reduce(0) { $0 + $1.n("w") * 0.5 }; if !sl.isEmpty { r["slideV"] = Double(sl.count) * 0.6 }
    St.project["calcFence"] = r; return r
}
func fenceLines() -> [Line] {
    let f = FN(); let r = calcFence(); let fp = D.o("FPOSTS").aa(f.s("post")) ?? arr("", "", "", 0.0); let B = LB()
    let m2 = t("m2"); let m3 = t("uM3"); let pc = t("uPcs"); let kg = t("uKg"); let bg = t("uBags"); let mm = t("m"); func a(_ pk: String, _ l: String, _ q: Double, _ u: String) { B.add(nil, pk, l, q, u) }
    let type = f.s("type"); let H = f.n("h")
    if type == "custom" { let c = f.o("cu"); let nm = c.s("name").isEmpty ? t("fnCustom") : c.s("name"); let dim = eq(c["unit"], "pcs") ? jsn(c.n("w")) + "×" + jsn(c.n("h")) + "×" + jsn(c.n("th")) + " мм" : ""
        a("fcustom", "\(nm) \(dim)", r.n("cuQty"), eq(c["unit"], "pcs") ? pc : eq(c["unit"], "m2") ? m2 : mm) }
    if eq(f["post"], "custom") && r.n("posts") != 0 { let cp = f.o("cp"); a("fpost_custom", "\(cp.s("name").isEmpty ? t("fnCustomPost") : cp.s("name")) \(cp.s("size")) × \(fmt(r.n("postLen"), 1)) \(mm)", r.n("posts"), pc) }
    for o in f.a("items").objs where eq(o["mode"], "custom") { let nm = o.s("cname").isEmpty ? (eq(o["k"], "gate") ? t("fnGate") : t("fnWicket")) : o.s("cname")
        a("gitem_" + o.s("uid"), "\(eq(o["k"], "gate") ? "🚪" : "🚶") \(nm) \(mround(o.n("w") * 1000))×\(mround(H * 1000))", 1.0, pc) }
    if r.n("posts") != 0 && !eq(f["post"], "custom") { a("fpost_" + f.s("post"), tr3(fp) + " " + fmt(r.n("postLen"), 1) + " " + mm, r.n("posts"), pc) }
    a("fpost_gate", t("fnGatePosts"), r.n("gatePosts"), pc)
    a("conc_M200", t("eConcrete") + " M200", r.n("holeV"), m3); a(type == "board" ? "batten4050" : "pipe4020", t("fnRails"), r.n("railM"), mm)
    if r.n("sheets") != 0 { a("fprof_" + jsn(f.n("profT")), tr3(D.o("FTYPES").o("prof")["n"]) + " " + jsn(f.n("profT")) + " мм", r.n("sheetArea"), m2) }
    a("feuro", tr3(D.o("FTYPES").o("euro")["n"]) + " ×" + fmt(H, 2), r.n("planks"), pc)
    if r.n("boards") != 0 { a("board", t("eTimber"), r.n("boardV"), m3) }; a("antiseptic", t("fnAnti"), r.n("anti"), t("uL")); a("screwRoof", t("fnScrews"), r.n("screws"), pc)
    a("mesh_" + jsn(f.n("mesh")) + "_" + jsn(H), t("fnRolls") + " ×" + fmt(H, 1), r.n("rolls"), pc); a("twire", t("fnWire"), r.n("wire"), mm)
    a("panel3d_" + jsn(H), t("fnPanels") + " 3D", r.n("panels"), pc); a("clip3d", t("fnClips"), r.n("clips"), pc)
    if r.n("cPanels") != 0 { a("cpanel", t("fnConcSec"), r.n("cPanels"), pc); a("cpost", t("fnConcPost"), r.n("cPosts"), pc) }
    if r.n("units") != 0 { a(type == "brick" ? "blk_brick_1NF_ceramFull_f" : "blk_keram_f", type == "brick" ? tr3(D.BTYPE.o("ceramFull")["n"]) + " 1НФ" : tr3(D.o("FTYPES").o("block")["n"]), r.n("units"), pc) }
    a("blk_brick_1NF_ceramFull_f", t("fnPillars"), r.n("pillarUnits"), pc); a("fcap", t("fnCaps"), r.n("caps"), pc)
    if r.n("cementBags") != 0 { a("cement50", t("eCement"), r.n("cementBags"), bg); a("sand", t("eSand"), r.n("sand"), m3) }
    if r.n("stripV") != 0 { a("conc_M200", t("eConcrete") + " M200", r.n("stripV"), m3); a("rebar12", t("eRebar") + " Ø12", r.n("stripRebar"), kg); a("dig", t("eDig"), r.n("dig"), m3) }
    a("pipe6040", t("fnFrame"), r.n("frame"), mm); a("ginfill_\(type)", t("fnInfill"), r.n("infill"), m2)
    a("hinge", t("fnHinges"), r.n("hinges"), pc); a("lock", t("fnLocks"), r.n("locks"), pc)
    if r.n("kits") != 0 { a("slidekit", t("fnGateKit"), r.n("kits"), pc); a("channel", t("fnChannel"), r.n("channel"), mm); a("conc_M200", t("eConcrete") + " M200", r.n("slideV"), m3) }
    return B.L
}
