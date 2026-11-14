import SwiftUI

// ---------- план этажа ----------
enum PL { static var tool = "hand"; static var wp: Pt? = nil; static var op = 0.0; static var st = 0.0; static var dims = true }
func planSnap(_ b: Obj, _ lv: Any?, _ p: Pt, _ from: Pt? = nil) -> Pt {
    let P = planOf(b, lv)!; let Cc = inContour(b); var best: Pt? = nil; var bd = 0.3
    let ends = wallsOf(P).flatMap { [pt($0.n("x0"), $0.n("y0")), pt($0.n("x1"), $0.n("y1"))] }
    for q in Cc + ends { let d = G.dist(p, q); if d < bd { bd = d; best = q } }
    if let bst = best { return pt(bst[0], bst[1]) }
    var q = pt((p[0] * 20).rounded(.toNearestOrAwayFromZero) / 20, (p[1] * 20).rounded(.toNearestOrAwayFromZero) / 20); var ax = 0
    if let from = from {
        let dx = q[0] - from[0], dy = q[1] - from[1]
        if abs(dx) < abs(dy) * 0.2 { q[0] = from[0]; ax = 1 } else if abs(dy) < abs(dx) * 0.2 { q[1] = from[1]; ax = 2 }
    }
    var sb: Pt? = nil; var sd = 0.3
    for s in planSegs(b, lv) {
        let a = s.a, c = s.c; let r = segD(q, a, c); let d = r[0], u = r[1]; if d >= sd { continue }; sd = d; sb = pt(a[0] + (c[0] - a[0]) * u, a[1] + (c[1] - a[1]) * u)
        if ax == 1 && abs(c[0] - a[0]) > 1e-6 { let u2 = (q[0] - a[0]) / (c[0] - a[0]); if u2 >= 0 && u2 <= 1 { sb = pt(q[0], a[1] + (c[1] - a[1]) * u2) } }
        if ax == 2 && abs(c[1] - a[1]) > 1e-6 { let u2 = (q[1] - a[1]) / (c[1] - a[1]); if u2 >= 0 && u2 <= 1 { sb = pt(a[0] + (c[0] - a[0]) * u2, q[1]) } }
    }
    return sb ?? q
}
struct OpP { var a: Pt; var dx: Double; var dy: Double; var x: Double; var y: Double }
func opPos(_ b: Obj, _ lv: Any?, _ o: Obj) -> OpP? {
    guard let s = planSegs(b, lv).first(where: { $0.on == (o["on"] as? String ?? "") && $0.k == o.n("k") }) else { return nil }
    let Ln = G.dist(s.a, s.c) == 0 ? 1.0 : G.dist(s.a, s.c)
    let dx = (s.c[0] - s.a[0]) / Ln, dy = (s.c[1] - s.a[1]) / Ln; return OpP(a: s.a, dx: dx, dy: dy, x: s.a[0] + dx * o.n("t"), y: s.a[1] + dy * o.n("t"))
}
func nearOp(_ b: Obj, _ lv: Any?, _ p: Pt) -> Obj? {
    var best: Obj? = nil; var bd = 0.4
    for o in planOf(b, lv)?.a("ops").objs ?? [] { guard let q = opPos(b, lv, o) else { continue }; let d = hypot(q.x - p[0], q.y - p[1]); if d < bd { bd = d; best = o } }
    return best
}
struct NS { var on: String; var k: Double; var t: Double; var L: Double }
func nearSeg(_ b: Obj, _ lv: Any?, _ p: Pt) -> NS? {
    var best: NS? = nil; var bd = 0.45
    for s in planSegs(b, lv) { let r = segD(p, s.a, s.c); if r[0] < bd { bd = r[0]; let Ln = G.dist(s.a, s.c); best = NS(on: s.on, k: s.k, t: r[1] * Ln, L: Ln) } }
    return best
}
func planTap(_ b: Obj, _ lv: Any?, _ p: Pt) -> Bool {
    guard let P = planOf(b, lv) else { return false }
    switch PL.tool {
    case "wall":
        let q = planSnap(b, lv, p, PL.wp); guard let wp = PL.wp else { PL.wp = q; return false }
        if G.dist(q, wp) < 0.2 { PL.wp = nil; return false }
        P["wid"] = P.n("wid") + 1; P.a("walls").add(obj(("id", P["wid"]), ("x0", wp[0]), ("y0", wp[1]), ("x1", q[0]), ("y1", q[1])))
        let S2 = Array(planSegs(b, lv).dropLast()); PL.wp = S2.contains(where: { segD(q, $0.a, $0.c)[0] < 0.02 }) ? nil : q; return true
    case "del":
        if let o = nearOp(b, lv, p) { P.a("ops").removeAll { ($0 as? Obj) === o }; return true }
        if let s = nearSeg(b, lv, p), s.on == "i" {
            P["walls"] = Arr(wallsOf(P).filter { $0.n("id") != s.k }.map { $0 as Any? }); P["ops"] = Arr(P.a("ops").objs.filter { !(eq($0["on"], "i") && $0.n("k") == s.k) }.map { $0 as Any? }); return true
        }
        return false
    case "door", "win":
        guard let s = nearSeg(b, lv, p) else { return false }; let win = PL.tool == "win"; if win && s.on == "i" { return false }
        let w = win ? 1.2 : (s.on == "o" ? 1.0 : 0.8); let h = win ? 1.2 : 2.1; if s.L < w + 0.1 { return false }
        P["oid"] = P.n("oid") + 1
        let o = obj(("id", P["oid"]), ("on", s.on), ("k", s.k), ("t", r2(max(w / 2, min(s.L - w / 2, s.t)))), ("type", win ? "win" : "door"), ("w", w), ("h", h))
        P.a("ops").add(o); PL.op = o.n("id"); return true
    default: return false }
}
struct SF { var x: Double; var y: Double; var w: Double; var d: Double }
func stFp(_ s: Obj) -> SF { Int(s.n("dir")) % 2 == 0 ? SF(x: s.n("x"), y: s.n("y"), w: s.n("w"), d: s.n("L")) : SF(x: s.n("x"), y: s.n("y"), w: s.n("L"), d: s.n("w")) }
func stFrame(_ s: Obj) -> [Double] {
    let f = stFp(s)
    switch Int(s.n("dir")) % 4 { case 0: return [f.x, f.y, 0, 1, 1, 0]; case 1: return [f.x, f.y, 1, 0, 0, 1]; case 2: return [f.x, f.y + f.d, 0, -1, 1, 0]; default: return [f.x + f.w, f.y, -1, 0, 0, 1] }
}
func addStair(_ b: Obj, _ lv: Any?) {
    if nextLv(b, lv) == nil { return }; let S = b.a("stairs"); if S.objs.contains(where: { lvEq($0["lv"], lv) }) { return }; let inn = inner(b)
    b["sid"] = b.n("sid") + 1; let s = obj(("id", b["sid"]), ("lv", lvVal(lv)), ("w", 1.0), ("dir", 0.0), ("x", 0.0), ("y", 0.0), ("L", 3.0)); s["L"] = stInfo(b, s).auto
    let f = stFp(s); s["x"] = r2(max(0, (inn.iw - f.w) / 2)); s["y"] = r2(max(0, (inn.id - f.d) / 2))
    if let sp = stairSpot(b, s) { s["x"] = r2(sp[0]); s["y"] = r2(sp[1]); s["dir"] = sp[2] }
    S.add(s); PL.st = s.n("id"); UI.room = 0.0; PL.op = 0.0
}
func copyWins(_ b: Obj, _ lv: Any?) {
    guard let src = planOf(b, lv) else { return }; let W = src.a("ops").objs.filter { eq($0["on"], "o") && eq($0["type"], "win") }
    for f in 0..<Int(b.n("floors")) {
        if lvEq(Double(f), lv) { continue }; toManual(b, Double(f)); let P = planOf(b, Double(f))!
        P["ops"] = Arr(P.a("ops").objs.filter { !(eq($0["on"], "o") && eq($0["type"], "win")) }.map { $0 as Any? })
        for o in W { P["oid"] = P.n("oid") + 1; P.a("ops").add(assign(obj(), o, obj(("id", P["oid"])))) }
    }
    planChanged(b)
}

