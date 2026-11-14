import SwiftUI
import UIKit

// ---------------- Единицы измерения для en/uz (как L() на Android) ----------------
private let reU = try! NSRegularExpression(pattern: "(\\d[\\d.,]*\\s?)(мм|см|кг|мл|кВт|мод\\.|м²|м³|м|л|Ф|А)(?=$|[^А-Яа-яЁёA-Za-z])")
private let reU2 = try! NSRegularExpression(pattern: "([,(]\\s?)(мм|мл|кг|см)(?=$|[^А-Яа-яЁё])")
private func rxRep(_ re: NSRegularExpression, _ s: String, _ um: Obj) -> String {
    let ns = s as NSString; var out = ""; var last = 0
    for m in re.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
        out += ns.substring(with: NSRange(location: last, length: m.range.location - last))
        let a = ns.substring(with: m.range(at: 1)), u = ns.substring(with: m.range(at: 2))
        out += a + ((um[u] as? String) ?? u); last = m.range.location + m.range.length
    }
    return out + ns.substring(from: last)
}
func L(_ s: String) -> String {
    guard let um = D.o("UMAP").oo(St.lang) ?? ((isExt() && St.lang != "kk") ? D.o("UMAP").oo("en") : nil) else { return s }
    if !s.unicodeScalars.contains(where: { ($0.value >= 0x410 && $0.value <= 0x44F) || $0.value == 0x401 || $0.value == 0x451 }) { return s }
    var r = rxRep(reU2, rxRep(reU, s, um), um)
    r = r.replacingOccurrences(of: "кг/м³", with: "kg/m³").replacingOccurrences(of: "кг/", with: "kg/").replacingOccurrences(of: "СИП-", with: "SIP-")
        .replacingOccurrences(of: "Ш общ.", with: li() == 1 ? "W total" : "E umumiy").replacingOccurrences(of: "Ш полезн.", with: li() == 1 ? "W useful" : "E foydali")
    return r
}
func T(_ k: String) -> String { L(t(k)) }

// ---------------- Базовые компоненты ----------------
struct Txt: View {
    let s: String; var size: CGFloat = 15; var color: Color = C.text; var bold = false; var align: TextAlignment = .leading
    init(_ s: String, _ size: CGFloat = 15, _ color: Color = C.text, bold: Bool = false, align: TextAlignment = .leading) { self.s = s; self.size = size; self.color = color; self.bold = bold; self.align = align }
    var body: some View {
        Text(L(s)).font(.system(size: size, weight: bold ? .bold : .regular)).foregroundColor(color).lineSpacing(size * 0.3)
            .multilineTextAlignment(align).fixedSize(horizontal: false, vertical: true)
    }
}
struct Gap: View { var h: CGFloat = 24; init(_ h: CGFloat = 24) { self.h = h }; var body: some View { Color.clear.frame(height: h) } }
struct Divider1: View { var body: some View { Rectangle().fill(C.line).frame(height: 1) } }

