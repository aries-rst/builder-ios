import SwiftUI

func ltr(_ i: Int) -> String { String(UnicodeScalar(UInt8(65 + i % 26))) }

// ---------- забор ----------
struct FenceScreen: View {
    @ObservedObject var u = UIS.shared
    func nm(_ i: Int, _ n: Int) -> String { "\(ltr(i))–\(ltr((i + 1) % n))" }
    var body: some View {
        let p = St.project; let f = FN(); let r = calcFence(); let poly = plot(); let type = f.s("type"); let heavy = type == "brick" || type == "block"; let m = T("m"); let E = f.a("edges"); let n = poly.count
        Page {
            TopBar(T("mFence"), { go("home") })
            Sec(T("fnPlan")) {
                Drawing(220) { drawFencePlan($0) }; Hint(T("fnSides"), top: 0)
                Chips { ForEach(Array(poly.enumerated()), id: \.offset) { i, a in
                    let on = truthy(E[i]); Chip("\(on ? "✓ " : "")\(nm(i, n)) · \(fmt(G.dist(a, poly[(i + 1) % n]), 1)) \(m)", on) { E[i] = !on } } }
            }
            Sec(T("fnType")) { typeSec(f, type, heavy) }
            if !heavy && type != "concrete" { postSec(f) }
            Sec(T("fnFound")) {
                if heavy { Hint(T("fnStrip") + " — " + T("fnNeeded"), top: 0) }
                else { Chips { ForEach([("none", "fnNone"), ("conc", "fnConc"), ("strip", "fnStrip")], id: \.0) { k, l in Chip(T(l), eq(f["found"], k)) { f["found"] = k } } } }
                if eq(f["found"], "strip") || heavy { HStack(spacing: 6) { NumField(T("fWidth"), f.n("fb")) { f["fb"] = $0 }; NumField(T("fDepth"), f.n("fh")) { f["fh"] = $0 } } }
            }
            Sec(T("fnGates")) { gates(f, p, poly, E, n) }
            Sec(T("fMaterials")) { Stat(T("fnLen"), fmt(r.n("L"), 1) + " " + m, accent: true); Hint(T("fnPriceHint"), top: 0); PricedList(ls: fenceLines(), totalKey: "fnTotal"); Hint(T("fnPriceShared")) }
            RateLink(back: "fence")
        }
    }
    @ViewBuilder func typeSec(_ f: Obj, _ type: String, _ heavy: Bool) -> some View {
        Drawing(150) { drawFenceView($0) }
        Chips { ForEach(Array(D.o("FTYPES").entries.enumerated()), id: \.offset) { _, e in Chip(tr3((e.1 as! Obj)["n"]), type == e.0) { f["type"] = e.0 } } }
        HStack(spacing: 6) {
            NumField(T("fnH"), f.n("h")) { f["h"] = clampD($0, 0.8, 3.5) }
            if !heavy && type != "concrete" { NumField(T("fnStep"), f.n("step")) { f["step"] = clampD($0, 1, 4) } }
        }
        if type == "prof" { Hint(T("fnThick")); Chips { ForEach([0.35, 0.4, 0.45, 0.5], id: \.self) { x in Chip(fmt(x) + " мм", f.n("profT") == x) { f["profT"] = x } } }; NumField(T("ownVal"), f.n("profT")) { f["profT"] = clampD($0, 0.2, 1.5) } }
        if type == "mesh" { Hint(T("fnThick")); Chips { ForEach([2.0, 2.5, 3.0], id: \.self) { x in Chip("Ø\(fmt(x)) мм · 50×50", f.n("mesh") == x) { f["mesh"] = x } } }; NumField(T("ownVal"), f.n("mesh")) { f["mesh"] = clampD($0, 1, 6) } }
        if type == "euro" || type == "board" { NumField(T("fnGap"), f.n("gap"), zero: true) { f["gap"] = clampD($0, 0, 200) } }
        if type == "board" { Hint("📏 \(szj("board")) мм"); OBtn("📏 " + T("szTitle")) { go("sizes", "fence") } }
        if type == "custom" {
            let cu = f.o("cu")
            Divider1(); TextIn(T("fnCuName"), cu.s("name"), placeholder: T("fnCuPh")) { cu["name"] = $0 }
            Hint(T("fnCuUnit")); Chips { ForEach([("pcs", "fnUPcs"), ("m2", "fnUM2"), ("m", "fnUM")], id: \.0) { k, l in Chip(T(l), eq(cu["unit"], k)) { cu["unit"] = k } } }
            if eq(cu["unit"], "pcs") {
                HStack(spacing: 6) { NumField(T("fnCuW"), cu.n("w")) { cu["w"] = $0 }; NumField(T("fnCuH"), cu.n("h")) { cu["h"] = $0 } }
                HStack(spacing: 6) { NumField(T("fnCuT"), cu.n("th")) { cu["th"] = $0 }; NumField(T("fnGap"), cu.n("gap"), zero: true) { cu["gap"] = $0 } }
            }
            Chips { Check(T("fnRails") + " 40×20", cu.b("rails")) { cu["rails"] = $0 } }
        }
        if type == "brick" { Hint(T("fnThick")); Chips { ForEach([(0.12, "½"), (0.25, "1")], id: \.0) { x, l in Chip("\(fmt(x * 100)) см (\(l) \(T("wBricks")))", f.n("brickT") == x) { f["brickT"] = x } } } }
        if D.o("FTYPES").o(type).b("col") || type == "board" {
            Hint(T("fnColor")); Chips { ForEach(Array(D.o("FCOLS").entries.enumerated()), id: \.offset) { _, e in ColorChip(hexColor(e.1 as? String), eq(f["color"], e.0), w: 36) { f["color"] = e.0 } } }
        }
    }
    @ViewBuilder func postSec(_ f: Obj) -> some View {
        Sec(T("fnPost")) {
            Chips {
                ForEach(Array(D.o("FPOSTS").entries.enumerated()), id: \.offset) { _, e in Chip(tr3(e.1), eq(f["post"], e.0) && !f.b("cols")) { f["post"] = e.0; f["cols"] = false } }
                Chip("🧱 " + T("fnCols"), f.b("cols")) { f["cols"] = !f.b("cols") }
            }
            if eq(f["post"], "custom") && !f.b("cols") {
                let cp = f.o("cp")
                HStack(spacing: 6) { TextIn(T("fnCuName"), cp.s("name"), placeholder: T("fnCpPh")) { cp["name"] = $0 }; TextIn(T("fnCpSize"), cp.s("size")) { cp["size"] = $0 } }
            }
        }
    }
    @ViewBuilder func gates(_ f: Obj, _ p: Obj, _ poly: [Pt], _ E: Arr, _ n: Int) -> some View {
        let its = f.a("items")
        ForEach(Array(its.objs.enumerated()), id: \.offset) { i, o in
            let gate = eq(o["k"], "gate"); let custom = eq(o["mode"], "custom")
            Divider1()
            HStack { Txt(gate ? "🚪 " + T("fnGate") : "🚶 " + T("fnWicket"), 15, bold: true).frame(maxWidth: .infinity, alignment: .leading); IconBtn("✕", C.warn) { its.a.remove(at: i); upd() } }
            if gate { Chips { Chip(T("fnSwing"), !eq(o["kind"], "slide")) { o["kind"] = "swing" }; Chip(T("fnSlide"), eq(o["kind"], "slide")) { o["kind"] = "slide" } } }
            Chips { Chip(T("fnSameMat"), !custom) { o["mode"] = "same" }; Chip(T("fnReady"), custom) { o["mode"] = "custom" } }
            if custom {
                TextIn(T("fnCuName"), o.s("cname"), placeholder: T(gate ? "fnGatePh" : "fnWicketPh")) { o["cname"] = $0 }
                NumField(T("fnPriceFor") + " " + T("uPcs") + ", " + St.cur, num(p.o("prices")["gitem_" + o.s("uid")]), zero: true) { p.o("prices")["gitem_" + o.s("uid")] = $0 }
            }
            Chips { ForEach(poly.indices.filter { truthy(E[$0]) }, id: \.self) { j in Chip(nm(j, n), Int(num(o["edge"])) == j) { o["edge"] = Double(j) } } }
            HStack(spacing: 6) { NumField(T("sWidth"), o.n("w")) { o["w"] = $0 }; NumField(T("fnPos"), o.n("pos"), zero: true) { o["pos"] = $0 } }
        }
        let e0 = poly.indices.first { truthy(E[$0]) } ?? 0
        HStack(spacing: 6) {
            OBtn(T("fnAddGate")) { its.add(obj(("k", "gate"), ("kind", "swing"), ("edge", Double(e0)), ("pos", 1.0), ("w", 3.5), ("uid", newUid()))); upd() }
            OBtn(T("fnAddWicket")) { its.add(obj(("k", "wicket"), ("edge", Double(e0)), ("pos", 1.0), ("w", 1.0), ("uid", newUid()))); upd() }
        }
    }
}

