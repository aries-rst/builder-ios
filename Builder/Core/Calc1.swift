import Foundation

let D8 = 0.395
func cint(_ x: Double) -> Double { x.rounded(.up) }
func rebarKg(_ d: Double) -> Double { let v = num(D.o("REBAR_KG")[fmt(d, 0)], 0.888); return v == 0 ? 0.888 : v }
func mix(_ g: String) -> [Double] { (D.o("MIX").aa(g) ?? D.o("MIX").a("M200")).nums }
func fbsDim(_ m: String) -> [Double] { (D.FBS.aa(m) ?? D.FBS.a("24.4.6")).nums }
struct FbsC { var pcs: Double; var rest: Double; var restV: Double }
func fbsCount(_ L: Double, _ mark: String, _ rows: Double) -> FbsC {
    let d = fbsDim(mark); let l = d[0]; let w = d[1]; let h = d[2]; let lm = l / 1000 + 0.01; let per = (L / lm).rounded(.down); let rest = L - per * lm
    return FbsC(pcs: per * rows, rest: rest, restV: rest * w / 1000 * h / 1000 * rows)
}
func inc(_ r: Obj, _ k: String, _ v: Double) { r[k] = num(r[k]) + v }
func storeCalc(_ b: Obj, _ k: String, _ r: Obj) { b.o("calc")[k] = r }

