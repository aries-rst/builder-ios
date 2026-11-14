import Foundation

func TPL() -> [Arr] { D.a("TPL").compactMap { $0 as? Arr } }
func tplBuild(_ T: Arr) -> Obj {
    let id = T.s(0); let W = T.n(2); let Dd = T.n(3); let p = blankProject()
    let sb: [String: Double] = ["city2": 1.0, "narrow": 1.5, "covered": 1.0]
    assign(p, obj(("plotW", W), ("plotD", Dd), ("points", toArr(rect(W, Dd))), ("fresh", false), ("tpl", id), ("setback", sb[id] ?? 3.0)))
    for e0 in (T.arr(4)?.a ?? []) { guard let e = e0 as? Arr else { continue }
        let kind = e.s(0); let o = (e.at(5) as? Obj) ?? obj(); let z = kind.hasPrefix("z:"); let k = z ? String(kind.dropFirst(2)) : kind
        let it = newItem(p, z ? "z" : "b", k, e.n(1), e.n(2)); it["w"] = e.n(3); it["d"] = e.n(4)
        if !z {
            if truthy(o["fl"]) { it["floors"] = num(o["fl"]) }; if truthy(o["roof"]) { it["roof"] = o["roof"] }; if truthy(o["mat"]) { it.o("walls")["mat"] = o["mat"] }; if truthy(o["wt"]) { it.o("walls")["t"] = num(o["wt"]) }
            if truthy(o["fd"]) { it.o("f")["type"] = o["fd"] }; if truthy(o["gh"]) { it["gh"] = o["gh"]; if eq(o["gh"], "lean") { it["roof"] = "SHED" } }
            if truthy(o["rf"]) { it["rf"] = assign(RF(it), obj(("angle", num(o["rf"])))) }; if truthy(o["sh"]) { it["shape"] = obj(("type", o["sh"]), ("a", o["a"])) }
            if truthy(o["pts"]) { it["shape"] = obj(("type", "poly"), ("pts", deep(o["pts"]))); syncPoly(it) }
            it["basement"] = obj(("on", truthy(o["base"])), ("h", truthy(o["base"]) ? num(o["base"]) : 2.4)); it["attic"] = obj(("on", o["att"] == nil || num(o["att"]) != 0))
            if truthy(o["lag"]) { it["fin"] = assign(obj(), it.oo("fin"), obj(("base", "joist"))) }
            if truthy(o["name"]) { if let a = o["name"] as? Arr { it["name"] = tr3(a) } else { it["name"] = o["name"] } }
            if truthy(o["cover"]) { it["shape"] = obj(("type", "poly"), ("full", true), ("pts", toArr(rect(W, Dd)))); it["roof"] = "FLAT"
                let mx = (p.a("items").objs.filter { eq($0["cat"], "b") }.map { $0.n("floors") * $0.n("floorH") + roofRise($0) }.max() ?? 0) + 0.5
                it["floorH"] = (mx * 10).rounded(.toNearestOrAwayFromZero) / 10 }
            if D.KINDS.o(k)["ops"] == nil { it.o("walls")["openings"] = autoOpenings(it) }
        }
        p.a("items").add(it) }
    let h = p.a("items").objs.first(where: { eq($0["cat"], "b") }); p["sel"] = h?["id"]; p["bSel"] = h?["id"]; return p
}
struct TplInfo { var p: Obj; var h: Obj?; var sot: Double; var fl: Double; var att: Bool; var base: Bool; var shape: Bool; var others: [Obj] }
func tplInfo(_ T: Arr) -> TplInfo {
    let p = tplBuild(T); let W = T.n(2); let Dd = T.n(3); let its = p.a("items").objs
    let h = its.first(where: { eq($0["kind"], "house") }) ?? its.first(where: { eq($0["cat"], "b") })
    return TplInfo(p: p, h: h, sot: W * Dd / 100, fl: h?.n("floors") ?? 0,
                   att: h != nil && hasAttic(h!) && h!.o("attic").b("on") && !(isShaped(h) && wings(h!) == nil) && eq(h!["kind"], "house"),
                   base: h != nil && h!.o("basement").b("on"), shape: h != nil && isShaped(h) && h!.oo("shape")?.b("full") != true,
                   others: its.filter { eq($0["cat"], "b") && $0 !== h })
}
func tplPass(_ f: String, _ I: TplInfo) -> Bool {
    f == "all" || (f == "s" && I.sot < 5) || (f == "m" && I.sot >= 5 && I.sot <= 10) || (f == "l" && I.sot > 10) || (f == "fl2" && I.fl >= 2) || (f == "att" && I.att) || (f == "base" && I.base) || (f == "shape" && I.shape)
}
