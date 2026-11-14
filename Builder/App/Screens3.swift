import SwiftUI
import UIKit

func tmpl(_ s: String, _ o: [String: String]) -> String {
    guard let re = try? NSRegularExpression(pattern: "\\{(\\w+)\\}") else { return s }
    let ns = s as NSString; var out = ""; var last = 0
    for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
        out += ns.substring(with: NSRange(location: last, length: m.range.location - last)); out += o[ns.substring(with: m.range(at: 1))] ?? ""; last = m.range.location + m.range.length
    }
    return out + ns.substring(from: last)
}
func optRow(_ n: Obj, _ key: String, _ pairs: [(String, String)]) -> some View {
    Chips { ForEach(Array(pairs.enumerated()), id: \.offset) { _, p in Chip(T(p.1), eq(n[key], p.0)) { n[key] = p.0 } } }
}
func numRow3(_ a: NumField, _ b: NumField, _ c: NumField) -> some View { HStack(spacing: 4) { a; b; c } }
func shareItems(_ items: [Any]) {
    guard let w = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.windows.first, var vc = w.rootViewController else { return }
    while let p = vc.presentedViewController { vc = p }
    let a = UIActivityViewController(activityItems: items, applicationActivities: nil)
    a.popoverPresentationController?.sourceView = w; a.popoverPresentationController?.sourceRect = CGRect(x: w.bounds.midX, y: w.bounds.midY, width: 1, height: 1)
    vc.present(a, animated: true)
}
func shareFile(_ name: String, _ data: Data) {
    let u = FileManager.default.temporaryDirectory.appendingPathComponent(name); try? data.write(to: u); shareItems([u])
}
func groupFL(_ list: [FL]) -> [(String, [FL])] {
    var out: [(String, [FL])] = []
    for l in list { if let i = out.firstIndex(where: { $0.0 == l.g }) { out[i].1.append(l) } else { out.append((l.g, [l])) } }
    return out
}

