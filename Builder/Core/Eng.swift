import Foundation

/// строка сметы: группа, ключ цены, название, количество, единица
final class Line { let g: String?; let pk: String; let label: String; let qty: Double; let unit: String; var sec: String?
    init(_ g: String?, _ pk: String, _ label: String, _ qty: Double, _ unit: String, _ sec: String? = nil) { self.g = g; self.pk = pk; self.label = label; self.qty = qty; self.unit = unit; self.sec = sec } }
final class LB { var L = [Line](); func add(_ g: String?, _ pk: String, _ label: String, _ q: Double, _ u: String) { if q > 0 { L.append(Line(g, pk, label, q, u)) } } }
/// словарь с порядком вставки (аналог linkedMapOf)
struct OD { var keys = [String](); var d = [String: Double]()
    subscript(_ k: String) -> Double? { get { d[k] } set { if let v = newValue { if d[k] == nil { keys.append(k) }; d[k] = v } } }
    var values: [Double] { keys.map { d[$0]! } }
    var sum: Double { values.reduce(0, +) } }
func notFalse(_ v: Any?) -> Bool { (v as? Bool) != false }

// ---------- инженерия ----------
func engDef(_ b: Obj) -> Obj { let h = eq(b["kind"], "house")
    return obj(("ph", 1.0), ("kw", 15.0), ("wInLen", 15.0), ("gas", nil), ("elec", true), ("inLen", 25.0), ("water", h ? "city" : "none"),
               ("wellD", 40.0), ("wellDist", 10.0), ("sewer", h ? "septic" : "none"), ("outLen", 12.0), ("res", 4.0), ("heat", h ? "gas" : "none"), ("gasLen", 20.0), ("vent", h ? "exhaust" : "none")) }