/// геометрия плана этажа на холсте
struct PM {
    let k: Double, ox: Double, oy: Double, id: Double
    func X(_ x: Double) -> Double { ox + x * k }
    func Y(_ y: Double) -> Double { oy + (id - y) * k }
    func Op(_ x: Double, _ y: Double) -> CGPoint { O(X(x), Y(y)) }
    func w(_ o: CGPoint) -> Pt { pt((Double(o.x) - ox) / k, id - (Double(o.y) - oy) / k) }
}
func planMap(_ b: Obj, _ W: Double, _ H: Double) -> PM {
    let i = inner(b); let pad = 24.0; let k = min((W - 2 * pad) / (i.iw + 2 * i.wt), (H - 2 * pad) / (i.id + 2 * i.wt))
    return PM(k: k, ox: (W - i.iw * k) / 2, oy: (H - i.id * k) / 2, id: i.id)
}
func drawPlan(_ d: DC, _ b: Obj, _ lv: Any?) {
    let i = inner(b); let iw = i.iw, id = i.id, wt = i.wt; let m = planMap(b, d.W, d.H); let k = m.k
    d.rcP(m.Op(-wt, id + wt), (iw + 2 * wt) * k, (id + 2 * wt) * k, Color(hex: 0x475569))
    if isShaped(b) {
        d.rcP(m.Op(0, id), iw * k, id * k, Color(hex: 0x0B0E11))
        d.poly(offsetIn(shapeLocal(b), wt).map { m.Op($0[0] + iw / 2, $0[1] + id / 2) }, Color(hex: 0x1E293B), Color(hex: 0x64748B), 3)
    } else { d.rcP(m.Op(0, id), iw * k, id * k, Color(hex: 0x1E293B)) }
    let FC = D.o("FCOL2"); let rs = rooms(b, lv)
    if isManual(b, lv) {
        let P = planOf(b, lv)!; let g = regions(b, lv)
        for r in rs where r["seed"] != nil {
            guard let R = g?.R[safe: Int(r.n("reg"))] else { continue }; let s = r.n("id") == UI.room
            let col = hexColor(FC[roomF(r)] as? String ?? "#888888").opacity(s ? 1 : 0.75)
            for q in R.rects { d.rcP(m.Op(q.x, q.y + q.d), q.w * k + 0.6, q.d * k + 0.6, col) }
            let T = D.ROOMT.o(r.s("type")); let lx = r.n("lx"), ly = r.n("ly")
            d.text(T.s("e") + " " + tr3(T["n"]), m.X(lx), m.Y(ly) - 2, s ? Color(hex: 0xB45309) : Color(hex: 0x0F172A), 12, bold: true, center: true)
            d.text(fmt(rA(r), 1) + " " + t("m2"), m.X(lx), m.Y(ly) + 12, Color(hex: 0x0F172A), 11, center: true)
        }
        for w in wallsOf(P) {
            d.line(m.Op(w.n("x0"), w.n("y0")), m.Op(w.n("x1"), w.n("y1")), Color(hex: 0xF1F5F9), max(4, IWT * m.k), round: true)
            if PL.tool != "hand" { d.text(fmt(hypot2(w.n("x1") - w.n("x0"), w.n("y1") - w.n("y0")), 2), (m.X(w.n("x0")) + m.X(w.n("x1"))) / 2 + 5, (m.Y(w.n("y0")) + m.Y(w.n("y1"))) / 2 - 5, Color(hex: 0xFDE68A), 10) }
        }
        for o in P.a("ops").objs {
            guard let q = opPos(b, lv, o) else { continue }; let h = o.n("w") / 2
            d.line(m.Op(q.x - q.dx * h, q.y - q.dy * h), m.Op(q.x + q.dx * h, q.y + q.dy * h), eq(o["type"], "win") ? Color(hex: 0x38BDF8) : C.accent, o.n("id") == PL.op ? 9 : 6)
            if eq(o["type"], "door") {
                let a0 = atan2(-q.dy, q.dx) * 180 / Double.pi; let c = m.Op(q.x - q.dx * h, q.y - q.dy * h); let r = o.n("w") * k
                d.arc(c, r, start: a0 - 90, sweep: 90, C.accent, 1.5)
            }
        }
        if let wp = PL.wp { d.circle(m.Op(wp[0], wp[1]), 6, C.accent) }
    } else {
        for r in rs {
            let T = D.ROOMT.o(r.s("type")); let s = r.n("id") == UI.room; let tl = m.Op(r.n("x"), r.n("y") + r.n("d")); let w = r.n("w") * k, h = r.n("d") * k
            d.rcP(tl, w, h, hexColor(FC[roomF(r)] as? String ?? "#888888").opacity(0.85)); d.rsP(tl, w, h, s ? C.accent : Color(hex: 0xF1F5F9), s ? 3 : 2)
            d.text(T.s("e") + " " + tr3(T["n"]), tl.x + 5, tl.y + 16, Color(hex: 0x0F172A), 12, bold: true); d.text(fmt(r.n("w") * r.n("d"), 1) + " " + t("m2"), tl.x + 5, tl.y + 30, Color(hex: 0x0F172A), 11)
        }
    }
    // лестницы
    for s in stairsOf(b) {
        let f = stFp(s); let up = lvEq(s["lv"], lv); let dn = lvEq(nextLv(b, s["lv"]), lv); if !up && !dn { continue }; let sel = s.n("id") == PL.st
        let tl = m.Op(f.x, f.y + f.d); let w = f.w * k, h = f.d * k
        if dn {
            d.rcP(tl, w, h, argb(0xD90B0E11)); d.poly([tl, O(tl.x + w, tl.y), O(tl.x + w, tl.y + h), O(tl.x, tl.y + h)], nil, sel ? C.accent : Color(hex: 0xF1F5F9), 2, dash: true)
            d.text("🪜 " + t("stOpen"), m.X(f.x + f.w / 2), m.Y(f.y + f.d / 2) + 4, Color(hex: 0xF1F5F9), 11, center: true); continue
        }
        let fr = stFrame(s); let I = stInfo(b, s)
        func Pp(_ a: Double, _ v: Double) -> CGPoint { m.Op(fr[0] + fr[2] * a + fr[4] * v, fr[1] + fr[3] * a + fr[5] * v) }
        d.rcP(tl, w, h, Color(hex: 0xCBD5E1)); for j in 1..<max(I.n, 1) { d.line(Pp(Double(j) * I.g, 0), Pp(Double(j) * I.g, s.n("w")), Color(hex: 0x475569)) }
        d.rsP(tl, w, h, sel ? C.accent : Color(hex: 0x1E293B), sel ? 3 : 2)
        d.line(Pp(0.25, s.n("w") / 2), Pp(s.n("L") - 0.25, s.n("w") / 2), Color(hex: 0xB45309), 2); d.circle(Pp(s.n("L") - 0.25, s.n("w") / 2), 4, Color(hex: 0xB45309))
    }
    // размеры
    if PL.dims {
        let C2 = inContour(b)
        for (j, a) in C2.enumerated() {
            let e = C2[(j + 1) % C2.count]; let Ln = G.dist(a, e); if Ln < 0.3 { continue }; let mx = (a[0] + e[0]) / 2, my = (a[1] + e[1]) / 2
            var nx = (e[1] - a[1]) / Ln, ny = -(e[0] - a[0]) / Ln; if G.inside(pt(mx + nx * 0.05, my + ny * 0.05), C2) { nx = -nx; ny = -ny }
            d.text(fmt(Ln, 2), m.X(mx) + nx * 14, m.Y(my) - ny * 14 + 4, Color(hex: 0xFDE68A), 11, bold: true, center: true)
        }
    }
    // ручки
    if PL.tool == "hand" {
        if isManual(b, lv) {
            for w in wallsOf(planOf(b, lv)!) { for q in [m.Op(w.n("x0"), w.n("y0")), m.Op(w.n("x1"), w.n("y1"))] { d.circle(q, 5, .white); d.circle(q, 5, C.accent, stroke: 2) } }
        } else if let r = rs.first(where: { $0.n("id") == UI.room }) {
            for q in [pt(r.n("x"), r.n("y")), pt(r.n("x") + r.n("w"), r.n("y")), pt(r.n("x") + r.n("w"), r.n("y") + r.n("d")), pt(r.n("x"), r.n("y") + r.n("d"))] {
                let o = m.Op(q[0], q[1]); d.rcP(O(o.x - 6, o.y - 6), 12, 12, .white); d.rsP(O(o.x - 6, o.y - 6), 12, 12, C.accent, 2)
            }
        }
    }
}
extension Array { subscript(safe i: Int) -> Element? { i >= 0 && i < count ? self[i] : nil } }

