import Foundation

// Динамическая модель данных, совместимая с JSON прототипа (проекты переносятся 1:1).
// Obj/Arr — ссылочные типы (как MutableMap/MutableList в Kotlin), чтобы изменения «вживую» видели все владельцы.

struct Pt { var x: Double; var y: Double
    init(_ x: Double, _ y: Double) { self.x = x; self.y = y }
    subscript(i: Int) -> Double { get { i == 0 ? x : y } set { if i == 0 { x = newValue } else { y = newValue } } }
}
func pt(_ x: Double, _ y: Double) -> Pt { Pt(x, y) }

final class Obj {
    var d: [String: Any] = [:]
    var keys: [String] = []   // порядок вставки
    init() {}
    init(_ pairs: [(String, Any?)]) { for (k, v) in pairs { self[k] = v } }
    subscript(_ k: String) -> Any? {
        get { d[k] }
        set { if let v = newValue { if d[k] == nil { keys.append(k) }; d[k] = v } else if d[k] != nil { d.removeValue(forKey: k); keys.removeAll { $0 == k } } }
    }
    func has(_ k: String) -> Bool { d[k] != nil }
    var entries: [(String, Any)] { keys.compactMap { k in d[k].map { (k, $0) } } }
    // типизированные доступы
    func n(_ k: String, _ def: Double = 0) -> Double { num(d[k], def) }
    /// число, где 0/пусто = «не задано» (JS: x||def)
    func nz(_ k: String, _ def: Double) -> Double { let v = num(d[k], 0); return v == 0 ? def : v }
    func s(_ k: String, _ def: String = "") -> String { if let v = d[k] { if let s = v as? String { return s }; if let n = v as? Double { return fmt(n) }; return "\(v)" }; return def }
    func b(_ k: String) -> Bool { truthy(d[k]) }
    func o(_ k: String) -> Obj { if let v = d[k] as? Obj { return v }; let v = Obj(); self[k] = v; return v }
    func oo(_ k: String) -> Obj? { d[k] as? Obj }
    func a(_ k: String) -> Arr { if let v = d[k] as? Arr { return v }; let v = Arr(); self[k] = v; return v }
    func aa(_ k: String) -> Arr? { d[k] as? Arr }
    func str(_ k: String) -> String? { d[k] as? String }
    func deepCopy() -> Obj { deep(self) as! Obj }
}

final class Arr: Sequence {
    var a: [Any] = []
    init() {}
    init(_ v: [Any?]) { a = v.map { $0 ?? NSNull() } }
    var count: Int { a.count }
    var isEmpty: Bool { a.isEmpty }
    subscript(_ i: Int) -> Any { get { a[i] } set { a[i] = newValue } }
    func at(_ i: Int) -> Any? { i >= 0 && i < a.count ? (a[i] is NSNull ? nil : a[i]) : nil }
    func add(_ v: Any?) { a.append(v ?? NSNull()) }
    func add(_ v: Any?, at i: Int) { a.insert(v ?? NSNull(), at: Swift.min(i, a.count)) }
    func removeAll(where f: (Any) -> Bool) { a.removeAll(where: f) }
    func makeIterator() -> IndexingIterator<[Any]> { a.makeIterator() }
    var objs: [Obj] { a.compactMap { $0 as? Obj } }
    var nums: [Double] { a.map { num($0) } }
    func n(_ i: Int, _ def: Double = 0) -> Double { num(at(i), def) }
    func s(_ i: Int) -> String { (at(i) as? String) ?? "" }
    func arr(_ i: Int) -> Arr? { at(i) as? Arr }
}
func arr(_ v: Any?...) -> Arr { Arr(v) }
func obj(_ p: (String, Any?)...) -> Obj { Obj(p) }