@discardableResult func ENG(_ b: Obj) -> Obj { keep(b, "eng", engDef(b)) }
func gasOn(_ b: Obj) -> Bool { let e = ENG(b); if e["gas"] != nil { return truthy(e["gas"]) }; return ["gas", "floor", "combi"].contains(e.s("heat")) }
func calcEng(_ b: Obj) -> Obj {
    let e = ENG(b); let r = obj(); let rl = arr(); r["rooms"] = rl
    let lv = levels(b); let rs: [Obj] = ["poly", "open"].contains(b.o("walls").s("mat")) ? [] : ensureRooms(b).filter { q in lv.contains(where: { lvEq($0, q["lv"]) }) }
    var S2 = 0.0; var L = 0.0; var W = 0.0; var s110 = 0.0; var s50 = 0.0; var heatA = 0.0; var secs = 0.0; var heated = 0.0
    for q in rs { let k = (D.o("RENG").aa(q.s("type")) ?? arr(2.0, 0.0, 0.0, 0.0, 1.0)).nums; let a = rA(q); let l = max(1.0, (a / 10).rounded(.up))
        S2 += k[0]; L += l; W += k[1]; s110 += k[2]; s50 += k[3]
        if k[4] != 0 { heatA += a; secs += (a * 100 / 180).rounded(.up); heated += a > 20 ? 2 : 1 }
        rl.add(arr(q, k[0], l, k[1])) }
    let nR = Double(rs.count)
    r["sock"] = S2; r["lights"] = L; r["switches"] = nR; r["wp"] = W; r["s110"] = s110; r["s50"] = s50; r["heatA"] = heatA; r["kw"] = max(6.0, (heatA * 0.12).rounded(.up)); r["secs"] = secs; r["radN"] = heated
    if e.b("elec") && !rs.isEmpty { r["cab25"] = S2 * RT("cabSock"); r["cab15"] = (L + nR) * RT("cabLight"); r["boxes"] = S2 + nR + (nR * 1.5).rounded(.up); let sg = (S2 / 6).rounded(.up); let lg = (nR / 4).rounded(.up)
        r["breakers"] = sg + lg + 3; r["rcd"] = (sg / 3).rounded(.up) + 1; r["board"] = r.n("breakers") + r.n("rcd") * 2 + 4 <= 24 ? 24.0 : 36.0 }
    if e.s("water") != "none" && W != 0 { r["ppr20"] = W * RT("pprPoint") + Double(mround(W * 0.7)) * RT("pprPoint"); r["fit"] = W * 6; r["valves"] = W + 2; r["heater"] = (s110 > 0 || W > 2) ? 1.0 : 0.0
        if e.s("water") == "well" { r["casing"] = e.n("wellD"); r["pump"] = 1.0; r["pe32"] = e.n("wellDist") + e.n("wellD") } }
    if e.s("sewer") != "none" && (s110 != 0 || s50 != 0) { r["p110"] = s110 * 3 + e.n("outLen"); r["p50"] = s50 * 4; r["sfit"] = (s110 + s50) * 3 + 4
        if e.s("sewer") == "septic" { let vol = max(2.0, e.n("res") * 0.6); r["rings"] = (vol / 0.7).rounded(.up) + 2; r["lids"] = 2.0 } }
    let heat = e.s("heat")
    if ["gas", "elboil", "combi"].contains(heat) && heatA != 0 { if heat != "elboil" { r["boiler"] = 1.0 }; if heat != "gas" { r["boilerE"] = 1.0 }; r["ppr25"] = heated * 12 + 10; r["tank"] = 1.0 }
    if heat == "electric" && heatA != 0 { r["conv"] = heated }
    if heat == "floor" && heatA != 0 { r["pex"] = heatA * 6.7; r["mani"] = (heated / 8).rounded(.up); r["eps"] = heatA * 1.05; r["boiler"] = 1.0 }
    if heat == "stove" { r["stove"] = 1.0; r["chim"] = b.n("floors") * b.n("floorH") + 1.5 }
    let nWet = Double(rs.filter { q in let k = (D.o("RENG").aa(q.s("type")) ?? arr()).nums; return k.count > 3 && (k[2] + k[3] > 0) }.count); r["nWet"] = nWet
    switch e.s("vent") {
    case "exhaust": if nWet > 0 { r["fans"] = nWet; r["duct100"] = nWet * 3; r["supplyVal"] = max(0.0, nR - nWet) }
    case "mvhr": if nR > 0 { r["recup"] = 1.0; r["duct160"] = nR * 6 + 10; r["diff"] = nR + nWet; r["ductIns"] = 10.0 }
    default: break
    }
    if gasOn(b) { r["gasPipe"] = e.n("gasLen") + 6; r["meter"] = 1.0; r["gasStove"] = rs.contains(where: { eq($0["type"], "kitchen") }) ? 1.0 : 0.0 }
    return r
}
func engLines(_ b: Obj) -> [Line] {
    let e = ENG(b); let r = calcEng(b); let B = LB(); let pc = t("uPcs"); let m = t("m"); let m2 = t("m2"); func a(_ g: String, _ pk: String, _ l: String, _ q: Double, _ u: String) { B.add(g, pk, l, q, u) }
    let ph3 = e.n("ph") == 3; let ph = fmt(e.n("ph"))
    if e.b("elec") { a("gElec", "e_sock", t("iSocket"), r.n("sock"), pc); a("gElec", "e_sw", t("iSwitch"), r.n("switches"), pc); a("gElec", "e_lamp", t("iLamp"), r.n("lights"), pc)
        a("gElec", "e_c25", t("iCable25"), r.n("cab25"), m); a("gElec", "e_c15", t("iCable15"), r.n("cab15"), m)
        a("gElec", "e_box", t("iBoxes"), r.n("boxes"), pc); a("gElec", "e_brk", t("iBreaker"), r.n("breakers"), pc); a("gElec", "e_rcd", t("iRcd"), r.n("rcd"), pc)
        let bd = r["board"].map { fmt(num($0)) } ?? "undefined"
        a("gElec", "e_board\(bd)", t("iBoard") + " " + bd + " мод.", r.n("board") != 0 ? 1.0 : 0.0, pc)
        a("gElec", "e_sip\(ph)", t("iInput") + (ph3 ? " (СИП-4 4×16)" : " (СИП-2 2×16)"), e.n("inLen"), m); a("gElec", "e_earth", t("iEarth"), r.n("sock") != 0 ? 1.0 : 0.0, pc)
        a("gElec", "e_meter\(ph)", t("iElMeter") + (ph3 ? " 3Ф" : " 1Ф"), 1.0, pc)
        a("gElec", "e_main\(ph)", t("iMainBrk") + " " + (ph3 ? "3P " : "2P ") + fmt(max(25.0, (e.n("kw") * 1000 / (ph3 ? 660 : 220) / 5).rounded(.up) * 5)) + " А", 1.0, pc)
        a("gElec", "e_uzip\(ph)", t("iUzip"), 1.0, pc); a("gElec", "e_meterbox", t("iMeterBox"), 1.0, pc)
        a("gElec", "e_corr", t("iCorr"), Double(mround((r.n("cab25") + r.n("cab15")) * 0.7)), m); a("gElec", "e_conn", t("iConnE"), 1.0, pc) }
    a("gWater", "w_ppr20", t("iPpr20"), r.n("ppr20"), m); a("gWater", "w_fit", t("iFit"), r.n("fit"), pc); a("gWater", "w_valve", t("iValve"), r.n("valves"), pc); a("gWater", "w_heater", t("iHeater"), r.n("heater"), pc)
    a("gWater", "w_casing", t("iCasing"), r.n("casing"), m); a("gWater", "w_pump", t("iPump"), r.n("pump"), pc); a("gWater", "w_pe32", t("iPe32"), r.n("pe32"), m)
    if e.s("water") == "well" && r.n("pump") != 0 { a("gWater", "w_acc", t("iAcc"), 1.0, pc); a("gWater", "w_relay", t("iRelay"), 1.0, pc) }
    if e.s("water") != "none" && r.n("ppr20") != 0 { a("gWater", "w_wmeter", t("iWMeter"), 1.0, pc); a("gWater", "w_filter", t("iWFilter"), 1.0, pc); a("gWater", "w_check", t("iWCheck"), 1.0, pc) }
    if e.s("water") == "city" && r.n("ppr20") != 0 { a("gWater", "w_pnd32", t("iPnd32"), e.n("wInLen"), m); a("gWater", "w_tapin", t("iTapIn"), 1.0, pc); a("gWater", "w_conn", t("iConnW"), 1.0, pc) }
    a("gSewer", "s_110", t("iP110"), r.n("p110"), m); a("gSewer", "s_50", t("iP50"), r.n("p50"), m); a("gSewer", "s_fit", t("iSfit"), r.n("sfit"), pc); a("gSewer", "s_ring", t("iRings"), r.n("rings"), pc); a("gSewer", "s_lid", t("iLids"), r.n("lids"), pc)
    a("gHeat", "h_boiler" + (e.s("heat") == "floor" ? "F" : ""), t("iBoiler") + " " + fmt(r.n("kw")) + " кВт", r.n("boiler"), pc); a("gHeat", "h_boilerE", t("iBoilerE") + " " + fmt(r.n("kw")) + " кВт", r.n("boilerE"), pc)
    a("gHeat", "h_rad", t("iRad"), ["gas", "elboil", "combi"].contains(e.s("heat")) ? r.n("secs") : 0.0, pc)
    a("gHeat", "h_ppr25", t("iPpr25"), r.n("ppr25"), m); a("gHeat", "h_tank", t("iTank"), r.n("tank"), pc)
    a("gHeat", "h_conv", t("iConv"), r.n("conv"), pc); a("gHeat", "h_pex", t("iPex"), r.n("pex"), m); a("gHeat", "h_mani", t("iMani"), r.n("mani"), pc); a("gHeat", "h_eps", t("iEps"), r.n("eps"), m2)
    a("gHeat", "h_stove", t("iStove"), r.n("stove"), pc); a("gHeat", "h_chim", t("iChim"), r.n("chim"), m)
    a("gGas", "g_pipe", t("iGasPipe"), r.n("gasPipe"), m); a("gGas", "g_meter", t("iMeter"), r.n("meter"), pc); a("gGas", "g_stove", t("iGasStove"), r.n("gasStove"), pc)
    if r.n("meter") != 0 { a("gGas", "g_valve", t("iGasValve"), 2 + r.n("gasStove") + r.n("boiler"), pc); a("gGas", "g_alarm", t("iGasAlarm"), 1.0, pc); a("gGas", "g_hose", t("iGasHose"), r.n("gasStove") + r.n("boiler"), pc); a("gGas", "g_conn", t("iConnG"), 1.0, pc) }
    a("gVent", "v_fan", t("iFan"), r.n("fans"), pc); a("gVent", "v_duct100", t("iDuct100"), r.n("duct100"), m); a("gVent", "v_supply", t("iSupplyVal"), r.n("supplyVal"), pc)
    a("gVent", "v_recup", t("iRecup"), r.n("recup"), pc); a("gVent", "v_duct160", t("iDuct160"), r.n("duct160"), m); a("gVent", "v_diff", t("iDiff"), r.n("diff"), pc); a("gVent", "v_ins", t("iDuctIns"), r.n("ductIns"), m)
    if e.s("sewer") == "central" && (r.n("p110") != 0 || r.n("p50") != 0) { a("gSewer", "s_conn", t("iConnS"), 1.0, pc) }
    return B.L
}

