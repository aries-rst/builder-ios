import SwiftUI

private let ink = Color(hex: 0xF1F5F9)

/// Разрез фундамента
func drawSection(_ d: DC, _ b: Obj) {
    let f = b.o("f"); let W = d.W, H = d.H
    struct Sc { var k: String; var bb = 0.0; var h = 0.0; var m = ""; var lbl: String? = nil }
    var secs: [Sc] = []
    switch f.s("type") {
    case "strip": secs.append(Sc(k: "strip", bb: f.n("b"), h: f.n("h"), lbl: t("fOuter"))); if f.n("inner") > 0 { secs.append(Sc(k: "strip", bb: f.n("bi"), h: f.n("hi"), lbl: t("fInnerW"))) }
    case "fbs": secs.append(Sc(k: "fbs", m: f.s("fbs"), lbl: t("fOuter"))); if f.n("inner") > 0 { secs.append(Sc(k: "fbs", m: f.s("fbsIn"), lbl: t("fInnerW"))) }
    default: secs.append(Sc(k: f.s("type"))) }
    struct Gg { var bw: Double; var top: Double; var bot: Double }
    func geo(_ s: Sc) -> Gg {
        switch s.k {
        case "strip": return Gg(bw: s.bb, top: 0.1, bot: -(s.h - 0.1))
        case "fbs": let fb = fbsDim(s.m); let hh = f.n("rows") * (fb[2] / 1000 + 0.01); return Gg(bw: fb[1] / 1000, top: 0.1, bot: 0.1 - hh - (f.b("pad") ? 0.3 : 0))
        case "slab": return Gg(bw: 2.4, top: f.n("slabT") - 0.05, bot: -0.05)
        default: return Gg(bw: f.n("a"), top: f.b("grill") ? 0.45 : 0.1, bot: -f.n("pd")) }
    }
    let gs = secs.map { geo($0) }; let cellW = gs.map { $0.bw + (f.s("type") == "post" ? 1.4 : 0.9) }.max()!; let spanW = cellW * Double(secs.count)
    let top = gs.map { $0.top }.max()!; let lb = gs.map { $0.bot }.min()! - f.n("gravel") - f.n("sand")
    let k = min(W / spanW, (H - 34) / (top - lb + 0.45)); let gz = 26 + (top + 0.2) * k
    for (si, s) in secs.enumerated() {
        let g = gs[si]; let ox = W / Double(secs.count) * (Double(si) + 0.5)
        func X(_ x: Double) -> Double { ox + x * k }
        func Z(_ z: Double) -> Double { gz - z * k }
        func R(_ x0: Double, _ z0: Double, _ x1: Double, _ z1: Double, _ col: Color) { d.rc(X(x0), Z(z0), X(x1), Z(z1), col) }
        R(-cellW / 2, lb - 0.3, cellW / 2, 0, Color(hex: 0x5B4636))
        let tw = (s.k == "post" ? f.n("a") : g.bw) + 0.2; let cb = s.k == "post" ? -f.n("pd") : g.bot
        R(-tw / 2, cb - f.n("gravel") - f.n("sand"), tw / 2, cb - f.n("gravel"), Color(hex: 0xE3C77A)); R(-tw / 2, cb - f.n("gravel"), tw / 2, cb, Color(hex: 0x9CA3AF))
        let conc = Color(hex: 0xCBD5E1); var dots: [(Double, Double)] = []
        func bar(_ x: Double, _ z: Double) { dots.append((x, z)) }
        switch s.k {
        case "strip":
            R(-g.bw / 2, g.bot, g.bw / 2, g.top, conc); let lv = s.h > 0.6 ? 3 : 2
            for i in 0..<lv { let z = g.bot + 0.05 + (g.top - g.bot - 0.1) * Double(i) / Double(lv - 1); bar(-g.bw / 2 + 0.05, z); bar(g.bw / 2 - 0.05, z) }
            d.rs(X(-g.bw / 2 + 0.05), Z(g.top - 0.05), X(g.bw / 2 - 0.05), Z(g.bot + 0.05), Color(hex: 0x475569))
        case "fbs":
            let hb = fbsDim(s.m)[2] / 1000; var z = g.bot
            if f.b("pad") { R(-(g.bw + 0.2) / 2, z, (g.bw + 0.2) / 2, z + 0.3, conc); for q in [-1.0, 1.0] { bar(q * ((g.bw + 0.2) / 2 - 0.05), z + 0.05); bar(q * ((g.bw + 0.2) / 2 - 0.05), z + 0.25) }; z += 0.3 }
            for _ in 0..<Int(f.n("rows")) { R(-g.bw / 2, z + 0.01, g.bw / 2, z + 0.01 + hb, Color(hex: 0xA8B3C2)); d.rs(X(-g.bw / 2), Z(z + 0.01 + hb), X(g.bw / 2), Z(z + 0.01), Color(hex: 0x334155), 1); z += hb + 0.01 }
        case "slab":
            R(-g.bw / 2, g.bot, g.bw / 2, g.top, conc); var x = -g.bw / 2 + 0.1; while x <= g.bw / 2 - 0.1 + 1e-9 { bar(x, g.bot + 0.05); bar(x, g.top - 0.05); x += f.n("mesh") }
        default:
            let a = f.n("a"); R(-a / 2, -f.n("pd"), a / 2, 0.1, conc)
            for q in [-1.0, 1.0] { bar(q * (a / 2 - 0.05), -f.n("pd") + 0.1); bar(q * (a / 2 - 0.05), 0) }
            if f.b("grill") { let bb = f.n("b"); R(-bb / 2 - 0.3, 0.05, bb / 2 + 0.3, 0.45, conc); bar(-bb / 2 - 0.25, 0.1); bar(bb / 2 + 0.25, 0.1); bar(-bb / 2 - 0.25, 0.4); bar(bb / 2 + 0.25, 0.4) }
        }
        for (x, z) in dots { d.circle(O(X(x), Z(z)), max(2.5, f.n("rd") / 1000 * k * 1.5), Color(hex: 0xB91C1C)) }
        d.ln(X(-cellW / 2), Z(0), X(cellW / 2), Z(0), Color(hex: 0xA3E635), 2)
        let m = t("m"); let fb: [Double] = s.k == "fbs" ? fbsDim(s.m) : []
        var lbl: [String]
        switch s.k {
        case "strip": lbl = ["\(fmt(s.bb)) \(m)", "\(fmt(s.h)) \(m)"]
        case "fbs": lbl = ["ФБС \(s.m)", "\(fmt(f.n("rows")))×\(fmt(fb[2]))"]
        case "slab": lbl = ["\(t("fMesh").components(separatedBy: ",")[0]) \(fmt(f.n("mesh"))) \(m)", "\(fmt(f.n("slabT"))) \(m)"]
        default: lbl = ["\(fmt(f.n("a")))×\(fmt(f.n("a"))) \(m)", "\(fmt(f.n("pd"))) \(m)"] }
        d.text(lbl[0], X(-g.bw / 2), Z(g.top) - 6, ink); d.text(lbl[1], X(g.bw / 2) + 6, Z((g.top + g.bot) / 2), ink)
        if let l = s.lbl { d.text(l, X(-cellW / 2) + 6, 14, C.accent, 12, bold: true) }
        if si == secs.count - 1 {
            d.text(t("fSand").components(separatedBy: ",")[0], X(tw / 2) + 4, Z(cb - f.n("gravel") - f.n("sand") / 2) + 4, Color(hex: 0xE3C77A), 11)
            d.text(t("fGravel").components(separatedBy: ",")[0], X(tw / 2) + 4, Z(cb - f.n("gravel") / 2) + 4, Color(hex: 0xD1D5DB), 11)
        }
    }
}

