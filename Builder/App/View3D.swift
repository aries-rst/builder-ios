import SwiftUI

typealias V3 = [Double]
func v3(_ x: Double, _ y: Double, _ z: Double) -> V3 { [x, y, z] }
final class Face {
    let p: [V3]; let c: String; let a: Double; let flat: Bool; var dec: [Face]?; let bias: Double; var pick: Obj?
    init(_ p: [V3], _ c: String, _ a: Double = 1, flat: Bool = false, dec: [Face]? = nil, bias: Double = 0, pick: Obj? = nil) { self.p = p; self.c = c; self.a = a; self.flat = flat; self.dec = dec; self.bias = bias; self.pick = pick }
}
enum V3D {
    static var yaw = -35.0, pitch = 38.0, zoom = 1.0, px = 0.0, py = 0.0
    static func reset() { yaw = -35.0; pitch = 38.0; zoom = 1.0; px = 0; py = 0 }
    static var mode = "out"; static var fl: Any? = 0.0; static var s3: Obj? = nil; static var msg = ""
    static var PK: [([CGPoint], Obj)] = []
}
typealias WF = (Double, Double, Double) -> V3

func rgbOf(_ s: String) -> (Double, Double, Double) {
    var h = s; if h.hasPrefix("#") { h.removeFirst() }; let v = UInt32(h, radix: 16) ?? 0x888888
    return (Double((v >> 16) & 255) / 255, Double((v >> 8) & 255) / 255, Double(v & 255) / 255)
}
func fenceFaces() -> [Face] {
    let p = St.project; if p["fence"] == nil || !FN().b("on") { return [] }
    let f = FN(); let col = fenceColor(); var out: [Face] = []
    for s in fenceSegs() {
        let len = s.b - s.a; let n = max(1, Int(ceil(len / 2.5)))
        for k in 0..<n {
            let a = s.a + len * Double(k) / Double(n); let b = s.a + len * Double(k + 1) / Double(n)
            func P(_ d: Double, _ z: Double) -> V3 { v3(s.p0[0] + s.ux * d, s.p0[1] + s.uy * d, z) }
            let h = s.op != nil ? f.n("h") * 0.95 : f.n("h")
            var c2 = col; if let o = s.op { c2 = eq(o["k"], "gate") ? "#1F2937" : "#374151" }
            let al: Double = (eq(f["type"], "mesh") && s.op == nil) ? 0.35 : 1
            out.append(Face([P(a, 0), P(b, 0), P(b, h), P(a, h)], c2, al))
        }
    }
    return out
}
func opColor(_ o: Obj) -> String { (D.o("OCOL").aa(o.s("col")) ?? D.o("OCOL").a("white")).s(1) }
func opFaces(_ Wp: WF, _ px: Double, _ py: Double, _ dx: Double, _ dy: Double, _ o0: Obj, _ z0: Double, _ z1: Double) -> [Face] {
    let o = opDef(o0); let hh = o.n("w") / 2; let col = opColor(o)
    func q(_ a: Double, _ b: Double, _ c1: Double, _ c2: Double, _ cl: String) -> Face {
        Face([Wp(px - dx * a, py - dy * a, c1), Wp(px + dx * b, py + dy * b, c1), Wp(px + dx * b, py + dy * b, c2), Wp(px - dx * a, py - dy * a, c2)], cl, flat: true)
    }
    if eq(o["type"], "door") {
        var f = [q(hh, hh, z0, z1, col)]
        if eq(o["mat"], "glass") || eq(o["mat"], "pvc") { f.append(q(hh - 0.12, hh - 0.12, z0 + 1, z1 - 0.12, "#7DD3FC")) }
        return f
    }
    let fr = 0.07
    return [q(hh, hh, z0, z1, col), q(hh - fr, -fr / 2, z0 + fr, z1 - fr, "#7DD3FC"), q(-fr / 2, hh - fr, z0 + fr, z1 - fr, "#7DD3FC")]
}
func archFaces(_ b: Obj, _ W: @escaping WF) -> [Face] {
    let along = b.n("w") >= b.n("d"); let L = (along ? b.n("w") : b.n("d")) / 2; let a = (along ? b.n("d") : b.n("w")) / 2; let H = b.n("floorH"); let N = 10
    func X(_ x: Double, _ u: Double, _ z: Double) -> V3 { along ? W(x, u, z) : W(u, x, z) }
    var pr: [[Double]] = []; for i in 0...N { let q = Double.pi * Double(i) / Double(N); pr.append([-a * cos(q), H * sin(q)]) }
    var F: [Face] = []
    for i in 0..<N { F.append(Face([X(-L, pr[i][0], pr[i][1]), X(L, pr[i][0], pr[i][1]), X(L, pr[i + 1][0], pr[i + 1][1]), X(-L, pr[i + 1][0], pr[i + 1][1])], "#BBF7D0", 0.45)) }
    for x in [-L, L] { F.append(Face(pr.map { X(x, $0[0], $0[1]) }, "#BBF7D0", 0.5)) }
    return F
}
func buildingFaces(_ b: Obj) -> [Face] {
    let r = b.n("rot") * Double.pi / 180; let c = cos(r), s = sin(r)
    let W: WF = { lx, ly, z in v3(b.n("cx") + lx * c - ly * s, b.n("cy") + lx * s + ly * c, z) }
    let h = b.n("floors") * b.n("floorH"); let loc = shapeLocal(b); var F: [Face] = []; let mat = b.oo("walls")?["mat"]
    let glass = eq(b["kind"], "greenhouse"); let open = eq(mat, "open")
    let mc = MI(b.oo("walls"))?.s("col") ?? ""; let wc = glass ? "#BBF7D0" : (mc.isEmpty ? "#D6C7A8" : mc); let al: Double = glass ? 0.45 : 1
    if glass && eq(b["gh"], "arch") { return archFaces(b, W) }
    if open {
        let pw = 0.12; let ol = offsetIn(loc, pw); var pp: [Pt] = []
        for (i, q) in ol.enumerated() {
            let n = ol[(i + 1) % ol.count]; let L = G.dist(q, n); let k = max(1, Int(ceil(L / 3.5)))
            for j in 0..<k { pp.append(pt(q[0] + (n[0] - q[0]) * Double(j) / Double(k), q[1] + (n[1] - q[1]) * Double(j) / Double(k))) }
        }
        for q in pp {
            let x = q[0], y = q[1]
            F.append(Face([W(x - pw, y, 0), W(x + pw, y, 0), W(x + pw, y, h), W(x - pw, y, h)], "#92400E"))
            F.append(Face([W(x, y - pw, 0), W(x, y + pw, 0), W(x, y + pw, h), W(x, y - pw, h)], "#92400E"))
        }
        if b.oo("shape")?.b("full") != true { F.append(Face(loc.map { W($0[0], $0[1], 0.02) }, "#A16207", flat: true)) }
    } else {
        let ops: [Obj] = glass ? [] : layoutOpenings(b, b.o("walls").a("openings").objs)
        for i in loc.indices {
            let x0 = loc[i][0], y0 = loc[i][1]; let x1 = loc[(i + 1) % loc.count][0], y1 = loc[(i + 1) % loc.count][1]
            let len = hypot(x1 - x0, y1 - y0); let dx = (x1 - x0) / len, dy = (y1 - y0) / len; let nx = dy, ny = -dx
            var dec: [Face] = []
            for o in ops where Int(o.n("wall")) == i {
                let fs = opFaces(W, x0 + dx * o.n("t") + nx * 0.04, y0 + dy * o.n("t") + ny * 0.04, dx, dy, o, o.n("z0"), o.n("z0") + o.n("h"))
                for f in fs { f.pick = obj(("k", "op"), ("b", b["id"]), ("fl", o["floor"]), ("wall", o["wall"]), ("t", o["t"]), ("mid", o["mid"])); dec.append(f) }
            }
            let pk: Obj? = glass ? nil : obj(("k", "wall"), ("b", b["id"]), ("i", Double(i)))
            F.append(Face([W(x0, y0, 0), W(x1, y1, 0), W(x1, y1, h), W(x0, y0, h)], wc, al, dec: dec, pick: pk))
        }
    }
    let rf = roofColor(b); let ra: Double = glass ? 0.45 : (b.oo("shape")?.b("full") == true ? 0.6 : 1); let wl: String? = open ? nil : wc
    if eq(b["roof"], "FLAT") { F.append(Face(loc.map { W($0[0], $0[1], h) }, open ? rf : "#6B7280", ra)) }
    else if isShaped(b) && wings(b) == nil {
        let T = polyRoofTop(b); let R = h + polyRoofRise(b); let o = T.o
        for (i, q) in loc.enumerated() {
            let j = (i + 1) % loc.count
            F.append(Face([W(q[0], q[1], h), W(loc[j][0], loc[j][1], h), W(o[j][0], o[j][1], R), W(o[i][0], o[i][1], R)], rf, ra))
        }
        F.append(Face(o.map { W($0[0], $0[1], R) }, rf, ra))
    } else { for g in (wings(b) ?? []) { wingRoof(b, g, h, W, rf, ra, wl, al, &F) } }
    if !glass && !open {
        valleys3D(b, W, h, &F, rf)
        for f in F where f.c == rf && f.pick == nil { f.pick = obj(("k", "roof"), ("b", b["id"])) }
    }
    atticWins3D(b, W, h, loc, &F)
    return F
}
private func wingRoof(_ b: Obj, _ g: Wing, _ h: Double, _ W: @escaping WF, _ rf: String, _ ra: Double, _ wl: String?, _ al: Double, _ F: inout [Face]) {
    let along = g.w >= g.d; let L = along ? g.w : g.d; let s = along ? g.d : g.w; let hl = L / 2
    func X(_ a: Double, _ u: Double, _ z: Double) -> V3 { along ? W(g.cx + a, g.cy + u, z) : W(g.cx + u, g.cy + a, z) }
    if eq(b["roof"], "HIP") {
        let R = riseFor(b, s); let r0 = max(hl - s / 2, 0)
        F.append(Face([X(-hl, -s / 2, h), X(hl, -s / 2, h), X(r0, 0, h + R), X(-r0, 0, h + R)], rf, ra))
        F.append(Face([X(hl, s / 2, h), X(-hl, s / 2, h), X(-r0, 0, h + R), X(r0, 0, h + R)], rf, ra))
        F.append(Face([X(-hl, s / 2, h), X(-hl, -s / 2, h), X(-r0, 0, h + R)], rf, ra))
        F.append(Face([X(hl, -s / 2, h), X(hl, s / 2, h), X(r0, 0, h + R)], rf, ra)); return
    }
    let P = roofProf(b, s)
    for i in 0..<(P.count - 1) {
        let u0 = P[i][0], z0 = P[i][1], u1 = P[i + 1][0], z1 = P[i + 1][1]
        F.append(Face([X(-hl, u0, h + z0), X(hl, u0, h + z0), X(hl, u1, h + z1), X(-hl, u1, h + z1)], rf, ra))
    }
    if let wl = wl {
        let shed = eq(b["roof"], "SHED")
        for a in [-hl, hl] {
            var pts: [V3] = P.map { X(a, $0[0], h + $0[1]) }; if shed { pts.append(X(a, s / 2, h)) }
            F.append(Face(pts, wl, al))
        }
        if shed { let R = P[1][1]; F.append(Face([X(-hl, s / 2, h), X(hl, s / 2, h), X(hl, s / 2, h + R), X(-hl, s / 2, h + R)], wl, al)) }
    }
}
private func valleys3D(_ b: Obj, _ W: @escaping WF, _ h: Double, _ F: inout [Face], _ rf: String) {
    if !pitched(b) || eq(b["roof"], "SHED") || !isShaped(b) { return }
    guard let ws = wings(b), ws.count >= 2 else { return }
    let q = shapeLocal(b); let n = q.count; let e = 0.02
    func onB(_ v: Pt, _ g: Wing) -> Bool {
        let x0 = g.cx - g.w / 2, x1 = g.cx + g.w / 2, y0 = g.cy - g.d / 2, y1 = g.cy + g.d / 2
        let inBox = v[0] >= x0 - e && v[0] <= x1 + e && v[1] >= y0 - e && v[1] <= y1 + e
        let onEdge = abs(v[0] - x0) < e || abs(v[0] - x1) < e || abs(v[1] - y0) < e || abs(v[1] - y1) < e
        return inBox && onEdge
    }
    for (i, v) in q.enumerated() {
        let a = q[(i - 1 + n) % n]; let c = q[(i + 1) % n]
        let cr = (v[0] - a[0]) * (c[1] - v[1]) - (v[1] - a[1]) * (c[0] - v[0]); if cr >= -1e-9 { continue }
        let gs = ws.filter { onB(v, $0) }
        guard let gx = gs.first(where: { $0.w >= $0.d }), let gy = gs.first(where: { $0.w < $0.d }) else { continue }
        let R = min(riseFor(b, gx.d), riseFor(b, gy.w)); let E = pt(gy.cx, gx.cy)
        var L = hypot(E[0] - v[0], E[1] - v[1]); if L == 0 { L = 1 }
        let px = -(E[1] - v[1]) / L * 0.07, py = (E[0] - v[0]) / L * 0.07
        let strip = Face([W(v[0] - px, v[1] - py, h + 0.04), W(v[0] + px, v[1] + py, h + 0.04), W(E[0] + px, E[1] + py, h + R + 0.04), W(E[0] - px, E[1] - py, h + R + 0.04)], "#3F0D0D", bias: 6)
        let mw = W((v[0] + E[0]) / 2, (v[1] + E[1]) / 2, 0)
        let host = F.first { f in f.c == rf && f.p.count >= 3 && G.inside(pt(mw[0], mw[1]), f.p.map { pt($0[0], $0[1]) }) }
        if let host = host { host.dec = (host.dec ?? []) + [strip] } else { F.append(strip) }
    }
}
func shade(_ f: Face) -> Color {
    let (r, g, b) = rgbOf(f.c); if f.flat { return Color(red: r, green: g, blue: b, opacity: f.a) }
    let a = f.p[0], bb = f.p[1], c = f.p[2]
    let u = [bb[0] - a[0], bb[1] - a[1], bb[2] - a[2]]; let v = [c[0] - a[0], c[1] - a[1], c[2] - a[2]]
    let n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
    var l = sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]); if l == 0 { l = 1 }
    let L = [-0.4, -0.6, 0.7]; let ll = sqrt(L[0] * L[0] + L[1] * L[1] + L[2] * L[2])
    let dot = (n[0] * L[0] + n[1] * L[1] + n[2] * L[2]) / l / ll; let k = 0.6 + 0.4 * abs(dot)
    return Color(red: r * k, green: g * k, blue: b * k, opacity: f.a)
}
func samePick(_ a: Obj?, _ b: Obj?) -> Bool {
    guard let a = a, let b = b, eq(a["k"], b["k"]), num(a["b"]) == num(b["b"]) else { return false }
    func L(_ x: Any?, _ y: Any?) -> Bool { lvKey(x) == lvKey(y) }
    switch a.s("k") {
    case "wall": return num(a["i"]) == num(b["i"])
    case "op":
        if truthy(a["mid"]) { return num(a["mid"]) == num(b["mid"]) && L(a["fl"], b["fl"]) }
        return !truthy(b["mid"]) && num(a["wall"]) == num(b["wall"]) && L(a["fl"], b["fl"]) && abs(num(a["t"]) - num(b["t"])) < 0.05
    case "pw": return num(a["wid"]) == num(b["wid"]) && L(a["lv"], b["lv"])
    case "room": return num(a["rid"]) == num(b["rid"])
    default: return true
    }
}
func pk3(_ d: DC, _ f: Face, _ pr: (V3) -> CGPoint) {
    guard let pk = f.pick else { return }
    let pts = f.p.map(pr); V3D.PK.append((pts, pk))
    if samePick(pk, V3D.s3) {
        var path = Path(); for (i, q) in pts.enumerated() { if i == 0 { path.move(to: q) } else { path.addLine(to: q) } }; path.closeSubpath()
        if pk.s("k") == "op" || pk.s("k") == "pw" { d.ctx.fill(path, with: .color(argb(0x59F59E0B))) }
        d.ctx.stroke(path, with: .color(C.accent), lineWidth: 3)
    }
}
func fillFace(_ d: DC, _ f: Face, _ pr: (V3) -> CGPoint, ol: Bool = true, al: Double = 1) {
    var path = Path(); for (i, v) in f.p.enumerated() { let q = pr(v); if i == 0 { path.move(to: q) } else { path.addLine(to: q) } }; path.closeSubpath()
    var col = shade(f); if al < 1 { let (r, g, b) = rgbOf(f.c); col = Color(red: r, green: g, blue: b, opacity: f.a * al); if !f.flat { col = shade(f).opacity(al) } }
    d.ctx.fill(path, with: .color(col)); if ol { d.ctx.stroke(path, with: .color(argb(0x59000000)), lineWidth: 1) }
    pk3(d, f, pr)
}
func bgGrad(_ d: DC) {
    d.ctx.fill(Path(CGRect(x: 0, y: 0, width: d.W, height: d.H)), with: .linearGradient(Gradient(colors: [Color(hex: 0x0F172A), Color(hex: 0x1E3A5F)]), startPoint: .zero, endPoint: CGPoint(x: 0, y: d.H)))
}
struct It3 { var f: Face?; var tree: Obj?; var d: Double }
func draw3D(_ d: DC) {
    V3D.PK.removeAll(); if V3D.mode == "in" { drawInterior(d); return }
    let Wd = d.W, Ht = d.H; let bs = buildings(); let poly = plot(); bgGrad(d); if poly.count < 3 { return }
    let minX = poly.map { $0[0] }.min()!, maxX = poly.map { $0[0] }.max()!, minY = poly.map { $0[1] }.min()!, maxY = poly.map { $0[1] }.max()!
    let maxH = bs.map { $0.n("floors") * $0.n("floorH") }.max() ?? 3
    let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2; let rad = max(maxX - minX, maxY - minY, maxH * 1.5) * 0.75; let Dd = rad * 3.5
    let base = min(Wd, Ht) / (2.2 * rad) * V3D.zoom; let yw = V3D.yaw * Double.pi / 180, pt0 = V3D.pitch * Double.pi / 180
    let cyw = cos(yw), syw = sin(yw), cp = cos(pt0), sp = sin(pt0)
    func depth(_ v: V3) -> Double { let x = v[0] - cx, y = v[1] - cy; return (x * syw + y * cyw) * cp - v[2] * sp }
    func proj3(_ v: V3) -> (Double, Double, Double) {
        let x = v[0] - cx, y = v[1] - cy; let x1 = x * cyw - y * syw, y1 = x * syw + y * cyw; let up = v[2] * cp + y1 * sp; let dd = y1 * cp - v[2] * sp; let k = base * Dd / max(Dd + dd, 0.1)
        return (Wd / 2 + x1 * k + V3D.px, Ht * 0.55 - up * k + V3D.py, k)
    }
    func pr(_ v: V3) -> CGPoint { let q = proj3(v); return CGPoint(x: q.0, y: q.1) }
    func face(_ f: Face, _ ol: Bool = true) { fillFace(d, f, pr, ol: ol) }
    let pd = rad * 0.6
    face(Face([v3(minX - pd, minY - pd, 0), v3(maxX + pd, minY - pd, 0), v3(maxX + pd, maxY + pd, 0), v3(minX - pd, maxY + pd, 0)], "#3F4A2E", flat: true), false)
    face(Face(poly.map { v3($0[0], $0[1], 0) }, "#65A30D", flat: true))
    for z in items() where !isB(z) && !eq(z["kind"], "tree") {
        let zc = D.ZONES.o(z.s("kind")).s("col")
        face(Face(G.corners(z).map { v3($0[0], $0[1], 0.01) }, zc.isEmpty ? "#78716C" : zc, flat: true), false)
    }
    var path = Path(); for (i, q) in poly.enumerated() { let p = pr(v3(q[0], q[1], 0)); if i == 0 { path.move(to: p) } else { path.addLine(to: p) } }; path.closeSubpath()
    d.ctx.stroke(path, with: .color(.white), lineWidth: 2)
    var its: [It3] = []
    for b in bs { for f in buildingFaces(b) { let s: Double = f.p.reduce(0.0) { $0 + depth($1) }; its.append(It3(f: f, tree: nil, d: s / Double(f.p.count) - f.bias)) } }
    for f in fenceFaces() { let s: Double = f.p.reduce(0.0) { $0 + depth($1) }; its.append(It3(f: f, tree: nil, d: s / 4)) }
    for tr in items() where eq(tr["kind"], "tree") { its.append(It3(f: nil, tree: tr, d: depth(v3(tr.n("cx"), tr.n("cy"), 3.2)))) }
    its.sort { $0.d > $1.d }
    for x in its {
        if let tr = x.tree {
            let a = proj3(v3(tr.n("cx"), tr.n("cy"), 0)); let bq = proj3(v3(tr.n("cx"), tr.n("cy"), 3.2)); let k = bq.2
            d.ln(a.0, a.1, bq.0, bq.1, Color(hex: 0x78350F), max(2, 0.25 * k)); d.circle(CGPoint(x: bq.0, y: bq.1), tr.n("w") / 2 * k, Color(hex: 0x16A34A))
            d.circle(CGPoint(x: bq.0 - tr.n("w") * 0.12 * k, y: bq.1 - tr.n("w") * 0.12 * k), tr.n("w") / 4 * k, argb(0x1FFFFFFF))
        } else if let f = x.f { face(f); for q in (f.dec ?? []) { face(q) } }
    }
}
private func atticWins3D(_ b: Obj, _ W: @escaping WF, _ h: Double, _ loc: [Pt], _ F: inout [Face]) {
    if !levels(b).contains(where: { eq($0, "a") }) { return }; guard let P = planOf(b, "a") else { return }
    let C = inContour(b); let ws = wings(b) ?? [Wing(cx: 0, cy: 0, w: b.n("w"), d: b.n("d"))]
    for o in P.a("ops").objs where eq(o["on"], "o") && eq(o["type"], "win") {
        let k = Int(o.n("k")) % loc.count; let A = loc[k], B = loc[(k + 1) % loc.count]
        var len = G.dist(A, B); if len == 0 { len = 1 }; var il = G.dist(C[k], C[(k + 1) % C.count]); if il == 0 { il = 1 }
        let dx = (B[0] - A[0]) / len, dy = (B[1] - A[1]) / len; let nx = dy, ny = -dx
        let tt = o.n("t") / il * len; let px = A[0] + dx * tt, py = A[1] + dy * tt
        let g = ws.first { abs(px - nx * 0.3 - $0.cx) <= $0.w / 2 + 0.01 && abs(py - ny * 0.3 - $0.cy) <= $0.d / 2 + 0.01 } ?? ws[0]
        let along = g.w >= g.d; let par = along ? abs(dy) < 0.01 : abs(dx) < 0.01
        let pk = obj(("k", "op"), ("b", b["id"]), ("fl", "a"), ("mid", o["id"]))
        if !par {
            let z0 = h + 0.4; let z1 = min(h + 0.4 + o.n("h"), h + roofRise(b) - 0.3); if z1 - z0 < 0.3 { continue }
            let oo = assign(obj(("type", "win"), ("mat", "pvc"), ("col", "white")), obj(("w", o["w"]), ("h", o["h"]))); if truthy(o["mat"]) { oo["mat"] = o["mat"] }; if truthy(o["col"]) { oo["col"] = o["col"] }
            for f in opFaces(W, px + nx * 0.04, py + ny * 0.04, dx, dy, oo, z0, z1) { F.append(Face(f.p, f.c, f.a, flat: f.flat, bias: 0.3, pick: pk)) }
            continue
        }
        let s = along ? g.d : g.w; let Pr = roofProf(b, s)
        func zAt(_ dd: Double) -> Double {
            let u = -s / 2 + dd
            for i in 0..<(Pr.count - 1) { let u0 = Pr[i][0], z0 = Pr[i][1], u1 = Pr[i + 1][0], z1 = Pr[i + 1][1]; if u >= u0 - 1e-9 && u <= u1 + 1e-9 { return z0 + (z1 - z0) * (u - u0) / (u1 - u0 == 0 ? 1 : u1 - u0) } }
            return Pr.last()![1]
        }
        let d0 = 0.6; let d1 = min(d0 + o.n("h") * 0.85, s / 2 - 0.2); let hw = o.n("w") / 2
        func Q(_ e: Double, _ dd: Double) -> V3 { W(px + dx * e - nx * dd, py + dy * e - ny * dd, h + zAt(dd) + 0.06) }
        let fr = Face([Q(-hw - 0.06, d0 - 0.06), Q(hw + 0.06, d0 - 0.06), Q(hw + 0.06, d1 + 0.06), Q(-hw - 0.06, d1 + 0.06)], "#E2E8F0", bias: 5.9, pick: pk)
        let gl = Face([Q(-hw, d0), Q(hw, d0), Q(hw, d1), Q(-hw, d1)], "#38BDF8", bias: 6, pick: pk); let rc = roofColor(b)
        let cx = gl.p.reduce(0.0) { $0 + $1[0] } / 4; let cy = gl.p.reduce(0.0) { $0 + $1[1] } / 4
        let host = F.first { f in
            guard f.c == rc && f.p.count >= 3 else { return false }
            let mz: Double = f.p.reduce(0.0) { $0 + $1[2] } / Double(f.p.count)
            return G.inside(pt(cx, cy), f.p.map { pt($0[0], $0[1]) }) && abs(mz - gl.p[0][2]) < 3
        }
        if let host = host { host.dec = (host.dec ?? []) + [fr, gl] } else { F.append(fr); F.append(gl) }
    }
}
func interiorWallColor(_ b: Obj) -> String {
    let n = FIN(b)
    if eq(n["wb"], "vag") { return "#D4A373" }
    if eq(n["wb"], "none") { let c = MI(b.oo("walls"))?.s("col") ?? ""; return c.isEmpty ? "#D6C7A8" : c }
    if eq(n["wf"], "paint") || eq(n["wf"], "lime") { return "#F5F5F4" }
    if eq(n["wf"], "wallpaper") { return "#E9D8A6" }
    if eq(n["wb"], "gkl") { return "#E7E5E4" }
    return "#D6D3D1"
}
func drawInterior(_ d: DC) {
    let Wd = d.W, Ht = d.H; let b = curB(); ensureRooms(b); let LV = levels(b); var lv: Any? = V3D.fl
    if !LV.contains(where: { lvEq($0, lv) }) { lv = LV.contains(where: { lvEq($0, 0.0) }) ? 0.0 : LV[0] }; V3D.fl = lv
    let isB_ = eq(lv, "b"), isA = eq(lv, "a")
    let fh = b.n("floorH"); let bh = b.o("basement").n("h"); let z0: Double = isB_ ? -bh : (isA ? b.n("floors") * fh : num(lv) * fh); let H: Double = isB_ ? bh : (isA ? roofRise(b) : fh)
    let inn = inner(b); let iw = inn.iw, id = inn.id, wt = inn.wt; let rms = rooms(b, lv); let focus = rms.first { $0.n("id") == UI.room }
    bgGrad(d)
    let rr = b.n("rot") * Double.pi / 180; let c = cos(rr), s = sin(rr)
    let Wp: WF = { lx, ly, z in v3(b.n("cx") + lx * c - ly * s, b.n("cy") + lx * s + ly * c, z) }
    func IN(_ x: Double, _ y: Double, _ z: Double) -> V3 { Wp(x - iw / 2, y - id / 2, z) }
    let fc: V3 = focus != nil ? IN(focus!.n("x") + focus!.n("w") / 2, focus!.n("y") + focus!.n("d") / 2, z0) : Wp(0, 0, z0)
    let rad = (focus != nil ? max(focus!.n("w"), focus!.n("d"), 2.5) : max(b.n("w"), b.n("d"), H * 2)) * 0.8; let Dd = rad * 3.5; let base = min(Wd, Ht) / (2.2 * rad) * V3D.zoom
    let yw = V3D.yaw * Double.pi / 180, ptc = V3D.pitch * Double.pi / 180; let cyw = cos(yw), syw = sin(yw), cp = cos(ptc), sp = sin(ptc)
    func depth(_ v: V3) -> Double { let x = v[0] - fc[0], y = v[1] - fc[1]; return (x * syw + y * cyw) * cp - (v[2] - z0) * sp }
    func pr(_ v: V3) -> CGPoint {
        let x = v[0] - fc[0], y = v[1] - fc[1], z = v[2] - z0; let x1 = x * cyw - y * syw, y1 = x * syw + y * cyw; let up = z * cp + y1 * sp; let dd = y1 * cp - z * sp; let k = base * Dd / max(Dd + dd, 0.1)
        return CGPoint(x: Wd / 2 + x1 * k + V3D.px, y: Ht * 0.6 - up * k + V3D.py)
    }
    func face(_ f: Face, _ ol: Bool = true, _ al: Double = 1) { fillFace(d, f, pr, ol: ol, al: al) }
    func camFacing(_ nx: Double, _ ny: Double) -> Bool { let wx = nx * c - ny * s, wy = nx * s + ny * c; return wx * syw + wy * cyw < 0 }
    let hw = b.n("w") / 2, hd = b.n("d") / 2; var items: [It3] = []; let concrete = isB_; let WC = D.o("WALLCOL")
    func push(_ f: Face, _ dp: Double? = nil) { let v: Double = dp ?? (f.p.reduce(0.0) { $0 + depth($1) } / Double(f.p.count)); items.append(It3(f: f, tree: nil, d: v)) }
    let gc: String = lvEq(lv, 0) ? "#65A30D" : (isB_ ? "#5B4636" : "#334155")
    face(Face([Wp(-hw - 2, -hd - 2, z0 - 0.03), Wp(hw + 2, -hd - 2, z0 - 0.03), Wp(hw + 2, hd + 2, z0 - 0.03), Wp(-hw - 2, hd + 2, z0 - 0.03)], gc, flat: true), false)
    let lo = shapeLocal(b); let li2 = offsetIn(lo, wt)
    face(Face(lo.map { Wp($0[0], $0[1], z0 - 0.01) }, "#64748B", flat: true)); face(Face(li2.map { Wp($0[0], $0[1], z0) }, "#78716C", flat: true))
    let FC = D.o("FCOL2")
    for r in rms {
        for q in roomRects(b, r) {
            let fcol = FC[roomF(r)] as? String ?? "#888888"
            let pk = obj(("k", "room"), ("b", b["id"]), ("rid", r["id"]))
            let ff = Face([IN(q.x, q.y, z0 + 0.01), IN(q.x + q.w, q.y, z0 + 0.01), IN(q.x + q.w, q.y + q.d, z0 + 0.01), IN(q.x, q.y + q.d, z0 + 0.01)], fcol, flat: true, pick: pk)
            face(ff, r["seed"] == nil, (focus != nil && r !== focus) ? 0.45 : 1)
        }
    }
    let mcol = MI(b.oo("walls"))?.s("col") ?? ""; let outC = isB_ ? "#6B7280" : (mcol.isEmpty ? "#D6C7A8" : mcol); let inDef = concrete ? WC.s("concrete") : interiorWallColor(b)
    let ops: [Obj] = (isB_ || isA) ? [] : layoutOpenings(b, b.o("walls").a("openings").objs).filter { $0.n("floor") == num(lv) }; let wallH: Double = isA ? 0.6 : H
    for i in lo.indices {
        let j = (i + 1) % lo.count; let x0 = lo[i][0], y0 = lo[i][1], x1 = lo[j][0], y1 = lo[j][1]; let u0 = li2[i][0], v0 = li2[i][1], u1 = li2[j][0], v1 = li2[j][1]
        let len = hypot(x1 - x0, y1 - y0); let dx = (x1 - x0) / len, dy = (y1 - y0) / len; let nx = dy, ny = -dx; let near = camFacing(nx, ny); let h: Double = near ? 0.35 : wallH
        let rm = roomAt(b, lv, rms, (u0 + u1) / 2 + iw / 2 - nx * 0.2, (v0 + v1) / 2 + id / 2 - ny * 0.2); let inC = rm != nil ? WC.s(roomW(rm!)) : inDef
        let outer = Face([Wp(x0, y0, z0), Wp(x1, y1, z0), Wp(x1, y1, z0 + h), Wp(x0, y0, z0 + h)], outC)
        var dec: [Face] = []
        if !near {
            for o in ops where Int(o.n("wall")) == i {
                let ilen = hypot(u1 - u0, v1 - v0); let tt = o.n("t") / len * ilen
                let fs = opFaces(Wp, u0 + dx * tt - nx * 0.02, v0 + dy * tt - ny * 0.02, dx, dy, o, o.n("z0"), min(o.n("z0") + o.n("h"), z0 + H))
                for f in fs { f.pick = obj(("k", "op"), ("b", b["id"]), ("fl", o["floor"]), ("wall", o["wall"]), ("t", o["t"]), ("mid", o["mid"])); dec.append(f) }
            }
        }
        let ipk: Obj? = isB_ ? nil : obj(("k", "wall"), ("b", b["id"]), ("i", Double(i)), ("lv", lvVal(lv)))
        let inner2 = Face([Wp(u0, v0, z0), Wp(u1, v1, z0), Wp(u1, v1, z0 + h), Wp(u0, v0, z0 + h)], inC, dec: dec, pick: ipk)
        push(outer, (depth(outer.p[0]) + depth(outer.p[1])) / 2 + 0.01); push(inner2, (depth(inner2.p[0]) + depth(inner2.p[1])) / 2)
        let cp2 = [Wp(x0, y0, z0 + h), Wp(x1, y1, z0 + h), Wp(u1, v1, z0 + h), Wp(u0, v0, z0 + h)]; push(Face(cp2, "#94A3B8", flat: true), cp2.reduce(0.0) { $0 + depth($1) } / 4 - 0.02)
    }
    if isA { atticInterior(b, z0, wt, Wp, push, camFacing) }
    let T = 0.1
    if !isManual(b, lv) {
        for r in rms {
            let x = r.n("x"), y = r.n("y"), w = r.n("w"), dd = r.n("d")
            let edges: [[Double]] = [[x, y, x + w, y, 0, -1], [x + w, y, x + w, y + dd, 1, 0], [x + w, y + dd, x, y + dd, 0, 1], [x, y + dd, x, y, -1, 0]]
            for e in edges {
                let a = e[0], bq = e[1], ex = e[2], f2 = e[3], nx = e[4], ny = e[5]
                let onOut = (nx == 0 && (abs(bq) < 0.06 || abs(bq - id) < 0.06)) || (ny == 0 && (abs(a) < 0.06 || abs(a - iw) < 0.06)); if onOut { continue }
                let ph: Double = isA ? min(2.2, H) : H; let cut = camFacing(nx, ny) || (focus != nil && r !== focus); let hh: Double = cut ? 0.35 : ph; let col = WC.s(roomW(r))
                let ox2 = -nx * T / 2, oy2 = -ny * T / 2
                let q = [IN(a + ox2, bq + oy2, z0), IN(ex + ox2, f2 + oy2, z0), IN(ex + ox2, f2 + oy2, z0 + hh), IN(a + ox2, bq + oy2, z0 + hh)]
                var dec: [Face] = []; let L2 = hypot(ex - a, f2 - bq)
                if !cut && L2 > 1.4 && !isB_ {
                    dec.append(contentsOf: opFaces({ xx, yy, zz in IN(xx, yy, zz) }, (a + ex) / 2 + ox2 * 1.2, (bq + f2) / 2 + oy2 * 1.2, (ex - a) / L2, (f2 - bq) / L2, obj(("type", "door"), ("w", 0.8), ("h", 2.0), ("mat", "mdf"), ("col", "oak")), z0, z0 + 2))
                }
                push(Face(q, col, dec: dec))
                let cp2 = [IN(a, bq, z0 + hh), IN(ex, f2, z0 + hh), IN(ex + 2 * ox2, f2 + 2 * oy2, z0 + hh), IN(a + 2 * ox2, bq + 2 * oy2, z0 + hh)]
                push(Face(cp2, "#94A3B8", flat: true), cp2.reduce(0.0) { $0 + depth($1) } / 4 - 0.02)
            }
        }
    } else if let P = planOf(b, lv) {
        let ctr = depth(fc); let ph: Double = isA ? min(2.2, H) : H; let h2 = IWT / 2
        for w in wallsOf(P) {
            let L2 = hypot(w.n("x1") - w.n("x0"), w.n("y1") - w.n("y0")); if L2 < 0.05 { continue }
            let dx = (w.n("x1") - w.n("x0")) / L2, dy = (w.n("y1") - w.n("y0")) / L2; let nx = dy, ny = -dx
            let cut = depth(IN((w.n("x0") + w.n("x1")) / 2, (w.n("y0") + w.n("y1")) / 2, z0)) < ctr - 0.4
            let hh: Double = cut ? 0.35 : ph; let sd: Double = camFacing(nx, ny) ? 1 : -1; let o0 = nx * h2 * sd, o1 = ny * h2 * sd
            let q = [IN(w.n("x0") + o0, w.n("y0") + o1, z0), IN(w.n("x1") + o0, w.n("y1") + o1, z0), IN(w.n("x1") + o0, w.n("y1") + o1, z0 + hh), IN(w.n("x0") + o0, w.n("y0") + o1, z0 + hh)]
            let rm = roomAt(b, lv, rms, (w.n("x0") + w.n("x1")) / 2 + o0 * 3, (w.n("y0") + w.n("y1")) / 2 + o1 * 3); let col = rm != nil ? WC.s(roomW(rm!)) : inDef; var dec: [Face] = []
            if !cut {
                for op in P.a("ops").objs where eq(op["on"], "i") && op.n("k") == w.n("id") {
                    let oo = obj(("type", "door"), ("mat", op["mat"] ?? "mdf"), ("col", op["col"] ?? "oak"), ("w", op["w"]), ("h", op["h"]))
                    let fs = opFaces({ xx, yy, zz in IN(xx, yy, zz) }, w.n("x0") + dx * op.n("t") + o0 * 1.3, w.n("y0") + dy * op.n("t") + o1 * 1.3, dx, dy, oo, z0, z0 + min(op.n("h"), hh))
                    for f in fs { f.pick = obj(("k", "op"), ("b", b["id"]), ("fl", lvVal(lv)), ("mid", op["id"])); dec.append(f) }
                }
            }
            push(Face(q, col, dec: dec, pick: obj(("k", "pw"), ("b", b["id"]), ("lv", lvVal(lv)), ("wid", w["id"]))))
            let cp2 = [IN(w.n("x0") + nx * h2, w.n("y0") + ny * h2, z0 + hh), IN(w.n("x1") + nx * h2, w.n("y1") + ny * h2, z0 + hh), IN(w.n("x1") - nx * h2, w.n("y1") - ny * h2, z0 + hh), IN(w.n("x0") - nx * h2, w.n("y0") - ny * h2, z0 + hh)]
            push(Face(cp2, "#94A3B8", flat: true), cp2.reduce(0.0) { $0 + depth($1) } / 4 - 0.02)
        }
    }
    for st in stairsOf(b) {
        let f = stFp(st)
        if lvEq(nextLv(b, st["lv"]), lv) {
            let q = [IN(f.x, f.y, z0 + 0.02), IN(f.x + f.w, f.y, z0 + 0.02), IN(f.x + f.w, f.y + f.d, z0 + 0.02), IN(f.x, f.y + f.d, z0 + 0.02)]
            push(Face(q, "#0B0E11", flat: true), q.reduce(0.0) { $0 + depth($1) } / 4 + 0.5); continue
        }
        if !lvEq(st["lv"], lv) { continue }
        let fr = stFrame(st); let I = stInfo(b, st)
        func P(_ a: Double, _ v: Double, _ z: Double) -> V3 { IN(fr[0] + fr[2] * a + fr[4] * v, fr[1] + fr[3] * a + fr[5] * v, z) }
        let sw = st.n("w")
        for i in 0..<I.n {
            let a0 = Double(i) * I.g, a1 = Double(i + 1) * I.g; let zt = z0 + Double(i + 1) * I.rise
            push(Face([P(a0, 0, zt), P(a1, 0, zt), P(a1, sw, zt), P(a0, sw, zt)], "#A16207", flat: true))
            push(Face([P(a0, 0, zt - I.rise), P(a0, sw, zt - I.rise), P(a0, sw, zt), P(a0, 0, zt)], "#854D0E"))
            push(Face([P(a0, 0, z0), P(a1, 0, z0), P(a1, 0, zt), P(a0, 0, zt)], "#78350F"))
            push(Face([P(a0, sw, z0), P(a1, sw, z0), P(a1, sw, zt), P(a0, sw, zt)], "#78350F"))
        }
    }
    items.sort { $0.d > $1.d }
    for x in items { if let f = x.f { face(f); for q in (f.dec ?? []) { face(q) } } }
    for r in rms {
        if focus != nil && r !== focus { continue }
        let T2 = D.ROOMT.o(r.s("type"))
        let q = pr(r["seed"] != nil ? IN(r.n("lx"), r.n("ly"), z0 + 0.05) : IN(r.n("x") + r.n("w") / 2, r.n("y") + r.n("d") / 2, z0 + 0.05))
        let tx = T2.s("e") + " " + tr3(T2["n"]); let w2 = d.textW(tx, 12) + 10
        d.rc(Double(q.x) - w2 / 2, Double(q.y) - 22, Double(q.x) + w2 / 2, Double(q.y) + 10, argb(0xBF0F172A))
        d.text(tx, Double(q.x), Double(q.y) - 8, Color(hex: 0xF8FAFC), 12, bold: true, center: true)
        d.text(fmt(rA(r), 1) + " " + t("m2"), Double(q.x), Double(q.y) + 6, Color(hex: 0xF8FAFC), 11, center: true)
    }
}
private func atticInterior(_ b: Obj, _ z0: Double, _ wt: Double, _ Wp: @escaping WF, _ push: (Face, Double?) -> Void, _ camFacing: (Double, Double) -> Bool) {
    let WC = D.o("WALLCOL"); let vc = WC.s("vag"); let SL = shapeLocal(b); let Pa = planOf(b, "a")
    let manW = Pa != nil && Pa!.a("ops").objs.contains(where: { eq($0["on"], "o") && eq($0["type"], "win") })
    for g in (wings(b) ?? []) {
        let along = g.w >= g.d; let s0 = along ? g.d : g.w; let L = (along ? g.w : g.d) - 2 * wt; let sw = s0 - 2 * wt; let hl = L / 2
        func X(_ a: Double, _ u: Double, _ z: Double) -> V3 { along ? Wp(g.cx + a, g.cy + u, z0 + z) : Wp(g.cx + u, g.cy + a, z0 + z) }
        func N(_ a: Double, _ u: Double) -> Pt { along ? pt(a, u) : pt(u, a) }
        var P: [[Double]] = roofProf(b, s0).map { [max(-sw / 2, min(sw / 2, $0[0])), $0[1]] }
        P[0][1] = max(P[0][1], 0.6); P[P.count - 1][1] = max(P[P.count - 1][1], 0.6)
        for j in 0..<(P.count - 1) {
            let ua = P[j][0], za = P[j][1], ub = P[j + 1][0], zb = P[j + 1][1]
            let nu: Double = eq(b["roof"], "SHED") ? -1 : ((ua + ub) / 2 < 0 ? -1 : 1); let nn = N(0, nu)
            if camFacing(nn[0], nn[1]) { continue }
            push(Face([X(-hl, ua, za), X(hl, ua, za), X(hl, ub, zb), X(-hl, ub, zb)], vc), nil)
        }
        for sg in [-1.0, 1.0] {
            let nn = N(sg, 0); let ee = N(sg * (hl + wt + 0.1), 0)
            if camFacing(nn[0], nn[1]) || G.inside(pt(g.cx + ee[0], g.cy + ee[1]), SL) { continue }
            var pts: [V3] = P.map { X(sg * hl, $0[0], $0[1]) }; pts.append(X(sg * hl, P[P.count - 1][0], 0)); pts.append(X(sg * hl, P[0][0], 0))
            let ww = N(sg * (hl - 0.02), 0); let dd = N(0, 1)
            var dec: [Face] = []
            if !manW { dec = opFaces(Wp, g.cx + ww[0], g.cy + ww[1], dd[0], dd[1], obj(("type", "win"), ("w", 0.9), ("h", 1.0), ("mat", "wood"), ("col", "white")), z0 + 1.1, z0 + min(2.1, riseFor(b, s0) - 0.2)) }
            push(Face(pts, vc, dec: dec), nil)
        }
    }
}