struct SoonScreen: View { let title: String; var body: some View { VStack(spacing: 0) { TopBar(title, { go("home") }); Centered { Txt("🚧", 64); Txt(T("soonText"), 16, align: .center) } } } }
func gLocal(_ p: Pt, _ poly: [Pt]) -> Pt {
    let a = poly[0], b = poly[1]; let len = max(G.dist(a, b), 1e-9); let ux = (b[0] - a[0]) / len, uy = (b[1] - a[1]) / len
    let (vx, vy): (Double, Double) = G.sarea(poly) >= 0 ? (-uy, ux) : (uy, -ux); let rx = p[0] - a[0], ry = p[1] - a[1]; return pt(rx * ux + ry * uy, rx * vx + ry * vy)
}
func rectDist(_ a: Obj, _ b: Obj) -> Double { if rectsOverlap(a, b) { return 0 }; let A = G.corners(a), B = G.corners(b); return min(G.minPE(A, B), G.minPE(B, A)) }
struct StakingScreen: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let b = curB(); let poly = plot(); let cs = G.corners(b); let bs = buildings(); let m = T("m")
        Page {
            TopBar(T("stakingTitle"), { go("plot") }); BSelector()
            Canvas { c, size in drawPlot(DC(c, size), edit: false, only: b.n("id")) }.frame(height: 360).padding(.horizontal, 8)
            Sec(itemName(b)) {
                Hint(T("refNote"), top: 0)
                ForEach(Array(cs.enumerated()), id: \.offset) { i, c in let l = gLocal(c, poly); Stat("\(T("corner")) \(i + 1)", "\(T("along")) \(fmt(l[0])) \(m) · \(T("inward")) \(fmt(l[1])) \(m)", accent: l[0] < 0 || l[1] < 0) }
            }
            Sec(T("sides")) {
                if isShaped(b) {
                    ForEach(Array(cs.enumerated()), id: \.offset) { i, q in Stat("\(i + 1)–\((i + 1) % cs.count + 1)", fmt(G.dist(q, cs[(i + 1) % cs.count])) + " " + m) }
                    Hint(T("shpDiag"))
                } else {
                    Stat("1–2 · 3–4", fmt(b.n("w")) + " " + m); Stat("2–3 · 4–1", fmt(b.n("d")) + " " + m); Stat(T("diagonal") + " 1–3 · 2–4", fmt(hypot(b.n("w"), b.n("d"))) + " " + m, accent: true); Hint(T("diagNote"))
                }
            }
            if bs.count > 1 { Sec(T("sDistTitle")) { ForEach(distPairs(bs), id: \.0) { k, i, j in Stat("\(itemName(bs[i])) ↔ \(itemName(bs[j]))", fmt(rectDist(bs[i], bs[j]), 2) + " " + m, accent: rectsOverlap(bs[i], bs[j])) } } }
            Sec(T("rule345")) { Txt(T("rule345Text"), 14) }
            Sec(T("steps")) { ForEach(Array(["step1", "step2", "step3", "step4"].enumerated()), id: \.offset) { i, k in Txt("\(i + 1). \(T(k))", 14).padding(.vertical, 4) } }
        }
    }
    func distPairs(_ bs: [Obj]) -> [(Int, Int, Int)] { var r: [(Int, Int, Int)] = []; var k = 0; for i in bs.indices { for j in (i + 1)..<max(bs.count, i + 1) { r.append((k, i, j)); k += 1 } }; return r }
}