func calcFound0(_ b: Obj) -> Obj {
    let f = b.o("f"); let r = obj(("type", f["type"])); let kg = rebarKg(f.n("rd")); var ties = 0.0
    func F(_ k: String) -> Double { f.n(k) }
    switch f.s("type") {
    case "strip":
        let Lo = bPer(b) - 4 * F("b"); let Li = F("inner"); let no: Double = F("h") > 0.6 ? 6 : 4; let ni: Double = F("hi") > 0.6 ? 6 : 4
        let clo = (Lo / 0.4).rounded(.up) + 1; let cli = Li > 0 ? (Li / 0.4).rounded(.up) + 1 : 0.0
        r["L"] = Lo; r["Li"] = Li; r["V"] = Lo * F("b") * F("h") + Li * F("bi") * F("hi"); r["mainM"] = (Lo * no + Li * ni) * 1.1
        r["clampM"] = clo * (2 * ((F("b") - 0.1) + (F("h") - 0.1)) + 0.2) + cli * (2 * ((F("bi") - 0.1) + (F("hi") - 0.1)) + 0.2); ties = clo * no + cli * ni
        r["form"] = 2 * (Lo * (F("h") + 0.1) + Li * (F("hi") + 0.1)); let two = F("b") + 0.2; let twi = F("bi") + 0.2
        r["bedSand"] = (Lo * two + Li * twi) * F("sand"); r["bedGravel"] = (Lo * two + Li * twi) * F("gravel")
        r["dig"] = Lo * two * (F("h") + F("sand") + F("gravel")) + Li * twi * (F("hi") + F("sand") + F("gravel"))
    case "fbs":
        let fo = fbsDim(f.s("fbs")); let fi = fbsDim(f.s("fbsIn")); let wo = fo[1] / 1000; let wi = fi[1] / 1000; let Lo = bPer(b) - 4 * wo; let Li = F("inner"); let hh = F("rows") * (fo[2] / 1000 + 0.01)
        let o = fbsCount(Lo, f.s("fbs"), F("rows")); let i = Li > 0 ? fbsCount(Li, f.s("fbsIn"), F("rows")) : FbsC(pcs: 0, rest: 0, restV: 0)
        r["L"] = Lo; r["Li"] = Li; r["fbsOut"] = o.pcs; r["fbsIn"] = i.pcs; r["fbsH"] = hh
        var vo: Double = 1; for x in fo { vo *= x / 1000 }
        var vi: Double = 1; for x in fi { vi *= x / 1000 }
        r["fbsW"] = (o.pcs * vo + i.pcs * vi) * 2.4
        r["insertV"] = (o.restV + i.restV) * 1.05; let pad = f.b("pad"); let pw = wo + 0.2; let pwi = wi + 0.2
        r["padV"] = pad ? (Lo * pw + Li * pwi) * 0.3 : 0.0; r["V"] = r.n("padV") + r.n("insertV")
        r["mainM"] = pad ? (Lo + Li) * 4 * 1.1 : 0.0
        r["clampM"] = pad ? (((Lo + Li) / 0.5).rounded(.up) + 1) * (2 * (pw - 0.1) + 0.2) : 0.0
        ties = pad ? (((Lo + Li) / 0.5).rounded(.up) + 1) * 4 : 0.0
        r["mortarBags"] = ((o.pcs + i.pcs) * 0.02 * 300 / 50).rounded(.up); r["form"] = pad ? 2 * (Lo + Li) * 0.35 : 0.0
        r["bedSand"] = (Lo * pw + Li * pwi) * F("sand"); r["bedGravel"] = (Lo * pw + Li * pwi) * F("gravel")
        r["dig"] = (Lo * (pw + 0.4) + Li * (pwi + 0.4)) * (hh + (pad ? 0.3 : 0.0) + F("sand") + F("gravel") - 0.3)
    case "slab":
        let BA = bArea(b); let cn = (BA / 0.16).rounded(.up) + 1; let A = BA + bPer(b) * 0.3 + 0.36
        r["A"] = BA; r["V"] = BA * F("slabT"); r["mainM"] = 4 * BA / F("mesh") * 1.05; r["clampM"] = cn * max(F("slabT") - 0.05, 0.1); ties = (2 * BA / (F("mesh") * F("mesh"))).rounded(.up)
        r["form"] = bPer(b) * (F("slabT") + 0.1); r["bedSand"] = A * F("sand"); r["bedGravel"] = A * F("gravel"); r["dig"] = A * (F("slabT") + F("sand") + F("gravel"))
    default:
        let a = F("a"); let L = bPer(b) - 4 * a + F("inner"); let n = max(4.0, (L / F("step")).rounded(.up)); let gh = 0.4; let pc = (F("pd") / 0.5).rounded(.up) + 1; let tw = pow(a + 0.2, 2); let gr = f.b("grill")
        r["L"] = L; r["n"] = n; r["V"] = n * a * a * F("pd") + (gr ? L * F("b") * gh : 0.0)
        r["mainM"] = (n * 4 * (F("pd") + 0.3) + (gr ? L * 4 * 1.1 : 0.0)) * 1.05
        r["clampM"] = n * pc * (4 * (a - 0.1) + 0.2) + (gr ? ((L / 0.4).rounded(.up) + 1) * (2 * ((F("b") - 0.1) + (gh - 0.1)) + 0.2) : 0.0)
        ties = n * pc * 4 + (gr ? ((L / 0.4).rounded(.up) + 1) * 4 : 0.0)
        r["form"] = n * 4 * a * 0.3 + (gr ? 2 * L * gh : 0.0)
        r["bedSand"] = n * tw * F("sand"); r["bedGravel"] = n * tw * F("gravel"); r["dig"] = n * tw * (F("pd") + F("sand") + F("gravel"))
    }
    r["V"] = r.n("V") * (1 + RT("concRes") / 100); r["mainKg"] = r.n("mainM") * kg; r["clampKg"] = r.n("clampM") * D8; r["wire"] = ties * RT("wireTie") / 1000; r["formM3"] = r.n("form") * 0.025
    let g = f.s("grade"); let m = mix(g); let V = r.n("V")
    r["cement"] = (V * (D.RDEF.has("cem\(g)") ? RT("cem\(g)") : m[0]) / 50).rounded(.up); r["sandMix"] = V * m[1]; r["gravelMix"] = V * m[2]; r["water"] = V * 190
    storeCalc(b, "found", r); return r
}
func calcFound(_ b: Obj) -> Obj {
    let r = calcFound0(b); let f = b.o("f"); let W = b.oo("walls") ?? obj(); if f["tolL"] == nil { f["tolL"] = 2.0 }
    if ["open", "poly"].contains(W.s("mat")) || !f.b("tolL") { r["tolA"] = 0.0; r["tolRolls"] = 0.0; return r }
    let t2 = W.nz("t", 0.3); let Lc = bPer(b) - 4 * t2 + f.n("inner"); r["tolA"] = Lc * t2 * f.n("tolL") * 1.15; r["tolRolls"] = (r.n("tolA") / 10).rounded(.up); return r
}

