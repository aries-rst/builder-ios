import Foundation

/// Хранение проектов (как Store на Android: те же ключи builder_*, тот же JSON).
enum Store {
    static var pid: String? = nil
    static var hist: [String] = []
    private static var lastJs: String? = nil
    static var noHist = false
    private static let ud = UserDefaults.standard

    static func get(_ k: String) -> String? { ud.string(forKey: "builder_" + k) }
    static func set(_ k: String, _ v: String?) { if let v = v { ud.set(v, forKey: "builder_" + k) } else { ud.removeObject(forKey: "builder_" + k) } }

    static func initApp() {
        if let u = Bundle.main.url(forResource: "data", withExtension: "json"), let d = try? Data(contentsOf: u) { D.load(d) }
        for (k, v) in TRX where D.TR.aa(k) == nil { D.TR[k] = Arr(v.map { $0 as Any }) }
        if let l = get("lang") { St.lang = l }; loadLang(); St.cur = get("cur") ?? "USD"
        var l = list()
        if l.isEmpty { let id = "p1"; put(id, blankProject()); l = [obj(("id", id), ("name", t("pjDefault")), ("auto", 0.0), ("upd", now()))]; setList(l); set("pid", id) }
        var id = get("pid"); if !l.contains(where: { ($0["id"] as? String) == id }) { id = l[0]["id"] as? String }
        pid = id; St.project = attach(load(id!) ?? defProject()); save()
    }
    /// Перевод доп. языка (i18n/<lang>.json: английская строка → перевод).
    static func loadLang() {
        if !isExt() { X.map = [:]; X.lang = ""; return }
        if X.lang == St.lang { return }
        var m: [String: String] = [:]
        if let u = Bundle.main.url(forResource: St.lang, withExtension: "json"), let d = try? Data(contentsOf: u), let o = Json.parse(d) as? Obj { for (k, v) in o.entries { m[k] = "\(v)" } }
        X.map = m; X.lang = St.lang
    }
    static func now() -> Double { (Date().timeIntervalSince1970 * 1000).rounded() }
    static func list() -> [Obj] { ((Json.parse(get("projects") ?? "[]") as? Arr)?.objs) ?? [] }
    static func setList(_ l: [Obj]) { set("projects", Json.str(Arr(l))) }
    static func load(_ id: String) -> Obj? { get("project_" + id).flatMap { Json.parse($0) as? Obj } }
    static func put(_ id: String, _ p: Obj) { set("project_" + id, Json.str(p)) }