/// Разрез крыши
func drawRoofSection(_ d: DC, _ b: Obj) {
    let f = RF(b); let s = roofSpan(b); let rise = pitched(b) ? roofRise(b) : 0.3; let ov = pitched(b) ? f.n("over") : 0.1; let wh = 1.2; let W = d.W, H = d.H
    let k = min((W - 40) / (s + 2 * ov), (H - 40) / (rise + wh + ov * tan(f.n("angle") * Double.pi / 180))); let ox = W / 2
    func X(_ x: Double) -> Double { ox + x * k }
    func Y(_ z: Double) -> Double { H - 20 - z * k }
    let wt = b.oo("walls")?.nz("t", 0.3) ?? 0.3
    let mc = MI(b.oo("walls"))?.s("col") ?? ""; let wc = hexColor(mc.isEmpty ? "#D6C7A8" : mc)
    d.rc(X(-s / 2), Y(wh), X(-s / 2 + wt), Y(0), wc); d.rc(X(s / 2 - wt), Y(wh), X(s / 2), Y(0), wc)
    d.rc(X(-s / 2), Y(wh + 0.15), X(-s / 2 + 0.15), Y(wh), Color(hex: 0xA16207)); d.rc(X(s / 2 - 0.15), Y(wh + 0.15), X(s / 2), Y(wh), Color(hex: 0xA16207))
    if eq(b["roof"], "FLAT") {
        d.rc(X(-s / 2 - 0.1), Y(wh + 0.3), X(s / 2 + 0.1), Y(wh + 0.18), Color(hex: 0x6B7280))
        if f.b("ins") { d.rc(X(-s / 2), Y(wh + 0.18), X(s / 2), Y(wh + 0.18) + 3, Color(hex: 0xFDE68A)) }
        return
    }
    let tmp = assign(obj(), b); tmp["shape"] = nil
    let z = wh + 0.15; let P = roofProf(tmp, s).map { pt($0[0], z + $0[1]) }; let ta = eq(b["roof"], "MANSARD") ? tan(MLA) : tan(f.n("angle") * Double.pi / 180)
    var pts: [Pt]
    if eq(b["roof"], "SHED") { pts = [pt(-s / 2 - ov, z - ov * ta), pt(s / 2 + ov, z + P[1][1] - z + ov * ta)] }
    else { pts = [pt(-s / 2 - ov, z - ov * ta)] + Array(P[1..<(P.count - 1)]) + [pt(s / 2 + ov, z - ov * ta)] }
    func line(_ Q: [Pt], _ col: Color, _ lw: Double, _ dz: Double = 0) { d.pl(Q.map { O(X($0[0]), Y($0[1]) - dz) }, col, lw) }
    if f.b("ins") {
        let q: [Pt] = eq(b["roof"], "SHED") ? [pt(-s / 2 + 0.2, z + 0.1), pt(s / 2 - 0.2, P[1][1] - 0.25)] : [pt(-s / 2 + 0.2, z + 0.1)] + P[1..<(P.count - 1)].map { pt($0[0], $0[1] - 0.15) } + [pt(s / 2 - 0.2, z + 0.1)]
        line(q, Color(hex: 0xFDE68A), max(3, f.n("ins") / 1000 * k))
    }
    line(pts, Color(hex: 0xA16207), max(3, 0.15 * k)); line(pts, hexColor(roofColor(b)), 4, 4)
    if !eq(b["roof"], "SHED") {
        let man = eq(b["roof"], "MANSARD"); let zc = man ? z + mansP(s).0 : z + rise * 0.35; let xc = man ? s / 2 - mansP(s).1 : s / 2 - 0.3
        line([pt(-xc, zc), pt(xc, zc)], Color(hex: 0xA16207), 2)
    }
    d.text(fmt(f.n("angle")) + "°", X(-s / 2) + 14, Y(wh + 0.3), ink); d.text(fmt(rise, 2) + " " + t("m"), X(eq(b["roof"], "SHED") ? s / 2 - 0.6 : 0) + 8, Y(z + rise / 2), ink)
    d.text(fmt(s, 2) + " " + t("m"), X(0) - 16, Y(wh / 2), ink)
}