func pbFor(_ w: Double) -> Arr? { let need = (w + 0.5) * 1000; for x in D.a("PB") { if let a = x as? Arr, a.n(1) >= need { return a } }; return nil }
func pkFor(_ need: Double) -> Int? { var n = 24; while n <= 90 { if Double(n * 100 - 20) >= need * 1000 { return n }; n += 3 }; return nil }
func calcSlabs(_ b: Obj) -> Obj {
    let W = b.o("walls"); let s = W.str("slab") ?? "none"; let t = W.nz("t", 0.3); let r = obj(("type", s))
    if s == "none" || ["poly", "open"].contains(W.s("mat")) { return r }
    let sc = (isShaped(b) ? roofSpan(b) : min(b.n("w"), b.n("d"))) - 2 * t; let lc = isShaped(b) ? inArea(b, t) / max(sc, 0.5) : max(b.n("w"), b.n("d")) - 2 * t
    let lev = b.n("floors"); r["levels"] = lev; r["span"] = sc; r["area"] = sc * lc * lev
    if s == "pk" { let need = sc + 0.24; let n = pkFor(need); let pw = W.nz("pw", 1.2); let wa = num(D.PK_W[fmt(pw)]) / 1000; r["need"] = need
        guard let nn = n else { r["tooLong"] = 1.0; return r }
        let per = (lc / (wa + 0.01)).rounded(.down); let rem = lc - per * (wa + 0.01); r["mark"] = "ПК \(nn).\(mround(pw * 10))-8"; r["len"] = Double(nn * 100 - 20) / 1000.0; r["pcs"] = per * lev
        r["wt"] = r.n("len") * wa * 0.22 * 0.72 * 2.5; r["wtAll"] = r.n("wt") * r.n("pcs"); r["monoV"] = rem > 0.05 ? rem * need * 0.22 * lev * 1.05 : 0.0 }
    if s == "wood" { let n = (lc / 0.6).rounded(.down) + 1; r["beams"] = n * lev; r["beamLen"] = sc + 0.3; r["timber"] = r.n("beams") * r.n("beamLen") * 0.1 * 0.2 * 1.05 }
    if s == "mono" { let A = (sc + 0.24) * (lc + 0.24); r["V"] = A * 0.2 * lev * 1.05; let nx = ((lc + 0.24) / 0.2).rounded(.down) + 1; let ny = ((sc + 0.24) / 0.2).rounded(.down) + 1
        r["rebarKg"] = 2 * (nx * (sc + 0.24) + ny * (lc + 0.24)) * 1.05 * 0.888 * lev }
    return r
}

struct PartInfo { var len: Double; var area: Double }
func partInfo(_ b: Obj) -> PartInfo {
    if ["poly", "open"].contains(b.o("walls").s("mat")) { return PartInfo(len: 0, area: 0) }; ensureRooms(b); let inn = inner(b); let iw = inn.iw; let id = inn.id; var len = 0.0; var area = 0.0
    for l in levels(b) { let rs = b.a("rooms").objs.filter { lvEq($0["lv"], l) }; let h = eq(l, "a") ? 2.2 : lvH(b, l); var s = 0.0
        if isManual(b, l) { s = wallsOf(planOf(b, l)!).reduce(0) { $0 + hypot2($1.n("x1") - $1.n("x0"), $1.n("y1") - $1.n("y0")) }; len += s; area += s * h; continue }
        for q in rs { let x = q.n("x"); let y = q.n("y"); let w = q.n("w"); let d = q.n("d")
            for (c, ln, vert) in [(y, w, false), (x + w, d, true), (y + d, w, false), (x, d, true)] {
                let onOut = vert ? (c < 0.06 || abs(c - iw) < 0.06) : (c < 0.06 || abs(c - id) < 0.06); if !onOut { s += ln } } }
        for i in rs.indices { for j in (i + 1)..<max(rs.count, i + 1) { let A = rs[i]; let B = rs[j]
            if abs(A.n("x") + A.n("w") - B.n("x")) < 0.06 || abs(B.n("x") + B.n("w") - A.n("x")) < 0.06 { s -= max(0, min(A.n("y") + A.n("d"), B.n("y") + B.n("d")) - max(A.n("y"), B.n("y"))) }
            if abs(A.n("y") + A.n("d") - B.n("y")) < 0.06 || abs(B.n("y") + B.n("d") - A.n("y")) < 0.06 { s -= max(0, min(A.n("x") + A.n("w"), B.n("x") + B.n("w")) - max(A.n("x"), B.n("x"))) } } }
        s = max(0, s); len += s; area += s * h }
    return PartInfo(len: len, area: area)
}