// ---------- выбор / правка ----------
func pick3d(_ x: Double, _ y: Double) {
    var H: [Obj] = []
    for (pts, pk) in V3D.PK.reversed() {
        if G.inside(pt(x, y), pts.map { pt(Double($0.x), Double($0.y)) }) && !H.contains(where: { samePick($0, pk) }) { H.append(pk) }
    }
    if !H.isEmpty {
        let cur = H.firstIndex(where: { samePick($0, V3D.s3) }); let pk = assign(obj(), H[cur != nil ? (cur! + 1) % H.count : 0]); var ch = false
        if eq(pk["k"], "op") && !truthy(pk["mid"]) { if let o = opFromPick(pk) { pk["mid"] = o["id"]; ch = true } }
        if eq(pk["k"], "room") { UI.room = pk.n("rid") }
        V3D.s3 = pk; V3D.msg = ""; St.project["bSel"] = pk["b"]; if ch { upd() } else { UI.tick += 1 }; return
    }
    if V3D.s3 != nil { V3D.s3 = nil; UI.tick += 1 }
}
func opFromPick(_ pk: Obj) -> Obj? {
    guard let b = items().first(where: { num($0["id"]) == num(pk["b"]) }) else { return nil }
    if truthy(pk["mid"]) { return planOf(b, pk["fl"])?.a("ops").objs.first { num($0["id"]) == num(pk["mid"]) } }
    guard pk["fl"] is Double else { return nil }
    let fl = num(pk["fl"]); toManual(b, fl); planChanged(b); guard let P = planOf(b, fl) else { return nil }
    let lo = shapeLocal(b); let C = inContour(b); let k = Int(num(pk["wall"]))
    var len = G.dist(lo[k], lo[(k + 1) % lo.count]); if len == 0 { len = 1 }; let il = G.dist(C[k], C[(k + 1) % C.count]); let tt = num(pk["t"]) / len * il
    let cands = P.a("ops").objs.filter { eq($0["on"], "o") && Int($0.n("k")) == k }
    return cands.min { abs($0.n("t") - tt) < abs($1.n("t") - tt) }
}
func addOpOnWall(_ b: Obj, _ i: Int, _ type: String, _ fl: Double) {
    toManual(b, fl); let P = planOf(b, fl)!; let C = inContour(b); let L = G.dist(C[i], C[(i + 1) % C.count]); let w: Double = type == "win" ? 1.2 : 1.0; let h: Double = type == "win" ? 1.2 : 2.1
    let busy = P.a("ops").objs.filter { eq($0["on"], "o") && Int($0.n("k")) == i }; var best: Double? = nil; var bd = 1e9; var t2 = w / 2 + 0.3
    while t2 <= L - w / 2 - 0.3 + 1e-9 {
        if !busy.contains(where: { abs($0.n("t") - t2) < ($0.n("w") + w) / 2 + 0.3 }) { let dd = abs(t2 - L / 2); if dd < bd { bd = dd; best = t2 } }
        t2 += 0.1
    }
    guard let bt = best else { V3D.msg = t("s3NoSpace"); UI.tick += 1; return }
    P["oid"] = P.n("oid") + 1; let o = obj(("id", P["oid"]), ("on", "o"), ("k", Double(i)), ("t", r2(bt)), ("type", type), ("w", w), ("h", h)); P.a("ops").add(o); planChanged(b)
    V3D.s3 = obj(("k", "op"), ("b", b["id"]), ("fl", fl), ("mid", o["id"])); V3D.msg = ""; upd()
}
func addDoorOnPw(_ b: Obj, _ lv: Any?, _ wid: Double) {
    guard let P = planOf(b, lv), let w = wallsOf(P).first(where: { $0.n("id") == wid }) else { return }
    let L = hypot(w.n("x1") - w.n("x0"), w.n("y1") - w.n("y0"))
    if L < 1.1 { V3D.msg = t("s3NoSpace"); UI.tick += 1; return }
    P["oid"] = P.n("oid") + 1; let o = obj(("id", P["oid"]), ("on", "i"), ("k", wid), ("t", r2(L / 2)), ("type", "door"), ("w", 0.8), ("h", 2.1)); P.a("ops").add(o); planChanged(b)
    V3D.s3 = obj(("k", "op"), ("b", b["id"]), ("fl", lvVal(lv)), ("mid", o["id"])); upd()
}

