import SwiftUI
import UIKit

func argb(_ v: UInt32) -> Color { Color(hex: v & 0xFFFFFF, alpha: Double(v >> 24) / 255) }
func roofColor(_ b: Obj) -> String { b.s("kind") == "greenhouse" ? "#BBF7D0" : (D.o("RCOL")[RF(b).s("color")] as? String ?? "#B45309") }
func fenceColor() -> String {
    let f = FN()
    switch f.s("type") { case "concrete", "block": return "#A8A29E"; case "brick": return D.BTYPE.o("ceramFull").s("col"); case "mesh": return "#94A3B8"
    default: return D.o("FCOLS")[f.s("color")] as? String ?? "#166534" }
}

/// Счётчик перерисовки холстов во время жестов (без полного обновления экрана)
final class Frame: ObservableObject { static let shared = Frame(); @Published var n = 0; static func bump() { shared.n += 1 } }

/// Контекст рисования (аналог DrawScope: координаты в точках, density = 1)
final class DC {
    var ctx: GraphicsContext; let W: Double; let H: Double
    init(_ c: GraphicsContext, _ size: CGSize) { ctx = c; W = Double(size.width); H = Double(size.height) }
    func rc(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ c: Color) { ctx.fill(Path(CGRect(x: min(x0, x1), y: min(y0, y1), width: abs(x1 - x0), height: abs(y1 - y0))), with: .color(c)) }
    func rs(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ c: Color, _ w: Double = 1.5) { ctx.stroke(Path(CGRect(x: min(x0, x1), y: min(y0, y1), width: abs(x1 - x0), height: abs(y1 - y0))), with: .color(c), lineWidth: w) }
    func rcP(_ o: CGPoint, _ w: Double, _ h: Double, _ c: Color) { ctx.fill(Path(CGRect(x: o.x, y: o.y, width: w, height: h)), with: .color(c)) }
    func rsP(_ o: CGPoint, _ w: Double, _ h: Double, _ c: Color, _ lw: Double) { ctx.stroke(Path(CGRect(x: o.x, y: o.y, width: w, height: h)), with: .color(c), lineWidth: lw) }
    func line(_ a: CGPoint, _ b: CGPoint, _ c: Color, _ w: Double = 1, dash: Bool = false, round: Bool = false) {
        var p = Path(); p.move(to: a); p.addLine(to: b)
        ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: w, lineCap: round ? .square : .butt, dash: dash ? [6, 4] : []))
    }
    func ln(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ c: Color, _ w: Double = 1) { line(CGPoint(x: x0, y: y0), CGPoint(x: x1, y: y1), c, w) }
    func pl(_ pts: [CGPoint], _ c: Color, _ w: Double) { guard pts.count > 1 else { return }; for i in 0..<(pts.count - 1) { line(pts[i], pts[i + 1], c, w) } }
    func poly(_ pts: [CGPoint], _ fill: Color?, _ stroke: Color? = nil, _ width: Double = 2, dash: Bool = false) {
        guard pts.count >= 2 else { return }
        var p = Path(); for (i, q) in pts.enumerated() { if i == 0 { p.move(to: q) } else { p.addLine(to: q) } }; p.closeSubpath()
        if let f = fill { ctx.fill(p, with: .color(f)) }
        if let s = stroke { ctx.stroke(p, with: .color(s), style: StrokeStyle(lineWidth: width, dash: dash ? [8, 5] : [])) }
    }
    func circle(_ c: CGPoint, _ r: Double, _ col: Color, stroke: Double? = nil) {
        let p = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        if let s = stroke { ctx.stroke(p, with: .color(col), lineWidth: s) } else { ctx.fill(p, with: .color(col)) }
    }
    func arc(_ c: CGPoint, _ r: Double, start: Double, sweep: Double, _ col: Color, _ w: Double) {
        var p = Path(); p.addArc(center: c, radius: r, startAngle: .degrees(start), endAngle: .degrees(start + sweep), clockwise: false); ctx.stroke(p, with: .color(col), lineWidth: w)
    }
    /// y — базовая линия, как в Canvas.drawText
    func text(_ s: String, _ x: Double, _ y: Double, _ c: Color, _ size: Double = 12, bold: Bool = false, center: Bool = false) {
        let t = Text(L(s)).font(.system(size: size, weight: bold ? .bold : .regular)).foregroundColor(c)
        ctx.draw(ctx.resolve(t), at: CGPoint(x: x, y: y + size * 0.22), anchor: center ? .bottom : .bottomLeading)
    }
    func textW(_ s: String, _ size: Double) -> Double { Double((L(s) as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: size)]).width) }
}
func O(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

/// Холст-рисунок в карточке
struct Drawing: View {
    @ObservedObject var u = UIS.shared
    let h: CGFloat; let draw: (DC) -> Void
    init(_ h: CGFloat, _ draw: @escaping (DC) -> Void) { self.h = h; self.draw = draw }
    var body: some View {
        Canvas { c, size in draw(DC(c, size)) }.frame(maxWidth: .infinity).frame(height: h).background(C.field).cornerRadius(10).clipped().padding(.vertical, 6)
    }
}

// ---------- Жесты: касание, перетаскивание одним пальцем, масштаб двумя ----------
final class TouchView: UIView {
    var onDown: (CGPoint) -> Void = { _ in }; var onMove: (CGPoint, CGPoint) -> Void = { _, _ in }; var onZoom: (CGFloat, CGPoint) -> Void = { _, _ in }; var onUp: () -> Void = {}
    private var prev = CGPoint.zero; private var prevDist: CGFloat = 0; private var active = false
    override init(frame: CGRect) { super.init(frame: frame); isMultipleTouchEnabled = true; backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError() }
    private weak var sc: UIScrollView?
    private func findScroller() -> UIScrollView? {
        var v: UIView? = superview; while let x = v { if let q = x as? UIScrollView { return q }; v = x.superview }
        func dig(_ x: UIView) -> UIScrollView? {
            if let q = x as? UIScrollView, self.isDescendant(of: q) { return q }
            for c in x.subviews { if let r = dig(c) { return r } }; return nil
        }
        if let w = window { return dig(w) }; return nil
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let r = super.hitTest(point, with: event)
        if r === self, event?.type == .touches {
            if sc == nil { sc = findScroller() }
            sc?.delaysContentTouches = false; sc?.panGestureRecognizer.isEnabled = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in if let self = self, !self.active { self.sc?.panGestureRecognizer.isEnabled = true } }
        }
        return r
    }
    private func live(_ e: UIEvent?) -> [UITouch] { (e?.allTouches ?? []).filter { $0.phase != .ended && $0.phase != .cancelled } }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !active, let t = touches.first { active = true; sc = findScroller(); sc?.isScrollEnabled = false; sc?.panGestureRecognizer.isEnabled = false; let p = t.location(in: self); prev = p; prevDist = 0; onDown(p) }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard active else { return }; let pr = live(event).sorted { $0.timestamp < $1.timestamp }; if pr.isEmpty { return }
        if pr.count >= 2 {
            let a = pr[0].location(in: self), b = pr[1].location(in: self); let d = hypot(a.x - b.x, a.y - b.y)
            if prevDist > 0 && d > 0 { onZoom(d / prevDist, CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)) }; prevDist = d; prev = a
        } else {
            let p = pr[0].location(in: self); if prevDist == 0 { onMove(p, CGPoint(x: p.x - prev.x, y: p.y - prev.y)) }; prev = p; if prevDist > 0 { prevDist = 0 }
        }
    }
    private func end(_ e: UIEvent?) { if active && live(e).isEmpty { active = false; prevDist = 0; sc?.isScrollEnabled = true; sc?.panGestureRecognizer.isEnabled = true; onUp() } }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { end(event) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { end(event) }
}
struct Gestures: View {
    var onDown: (CGPoint) -> Void; var onMove: (CGPoint, CGPoint) -> Void; var onZoom: (CGFloat, CGPoint) -> Void = { _, _ in }; var onUp: () -> Void
    @State private var started = false; @State private var last = CGPoint.zero; @State private var lastMag: CGFloat = 1; @State private var mag = false; @State private var size = CGSize.zero
    var body: some View {
        GeometryReader { g in
            Color.clear.contentShape(Rectangle()).onAppear { size = g.size }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { v in
                            if !started { started = true; UIS.shared.lock = true; last = v.startLocation; onDown(v.startLocation) }
                            if mag { last = v.location; return }
                            let d = CGPoint(x: v.location.x - last.x, y: v.location.y - last.y); last = v.location
                            if d.x != 0 || d.y != 0 { onMove(v.location, d) }
                        }
                        .onEnded { _ in started = false; mag = false; lastMag = 1; UIS.shared.lock = false; onUp() }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { m in
                            mag = true; let k = m / lastMag; lastMag = m
                            if k != 1 { onZoom(k, CGPoint(x: g.size.width / 2, y: g.size.height / 2)) }
                        }
                        .onEnded { _ in lastMag = 1; DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { mag = false } }
                )
        }
    }
}