/// Каркасные стены: деревянный каркас, сэндвич-панели, синч (каркас с заполнением гувалой).
func frameItems(_ fr: String, _ W: Obj, _ Lc: Double, _ H: Double, _ net: Double, _ pLen: Double, _ pA: Double, _ t: Double, _ nOps: Double) -> Arr {
    let L = arr(); func a(_ pk: String, _ k: String, _ q: Double, _ u: String) { if q > 0 { L.add(obj(("pk", pk), ("k", k), ("q", q), ("u", u))) } }
    let A = net + pA
    switch fr {
    case "frame":
        let studs = (Lc / 0.6).rounded(.up) + 8 + 2 * nOps + (pLen / 0.6).rounded(.up); let studV = studs * H * 0.05 * t; let plateV = 3 * (Lc + pLen) * 0.05 * t
        a("timber", "wFrStuds", (studV + plateV) * 1.1, "uM3"); a("wool", "wFrWool", net * t * 1.05, "uM3")
        a("osb", "wFrOSB", (A * 2 * 1.1 / 3.125).rounded(.up), "uPcs"); a("frm_vapor", "wFrVapor", net * 1.15, "m2"); a("frm_wind", "wFrWind", net * 1.15, "m2"); a("nails", "wNails", A * 0.3, "uKg")
    case "sandwich":
        let posts = (Lc / 3).rounded(.up) + 4; a("sandwich_" + jsn(t), "wSwPanel", net * 1.05, "m2"); a("pipe8080", "wSwPost", posts * (H + 0.5), "m")
        a("pipe6040", "wSwGirt", ((H / 1.5).rounded(.up) + 1) * Lc, "m"); a("screwSw", "wSwScrew", (net * 4).rounded(.up), "uPcs"); a("swFlash", "wSwFlash", 4 * H + 2 * Lc + nOps * 4, "m")
    case "sinch":
        let posts = Lc.rounded(.up) + 4 + pLen.rounded(.up); let pv = posts * H * 0.1 * 0.1; let beam = 3 * (Lc + pLen) * 0.1 * 0.15; let br = posts * H * 1.4 * 0.05 * 0.1
        a("timber", "wSnPost", (pv + beam + br) * 1.1, "uM3"); let fill = (net * t + pA * W.n("innerT")) * 0.85
        a("guvala", "wSnFill", (fill / (0.26 * 0.13 * 0.11)).rounded(.up), "uPcs"); a("clay", "wSnClay", fill * 0.25, "uM3"); a("snPlaster", "wSnPlaster", (net + pA) * 2 * 0.025 * 1.1, "uM3"); a("nails", "wNails", A * 0.2, "uKg")
    default: break
    }
    return L
}

