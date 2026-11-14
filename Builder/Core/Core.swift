import Foundation

/// Глобальное состояние (как S в прототипе).
enum St {
    static var project: Obj = Obj()
    static var lang = "ru"
    static var cur = "USD"
    /// выбранная постройка (S.project.b)
    static var b: Obj {
        let its = project.a("items").objs
        return its.first { num($0["id"]) == num(project["bSel"]) && isB($0) } ?? its.first { isB($0) }!
    }
}

/// Справочники из прототипа (Resources/data.json).
enum D {
    static var all: Obj = Obj()
    static func load(_ data: Data) { if let o = Json.parse(data) as? Obj { all = o } }
    static func o(_ k: String) -> Obj { all.o(k) }
    static func a(_ k: String) -> Arr { all.a(k) }
    static var TR: Obj { o("TR") }; static var KINDS: Obj { o("KINDS") }; static var ZONES: Obj { o("ZONES") }; static var WMAT: Obj { o("WMAT") }
    static var SZDEF: Obj { o("SZDEF") }; static var RDEF: Obj { o("RDEF") }; static var ROOMT: Obj { o("ROOMT") }; static var COVERS: Obj { o("COVERS") }
    static var BFMT: Obj { o("BFMT") }; static var BTYPE: Obj { o("BTYPE") }; static var FBS: Obj { o("FBS") }; static var PK_W: Obj { o("PK_W") }; static var FIN_DEF: Obj { o("FIN_DEF") }
}

/// Доп. языки: перевод по английской строке из i18n/<lang>.json, при отсутствии — английский.
enum X { static var map: [String: String] = [:]; static var lang = "" }
let BASE_LANGS: Set<String> = ["ru", "en", "uz", "uzc"]
let RTL_LANGS: Set<String> = ["ar", "fa"]
func isExt() -> Bool { !BASE_LANGS.contains(St.lang) }
func xl(_ en: String) -> String { isExt() ? (X.map[en] ?? en) : en }
func li() -> Int { switch St.lang { case "ru": return 0; case "uz", "uzc": return 2; default: return 1 } }
func t(_ k: String) -> String {
    guard let v = D.TR.aa(k) else { return k }
    if St.lang == "uzc" { return cyr(v.s(2)) }
    if isExt() { return xl(v.s(1)) }
    return v.s(li())
}
/// Площадь участка: в сотках для ru/uz/kk, в м² для остальных языков.
func sotWord(_ v: Double) -> String {
    if St.lang != "ru" { return t("sotka") }
    let n = Int(v.rounded()); if abs(v - Double(n)) > 1e-9 { return "сотки" }
    if n % 10 == 1 && n % 100 != 11 { return "сотка" }
    if (2...4).contains(n % 10) && !(12...14).contains(n % 100) { return "сотки" }
    return "соток"
}
func sotStr(_ sot: Double, _ dec: Int = 1, _ m2: Bool = true) -> String {
    if ["ru", "uz", "uzc", "kk"].contains(St.lang) {
        let f = fmt(sot, dec); let nv = Double(f.replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")) ?? sot
        return "\(f) \(sotWord(nv))" + (m2 ? " · \(fmt((sot * 100).rounded())) \(t("m2"))" : "")
    }
    return "\(fmt((sot * 100).rounded())) \(t("m2"))"
}
func tr3(_ v: Any?) -> String {
    guard let a = asArr(v) else { if let v = v { return (v as? String) ?? "\(v)" }; return "" }
    if St.lang == "uzc" { return cyr(a.s(2)) }
    if isExt() { return xl(a.s(1)) }
    return a.s(li())
}

private let keepRe = try! NSRegularExpression(pattern: "ARESTI Labs[’']?|3D|PDF|XPS|PEX|PPR|MDF|OSB(-3)?|PVC|M\\d{3}|\\d(\\.\\d)?NF|CSV|Excel|UZS|RUB|KZT|KGS|TJS|USD|EUR|TRY|AZN|BYN")
private func rxRep(_ p: String, _ s: String, _ to: String) -> String {
    guard let r = try? NSRegularExpression(pattern: p) else { return s }
    return r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: NSRegularExpression.escapedTemplate(for: to))
}
private let cyrPairs: [(String, String)] = {
    let A = "[‘’ʻ'`]"
    return [("O\(A)", "Ў"), ("o\(A)", "ў"), ("G\(A)", "Ғ"), ("g\(A)", "ғ"), ("SH", "Ш"), ("Sh", "Ш"), ("sh", "ш"), ("CH", "Ч"), ("Ch", "Ч"), ("ch", "ч"), ("Yo", "Ё"), ("yo", "ё"), ("Yu", "Ю"), ("yu", "ю"), ("Ya", "Я"), ("ya", "я"),
            ("Ye", "Е"), ("ye", "е"), ("TS", "Ц"), ("Ts", "Ц"), ("ts", "ц"), ("\\bE", "Э"), ("\\be", "э"), (A, "ъ")]
}()
private let cyrMap: [Character: String] = ["a": "а", "b": "б", "c": "ц", "d": "д", "e": "е", "f": "ф", "g": "г", "h": "ҳ", "i": "и", "j": "ж", "k": "к", "l": "л", "m": "м", "n": "н",
    "o": "о", "p": "п", "q": "қ", "r": "р", "s": "с", "t": "т", "u": "у", "v": "в", "w": "в", "x": "х", "y": "й", "z": "з"]
