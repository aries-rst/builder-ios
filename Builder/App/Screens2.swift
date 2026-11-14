import SwiftUI

func mn(_ v: Double) -> String { let m = money(v); if let i = m.lastIndex(of: " ") { return String(m[m.startIndex..<i]) }; return m }
func stv(_ v: Double, _ d: Int, _ u: String) -> String { fmt(v, d) + " " + u }
func opsTag(_ o: Obj) -> String { eq(o["type"], "door") ? "🚪 " + T("wDoor") : "🪟 " + T("wWindow") }
func clampD(_ v: Double, _ lo: Double, _ hi: Double) -> Double { min(max(v, lo), hi) }
func fdim(_ v: Any?) -> String { (v as? Arr)?.nums.map { fmt($0) }.joined(separator: "×") ?? "" }

// ---------- фундамент ----------
struct FoundScreen: View {
    @ObservedObject var u = UIS.shared
    func fd(_ f: Obj, _ k: String, _ key: String, _ z: Bool = false) -> NumField { NumField(T(k), f.n(key), zero: z) { f[key] = $0 } }
    var body: some View {
        let b = curB(); let f = b.o("f"); let r = calcFound(b); let m3 = T("uM3"); let m = T("m"); let type = f.s("type")
        Page {
            TopBar(T("mFound"), { go("home") }); BSelector()
            Sec(T("fType")) {
                Chips { ForEach(["strip", "fbs", "slab", "post"], id: \.self) { k in Chip(T(["strip": "fStrip", "fbs": "fFbs", "slab": "fSlab", "post": "fPost"][k]!), type == k) { f["type"] = k } } }
                Hint("\(itemName(b)): \(fmt(b.n("w"))) × \(fmt(b.n("d"))) \(m)")
            }
            Sec(T("fSection")) { Drawing(220) { drawSection($0, b) } }
            Sec(T("fParams")) { foundParams(b, f, type) }
            Sec(T("fMaterials")) { foundMaterials(b, f, r, type, m, m3) }
            if !["open", "poly"].contains(b.o("walls")["mat"] as? String ?? "") {
                Sec("🧻 " + T("fTol")) {
                    let tl = f.nz("tolL", 2.0)
                    Chips { ForEach([0.0, 1.0, 2.0, 3.0], id: \.self) { k in Chip(k > 0 ? T("lmL") + ": " + fmt(k) : T("oNone"), tl == k) { f["tolL"] = k } } }
                    if r.n("tolA") > 0 { Stat(T("mTol"), "\(fmt(r.n("tolRolls"))) \(T("uPcs")) · \(fmt(r.n("tolA"), 1)) \(T("m2"))") }
                    Hint(T("fTolHint"))
                }
            }
            HintOut("⚠️ " + T("fNote")); RateLink(back: "found")
            if eq(b["kind"], "house") { basementSec(b) }
            ExtrasUI(b: b, sec: "found")
        }
    }
    @ViewBuilder func basementSec(_ b: Obj) -> some View {
        let _ = ensureRooms(b); let B = b.o("basement")
        Sec("🕳️ " + T("bsTitle")) {
            Toggle1(B.b("on")) { B["on"] = $0 }
            if B.b("on") {
                NumField(T("lvBaseH"), B.n("h")) { B["h"] = clampD($0, 1.8, 4.0) }; Hint(T("bsWallT"))
                Chips { Chip(T("bsFbs"), (B["wt"] as? String ?? "fbs") == "fbs") { B["wt"] = "fbs" }; Chip(T("bsMono"), eq(B["wt"], "mono")) { B["wt"] = "mono" } }
                PricedList(ls: basementLines(b), totalKey: "exTotal")
            } else { Hint(T("bsOnHint")) }
        }
    }
    @ViewBuilder func foundParams(_ b: Obj, _ f: Obj, _ type: String) -> some View {
        switch type {
        case "strip":
            Txt(T("fOuter"), 14); HStack(spacing: 6) { fd(f, "fWidth", "b"); fd(f, "fDepth", "h") }
            Txt(T("fInnerW"), 14).padding(.top, 8); fd(f, "fInner", "inner", true)
            if f.n("inner") > 0 { HStack(spacing: 6) { fd(f, "fWidth", "bi"); fd(f, "fDepth", "hi") } }
        case "fbs":
            Hint(T("fFbsGost"), top: 0); Txt(T("fOuter"), 14)
            Chips { ForEach(Array(D.FBS.entries.enumerated()), id: \.offset) { _, e in Chip("ФБС \(e.0)", eq(f["fbs"], e.0), sub: fdim(e.1)) { f["fbs"] = e.0 } } }
            fd(f, "fRows", "rows"); Txt(T("fInnerW"), 14).padding(.top, 8); fd(f, "fInner", "inner", true)
            if f.n("inner") > 0 { Chips { ForEach(Array(D.FBS.entries.enumerated()), id: \.offset) { _, e in Chip("ФБС \(e.0)", eq(f["fbsIn"], e.0), sub: fdim(e.1)) { f["fbsIn"] = e.0 } } } }
            Chips { Check(T("fPad"), f.b("pad")) { f["pad"] = $0 } }
        case "slab":
            HStack(spacing: 6) { fd(f, "fSlabT", "slabT"); fd(f, "fMesh", "mesh") }
        default:
            HStack(spacing: 6) { fd(f, "fPostA", "a"); fd(f, "fPostDepth", "pd") }
            HStack(spacing: 6) { fd(f, "fPostStep", "step"); fd(f, "fInner", "inner", true) }
            Chips { Check(T("fGrill"), f.b("grill")) { f["grill"] = $0 } }
            if f.b("grill") { fd(f, "fWidth", "b") }
        }
        HStack(spacing: 6) { fd(f, "fSand", "sand", true); fd(f, "fGravel", "gravel", true) }
        Hint(T("fRebarD")); Chips { ForEach([10.0, 12.0, 14.0, 16.0], id: \.self) { x in Chip("Ø" + fmt(x), f.n("rd") == x) { f["rd"] = x } } }
        Hint(T("fGrade")); Chips { ForEach(D.o("MIX").keys, id: \.self) { x in Chip(x, eq(f["grade"], x)) { f["grade"] = x } } }
        Hint(T("fMix")); Chips { Chip(T("fReady"), eq(f["mix"], "ready")) { f["mix"] = "ready" }; Chip(T("fSelf"), eq(f["mix"], "self")) { f["mix"] = "self" } }
    }
    @ViewBuilder func foundMaterials(_ b: Obj, _ f: Obj, _ r: Obj, _ type: String, _ m: String, _ m3: String) -> some View {
        if r["L"] != nil { Stat(T("fLen") + " (" + T("fOuter").lowercased() + ")", stv(r.n("L"), 1, m)) }
        if r.n("Li") != 0 { Stat(T("fLen") + " (" + T("fInnerW").lowercased() + ")", stv(r.n("Li"), 1, m)) }
        if r["A"] != nil { Stat(T("fArea"), stv(r.n("A"), 1, T("m2"))) }
        if r["n"] != nil { Stat(T("fPosts"), fmt(r.n("n")) + " " + T("uPcs")) }
        if type == "fbs" {
            Stat("ФБС \(f.s("fbs"))", fmt(r.n("fbsOut")) + " " + T("uPcs"), accent: true)
            if r.n("fbsIn") != 0 { Stat("ФБС \(f.s("fbsIn"))", fmt(r.n("fbsIn")) + " " + T("uPcs"), accent: true) }
            Stat(T("fFbsWeight"), stv(r.n("fbsW"), 1, T("uT"))); Stat(T("fFbsH"), stv(r.n("fbsH"), 2, m))
            if r.n("insertV") > 0 { Stat(T("fInsert"), stv(r.n("insertV"), 2, m3)) }
            Stat(T("fJoint"), fmt(r.n("mortarBags")) + " " + T("uBags"))
        }
        if r.n("V") > 0 { Stat(T("fConcrete") + " " + f.s("grade"), stv(r.n("V"), 2, m3), accent: type != "fbs") }
        if eq(f["mix"], "self") && r.n("V") > 0 {
            Stat(T("fCement"), fmt(r.n("cement")) + " " + T("uBags")); Stat(T("fSandMix"), stv(r.n("sandMix"), 2, m3)); Stat(T("fGravelMix"), stv(r.n("gravelMix"), 2, m3)); Stat(T("fWater"), "\(mround(r.n("water"))) \(T("uL"))")
        }
        if r.n("mainM") != 0 { Stat(T("fRebarMain") + " Ø" + fmt(f.n("rd")), "\(fmt(r.n("mainM"), 0)) \(m) · \(fmt(r.n("mainKg"), 0)) \(T("uKg"))") }
        if r.n("clampM") != 0 { Stat(T("fRebarClamp"), "\(fmt(r.n("clampM"), 0)) \(m) · \(fmt(r.n("clampKg"), 0)) \(T("uKg"))") }
        if r.n("wire") != 0 { Stat(T("fWire"), stv(r.n("wire"), 1, T("uKg"))) }
        if r.n("form") != 0 { Stat(T("fForm"), "\(fmt(r.n("form"), 1)) \(T("m2")) · \(fmt(r.n("formM3"), 2)) \(m3)") }
        Stat(T("fBedSand"), stv(r.n("bedSand"), 2, m3)); Stat(T("fBedGravel"), stv(r.n("bedGravel"), 2, m3)); Stat(T("fDig"), stv(r.n("dig"), 1, m3))
        if type == "fbs" { Hint("🏗️ " + T("fCrane")) }
        Hint(T("fPriceNote"))
    }
}