// ---------- отделка ----------
struct FinishScreen: View {
    @ObservedObject var u = UIS.shared
    func res(_ list: [FL]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(groupFL(list).enumerated()), id: \.offset) { _, g in
                Head(T(g.0))
                ForEach(Array(g.1.enumerated()), id: \.offset) { _, l in Stat(T(l.k), fmt(l.v, 10) + " " + l.u, sub: l.x.map { L($0) }) }
            }
            if list.isEmpty { Hint("—") }
            Hint(T("fPriceNote"))
        }
    }
    var body: some View {
        let b = curB()
        Page {
            TopBar(T("mFinish"), { go("home") }); BSelector()
            Sec(pad: 10) { Hint("\(itemName(b)): \(fmt(b.n("w"))) × \(fmt(b.n("d"))) \(T("m")), \(fmt(b.n("floors"))) × \(fmt(b.n("floorH"))) \(T("m"))", top: 0, bottom: 0) }
            if eq(b["kind"], "greenhouse") { Sec { Txt("🌱 " + T("nGhNo"), 14) } }
            else { FinishBody(b: b, res: res) }
        }
    }
}
struct FinishBody: View {
    let b: Obj; let res: ([FL]) -> AnyView
    init(b: Obj, res: @escaping ([FL]) -> some View) { self.b = b; self.res = { AnyView(res($0)) } }
    var body: some View {
        let open = eq(b.o("walls")["mat"], "open"); let n: Obj = open ? obj() : FIN(b); let r = calcFin(b); let list = (r["list"] as? FLBox)?.a ?? []
        if open { Sec(T("fMaterials")) { res(list) } }
        else { FinishFull(b: b, n: n, r: r, list: list, res: res) }
    }
}
struct FinishFull: View {
    let b: Obj; let n: Obj; let r: Obj; let list: [FL]; let res: ([FL]) -> AnyView
    var body: some View {
        let byRooms = notFalse(n["byRooms"]); let rooms = r["rooms"] as? Arr
        let PLT = D.a("PLT").map { "\($0)" }; let PLTN = D.o("PLT_N"); let rs = b.a("rooms").objs
        Sec(pad: 10) {
            Chips { Chip("📐 " + T("nByRooms"), byRooms) { n["byRooms"] = true }; Chip("🏠 " + T("nWhole"), !byRooms) { n["byRooms"] = false } }
            if byRooms { Hint(T("nByRoomsHint")); OBtn("✏️ " + T("rmTitle")) { UI.lv = 0.0; go("rooms") } }
        }
        if let rooms = rooms { roomsSec(rooms) }
        Sec(T("nAreas")) { Stat(T("aFloor"), stv(r.n("floor"), 1, T("m2"))); Stat(T("aWall"), stv(r.n("wall"), 1, T("m2"))); Stat(T("nCeil"), stv(r.n("ceil"), 1, T("m2"))); Stat(T("aFacade"), stv(r.n("facade"), 1, T("m2"))) }
        Sec(T("nWalls")) {
            Hint(T("nBase"), top: 0); optRow(n, "wb", [("plaster", "oPlaster"), ("gkl", "oGkl"), ("vag", "oVag"), ("none", "oNone")])
            if eq(n["wb"], "plaster") {
                Chips { ForEach(PLT, id: \.self) { k in Chip(T(PLTN.s(k)), eq(n["pType"], k)) { n["pType"] = k } } }; Hint(T("ph_" + n.s("pType")))
                NumField(T("nPlasterT"), n.n("pT")) { n["pT"] = clampD($0, 5, 50) }
                Hint(T("pBag")); Chips { ForEach([25.0, 30.0, 40.0, 50.0], id: \.self) { x in Chip(fmt(x) + " кг", n.n("bag") == x) { n["bag"] = x } } }
                if rooms != nil { Hint(T("pRoomsHint")) }
            }
            if rooms == nil && !eq(n["wb"], "vag") && !eq(n["wb"], "none") { Hint(T("nFinish")); optRow(n, "wf", [("paint", "oPaint"), ("lime", "oLime"), ("wallpaper", "oWallpaper"), ("none", "oNone")]) }
            if eq(n["wf"], "wallpaper") || (byRooms && rs.contains(where: { roomW($0) == "wallpaper" })) { WpUI(n: n) }
            if eq(n["wf"], "lime") || eq(n["cf"], "lime") || rs.contains(where: { roomW($0) == "lime" }) {
                NumField(T("lmLayers"), n.n("lmL")) { n["lmL"] = clampD($0, 1, 6).rounded(.toNearestOrAwayFromZero) }
                Chips { Chip(T("lmQuick"), eq(n["lmT"], "quick")) { n["lmT"] = "quick" }; Chip(T("lmHyd"), !eq(n["lmT"], "quick")) { n["lmT"] = "hyd" } }
                LimeRecipe(n: n, r: r); Hint(T("lmHint"))
            }
        }
        OpsUI(b: b, n: n); WoodUI(b: b, n: n)
        Sec(T("nCeil")) {
            optRow(n, "cb", [("plaster", "oPlaster"), ("gkl", "oGkl"), ("stretch", "oStretch"), ("pvc", "oPvc"), ("mdf", "oMdf"), ("deco", "oDeco"), ("arm", "oArm"), ("rack", "oRack"), ("vag", "oVag"), ("none", "oNone")])
            if eq(n["cb"], "plaster") {
                Chips { ForEach(PLT.filter { $0 != "clay" }, id: \.self) { k in Chip(T(PLTN.s(k)), eq(n["pCeilType"], k)) { n["pCeilType"] = k } } }
                NumField(T("nPlasterT"), n.n("pCeilT")) { n["pCeilT"] = clampD($0, 3, 40) }
            }
            if let sz = ["pvc": "pvcP", "mdf": "mdfP", "deco": "decoT", "arm": "armT", "rack": "rackP"][n.s("cb")] { Hint("📏 \(szj(sz)) мм"); OBtn("📏 " + T("szTitle")) { go("sizes", "finish") } }
            if ["plaster", "gkl"].contains(n.s("cb")) { Hint(T("nFinish")); optRow(n, "cf", [("paint", "oPaint"), ("lime", "oLime"), ("none", "oNone")]) }
        }
        Sec(T("nFloor")) {
            NumField(T("nScreed"), n.n("scr"), zero: true) { n["scr"] = $0.rounded(.toNearestOrAwayFromZero) }
            if rooms == nil { Hint(T("nFinish")); optRow(n, "ff", [("laminate", "oLaminate"), ("tile", "oTile"), ("lino", "oLino"), ("board", "oBoard"), ("none", "oNone")]) }
        }
        if rooms == nil { Sec(T("nWet")) { HStack(spacing: 6) { NumField(T("nWetFloor"), n.n("wetF"), zero: true) { n["wetF"] = $0 }; NumField(T("nWetWall"), n.n("wetW"), zero: true) { n["wetW"] = $0 } } } }
        Sec(T("nFacade")) {
            optRow(n, "fac", [("ins", "oFIns"), ("paint", "oFPaint"), ("siding", "oSiding"), ("brick", "oBrick"), ("none", "oNone")])
            if eq(n["fac"], "ins") { Chips { ForEach([50.0, 100.0, 150.0], id: \.self) { x in Chip(fmt(x) + " мм", n.n("insT") == x) { n["insT"] = x } } }; NumField(T("ownVal"), n.n("insT")) { n["insT"] = clampD($0, 10, 300) } }
            if eq(n["fac"], "paint") {
                let pt = n["pFacType"] as? String ?? "cem"
                Chips { ForEach(["cem", "cs", "cl", "lime", "clay"], id: \.self) { k in Chip(T(PLTN.s(k)), pt == k) { n["pFacType"] = k } } }; Hint(T("ph_" + pt))
                NumField(T("nPlasterT"), n.n("pFacT")) { n["pFacT"] = clampD($0, 5, 50) }
            }
        }
        RateLink(back: "finish"); ExtrasUI(b: b, sec: "finish"); SzLink(back: "finish")
        Sec(T("fMaterials")) { res(list) }
    }
    @ViewBuilder func roomsSec(_ rooms: Arr) -> some View {
        Sec(T("nRoomsT")) {
            ForEach(Array(rooms.a.enumerated()), id: \.offset) { _, x0 in
                let x = x0 as! Arr; let q = x[0] as! Obj; let rt = D.ROOMT.o(q.s("type"))
                let fN = ["laminate": "oLaminate", "tile": "oTile", "board": "oBoard", "lino": "oLino", "screed": "oScreedOnly"][roomF(q)] ?? "oNone"
                let wN = ["paint": "oPaint", "wallpaper": "oWallpaper", "tile": "oTile", "vag": "oVag", "concrete": "oNone", "lime": "oLime"][roomW(q)] ?? "oNone"
                Stat("\(rt.s("e")) \(tr3(rt["n"])) (\(lvName(q["lv"])))", "\(fmt(num(x[1]), 1)) \(T("m2")) · \(T(fN))\n\(T(wN)) \(fmt(num(x[2]), 1)) \(T("m2"))")
            }
        }
    }
}
struct WpUI: View {
    @ObservedObject var u = UIS.shared
    let n: Obj
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Txt("🧻 " + T("wpTitle"), 15, bold: true)
            Chips { ForEach(Array(D.o("WPT").entries.enumerated()), id: \.offset) { _, e in Chip(T(e.1 as! String), eq(n["wpType"], e.0)) { n["wpType"] = e.0; if e.0 == "glass" { n["wpL"] = 25.0; n["wpW"] = 1.0 } } } }
            Hint(T("wpWidth")); Chips { ForEach([0.53, 0.7, 1.06], id: \.self) { v in Chip(fmt(v).replacingOccurrences(of: ".", with: ",") + " м", n.n("wpW") == v) { n["wpW"] = v } } }
            HStack(spacing: 4) {
                NumField(T("wpW"), n.n("wpW")) { n["wpW"] = clampD($0, 0.3, 1.5) }; NumField(T("wpL"), n.n("wpL")) { n["wpL"] = clampD($0, 3, 50) }
                NumField(T("wpRap"), n.n("wpRap"), zero: true) { n["wpRap"] = clampD($0, 0, 100) }
            }
            Hint(T("wpHint"))
        }.padding(10).background(C.field).cornerRadius(12).padding(.vertical, 8)
    }
}
struct LimeRecipe: View {
    @ObservedObject var u = UIS.shared
    let n: Obj; let r: Obj
    var body: some View {
        let q = RT("lmQ"); let quick = eq(n["lmT"], "quick"); let per = 10 / RT("lmSol")
        let o: [String: String] = ["q": fmt(q, 1), "h": fmt(q * 1.32, 1), "w": fmt(q * RT("lmSlake"), 1), "s": fmt(RT("lmSalt"), 0), "m": fmt(per, 0), "n": fmt(n.n("lmL"))]
        let keys = quick ? ["lrQ1", "lrQ2", "lrQ3", "lrQ4", "lrQ5"] : ["lrH1", "lrH2", "lrH3"]
        VStack(alignment: .leading, spacing: 0) {
            Txt("🪣 " + T(quick ? "lrTitleQ" : "lrTitleH"), 15, bold: true)
            ForEach(Array(keys.enumerated()), id: \.offset) { i, k in Txt("\(i + 1). " + tmpl(T(k), o), 14) }
            if r.n("whL") != 0 {
                let Ll = r.n("whL"); let kq = Ll / 10 * q
                Stat("\(T("lrTotal")) (\(fmt(r.n("whA"), 1)) \(T("m2")) × \(fmt(n.n("lmL"))))", "\(fmt(Ll, 0)) л")
                if quick { Stat(T("lrQuickKg"), "\(fmt(kq, 1)) кг"); Stat(T("lrSlakeW"), "\(fmt(kq * RT("lmSlake"), 1)) л") } else { Stat(T("lrHydKg"), "\(fmt(kq * 1.32, 1)) кг") }
                Stat(T("lrSalt"), "\(fmt(Ll / 10 * RT("lmSalt") / 1000, 2)) кг")
            }
            Hint("⚠️ " + T(quick ? "lrWarnQ" : "lrWarnH"), C.warn)
        }.padding(10).background(C.field).cornerRadius(12).padding(.vertical, 8)
    }
}
struct OpsUI: View {
    @ObservedObject var u = UIS.shared
    let b: Obj; let n: Obj
    var body: some View {
        let O = opsMount(b)
        if O.win.n + O.door.n + O.inner.n != 0 {
            Sec("🪟 " + T("nOps")) {
                Hint(T("opCount").replacingOccurrences(of: "{w}", with: fmt(O.win.n)).replacingOccurrences(of: "{d}", with: fmt(O.door.n)).replacingOccurrences(of: "{i}", with: fmt(O.inner.n)), top: 0)
                Chips { Check(T("opTape"), notFalse(n["opTape"])) { n["opTape"] = $0 }; Check(T("opSill"), notFalse(n["opSill"])) { n["opSill"] = $0 } }
                Hint(T("opFoamV")); Chips { ForEach([500.0, 750.0, 850.0, 1000.0], id: \.self) { v in Chip(fmt(v) + " мл", n.nz("foamV", 750) == v) { n["foamV"] = v } } }
                NumField(T("ownValP") + ", мл", n.nz("foamV", 750)) { n["foamV"] = clampD($0, 100, 2000) }
                Hint(T("opSealV")); Chips { ForEach([280.0, 300.0, 310.0, 600.0], id: \.self) { v in Chip(fmt(v) + " мл", n.nz("sealV", 300) == v) { n["sealV"] = v } } }
                NumField(T("ownValP") + ", мл", n.nz("sealV", 300)) { n["sealV"] = clampD($0, 50, 1000) }; Hint(T("opHint"))
            }
        }
    }
}
struct WoodUI: View {
    @ObservedObject var u = UIS.shared
    let b: Obj; let n: Obj
    var body: some View {
        let L = lagInfo(b, n); let ls = n.s("lagS").split(separator: "x").map { Double($0) ?? 50 }; let bc = bcOn(b, n); let l0 = ls[safe: 0] ?? 50; let l1 = ls[safe: 1] ?? 150; let joist = eq(n["base"], "joist")
        Sec("🪵 " + T("wdTitle")) {
            Hint(T("wdFloor"), top: 0)
            Chips { Chip(T("wdSlab"), !joist) { n["base"] = "slab" }; Chip(T("wdJoist"), joist) { n["base"] = "joist" } }
            if joist {
                Hint(T("wdLagS")); Chips { ForEach(["50x100", "50x150", "100x100", "100x150"], id: \.self) { x in Chip(x.replacingOccurrences(of: "x", with: "×"), eq(n["lagS"], x)) { n["lagS"] = x } } }
                HStack(spacing: 4) {
                    NumField(T("wdLagW"), l0) { n["lagS"] = fmt(max(30, $0)) + "x" + fmt(l1) }
                    NumField(T("wdLagH"), l1) { n["lagS"] = fmt(l0) + "x" + fmt(max(50, $0)) }
                    NumField(T("wdLagStep"), n.n("lagStep")) { n["lagStep"] = clampD($0, 0.3, 1.2) }
                }
                if L.onGround {
                    Hint(T("wdTumb")); Chips { ForEach([("brick", "wdTBrick"), ("conc", "wdTConc"), ("block", "wdTBlock")], id: \.0) { k, l in Chip(T(l), eq(n["tType"], k)) { n["tType"] = k } } }
                    HStack(spacing: 6) { NumField(T("wdTStep"), n.n("tStep")) { n["tStep"] = clampD($0, 0.5, 2.0) }; NumField(T("wdTH"), n.n("tH")) { n["tH"] = clampD($0, 0.2, 1.5) } }
                    Hint(T("wdTol")); Chips { ForEach([0.0, 1.0, 2.0, 3.0], id: \.self) { k in Chip(k > 0 ? T("lmL") + ": " + fmt(k) : T("oNone"), n.n("tolL") == k) { n["tolL"] = k } } }
                    Stat(T("wdRows"), "\(fmt(L.rows)) × \(fmt(L.lc, 2)) \(T("m"))"); Stat(T("wdTCnt"), fmt(L.cnt) + " " + T("uPcs"))
                } else { Hint(T("wdOnSlab")) }
            }
            Hint(T("wdBc")); Chips { Chip(T("wdYes"), bc) { n["bc"] = true }; Chip(T("wdNo"), !bc) { n["bc"] = false } }
            if bc {
                NumField(T("wdBcT"), n.n("bcT")) { n["bcT"] = clampD($0, 10, 60) }
                Hint(T("wdBcTol")); Chips { ForEach([0.0, 1.0, 2.0], id: \.self) { k in Chip(k > 0 ? T("lmL") + ": " + fmt(k) : T("oNone"), n.n("bcTol") == k) { n["bcTol"] = k } } }
                Hint(T("wdBcIns")); Chips { ForEach([("none", "oNone"), ("clay", "wdIClay"), ("slag", "wdISlag"), ("saw", "wdISaw"), ("exp", "wdIExp"), ("wool", "wdIWool")], id: \.0) { k, l in Chip(T(l), eq(n["bcIns"], k)) { n["bcIns"] = k } } }
                if !eq(n["bcIns"], "none") { NumField(T("wdBcInsT"), n.n("bcInsT")) { n["bcInsT"] = clampD($0, 20, 400) } }
                Hint(T("wdBcHint"))
            }
        }
    }
}