// ---------- подвал ----------
func calcBasement(_ b: Obj) -> Obj? {
    let B = b.oo("basement") ?? obj(); if !B.b("on") || !eq(b["kind"], "house") { return nil }
    let h = B.nz("h", 2.4); let wt = B.str("wt") ?? "fbs"; let bw = 0.5; let r = obj(("h", h), ("wt", wt))
    let Lc = bPer(b) - 4 * bw; let P = bPer(b); let A = inArea(b, bw); r["L"] = Lc; r["dig"] = (bArea(b) + bPer(b) * 0.6 + 1.44) * (h + 0.4)
    if wt == "fbs" { let rows = (h / 0.59).rounded(.up); let c = fbsCount(Lc, "24.5.6", rows); r["fbs"] = c.pcs; r["insertV"] = c.restV * 1.05; r["fbsW"] = c.pcs * 2.38 * 0.5 * 0.58 * 2.4; r["mortarBags"] = (c.pcs * 0.02 * 300 / 50).rounded(.up) }
    else { r["wallV"] = Lc * 0.3 * h * 1.05; r["wallRebar"] = Lc * h * 20 * 0.888; r["wallForm"] = 2 * Lc * h }
    r["floorV"] = A * 0.15 * 1.05; r["floorRebar"] = A * 10 * 0.617; r["gravel"] = A * 0.15; r["sand"] = A * 0.1; r["wp"] = P * h * 1.1 * 2.5; r["xps"] = P * h * 1.05; r["drain"] = P + 8; r["geo"] = r.n("drain") * 1.5
    return r
}
func basementLines(_ b: Obj) -> [Line] {
    guard let r = calcBasement(b) else { return [] }; let B = LB(); let pc = t("uPcs"); let m3 = t("uM3"); let kg = t("uKg"); let m2 = t("m2"); let m = t("m"); let bs = t("bsTitle") + ": "
    func a(_ pk: String, _ l: String, _ q: Double, _ u: String) { B.add(nil, pk, bs + l, q, u) }
    a("dig", t("bsDig"), r.n("dig"), m3)
    if r.n("fbs") != 0 { a("fbs_24.5.6", "ФБС 24.5.6 (ГОСТ 13579-2018)", r.n("fbs"), pc); a("conc_M200", t("fInsert"), r.n("insertV"), m3); a("cement50", t("fJoint"), r.n("mortarBags"), t("uBags")) }
    if r.n("wallV") != 0 { a("conc_M250", t("eConcrete") + " M250", r.n("wallV"), m3); a("rebar12", t("eRebar") + " Ø12", r.n("wallRebar"), kg); a("board", t("eBoard"), r.n("wallForm") * 0.025, m3) }
    a("conc_M200", t("bsFloor"), r.n("floorV"), m3); a("rebar10", t("eRebar") + " Ø10", r.n("floorRebar"), kg); a("gravel", t("eGravel"), r.n("gravel"), m3); a("sand", t("eSand"), r.n("sand"), m3)
    a("bitumen", t("bsWp"), r.n("wp"), kg); a("xps50", t("bsXps"), r.n("xps"), m2); a("drain110", t("bsDrain"), r.n("drain"), m); a("geotex", t("bsGeo"), r.n("geo"), m2)
    return B.L
}