final class PlanTouch {
    var W = 300.0, H = 300.0
    private var mode = 0; private var moved = false; private var off = pt(0, 0); private var st: Obj? = nil; private var room: Obj? = nil; private var opp = pt(0, 0)
    private var eps: [(Obj, Int)] = []
    func down(_ o: CGPoint) {
        let b = curB(); let lv = UI.lv; let m = planMap(b, W, H); let p = m.w(o); let x = p[0], y = p[1]; moved = false; mode = 0
        if PL.tool != "hand" { if planTap(b, lv, p) { planChanged(b); upd() } else { UI.tick += 1 }; return }
        if let s = stairsOf(b).first(where: { s in let f = stFp(s); return (lvEq(s["lv"], lv) || lvEq(nextLv(b, s["lv"]), lv)) && x >= f.x && x <= f.x + f.w && y >= f.y && y <= f.y + f.d }) {
            PL.st = s.n("id"); UI.room = 0.0; PL.op = 0.0; st = s; off = pt(x - s.n("x"), y - s.n("y")); mode = 1; UI.tick += 1; return
        }
        if isManual(b, lv) {
            let P = planOf(b, lv)!; var ep: Pt? = nil
            for w in wallsOf(P) { for q in [pt(w.n("x0"), w.n("y0")), pt(w.n("x1"), w.n("y1"))] { if ep == nil && hypot(m.X(q[0]) - Double(o.x), m.Y(q[1]) - Double(o.y)) < 14 { ep = q } } }
            if let e = ep {
                eps = wallsOf(P).flatMap { w -> [(Obj, Int)] in var r: [(Obj, Int)] = []
                    if hypot(w.n("x0") - e[0], w.n("y0") - e[1]) < 0.02 { r.append((w, 0)) }; if hypot(w.n("x1") - e[0], w.n("y1") - e[1]) < 0.02 { r.append((w, 1)) }; return r }
                mode = 2; return
            }
            if let op = nearOp(b, lv, p) { PL.op = op.n("id"); UI.room = 0.0; UI.tick += 1; return }
            let r = roomAt(b, lv, rooms(b, lv), x, y); PL.op = 0.0; PL.st = 0.0; UI.room = r?.n("id") ?? 0.0; UI.tick += 1; return
        }
        if let sr = rooms(b, lv).first(where: { $0.n("id") == UI.room }) {
            let cs = [pt(sr.n("x"), sr.n("y")), pt(sr.n("x") + sr.n("w"), sr.n("y")), pt(sr.n("x") + sr.n("w"), sr.n("y") + sr.n("d")), pt(sr.n("x"), sr.n("y") + sr.n("d"))]
            if let hi = cs.firstIndex(where: { hypot(m.X($0[0]) - Double(o.x), m.Y($0[1]) - Double(o.y)) < 14 }) { room = sr; opp = cs[(hi + 2) % 4]; mode = 3; return }
        }
        if let hit = rooms(b, lv).reversed().first(where: { x >= $0.n("x") && x <= $0.n("x") + $0.n("w") && y >= $0.n("y") && y <= $0.n("y") + $0.n("d") }) { UI.room = hit.n("id"); room = hit; mode = 4; UI.tick += 1 }
    }
    func move(_ o: CGPoint, _ d: CGPoint) {
        if mode == 0 { return }; let b = curB(); let lv = UI.lv; let inn = inner(b); let m = planMap(b, W, H); let p = m.w(o); let x = p[0], y = p[1]; moved = true
        func cl(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }
        switch mode {
        case 1: guard let s = st else { return }; let f = stFp(s)
            s["x"] = cl(((x - off[0]) * 20).rounded(.toNearestOrAwayFromZero) / 20, 0, max(0, inn.iw - f.w)); s["y"] = cl(((y - off[1]) * 20).rounded(.toNearestOrAwayFromZero) / 20, 0, max(0, inn.id - f.d))
        case 2: let P = planOf(b, lv)!; let keep = P["walls"]; P["walls"] = Arr(wallsOf(P).filter { w in !eps.contains(where: { $0.0 === w }) }.map { $0 as Any? }); let q = planSnap(b, lv, p); P["walls"] = keep
            for (w, j) in eps { if j == 1 { w["x1"] = q[0]; w["y1"] = q[1] } else { w["x0"] = q[0]; w["y0"] = q[1] } }
        case 3: guard let r = room else { return }; let cx = cl((x * 20).rounded(.toNearestOrAwayFromZero) / 20, 0, inn.iw), cy = cl((y * 20).rounded(.toNearestOrAwayFromZero) / 20, 0, inn.id)
            r["x"] = min(opp[0], cx); r["y"] = min(opp[1], cy); r["w"] = max(0.5, abs(cx - opp[0])); r["d"] = max(0.5, abs(cy - opp[1]))
        case 4: guard let r = room else { return }
            r["x"] = cl(r.n("x") + Double(d.x) / m.k, 0, max(0, inn.iw - r.n("w"))); r["y"] = cl(r.n("y") - Double(d.y) / m.k, 0, max(0, inn.id - r.n("d")))
        default: break }
        Frame.bump()
    }
    func up() {
        let b = curB(); if !moved { mode = 0; return }
        switch mode { case 1, 2: planChanged(b)
        case 4: if let r = room { r["x"] = (r.n("x") * 20).rounded(.toNearestOrAwayFromZero) / 20; r["y"] = (r.n("y") * 20).rounded(.toNearestOrAwayFromZero) / 20 }
        default: break }
        mode = 0; moved = false; upd()
    }
}

