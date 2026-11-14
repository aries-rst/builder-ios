import Foundation

/// Math.round как в Kotlin/JS: половина вверх.
func mround(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

// ---------- крыши ----------
let MLA = 65 * Double.pi / 180
func pitched(_ b: Obj) -> Bool { ["GABLE", "SHED", "HIP", "MANSARD"].contains(b.s("roof")) }
func hasGables(_ b: Obj) -> Bool { ["GABLE", "SHED", "MANSARD"].contains(b.s("roof")) }
func hasAttic(_ b: Obj) -> Bool { ["GABLE", "MANSARD"].contains(b.s("roof")) }
func mansP(_ s: Double) -> (Double, Double) { let hl = min(2.3, s * 0.35); return (hl, min(hl / tan(MLA), s * 0.3)) }
func angleOf(_ b: Obj) -> Double { (b.oo("rf")?.nz("angle", 30) ?? 30) * Double.pi / 180 }
func riseFor(_ b: Obj, _ s: Double) -> Double {
    if !pitched(b) { return 0 }; if eq(b["kind"], "greenhouse") { return s * 0.4 }; let a = angleOf(b)
    if eq(b["roof"], "SHED") { return s * tan(a) }
    if eq(b["roof"], "MANSARD") { let (hl, p) = mansP(s); return hl + (s / 2 - p) * tan(a) }
    return s / 2 * tan(a)
}
func roofProf(_ b: Obj, _ s: Double) -> [Pt] { let R = riseFor(b, s)
    if eq(b["roof"], "SHED") { return [pt(-s / 2, 0), pt(s / 2, R)] }
    if eq(b["roof"], "MANSARD") { let (hl, p) = mansP(s); return [pt(-s / 2, 0), pt(-s / 2 + p, hl), pt(0, R), pt(s / 2 - p, hl), pt(s / 2, 0)] }
    return [pt(-s / 2, 0), pt(0, R), pt(s / 2, 0)]
}
func gEnd(_ b: Obj, _ s: Double) -> Double { let R = riseFor(b, s)
    if eq(b["roof"], "GABLE") || eq(b["roof"], "SHED") { return s * R / 2 }
    if eq(b["roof"], "MANSARD") { let (hl, p) = mansP(s); return s * hl - p * hl + (s - 2 * p) * (R - hl) / 2 }
    return 0
}
func gableArea(_ b: Obj) -> Double {
    if !hasGables(b) { return 0 }; guard let ws = wings(b) else { return 0 }
    let e = ws.map { gEnd(b, min($0.w, $0.d)) }
    var A = e.reduce(0) { $0 + 2 * $1 } - Double(ws.count - 1) * (e.min() ?? 0)
    if eq(b["roof"], "SHED") { A += ws.reduce(0) { $0 + max($1.w, $1.d) * riseFor(b, min($1.w, $1.d)) } }
    return max(0, A)
}
final class PolyTop { let d: Double; let o: [Pt]; init(_ d: Double, _ o: [Pt]) { self.d = d; self.o = o } }
func polyRoofTop(_ b: Obj) -> PolyTop {
    let loc = shapeLocal(b); let A0 = G.sarea(loc); let s = eqRect(b).min() ?? 1; var d = s / 2 * 0.95
    for _ in 0..<14 {
        let o = offsetIn(loc, d); let n = o.count
        var bad = false
        outer: for i in o.indices { for j in o.indices {
            if abs(i - j) <= 1 || (i == 0 && j == n - 1) || (j == 0 && i == n - 1) { continue }
            if segX(o[i], o[(i + 1) % n], o[j], o[(j + 1) % n]) { bad = true; break outer } } }
        if !bad && G.sarea(o) > 0.03 * A0 && o.allSatisfy({ G.inside($0, loc) }) { return PolyTop(d, o) }
        d *= 0.8
    }
    return PolyTop(0.01, offsetIn(loc, 0.01))
}
func polyRoofRise(_ b: Obj) -> Double { polyRoofTop(b).d * tan(angleOf(b)) }
func roofRise(_ b: Obj) -> Double {
    if !pitched(b) { return 0 }
    if isShaped(b) { if let ws = wings(b) { return ws.map { riseFor(b, min($0.w, $0.d)) }.max() ?? 0 }; return polyRoofRise(b) }
    return riseFor(b, min(b.n("w"), b.n("d")))
}
func valleyInfo(_ b: Obj) -> (Int, Double) {
    if !pitched(b) || eq(b["roof"], "SHED") || !isShaped(b) { return (0, 0) }
    let q = shapeLocal(b); let n = q.count; var k = 0
    for (i, p) in q.enumerated() { let a = q[(i - 1 + n) % n]; let c = q[(i + 1) % n]
        if (p[0] - a[0]) * (c[1] - p[1]) - (p[1] - a[1]) * (c[0] - p[0]) < -1e-9 { k += 1 } }
    let s = roofSpan(b); let R = riseFor(b, s); return (k, Double(k) * hypot2(2.0.squareRoot() * s / 2, R))
}

// ---------- значения по умолчанию ----------
func fdef() -> Obj { obj(("type", "strip"), ("b", 0.4), ("h", 0.8), ("inner", 0.0), ("bi", 0.3), ("hi", 0.7), ("sand", 0.15), ("gravel", 0.1), ("rd", 12.0), ("slabT", 0.25), ("mesh", 0.2),
    ("a", 0.3), ("pd", 1.5), ("step", 2.0), ("grill", true), ("grade", "M200"), ("mix", "ready"), ("fbs", "24.4.6"), ("fbsIn", "24.3.6"), ("rows", 3.0), ("pad", true)) }
func wdef() -> Obj { obj(("mat", "gas"), ("t", 0.3), ("innerLen", 0.0), ("innerT", 0.1), ("gables", true), ("belt", true), ("openings", nil), ("bf", "1NF"), ("bt", "ceramFull"), ("slab", "pk"), ("pw", 1.2)) }
func rdef() -> Obj { obj(("angle", 30.0), ("over", 0.5), ("cover", "metal"), ("color", "red"), ("rafter", "50x150"), ("step", 0.6), ("ins", 150.0)) }
@discardableResult func RF(_ b: Obj) -> Obj { keep(b, "rf", rdef()) }

func newItem(_ p: Obj, _ cat: String, _ kind: String, _ cx: Double, _ cy: Double) -> Obj {
    let k = cat == "b" ? D.KINDS.o(kind) : D.ZONES.o(kind); let id = p.n("nextId", 1); p["nextId"] = id + 1
    let it = obj(("id", id), ("cat", cat), ("kind", kind), ("cx", cx), ("cy", cy), ("w", k.n("w")), ("d", k.n("d")), ("rot", 0.0))
    if cat == "b" { assign(it, obj(("floors", 1.0), ("floorH", k.n("fh")), ("roof", k["roof"]))); ensureB(it) }
    return it
}
@discardableResult func ensureB(_ it: Obj) -> Obj {
    let k = D.KINDS.oo(it.s("kind")) ?? D.KINDS.o("house")
    it["floors"] = it.nz("floors", 1); it["floorH"] = it.nz("floorH", k.n("fh")); if !truthy(it["roof"]) { it["roof"] = k["roof"] }
    keep(it, "f", assign(fdef(), deep(k.oo("fd")) as? Obj)); keep(it, "walls", assign(wdef(), deep(k.oo("wm")) as? Obj))
    let W = it.o("walls"); if eq(W["mat"], "brick15") { W["mat"] = "brick"; W["bf"] = "1.4NF" }
    if W["openings"] == nil { if let o = k["ops"] { W["openings"] = deep(o) } else { W["openings"] = autoOpenings(it) } }
    return it
}
func blankProject() -> Obj { obj(("rectMode", true), ("plotW", 20.0), ("plotD", 30.0), ("points", toArr(rect(20, 30))), ("setback", 3.0), ("setbackAux", 1.0),
    ("items", arr()), ("nextId", 1.0), ("sel", nil), ("bSel", nil), ("fresh", true)) }
/// Приведение загруженного проекта (attach).
@discardableResult func attach(_ p: Obj) -> Obj { syncCur(p)
    if p["setbackAux"] == nil { p["setbackAux"] = 1.0 }
    let its = p.a("items").objs; if !truthy(p["nextId"]) { p["nextId"] = (its.map { $0.n("id") }.max() ?? 0) + 1 }
    for it in its where isB(it) { ensureB(it) }
    if !its.contains(where: { num($0["id"]) == num(p["sel"]) }) { p["sel"] = its.first?["id"] }
    if !its.contains(where: { num($0["id"]) == num(p["bSel"]) && isB($0) }) { p["bSel"] = its.first(where: { isB($0) })?["id"] }
    return p
}

// ---------- комнаты и уровни ----------
func roomF(_ r: Obj) -> String { r.str("f") ?? D.ROOMT.o(r.s("type")).s("f") }
func roomW(_ r: Obj) -> String { r.str("wf") ?? D.ROOMT.o(r.s("type")).s("w") }
func lvH(_ b: Obj, _ l: Any?) -> Double { eq(l, "b") ? b.o("basement").n("h") : eq(l, "a") ? 1.6 : b.n("floorH") }
struct Inner { var iw: Double; var id: Double; var wt: Double }
func inner(_ b: Obj) -> Inner { let wt = b.oo("walls")?.nz("t", 0.3) ?? 0.3; return Inner(iw: max(b.n("w") - 2 * wt, 0.5), id: max(b.n("d") - 2 * wt, 0.5), wt: wt) }
func levels(_ b: Obj) -> [Any] {
    var L = [Any](); if b.oo("basement")?.b("on") == true { L.append("b") }
    for i in 0..<Int(b.n("floors")) { L.append(Double(i)) }
    if hasAttic(b) && !(isShaped(b) && wings(b) == nil) && b.oo("attic")?.b("on") == true && eq(b["kind"], "house") { L.append("a") }
    return L
}
func lvName(_ l: Any?) -> String { eq(l, "b") ? t("lvBase") : eq(l, "a") ? t("lvAttic") : "\(Int(num(l)) + 1) \(t("vFloor"))" }
func rooms(_ b: Obj, _ lv: Any? = nil) -> [Obj] { let r = b.a("rooms").objs; return lv == nil ? r : r.filter { lvEq($0["lv"], lv) } }

func autoRooms(_ b: Obj, _ lv: Any) -> [Obj] {
    let inn = inner(b); let W = inn.iw; let Dd = inn.id
    func R(_ type: String, _ x: Double, _ y: Double, _ w: Double, _ d: Double) -> Obj { obj(("type", type), ("lv", lv), ("x", r2(x * W)), ("y", r2(y * Dd)), ("w", r2(w * W)), ("d", r2(d * Dd))) }
    if isShaped(b) { let ws = wings(b); let wt2 = inn.wt
        if let ws = ws {
            let types: [String] = eq(lv, "a") ? ["mansard"] : eq(lv, "b") ? ["boiler", "storage", "storage", "storage"] : lvEq(lv, 0.0) ? ["living", "kitchen", "bed", "bed"] : ["bed", "kids", "bed", "bed"]
            let hw = b.n("w") / 2; let hd = b.n("d") / 2; let SL = shapeLocal(b)
            return ws.enumerated().map { (i, g) in
                let x0 = g.cx - g.w / 2; let x1 = g.cx + g.w / 2; let y0 = g.cy - g.d / 2; let y1 = g.cy + g.d / 2
                func O(_ px: Double, _ py: Double) -> Bool { !G.inside(pt(px, py), SL) }
                let X0 = x0 + (O(x0 - 0.05, g.cy) ? wt2 : 0.05); let X1 = x1 - (O(x1 + 0.05, g.cy) ? wt2 : 0.05)
                let Y0 = y0 + (O(g.cx, y0 - 0.05) ? wt2 : 0.05); let Y1 = y1 - (O(g.cx, y1 + 0.05) ? wt2 : 0.05)
                return obj(("type", types[i % types.count]), ("lv", lv), ("x", r2(X0 + hw - wt2)), ("y", r2(Y0 + hd - wt2)), ("w", r2(max(0.5, X1 - X0))), ("d", r2(max(0.5, Y1 - Y0))))
            }
        }
    }
    if eq(lv, "b") { return [R("boiler", 0, 0, 0.4, 1), R("storage", 0.4, 0, 0.6, 1)] }
    if eq(lv, "a") { return [R("mansard", 0, 0, 1, 1)] }
    switch b.s("kind") {
    case "banya": return [R("rest", 0, 0, 0.5, 1), R("wash", 0.5, 0, 0.25, 1), R("steam", 0.75, 0, 0.25, 1)]
    case "kitchen": return [R("kitchen", 0, 0, 1, 1)]
    case "coop": return [R("poultry", 0, 0, 1, 1)]
    case "barn": return [R("stall", 0, 0, 0.7, 1), R("storage", 0.7, 0, 0.3, 1)]
    case "saray": return [R("storage", 0, 0, 1, 1)]
    case "workshop": return [R("workshop", 0, 0, 1, 1)]
    case "custom": return [R("room", 0, 0, 1, 1)]
    case "garage": return [R("garage", 0, 0, 1, 1)]
    case "shed": return [R("storage", 0, 0, 1, 1)]
    default: break
    }
    if lvEq(lv, 0.0) { return [R("living", 0, 0, 0.55, 0.6), R("hall", 0, 0.6, 0.55, 0.4), R("kitchen", 0.55, 0, 0.45, 0.4), R("bath", 0.55, 0.4, 0.45, 0.2), R("bed", 0.55, 0.6, 0.45, 0.4)] }
    return [R("bed", 0, 0, 0.5, 0.6), R("kids", 0.5, 0, 0.5, 0.6), R("bath", 0, 0.6, 0.4, 0.4), R("corridor", 0.4, 0.6, 0.6, 0.4)]
}
@discardableResult func ensureRooms(_ b: Obj) -> [Obj] {
    keep(b, "basement", obj(("on", false), ("h", 2.4))); keep(b, "attic", obj(("on", true))); _ = b.a("rooms")
    for l in levels(b) {
        if isManual(b, l) { syncRooms(b, l); continue }
        if isShaped(b) && wings(b) == nil {
            let na = Arr(); na.a = b.a("rooms").a.filter { !lvEq(($0 as? Obj)?["lv"], l) }; b["rooms"] = na; toManual(b, l)
            for r in rooms(b, l) where eq(r["type"], "room") { r["type"] = lvEq(l, 0.0) ? "living" : eq(l, "b") ? "storage" : "bed" }
            continue
        }
        if rooms(b, l).isEmpty { for r in autoRooms(b, l) { let rid = b.n("rid") + 1; b["rid"] = rid; r["id"] = rid; b.a("rooms").add(r) } }
    }
    return b.a("rooms").objs
}

// ---------- ручная планировка ----------
let PG = 0.1; let IWT = 0.12
func planOf(_ b: Obj, _ lv: Any?) -> Obj? { b.oo("plan")?.oo(lvKey(lv)) }
func isManual(_ b: Obj, _ lv: Any?) -> Bool { if let P = planOf(b, lv) { return !P.b("rect") }; return false }
func inContour(_ b: Obj) -> [Pt] { let i = inner(b); return offsetIn(shapeLocal(b), i.wt).map { pt($0[0] + i.iw / 2, $0[1] + i.id / 2) } }
func segD(_ p: Pt, _ a: Pt, _ c: Pt) -> [Double] {
    let dx = c[0] - a[0]; let dy = c[1] - a[1]; var L = dx * dx + dy * dy; if L == 0 { L = 1e-9 }
    var u = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / L; u = max(0, min(1, u)); return [hypot2(p[0] - a[0] - u * dx, p[1] - a[1] - u * dy), u]
}
struct RRect { var x: Double; var y: Double; var w: Double; var d: Double }
final class Region { let A: Double, P: Double, lx: Double, ly: Double, rects: [RRect]
    init(_ A: Double, _ P: Double, _ lx: Double, _ ly: Double, _ r: [RRect]) { self.A = A; self.P = P; self.lx = lx; self.ly = ly; rects = r } }
final class Regions { let key: String, nx: Int, ny: Int; var lab: [Int]; let R: [Region]
    init(_ k: String, _ nx: Int, _ ny: Int, _ lab: [Int], _ R: [Region]) { key = k; self.nx = nx; self.ny = ny; self.lab = lab; self.R = R } }
private var rgCache = [String: Regions]()
func wallsOf(_ P: Obj) -> [Obj] { P.a("walls").objs }
func regions(_ b: Obj, _ lv: Any?) -> Regions? {
    guard let P = planOf(b, lv) else { return nil }; let inn = inner(b); let C = inContour(b)
    let key = Json.str(arr(inn.iw, inn.id, toArr(C), P["walls"])); let ck = "\(b.s("id"))|\(lvKey(lv))"
    if let c = rgCache[ck], c.key == key { return c }
    let nx = Int((inn.iw / PG).rounded(.up)); let ny = Int((inn.id / PG).rounded(.up)); var lab = [Int](repeating: -1, count: nx * ny); var ok = [Bool](repeating: false, count: nx * ny); let hw = max(IWT / 2, 0.08)
    let ws = wallsOf(P).map { [$0.n("x0"), $0.n("y0"), $0.n("x1"), $0.n("y1")] }
    for j in 0..<ny { for i in 0..<nx {
        let p = pt((Double(i) + 0.5) * PG, (Double(j) + 0.5) * PG); if !G.inside(p, C) { continue }
        if ws.contains(where: { segD(p, pt($0[0], $0[1]), pt($0[2], $0[3]))[0] < hw }) { continue }
        ok[j * nx + i] = true } }
    var R = [Region]()
    for s in 0..<(nx * ny) {
        if !ok[s] || lab[s] != -1 { continue }
        let k = R.count; var st = [s]; var cells = [Int](); lab[s] = k; var per = 0; var sx = 0.0; var sy = 0.0
        while let c = st.popLast() { let i = c % nx; let j = c / nx; sx += Double(i); sy += Double(j); cells.append(c)
            for (a, e) in [(1, 0), (-1, 0), (0, 1), (0, -1)] { let I = i + a; let J = j + e
                if I < 0 || J < 0 || I >= nx || J >= ny || !ok[J * nx + I] { per += 1; continue }
                let q = J * nx + I; if lab[q] == -1 { lab[q] = k; st.append(q) } } }
        if cells.count < 6 { for c in cells { lab[c] = -2 }; continue }
        let n = cells.count; let mx = sx / Double(n); let my = sy / Double(n); var best = cells[0]; var bd = 1e9
        for c in cells { let i = c % nx; let j = c / nx; let d = pow(Double(i) - mx, 2) + pow(Double(j) - my, 2); if d < bd { bd = d; best = c } }
        var rows = [Int: [Int]](); for c in cells { rows[c / nx, default: []].append(c % nx) }
        final class RR { let a: Int, e: Int, j0: Int; var j1: Int; init(_ a: Int, _ e: Int, _ j0: Int, _ j1: Int) { self.a = a; self.e = e; self.j0 = j0; self.j1 = j1 } }
        var rects = [RR](); var prev = [RR]()
        for j in rows.keys.sorted() { let xs = rows[j]!.sorted(); var runs = [(Int, Int)](); var a = xs[0]; var e = xs[0]
            for m in 1...xs.count { if m < xs.count && xs[m] == e + 1 { e = xs[m]; continue }; runs.append((a, e)); if m < xs.count { a = xs[m]; e = xs[m] } }
            prev = runs.map { (a2, e2) in
                if let f = prev.first(where: { $0.a == a2 && $0.e == e2 && $0.j1 == j }) { f.j1 = j + 1; return f }
                let nr = RR(a2, e2, j, j + 1); rects.append(nr); return nr } }
        let bi = best % nx; let bj = best / nx
        R.append(Region(Double(n) * PG * PG, Double(per) * PG, (Double(bi) + 0.5) * PG, (Double(bj) + 0.5) * PG,
                        rects.map { RRect(x: Double($0.a) * PG, y: Double($0.j0) * PG, w: Double($0.e - $0.a + 1) * PG, d: Double($0.j1 - $0.j0) * PG) }))
    }
    let g = Regions(key, nx, ny, lab, R); rgCache[ck] = g; return g
}
func regAt(_ g: Regions, _ x: Double, _ y: Double) -> Int { let i = Int((x / PG).rounded(.down)); let j = Int((y / PG).rounded(.down)); if i < 0 || j < 0 || i >= g.nx || j >= g.ny { return -1 }; return g.lab[j * g.nx + i] }
func syncRooms(_ b: Obj, _ lv: Any?) {
    guard let g = regions(b, lv) else { return }; var used = Set<Int>()
    let na = Arr()
    for r in b.a("rooms").objs {
        if !lvEq(r["lv"], lv) { na.add(r); continue }
        if r["seed"] == nil { continue }
        let k = regAt(g, r.a("seed").n(0), r.a("seed").n(1)); if k < 0 || used.contains(k) { continue }
        used.insert(k); na.add(r)
    }
    b["rooms"] = na
    for (k, R) in g.R.enumerated() where !used.contains(k) { let rid = b.n("rid") + 1; b["rid"] = rid; b.a("rooms").add(obj(("id", rid), ("type", "room"), ("lv", lvVal(lv)), ("seed", arr(r2(R.lx), r2(R.ly))))) }
    for r in rooms(b, lv) { let k = regAt(g, r.a("seed").n(0), r.a("seed").n(1)); if k < 0 || k >= g.R.count { continue }; let R = g.R[k]; let xs = R.rects
        r["reg"] = Double(k); r["lx"] = R.lx; r["ly"] = R.ly; r["A"] = r2(R.A); r["P"] = r2(R.P); let x = xs.map { $0.x }.min()!; let y = xs.map { $0.y }.min()!
        r["x"] = x; r["y"] = y; r["w"] = r2(xs.map { $0.x + $0.w }.max()! - x); r["d"] = r2(xs.map { $0.y + $0.d }.max()! - y) }
}
/// значение уровня для записи в JSON (число для этажей)
func lvVal(_ lv: Any?) -> Any? { if let d = lv as? Double { return d }; if let i = lv as? Int { return Double(i) }; return lv }
func rA(_ q: Obj) -> Double { q["seed"] != nil && q["A"] != nil ? q.n("A") : q.n("w") * q.n("d") }
func rP(_ q: Obj) -> Double { q["seed"] != nil && q["P"] != nil ? q.n("P") : 2 * (q.n("w") + q.n("d")) }
func roomRects(_ b: Obj, _ r: Obj) -> [RRect] {
    if r["seed"] == nil { return [RRect(x: r.n("x"), y: r.n("y"), w: r.n("w"), d: r.n("d"))] }
    let g = regions(b, r["lv"]); let i = Int(r.n("reg")); if let g = g, i >= 0, i < g.R.count { return g.R[i].rects }; return []
}
func roomAt(_ b: Obj, _ lv: Any?, _ rs: [Obj], _ x: Double, _ y: Double) -> Obj? {
    if isManual(b, lv) { guard let g = regions(b, lv) else { return nil }; let k = regAt(g, x, y); return k >= 0 ? rs.first(where: { Int($0.n("reg")) == k }) : nil }
    return rs.first(where: { x >= $0.n("x") - 0.05 && x <= $0.n("x") + $0.n("w") + 0.05 && y >= $0.n("y") - 0.05 && y <= $0.n("y") + $0.n("d") + 0.05 })
}
struct PSeg { var a: Pt; var c: Pt; var on: String; var k: Double }
func planSegs(_ b: Obj, _ lv: Any?) -> [PSeg] { let C = inContour(b); let P = planOf(b, lv)!
    return C.enumerated().map { (i, a) in PSeg(a: a, c: C[(i + 1) % C.count], on: "o", k: Double(i)) } + wallsOf(P).map { PSeg(a: pt($0.n("x0"), $0.n("y0")), c: pt($0.n("x1"), $0.n("y1")), on: "i", k: $0.n("id")) }
}

// ---------- проёмы ----------
func opDef(_ o: Obj) -> Obj { eq(o["type"], "door") ? assign(obj(("mat", "metal"), ("col", "anth")), o) : assign(obj(("mat", "pvc"), ("col", "white"), ("glz", 2.0)), o) }
func opName(_ o0: Obj) -> String { let o = opDef(o0)
    let m = (eq(o["type"], "door") ? D.o("DOORMAT") : D.o("WINMAT")).aa(o.s("mat")) ?? arr("", "", ""); let c = D.o("OCOL").aa(o.s("col")) ?? D.o("OCOL").a("white")
    let glz = eq(o["type"], "door") ? "" : ", \(fmt(o.n("glz")))-\(t("wGlzShort"))"
    return "\(eq(o["type"], "door") ? t("wDoor") : t("wWindow")) \(tr3(m)), \(tr3(c.at(0)).lowercased())\(glz), \(mround(o.n("w") * 1000))×\(mround(o.n("h") * 1000))"
}
func opMatch(_ x: Obj, _ o: Obj) -> Bool { let d = opDef(x)
    return eq(x["type"], o.s("type")) && abs(x.n("w") - o.n("w")) < 0.01 && abs(x.n("h") - o.n("h")) < 0.01 &&
        (!truthy(o["mat"]) || eq(d["mat"], o.s("mat"))) && (!truthy(o["col"]) || eq(d["col"], o.s("col"))) && (!truthy(o["glz"]) || d.n("glz") == o.n("glz")) }
func edgeLens(_ b: Obj) -> [Double] { let q = shapeLocal(b); return q.enumerated().map { (i, p) in G.dist(p, q[(i + 1) % q.count]) } }
func autoOpenings(_ b: Obj) -> Arr { let lens = edgeLens(b); var n = 0; for l in lens { n += max(1, Int((l / 3).rounded(.down))) }; n = n * Int(b.n("floors", 1)) - 1
    return arr(obj(("type", "win"), ("w", 1.2), ("h", 1.2), ("q", Double(max(n, 1)))), obj(("type", "door"), ("w", 1.0), ("h", 2.1), ("q", 1.0))) }
func manOuter(_ b: Obj) -> [(Int, Obj)] { var out = [(Int, Obj)]()
    guard let pl = b.oo("plan") else { return out }
    for (lv, P0) in pl.entries { guard let f = Int(lv), let P = P0 as? Obj else { continue }; if f < 0 || f >= Int(b.n("floors")) { continue }
        for o in (P.aa("ops")?.objs ?? []) where eq(o["on"], "o") { out.append((f, o)) } }
    return out }
func syncOpenings(_ b: Obj) { let M = manOuter(b); if M.isEmpty { return }; let T = b.o("walls").a("openings"); for o in T.objs { o["q"] = 0.0 }
    for (_, o) in M { var tp = T.objs.first(where: { opMatch($0, o) })
        if tp == nil { let base = T.objs.first(where: { eq($0["type"], o.s("type")) }) ?? obj(); let n = assign(obj(), base, obj(("type", o["type"]), ("w", o["w"]), ("h", o["h"]), ("q", 0.0)))
            for k in ["mat", "col", "glz"] where truthy(o[k]) { n[k] = o[k] }; T.add(n); tp = n }
        tp!["q"] = tp!.n("q") + 1 } }
/// Раскладка проёмов: wall, floor, t, w, h, z0, door (+ mid и свойства шаблона)
func layoutOpenings(_ b: Obj, _ ops: [Obj]) -> [Obj] {
    let M = manOuter(b)
    if !M.isEmpty { let lo = shapeLocal(b); let C = inContour(b)
        return M.map { (f, o) in let k = Int(o.n("k")) % lo.count; let len = G.dist(lo[k], lo[(k + 1) % lo.count]); var il = G.dist(C[k], C[(k + 1) % C.count]); if il == 0 { il = 1 }
            let tp = b.o("walls").a("openings").objs.first(where: { opMatch($0, o) }) ?? obj()
            let r = assign(obj(), tp, obj(("wall", Double(k)), ("floor", Double(f)), ("t", o.n("t") / il * len), ("w", o["w"]), ("h", o["h"]), ("door", eq(o["type"], "door") ? 1.0 : 0.0),
                                          ("z0", Double(f) * b.n("floorH") + (eq(o["type"], "door") ? 0.0 : 0.9)), ("mid", o["id"])))
            for kk in ["mat", "col", "glz"] where truthy(o[kk]) { r[kk] = o[kk] }; return r } }
    let lens = edgeLens(b); let sum = lens.reduce(0, +); let fl = Int(b.n("floors"))
    var slots = [[[Obj]]](repeating: [[Obj]](repeating: [], count: fl), count: lens.count)
    var wins = [Obj](); var doors = [Obj]()
    for o in ops { for _ in 0..<min(Int(o.n("q")), 200) { if eq(o["type"], "door") { doors.append(o) } else { wins.append(o) } } }
    let dw = [0, 2, 1, 3, 4, 5, 6, 7, 8, 9, 10, 11].filter { $0 < lens.count }
    for (i, d) in doors.enumerated() { slots[dw[i % dw.count]][0].append(assign(obj(("door", 1.0)), d)) }
    let per = Int((Double(wins.count) / Double(fl)).rounded(.up))
    for f in 0..<fl { let chunk = Array(wins.dropFirst(f * per).prefix(per)); let k = chunk.count; if k == 0 { continue }
        let q = lens.map { $0 / sum * Double(k) }; var base = q.map { Int($0.rounded(.down)) }; var rest = k - base.reduce(0, +)
        var order: [(Double, Int)] = []
        for (i, v) in q.enumerated() { let dv: Double = v - Double(base[i]); order.append((dv, i)) }
        order.sort { (a: (Double, Int), b: (Double, Int)) -> Bool in if a.0 != b.0 { return a.0 > b.0 }; return a.1 < b.1 }
        for (_, i) in order { if rest > 0 { base[i] += 1; rest -= 1 } }
        var p = 0
        for (i, cnt) in base.enumerated() { for _ in 0..<cnt { slots[i][f].append(assign(obj(("door", 0.0)), chunk[p])); p += 1 } } }
    var out = [Obj]()
    for (i, flr) in slots.enumerated() { for (f, its) in flr.enumerated() {
        let ds = its.filter { truthy($0["door"]) }; let ws = its.filter { !truthy($0["door"]) }; var a = ws
        for (k, d) in ds.enumerated() { a.insert(d, at: min(a.count / 2 + k, a.count)) }
        for (k, it) in a.enumerated() {
            out.append(obj(("wall", Double(i)), ("floor", Double(f)), ("t", (Double(k) + 0.5) * lens[i] / Double(a.count)), ("w", it["w"]), ("h", it["h"]), ("door", it["door"]),
                           ("z0", Double(f) * b.n("floorH") + (truthy(it["door"]) ? 0.0 : 0.9)))) } } }
    return out
}
func toManual(_ b: Obj, _ lv: Any?) {
    let plan = b.o("plan"); if isManual(b, lv) { return }; if b["rooms"] == nil { ensureRooms(b) }
    if !b.b("opsImp") { b["opsImp"] = 1.0; let A = !manOuter(b).isEmpty ? [Obj]() : layoutOpenings(b, b.o("walls").a("openings").objs); let lo = shapeLocal(b); let C = inContour(b)
        for f in 0..<Int(b.n("floors")) { if !lvEq(f, lv) { toManual(b, Double(f)) }
            let P: Obj; if let e = plan.oo(String(f)) { P = e } else { P = obj(("walls", arr()), ("ops", arr()), ("rect", true)); plan[String(f)] = P }
            for o in A where Int(o.n("floor")) == f { let k = Int(o.n("wall")); var len = G.dist(lo[k], lo[(k + 1) % lo.count]); if len == 0 { len = 1 }; let il = G.dist(C[k], C[(k + 1) % C.count])
                let oid = P.n("oid") + 1; P["oid"] = oid
                P.a("ops").add(obj(("id", oid), ("on", "o"), ("k", Double(k)), ("t", r2(o.n("t") / len * il)), ("type", truthy(o["door"]) ? "door" : "win"), ("w", o["w"]), ("h", o["h"]))) } } }
    let old = plan.oo(lvKey(lv)); let C = inContour(b); let rs = rooms(b, lv).filter { $0["seed"] == nil }
    var H = [String: [[Double]]](); var Vt = [String: [[Double]]]()
    func add(_ M: inout [String: [[Double]]], _ key: Double, _ a: Double, _ e: Double) { let k = String(format: "%.2f", Double(mround(key * 20)) / 20.0); M[k, default: []].append([min(a, e), max(a, e)]) }
    for r in rs { let x = r.n("x"); let y = r.n("y"); let w = r.n("w"); let d = r.n("d"); add(&H, y, x, x + w); add(&H, y + d, x, x + w); add(&Vt, x, y, y + d); add(&Vt, x + w, y, y + d) }
    let walls = arr(); var wid = 0.0
    func out(_ m: Pt) -> Bool { C.indices.contains(where: { segD(m, C[$0], C[($0 + 1) % C.count])[0] < 0.12 }) || !G.inside(m, C) }
    for (M, vert) in [(H, false), (Vt, true)] { for k in M.keys.sorted() { var iv = M[k]!; iv.sort { $0[0] < $1[0] }; var mg = [[Double]]()
        for s in iv { if var l = mg.last, s[0] <= l[1] + 0.06 { l[1] = max(l[1], s[1]); mg[mg.count - 1] = l } else { mg.append(s) } }
        for seg in mg { let a = seg[0]; let e = seg[1]; if e - a < 0.2 { continue }
            let v = Double(k) ?? 0; let m = vert ? pt(v, (a + e) / 2) : pt((a + e) / 2, v); if out(m) { continue }
            wid += 1; walls.add(vert ? obj(("id", wid), ("x0", v), ("y0", a), ("x1", v), ("y1", e)) : obj(("id", wid), ("x0", a), ("y0", v), ("x1", e), ("y1", v))) } } }
    plan[lvKey(lv)] = obj(("walls", walls), ("ops", old?["ops"] ?? arr()), ("wid", wid), ("oid", old?.n("oid") ?? 0.0))
    for r in rs { r["seed"] = arr(r2(r.n("x") + r.n("w") / 2), r2(r.n("y") + r.n("d") / 2)) }
    syncRooms(b, lv)
}
func planChanged(_ b: Obj) { for l in levels(b) where isManual(b, l) { syncRooms(b, l) }; syncOpenings(b) }

// ---------- лестницы ----------
func nextLv(_ b: Obj, _ lv: Any?) -> Any? { let L = levels(b); if let i = L.firstIndex(where: { lvEq($0, lv) }), i < L.count - 1 { return L[i + 1] }; return nil }
struct StInfo { var H: Double; var n: Int; var rise: Double; var g: Double; var auto: Double }
func stInfo(_ b: Obj, _ s: Obj) -> StInfo { let H = lvH(b, s["lv"]) + 0.2; let n = max(3, mround(H / 0.17)); return StInfo(H: H, n: n, rise: H / Double(n), g: s.n("L") / Double(n), auto: r2(Double(n - 1) * 0.28)) }
func stairsOf(_ b: Obj) -> [Obj] { b.a("stairs").objs.filter { s in levels(b).contains(where: { lvEq($0, s["lv"]) }) && nextLv(b, s["lv"]) != nil } }
func stairsOpen(_ b: Obj) -> Double { stairsOf(b).filter { lvIsNum(nextLv(b, $0["lv"])) }.reduce(0) { $0 + $1.n("w") * $1.n("L") } }
