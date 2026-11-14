import SwiftUI

// ---------- участок ----------
struct PlotCanvas: View {
    @ObservedObject var fr = Frame.shared
    @ObservedObject var u = UIS.shared
    @State private var touch = PlotTouch()
    var body: some View {
        GeometryReader { g in
            let _ = { touch.W = Double(g.size.width); touch.H = Double(g.size.height) }()
            ZStack(alignment: .topTrailing) {
                let _ = fr.n
                Canvas { c, size in drawPlot(DC(c, size), edit: true) }
                Gestures(onDown: { touch.down($0) }, onMove: { touch.move($0, $1) }, onZoom: { touch.zoom($0, $1) }, onUp: { touch.up() })
                VStack(spacing: 6) {
                    zoomBtn("+", "tpZin") { PV.z = min(PV.z * 1.5, 30) }
                    zoomBtn("−", "tpZout") { PV.z = max(PV.z / 1.5, 0.5) }
                    zoomBtn("⤢", "tpZfit") { PV.z = 1; PV.ox = 0; PV.oy = 0 }
                    zoomBtn(PV.del ? "✓" : "🗑", "tpDelMode") { PV.del = !PV.del; PV.delSet.removeAll(); PV.draw = nil; UI.tick += 1 }
                }.padding(8)
            }
        }.frame(height: 400).background(C.field).cornerRadius(12).clipped().padding(.horizontal, 8)
    }
    func zoomBtn(_ l: String, _ tip: String, _ f: @escaping () -> Void) -> some View {
        Txt(l, 20, C.accent, bold: true).frame(width: 40, height: 40).background(C.bg.opacity(0.8)).cornerRadius(20).contentShape(Circle())
            .onTapGesture { f(); Frame.bump() }.onLongPressGesture(minimumDuration: 0.5) { toast(T(tip)) }
    }
}
private func afterResize(_ b: Obj) { if manOuter(b).isEmpty { b.o("walls")["openings"] = autoOpenings(b) }; planChanged(b) }
func removeSel(_ p: Obj) {
    if !items().contains(where: { num($0["id"]) == num(p["sel"]) }) { p["sel"] = items().first?["id"] }
    if !buildings().contains(where: { num($0["id"]) == num(p["bSel"]) }) { p["bSel"] = buildings().first?["id"] }
}
func addItem(_ cat: String, _ kind: String) {
    let p = St.project; let poly = plot(); let c = G.centroid(poly); let it = newItem(p, cat, kind, c[0], c[1]); let others = items().filter { !eq($0["kind"], "tree") }
    func ok() -> Bool { (isB(it) ? G.fits(it, poly, setbackOf(it)) : G.corners(it).allSatisfy { G.inside($0, poly) }) && !others.contains(where: { rectsOverlap(it, $0) }) }
    if !ok() {
        let st = max(1, min(it.n("w"), it.n("d")) / 2); var found = false
        search: for r in 1..<40 { for a in 0..<(8 * r) {
            let ang = Double(a) / Double(8 * r) * 2 * Double.pi; it["cx"] = c[0] + cos(ang) * Double(r) * st; it["cy"] = c[1] + sin(ang) * Double(r) * st; if ok() { found = true; break search } } }
        if !found { it["cx"] = c[0]; it["cy"] = c[1] }
    }
    it["cx"] = r2(it.n("cx")); it["cy"] = r2(it.n("cy")); p.a("items").add(it); selectItem(it["id"]); upd()
}
struct PlotScreen: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let p = St.project; let its = items(); let sel = selItem(); let poly = plot()
        Page {
            TopBar(T("plotTitle"), { go("home") })
            PlotCanvas()
            if PV.del { delSec(p) }
            if let P = PV.draw { drawSec(P) }
            HintOut(T("sTapHint") + " " + T("sZoomHint"))
            if its.isEmpty { Sec("👋 " + T("startTitle"), border: true) { Txt(T("stText"), 14) } }
            Sec(T("sAdd")) {
                Hint(T("sBuildings"), top: 0)
                Chips { ForEach(Array(D.KINDS.entries.enumerated()), id: \.offset) { _, e in let v = e.1 as! Obj; Chip("\(v.s("e")) \(tr3(v["n"]))", false) { addItem("b", e.0) } } }
                Hint(T("sLandscape"))
                Chips { ForEach(Array(D.ZONES.entries.enumerated()), id: \.offset) { _, e in let v = e.1 as! Obj; Chip("\(v.s("e")) \(tr3(v["n"]))", false) { addItem("z", e.0) } } }
                OBtn("✏️ " + T("drNew")) { PV.draw = []; PV.drawTarget = nil; UI.tick += 1 }
            }
            if let sel = sel { selectedSec(p, sel, poly) }
            Sec(T("sObjects")) { Chips { ForEach(Array(its.enumerated()), id: \.offset) { _, x in Chip(itemName(x), x === sel) { selectItem(x["id"]) } } } }
            resultsSec(poly)
            siteMaterials()
            Sec(T("plotTitle")) { plotParams(p, poly) }
            Btn(T("toStaking")) { go("staking") }; Btn(T("to3d"), false) { go("view3d") }
        }
    }
    @ViewBuilder func delSec(_ p: Obj) -> some View {
        Sec(border: true) {
            Txt("🗑 " + T("dlHint"), 14)
            HStack(spacing: 6) {
                if !PV.delSet.isEmpty {
                    OBtn("\(T("dlDo")) (\(PV.delSet.count))", C.warn) {
                        p["items"] = Arr(items().filter { !PV.delSet.contains($0.n("id")) }.map { $0 as Any? }); PV.del = false; PV.delSet.removeAll(); removeSel(p); upd()
                    }
                }
                OBtn(T("dlCancel")) { PV.del = false; PV.delSet.removeAll(); UI.tick += 1 }
            }
        }
    }
    @ViewBuilder func drawSec(_ P: [Pt]) -> some View {
        Sec(border: true) {
            Txt("✏️ \(T("drHint")) · \(T("drPts")): \(P.count)", 14)
            HStack(spacing: 6) {
                if !P.isEmpty { OBtn("↶ " + T("drUndo")) { PV.draw?.removeLast(); UI.tick += 1 } }
                if P.count >= 3 { OBtn("✓ " + T("drDone")) { drawFinish() } }
                OBtn(T("dlCancel")) { PV.draw = nil; UI.tick += 1 }
            }
        }
    }
    @ViewBuilder func selectedSec(_ p: Obj, _ sel: Obj, _ poly: [Pt]) -> some View {
        let b = isB(sel); let k = kindOf(sel) ?? obj()
        Sec("\(T("sSelected")): \(itemName(sel))") {
            TextIn(T("sName"), sel.s("name"), placeholder: tr3(k["n"])) { sel["name"] = $0 }
            if b {
                Hint(T("sIcon"))
                Chips { ForEach(([k.s("e")] + D.a("EMOJIS").map { "\($0)" }.filter { $0 != k.s("e") }), id: \.self) { e in Chip(e, (sel["emoji"] as? String ?? k.s("e")) == e) { sel["emoji"] = e } } }
            }
            if eq(sel["kind"], "tree") { NumField(T("sDiam"), sel.n("w")) { sel["w"] = $0; sel["d"] = $0 } }
            else { HStack(spacing: 6) { NumField(T("sWidth"), sel.n("w")) { sel["w"] = $0; if b { afterResize(sel) } }; NumField(T("sLength"), sel.n("d")) { sel["d"] = $0; if b { afterResize(sel) } } } }
            if b && !eq(sel["kind"], "greenhouse") { shapeSec(sel) }
            if b {
                HStack(spacing: 6) {
                    NumField(T("floors"), sel.n("floors")) { sel["floors"] = clampD($0, 1, 5).rounded(.toNearestOrAwayFromZero); afterResize(sel) }
                    NumField(T("floorH"), sel.n("floorH")) { sel["floorH"] = clampD($0, 2, 6) }
                }
                Chips { ForEach([("GABLE", "roofGable"), ("SHED", "roofShed"), ("HIP", "roofHip"), ("MANSARD", "roofMans"), ("FLAT", "roofFlat")], id: \.0) { k2, l2 in
                    Chip(T(l2), eq(sel["roof"], k2)) { sel["roof"] = k2; if k2 == "SHED" && RF(sel).n("angle") > 20 { sel.o("rf")["angle"] = 12.0 } } } }
            }
            if !eq(sel["kind"], "tree") {
                HStack {
                    Txt("\(T("rotation")): \(fmt(sel.n("rot"), 0))°", 14).frame(maxWidth: .infinity, alignment: .leading)
                    OBtn("↺ 15°") { sel["rot"] = ((sel.n("rot") - 15).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360); upd() }
                    OBtn("↻ 15°") { sel["rot"] = ((sel.n("rot") + 15).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360); upd() }
                }
            }
            HStack(spacing: 6) {
                OBtn("⧉ " + T("sDup")) { let c = deep(sel) as! Obj; let id = p.n("nextId", 1); p["nextId"] = id + 1; c["id"] = id; c["cx"] = sel.n("cx") + 1; c["cy"] = sel.n("cy") - 1; c["calc"] = nil; p.a("items").add(c); selectItem(id); upd() }
                OBtn("⊕ " + T("center")) { let c = G.centroid(poly); sel["cx"] = r2(c[0]); sel["cy"] = r2(c[1]); upd() }
                OBtn("✕ " + T("sDel"), C.warn) { p.a("items").removeAll { ($0 as? Obj) === sel }; removeSel(p); upd() }
            }
        }
    }
    @ViewBuilder func shapeSec(_ sel: Obj) -> some View {
        let st = sel.oo("shape")?.s("type").isEmpty == false ? sel.oo("shape")!.s("type") : "rect"; let en = li() == 1
        Hint(T("shpTitle"))
        Chips { ForEach([("rect", "▭ " + T("shpRect")), ("L", en ? "L" : "Г"), ("U", en ? "U" : "П"), ("T", en ? "T" : "Т"), ("poly", "✏️ " + T("shpPoly"))], id: \.0) { kk, l in Chip(l, st == kk) { setShape(sel, kk) } } }
        if ["L", "U", "T"].contains(st) {
            NumField(T("shpWing"), sel.o("shape").nz("a", r2(min(sel.n("w"), sel.n("d")) * 0.45))) { sel.o("shape")["a"] = $0; sel["rooms"] = arr(); afterResize(sel) }
        }
        if st == "poly" {
            Hint(T("shpPts")); let P = sel.o("shape").a("pts")
            ForEach(Array(P.a.enumerated()), id: \.offset) { i, q0 in
                let q = q0 as! Arr
                HStack(alignment: .bottom, spacing: 4) {
                    Txt(ltr(i), 15, bold: true).frame(width: 24, alignment: .leading).padding(.bottom, 12)
                    NumField("X, " + T("m"), num(q[0]), zero: true) { q[0] = $0; syncPoly(sel) }; NumField("Y, " + T("m"), num(q[1]), zero: true) { q[1] = $0; syncPoly(sel) }
                    IconBtn("✕", C.warn) { if P.count > 3 { P.a.remove(at: i); syncPoly(sel); upd() } }
                }
            }
            HStack(spacing: 6) {
                OBtn(T("addPoint")) { let a = P.a.last as! Arr, c = P.a.first as! Arr; P.add(arr(r2((num(a[0]) + num(c[0])) / 2), r2((num(a[1]) + num(c[1])) / 2))); syncPoly(sel); upd() }
                OBtn("✏️ " + T("drRedraw")) { PV.draw = []; PV.drawTarget = sel.n("id"); UI.tick += 1 }
            }
        }
        if eq(sel.o("walls")["mat"], "open") { OBtn("⤢ " + T("shpCover")) { coverPlot(sel); upd() } }
    }
    @ViewBuilder func resultsSec(_ poly: [Pt]) -> some View {
        let ss = siteStats(); let probs = siteProblems(); let m2 = T("m2")
        Sec(T("results")) {
            Stat(T("plotArea"), "\(fmt(ss.area, 1)) \(m2)" + (["ru", "uz", "uzc", "kk"].contains(St.lang) ? " · \(sotStr(ss.area / 100, 2, false))" : "")); Stat(T("perimeter"), fmt(G.perim(poly), 1) + " " + T("m"))
            Stat(T("sBuilt"), "\(fmt(ss.built, 1)) \(m2) (\(fmt(ss.area > 0 ? ss.built / ss.area * 100 : 0, 1)) %)")
            ForEach(Array(ss.zones.enumerated()), id: \.offset) { _, kv in let z = D.ZONES.o(kv.0); Stat(z.s("e") + " " + tr3(z["n"]), fmt(kv.1, 1) + " " + m2) }
            if ss.trees > 0 { Stat(D.ZONES.o("tree").s("e") + " " + T("sTrees"), "\(ss.trees) \(T("uPcs"))") }
            Stat(T("sFree"), fmt(ss.free, 1) + " " + m2)
            if probs.isEmpty { Hint("✅ " + T("sAllOk"), C.ok) } else { ForEach(Array(probs.enumerated()), id: \.offset) { _, s in Hint("⚠️ " + s, C.warn) } }
        }
    }
    @ViewBuilder func siteMaterials() -> some View {
        let ss = siteStats(); let m3 = T("uM3")
        if ss.tiles > 0 || ss.seed > 0 || ss.soil > 0 {
            Sec(T("sLandscape") + ": " + T("fMaterials").lowercased()) {
                if ss.tiles > 0 {
                    Stat(T("sTiles"), "\(fmt(ss.tiles, 1)) \(T("m2")) · \(ss.pavePcs) \(T("uPcs")) \(szj("pave"))"); Stat(T("sCurb"), fmt(ss.curb, 1) + " " + T("m"))
                    Stat(T("sBaseSand"), fmt(ss.bSand, 2) + " " + m3); Stat(T("sBaseGravel"), fmt(ss.bGravel, 2) + " " + m3)
                }
                if ss.seed > 0 { Stat(T("sSeed"), fmt(ss.seed, 1) + " " + T("uKg")) }
                if ss.soil > 0 { Stat(T("sSoil"), fmt(ss.soil, 1) + " " + m3) }
            }
        }
    }
    @ViewBuilder func plotParams(_ p: Obj, _ poly: [Pt]) -> some View {
        Chips {
            Chip(T("modeRect"), p.b("rectMode")) { if !p.b("rectMode") { p["rectMode"] = true; p["plotW"] = max(1, poly.map { $0[0] }.max()! - poly.map { $0[0] }.min()!); p["plotD"] = max(1, poly.map { $0[1] }.max()! - poly.map { $0[1] }.min()!) } }
            Chip(T("modePoints"), !p.b("rectMode")) { if p.b("rectMode") { p["rectMode"] = false; p["points"] = toArr(rect(p.n("plotW"), p.n("plotD"))) } }
        }
        if p.b("rectMode") {
            Hint(T("sPreset"))
            Chips { ForEach([(10, 20), (15, 20), (20, 30), (25, 40), (30, 50), (50, 50), (50, 100), (100, 100)], id: \.0) { w, d in
                Chip(sotStr(Double(w * d) / 100.0, 0), p.n("plotW") == Double(w) && p.n("plotD") == Double(d), sub: "\(w)×\(d)") { p["plotW"] = Double(w); p["plotD"] = Double(d); PV.z = 1; PV.ox = 0; PV.oy = 0 } } }
            HStack(spacing: 6) { NumField(T("plotWidth"), p.n("plotW")) { p["plotW"] = $0 }; NumField(T("plotDepth"), p.n("plotD")) { p["plotD"] = $0 } }
        } else {
            Hint(T("pointsNote")); let P = p.a("points")
            ForEach(Array(P.a.enumerated()), id: \.offset) { i, q0 in
                let q = q0 as! Arr
                HStack(alignment: .bottom, spacing: 4) {
                    Txt(ltr(i), 15, bold: true).frame(width: 24, alignment: .leading).padding(.bottom, 12)
                    NumField("X, " + T("m"), num(q[0]), zero: true) { q[0] = $0 }; NumField("Y, " + T("m"), num(q[1]), zero: true) { q[1] = $0 }
                    IconBtn("✕", P.count > 3 ? C.warn : C.muted) { if P.count > 3 { P.a.remove(at: i); upd() } }
                }
            }
            OBtn(T("addPoint")) { let a = P.a.last as! Arr, c = P.a.first as! Arr; P.add(arr((num(a[0]) + num(c[0])) / 2, (num(a[1]) + num(c[1])) / 2)); upd() }
        }
        HStack(spacing: 6) { NumField(T("setback"), p.n("setback"), zero: true) { p["setback"] = $0 }; NumField(T("sSetbackAux"), p.n("setbackAux", 1), zero: true) { p["setbackAux"] = $0 } }
    }
}