// ---------- коммуникации ----------
struct EngScreen: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let bs = buildings().filter { !["poly", "open"].contains($0.o("walls")["mat"] as? String ?? "") }; let p = St.project; let b = curB(); let e = ENG(b); let r = calcEng(b)
        let heat = e.s("heat"); let water = e.s("water"); let sewer = e.s("sewer")
        Page {
            TopBar(T("mEng"), { go("home") })
            if bs.count > 1 { Sec { Chips { ForEach(Array(bs.enumerated()), id: \.offset) { _, x in Chip(itemName(x), num(x["id"]) == num(p["bSel"])) { p["bSel"] = x["id"] } } } } }
            Sec(T("ePoints")) {
                ForEach(Array(((r["rooms"] as? Arr)?.a ?? []).enumerated()), id: \.offset) { _, x0 in
                    let x = x0 as! Arr; let q = x[0] as! Obj; let rt = D.ROOMT.o(q.s("type"))
                    Stat("\(rt.s("e")) \(tr3(rt["n"])) (\(lvName(q["lv"])))", "🔌 \(fmt(num(x[1]))) · 💡 \(fmt(num(x[2])))" + (num(x[3]) != 0 ? " · 💧 \(fmt(num(x[3])))" : ""))
                }
                Stat(T("eHeatA"), stv(r.n("heatA"), 1, T("m2"))); OBtn("✏️ " + T("rmTitle")) { UI.lv = 0.0; go("rooms") }
            }
            Sec(T("gElec")) {
                Toggle1(e.b("elec")) { e["elec"] = $0 }
                if e.b("elec") {
                    Hint(T("ePh")); Chips { Chip(T("ePh1"), e.n("ph") != 3) { e["ph"] = 1.0 }; Chip(T("ePh3"), e.n("ph") == 3) { e["ph"] = 3.0 } }
                    HStack(spacing: 6) { NumField(T("eInLen"), e.n("inLen"), zero: true) { e["inLen"] = $0 }; NumField(T("eKwIn"), e.n("kw"), zero: true) { e["kw"] = clampD($0, 3, 100) } }; Hint(T("eElHint"))
                }
            }
            Sec(T("gWater")) {
                Chips { ForEach([("city", "eCity"), ("well", "eWell"), ("none", "eOff")], id: \.0) { k, l in Chip(T(l), water == k) { e["water"] = k } } }
                if water == "city" { NumField(T("eWInLen"), e.n("wInLen"), zero: true) { e["wInLen"] = $0 }; Hint(T("eWHint")) }
                if water == "well" { HStack(spacing: 6) { NumField(T("eWellD"), e.n("wellD")) { e["wellD"] = $0 }; NumField(T("eWellDist"), e.n("wellDist"), zero: true) { e["wellDist"] = $0 } } }
            }
            Sec(T("gSewer")) {
                Chips { ForEach([("central", "eCentral"), ("septic", "eSeptic"), ("none", "eOff")], id: \.0) { k, l in Chip(T(l), sewer == k) { e["sewer"] = k } } }
                if sewer != "none" { HStack(spacing: 6) { NumField(T("eOutLen"), e.n("outLen"), zero: true) { e["outLen"] = $0 }; if sewer == "septic" { NumField(T("eRes"), e.n("res")) { e["res"] = $0.rounded(.toNearestOrAwayFromZero) } } } }
            }
            Sec(T("gHeat")) {
                Chips { ForEach([("gas", "eGasBoil"), ("elboil", "eElBoil"), ("combi", "eCombi"), ("floor", "eFloor"), ("electric", "eElecH"), ("stove", "eStove"), ("none", "eOff")], id: \.0) { k, l in Chip(T(l), heat == k) { e["heat"] = k } } }
                if ["gas", "floor", "elboil", "combi"].contains(heat) { Stat(T("eKw"), fmt(r.n("kw")) + " кВт") }
                if heat == "combi" { Hint(T("eCombiHint")) }; if heat == "elboil" { Hint(T("eElBoilHint")) }
            }
            Sec(T("gVent")) { Chips { ForEach([("exhaust", "eVExh"), ("mvhr", "eVMvhr"), ("none", "eOff")], id: \.0) { k, l in Chip(T(l), eq(e["vent"], k)) { e["vent"] = k } } }; Hint(T("eVHint")) }
            Sec(T("gGas")) { Toggle1(gasOn(b)) { e["gas"] = $0 }; if gasOn(b) { NumField(T("eGasLen"), e.n("gasLen"), zero: true) { e["gasLen"] = $0 }; Hint(T("eGHint")) } }
            Sec(T("fMaterials")) { PricedList(ls: engLines(b), totalKey: "engTotal"); Hint(T("fnPriceShared")) }
            HintOut("⚠️ " + T("engNote")); RateLink(back: "eng"); ExtrasUI(b: b, sec: "eng")
        }
    }
}