func cyr(_ src: String?) -> String {
    guard let src = src, !src.isEmpty else { return src ?? "" }
    var keep = [String](); var s = src
    let ms = keepRe.matches(in: s, range: NSRange(s.startIndex..., in: s))
    // заменяем справа налево, чтобы не сбить диапазоны; индексы раздаём слева направо
    var tokens = [(NSRange, Int)](); for (i, m) in ms.enumerated() { keep.append((s as NSString).substring(with: m.range)); tokens.append((m.range, i)) }
    for (rg, i) in tokens.reversed() { s = (s as NSString).replacingCharacters(in: rg, with: "\u{1}\(i)\u{2}") }
    for (p, v) in cyrPairs { s = rxRep(p, s, v) }
    var out = ""
    for ch in s { if let l = cyrMap[Character(ch.lowercased())], ch.isASCII, ch.isLetter { out += ch.isLowercase ? l : l.uppercased() } else { out.append(ch) } }
    if let r = try? NSRegularExpression(pattern: "\u{1}(\\d+)\u{2}") {
        let ns = out as NSString; var res = ""; var last = 0
        for m in r.matches(in: out, range: NSRange(location: 0, length: ns.length)) { res += ns.substring(with: NSRange(location: last, length: m.range.location - last)); res += keep[Int(ns.substring(with: m.range(at: 1)))!]; last = m.range.location + m.range.length }
        res += ns.substring(from: last); out = res
    }
    return out
}

func isB(_ it: Obj?) -> Bool { it != nil && eq(it!["cat"], "b") }
func rect(_ w: Double, _ d: Double) -> [Pt] { [pt(0, 0), pt(w, 0), pt(w, d), pt(0, d)] }
func plot() -> [Pt] { let p = St.project; return p.b("rectMode") ? rect(p.n("plotW"), p.n("plotD")) : pts(p["points"]) }
func items() -> [Obj] { St.project.a("items").objs }
func buildings() -> [Obj] { items().filter { isB($0) } }
func kindOf(_ it: Obj) -> Obj? { isB(it) ? D.KINDS.oo(it.s("kind")) : D.ZONES.oo(it.s("kind")) }
func itemName(_ it: Obj) -> String {
    guard let k = kindOf(it) else { return "?" }
    let nm = (it.str("name")).flatMap { $0.isEmpty ? nil : $0 } ?? tr3(k["n"])
    return (it.str("emoji") ?? k.s("e")) + " " + nm
}

// ---------- уровни: число (этаж) или "b"/"a" ----------
func lvKey(_ l: Any?) -> String { if let d = l as? Double { return String(Int(d)) }; if let i = l as? Int { return String(i) }; return (l as? String) ?? "\(l ?? "")" }
func lvEq(_ a: Any?, _ b: Any?) -> Bool { lvKey(a) == lvKey(b) }
func lvIsNum(_ l: Any?) -> Bool { l is Double || l is Int }