func calcWalls(_ b: Obj) -> Obj {
    let W = b.o("walls"); let m = MI(W) ?? D.WMAT.o("gas"); let t = W.n("t"); let H = b.n("floors") * b.n("floorH"); let r = obj()
    let Lc = bPer(b) - 4 * t; r["Lc"] = Lc; r["H"] = H
    let gable = W.b("gables") ? gableArea(b) : 0.0
    let ops = W.a("openings").objs
    r["gross"] = Lc * H + gable; r["open"] = ops.reduce(0) { $0 + $1.n("w") * $1.n("h") * $1.n("q") }; r["net"] = max(r.n("gross") - r.n("open"), 0)
    let autoIn: Bool; if let v = W["innerAuto"] as? Bool, v == false { autoIn = false } else { autoIn = true }
    let PA = autoIn ? partInfo(b) : PartInfo(len: W.n("innerLen"), area: W.n("innerLen") * H); r["partLen"] = PA.len; r["partA"] = PA.area
    let net = r.n("net"); let vol = net * t + PA.area * W.n("innerT"); r["vol"] = vol
    let fr = m.s("frame")
    if !fr.isEmpty { r["fItems"] = frameItems(fr, W, Lc, H, net, PA.len, PA.area, t, ops.reduce(0) { $0 + $1.n("q") }); r["lintels"] = obj(); r["count"] = 0.0; r["rows"] = 0.0
        r["weight"] = vol * m.n("dens") / 1000; storeCalc(b, "walls", r); return r }
    let mL = m.n("L"); let mH = m.n("H"); let mj = m.n("j"); let mjh = (!m.b("glue") && mj > 0) ? 0.012 : mj; let hasD = m.n("D") != 0; let Dm = m.nz("D", t)
    let perM3 = 1 / ((mL + mj) * (mH + mjh) * (Dm + mj))
    let count = ((net * t * perM3 + (hasD ? PA.area * W.n("innerT") * perM3 : PA.area / ((mL + mj) * (mH + mjh)))) * (1 + RT("blkRes") / 100)).rounded(.up); r["count"] = count
    r["pallets"] = m.n("pal") != 0 ? (count / m.n("pal")).rounded(.up) : (vol * 1.05 / m.n("palM3")).rounded(.up)
    let wood = m.b("wood")
    if wood {} else if m.b("glue") { r["glueBags"] = (vol * RT("blkGlue") / 25).rounded(.up) }
    else { let blockVol = count / 1.05 * mL * mH * Dm
        var mort = max(vol - (hasD ? blockVol : vol * (1 - ((mL * mH) / ((mL + mj) * (mH + mjh))))), 0)
        if !hasD { mort = vol * (1 - (mL * mH) / ((mL + mj) * (mH + mjh))) + vol * 0.02 }
        r["mortar"] = mort; if m.b("clay") { r["cementBags"] = 0.0; r["sand"] = 0.0; r["clay"] = mort * 1.1 } else { r["cementBags"] = (mort * RT("mortCem") / 50).rounded(.up); r["sand"] = mort * RT("mortSand") } }
    r["lintelPcs"] = 0.0; let lint = obj(); r["lintels"] = lint; r["lintelMono"] = 0.0
    if !wood { for o in ops { let pcs = o.n("q") * (t / 0.125).rounded(.up); if let pb = pbFor(o.n("w")) { inc(r, "lintelPcs", pcs); inc(lint, pb.s(0), pcs) } else { inc(r, "lintelMono", o.n("q") * (o.n("w") + 0.5) * t * 0.2) } } }
    if W.b("belt") { r["beltV"] = b.n("floors") * Lc * t * 0.25 * 1.05; r["beltRebarM"] = b.n("floors") * Lc * 4 * 1.1; r["beltRebarKg"] = r.n("beltRebarM") * 0.888 }
    let rows = (H / (mH + mjh)).rounded(.down); r["rows"] = rows
    if wood { r["jute"] = Lc * rows } else if m.b("glue") { r["reinfM"] = 2 * Lc * (rows / 4).rounded(.up) } else { r["meshM2"] = Lc * t * (rows / 5).rounded(.up) }
    r["weight"] = vol * m.n("dens") / 1000
    storeCalc(b, "walls", r); return r
}