// ---------- экран ----------
final class Tap { var x = 0.0, y = 0.0, dist = 0.0; var multi = false; var cx: Double? = nil; var cy = 0.0 }
struct V3Canvas: View {
    @ObservedObject var fr = Frame.shared
    @ObservedObject var u = UIS.shared
    @State private var tap = Tap()
    var body: some View {
        ZStack {
            let _ = fr.n
            Canvas { c, size in draw3D(DC(c, size)) }
            Gestures(onDown: { o in tap.x = Double(o.x); tap.y = Double(o.y); tap.dist = 0; tap.multi = false; tap.cx = nil },
                     onMove: { _, dl in
                        tap.cx = nil; tap.dist += Double(abs(dl.x) + abs(dl.y))
                        if tap.dist > 8 { V3D.yaw += Double(dl.x) * 0.4; V3D.pitch = min(89, max(5, V3D.pitch + Double(dl.y) * 0.3)); Frame.bump() } },
                     onZoom: { k, c in
                        tap.multi = true; V3D.zoom = min(25, max(0.4, V3D.zoom * Double(k)))
                        if let cx0 = tap.cx { V3D.px += Double(c.x) - cx0; V3D.py += Double(c.y) - tap.cy }
                        tap.cx = Double(c.x); tap.cy = Double(c.y); Frame.bump() },
                     onUp: { if !tap.multi && tap.dist <= 8 { pick3d(tap.x, tap.y) } })
        }.frame(height: 440).clipped()
    }
}
struct View3DScreen: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let p = St.project; let bs = buildings(); let inB = bs.filter { !["poly", "open"].contains($0.o("walls")["mat"] as? String ?? "") }
        let _ = fixMode(p, inB)
        Page {
            TopBar(T("mView"), { go("home") })
            Sec(pad: 10) {
                Chips {
                    Chip("🏡 " + T("vOut"), V3D.mode != "in") { V3D.mode = "out"; V3D.s3 = nil }
                    if !inB.isEmpty { Chip("🛋️ " + T("vIn"), V3D.mode == "in") { V3D.mode = "in"; V3D.zoom = 1; V3D.pitch = max(V3D.pitch, 50); V3D.s3 = nil } }
                }
                if V3D.mode == "in" { inSel(p, inB) }
            }
            HintOut(T("view3dHint"))
            V3Canvas()
            navPad
            S3Panel()
            Sec { info(bs) }
        }
    }
    func fixMode(_ p: Obj, _ inB: [Obj]) {
        if V3D.mode == "in" && inB.isEmpty { V3D.mode = "out" }
        if V3D.mode == "in" && !inB.contains(where: { num($0["id"]) == num(p["bSel"]) }) { p["bSel"] = inB[0]["id"] }
    }
    @ViewBuilder func inSel(_ p: Obj, _ inB: [Obj]) -> some View {
        let b = curB(); let _ = ensureRooms(b); let LV = levels(b); let rs = rooms(b, V3D.fl)
        if inB.count > 1 { Chips { ForEach(Array(inB.enumerated()), id: \.offset) { _, x in Chip(itemName(x), num(x["id"]) == num(p["bSel"])) { p["bSel"] = x["id"]; UI.room = 0; V3D.s3 = nil } } } }
        Chips { ForEach(Array(LV.enumerated()), id: \.offset) { _, l in Chip(lvName(l), lvEq(V3D.fl, l)) { V3D.fl = l; UI.room = 0; V3D.s3 = nil } } }
        Chips {
            Chip(T("rmAll"), UI.room == 0) { UI.room = 0; V3D.zoom = 1 }
            ForEach(Array(rs.enumerated()), id: \.offset) { _, r in let rt = D.ROOMT.o(r.s("type")); Chip(rt.s("e") + " " + tr3(rt["n"]), UI.room == r.n("id")) { UI.room = r.n("id"); V3D.zoom = 1 } }
        }
        OBtn("✏️ " + T("rmTitle")) { UI.lv = V3D.fl; go("rooms") }
    }
    @ViewBuilder func info(_ bs: [Obj]) -> some View {
        if V3D.mode == "in" {
            let b = curB(); let n = FIN(b)
            let fl = ["laminate": "oLaminate", "tile": "oTile", "lino": "oLino", "board": "oBoard"][n.s("ff")] ?? "oNone"
            let wb = ["plaster": "oPlaster", "gkl": "oGkl", "vag": "oVag"][n.s("wb")] ?? "oNone"
            let wf = ["paint": "oPaint", "wallpaper": "oWallpaper"][n.s("wf")] ?? "oNone"
            let scr: String = n.n("scr") > 0 ? " · " + T("nScreed").components(separatedBy: ",")[0].lowercased() + " " + fmt(n.n("scr")) + " мм" : ""
            let wtxt: String = T(wb) + ((!eq(n["wb"], "vag") && !eq(n["wb"], "none")) ? " + " + T(wf).lowercased() : "")
            Stat(T("nFloor"), T(fl) + scr); Stat(T("nWalls"), wtxt); Hint(T("inHint"))
        } else {
            ForEach(Array(bs.enumerated()), id: \.offset) { _, b in Stat(itemName(b), "\(fmt(b.n("w"))) × \(fmt(b.n("d"))) \(T("m")) · \(fmt(b.n("floors"))) × \(fmt(b.n("floorH"))) \(T("m"))") }
        }
    }
    var navPad: some View {
        let st = 130.0
        let items: [(String, () -> Void)] = [("◀", { V3D.px -= st }), ("▲", { V3D.py -= st }), ("▼", { V3D.py += st }), ("▶", { V3D.px += st }),
            ("＋", { V3D.zoom = min(25, max(0.4, V3D.zoom * 1.25)) }), ("－", { V3D.zoom = min(25, max(0.4, V3D.zoom / 1.25)) }), ("⟲", { V3D.reset() })]
        return HStack(spacing: 4) { ForEach(Array(items.enumerated()), id: \.offset) { _, it in OBtn(it.0) { it.1(); Frame.bump() }.frame(maxWidth: .infinity) } }.padding(.horizontal, 12).padding(.vertical, 6)
    }
}
struct S3Panel: View {
    @ObservedObject var u = UIS.shared
    func head3(_ title: String) -> some View { HStack { Txt(title, 17, bold: true).frame(maxWidth: .infinity, alignment: .leading); IconBtn("✕") { V3D.s3 = nil; UI.tick += 1 } } }
    var body: some View {
        if let s = V3D.s3 {
            if let b = items().first(where: { num($0["id"]) == num(s["b"]) }) { panel(s, b) } else { let _ = { V3D.s3 = nil }(); EmptyView() }
        } else { HintOut("👆 " + T("s3Hint")) }
    }
    @ViewBuilder func panel(_ s: Obj, _ b: Obj) -> some View {
        switch s.s("k") {
        case "wall": wallP(s, b)
        case "roof": roofP(b)
        case "op": opP(s, b)
        case "pw": pwP(s, b)
        case "room": roomP(s, b)
        default: EmptyView()
        }
    }
    @ViewBuilder func wallP(_ s: Obj, _ b: Obj) -> some View {
        let lo = shapeLocal(b); let i = Int(num(s["i"])); let L = G.dist(lo[i], lo[(i + 1) % lo.count]); let fl: Double = s["lv"] is Double ? num(s["lv"]) : 0
        Sec {
            head3("🧱 \(T("s3Wall")) \(i + 1) · \(fmt(L, 2)) \(T("m")) · \(itemName(b))"); Hint(T("wMaterial"), top: 0)
            Chips { ForEach(Array(D.o("WMAT").entries.enumerated()), id: \.offset) { _, e in Chip(tr3((e.1 as! Obj)["n"]), eq(b.o("walls")["mat"], e.0)) { b.o("walls")["mat"] = e.0 } } }
            if b.n("floors") > 1 { Chips { ForEach(0..<Int(b.n("floors")), id: \.self) { f in Chip(lvName(Double(f)), fl == Double(f)) { s["lv"] = Double(f) } } } }
            if !V3D.msg.isEmpty { Hint(V3D.msg, C.warn) }
            HStack(spacing: 6) { OBtn("🪟 + " + T("tlWin")) { addOpOnWall(b, i, "win", fl) }; OBtn("🚪 + " + T("tlDoor")) { addOpOnWall(b, i, "door", fl) } }
        }
    }
    @ViewBuilder func roofP(_ b: Obj) -> some View {
        let f = RF(b)
        Sec {
            head3("🏠 \(T("s3Roof")) · \(itemName(b))")
            Chips { ForEach([("GABLE", "roofGable"), ("SHED", "roofShed"), ("HIP", "roofHip"), ("MANSARD", "roofMans"), ("FLAT", "roofFlat")], id: \.0) { k2, l2 in Chip(T(l2), eq(b["roof"], k2)) { b["roof"] = k2 } } }
            if pitched(b) {
                Chips { ForEach(Array(D.o("RCOL").entries.enumerated()), id: \.offset) { _, e in ColorChip(hexColor(e.1 as? String), eq(f["color"], e.0), w: 44) { f["color"] = e.0 } } }
                NumField(T("rAngle"), f.n("angle")) { f["angle"] = clampD($0, 5, 60) }
            }
            OBtn(T("s3More")) { go("roof") }
        }
    }
    @ViewBuilder func opP(_ s: Obj, _ b: Obj) -> some View {
        if let o = opFromPick(s) {
            let tpl = b.o("walls").a("openings").objs.first { opMatch($0, obj(("type", o["type"]), ("w", o["w"]), ("h", o["h"]))) } ?? obj()
            let d = opDef(assign(obj(), tpl, o)); let win = eq(o["type"], "win")
            Sec {
                head3((win ? "🪟 " + T("tlWin") : "🚪 " + T(eq(o["on"], "o") ? "opDoorOut" : "opDoorIn")) + " · " + lvName(s["fl"]))
                HStack(spacing: 4) {
                    NumField(T("sWidth"), o.n("w")) { o["w"] = max(0.4, $0); planChanged(b) }; NumField(T("opH"), o.n("h")) { o["h"] = max(0.3, $0); planChanged(b) }
                    NumField(T("opPos"), o.n("t"), zero: true) { o["t"] = max(0, $0); planChanged(b) }
                }
                Chips { ForEach(Array((win ? D.o("WINMAT") : D.o("DOORMAT")).entries.enumerated()), id: \.offset) { _, e in Chip(tr3(e.1), eq(d["mat"], e.0)) { o["mat"] = e.0; planChanged(b) } } }
                Chips { ForEach(Array(D.o("OCOL").entries.enumerated()), id: \.offset) { _, e in ColorChip(hexColor((e.1 as! Arr).s(1)), eq(d["col"], e.0), w: 34) { o["col"] = e.0; planChanged(b) } } }
                if win { Chips { ForEach([1.0, 2.0, 3.0], id: \.self) { g in Chip(fmt(g) + "-" + T("wGlz"), d.n("glz") == g) { o["glz"] = g; planChanged(b) } } } }
                OBtn("✕ " + T("sDel"), C.warn) { planOf(b, s["fl"])?.a("ops").removeAll { ($0 as? Obj) === o }; V3D.s3 = nil; planChanged(b); upd() }
            }
        }
    }
    @ViewBuilder func pwP(_ s: Obj, _ b: Obj) -> some View {
        if let P = planOf(b, s["lv"]), let w = wallsOf(P).first(where: { $0.n("id") == num(s["wid"]) }) {
            let L = hypot(w.n("x1") - w.n("x0"), w.n("y1") - w.n("y0"))
            Sec {
                head3("🧱 \(T("s3Pw")) · \(fmt(L, 2)) \(T("m")) · \(lvName(s["lv"]))"); if !V3D.msg.isEmpty { Hint(V3D.msg, C.warn) }
                HStack(spacing: 6) {
                    OBtn("🚪 + " + T("tlDoor")) { addDoorOnPw(b, s["lv"], w.n("id")) }
                    OBtn("✕ " + T("s3DelWall"), C.warn) {
                        P["walls"] = Arr(wallsOf(P).filter { $0 !== w }.map { $0 as Any? }); P["ops"] = Arr(P.a("ops").objs.filter { !(eq($0["on"], "i") && $0.n("k") == w.n("id")) }.map { $0 as Any? })
                        V3D.s3 = nil; planChanged(b); upd()
                    }
                }
            }
        }
    }
    @ViewBuilder func roomP(_ s: Obj, _ b: Obj) -> some View {
        if let r = b.a("rooms").objs.first(where: { $0.n("id") == num(s["rid"]) }) {
            let rt = D.ROOMT.o(r.s("type"))
            Sec {
                head3("\(rt.s("e")) \(tr3(rt["n"])) · \(fmt(rA(r), 1)) \(T("m2"))")
                Chips { ForEach(Array(D.ROOMT.entries.enumerated()), id: \.offset) { _, e in let v = e.1 as! Obj; Chip(v.s("e") + " " + tr3(v["n"]), eq(r["type"], e.0)) { r["type"] = e.0 } } }
                Hint(T("nFloor")); Chips { ForEach([("laminate", "oLaminate"), ("tile", "oTile"), ("board", "oBoard"), ("lino", "oLino"), ("screed", "oScreedOnly")], id: \.0) { k, l in Chip(T(l), roomF(r) == k) { r["f"] = k } } }
                Hint(T("nWalls")); Chips { ForEach([("paint", "oPaint"), ("lime", "oLime"), ("wallpaper", "oWallpaper"), ("tile", "oTile"), ("vag", "oVag"), ("concrete", "oNone")], id: \.0) { k, l in Chip(T(l), roomW(r) == k) { r["wf"] = k } } }
            }
        }
    }
}
