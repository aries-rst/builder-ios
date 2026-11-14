import Foundation

// ---------- даты (аналог java.time.LocalDate, UTC-полночь) ----------
let utcCal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
private let dateFmt: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "UTC"); f.dateFormat = "yyyy-MM-dd"; return f }()
func plusDays(_ d: Date, _ n: Int) -> Date { utcCal.date(byAdding: .day, value: n, to: d)! }
func parseDate(_ s: String) -> Date? { dateFmt.date(from: s) }
func dateStr(_ d: Date) -> String { dateFmt.string(from: d) }
func localToday() -> Date { let c = Calendar.current.dateComponents([.year, .month, .day], from: Date()); return utcCal.date(from: c)! }

func SC() -> Obj { keep(St.project, "sched", obj(("start", dateStr(localToday())), ("crew", 4.0), ("days", 6.0), ("par", false))) }
private func isWork(_ d: Date, _ dpw: Int) -> Bool { let w = utcCal.component(.weekday, from: d); return dpw >= 7 || (dpw == 6 && w != 1) || (dpw <= 5 && w != 1 && w != 7) }
func addWork(_ d0: Date, _ n: Int, _ dpw: Int) -> Date { var d = d0; var k = 0; while k < n { d = plusDays(d, 1); if isWork(d, dpw) { k += 1 } }; return d }
func nextWork(_ d0: Date, _ dpw: Int) -> Date { var d = d0; while !isWork(d, dpw) { d = plusDays(d, 1) }; return d }
final class Stage { let name: String; let g: String; let dur: Int; let st: Date; let en: Date; let cost: Double; let col: String; var cureEnd: Date?
    init(_ name: String, _ g: String, _ dur: Int, _ st: Date, _ en: Date, _ cost: Double, _ col: String) { self.name = name; self.g = g; self.dur = dur; self.st = st; self.en = en; self.cost = cost; self.col = col } }
struct Schedule { var stages: [Stage]; var start: Date; var end: Date; var anyCost: Bool }
func buildSchedule() -> Schedule {
    let p = St.project; let s = SC(); let f = s.n("crew") / 3; let E = estimate(); var stages = [Stage](); let dpw = Int(s.n("days"))
    func costOf(_ g: String, _ sec: String) -> Double { E.L.filter { $0.g == g && $0.sec == sec }.reduce(0) { $0 + $1.qty * E.price($1.pk) } }
    let wf = E.mat != 0 ? E.work / E.mat : 0.0; func Dd(_ x: Double) -> Int { max(1, Int((x / f).rounded(.up))) }
    let bs = buildings(); let dig = bs.reduce(0) { $0 + calcFound($1).n("dig") }
    let t0 = nextWork(parseDate(s.s("start")) ?? localToday(), dpw)
    func push(_ name: String, _ g: String, _ dur: Int, _ start: Date, _ cost: Double, _ col: String, _ cure: Int = 0) -> Date {
        let st = nextWork(start, dpw); let en = addWork(st, dur - 1, dpw); let it = Stage(name, g, dur, st, en, cost * (1 + wf), col); stages.append(it)
        if cure > 0 { let c2 = plusDays(en, cure); it.cureEnd = c2; return c2 }; return plusDays(en, 1) }
    let prepEnd = push(t("stPrep"), "", Dd(2 + dig / 25), t0, 0.0, "#64748B")
    let cols = ["#F59E0B", "#38BDF8", "#A78BFA", "#34D399", "#F472B6", "#FB923C", "#22D3EE", "#A3E635"]; var cur = prepEnd; var lastEnd = prepEnd
    for (bi, b) in bs.enumerated() { let g = itemName(b); let col = cols[bi % cols.count]; let W = b.o("walls"); let fo = calcFound(b); var tt = s.b("par") ? prepEnd : cur; let F = b.o("f")
        let fd = eq(F["type"], "fbs") ? (fo.n("fbsOut") + fo.n("fbsIn")) / 25 + fo.n("padV") / 4 : fo.n("V") / 4 + fo.n("mainKg") / 400; let BS = calcBasement(b)
        tt = push(t("stFound"), g, Dd(max(2.0, fd + (BS != nil ? BS!.n("dig") / 25 + BS!.n("fbs") / 25 + BS!.n("wallV") / 4 + 5 : 0))), tt, costOf(g, t("mFound")), col, eq(F["type"], "post") ? 3 : 7)
        let mat = W.s("mat")
        if mat == "poly" { tt = push(t("stWalls"), g, Dd(2), tt, costOf(g, t("mWalls")), col) }
        else if mat == "open" { tt = push(t("stWalls"), g, Dd(1), tt, costOf(g, t("mWalls")), col) }
        else { let w = calcWalls(b); let m = MI(W) ?? obj(); let sl = calcSlabs(b); let wd = m.b("wood") ? w.n("net") / 12 : w.n("vol") / (m.b("glue") ? 4.0 : 2.5)
            let sd = sl.n("pcs") != 0 ? sl.n("pcs") / 12 : sl.n("beams") != 0 ? sl.n("beams") / 20 : sl.n("V") != 0 ? sl.n("V") / 5 : 0.0
            tt = push(t("stWalls"), g, Dd(max(2.0, wd + sd)), tt, costOf(g, t("mWalls")) * 0.8, col, sl.n("V") != 0 ? 7 : 0) }
        if !eq(b["kind"], "greenhouse") { let r = calcRoof(b); tt = push(t("stRoof"), g, Dd(max(1.0, r.n("area") / (eq(b["roof"], "FLAT") ? 30 : 20))), tt, costOf(g, t("mRoof")), col) }
        if !["poly", "open"].contains(mat) { let nOp = W.a("openings").objs.reduce(0) { $0 + $1.n("q") }; if nOp != 0 { tt = push(t("stWin"), g, Dd(max(1.0, nOp / 5)), tt, costOf(g, t("mWalls")) * 0.2, col) }
            let er = calcEng(b); let pts = er.n("sock") + er.n("lights") + er.n("wp") + er.n("s110") + er.n("s50"); if pts != 0 { tt = push(t("stEng"), g, Dd(max(1.0, pts / 12 + er.n("heatA") / 40)), tt, costOf(g, t("mEng")), col) }
            if !eq(b["kind"], "gazebo") { let fi = calcFin(b); let fd2 = fi.n("wall") / 35 + fi.n("floor") / 25 + fi.n("facade") / 25; if fd2 > 0 { tt = push(t("stFin"), g, Dd(max(1.0, fd2)), tt, costOf(g, t("mFinish")), col) } } }
        cur = tt; if tt > lastEnd { lastEnd = tt } }
    if p["fence"] != nil { let fr = calcFence(); if fr.n("L") > 0 { _ = push(t("stFence"), "", Dd(max(1.0, fr.n("L") / 15)), prepEnd, E.L.filter { $0.g == t("mFence") }.reduce(0) { $0 + $1.qty * E.price($1.pk) }, "#94A3B8") } }
    let ss = siteStats(); let la = ["path", "paving", "lawn", "garden"].reduce(0) { $0 + ss.zone($1) }
    if la > 0 { _ = push(t("stLand"), "", Dd(max(1.0, la / 40)), lastEnd, E.L.filter { $0.g == t("eLand") }.reduce(0) { $0 + $1.qty * E.price($1.pk) }, "#4ADE80") }
    let end = stages.map { $0.cureEnd ?? $0.en }.max() ?? t0; return Schedule(stages: stages, start: t0, end: end, anyCost: stages.contains { $0.cost > 0 })
}