/// Удобное место для лестницы: внутри контура, не пересекает стены, лучше в холле/коридоре, ближе к стене
func stairSpot(_ b: Obj, _ s: Obj) -> [Double]? {
    let inn = inner(b); let Cc = inContour(b); let nC = Cc.count; let rs = rooms(b, s["lv"]); let man = isManual(b, s["lv"]); let P = planOf(b, s["lv"]); let g = man ? regions(b, s["lv"]) : nil
    var best: [Double]? = nil; var bs = -1e9
    func typeScore(_ t: String?) -> Double { switch t { case "hall", "corridor": return 30; case "living": return 15; case "bath", "boiler", "steam", "wash": return -20; default: return 0 } }
    for dir in [0.0, 1.0] {
        let tmp = assign(obj(), s, obj(("dir", dir))); let f0 = stFp(tmp); var x = 0.0
        while x <= inn.iw - f0.w + 1e-9 {
            var y = 0.0
            while y <= inn.id - f0.d + 1e-9 {
                let cs = [pt(x, y), pt(x + f0.w, y), pt(x + f0.w, y + f0.d), pt(x, y + f0.d)]; let cx = x + f0.w / 2, cy = y + f0.d / 2
                var ok = cs.allSatisfy { G.inside($0, Cc) }
                if ok { for i in 0..<nC { for j in 0..<4 { if segX(Cc[i], Cc[(i + 1) % nC], cs[j], cs[(j + 1) % 4]) { ok = false } } } }
                if ok {
                    var sc = 0.0; var skip = false
                    if man {
                        for w in wallsOf(P!) { let a = pt(w.n("x0"), w.n("y0")), e = pt(w.n("x1"), w.n("y1"))
                            var hit = G.inside(a, cs) || G.inside(e, cs); if !hit { for j in 0..<4 { if segX(a, e, cs[j], cs[(j + 1) % 4]) { hit = true } } }; if hit { skip = true } }
                        if !skip { let ri = regAt(g!, cx, cy); let r = rs.first { Int($0.n("reg")) == ri }; sc += typeScore(r?.s("type")) }
                    } else {
                        let r = rs.first { x >= $0.n("x") - 0.01 && y >= $0.n("y") - 0.01 && x + f0.w <= $0.n("x") + $0.n("w") + 0.01 && y + f0.d <= $0.n("y") + $0.n("d") + 0.01 }
                        sc += r == nil ? -50 : typeScore(r!.s("type"))
                    }
                    if !skip {
                        sc -= 5 * cs.map { q in (0..<nC).map { i in segD(q, Cc[i], Cc[(i + 1) % nC])[0] }.min()! }.min()!
                        if sc > bs { bs = sc; best = [x, y, dir] }
                    }
                }
                y += 0.25
            }
            x += 0.25
        }
    }
    return best
}