// ---------- геометрия ----------
enum G {
    static func sarea(_ p: [Pt]) -> Double { var s = 0.0; for i in p.indices { let a = p[i]; let b = p[(i + 1) % p.count]; s += a[0] * b[1] - b[0] * a[1] }; return s / 2 }
    static func area(_ p: [Pt]) -> Double { abs(sarea(p)) }
    static func dist(_ a: Pt, _ b: Pt) -> Double { hypot2(a[0] - b[0], a[1] - b[1]) }
    static func perim(_ p: [Pt]) -> Double { var s = 0.0; for i in p.indices { s += dist(p[i], p[(i + 1) % p.count]) }; return s }
    static func corners(_ b: Obj) -> [Pt] {
        let r = b.n("rot") * Double.pi / 180; let c = cos(r); let s = sin(r); let hw = b.n("w") / 2; let hd = b.n("d") / 2; let cx = b.n("cx"); let cy = b.n("cy")
        let loc = isShaped(b) ? shapeLocal(b) : [pt(-hw, -hd), pt(hw, -hd), pt(hw, hd), pt(-hw, hd)]
        return loc.map { pt(cx + $0[0] * c - $0[1] * s, cy + $0[0] * s + $0[1] * c) }
    }
    static func inside(_ p: Pt, _ poly: [Pt]) -> Bool {
        var r = false; var j = poly.count - 1
        for i in poly.indices { let a = poly[i]; let b = poly[j]
            if (a[1] > p[1]) != (b[1] > p[1]) && p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0] { r.toggle() }; j = i }
        return r
    }
    static func dseg(_ p: Pt, _ a: Pt, _ b: Pt) -> Double {
        let dx = b[0] - a[0]; let dy = b[1] - a[1]; let l2 = dx * dx + dy * dy; if l2 < 1e-12 { return dist(p, a) }
        let tt = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2)); return hypot2(p[0] - (a[0] + tt * dx), p[1] - (a[1] + tt * dy))
    }
    static func minPE(_ pts: [Pt], _ poly: [Pt]) -> Double { var m = 1e9; for p in pts { for i in poly.indices { m = min(m, dseg(p, poly[i], poly[(i + 1) % poly.count])) } }; return m }
    static func minDist(_ b: Obj, _ poly: [Pt]) -> Double { let cs = corners(b); return min(minPE(cs, poly), minPE(poly, cs)) }
    static func fits(_ b: Obj, _ poly: [Pt], _ sb: Double) -> Bool {
        if poly.count < 3 { return false }; let cs = corners(b)
        if cs.contains(where: { !inside($0, poly) }) { return false }; if poly.contains(where: { inside($0, cs) }) { return false }; return minDist(b, poly) >= sb - 1e-6
    }
    static func centroid(_ p: [Pt]) -> Pt { pt(p.reduce(0) { $0 + $1[0] } / Double(p.count), p.reduce(0) { $0 + $1[1] } / Double(p.count)) }
}