struct IconBtn: View {
    let s: String; var color: Color = C.text; let action: () -> Void
    init(_ s: String, _ color: Color = C.text, _ action: @escaping () -> Void) { self.s = s; self.color = color; self.action = action }
    static let tips = ["←": "tpBack", "↶": "tpUndo", "🏠": "tpHome", "📁": "tpProjects", "⚙️": "tpSettings", "✕": "tpDel"]
    var body: some View {
        Text(s).font(.system(size: 20)).foregroundColor(color).frame(width: 44, height: 44).contentShape(Rectangle())
            .onTapGesture(perform: action)
            .onLongPressGesture(minimumDuration: 0.5) { if let k = IconBtn.tips[s] { toast(T(k)) } }
    }
}
struct TopBar: View {
    @ObservedObject var u = UIS.shared
    let title: String; var onBack: (() -> Void)?; var home = true
    init(_ title: String, _ onBack: (() -> Void)?, home: Bool = true) { self.title = title; self.onBack = onBack; self.home = home }
    var body: some View {
        HStack(spacing: 0) {
            if let b = onBack { IconBtn("←", C.text, b) }
            Txt(title, 20, bold: true).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 8)
            if !Store.hist.isEmpty { IconBtn("↶") { Store.undo() } }
            if home { IconBtn("🏠") { go("home") } }
        }.padding(.horizontal, 4).padding(.top, 8).padding(.bottom, 4)
    }
}
struct Sec<Content: View>: View {
    var title: String?; var pad: CGFloat; var border: Bool; let content: Content
    init(_ title: String? = nil, pad: CGFloat = 14, border: Bool = false, @ViewBuilder _ content: () -> Content) { self.title = title; self.pad = pad; self.border = border; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let t = title { Txt(t, 17, bold: true).padding(.bottom, 8) }
            content
        }.padding(pad).frame(maxWidth: .infinity, alignment: .leading).background(C.card).cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(C.accent, lineWidth: border ? 2 : 0))
            .padding(.horizontal, 16).padding(.vertical, 6)
    }
}
struct Hint: View {
    let s: String; var color: Color = C.muted; var top: CGFloat = 4; var bottom: CGFloat = 4; var size: CGFloat = 13
    init(_ s: String, _ color: Color = C.muted, top: CGFloat = 4, bottom: CGFloat = 4, size: CGFloat = 13) { self.s = s; self.color = color; self.top = top; self.bottom = bottom; self.size = size }
    var body: some View { Txt(s, size, color).padding(.top, top).padding(.bottom, bottom).frame(maxWidth: .infinity, alignment: .leading) }
}
struct HintOut: View {
    let s: String; var color: Color = C.muted
    init(_ s: String, _ color: Color = C.muted) { self.s = s; self.color = color }
    var body: some View { Txt(s, 13, color).padding(.horizontal, 16).padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading) }
}
struct Head: View {
    let s: String; var color: Color = C.accent
    init(_ s: String, _ color: Color = C.accent) { self.s = s; self.color = color }
    var body: some View { Txt(s, 14, color, bold: true).padding(.top, 10).padding(.bottom, 2).frame(maxWidth: .infinity, alignment: .leading) }
}

/// Перенос по строкам (FlowRow)
struct FlowLayout: Layout {
    var spacing: CGFloat = 6; var rtl = St.lang == "ar" || St.lang == "fa"
    private func rows(_ w: CGFloat, _ subs: Subviews) -> [[(Int, CGSize)]] {
        var rs: [[(Int, CGSize)]] = [[]]; var x: CGFloat = 0
        for (i, s) in subs.enumerated() {
            let sz = s.sizeThatFits(ProposedViewSize(width: w, height: nil))
            if x > 0 && x + sz.width > w { rs.append([]); x = 0 }
            rs[rs.count - 1].append((i, sz)); x += sz.width + spacing
        }
        return rs
    }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? 10000; let rs = rows(w, subviews); var h: CGFloat = 0; var mw: CGFloat = 0
        for r in rs { h += (r.map { $0.1.height }.max() ?? 0) + spacing; mw = max(mw, r.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(r.count - 1, 0))) }
        return CGSize(width: proposal.width ?? mw, height: max(h - spacing, 0))
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = b.minY
        for r in rows(b.width, subviews) {
            let rh = r.map { $0.1.height }.max() ?? 0; var x = rtl ? b.maxX : b.minX
            for (i, sz) in r {
                if rtl { x -= sz.width; subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz)); x -= spacing }
                else { subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz)); x += sz.width + spacing }
            }
            y += rh + spacing
        }
    }
}
struct Chips<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View { FlowLayout { content }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4) }
}
struct Chip: View {
    let text: String; let on: Bool; var sub: String?; let action: () -> Void
    init(_ text: String, _ on: Bool, sub: String? = nil, _ action: @escaping () -> Void) { self.text = text; self.on = on; self.sub = sub; self.action = action }
    var body: some View {
        VStack(spacing: 0) {
            Txt(text, 14, on ? C.onAccent : C.text, bold: on, align: .center)
            if let s = sub { Txt(s, 11, on ? C.onAccent : C.muted, align: .center) }
        }.padding(.horizontal, 14).padding(.vertical, 8).background(on ? C.accent : C.field).cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(on ? C.accent : C.border, lineWidth: 1))
            .onTapGesture { action(); upd() }
    }
}
struct ColorChip: View {
    let col: Color; let on: Bool; var w: CGFloat = 40; let action: () -> Void
    init(_ col: Color, _ on: Bool, w: CGFloat = 40, _ action: @escaping () -> Void) { self.col = col; self.on = on; self.w = w; self.action = action }
    var body: some View { RoundedRectangle(cornerRadius: 16).fill(col).frame(width: w, height: 32).overlay(RoundedRectangle(cornerRadius: 16).stroke(on ? C.accent : C.border, lineWidth: 3)).onTapGesture { action(); upd() } }
}
/// Переключатель «да/нет» в виде пары чипов
struct Toggle1: View {
    let on: Bool; var yes = T("eOn"); var no = T("eOff"); let set: (Bool) -> Void
    init(_ on: Bool, yes: String = T("eOn"), no: String = T("eOff"), _ set: @escaping (Bool) -> Void) { self.on = on; self.yes = yes; self.no = no; self.set = set }
    var body: some View { Chips { Chip(yes, on) { set(true) }; Chip(no, !on) { set(false) } } }
}
struct Check: View {
    let text: String; let on: Bool; let set: (Bool) -> Void
    init(_ text: String, _ on: Bool, _ set: @escaping (Bool) -> Void) { self.text = text; self.on = on; self.set = set }
    var body: some View { Chip((on ? "✓ " : "") + text, on) { set(!on) } }
}