// ---------- стены ----------
struct WallsScreen: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let b = curB(); let W = b.o("walls"); let mat = W.s("mat")
        if mat == "poly" || mat == "open" { WallsSpecial(b: b) } else { WallsMain(b: b) }
    }
}
struct WallsMain: View {
    @ObservedObject var u = UIS.shared
    let b: Obj
    func prep(_ W: Obj, _ th: [Double]) {
        if !W.b("tc") && !th.contains(where: { abs($0 - W.n("t")) < 1e-6 }) { W["t"] = th[min(1, th.count - 1)]; Store.save() }
    }
    func pbLen(_ k: String) -> Double { (D.a("PB").compactMap { $0 as? Arr }.first { $0.s(0) == k })?.n(1) ?? 0 }
    var body: some View {
        let W = b.o("walls"); let mat = W.s("mat"); let m = MI(W) ?? D.WMAT.o("gas"); let th = m.a("th").nums
        let _ = prep(W, th)
        let r = calcWalls(b); let sl = calcSlabs(b); let m3 = T("uM3"); let mm = T("m")
        Page {
            TopBar(T("mWalls"), { go("home") }); BSelector()
            Sec(T("wMaterial")) { material(W, mat, m, th) }
            Sec(T("wFacade")) { Drawing(230) { drawFacade($0, b) } }
            SzLink(back: "walls")
            Sec(T("wOpenings")) { openings(W) }
            Sec(T("wInner")) { inner(W, r, mm) }
            Sec(T("wSlab")) { slab(W, sl, mm, m3) }
            Sec(T("fMaterials")) { materials(W, m, r, mm, m3) }
            HintOut("⚠️ " + T("fNote")); RateLink(back: "walls"); ExtrasUI(b: b, sec: "walls")
        }
    }
    @ViewBuilder func material(_ W: Obj, _ mat: String, _ m: Obj, _ th: [Double]) -> some View {
        let half = ["½", "1", "1½", "2"]
        Chips {
            ForEach(Array(D.WMAT.entries.enumerated()), id: \.offset) { _, e in Chip(tr3((e.1 as! Obj)["n"]), mat == e.0) { W["mat"] = e.0 } }
            Chip("✏️ " + T("fnCustom"), mat == "custom") { W["mat"] = "custom"; W["tc"] = true; if W["cm"] == nil { W["cm"] = obj(("name", ""), ("L", 390.0), ("H", 190.0), ("glue", false), ("dens", 1200.0)) } }
        }
        if mat == "custom" {
            let cm = W.o("cm")
            TextIn(T("cmName"), cm.s("name")) { cm["name"] = $0 }
            HStack(spacing: 4) { NumField(T("cmL"), cm.n("L")) { cm["L"] = $0 }; NumField(T("cmH"), cm.n("H")) { cm["H"] = $0 }; NumField(T("cmDens"), cm.n("dens")) { cm["dens"] = $0 } }
            Chips { Chip(T("cmGlue"), cm.b("glue")) { cm["glue"] = true }; Chip(T("cmMortar"), !cm.b("glue")) { cm["glue"] = false } }
        }
        Hint(T("wThick"))
        Chips {
            ForEach(Array(th.enumerated()), id: \.offset) { i, x in
                Chip(m.n("D") != 0 ? "\(fmt(x * 100, 1)) см (\(half[safe: i] ?? "") \(T("wBricks")))" : "\(fmt(x * 100, 1)) см", abs(W.n("t") - x) < 1e-6) { W["t"] = x; W["tc"] = false }
            }
        }
        if m.b("brick") {
            Hint(T("wBrickFmt"))
            Chips {
                ForEach(Array(D.BFMT.entries.enumerated()), id: \.offset) { _, e in let v = e.1 as! Obj
                    Chip(tr3(v["n"]), eq(W["bf"], e.0), sub: "\(fmt(v.n("L") * 1000))×\(fmt(v.n("D") * 1000))×\(fmt(v.n("H") * 1000))") { W["bf"] = e.0 } }
                Chip("📏 " + szj("brick"), eq(W["bf"], "custom")) { W["bf"] = "custom" }
            }
            Hint(T("wBrickType")); Chips { ForEach(Array(D.BTYPE.entries.enumerated()), id: \.offset) { _, e in Chip(tr3((e.1 as! Obj)["n"]), eq(W["bt"], e.0)) { W["bt"] = e.0 } } }
            Hint("📄 \(m.s("gost")) · \(T("wDens")) \(fmt(m.n("dens"))) кг/м³")
        } else { NumField(T("wCustomT"), W.n("t") * 100) { W["t"] = $0 / 100; W["tc"] = true } }
        Hint("\(itemName(b)): \(fmt(b.n("w"))) × \(fmt(b.n("d"))) \(T("m")), \(fmt(b.n("floors"))) × \(fmt(b.n("floorH"))) \(T("m"))")
    }
    @ViewBuilder func openings(_ W: Obj) -> some View {
        if !manOuter(b).isEmpty { Hint(T("opManHint"), top: 0) }
        let ops = W.a("openings")
        ForEach(Array(ops.objs.enumerated()), id: \.offset) { i, o in
            let d = opDef(o); let isDoor = eq(o["type"], "door")
            Divider1()
            HStack(alignment: .bottom, spacing: 4) {
                Txt(opsTag(o), 13, isDoor ? hexColor("#FDBA74") : hexColor("#7DD3FC")).frame(width: 70, alignment: .leading).padding(.bottom, 12)
                NumField(T("wW"), o.n("w")) { o["w"] = $0 }; NumField(T("wH"), o.n("h")) { o["h"] = $0 }
                NumField(T("wQty"), o.n("q")) { o["q"] = $0.rounded(.toNearestOrAwayFromZero) }.frame(width: 64)
                IconBtn("✕", C.warn) { ops.a.remove(at: i); upd() }
            }
            Chips { ForEach(Array((isDoor ? D.o("DOORMAT") : D.o("WINMAT")).entries.enumerated()), id: \.offset) { _, e in Chip(tr3(e.1), eq(d["mat"], e.0)) { o["mat"] = e.0 } } }
            Chips { ForEach(Array(D.o("OCOL").entries.enumerated()), id: \.offset) { _, e in ColorChip(hexColor((e.1 as! Arr).s(1)), eq(d["col"], e.0), w: 34) { o["col"] = e.0 } } }
            Hint(tr3((D.o("OCOL").aa(d.s("col")) ?? D.o("OCOL").a("white")).at(0)), top: 0)
            if !isDoor { Chips { ForEach([1.0, 2.0, 3.0], id: \.self) { g in Chip(fmt(g) + "-" + T("wGlz"), d.n("glz") == g) { o["glz"] = g } } } }
        }
        HStack(spacing: 6) {
            OBtn(T("wAddWin")) { ops.add(obj(("type", "win"), ("w", 1.2), ("h", 1.2), ("q", 1.0))); upd() }
            OBtn(T("wAddDoor")) { ops.add(obj(("type", "door"), ("w", 1.0), ("h", 2.1), ("q", 1.0))); upd() }
        }
        Hint("🏡 " + T("wNote3d"))
    }
    @ViewBuilder func inner(_ W: Obj, _ r: Obj, _ mm: String) -> some View {
        let auto = (W["innerAuto"] as? Bool) != false
        Chips { Chip("📐 " + T("wPartAuto"), auto) { W["innerAuto"] = true }; Chip("✏️ " + T("wPartMan"), !auto) { W["innerAuto"] = false } }
        if auto { Stat(T("wPartRes"), "\(fmt(r.n("partLen"), 1)) \(mm) · \(fmt(r.n("partA"), 1)) \(T("m2"))") }
        HStack(spacing: 6) {
            if !auto { NumField(T("wInnerLen"), W.n("innerLen"), zero: true) { W["innerLen"] = $0 } }
            NumField(T("wInnerT"), W.n("innerT")) { W["innerT"] = $0 }
        }
        Chips { if hasGables(b) { Check(T("wGables"), W.b("gables")) { W["gables"] = $0 } }; Check(T("wBelt"), W.b("belt")) { W["belt"] = $0 } }
    }
    @ViewBuilder func slab(_ W: Obj, _ sl: Obj, _ mm: String, _ m3: String) -> some View {
        Chips { ForEach([("pk", "wSlabPk"), ("mono", "wSlabMono"), ("wood", "wSlabWood"), ("none", "oNone")], id: \.0) { k, l in Chip(T(l), eq(W["slab"], k)) { W["slab"] = k } } }
        if eq(W["slab"], "pk") {
            Hint(T("wSlabW")); Chips { ForEach([1.0, 1.2, 1.5], id: \.self) { x in Chip("\(fmt(x)) м (\(fmt(num(D.PK_W[fmt(x)]))) мм)", W.nz("pw", 1.2) == x) { W["pw"] = x } } }
        }
        if eq(sl["type"], "pk") {
            if sl.b("tooLong") { Hint("⚠️ \(T("wSlabLong")) (\(fmt(sl.n("need"), 2)) \(mm))", C.warn) }
            else if sl["mark"] != nil {
                Stat("\(sl.s("mark")) · \(fmt(sl.n("len"), 2))×\(fmt(num(D.PK_W[fmt(W.nz("pw", 1.2))]) / 1000))×0,22 \(mm)", fmt(sl.n("pcs")) + " " + T("uPcs"), accent: true)
                Stat(T("wSlabWt"), "≈ \(fmt(sl.n("wt"), 2)) / \(fmt(sl.n("wtAll"), 1)) \(T("uT"))")
                if sl.n("monoV") != 0 { Stat(T("wSlabMonoIns"), stv(sl.n("monoV"), 2, m3)) }
                Hint("📄 ГОСТ 9561-2016 · " + T("wSlabNote"))
            }
        }
        if eq(sl["type"], "wood") && sl.n("beams") != 0 { Stat("\(T("wBeams")) 100×200 · \(fmt(sl.n("beamLen"), 2)) \(mm)", "\(fmt(sl.n("beams"))) \(T("uPcs")) · \(fmt(sl.n("timber"), 2)) \(m3)", accent: true) }
        if eq(sl["type"], "mono") && sl.n("V") != 0 { Stat(T("eConcrete") + " M250", stv(sl.n("V"), 2, m3), accent: true); Stat(T("eRebar") + " Ø12", stv(sl.n("rebarKg"), 0, T("uKg"))) }
        if sl.n("area") != 0 { Hint("\(T("wSlabSpan")): \(fmt(sl.n("span"), 2)) \(mm) · \(fmt(sl.n("levels"))) \(T("wLevels"))") }
    }
    @ViewBuilder func materials(_ W: Obj, _ m: Obj, _ r: Obj, _ mm: String, _ m3: String) -> some View {
        Stat(T("wGross"), stv(r.n("gross"), 1, T("m2"))); Stat(T("wOpen"), "− " + stv(r.n("open"), 1, T("m2"))); Stat(T("wNet"), stv(r.n("net"), 1, T("m2"))); Stat(T("wVol"), stv(r.n("vol"), 2, m3))
        if !m.s("frame").isEmpty {
            ForEach(Array(r.a("fItems").objs.enumerated()), id: \.offset) { _, x in Stat(T(x.s("k")), stv(x.n("q"), x.s("u") == "uPcs" ? 0 : 2, T(x.s("u")))) }
            Hint(T("fPriceNote"))
        } else {
            Stat(T("wCount"), mn(r.n("count")) + " " + T("uPcs"), accent: true)
            if !m.b("wood") { Stat(T("wPallets"), fmt(r.n("pallets")) + " " + T("uPcs")) }
            if !m.b("wood") {
                if m.b("glue") { Stat(T("wGlue"), fmt(r.n("glueBags")) + " " + T("uBags")) }
                else {
                    Stat(T("wMortar"), stv(r.n("mortar"), 2, m3))
                    if m.b("clay") { Stat(T("eClay"), stv(r.n("clay"), 2, m3)) } else { Stat(T("wCement"), fmt(r.n("cementBags")) + " " + T("uBags")); Stat(T("wSand"), stv(r.n("sand"), 2, m3)) }
                }
            }
            if r.n("lintelPcs") != 0 {
                Hint(T("wLintels") + " · ГОСТ 948-2016, 120×140 мм")
                ForEach(Array(r.o("lintels").entries.enumerated()), id: \.offset) { _, e in Stat("\(e.0) (\(fmt(pbLen(e.0))) мм)", fmt(num(e.1)) + " " + T("uPcs")) }
            }
            if r.n("lintelMono") != 0 { Stat(T("wLintelMono"), stv(r.n("lintelMono"), 2, m3)) }
            if W.b("belt") { Stat(T("wBeltConc"), stv(r.n("beltV"), 2, m3)); Stat(T("wBeltRebar"), "\(fmt(r.n("beltRebarM"), 0)) \(mm) · \(fmt(r.n("beltRebarKg"), 0)) \(T("uKg"))") }
            if m.b("wood") { Stat(T("wJute"), stv(r.n("jute"), 0, mm)) } else if m.b("glue") { Stat(T("wReinf"), stv(r.n("reinfM"), 0, mm)) } else { Stat(T("wMesh"), stv(r.n("meshM2"), 1, T("m2"))) }
            Stat(T("wRows"), fmt(r.n("rows"))); Stat(T("wWeight"), stv(r.n("weight"), 1, T("uT"))); Hint(T("fPriceNote"))
        }
    }
}
struct WallsSpecial: View {
    @ObservedObject var u = UIS.shared
    let b: Obj
    var body: some View {
        let W = b.o("walls")
        Page {
            TopBar(T("mWalls"), { go("home") }); BSelector()
            if eq(W["mat"], "poly") {
                let g = ghCalc(b); let gh = b["gh"] as? String ?? "gable"
                Sec("🌱 " + T("ghTitle")) {
                    Chips { ForEach([("gable", "ghGable"), ("arch", "ghArch"), ("lean", "ghLean")], id: \.0) { k, l in Chip(T(l), gh == k) { b["gh"] = k; b["roof"] = k == "lean" ? "SHED" : "GABLE" } } }
                    Hint(T(["gable": "ghhGable", "arch": "ghhArch", "lean": "ghhLean"][gh] ?? "ghhGable"), top: 0)
                    Stat(T("ghArc"), stv(g.arch, 2, T("m"))); Stat(T("ghArea"), stv(g.area, 1, T("m2"))); Stat(T("ghSheets") + " " + szj("poly"), fmt(g.sheets) + " " + T("uPcs"), accent: true)
                    Stat(T("ghArches"), fmt(g.arches) + " " + T("uPcs")); Stat(T("ghFrame"), stv(g.frame, 0, T("m"))); Stat(T("ghScrews"), fmt(g.screws) + " " + T("uPcs")); Hint(T("fPriceNote"))
                }
            } else {
                Sec("⛱️ " + T("gzTitle")) { Txt(T("gzText"), 14); Stat(T("gzPosts"), "4 \(T("uPcs")) × \(fmt(b.n("floorH") + 0.1)) \(T("m"))", accent: true) }
            }
        }
    }
}