// ---------- формы зданий ----------
func isShaped(_ b: Obj?) -> Bool {
    guard let b = b, eq(b["cat"], "b"), let s = b.oo("shape") else { return false }
    return truthy(s["type"]) && !eq(s["type"], "rect")
}
private func wingA(_ b: Obj) -> Double { let s = b.oo("shape") ?? Obj(); let m = min(b.n("w"), b.n("d")); return max(0.5, min(s.nz("a", m * 0.45), m * 0.9)) }
func shapeLocal(_ b: Obj) -> [Pt] {
    let hw = b.n("w") / 2; let hd = b.n("d") / 2; let s = b.oo("shape") ?? Obj(); let a = wingA(b)
    switch s.s("type") {
    case "L": return [pt(-hw, -hd), pt(hw, -hd), pt(hw, -hd + a), pt(-hw + a, -hd + a), pt(-hw + a, hd), pt(-hw, hd)]
    case "U": return [pt(-hw, -hd), pt(hw, -hd), pt(hw, hd), pt(hw - a, hd), pt(hw - a, -hd + a), pt(-hw + a, -hd + a), pt(-hw + a, hd), pt(-hw, hd)]
    case "T": return [pt(-a / 2, -hd), pt(a / 2, -hd), pt(a / 2, hd - a), pt(hw, hd - a), pt(hw, hd), pt(-hw, hd), pt(-hw, hd - a), pt(-a / 2, hd - a)]
    case "poly":
        let P = pts(s["pts"])
        if P.count >= 3 {
            let cx = (P.map { $0[0] }.min()! + P.map { $0[0] }.max()!) / 2; let cy = (P.map { $0[1] }.min()! + P.map { $0[1] }.max()!) / 2
            var q = P.map { pt($0[0] - cx, $0[1] - cy) }; if G.sarea(q) < 0 { q.reverse() }; return q
        }
    default: break
    }
    return [pt(-hw, -hd), pt(hw, -hd), pt(hw, hd), pt(-hw, hd)]
}
struct Wing { var cx: Double; var cy: Double; var w: Double; var d: Double }
func wings(_ b: Obj) -> [Wing]? {
    let hw = b.n("w") / 2; let hd = b.n("d") / 2; let s = b.oo("shape") ?? Obj(); let a = wingA(b); let W = b.n("w"); let Dd = b.n("d")
    switch s.s("type") {
    case "L": return [Wing(cx: 0, cy: -hd + a / 2, w: W, d: a), Wing(cx: -hw + a / 2, cy: a / 2, w: a, d: Dd - a)]
    case "U": return [Wing(cx: 0, cy: -hd + a / 2, w: W, d: a), Wing(cx: -hw + a / 2, cy: a / 2, w: a, d: Dd - a), Wing(cx: hw - a / 2, cy: a / 2, w: a, d: Dd - a)]
    case "T": return [Wing(cx: 0, cy: hd - a / 2, w: W, d: a), Wing(cx: 0, cy: -a / 2, w: a, d: Dd - a)]
    case "poly": return polyRects(b)
    default: return [Wing(cx: 0, cy: 0, w: W, d: Dd)]
    }
}
func polyRects(_ b: Obj) -> [Wing]? {
    let q = shapeLocal(b); let n = q.count
    if !q.indices.allSatisfy({ i in let p = q[i]; let r = q[(i + 1) % n]; return abs(p[0] - r[0]) < 1e-6 || abs(p[1] - r[1]) < 1e-6 }) { return nil }
    func U(_ a: [Double]) -> [Double] { Array(Set(a.map { ($0 * 1000).rounded() / 1000 })).sorted() }
    let xs = U(q.map { $0[0] }); let ys = U(q.map { $0[1] })
    final class R { let x0: Double, x1: Double, y0: Double; var y1: Double; init(_ a: Double, _ b: Double, _ c: Double, _ d: Double) { x0 = a; x1 = b; y0 = c; y1 = d } }
    var out = [R](); var prev = [R]()
    if ys.count < 2 { return nil }
    for j in 0..<(ys.count - 1) {
        var row = [(Double, Double)](); var st: Double? = nil
        for i in 0..<(xs.count - 1) {
            let inn = G.inside(pt((xs[i] + xs[i + 1]) / 2, (ys[j] + ys[j + 1]) / 2), q)
            if inn && st == nil { st = xs[i] }
            if !inn, let s0 = st { row.append((s0, xs[i])); st = nil }
        }
        if let s0 = st { row.append((s0, xs.last!)) }
        prev = row.map { (x0, x1) in
            if let f = prev.first(where: { abs($0.x0 - x0) < 1e-6 && abs($0.x1 - x1) < 1e-6 }) { f.y1 = ys[j + 1]; return f }
            let nr = R(x0, x1, ys[j], ys[j + 1]); out.append(nr); return nr
        }
    }
    if out.isEmpty || out.count > 8 { return nil }
    return out.map { Wing(cx: ($0.x0 + $0.x1) / 2, cy: ($0.y0 + $0.y1) / 2, w: $0.x1 - $0.x0, d: $0.y1 - $0.y0) }
}
func bPer(_ b: Obj) -> Double { !isShaped(b) ? 2 * (b.n("w") + b.n("d")) : G.perim(shapeLocal(b)) }
func bArea(_ b: Obj) -> Double { !isShaped(b) ? b.n("w") * b.n("d") : G.area(shapeLocal(b)) }
func inArea(_ b: Obj, _ t: Double) -> Double { max(bArea(b) - bPer(b) * t + 4 * t * t, 0.25) }
func inPer(_ b: Obj, _ t: Double) -> Double { max(bPer(b) - 8 * t, 1.0) }
func eqRect(_ b: Obj) -> [Double] {
    let P = bPer(b) / 2; let A = bArea(b); let Dd = P * P - 4 * A
    if Dd < 0 { let s = A.squareRoot(); return [s, s] }
    let w = (P + Dd.squareRoot()) / 2; return [w, max(P - w, 0.5)]
}
func roofSpan(_ b: Obj) -> Double {
    if !isShaped(b) { return min(b.n("w"), b.n("d")) }
    if let ws = wings(b) { return ws.map { min($0.w, $0.d) }.max()! }
    return eqRect(b).min()!
}
func offsetIn(_ pts: [Pt], _ t: Double) -> [Pt] {
    let n = pts.count
    func N(_ a: Pt, _ b: Pt) -> Pt { let dx = b[0] - a[0]; let dy = b[1] - a[1]; var l = hypot2(dx, dy); if l == 0 { l = 1 }; return pt(-dy / l, dx / l) }
    return pts.enumerated().map { (i, v) in
        let n1 = N(pts[(i - 1 + n) % n], v); let n2 = N(v, pts[(i + 1) % n]); let k = 1 + n1[0] * n2[0] + n1[1] * n2[1]
        return k < 0.05 ? pt(v[0] + n1[0] * t, v[1] + n1[1] * t) : pt(v[0] + t * (n1[0] + n2[0]) / k, v[1] + t * (n1[1] + n2[1]) / k)
    }
}
func segX(_ p1: Pt, _ p2: Pt, _ p3: Pt, _ p4: Pt) -> Bool {
    func d(_ a: Pt, _ b: Pt, _ c: Pt) -> Double { (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]) }
    let d1 = d(p3, p4, p1); let d2 = d(p3, p4, p2); let d3 = d(p1, p2, p3); let d4 = d(p1, p2, p4)
    return ((d1 > 1e-9 && d2 < -1e-9) || (d1 < -1e-9 && d2 > 1e-9)) && ((d3 > 1e-9 && d4 < -1e-9) || (d3 < -1e-9 && d4 > 1e-9))
}
func polysOverlap(_ A: [Pt], _ B: [Pt]) -> Bool {
    for i in A.indices { for j in B.indices { if segX(A[i], A[(i + 1) % A.count], B[j], B[(j + 1) % B.count]) { return true } } }
    return A.contains { G.inside($0, B) } || B.contains { G.inside($0, A) } || G.inside(G.centroid(A), B) || G.inside(G.centroid(B), A)
}
func noClash(_ it: Obj) -> Bool { eq(it.oo("walls")?["mat"], "open") }
func isFull(_ it: Obj) -> Bool { it.oo("shape")?.b("full") == true }
func syncPoly(_ b: Obj) {
    let P = pts(b.o("shape")["pts"]); if P.count < 3 { return }
    b["w"] = max(0.5, P.map { $0[0] }.max()! - P.map { $0[0] }.min()!); b["d"] = max(0.5, P.map { $0[1] }.max()! - P.map { $0[1] }.min()!)
}