// ---------- отмостка, крыльцо, лестницы ----------
struct ExtraScreen: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let b = curB(); let e = EXD(b); let r = calcExtra(b); let p = St.project
        let bl = e.o("blind"); let po = e.o("porch"); let st = e.o("stair"); let dr = e.o("drain")
        let all = extraLines(b) + extrasLines(b, "extra").map { Line("xTitle", $0.pk, $0.label, $0.qty, $0.unit) }
        Page {
            TopBar(T("mExtra"), { go("home") })
            if buildings().count > 1 { Sec { Chips { ForEach(Array(buildings().enumerated()), id: \.offset) { _, x in Chip(itemName(x), num(x["id"]) == num(p["bSel"])) { p["bSel"] = x["id"] } } } } }
            Sec(T("exBlind")) {
                Toggle1(bl.b("on")) { bl["on"] = $0 }
                if bl.b("on") {
                    Chips { Chip(T("exConc"), eq(bl["type"], "conc")) { bl["type"] = "conc" }; Chip(T("exTile"), eq(bl["type"], "tile")) { bl["type"] = "tile" } }
                    HStack(spacing: 6) { NumField(T("exW"), bl.n("w")) { bl["w"] = clampD($0, 0.5, 2) }; if eq(bl["type"], "conc") { NumField(T("exT"), bl.n("t")) { bl["t"] = $0 } } }
                    Hint("\(T("exArea")): \(stv(r.n("blindA"), 1, T("m2")))")
                }
            }
            Sec(T("exPorch")) {
                Toggle1(po.b("on")) { po["on"] = $0 }
                if po.b("on") {
                    Chips { ForEach([("conc", "exConc"), ("brick", "exBrick"), ("wood", "exWood")], id: \.0) { k, l in Chip(T(l), eq(po["mat"], k)) { po["mat"] = k } } }
                    HStack(spacing: 4) { NumField(T("exW"), po.n("w")) { po["w"] = $0 }; NumField(T("exD"), po.n("d")) { po["d"] = $0 }; NumField(T("exH"), po.n("h")) { po["h"] = $0 } }
                    Hint("\(fmt(r.n("pSteps"))) \(T("exSteps"))")
                }
            }
            Sec(T("exStair")) {
                Toggle1(st.b("on")) { st["on"] = $0 }
                if st.b("on") {
                    if r.n("sFl") != 0 {
                        Chips { ForEach([("wood", "exWood"), ("conc", "exConc"), ("metal", "exMetal")], id: \.0) { k, l in Chip(T(l), eq(st["type"], k)) { st["type"] = k } } }
                        NumField(T("exW"), st.n("w")) { st["w"] = $0 }; Hint("\(fmt(r.n("sFl"))) \(T("exFlights")) × \(fmt(r.n("sSteps"))) \(T("exSteps"))")
                    } else { Hint("—") }
                }
            }
            Sec(T("exDrain")) {
                Toggle1(dr.b("on")) { dr["on"] = $0 }
                if dr.b("on") {
                    Chips { Chip(T("exTray"), eq(dr["type"], "tray")) { dr["type"] = "tray" }; Chip(T("exPipe"), eq(dr["type"], "pipe")) { dr["type"] = "pipe" } }
                    NumField(T("exOut"), dr.n("out"), zero: true) { dr["out"] = $0 }
                }
            }
            Sec(T("fMaterials")) { PricedList(ls: all, totalKey: "exTotal"); Hint(T("fnPriceShared")) }
            ExtrasUI(b: b, sec: "extra")
        }
    }
}