// ---------- кровля ----------
struct RoofScreen: View {
    @ObservedObject var u = UIS.shared
    var body: some View {
        let b = curB(); let f = RF(b)
        Page {
            TopBar(T("mRoof"), { go("home") }); BSelector()
            Sec(pad: 10) { Hint("\(itemName(b)): \(fmt(b.n("w"))) × \(fmt(b.n("d"))) \(T("m"))", top: 0, bottom: 0) }
            if eq(b["kind"], "greenhouse") { Sec { Txt("🌱 " + T("rGhNote"), 14) } }
            else { RoofBody(b: b, f: f) }
        }
    }
}
struct RoofBody: View {
    let b: Obj; let f: Obj
    var body: some View {
        let r = calcRoof(b); let m2 = T("m2"); let m3 = T("uM3"); let pc = T("uPcs"); let c = D.COVERS.oo(f.s("cover")) ?? obj(); let rolls = T("rRolls").lowercased()
        Sec(T("rType")) {
            Chips { ForEach([("GABLE", "roofGable"), ("SHED", "roofShed"), ("HIP", "roofHip"), ("MANSARD", "roofMans"), ("FLAT", "roofFlat")], id: \.0) { k, l in
                Chip(T(l), eq(b["roof"], k)) { b["roof"] = k; if k == "SHED" && RF(b).n("angle") > 20 { b.o("rf")["angle"] = 12.0 } } } }
            Hint(T(["GABLE": "rhGable", "SHED": "rhShed", "HIP": "rhHip", "MANSARD": "rhMans", "FLAT": "rhFlat"][b.s("roof")] ?? "rhGable"))
            if pitched(b) {
                HStack(spacing: 6) {
                    NumField(T(eq(b["roof"], "MANSARD") ? "rAngleUp" : "rAngle"), f.n("angle")) { f["angle"] = clampD($0, 10, 60) }
                    NumField(T("rOver"), f.n("over"), zero: true) { f["over"] = min(1.5, $0) }
                }
            }
            Drawing(200) { drawRoofSection($0, b) }
        }
        if pitched(b) {
            Sec(T("rCover")) {
                Chips { ForEach(Array(D.COVERS.entries.enumerated()), id: \.offset) { _, e in Chip(tr3((e.1 as! Obj)["n"]), eq(f["cover"], e.0)) { f["cover"] = e.0; if e.0 == "custom" && f["cc"] == nil { f["cc"] = obj(("name", ""), ("uw", 1000.0), ("ul", 2000.0)) } } } }
                if eq(f["cover"], "custom") {
                    let cc = f.o("cc")
                    TextIn(T("ccName"), cc.s("name")) { cc["name"] = $0 }
                    HStack(spacing: 6) { NumField(T("ccUW"), cc.n("uw")) { cc["uw"] = $0 }; NumField(T("ccUL"), cc.n("ul")) { cc["ul"] = $0 } }
                }
                Hint(T("rColor")); Chips { ForEach(Array(D.o("RCOL").entries.enumerated()), id: \.offset) { _, e in ColorChip(hexColor(e.1 as? String), eq(f["color"], e.0), w: 44) { f["color"] = e.0 } } }
            }
        }
        SzLink(back: "roof")
        Sec(T("rRafter")) {
            Chips { ForEach(["50x150", "50x200", "100x150"], id: \.self) { x in Chip(x.replacingOccurrences(of: "x", with: "×") + " мм", eq(f["rafter"], x)) { f["rafter"] = x } } }
            NumField(T("rStep"), f.n("step")) { f["step"] = clampD($0, 0.3, 1.2) }
            Hint(T("rIns"))
            Chips { Chip(T("rNoIns"), !f.b("ins")) { f["ins"] = 0.0 }; ForEach([100.0, 150.0, 200.0], id: \.self) { x in Chip(fmt(x) + " мм", f.n("ins") == x) { f["ins"] = x } } }
            NumField(T("ownVal"), f.n("ins"), zero: true) { f["ins"] = clampD($0, 0, 400) }
        }
        Sec(T("fMaterials")) { mats(r, c, m2, m3, pc, rolls) }
        HintOut("⚠️ " + T("rNote")); RateLink(back: "roof"); ExtrasUI(b: b, sec: "roof")
    }
    @ViewBuilder func mats(_ r: Obj, _ c: Obj, _ m2: String, _ m3: String, _ pc: String, _ rolls: String) -> some View {
        Stat(T("rArea"), stv(r.n("area"), 1, m2), accent: true)
        if r.n("slope") != 0 { Stat(T("rSlope"), stv(r.n("slope"), 2, T("m"))); Stat(T("rRidgeH"), stv(r.n("rise"), 2, T("m"))) }
        if r.n("flatRolls") != 0 { Stat(T("rFlatRoll"), fmt(r.n("flatRolls")) + " " + rolls) }
        if r.n("sheets") != 0 {
            Stat(tr3(c["n"]) + (r.n("sheetLen") != 0 ? " (\(fmt(r.n("sheetLen"), 1)) \(T("m")))" : "") + (r["sheetDim"] != nil ? " " + r.s("sheetDim") : ""),
                 fmt(r.n("sheets")) + " " + pc + (r.n("sheetArea") != 0 ? " · " + stv(r.n("sheetArea"), 1, m2) : ""), accent: true)
        }
        if r.n("packs") != 0 { Stat(tr3(c["n"]), fmt(r.n("packs")) + " " + T("rPacks").lowercased(), accent: true); Stat(T("rOSB"), fmt(r.n("osb")) + " " + pc); Stat(T("rUnder"), fmt(r.n("under")) + " " + rolls + " (15 м²)") }
        if r.n("raftersN") != 0 { Stat("\(T("rRafters")) \(f.s("rafter").replacingOccurrences(of: "x", with: "×"))", "\(fmt(r.n("raftersN"))) \(pc) × \(fmt(r.n("raftersLen"), 2)) \(T("m"))") }
        if r.n("mauerlat") != 0 { Stat(T("rMauerlat"), stv(r.n("mauerlat"), 1, T("m"))) }
        if r.n("lath") != 0 { Stat(T("rLath"), stv(r.n("lath"), 0, T("m"))) }
        if r.n("counter") != 0 { Stat(T("rCounter"), stv(r.n("counter"), 0, T("m"))) }
        Stat(T("rTimber"), stv(r.n("timber"), 2, m3))
        if r.n("membrane") != 0 { Stat(T("rMembrane"), fmt(r.n("membrane")) + " " + rolls) }
        if r.n("vapor") != 0 { Stat(T("rVapor"), fmt(r.n("vapor")) + " " + rolls) }
        if r.n("wool") != 0 { Stat("\(T("rWool")) \(fmt(f.n("ins"))) мм", stv(r.n("wool"), 2, m3)) }
        if r.n("ridge") != 0 { Stat(T("rRidge"), fmt(r.n("ridge")) + " " + pc) }
        if r.n("valleys") != 0 { Stat(T("rValley") + " (\(fmt(r.n("valleys"))) × \(fmt(r.n("valleyLen") / r.n("valleys"), 2)) \(T("m")))", fmt(r.n("valleyPcs")) + " " + pc) }
        if r.n("screws") != 0 { Stat(T("rScrews"), fmt(r.n("screws")) + " " + pc) }
        Stat(T("rGutter"), fmt(r.n("gutter")) + " " + pc); Stat(T("rPipe"), "\(fmt(r.n("pipes"))) × \(fmt(r.n("pipeLen"), 1)) \(T("m"))"); Hint(T("fPriceNote"))
    }
}