// ---------- участок ----------
func setbackOf(_ it: Obj) -> Double { noClash(it) ? 0 : (eq(it["kind"], "house") ? St.project.n("setback") : St.project.n("setbackAux", 1.0)) }
func rectsOverlap(_ a: Obj, _ b: Obj) -> Bool { polysOverlap(G.corners(a), G.corners(b)) }
func siteProblems() -> [String] {
    let poly = plot(); let bs = buildings(); var out = [String]()
    for b in bs where !isFull(b) && !G.fits(b, poly, setbackOf(b)) { out.append("\(itemName(b)) — \(t("sOutside")) (\(fmt(setbackOf(b))) \(t("m")))") }
    for i in bs.indices { for j in (i + 1)..<max(bs.count, i + 1) where !noClash(bs[i]) && !noClash(bs[j]) && rectsOverlap(bs[i], bs[j]) { out.append("\(t("sOverlap")): \(itemName(bs[i])) + \(itemName(bs[j]))") } }
    return out
}
final class SiteStats {
    var area: Double; var built = 0.0; var zones: [(String, Double)] = []; var trees = 0; var free = 0.0
    var tiles = 0.0; var pavePcs = 0; var curb = 0.0; var bSand = 0.0; var bGravel = 0.0; var seed = 0.0; var soil = 0.0
    init(_ a: Double) { area = a }
    func zone(_ k: String) -> Double { zones.first { $0.0 == k }?.1 ?? 0 }
    func addZone(_ k: String, _ v: Double) { if let i = zones.firstIndex(where: { $0.0 == k }) { zones[i].1 += v } else { zones.append((k, v)) } }
}
func siteStats() -> SiteStats {
    let poly = plot(); let r = SiteStats(G.area(poly))
    for it in items() { if isB(it) { if !noClash(it) { r.built += bArea(it) } } else if eq(it["kind"], "tree") { r.trees += 1 } else { r.addZone(it.s("kind"), it.n("w") * it.n("d")) } }
    r.free = max(r.area - r.built - r.zones.reduce(0) { $0 + $1.1 }, 0)
    let pave = r.zone("path") + r.zone("paving")
    let curb = items().filter { eq($0["kind"], "path") }.reduce(0.0) { $0 + 2 * max($1.n("w"), $1.n("d")) } + items().filter { eq($0["kind"], "paving") }.reduce(0.0) { $0 + 2 * ($1.n("w") + $1.n("d")) }
    r.tiles = pave * 1.05; let pz = SZm("pave"); r.pavePcs = Int(ceil(pave * 1.05 / (pz[0] * pz[1]))); r.curb = curb; r.bSand = pave * 0.05; r.bGravel = pave * 0.1
    r.seed = r.zone("lawn") * 0.04; r.soil = (r.zone("lawn") + r.zone("garden")) * 0.1
    return r
}