/// Фасад
func drawFacade(_ d: DC, _ b: Obj) {
    let Wl = b.o("walls"); let m = MI(Wl) ?? D.WMAT.o("gas"); let H = b.n("floors") * b.n("floorH"); let R = roofRise(b); let Wd = d.W, Ht = d.H; let bw = b.n("w")
    let k = min((Wd - 60) / bw, (Ht - 40) / (H + R + 0.4)); let ox = (Wd - bw * k) / 2; let gy = Ht - 22
    func X(_ x: Double) -> Double { ox + (x + bw / 2) * k }
    func Y(_ z: Double) -> Double { gy - z * k }
    let rf = hexColor(roofColor(b)); let mcs = m.s("col"); let mc = hexColor(mcs.isEmpty ? "#D6C7A8" : mcs); let ol = argb(0x59000000)
    func pg(_ pts: [(Double, Double)], _ fill: Color?, _ stroke: Color? = nil) { d.poly(pts.map { O(X($0.0), Y($0.1)) }, fill, stroke, 1.5) }
    let ws = (wings(b) ?? [Wing(cx: 0, cy: 0, w: bw, d: b.n("d"))]).sorted { $0.cy > $1.cy }
    for g in ws {
        let x0 = g.cx - g.w / 2, x1 = g.cx + g.w / 2; let along = g.w >= g.d; let s = along ? g.d : g.w; let Rg = riseFor(b, s)
        if pitched(b) {
            var roofPts: [(Double, Double)]? = nil; var gab: [(Double, Double)]? = nil
            if along {
                if eq(b["roof"], "HIP") { let r0 = max(g.w / 2 - s / 2, 0); roofPts = [(x0, H), (x1, H), (g.cx + r0, H + Rg), (g.cx - r0, H + Rg)] }
                else { roofPts = [(x0, H), (x1, H), (x1, H + Rg), (x0, H + Rg)] }
            } else {
                let P = roofProf(b, s).map { (g.cx + $0[0], H + $0[1]) }
                if eq(b["roof"], "HIP") { roofPts = P } else { gab = P; if eq(b["roof"], "SHED") { gab!.append((x1, H)) } }
            }
            if let gg = gab {
                pg(gg, mc, argb(0x4D000000))
                let take = eq(b["roof"], "SHED") ? 2 : gg.count
                d.pl(gg.prefix(take).map { O(X($0.0), Y($0.1)) }, rf, 5)
            }
            if let rp = roofPts {
                pg(rp, rf, ol)
                if eq(b["roof"], "MANSARD") && along { let hl = mansP(s).0; d.ln(X(x0), Y(H + hl), X(x1), Y(H + hl), argb(0x73000000), 2) }
            }
        } else { pg([(x0 - 0.1, H), (x1 + 0.1, H), (x1 + 0.1, H + 0.25), (x0 - 0.1, H + 0.25)], Color(hex: 0x6B7280)) }
        pg([(x0, 0), (x1, 0), (x1, H), (x0, H)], mc, ol)
    }
    let rowH = (m.n("H") + m.n("j")) * k; let blk = (m.n("L") + m.n("j")) * k; let jc = argb(0x2E000000)
    if rowH >= 3 && ws.count == 1 {
        var z = 0.0; var i = 0
        while z < H - 1e-9 {
            d.ln(X(-bw / 2), Y(z), X(bw / 2), Y(z), jc, 1)
            if blk >= 6 {
                var x = -bw / 2 + Double(i % 2) * (m.n("L") + m.n("j")) / 2
                while x < bw / 2 { d.ln(X(x), Y(z), X(x), Y(min(z + m.n("H") + m.n("j"), H)), jc, 1); x += m.n("L") + m.n("j") }
            }
            z += m.n("H") + m.n("j"); i += 1
        }
    }
    if Wl.b("belt") { for fl in 1...max(1, Int(b.n("floors"))) where Int(b.n("floors")) >= 1 { d.rc(X(-bw / 2), Y(Double(fl) * b.n("floorH")), X(bw / 2), Y(Double(fl) * b.n("floorH") - 0.25), Color(hex: 0x94A3B8)) } }
    let lo = shapeLocal(b)
    var front = Set<Int>(); for i in lo.indices { let p = lo[i], q = lo[(i + 1) % lo.count]; if abs(q[1] - p[1]) < 1e-6 && q[0] > p[0] { front.insert(i) } }
    for o in layoutOpenings(b, Wl.a("openings").objs) where front.contains(Int(o.n("wall"))) {
        let xs = lo[Int(o.n("wall"))][0] + o.n("t"); let door = truthy(o["door"])
        let x0 = X(xs - o.n("w") / 2), x1 = X(xs + o.n("w") / 2), y1 = Y(o.n("z0") + o.n("h")), y0 = Y(o.n("z0"))
        d.rc(x0, y1, x1, y0, door ? Color(hex: 0x7C2D12) : Color(hex: 0x7DD3FC)); d.rs(x0, y1, x1, y0, Color(hex: 0x1E293B))
        if !door { d.ln((x0 + x1) / 2, y1, (x0 + x1) / 2, y0, Color(hex: 0x1E293B), 1.5) }
        d.rc(X(xs - o.n("w") / 2 - 0.25), y1 - max(0.12 * k, 2), X(xs + o.n("w") / 2 + 0.25), y1, Color(hex: 0x334155))
    }
    d.ln(0, gy, Wd, gy, Color(hex: 0xA3E635), 2)
    d.text(fmt(bw) + " " + t("m"), X(0) - 14, gy + 15, ink); d.text(fmt(H) + " " + t("m"), X(bw / 2) + 6, Y(H / 2), ink)
    if R > 0 { d.text("↑ " + fmt(H + R, 2) + " " + t("m"), X(-bw / 2), Y(H + R) - 6, ink) }
}