/// JS-подобное приведение к числу.
func num(_ v: Any?, _ def: Double = 0) -> Double {
    guard let v = v else { return def }
    if let d = v as? Double { return d.isNaN ? def : d }
    if let i = v as? Int { return Double(i) }
    if let b = v as? Bool { return b ? 1 : 0 }
    if let s = v as? String { return Double(s.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)) ?? def }
    return def
}
/// JS truthiness.
func truthy(_ v: Any?) -> Bool {
    guard let v = v else { return false }
    if v is NSNull { return false }
    if let b = v as? Bool { return b }
    if let d = v as? Double { return d != 0 && !d.isNaN }
    if let i = v as? Int { return i != 0 }
    if let s = v as? String { return !s.isEmpty }
    return true
}
func eq(_ v: Any?, _ s: String) -> Bool { (v as? String) == s }
func asObj(_ v: Any?) -> Obj? { v as? Obj }
func asArr(_ v: Any?) -> Arr? { v as? Arr }
/// список точек [[x,y],...]
func pts(_ v: Any?) -> [Pt] { (asArr(v)?.a ?? []).compactMap { q in (q as? Arr).map { pt($0.n(0), $0.n(1)) } } }
func toArr(_ p: [Pt]) -> Arr { Arr(p.map { Arr([$0.x, $0.y]) }) }

/// Глубокая копия (аналог JSON.parse(JSON.stringify(x))).
func deep(_ v: Any?) -> Any? {
    if let o = v as? Obj { let m = Obj(); for (k, x) in o.entries { m[k] = deep(x) }; return m }
    if let a = v as? Arr { let r = Arr(); r.a = a.a.map { deep($0) ?? NSNull() }; return r }
    return v
}
/// Object.assign(target, ...src)
@discardableResult func assign(_ t: Obj, _ src: Obj?...) -> Obj { for s in src { if let s = s { for (k, v) in s.entries { t[k] = v } } }; return t }
/// Дописывает недостающие ключи из d в существующий объект, не заменяя его.
@discardableResult func keep(_ owner: Obj, _ key: String, _ d: Obj) -> Obj {
    guard let cur = owner.oo(key) else { owner[key] = d; return d }
    for (k, v) in d.entries where !cur.has(k) { cur[k] = v }; return cur
}

/// Точное десятичное округление «половина вверх» (как BigDecimal(v).setScale(d, HALF_UP)): "123.40" с d знаками.
func hup(_ v: Double, _ d: Int) -> String {
    let neg = v < 0; let full = String(format: "%.40f", abs(v))
    let parts = full.split(separator: ".", omittingEmptySubsequences: false); let ip = String(parts[0]); let fp = Array(parts.count > 1 ? parts[1] : "")
    var digits = Array(ip) + Array(fp.prefix(d)); let up = fp.count > d && fp[d] >= "5"
    if up { var i = digits.count - 1; while i >= 0 { if digits[i] == "9" { digits[i] = "0"; i -= 1 } else { digits[i] = Character(UnicodeScalar(digits[i].asciiValue! + 1)); break } }; if i < 0 { digits.insert("1", at: 0) } }
    let ilen = digits.count - d; var out = String(digits[0..<ilen]); if d > 0 { out += "." + String(digits[ilen...]) }
    if neg && out.contains(where: { $0 != "0" && $0 != "." }) { out = "-" + out }
    return out
}
/// Формат числа как в Android: BigDecimal HALF_UP, без лишних нулей.
func fmt(_ v: Double, _ d: Int = 2) -> String {
    if v.isNaN || v.isInfinite { return "0" }
    var s = hup(v, d)
    if s.contains(".") { while s.hasSuffix("0") { s.removeLast() }; if s.hasSuffix(".") { s.removeLast() } }
    return s
}
func hypot2(_ x: Double, _ y: Double) -> Double { (x * x + y * y).squareRoot() }
func rnd(_ v: Double, _ d: Int) -> Double { guard v.isFinite else { return v }; return Double(hup(v, d)) ?? v }
func r2(_ v: Double) -> Double { rnd(v, 2) }
func r3(_ v: Double) -> Double { rnd(v, 3) }