// ---------- планировка ----------
struct PlanCanvas: View {
    @ObservedObject var fr = Frame.shared
    @ObservedObject var u = UIS.shared
    @State private var touch = PlanTouch()
    var body: some View {
        GeometryReader { g in
            let _ = { touch.W = Double(g.size.width); touch.H = Double(g.size.height) }()
            ZStack {
                let _ = fr.n
                Canvas { c, size in drawPlan(DC(c, size), curB(), UI.lv) }
                Gestures(onDown: { touch.down($0) }, onMove: { touch.move($0, $1) }, onUp: { touch.up() })
            }
        }.frame(height: 340).background(C.field).cornerRadius(12).clipped().padding(.horizontal, 16)
    }
}
struct RoomsScreen: View {
    @ObservedObject var u = UIS.shared
    func prep(_ b: Obj) {
        ensureRooms(b); let Ls = levels(b)
        if !Ls.contains(where: { lvEq($0, UI.lv) }) { UI.lv = Ls.contains(where: { lvEq($0, 0.0) }) ? 0.0 : Ls[0] }
    }
    var body: some View {
        let p = St.project; let bs = buildings().filter { !["poly", "open"].contains($0.o("walls")["mat"] as? String ?? "") }; let b = curB()
        let _ = prep(b)
        let lv = UI.lv; let Ls = levels(b); let rs = rooms(b, lv); let sel = rs.first { $0.n("id") == UI.room }; let inn = inner(b); let n = FIN(b)
        Page {
            TopBar(T("rmTitle"), { go("home") })
            Sec {
                if bs.count > 1 { Chips { ForEach(Array(bs.enumerated()), id: \.offset) { _, x in Chip(itemName(x), num(x["id"]) == num(p["bSel"])) { p["bSel"] = x["id"]; UI.room = 0.0; PL.op = 0.0; PL.st = 0.0; PL.wp = nil } } } }
                Chips { ForEach(Array(Ls.enumerated()), id: \.offset) { _, l in Chip(lvName(l), lvEq(l, lv)) { UI.lv = l; UI.room = 0.0; PL.op = 0.0; PL.wp = nil } } }
                if eq(b["kind"], "house") { basAttic(b) }
            }
            toolsBar(b, lv)
            PlanCanvas()
            HintOut(T(isManual(b, lv) ? "rmHintM" : "rmHint") + " · \(fmt(inn.iw)) × \(fmt(inn.id)) \(T("m"))")
            if let o = planOf(b, lv)?.a("ops").objs.first(where: { $0.n("id") == PL.op }) { opSec(b, lv, o) }
            if let s = b.a("stairs").objs.first(where: { $0.n("id") == PL.st && (lvEq($0["lv"], lv) || lvEq(nextLv(b, $0["lv"]), lv)) }) { stairSec(b, s) }
            if let sel = sel { roomSec(b, sel, inn, n) }
            roomList(b, lv, rs, inn)
        }
    }
    @ViewBuilder func basAttic(_ b: Obj) -> some View {
        let B = b.o("basement"); let A = b.o("attic")
        Chips { Check(T("lvBaseOn"), B.b("on")) { B["on"] = $0 }; if hasAttic(b) { Check(T("lvAtticOn"), A.b("on")) { A["on"] = $0 } } }
        if B.b("on") { NumField(T("lvBaseH"), B.n("h")) { B["h"] = clampD($0, 1.8, 4.0) } }
    }
    @ViewBuilder func toolsBar(_ b: Obj, _ lv: Any?) -> some View {
        let tools: [(String, String)] = [("hand", "✋ " + T("tlHand")), ("wall", "🧱 " + T("tlWall")), ("door", "🚪 " + T("tlDoor"))] + (!eq(lv, "b") ? [("win", "🪟 " + T("tlWin"))] : []) + [("del", "🗑 " + T("tlDel"))]
        let P0 = planOf(b, lv)
        VStack(alignment: .leading, spacing: 0) {
            Chips {
                ForEach(tools, id: \.0) { k, l in Chip(l, PL.tool == k) { PL.tool = k; PL.wp = nil; PL.op = 0; if k != "hand" { toManual(b, lv); planChanged(b) } } }
                if nextLv(b, lv) != nil && !b.a("stairs").objs.contains(where: { lvEq($0["lv"], lv) }) { Chip("🪜 " + T("stAdd"), false) { addStair(b, lv) } }
                Chip("📏 " + T("dimT"), PL.dims) { PL.dims = !PL.dims }
                if lvIsNum(lv) && b.n("floors") > 1 && P0 != nil && P0!.a("ops").objs.contains(where: { eq($0["on"], "o") && eq($0["type"], "win") }) { Chip("⧉ " + T("cpWin"), false) { copyWins(b, lv) } }
            }
            HStack {
                Hint(T(["hand": "tlHHand", "wall": "tlHWall", "door": "tlHDoor", "win": "tlHWin", "del": "tlHDel"][PL.tool] ?? "tlHHand"), top: 0)
                if PL.tool == "wall" && PL.wp != nil { OBtn("⏹ " + T("tlEnd")) { PL.wp = nil; UI.tick += 1 } }
            }
        }.padding(.horizontal, 16)
    }
    @ViewBuilder func opSec(_ b: Obj, _ lv: Any?, _ o: Obj) -> some View {
        let P = planOf(b, lv)!; let isDoor = eq(o["type"], "door"); let d = opDef(o)
        Sec(!isDoor ? "🪟 " + T("tlWin") : "🚪 " + T(eq(o["on"], "o") ? "opDoorOut" : "opDoorIn")) {
            HStack(spacing: 6) { NumField(T("sWidth"), o.n("w")) { o["w"] = max(0.4, $0); planChanged(b) }; NumField(T("opH"), o.n("h")) { o["h"] = max(0.3, $0); planChanged(b) } }
            NumField(T("opPos"), o.n("t"), zero: true) { o["t"] = max(0, $0) }
            if !isDoor || eq(o["on"], "o") {
                Chips { ForEach(Array((isDoor ? D.o("DOORMAT") : D.o("WINMAT")).entries.enumerated()), id: \.offset) { _, e in Chip(tr3(e.1), eq(d["mat"], e.0)) { o["mat"] = e.0; planChanged(b) } } }
                Chips { ForEach(Array(D.o("OCOL").entries.enumerated()), id: \.offset) { _, e in ColorChip(hexColor((e.1 as! Arr).s(1)), eq(d["col"], e.0), w: 34) { o["col"] = e.0; planChanged(b) } } }
            }
            OBtn("✕ " + T("sDel"), C.warn) { P.a("ops").removeAll { ($0 as? Obj) === o }; PL.op = 0; planChanged(b); upd() }
        }
    }
    @ViewBuilder func stairSec(_ b: Obj, _ s: Obj) -> some View {
        let I = stInfo(b, s)
        Sec("🪜 \(T("stTitle")) · \(lvName(s["lv"])) → \(lvName(nextLv(b, s["lv"])))") {
            HStack(spacing: 6) { NumField(T("stW"), s.n("w")) { s["w"] = max(0.6, $0) }; NumField(T("stL"), s.n("L")) { s["L"] = max(1, $0) } }
            Stat(T("stSteps"), "\(I.n) × \(fmt(I.rise * 1000, 0)) мм"); Stat(T("stGoing"), "\(fmt(I.g * 1000, 0)) мм")
            if I.rise > 0.19 || I.g < 0.25 { Hint("\(T("stSteep")) (\(fmt(I.auto)) \(T("m")))", C.warn) }
            HStack(spacing: 6) {
                OBtn("⤾ " + T("rotation")) { s["dir"] = (s.n("dir") + 1).truncatingRemainder(dividingBy: 4); upd() }
                OBtn(T("stAuto")) { s["L"] = stInfo(b, s).auto; upd() }
                OBtn("✕ " + T("sDel"), C.warn) { b.a("stairs").removeAll { ($0 as? Obj) === s }; PL.st = 0; upd() }
            }
        }
    }
    @ViewBuilder func roomSec(_ b: Obj, _ sel: Obj, _ inn: Inner, _ n: Obj) -> some View {
        let rt = D.ROOMT.o(sel.s("type"))
        Sec("\(rt.s("e")) \(tr3(rt["n"])) · \(fmt(rA(sel), 1)) \(T("m2"))") {
            Chips { ForEach(Array(D.ROOMT.entries.enumerated()), id: \.offset) { _, e in let v = e.1 as! Obj; Chip(v.s("e") + " " + tr3(v["n"]), eq(sel["type"], e.0)) { sel["type"] = e.0 } } }
            Hint(T("nFloor")); Chips { ForEach([("laminate", "oLaminate"), ("tile", "oTile"), ("board", "oBoard"), ("lino", "oLino"), ("screed", "oScreedOnly")], id: \.0) { k, l in Chip(T(l), roomF(sel) == k) { sel["f"] = k } } }
            Hint(T("nWalls")); Chips { ForEach([("paint", "oPaint"), ("lime", "oLime"), ("wallpaper", "oWallpaper"), ("tile", "oTile"), ("vag", "oVag"), ("concrete", "oNone")], id: \.0) { k, l in Chip(T(l), roomW(sel) == k) { sel["wf"] = k } } }
            Hint(T("oPlaster"))
            Chips {
                Chip(T("plSame"), sel["plT"] == nil) { sel["plT"] = nil }
                ForEach(D.a("PLT").map { "\($0)" }, id: \.self) { k in Chip(T(D.o("PLT_N").s(k)), eq(sel["plT"], k)) { sel["plT"] = k } }
            }
            NumField(T("nPlasterT") + " (" + T("plSame").lowercased() + ": " + fmt(plMm(sel, n)) + ")", sel.n("plMm"), zero: true) { if $0 > 0 { sel["plMm"] = $0 } else { sel["plMm"] = nil } }
            if sel["seed"] != nil { Hint(T("manNote")) }
            else {
                HStack(spacing: 6) { NumField(T("sWidth"), sel.n("w")) { sel["w"] = min($0, inn.iw) }; NumField(T("sLength"), sel.n("d")) { sel["d"] = min($0, inn.id) } }
                HStack(spacing: 6) {
                    OBtn("⤾ " + T("rotation")) { let w = sel["w"]; sel["w"] = sel["d"]; sel["d"] = w; upd() }
                    OBtn("✕ " + T("sDel"), C.warn) { b.a("rooms").removeAll { ($0 as? Obj) === sel }; UI.room = 0; upd() }
                }
            }
        }
    }
    @ViewBuilder func roomList(_ b: Obj, _ lv: Any?, _ rs: [Obj], _ inn: Inner) -> some View {
        Sec(lvName(lv)) {
            ForEach(Array(rs.enumerated()), id: \.offset) { _, r in
                let rt = D.ROOMT.o(r.s("type"))
                Stat("\(rt.s("e")) \(tr3(rt["n"]))", (r["seed"] != nil ? "" : "\(fmt(r.n("w")))×\(fmt(r.n("d"))) = ") + "\(fmt(rA(r), 1)) \(T("m2"))", accent: r.n("id") == UI.room)
                    .contentShape(Rectangle()).onTapGesture { UI.room = r.n("id"); PL.op = 0; PL.st = 0; UI.tick += 1 }
            }
            Stat(T("rmSum"), "\(fmt(rs.reduce(0.0) { $0 + rA($1) }, 1)) / \(fmt(isShaped(b) ? inArea(b, b.o("walls").nz("t", 0.3)) : inn.iw * inn.id, 1)) \(T("m2"))")
            HStack(spacing: 6) {
                if !isManual(b, lv) {
                    OBtn("+ " + T("rmAdd")) {
                        let rid = b.n("rid") + 1; b["rid"] = rid
                        b.a("rooms").add(obj(("id", rid), ("type", "room"), ("lv", lvVal(lv)), ("x", 0.0), ("y", 0.0), ("w", min(3, inn.iw)), ("d", min(3, inn.id)))); UI.room = rid; upd()
                    }
                }
                OBtn("↻ " + T("rmAuto")) {
                    if let P = planOf(b, lv) { P["walls"] = arr(); P["ops"] = Arr(P.a("ops").objs.filter { eq($0["on"], "o") }.map { $0 as Any? }); P["rect"] = true }
                    PL.tool = "hand"; PL.wp = nil; b["rooms"] = Arr(b.a("rooms").objs.filter { !lvEq($0["lv"], lv) }.map { $0 as Any? }); planChanged(b); ensureRooms(b); UI.room = 0; upd()
                }
            }
        }
    }
}