// ---------------- Поля ввода (UITextField с кнопкой «Готово») ----------------
struct KField: UIViewRepresentable {
    @Binding var text: String
    var keyboard: UIKeyboardType = .default; var align: NSTextAlignment = .natural; var size: CGFloat = 16
    var onFocus: (Bool) -> Void = { _ in }; var onDone: () -> Void = {}
    func makeCoordinator() -> Coord { Coord(self) }
    func makeUIView(context: Context) -> UITextField {
        let f = UITextField(); f.delegate = context.coordinator; f.keyboardType = keyboard; f.textAlignment = align
        f.textColor = UIColor(C.text); f.tintColor = UIColor(C.accent); f.font = .systemFont(ofSize: size); f.autocorrectionType = .no
        f.setContentHuggingPriority(.defaultLow, for: .horizontal); f.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        f.addTarget(context.coordinator, action: #selector(Coord.changed(_:)), for: .editingChanged)
        let tb = UIToolbar(); tb.sizeToFit(); tb.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), UIBarButtonItem(title: "OK", style: .done, target: context.coordinator, action: #selector(Coord.done))]
        f.inputAccessoryView = tb; return f
    }
    func updateUIView(_ f: UITextField, context: Context) { context.coordinator.p = self; if f.text != text { f.text = text } }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? { CGSize(width: proposal.width ?? 100, height: size + 6) }
    final class Coord: NSObject, UITextFieldDelegate {
        var p: KField; init(_ p: KField) { self.p = p }
        @objc func changed(_ f: UITextField) { p.text = f.text ?? "" }
        @objc func done() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        func textFieldDidBeginEditing(_ f: UITextField) { p.onFocus(true) }
        func textFieldDidEndEditing(_ f: UITextField) { p.onFocus(false) }
        func textFieldShouldReturn(_ f: UITextField) -> Bool { f.resignFirstResponder(); return true }
    }
}
private func parseNum(_ s: String) -> Double? { Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: " ", with: "")) }
struct NumField: View {
    let label: String; let value: Double; var zero = false; let onSet: (Double) -> Void
    @State private var txt = ""; @State private var focused = false; @State private var inited = false
    init(_ label: String, _ value: Double, zero: Bool = false, _ onSet: @escaping (Double) -> Void) { self.label = label; self.value = value; self.zero = zero; self.onSet = onSet }
    private func commit() { if let v = parseNum(txt), v > 0 || (zero && v >= 0) { if v != value { onSet(v); upd() } } else { txt = fmt(value) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Txt(label, 12, C.muted)
            KField(text: $txt, keyboard: .decimalPad, onFocus: { f in if focused && !f { commit() }; focused = f })
                .padding(10).background(C.field).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? C.accent : C.border, lineWidth: 1))
        }.padding(.vertical, 3).frame(maxWidth: .infinity, alignment: .leading)
            .onAppear { txt = fmt(value) }.onChange(of: value) { v in if !focused { txt = fmt(v) } }
    }
}
struct TextIn: View {
    let label: String; let value: String; var placeholder = ""; let onSet: (String) -> Void
    @State private var txt = ""; @State private var focused = false
    init(_ label: String, _ value: String, placeholder: String = "", _ onSet: @escaping (String) -> Void) { self.label = label; self.value = value; self.placeholder = placeholder; self.onSet = onSet }
    private func commit() {
        let bad: Set<Character> = ["<", ">", "\"", "'", "`"]
        let v = String(txt.trimmingCharacters(in: .whitespaces).filter { !bad.contains($0) }.prefix(60)); if v != value { onSet(v); upd() }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !label.isEmpty { Txt(label, 12, C.muted) }
            ZStack(alignment: .leading) {
                if txt.isEmpty && !placeholder.isEmpty { Txt(placeholder, 15, C.muted) }
                KField(text: $txt, onFocus: { f in if focused && !f { commit() }; focused = f })
            }.padding(10).background(C.field).cornerRadius(10).overlay(RoundedRectangle(cornerRadius: 10).stroke(focused ? C.accent : C.border, lineWidth: 1))
        }.padding(.vertical, 3).frame(maxWidth: .infinity, alignment: .leading)
            .onAppear { txt = value }.onChange(of: value) { v in if !focused { txt = v } }
    }
}
/// Поле цены в строке сметы
struct PriceIn: View {
    let value: Double; var placeholder = "0"; let onSet: (Double) -> Void
    @State private var txt = ""; @State private var focused = false
    init(_ value: Double, placeholder: String = "0", _ onSet: @escaping (Double) -> Void) { self.value = value; self.placeholder = placeholder; self.onSet = onSet }
    private func commit() { let v = max(0, parseNum(txt) ?? 0); if v != value { onSet(v); upd() } }
    var body: some View {
        ZStack(alignment: .trailing) {
            if txt.isEmpty { Txt(placeholder, 14, C.muted) }
            KField(text: $txt, keyboard: .decimalPad, align: .right, size: 15, onFocus: { f in if focused && !f { commit() }; focused = f })
        }.padding(8).background(C.field).cornerRadius(8).overlay(RoundedRectangle(cornerRadius: 8).stroke(focused ? C.accent : C.border, lineWidth: 1))
            .onAppear { txt = value > 0 ? fmt(value) : "" }.onChange(of: value) { v in if !focused { txt = v > 0 ? fmt(v) : "" } }
    }
}
struct Stat: View {
    let label: String; let value: String; var accent = false; var sub: String?; var big = false
    init(_ label: String, _ value: String, accent: Bool = false, sub: String? = nil, big: Bool = false) { self.label = label; self.value = value; self.accent = accent; self.sub = sub; self.big = big }
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) { Txt(label, 14, C.muted); if let s = sub { Txt(s, 12, C.muted) } }.frame(maxWidth: .infinity, alignment: .leading)
            Txt(value, big ? 16 : 14, accent ? C.accent : C.text, bold: true, align: .trailing).frame(maxWidth: 215, alignment: .trailing)
        }.padding(.vertical, 5)
    }
}
struct Btn: View {
    let text: String; var primary = true; var color: Color?; let action: () -> Void
    init(_ text: String, _ primary: Bool = true, color: Color? = nil, _ action: @escaping () -> Void) { self.text = text; self.primary = primary; self.color = color; self.action = action }
    var body: some View {
        Txt(text, 15, color ?? (primary ? C.onAccent : C.text), bold: true, align: .center).padding(13).frame(maxWidth: .infinity)
            .background(primary ? C.accent : C.card).cornerRadius(24).contentShape(Rectangle()).onTapGesture(perform: action).padding(.horizontal, 16).padding(.vertical, 6)
    }
}
/// Обводная кнопка (ob в прототипе)
struct OBtn: View {
    let text: String; var color: Color = C.accent; var full = false; let action: () -> Void
    init(_ text: String, _ color: Color = C.accent, full: Bool = false, _ action: @escaping () -> Void) { self.text = text; self.color = color; self.full = full; self.action = action }
    var body: some View {
        Txt(text, 14, color, bold: true, align: .center).padding(.horizontal, 14).padding(.vertical, 9).frame(maxWidth: full ? .infinity : nil)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(color, lineWidth: 1)).contentShape(Rectangle()).onTapGesture(perform: action).padding(.vertical, 4)
    }
}
struct Page<Content: View>: View {
    @ObservedObject var u = UIS.shared
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 0) { content; Gap() }.frame(maxWidth: .infinity, alignment: .leading) }.scrollDisabled(u.lock).scrollDismissesKeyboard(.interactively) }
}
struct Centered<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View { ScrollView { VStack(spacing: 0) { content }.frame(maxWidth: .infinity).padding(24).frame(minHeight: UIScreen.main.bounds.height * 0.8) } }
}