// ---------- кровля ----------
private let ROOF_MAX: Set<String> = ["slope", "rise", "L", "sheetLen", "raftersLen", "pipeLen"]
func calcRoof(_ b: Obj) -> Obj {
    if !isShaped(b) { return calcRoofOne(b) }; RF(b)
    let dims: [(Double, Double)] = wings(b)?.map { ($0.w, $0.d) } ?? { let e = eqRect(b); return [(e[0], e[1])] }()
    let parts = dims.map { (w, d) -> Obj in let p = assign(obj(), b, obj(("w", w), ("d", d))); p["shape"] = nil; return p }; let rs = parts.map { calcRoofOne($0) }; let r = obj()
    for x in rs { for (k, v) in x.entries { guard let dv = v as? Double else { continue }; if ROOF_MAX.contains(k) { r[k] = max(r.n(k), dv) } else { r[k] = r.n(k) + dv } } }
    r["sheetDim"] = rs[0]["sheetDim"]
    if wings(b) == nil && pitched(b) { let T = polyRoofTop(b); let A = bArea(b); let Ac = max(0, G.sarea(T.o)); let a = RF(b).n("angle") * Double.pi / 180
        let na = (A - Ac) / cos(a) + Ac + bPer(b) * RF(b).n("over") / cos(a); let k = na / (r.n("area") == 0 ? na : r.n("area"))
        for x in ["area", "sheets", "sheetArea", "packs", "osb", "under", "membrane", "vapor", "wool", "lath", "timber", "screws"] where r.n(x) != 0 {
            r[x] = ["area", "sheetArea", "wool", "timber", "lath"].contains(x) ? r.n(x) * k : (r.n(x) * k).rounded(.up) }
        r["rise"] = polyRoofRise(b); r["hips"] = 0.0 }
    let (vn, vl) = valleyInfo(b); if vn > 0 { r["valleys"] = Double(vn); r["valleyLen"] = vl; r["valleyPcs"] = (vl / 1.9).rounded(.up); r["area"] = r.n("area") + vl * 0.6 }
    storeCalc(b, "roof", r); return r
}
func rafterDims(_ f: Obj) -> (Double, Double) { let p = f.s("rafter").split(separator: "x", omittingEmptySubsequences: false).map { (Double($0) ?? 0) / 1000 }; return (p.count > 0 ? p[0] : 0, p.count > 1 ? p[1] : 0) }
func calcRoofOne(_ b: Obj) -> Obj {
    let f = RF(b); let r = obj(); let bw = b.n("w"); let bd = b.n("d")
    if eq(b["roof"], "FLAT") { let A = (bw + 0.2) * (bd + 0.2); r["area"] = A; r["flatRolls"] = (A * 2 * 1.15 / 10).rounded(.up); r["vapor"] = (A * 1.15 / 75).rounded(.up)
        if f.b("ins") { r["wool"] = A * f.n("ins") / 1000 * 1.05 }; r["gutter"] = (2 * max(bw, bd) / 3).rounded(.up); r["pipes"] = 2.0; r["pipeLen"] = b.n("floors") * b.n("floorH")
        let n = (max(bw, bd) / f.n("step")).rounded(.down) + 1; let (tw, th) = rafterDims(f); r["raftersN"] = n; r["raftersLen"] = min(bw, bd) + 0.3; r["timber"] = n * r.n("raftersLen") * tw * th
        return r }
    let s = min(bw, bd); let Lb = max(bw, bd); let o = f.n("over"); let L = Lb + 2 * o; let a = f.n("angle") * Double.pi / 180; let R = riseFor(b, s); let sides: Double = eq(b["roof"], "SHED") ? 1 : 2; let cut = eq(b["roof"], "HIP")
    let slope: Double; let area: Double; var ridgeL = L; var hips = 0.0
    switch b.s("roof") {
    case "SHED": slope = (s + o) / cos(a); area = slope * L
    case "HIP": slope = (s / 2 + o) / cos(a); area = (Lb + 2 * o) * (s + 2 * o) / cos(a); ridgeL = max(Lb - s, 0); hips = 4 * hypot2(2.0.squareRoot() * (s / 2 + o), R); r["hips"] = hips
    case "MANSARD": let (hl, p) = mansP(s); slope = hl / sin(MLA) + o + (s / 2 - p) / cos(a); area = 2 * slope * L; r["brk"] = hl
    default: slope = (s / 2) / cos(a) + o / cos(a); area = 2 * slope * L
    }
    r["slope"] = slope; r["L"] = L; r["rise"] = R; r["area"] = area
    let cov = f.s("cover"); let c = D.COVERS.oo(cov) ?? obj()
    if cov == "soft" { let oz = SZm("osb"); r["packs"] = (area * 1.1 / c.n("pack")).rounded(.up); r["osb"] = (area * 1.05 / (oz[0] * oz[1])).rounded(.up); r["under"] = (area * 1.1 / 15).rounded(.up) }
    else if c.n("ul") != 0 { let z = SZm(cov); let uw = z[1] - (cov == "slate" ? 0.15 : 0.12); let ul = z[0] - 0.15
        r["sheets"] = cut ? (area * 1.15 / (uw * ul)).rounded(.up) : sides * (L / uw).rounded(.up) * (slope / ul).rounded(.up); r["sheetDim"] = SZ(cov).map { fmt($0) }.joined(separator: "×") }
    else if cov == "custom" { let cc = f.oo("cc") ?? obj(("uw", 1000.0), ("ul", 2000.0)); let uw = cc.n("uw"); let ul = cc.n("ul")
        r["sheets"] = cut ? (area * 1.15 / (uw * ul / 1e6)).rounded(.up) : sides * (L / (uw / 1000)).rounded(.up) * (slope / (ul / 1000)).rounded(.up); r["sheetDim"] = cc.s("name") + " " + fmt(uw) + "×" + fmt(ul) }
    else if cov == "cer" { let z = SZm("ctile"); r["sheets"] = (area * 1.05 / (z[0] * 0.8 * z[1] * 0.9)).rounded(.up); r["sheetDim"] = SZ("ctile").map { fmt($0) }.joined(separator: "×") }
    else { let z = SZm(cov); let uw = z[1]; let fw = z[0]; r["sheets"] = cut ? (area * 1.15 / (fw * slope)).rounded(.up) + 4 : sides * (L / uw).rounded(.up); r["sheetDim"] = SZ(cov).map { fmt($0) }.joined(separator: "/")
        r["sheetLen"] = (slope * 10).rounded(.up) / 10; r["sheetArea"] = r.n("sheets") * fw * r.n("sheetLen") }
    let (tw, th) = rafterDims(f); let n = (L / f.n("step")).rounded(.down) + 1
    r["raftersN"] = sides * n + (cut ? 4 : 0); r["raftersLen"] = slope + 0.1; let vR = r.n("raftersN") * r.n("raftersLen") * tw * th
    r["mauerlat"] = cut ? 2 * (bw + bd) : 2 * Lb; let vM = r.n("mauerlat") * 0.15 * 0.15
    r["lath"] = cov == "soft" ? 0.0 : cut ? (area / 0.35).rounded(.up) : sides * (slope / 0.35 + 1).rounded(.up) * L; let vL = r.n("lath") * 0.025 * 0.1
    r["counter"] = r.n("raftersN") * slope; let vC = r.n("counter") * 0.05 * 0.05
    r["timber"] = (vR + vM + vL + vC) * (1 + RT("timberRes") / 100); r["membrane"] = (area * 1.15 / 75).rounded(.up)
    if f.b("ins") { r["wool"] = area * f.n("ins") / 1000 * 1.05; r["vapor"] = (area * 1.15 / 75).rounded(.up) }
    r["ridge"] = ((ridgeL + hips) / 1.9).rounded(.up); r["screws"] = cov == "soft" ? 0.0 : (area * RT("roofScrews")).rounded(.up)
    r["gutter"] = ((eq(b["roof"], "SHED") ? L : cut ? 2 * (L + s + 2 * o) : 2 * L) / 3).rounded(.up); r["pipes"] = max(2.0, (2 * L / 10).rounded(.up)); r["pipeLen"] = b.n("floors") * b.n("floorH")
    return r
}