    private static func snap() -> String { let c = Obj(); for (k, v) in St.project.entries where k != "calc" && k != "calcFence" { c[k] = v }; return Json.str(c) }
    static func save() {
        guard let id = pid else { return }
        let js = snap(); if !noHist, let l = lastJs, js != l { hist.append(l); if hist.count > 40 { hist.removeFirst() } }; lastJs = js
        put(id, St.project); let l = list()
        if let m = l.first(where: { ($0["id"] as? String) == id }) { m["upd"] = now(); m["sot"] = G.area(plot()) / 100; m["nb"] = Double(buildings().count); setList(l) }
    }
    static func undo() {
        guard !hist.isEmpty else { return }; let js = hist.removeLast()
        St.project = attach(Json.parse(js) as! Obj); lastJs = js; noHist = true; save(); noHist = false; toast(t("undone")); UI.tick += 1
    }
    static func open(_ id: String) {
        guard let p = load(id) else { return }; pid = id; set("pid", id); St.project = attach(p); hist.removeAll(); lastJs = nil; save(); UI.lv = 0.0; go("home")
    }
    static func newId() -> String { "p" + String(Int(Date().timeIntervalSince1970 * 1000), radix: 36) }
    static func newProject(_ demo: Bool, _ src: Obj? = nil) {
        if !Premium.canAddProject() { Premium.gate("limit", false) {}; return }
        var l = list(); let id = newId()
        let p: Obj = src != nil ? (deep(src) as! Obj) : (demo ? defProject() : blankProject())
        if src == nil, let pr = St.project.oo("prices") { p["prices"] = deep(pr) }
        let name = src != nil ? ((l.first { ($0["id"] as? String) == pid }.map { title($0) } ?? t("pjDefault")) + " (" + t("pjCopy").lowercased() + ")") : (t("pjDefault") + " " + String(l.count + 1))
        let m = obj(("id", id), ("name", name), ("upd", now())); if src == nil { m["auto"] = Double(l.count + 1) }
        l.append(m); setList(l); put(id, p); open(id)
    }
    static func newFromTpl(_ T: Arr) {
        if !Premium.canAddProject() { Premium.gate("limit", false) {}; return }
        let p = tplBuild(T); var l = list(); let id = newId()
        if let pr = St.project.oo("prices") { p["prices"] = deep(pr) }
        l.append(obj(("id", id), ("name", tr3(T.at(1))), ("tpl", T.at(0)), ("upd", now()))); setList(l); put(id, p); open(id); go("plot")
    }
    static func rename(_ id: String, _ name: String) {
        let l = list(); if let m = l.first(where: { ($0["id"] as? String) == id }) { if name == title(m) { return }; m["name"] = name.trimmingCharacters(in: .whitespaces).isEmpty ? t("pjDefault") : name; m["tpl"] = nil; m["auto"] = nil }
        setList(l)
    }
    /// Имя проекта на текущем языке: автоимена (шаблон, «Мой проект N») переводятся, своё имя остаётся как введено.
    static func title(_ m: Obj) -> String {
        let n = m.s("name")
        if let id = m["tpl"] as? String, let T = TPL().first(where: { $0.s(0) == id }) { return tr3(T.at(1)) }
        if let a = m["auto"] as? Double { return t("pjDefault") + (Int(a) > 0 ? " " + String(Int(a)) : "") }
        if let T = TPL().first(where: { ($0.at(1) as? Arr)?.contains(where: { ($0 as? String) == n }) == true }) { return tr3(T.at(1)) }
        if let vs = D.TR.aa("pjDefault") {
            for v in vs { let pre = "\(v)"; if n.hasPrefix(pre) { let rest = String(n.dropFirst(pre.count)); if rest.isEmpty { return t("pjDefault") }; if rest.hasPrefix(" "), Int(rest.dropFirst()) != nil { return t("pjDefault") + rest } } }
        }
        return n
    }
    static func delete(_ id: String) {
        let l = list().filter { ($0["id"] as? String) != id }; if l.isEmpty { return }
        setList(l); set("project_" + id, nil); if id == pid { open(l[0]["id"] as! String) }
    }
    static func importJson(_ s: String) -> Bool {
        if !Premium.canAddProject() { Premium.gate("limit", false) {}; return true }
        guard let p = Json.parse(s) as? Obj else { return false }
        if p["items"] == nil && p["b"] == nil { return false }
        newProject(false, p); return true
    }
}

/// Демо-проект
func defProject() -> Obj {
    let p = obj(("rectMode", true), ("plotW", 20.0), ("plotD", 30.0), ("points", toArr(rect(20, 30))), ("setback", 3.0), ("setbackAux", 1.0), ("items", arr()), ("nextId", 1.0))
    let defs: [(String, String, Double, Double)] = [("b", "house", 10, 22), ("b", "banya", 16, 9), ("b", "greenhouse", 5, 8), ("z", "path", 10, 10.5), ("z", "lawn", 16, 15), ("z", "garden", 4, 13.5), ("z", "tree", 3, 27.5), ("z", "tree", 17, 27.5)]
    for (c, k, x, y) in defs { let it = newItem(p, c, k, x, y); if k == "path" { it["d"] = 13.0 }; if k == "garden" { it["d"] = 4.0 }; p.a("items").add(it) }
    let f = p.a("items").objs[0]["id"]; p["sel"] = f; p["bSel"] = f; return p
}