// ---------- свои материалы и доп. работы ----------
func extrasOf(_ b: Obj, _ sec: String) -> Arr { b.o("extras").a(sec) }
func extrasLines(_ b: Obj, _ sec: String) -> [Line] {
    let um: [String: String] = ["pcs": "uPcs", "m2": "m2", "m": "m", "m3": "uM3", "kg": "uKg"]
    return extrasOf(b, sec).objs.filter { $0.n("qty") > 0 }.map { x in
        let nm = x.s("name").isEmpty ? t("fnCustom") : x.s("name")
        return Line(nil, "x_" + x.s("uid"), "✏️ \(nm)\(x.s("size").isEmpty ? "" : " " + x.s("size"))", x.n("qty"), t(um[x.s("unit")] ?? "uPcs")) }
}
@discardableResult func EXD(_ b: Obj) -> Obj {
    let ex = b.o("ex"); let h = eq(b["kind"], "house")
    let d: [(String, Obj)] = [("blind", obj(("on", h), ("w", 1.0), ("t", 0.1), ("type", "conc"))), ("porch", obj(("on", h), ("w", 2.0), ("d", 1.5), ("h", 0.6), ("mat", "conc"))),
        ("stair", obj(("on", true), ("type", "wood"), ("w", 0.9))), ("drain", obj(("on", false), ("type", "tray"), ("out", 10.0)))]
    for (k, v) in d { ex[k] = assign(v, ex.oo(k)) }; return ex
}
func calcExtra(_ b: Obj) -> Obj {
    let e = EXD(b); let r = obj(); let P = bPer(b)
    let bl = e.o("blind"); if bl.b("on") { let w = bl.n("w"); let Pp = P + 4 * w; let A = Pp * w; r["blindA"] = A
        if eq(bl["type"], "conc") { r["bV"] = A * bl.n("t") * 1.05; r["bMesh"] = A * 1.05; r["bGravel"] = A * 0.1; r["bSand"] = A * 0.1; r["bDamp"] = Pp }
        else { r["bTiles"] = A * 1.05; r["bCurb"] = Pp; r["bSand"] = A * 0.05; r["bGravel"] = A * 0.15; r["bGeo"] = A * 1.1 } }
    let p = e.o("porch"); if p.b("on") { let n = max(1.0, Double(mround(p.n("h") / 0.17))); let run = p.n("d") + n * 0.3; let pw = p.n("w"); let ph = p.n("h"); r["pSteps"] = n; r["pTop"] = pw * run + n * pw * 0.17
        switch p.s("mat") {
        case "conc": r["pV"] = pw * run * ph * 0.55; r["pRebar"] = r.n("pV") * 80; r["pForm"] = 2 * run * ph + pw * ph
        case "brick": r["pBricks"] = ((2 * run + pw) * ph * 102 * 1.05).rounded(.up); r["pV"] = pw * run * 0.12 + 0.2; r["pFill"] = pw * run * ph * 0.8
        default: r["pDeck"] = r.n("pTop") * 1.1; r["pJoist"] = (pw / 0.5 + 1) * run
        }
        r["pTile"] = eq(p["mat"], "wood") ? 0.0 : r.n("pTop") * 1.1; r["pRail"] = ph > 0.45 ? run * 2 : 0.0 }
    let flights: Double = ["poly", "open"].contains(b.o("walls").s("mat")) ? 0 : Double(max(0, levels(b).count - 1)); let s = e.o("stair")
    if s.b("on") && flights != 0 { let H = b.n("floorH"); let n = (H / 0.175).rounded(.up); let run = n * 0.28; let len = hypot2(H, run); let sw = s.n("w"); r["sFl"] = flights; r["sSteps"] = n
        switch s.s("type") {
        case "wood": r["sStringer"] = 2 * len * 1.1 * flights * 0.05 * 0.3; r["sTread"] = n * flights * sw * 0.3 * 0.04 * 1.1; r["sBal"] = (run / 0.15).rounded(.up) * flights
        case "conc":
            let sv1: Double = sw * len * 0.15; let sv2: Double = n * sw * 0.28 * 0.175 / 2
            r["sV"] = (sv1 + sv2) * flights * 1.05; r["sRebar"] = r.n("sV") * 90
            let sf1: Double = sw * len; let sf2: Double = 2 * len * 0.3
            r["sForm"] = (sf1 + sf2) * flights
        default: r["sChannel"] = 2 * len * 1.1 * flights; r["sMetalSteps"] = n * flights; r["sBal"] = (run / 0.15).rounded(.up) * flights
        }
        r["sRail"] = (len + 1) * flights }
    let dr = e.o("drain"); if dr.b("on") { let pipes = eq(b["kind"], "greenhouse") ? 2.0 : calcRoof(b).nz("pipes", 4.0)
        if eq(dr["type"], "tray") { r["dTray"] = P.rounded(.up); r["dGrate"] = r["dTray"]; r["dTrap"] = pipes; r["dPipe"] = dr.n("out") } else { r["dPipe"] = P + dr.n("out"); r["dInlet"] = pipes } }
    return r
}
func extraLines(_ b: Obj) -> [Line] {
    let r = calcExtra(b); let B = LB(); let pc = t("uPcs"); let m3 = t("uM3"); let kg = t("uKg"); let m2 = t("m2"); let m = t("m")
    func a(_ g: String, _ pk: String, _ l: String, _ k: String, _ u: String, _ mul: Double = 1.0) { B.add(g, pk, l, r.n(k) * mul, u) }
    a("exBlind", "conc_M200", t("iBlindConc") + " M200", "bV", m3); a("exBlind", "mesh4", t("iMesh4"), "bMesh", m2); a("exBlind", "damper", t("iDamper"), "bDamp", m)
    a("exBlind", "tiles", t("iTiles"), "bTiles", m2); a("exBlind", "curb", t("iCurb"), "bCurb", m); a("exBlind", "sand", t("eSand"), "bSand", m3); a("exBlind", "gravel", t("eGravel"), "bGravel", m3); a("exBlind", "geotex", t("bsGeo"), "bGeo", m2)
    a("exPorch", "conc_M200", t("iPorchConc") + " M200", "pV", m3); a("exPorch", "rebar12", t("eRebar") + " Ø12", "pRebar", kg); a("exPorch", "board", t("eBoard"), "pForm", m3, 0.025)
    a("exPorch", "blk_brick_1NF_ceramFull_f", t("exBrick") + " 1НФ", "pBricks", pc); a("exPorch", "sand", t("eSand"), "pFill", m3); a("exPorch", "deck", t("mDeck"), "pDeck", m2); a("exPorch", "joist", t("mJoist"), "pJoist", m)
    a("exPorch", "porchTile", t("iPorchTile"), "pTile", m2); a("exPorch", "rail", t("iRail"), "pRail", m)
    a("exStair", "timber", t("iStringer"), "sStringer", m3); a("exStair", "timber", t("iTread"), "sTread", m3); a("exStair", "conc_M250", t("iStairConc") + " M250", "sV", m3); a("exStair", "rebar12", t("eRebar") + " Ø12", "sRebar", kg)
    a("exStair", "board", t("eBoard"), "sForm", m3, 0.025); a("exStair", "channel", t("iChannel"), "sChannel", m); a("exStair", "stepMetal", t("iStepMetal"), "sMetalSteps", pc); a("exStair", "baluster", t("iBal"), "sBal", pc); a("exStair", "rail", t("iRail"), "sRail", m)
    a("exDrain", "tray", t("iTray"), "dTray", pc); a("exDrain", "grate", t("iGrate"), "dGrate", pc); a("exDrain", "trap", t("iTrap"), "dTrap", pc); a("exDrain", "p110o", t("iP110o"), "dPipe", m); a("exDrain", "inlet", t("iInlet"), "dInlet", pc)
    return B.L
}