// ---------- смета ----------
func groupSec(_ L: [Line]) -> [(String, [(String, [Line])])] {
    var gs: [(String, [(String, [Line])])] = []
    for l in L {
        let g = l.g ?? "", s = l.sec ?? ""
        if let i = gs.firstIndex(where: { $0.0 == g }) {
            if let j = gs[i].1.firstIndex(where: { $0.0 == s }) { gs[i].1[j].1.append(l) } else { gs[i].1.append((s, [l])) }
        } else { gs.append((g, [(s, [l])])) }
    }
    return gs
}
struct EstimateScreen: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let p = St.project; let E = estimate(); let est = p.o("est"); let P = p.o("prices"); let filled = E.agg.filter { E.price($0.pk) > 0 }.count
        Page {
            TopBar(T("mEstimate"), { go("home") })
            Sec(T("eTotal")) {
                Stat(T("eMat"), money(E.mat))
                Hint(T("eWorkHow")); Chips { Chip(T("eWorkPct"), !eq(est["workMode"], "items")) { est["workMode"] = "pct" }; Chip(T("eWorkItems"), eq(est["workMode"], "items")) { est["workMode"] = "items" } }
                HStack(spacing: 6) { NumField(T(eq(est["workMode"], "items") ? "eWorkAuto" : "eWork"), est.n("work"), zero: true) { est["work"] = $0 }; NumField(T("eReserve"), est.n("reserve"), zero: true) { est["reserve"] = $0 } }
                Hint(T("locNote"))
                NumField(T("eLogi"), est.n("logi"), zero: true) { est["logi"] = clampD($0, 0, 30) }; Hint(T("eLogiHint"))
                Stat(T("eLogiS"), money(E.logi)); Stat(T("eWork").components(separatedBy: ",")[0], money(E.work)); Stat(T("eReserve").components(separatedBy: ",")[0], money(E.res)); Stat(T("eGrand"), money(E.total), accent: true, big: true)
                if E.living > 0 { Stat(T("ePerM2"), money(E.total / E.living) + " / " + T("m2")) }
                Hint("\(T("eFilled")): \(filled) / \(E.agg.count) · \(T("currency")): \(St.cur)")
            }
            Sec(pad: 10) { Chips { Chip(T("eSummary"), !eq(est["tab"], "byb")) { est["tab"] = "sum" }; Chip(T("eByB"), eq(est["tab"], "byb")) { est["tab"] = "byb" } } }
            if let WT = E.WT { workSec(WT) }
            if E.L.isEmpty { Sec { Txt(T("eEmpty"), 15) } }
            else if !eq(est["tab"], "byb") { summarySec(E, P) }
            else { bybSec(E) }
            Btn("💰 " + T("tasTitle"), false) { go("price") }
            Btn(T("eShare")) { shareItems([estimateText(E)]) }
            Btn(T("ePdf")) { Premium.gate("pdf") { shareEstimatePdf() } }
            Btn(T("eCsv"), false) { Premium.gate("csv") { shareFile("estimate.csv", Data(estimateCsv(E).utf8)) } }
        }
    }
    @ViewBuilder func workSec(_ WT: WT) -> some View {
        Sec(T("eWorkItems")) {
            Hint(T("eWorkItemsHint"), top: 0)
            ForEach(Array(WT.rows.enumerated()), id: \.offset) { _, r in
                Divider1()
                if r.other { Stat(T(r.lbl) + " · " + (r.sec ?? ""), money(r.v)); Hint(T("eAuto"), top: 0) }
                else {
                    let w = r.w; let rate = eq(w["mode"], "rate"); let key = rate ? "rate" : "sum"
                    Stat(T(r.lbl), r.v != 0 ? money(r.v) : "—")
                    Hint("\(qfmt(r.q)) \(T(r.u))" + (r.auto ? " · " + T("eAuto") : (rate && w.n("rate") != 0 ? " · \(money(w.n("rate"))) / \(T(r.u))" : "")), r.auto ? C.accent : C.muted, top: 0)
                    HStack(spacing: 6) {
                        Chip(T("eRate"), rate) { w["mode"] = "rate" }; Chip(T("eContract"), !rate) { w["mode"] = "contract" }
                        PriceIn(w.n(key), placeholder: rate ? T("eRateIn") + " " + T(r.u) : T("eSumIn")) { w[key] = $0 }
                    }
                }
            }
            Stat(T("eWorkTotal"), money(WT.tot), accent: true)
        }
    }
    @ViewBuilder func summarySec(_ E: Est, _ P: Obj) -> some View {
        Sec(T("eSummary")) {
            Hint(T("ePriceHint"), top: 0)
            ForEach(Array(E.agg.enumerated()), id: \.offset) { _, a in
                Divider1()
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) { Txt(a.label, 14); Txt("\(qfmt(a.qty)) \(a.unit) × \(T("ePrice").lowercased()) / \(a.unit)", 12, C.muted) }.frame(maxWidth: .infinity, alignment: .leading)
                    PriceIn(E.price(a.pk)) { P[a.pk] = $0 }.frame(width: 96)
                    Txt(E.price(a.pk) > 0 ? money(a.qty * E.price(a.pk)) : "—", 13, bold: true, align: .trailing).frame(width: 92, alignment: .trailing)
                }.padding(.vertical, 7)
            }
        }
    }
    @ViewBuilder func bybSec(_ E: Est) -> some View {
        ForEach(Array(groupSec(E.L).enumerated()), id: \.offset) { _, gs in
            let tot = gs.1.reduce(0.0) { $0 + $1.1.reduce(0.0) { $0 + $1.qty * E.price($1.pk) } }
            Sec {
                HStack { Txt(gs.0, 17, bold: true).frame(maxWidth: .infinity, alignment: .leading); Txt(money(tot), 15, bold: true) }
                ForEach(Array(gs.1.enumerated()), id: \.offset) { _, s in
                    Head("\(s.0) · \(money(s.1.reduce(0.0) { $0 + $1.qty * E.price($1.pk) }))", C.muted)
                    ForEach(Array(s.1.enumerated()), id: \.offset) { _, l in Stat("\(l.label) — \(qfmt(l.qty)) \(l.unit)", E.price(l.pk) > 0 ? money(l.qty * E.price(l.pk)) : "—") }
                }
            }
        }
    }
}
func estimateText(_ E: Est) -> String {
    var sb = ""; let name = Store.list().first { ($0["id"] as? String) == Store.pid }.map { Store.title($0) } ?? ""
    sb += "🏗️ \(t("appTitle")) — \(name)\n\n"
    for a in E.agg { sb += "• \(a.label): \(qfmt(a.qty)) \(a.unit)" + (E.price(a.pk) > 0 ? " = \(money(a.qty * E.price(a.pk)))" : "") + "\n" }
    sb += "\n\(t("eMat")): \(money(E.mat))\n\(t("eLogiS")): \(money(E.logi))\n\(t("eWork").components(separatedBy: ",")[0]): \(money(E.work))\n\(t("eReserve").components(separatedBy: ",")[0]): \(money(E.res))\n\(t("eGrand")): \(money(E.total))\n"
    return L(sb)
}
func estimateCsv(_ E: Est) -> String {
    var sb = "\u{FEFF}\(t("prProject"));\(t("cmName"));\(t("prQty"));\(t("prUnit"));\(t("ePrice"));Σ\n"
    for l in E.L { let pr = E.price(l.pk); sb += "\"\(l.g ?? "")\";\"\(l.label.replacingOccurrences(of: "\"", with: "'"))\";\(fmt(l.qty, 3).replacingOccurrences(of: ".", with: ","));\(l.unit);\(fmt(pr, 2).replacingOccurrences(of: ".", with: ","));\(fmt(l.qty * pr, 0))\n" }
    return L(sb)
}