/// План забора
func drawFencePlan(_ d: DC) {
    let poly = plot(); if poly.count < 3 { return }
    let sv = PV.z, so = PV.ox, sy = PV.oy; PV.z = 1; PV.ox = 0; PV.oy = 0
    let m = zmap(poly, d.W, d.H, 30); PV.z = sv; PV.ox = so; PV.oy = sy
    func Op(_ x: Double, _ y: Double) -> CGPoint { O(m.sx(x), m.sy(y)) }
    d.poly(poly.map { Op($0[0], $0[1]) }, argb(0x4D4D7C0F), argb(0x4DFFFFFF), 1)
    for b in buildings() { d.poly(G.corners(b).map { Op($0[0], $0[1]) }, argb(0x80F59E0B)) }
    let fc = hexColor(fenceColor())
    for s in fenceSegs() {
        let a = Op(s.p0[0] + s.ux * s.a, s.p0[1] + s.uy * s.a); let e = Op(s.p0[0] + s.ux * s.b, s.p0[1] + s.uy * s.b)
        if let op = s.op {
            let gate = eq(op["k"], "gate")
            d.line(a, e, gate ? C.accent : Color(hex: 0x38BDF8), 7); d.text(gate ? "🚪" : "🚶", (a.x + e.x) / 2 - 6, (a.y + e.y) / 2 - 6, .white, 11)
        } else { d.line(a, e, fc, 4) }
    }
    for (i, q) in poly.enumerated() { d.text(String(UnicodeScalar(UInt8(65 + i % 26))), Op(q[0], q[1]).x - 4, Op(q[0], q[1]).y + (i < 2 ? 16 : -6), .white, 13, bold: true) }
}