// ---------- карта участка ----------
enum PV { static var del = false; static var delSet = Set<Double>(); static var z = 1.0; static var ox = 0.0; static var oy = 0.0; static var hd: Int? = nil; static var draw: [Pt]? = nil; static var drawTarget: Double? = nil }
struct Mapper { let sc: Double; let sx: (Double) -> Double; let sy: (Double) -> Double; let w: (Double, Double) -> Pt }
func zmap(_ poly: [Pt], _ W: Double, _ H: Double, _ pad: Double) -> Mapper {
    let xs = poly.map { $0[0] }, ys = poly.map { $0[1] }; let minX = xs.min()!, minY = ys.min()!
    let bw = max(xs.max()! - minX, 1), bh = max(ys.max()! - minY, 1); let sc0 = max(min((W - 2 * pad) / bw, (H - 2 * pad) / bh), 0.01)
    let ox0 = (W - bw * sc0) / 2, oy0 = (H - bh * sc0) / 2; let z = PV.z; let cx = W / 2, cy = H / 2
    func bx(_ x: Double) -> Double { ox0 + (x - minX) * sc0 }
    func by(_ y: Double) -> Double { H - (oy0 + (y - minY) * sc0) }
    let pox = PV.ox, poy = PV.oy
    return Mapper(sc: sc0 * z, sx: { x in (bx(x) - cx) * z + cx + pox }, sy: { y in (by(y) - cy) * z + cy + poy },
                  w: { px, py in let ux = (px - pox - cx) / z + cx; let uy = (py - poy - cy) / z + cy; return pt(minX + (ux - ox0) / sc0, minY + ((H - uy) - oy0) / sc0) })
}
func selItem() -> Obj? { items().first { num($0["id"]) == num(St.project["sel"]) } }
func selectItem(_ id: Any?) { St.project["sel"] = id; if let it = selItem(), isB(it) { St.project["bSel"] = id } }
func hitItem(_ w: Pt) -> Obj? {
    let its = items(); let order = its.filter { isB($0) } + its.filter { eq($0["kind"], "tree") } + its.filter { !isB($0) && !eq($0["kind"], "tree") }
    return order.first { eq($0["kind"], "tree") ? G.dist(w, pt($0.n("cx"), $0.n("cy"))) <= $0.n("w") / 2 : G.inside(w, G.corners($0)) }
}
private func rotW(_ it: Obj) -> (Double, Double) -> Pt { let r = it.n("rot") * Double.pi / 180; let c = cos(r), s = sin(r); let cx = it.n("cx"), cy = it.n("cy"); return { x, y in pt(cx + x * c - y * s, cy + x * s + y * c) } }
func itemHandles(_ it: Obj?) -> [Pt] {
    guard let it = it, !eq(it["kind"], "tree"), it.oo("shape")?.b("full") != true else { return [] }; let W = rotW(it)
    if eq(it.oo("shape")?["type"], "poly") && isShaped(it) { return shapeLocal(it).map { W($0[0], $0[1]) } }
    let hw = it.n("w") / 2, hd = it.n("d") / 2; return [W(-hw, -hd), W(hw, -hd), W(hw, hd), W(-hw, hd)]
}
func dragHandle(_ it: Obj, _ i: Int, _ wp: Pt) {
    let r = it.n("rot") * Double.pi / 180; let c = cos(r), s = sin(r); let dx = wp[0] - it.n("cx"), dy = wp[1] - it.n("cy"); let lx = dx * c + dy * s, ly = -dx * s + dy * c
    func sn(_ v: Double) -> Double { (v * 20).rounded(.toNearestOrAwayFromZero) / 20 }
    if eq(it.oo("shape")?["type"], "poly") && isShaped(it) {
        var q = shapeLocal(it); q[i] = pt(sn(lx), sn(ly))
        let mx = q.map { $0[0] }.min()!, my = q.map { $0[1] }.min()!; let cx = (mx + q.map { $0[0] }.max()!) / 2, cy = (my + q.map { $0[1] }.max()!) / 2
        it.o("shape")["pts"] = toArr(q.map { pt(r2($0[0] - mx), r2($0[1] - my)) }); syncPoly(it); it["cx"] = it.n("cx") + cx * c - cy * s; it["cy"] = it.n("cy") + cx * s + cy * c; return
    }
    let S2: [[Double]] = [[-1, -1], [1, -1], [1, 1], [-1, 1]]; let sg = S2[i]; let ox = -sg[0] * it.n("w") / 2, oy = -sg[1] * it.n("d") / 2
    let nw = max(0.5, sn(abs(lx - ox))), nd = max(0.5, sn(abs(ly - oy))); let px = ox + sg[0] * nw, py = oy + sg[1] * nd; let cx = (ox + px) / 2, cy = (oy + py) / 2
    it["w"] = nw; it["d"] = nd; it["cx"] = it.n("cx") + cx * c - cy * s; it["cy"] = it.n("cy") + cx * s + cy * c
}
func setShape(_ b: Obj, _ type: String) {
    let s = b.o("shape")
    if type == "poly" && ((s["pts"] as? Arr).map { $0.count < 3 } ?? true) {
        let tmp = assign(obj(), b, obj(("shape", nil), ("rot", 0.0)))
        s["pts"] = toArr(G.corners(tmp).map { pt(r2($0[0] - b.n("cx") + b.n("w") / 2), r2($0[1] - b.n("cy") + b.n("d") / 2)) })
    }
    if type == "rect" { b["shape"] = nil } else { s["type"] = type; if type == "poly" { syncPoly(b) } }
    b["rooms"] = arr(); b["plan"] = obj(); if manOuter(b).isEmpty { b.o("walls")["openings"] = autoOpenings(b) }
}
func coverPlot(_ b: Obj) {
    let poly = plot(); let mx = poly.map { $0[0] }.min()!, my = poly.map { $0[1] }.min()!
    b["rot"] = 0.0; b["shape"] = obj(("type", "poly"), ("full", true), ("pts", toArr(poly.map { pt(r2($0[0] - mx), r2($0[1] - my)) }))); syncPoly(b)
    b["cx"] = (mx + poly.map { $0[0] }.max()!) / 2; b["cy"] = (my + poly.map { $0[1] }.max()!) / 2; b["roof"] = "FLAT"
    let hi = max(0, buildings().filter { $0 !== b }.map { $0.n("floors") * $0.n("floorH") + roofRise($0) }.max() ?? 0); b["floors"] = 1.0; b["floorH"] = r2(max(2.7, hi + 0.5))
}
func drawFinish() {
    let p = St.project; guard let P = PV.draw, P.count >= 3 else { return }
    let mx = P.map { $0[0] }.min()!, my = P.map { $0[1] }.min()!; let cx = (mx + P.map { $0[0] }.max()!) / 2, cy = (my + P.map { $0[1] }.max()!) / 2
    var b: Obj? = PV.drawTarget.flatMap { id in items().first { $0.n("id") == id } }
    if b == nil { b = newItem(p, "b", "house", cx, cy); p.a("items").add(b) }
    let bb = b!
    bb["cx"] = cx; bb["cy"] = cy; bb["rot"] = 0.0; bb["shape"] = obj(("type", "poly"), ("pts", toArr(P.map { pt(r2($0[0] - mx), r2($0[1] - my)) }))); syncPoly(bb); bb["rooms"] = arr(); bb["plan"] = obj()
    bb.o("walls")["openings"] = autoOpenings(bb); PV.draw = nil; selectItem(bb["id"]); upd()
}