// ---------- размеры, нормы, материалы ----------
func SZ(_ k: String) -> [Double] { let p = St.project.oo("sizes"); return (p?.aa(k) ?? D.SZDEF.o(k).a("d")).nums }
func SZm(_ k: String) -> [Double] { SZ(k).map { $0 / 1000 } }
func packSize() -> Double { St.project.oo("sizes").flatMap { $0["lamPack"] }.map { num($0) } ?? D.SZDEF.o("lam").n("pack") }
func RT(_ k: String) -> Double { let p = St.project.oo("rates"); if let v = p?[k] { return num(v) }; return num(D.RDEF.a(k).at(1)) }
/// Материал стен с размерами (MI).
func MI(_ W: Obj?) -> Obj? {
    guard let W = W else { return nil }
    let mat = W.s("mat")
    if mat == "custom" {
        let c = W.oo("cm") ?? Obj(); let nm = c.s("name")
        return obj(("n", arr(nm.isEmpty ? "Свой материал" : nm, nm.isEmpty ? "Custom material" : nm, nm.isEmpty ? "O‘z materiali" : nm)), ("L", c.nz("L", 390) / 1000), ("H", c.nz("H", 190) / 1000),
                   ("j", c.b("glue") ? 0.003 : 0.01), ("glue", c.b("glue") ? 1.0 : 0.0), ("dens", c.nz("dens", 1200)), ("col", "#A8A29E"), ("th", arr(W.n("t"))), ("palM3", 1.5))
    }
    if mat == "brick" {
        let cz = SZm("brick")
        let f: Obj
        if eq(W["bf"], "custom") { let sz = SZ("brick").map { fmt($0, 0) }.joined(separator: "×")
            f = obj(("n", arr("Свой \(sz)", "Custom \(sz)", "O‘z \(sz)")), ("L", cz[0]), ("D", cz[1]), ("H", cz[2]), ("pal", 400.0)) }
        else { f = D.BFMT.oo(W.s("bf")) ?? D.BFMT.o("1NF") }
        let ty = D.BTYPE.oo(W.s("bt")) ?? D.BTYPE.o("ceramFull"); let fn = f.a("n"); let tn = ty.a("n")
        let L = f.n("L"); let Dd = f.n("D")
        let names = (0..<3).map { tn.s($0) + ", " + fn.s($0).lowercased() }
        return obj(("n", Arr(names)), ("L", L), ("H", f.n("H")), ("D", Dd), ("j", 0.01), ("glue", 0.0), ("dens", ty.n("dens")), ("col", ty["col"]), ("pal", f["pal"]), ("gost", ty["g"]),
                   ("th", arr(Dd, L, r3(L + Dd + 0.01), r3(2 * L + 0.01))), ("brick", 1.0))
    }
    guard let m = D.WMAT.oo(mat) else { return nil }
    if D.SZDEF.oo("blk_\(mat)") == nil { return m }
    let z = SZm("blk_\(mat)"); let o = assign(Obj(), m, obj(("L", z[0]), ("H", z[1])))
    var th = (m.aa("th") ?? Arr()).a
    if W.b("tc") && !th.contains(where: { abs(num($0) - W.n("t")) < 1e-6 }) { th.append(W.n("t")) }
    let tha = Arr(); tha.a = th; o["th"] = tha; return o
}