/// Смета в PDF (A4) и отправка
func shareEstimatePdf() {
    let E = estimate(); let W: CGFloat = 595, H: CGFloat = 842, M: CGFloat = 36; let right = W - M
    let fp = UIFont.systemFont(ofSize: 9), fb = UIFont.boldSystemFont(ofSize: 9), fh = UIFont.boldSystemFont(ofSize: 15), fg = UIFont.boldSystemFont(ofSize: 11), fT = UIFont.boldSystemFont(ofSize: 12)
    let name = Store.list().first { ($0["id"] as? String) == Store.pid }.map { Store.title($0) } ?? ""
    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: W, height: H))
    let data = renderer.pdfData { ctx in
        var y = M; var started = false
        func newPage() { ctx.beginPage(); y = M; started = true }
        func need(_ h: CGFloat) { if !started { newPage() } else if y + h > H - M { newPage() } }
        func draw(_ s: String, _ x: CGFloat, _ yy: CGFloat, _ f: UIFont, _ col: UIColor = .black, right: Bool = false) {
            let a: [NSAttributedString.Key: Any] = [.font: f, .foregroundColor: col]; let sz = (s as NSString).size(withAttributes: a)
            (s as NSString).draw(at: CGPoint(x: right ? x - sz.width : x, y: yy), withAttributes: a)
        }
        func fit(_ s: String, _ w: CGFloat, _ f: UIFont) -> String {
            let a: [NSAttributedString.Key: Any] = [.font: f]; if (s as NSString).size(withAttributes: a).width <= w { return s }
            var t2 = s; while !t2.isEmpty && ("\(t2)…" as NSString).size(withAttributes: a).width > w { t2.removeLast() }; return t2 + "…"
        }
        func hline() { let p = UIBezierPath(); p.move(to: CGPoint(x: M, y: y)); p.addLine(to: CGPoint(x: right, y: y)); UIColor.lightGray.setStroke(); p.lineWidth = 0.5; p.stroke() }
        let cols: [CGFloat] = [M, 330, 400, 480]
        func row(_ a: String, _ q: String, _ pr: String, _ sm: String, _ f: UIFont) {
            need(14); draw(fit(L(a), cols[1] - cols[0] - 6, f), cols[0], y, f); draw(L(q), cols[2] - 4, y, f, right: true); draw(pr, cols[3] - 4, y, f, right: true); draw(sm, right, y, f, right: true)
            y += 13; hline(); y += 1
        }
        func nf(_ v: Double) -> String { v > 0 ? mn(v) : "—" }
        need(40); draw(L(t("appTitle") + " — " + name), M, y, fh); y += 22
        let df = DateFormatter(); df.dateStyle = .long; df.locale = Locale(identifier: St.lang == "uzc" ? "uz-Cyrl" : St.lang)
        draw(df.string(from: Date()) + " · " + t("currency") + ": " + St.cur, M, y, fp); y += 22
        row(t("cmName"), t("prQty"), t("ePrice"), "Σ", fb)
        for (g, secs) in groupSec(E.L) {
            need(30); y += 6; draw(fit(L(g), right - M, fg), M, y, fg); y += 16
            for (sec, ls) in secs {
                need(14); draw(L(sec), M + 6, y, fb, .darkGray); y += 13
                for l in ls { let pr = E.price(l.pk); row("  " + l.label, qfmt(l.qty) + " " + l.unit, nf(pr), nf(l.qty * pr), fp) }
            }
        }
        y += 8
        let tot: [(String, Double)] = [(t("eMat"), E.mat), (t("eLogiS"), E.logi), (t("eWork").components(separatedBy: ",")[0], E.work), (t("eReserve").components(separatedBy: ",")[0], E.res), (t("eGrand"), E.total)]
        for (i, kv) in tot.enumerated() { need(16); let f = i == 4 ? fT : fb; draw(L(kv.0), M, y, f); draw(money(kv.1), right, y, f, right: true); y += 16 }
        need(30); y += 10; draw(fit(L(t("fNote")), right - M, fp), M, y, fp, .gray)
    }
    shareFile("estimate.pdf", data)
}