/// Вид забора спереди
func drawFenceView(_ d: DC) {
    let f = FN(); let fh = f.n("h"); let span = 9.0; let W = d.W, H = d.H
    let k = min((W - 20) / span, (H - 30) / (fh + 0.3)); let gy = H - 16
    func X(_ x: Double) -> Double { 10 + x * k }
    func Y(_ z: Double) -> Double { gy - z * k }
    let col = hexColor(fenceColor()); let type = f.s("type")
    d.rc(0, gy, W, H, Color(hex: 0x5B4636)); d.ln(0, gy, W, gy, Color(hex: 0xA3E635), 2)
    let gx = 5.5, gw = 3.0; func wall(_ x: Double) -> Bool { x < gx || x > gx + gw }
    switch type {
    case "brick", "block":
        d.rc(X(0), Y(fh), X(gx), Y(0), col); d.rc(X(gx + gw), Y(fh), X(span), Y(0), col); var z = 0.0
        while z < fh { d.ln(X(0), Y(z), X(gx), Y(z), argb(0x33000000), 1); d.ln(X(gx + gw), Y(z), X(span), Y(z), argb(0x33000000), 1); z += type == "brick" ? 0.075 : 0.2 }
    case "concrete":
        var x = 0.0
        while x < span { if wall(x + 1) { var z = 0.0; while z < fh - 0.01 { d.rc(X(x) + 1, Y(z + 0.5) + 1, X(x + 2) - 1, Y(z) - 1, col); z += 0.5 } }; x += 2 }
    case "mesh":
        var x = 0.0
        while x < span { if wall(x) { d.ln(X(x), Y(0), X(x + fh * 0.5), Y(fh), Color(hex: 0xCBD5E1), 0.6); d.ln(X(x + fh * 0.5), Y(0), X(x), Y(fh), Color(hex: 0xCBD5E1), 0.6) }; x += 0.15 }
    case "panel3d":
        var x = 0.0; while x < span { if wall(x) { d.ln(X(x), Y(0.05), X(x), Y(fh), col, 1.5) }; x += 0.2 }
        var z = 0.05; while z < fh { d.ln(X(0), Y(z), X(gx), Y(z), col, 1.5); d.ln(X(gx + gw), Y(z), X(span), Y(z), col, 1.5); z += 0.2 }
    case "prof":
        d.rc(X(0), Y(fh), X(gx), Y(0), col); d.rc(X(gx + gw), Y(fh), X(span), Y(0), col); var x = 0.0
        while x < span { if wall(x) { d.ln(X(x), Y(0), X(x), Y(fh), argb(0x40000000), 1) }; x += 0.11 }
    default:
        let pw = type == "euro" ? 0.118 : SZm("board")[1]; let gp = f.n("gap") / 1000; var x = 0.0
        while x < span { if wall(x) && wall(x + pw) { d.rc(X(x), Y(fh), X(x + pw), Y(0), col) }; x += pw + gp }
    }
    if !["brick", "block", "concrete"].contains(type) {
        var x = 0.0
        while x <= span {
            if !(x > gx - 0.1 && x < gx + gw + 0.1) {
                if f.b("cols") { d.rc(X(x - 0.19), Y(fh + 0.15), X(x + 0.19), Y(0), hexColor(D.BTYPE.o("ceramFull").s("col"))) }
                else { d.rc(X(x) - 2, Y(fh + 0.05), X(x) + 2, Y(0), Color(hex: 0x334155)) }
            }
            x += f.n("step")
        }
    } else if type != "concrete" {
        var x = 0.0; while x <= span { if !(x > gx - 0.2 && x < gx + gw + 0.2) { d.rc(X(x - 0.19), Y(fh + 0.2), X(x + 0.19), Y(0), Color(hex: 0x7C2D12)) }; x += 3 }
    }
    d.rc(X(gx) - 3, Y(fh + 0.1), X(gx) + 3, Y(0), Color(hex: 0x1F2937)); d.rc(X(gx + gw) - 3, Y(fh + 0.1), X(gx + gw) + 3, Y(0), Color(hex: 0x1F2937))
    let gc = (type == "mesh" ? Color(hex: 0x64748B) : col).opacity(0.85)
    d.rc(X(gx) + 4, Y(fh - 0.05), X(gx + gw / 2) - 2, Y(0.05), gc); d.rc(X(gx + gw / 2) + 2, Y(fh - 0.05), X(gx + gw) - 4, Y(0.05), gc)
    d.rs(X(gx) + 4, Y(fh - 0.05), X(gx + gw / 2) - 2, Y(0.05), Color(hex: 0x0F172A), 2); d.rs(X(gx + gw / 2) + 2, Y(fh - 0.05), X(gx + gw) - 4, Y(0.05), Color(hex: 0x0F172A), 2)
    d.text(fmt(fh) + " " + t("m"), W - 34, Y(fh / 2), ink, 11)
}