// ---------------- Составные ----------------
/// Список строк с вводом цены и суммой (pricedList)
struct PricedList: View {
    @ObservedObject var u = UIS.shared
    let ls: [Line]; let totalKey: String
    var body: some View {
        let pr0 = St.project.o("prices"); let tot = ls.reduce(0.0) { $0 + $1.qty * num(pr0[$1.pk]) }
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(ls.enumerated()), id: \.offset) { i, l in
                let pr = num(pr0[l.pk]); let sm = l.qty * pr
                if let g = l.g, i == 0 || ls[i - 1].g != g { Head(T(g)) }
                Divider1()
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) { Txt(l.label, 14); Txt("\(qfmt(l.qty)) \(l.unit)", 12, C.muted) }.frame(maxWidth: .infinity, alignment: .leading)
                    PriceIn(pr, placeholder: T("ePrice")) { pr0[l.pk] = $0 }.frame(width: 88)
                    Txt(pr > 0 ? money(sm) : "—", 13, bold: true, align: .trailing).frame(width: 86, alignment: .trailing)
                }.padding(.vertical, 7)
            }
            Stat(T(totalKey), money(tot), accent: true)
        }
    }
}
/// Выбор здания, если их несколько
struct BSelector: View {
    @ObservedObject var u = UIS.shared
    var list: [Obj] = buildings()
    var body: some View {
        let p = St.project
        if list.count >= 2 {
            Sec(T("sForBuilding")) { Chips { ForEach(Array(list.enumerated()), id: \.offset) { _, b in Chip(itemName(b), num(b["id"]) == num(p["bSel"])) { p["bSel"] = b["id"]; p["sel"] = b["id"] } } } }
        }
    }
}
struct RateLink: View { let back: String; var body: some View { OBtn("🧮 " + T("rtTitle")) { go("rates", back) }.padding(.horizontal, 16) } }
struct SzLink: View { let back: String; var body: some View { OBtn("📏 " + T("szTitle")) { go("sizes", back) }.padding(.horizontal, 16) } }
/// Свои материалы в разделе
struct ExtrasUI: View {
    @ObservedObject var u = UIS.shared
    let b: Obj; let sec: String
    var body: some View {
        let xs = extrasOf(b, sec); let prices = St.project.o("prices")
        let units: [(String, String)] = [("pcs", "uPcs"), ("m2", "m2"), ("m", "m"), ("m3", "uM3"), ("kg", "uKg")]
        Sec(T("xTitle")) {
            Hint(T("xHint"), top: 0)
            ForEach(Array(xs.objs.enumerated()), id: \.offset) { i, x in
                Divider1()
                HStack(alignment: .bottom, spacing: 6) {
                    TextIn(T("cmName"), x.s("name")) { x["name"] = $0 }.frame(maxWidth: .infinity)
                    TextIn(T("xSize"), x.s("size")) { x["size"] = $0 }.frame(width: 90)
                    IconBtn("✕", C.warn) { xs.a.remove(at: i); upd() }
                }
                Chips { ForEach(units, id: \.0) { (k, l) in Chip(T(l), (x["unit"] as? String) == k) { x["unit"] = k } } }
                HStack(spacing: 6) {
                    NumField(T("xQty"), x.n("qty"), zero: true) { x["qty"] = $0 }
                    NumField(T("fnPriceFor") + " " + T(units.first { $0.0 == (x["unit"] as? String) }?.1 ?? "uPcs") + ", " + St.cur, num(prices["x_" + x.s("uid")]), zero: true) { prices["x_" + x.s("uid")] = $0 }
                }
            }
            OBtn(T("xAdd")) { xs.add(obj(("uid", newUid()), ("name", ""), ("size", ""), ("unit", "pcs"), ("qty", 1.0))); upd() }
        }
    }
}

/// Холст с кнопкой «на весь экран» (в полноэкранном режиме нет прокрутки страницы — жесты работают как в Android)
struct Expandable<Content: View>: View {
    let content: (Bool) -> Content
    @State private var full = false
    @ObservedObject private var fr = Frame.shared
    init(@ViewBuilder _ content: @escaping (Bool) -> Content) { self.content = content }
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content(false)
            Txt("⛶", 20, C.accent, bold: true).frame(width: 40, height: 40).background(C.bg.opacity(0.8)).cornerRadius(20).contentShape(Circle())
                .onTapGesture { full = true }.padding(.trailing, 18).padding(.bottom, 10)
        }
        .fullScreenCover(isPresented: $full) {
            ZStack(alignment: .topLeading) {
                C.bg.ignoresSafeArea()
                VStack { Spacer(minLength: 0); content(true); Spacer(minLength: 0) }
                Txt("✕", 22, C.accent, bold: true).frame(width: 44, height: 44).background(C.card.opacity(0.9)).cornerRadius(22).contentShape(Circle())
                    .onTapGesture { full = false }.padding(.leading, 14).padding(.top, 10)
            }
        }
    }
}