// ---------- график ----------
func schedFmt(_ d: Date, _ pat: String = "d MMM") -> String {
    let f = DateFormatter(); f.calendar = utcCal; f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = pat
    f.locale = Locale(identifier: St.lang == "en" ? "en_GB" : (St.lang == "uzc" ? "uz-Cyrl" : St.lang)); return f.string(from: d)
}
func daysBetween(_ a: Date, _ b: Date) -> Int { utcCal.dateComponents([.day], from: a, to: b).day ?? 0 }
struct ScheduleScreen: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let s = SC(); let R = buildSchedule()
        Page {
            TopBar(T("mSched"), { go("home") })
            Sec {
                TextIn(T("scStart") + " (ГГГГ-ММ-ДД)", s.s("start")) { v in if parseDate(v) != nil { s["start"] = v } else { toast("⚠️ 2026-11-16") } }
                Hint(T("scCrew")); Chips { ForEach([2.0, 3.0, 4.0, 6.0, 8.0], id: \.self) { n in Chip(fmt(n) + " 👷", s.n("crew") == n) { s["crew"] = n } } }
                Hint(T("scDays")); Chips { ForEach([5.0, 6.0, 7.0], id: \.self) { n in Chip(fmt(n), s.n("days") == n) { s["days"] = n } } }
                Chips { Chip(T("scPar"), s.b("par")) { s["par"] = true }; Chip(T("scSeq"), !s.b("par")) { s["par"] = false } }
            }
            Sec { Stat(T("scStart"), schedFmt(R.start) + " " + schedFmt(R.start, "yyyy")); Stat(T("scFinish"), schedFmt(R.end) + " " + schedFmt(R.end, "yyyy"), accent: true); Stat(T("scTotalDays"), String(daysBetween(R.start, R.end) + 1)) }
            Sec(T("scGantt")) { Gantt(R: R) }
            Sec(T("scStages")) { stages(R) }
            Sec(T("scMonthly")) { monthly(R) }
            HintOut("⚠️ " + T("scNote"))
        }
    }
    @ViewBuilder func stages(_ R: Schedule) -> some View {
        ForEach(Array(R.stages.enumerated()), id: \.offset) { _, x in
            Divider1()
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(hexColor(x.col)).frame(width: 10, height: 10)
                Txt((x.g.isEmpty ? "" : x.g + " — ") + x.name, 14).frame(maxWidth: .infinity, alignment: .leading)
                if x.cost > 0 { Txt(money(x.cost), 13, bold: true) }
            }.padding(.top, 6)
            Hint("\(schedFmt(x.st)) – \(schedFmt(x.en)) · \(x.dur) \(T("scDaysU"))" + (x.cureEnd.map { " + \(T("scCure")) \(daysBetween(x.en, $0)) \(T("scDaysU"))" } ?? ""), top: 0)
        }
    }
    func monthData(_ R: Schedule) -> [(String, Double)] {
        var months: [String: Double] = [:]
        for x in R.stages where x.cost > 0 {
            let n = Double(daysBetween(x.st, x.en) + 1); var dd = x.st
            while dd <= x.en { let k = schedFmt(dd, "yyyy-MM"); months[k, default: 0] += x.cost / n; dd = plusDays(dd, 1) }
        }
        return months.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }
    @ViewBuilder func monthly(_ R: Schedule) -> some View {
        let months = monthData(R); let mx = max(1, months.map { $0.1 }.max() ?? 1)
        if !R.anyCost { Hint(T("scNoPrice"), top: 0) }
        else {
            ForEach(Array(months.enumerated()), id: \.offset) { _, kv in
                HStack(spacing: 6) {
                    Txt(kv.0, 12, C.muted).frame(width: 62, alignment: .leading)
                    GeometryReader { g in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color(hex: 0x1E293B)); RoundedRectangle(cornerRadius: 4).fill(C.accent).frame(width: g.size.width * CGFloat(kv.1 / mx)) } }.frame(height: 16)
                    Txt(money(kv.1), 12, bold: true, align: .trailing).frame(width: 110, alignment: .trailing)
                }.padding(.vertical, 3)
            }
        }
    }
}
struct Gantt: View {
    let R: Schedule
    var body: some View {
        let days = daysBetween(R.start, R.end) + 1; let w = min(max(360, days * 4), 2000)
        ScrollView(.horizontal) {
            Canvas { c, size in
                let d = DC(c, size); let W = d.W
                func X(_ dd: Date) -> Double { 8 + Double(daysBetween(R.start, dd)) / Double(days + 1) * (W - 16) }
                var dd = R.start
                while dd <= R.end {
                    if utcCal.component(.day, from: dd) == 1 || dd == R.start { d.rc(X(dd), 16, X(dd) + 1, Double(size.height), Color(hex: 0x334155)); d.text(schedFmt(dd, "dd.MM"), X(dd) + 2, 12, Color(hex: 0x94A3B8), 9) }
                    dd = plusDays(dd, 1)
                }
                for (i, x) in R.stages.enumerated() {
                    let y = Double(24 + i * 26)
                    d.rc(X(x.st), y, X(x.st) + max(3, X(plusDays(x.en, 1)) - X(x.st)), y + 16, hexColor(x.col))
                    let lbl = (x.g.isEmpty ? "" : x.g + " · ") + x.name; let xe = X(plusDays(x.en, 1)); let tw = d.textW(lbl, 10)
                    d.text(lbl, xe + 4 + tw < W ? xe + 4 : max(2, X(x.st) - 4 - tw), y + 12, Color(hex: 0xE2E8F0), 10)
                    if let c = x.cureEnd { d.rc(X(plusDays(x.en, 1)), y + 4, X(c), y + 12, argb(0x7394A3B8)) }
                }
            }.frame(width: CGFloat(w), height: CGFloat(40 + R.stages.count * 26))
        }
    }
}