// ---------- теплица ----------
struct GH { var area: Double; var sheets: Double; var arches: Double; var frame: Double; var screws: Double; var arch: Double }
func ghCalc(_ b: Obj) -> GH {
    let s = min(b.n("w"), b.n("d")); let L = max(b.n("w"), b.n("d")); let h = b.n("floorH"); let ty = b.str("gh") ?? "gable"; let area: Double; let arch: Double; let frame: Double
    switch ty {
    case "arch": let a = s / 2; let c = h; arch = Double.pi * (3 * (a + c) - ((3 * a + c) * (a + 3 * c)).squareRoot()) / 2; area = arch * L + Double.pi * a * c; frame = (L.rounded(.down) + 1) * arch + 4 * L + 2 * (2 * c + s)
    case "lean": let r = s * 0.4; let sl = hypot2(s, r); area = L * h + s * (2 * h + r) + sl * L; arch = h + sl + h + r; frame = (L.rounded(.down) + 1) * arch + 4 * L
    default: let r = s * 0.4; let sl = hypot2(s / 2, r); area = 2 * (b.n("w") + b.n("d")) * h + 2 * sl * L + s * r; arch = 2 * h + 2 * sl; frame = (L.rounded(.down) + 1) * arch + 6 * L
    }
    let z = SZm("poly"); return GH(area: area, sheets: (area * 1.1 / (z[0] * z[1])).rounded(.up), arches: L.rounded(.down) + 1, frame: frame, screws: (area * 6).rounded(.up), arch: arch)
}