// ---------------- JSON ----------------
enum Json {
    static func parse(_ data: Data) -> Any? { var p = Parser(Array(data)); return p.value() }
    static func parse(_ s: String) -> Any? { parse(Data(s.utf8)) }
    private struct Parser {
        let b: [UInt8]; var i = 0
        init(_ b: [UInt8]) { self.b = b }
        mutating func ws() { while i < b.count, b[i] == 32 || b[i] == 10 || b[i] == 13 || b[i] == 9 { i += 1 } }
        mutating func value() -> Any? {
            ws(); guard i < b.count else { return nil }
            switch b[i] {
            case UInt8(ascii: "{"):
                i += 1; let m = Obj(); ws(); if b[i] == UInt8(ascii: "}") { i += 1; return m }
                while true { ws(); let k = str(); ws(); i += 1; m[k] = value(); ws(); if b[i] == UInt8(ascii: ",") { i += 1; continue }; i += 1; break }
                return m
            case UInt8(ascii: "["):
                i += 1; let l = Arr(); ws(); if b[i] == UInt8(ascii: "]") { i += 1; return l }
                while true { l.add(value()); ws(); if b[i] == UInt8(ascii: ",") { i += 1; continue }; i += 1; break }
                return l
            case UInt8(ascii: "\""): return str()
            case UInt8(ascii: "t"): i += 4; return true
            case UInt8(ascii: "f"): i += 5; return false
            case UInt8(ascii: "n"): i += 4; return nil
            default:
                let st = i; while i < b.count, (b[i] >= 48 && b[i] <= 57) || b[i] == 45 || b[i] == 43 || b[i] == 46 || b[i] == 101 || b[i] == 69 { i += 1 }
                return Double(String(decoding: b[st..<i], as: UTF8.self)) ?? 0
            }
        }
        mutating func str() -> String {
            i += 1; var out = [UInt8](); var units = [UInt16]()
            func flush(_ out: inout [UInt8], _ units: inout [UInt16]) { if !units.isEmpty { out += Array(String(decoding: units, as: UTF16.self).utf8); units.removeAll() } }
            while true {
                let c = b[i]; i += 1
                if c == UInt8(ascii: "\"") { flush(&out, &units); return String(decoding: out, as: UTF8.self) }
                if c == UInt8(ascii: "\\") {
                    let e = b[i]; i += 1
                    switch e {
                    case UInt8(ascii: "n"): flush(&out, &units); out.append(10)
                    case UInt8(ascii: "t"): flush(&out, &units); out.append(9)
                    case UInt8(ascii: "r"): flush(&out, &units); out.append(13)
                    case UInt8(ascii: "b"): flush(&out, &units); out.append(8)
                    case UInt8(ascii: "f"): flush(&out, &units); out.append(12)
                    case UInt8(ascii: "u"): units.append(UInt16(String(decoding: b[i..<i+4], as: UTF8.self), radix: 16) ?? 63); i += 4
                    default: flush(&out, &units); out.append(e)
                    }
                } else { flush(&out, &units); out.append(c) }
            }
        }
    }
    static func str(_ v: Any?) -> String { var s = ""; w(&s, v); return s }
    private static func w(_ b: inout String, _ v: Any?) {
        guard let v = v, !(v is NSNull) else { b += "null"; return }
        if let x = v as? Bool { b += x ? "true" : "false" }
        else if let d = v as? Double { if d.isNaN || d.isInfinite { b += "null" } else if d == d.rounded() && abs(d) < 1e15 { b += String(Int64(d)) } else { b += "\(d)" } }
        else if let i = v as? Int { b += String(i) }
        else if let s = v as? String { b += "\""; for c in s.unicodeScalars { switch c { case "\"": b += "\\\""; case "\\": b += "\\\\"; case "\n": b += "\\n"; case "\r": b += "\\r"; case "\t": b += "\\t"
            default: if c.value < 32 { b += String(format: "\\u%04x", c.value) } else { b.unicodeScalars.append(c) } } }; b += "\"" }
        else if let o = v as? Obj { b += "{"; var f = true; for (k, x) in o.entries { if !f { b += "," }; f = false; w(&b, k); b += ":"; w(&b, x) }; b += "}" }
        else if let a = v as? Arr { b += "["; for (j, x) in a.a.enumerated() { if j > 0 { b += "," }; w(&b, x) }; b += "]" }
        else if let p = v as? [Pt] { w(&b, toArr(p)) }
        else { w(&b, "\(v)") }
    }
}