func drawPlot(_ d: DC, edit: Bool, only: Double? = nil) {
    let p = St.project; let poly = plot(); guard poly.count >= 3 else { return }; let W = d.W, H = d.H; let m = zmap(poly, W, H, 40)
    func Op(_ q: Pt) -> CGPoint { O(m.sx(q[0]), m.sy(q[1])) }
    let xs = poly.map { $0[0] }, ys = poly.map { $0[1] }; let step = [1.0, 2, 5, 10, 20, 50, 100].first { $0 * m.sc >= 14 } ?? 100; let gc = argb(0x12FFFFFF)
    var x = (xs.min()! / step).rounded(.up) * step; while x <= xs.max()! + 1e-9 { d.line(O(m.sx(x), m.sy(ys.min()!)), O(m.sx(x), m.sy(ys.max()!)), gc); x += step }
    var y = (ys.min()! / step).rounded(.up) * step; while y <= ys.max()! + 1e-9 { d.line(O(m.sx(xs.min()!), m.sy(y)), O(m.sx(xs.max()!), m.sy(y)), gc); y += step }
    d.poly(poly.map { Op($0) }, argb(0x4D4D7C0F), .white, 2)
    let c = G.centroid(poly)
    for (i, q) in poly.enumerated() {
        let n = poly[(i + 1) % poly.count]; let dx = q[0] - c[0], dy = q[1] - c[1]; let l = max(hypot(dx, dy), 1e-6)
        d.text(String(UnicodeScalar(UInt8(65 + i % 26))), m.sx(q[0]) + dx / l * 14 - 5, m.sy(q[1]) - dy / l * 14 + 5, .white, 15, bold: true)
        let mx = (q[0] + n[0]) / 2, my = (q[1] + n[1]) / 2; let ex = mx - c[0], ey = my - c[1]; let el = max(hypot(ex, ey), 1e-6)
        d.text(fmt(G.dist(q, n), 1) + " " + t("m"), m.sx(mx) + ex / el * 22, m.sy(my) - ey / el * 14 + 4, Color(hex: 0xCBD5E1), 12, center: true)
    }
    let bs = buildings(); var probs = Set<Double>()
    for b in bs where b.oo("shape")?.b("full") != true && !G.fits(b, poly, setbackOf(b)) { probs.insert(b.n("id")) }
    for i in bs.indices { for j in (i + 1)..<max(bs.count, i + 1) where !noClash(bs[i]) && !noClash(bs[j]) && rectsOverlap(bs[i], bs[j]) { probs.insert(bs[i].n("id")); probs.insert(bs[j].n("id")) } }
    let its = items(); let order = its.filter { !isB($0) && !eq($0["kind"], "tree") } + bs + its.filter { eq($0["kind"], "tree") }
    if let P = PV.draw, !P.isEmpty {
        let pts = P.map { Op($0) }
        if P.count > 2 { d.poly(pts, nil, C.accent, 3, dash: true) } else if P.count == 2 { d.line(pts[0], pts[1], C.accent, 3, dash: true) }
        for (i, q) in P.enumerated() {
            d.circle(Op(q), 6, C.accent); d.text(String(UnicodeScalar(UInt8(65 + i % 26))), Op(q).x + 8, Op(q).y - 8, .white, 13, bold: true)
            if i > 0 { let a = P[i - 1]; d.text(fmt(G.dist(a, q), 2), (Op(a).x + Op(q).x) / 2 + 4, (Op(a).y + Op(q).y) / 2 - 4, Color(hex: 0xFDE68A), 11) }
        }
    }
    for it in order {
        let sel = (edit && !PV.del && it.n("id") == num(p["sel"])) || it.n("id") == (only ?? -999); let k = kindOf(it) ?? obj()
        if eq(it["kind"], "tree") {
            let cc = Op(pt(it.n("cx"), it.n("cy"))); let r = it.n("w") / 2 * m.sc
            d.circle(cc, r, argb(0xD915803D)); d.circle(cc, r, sel ? C.accent : Color(hex: 0x064E3B), stroke: sel ? 3 : 1.5)
        } else {
            let cs = G.corners(it).map { Op($0) }
            if isB(it) {
                let bad = probs.contains(it.n("id")); let hc = bad ? C.warn : C.accent
                d.poly(cs, eq(it["kind"], "greenhouse") ? argb(0x8CBBF7D0) : hc.opacity(0.55), sel ? .white : hc, sel ? 3.5 : 2)
                if ((eq(it["roof"], "GABLE") || eq(it["roof"], "MANSARD")) && !eq(it["kind"], "greenhouse") && !isShaped(it)) {
                    let W2 = rotW(it); let (ax, ay): (Double, Double) = it.n("w") >= it.n("d") ? (it.n("w") / 2, 0) : (0, it.n("d") / 2)
                    d.line(Op(W2(-ax, -ay)), Op(W2(ax, ay)), argb(0x99FFFFFF), 1, dash: true)
                }
                if sel { for (i, q) in cs.enumerated() { d.circle(q, 3, .white); d.text(String(i + 1), q.x + 5, q.y - 5, hc, 13, bold: true) } }
            } else {
                d.poly(cs, hexColor(k.s("col")).opacity(eq(it["kind"], "lawn") ? 0.7 : 0.9), sel ? C.accent : argb(0x4D000000), sel ? 3 : 1)
            }
        }
        if PV.del && PV.delSet.contains(it.n("id")) {
            let c0 = Op(pt(it.n("cx"), it.n("cy"))); let rr = max(14, min(it.n("w"), it.n("d")) * m.sc / 2)
            d.circle(c0, rr, C.warn, stroke: 4); d.line(O(c0.x - rr * 0.6, c0.y - rr * 0.6), O(c0.x + rr * 0.6, c0.y + rr * 0.6), C.warn, 4); d.line(O(c0.x + rr * 0.6, c0.y - rr * 0.6), O(c0.x - rr * 0.6, c0.y + rr * 0.6), C.warn, 4)
        }
        let fs = max(11, min(20, min(it.n("w"), it.n("d")) * m.sc * 0.45))
        d.text((it["emoji"] as? String) ?? k.s("e"), m.sx(it.n("cx")), m.sy(it.n("cy")) + fs * 0.35, .white, fs, center: true)
    }
    if edit && PV.draw == nil && !PV.del {
        let it = selItem()
        for q in itemHandles(it) { let o = Op(q); d.rcP(O(o.x - 6, o.y - 6), 12, 12, .white); d.rsP(O(o.x - 6, o.y - 6), 12, 12, C.accent, 2) }
        if PV.hd != nil, let it = it { d.text(fmt(it.n("w"), 2) + " × " + fmt(it.n("d"), 2) + " м", m.sx(it.n("cx")), m.sy(it.n("cy")) + 28, Color(hex: 0xFDE68A), 14, bold: true, center: true) }
    }
    d.text("×" + fmt(PV.z, 1), 10, H - 10, Color(hex: 0xCBD5E1), 12)
}
/// обработчики жестов карты участка
final class PlotTouch {
    var W = 300.0, H = 300.0
    private var mode = 0; private var moved = false // 0 нет, 1 пан, 2 тащим объект, 3 ручка
    func m() -> Mapper { zmap(plot(), W, H, 40) }
    func down(_ o: CGPoint) {
        moved = false; let m = m(); let w = m.w(Double(o.x), Double(o.y))
        if PV.del { if let h = hitItem(w) { let id = h.n("id"); if PV.delSet.contains(id) { PV.delSet.remove(id) } else { PV.delSet.insert(id) }; mode = 0; UI.tick += 1; return }; mode = 1; return }
        if PV.draw != nil { func sn(_ v: Double) -> Double { (v * 4).rounded(.toNearestOrAwayFromZero) / 4 }; PV.draw!.append(pt(sn(w[0]), sn(w[1]))); mode = 0; UI.tick += 1; return }
        let hs = itemHandles(selItem()); let hi = hs.firstIndex { hypot(m.sx($0[0]) - Double(o.x), m.sy($0[1]) - Double(o.y)) < 16 }
        if let hi = hi { PV.hd = hi; mode = 3; moved = true; return }
        if let hit = hitItem(w) { if hit.n("id") != num(St.project["sel"]) { selectItem(hit["id"]); moved = true }; mode = 2; Frame.bump() } else { mode = 1 }
    }
    func move(_ o: CGPoint, _ d: CGPoint) {
        switch mode {
        case 1: PV.ox += Double(d.x); PV.oy += Double(d.y); Frame.bump()
        case 2: guard let it = selItem() else { return }; let m = m(); it["cx"] = it.n("cx") + Double(d.x) / m.sc; it["cy"] = it.n("cy") - Double(d.y) / m.sc; moved = true; Frame.bump()
        case 3: guard let it = selItem(), let hd = PV.hd else { return }; let m = m(); dragHandle(it, hd, m.w(Double(o.x), Double(o.y))); moved = true; Frame.bump()
        default: break }
    }
    func zoom(_ k: CGFloat, _ c: CGPoint) {
        let px = Double(c.x) - W / 2, py = Double(c.y) - H / 2; let nz = min(max(PV.z * Double(k), 0.5), 30); let kk = nz / PV.z
        PV.ox = px - (px - PV.ox) * kk; PV.oy = py - (py - PV.oy) * kk; PV.z = nz; mode = 0; Frame.bump()
    }
    func up() {
        let wasHd = PV.hd != nil; PV.hd = nil
        if mode == 2 || mode == 3 { if let it = selItem() { it["cx"] = r2(it.n("cx")); it["cy"] = r2(it.n("cy")); if wasHd && isB(it) { if manOuter(it).isEmpty { it.o("walls")["openings"] = autoOpenings(it) }; planChanged(it) } } }
        mode = 0; if moved { moved = false; upd() } else { Frame.bump() }
    }
}
