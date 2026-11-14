import SwiftUI

struct PromoApp { let pkg: String; let emoji: String; let names: [String]; func name() -> String { tr3(Arr(names.map { $0 as Any })) } }
enum CrossPromo {
    static let SELF = "com.builder.app"
    static let SITE = "https://aresti-labs.web.app"
    static let all: [PromoApp] = [
        PromoApp(pkg: SITE, emoji: "🌐", names: ["aresti-labs.web.app", "aresti-labs.web.app", "aresti-labs.web.app"]),
        PromoApp(pkg: "nardygame", emoji: "🎲", names: ["Нарды", "Backgammon", "Nard"]),
        PromoApp(pkg: "chesspuzzledaily", emoji: "♟️", names: ["Шахматная задача", "Chess Puzzle", "Shaxmat masalasi"]),
        PromoApp(pkg: "checkersgame", emoji: "⚪", names: ["Шашки", "Checkers", "Shashka"]),
        PromoApp(pkg: "durakgame", emoji: "🃏", names: ["Дурак", "Durak", "Durak"]),
        PromoApp(pkg: "dominogame", emoji: "🁫", names: ["Домино", "Dominoes", "Domino"]),
        PromoApp(pkg: "trueorlie", emoji: "❓", names: ["Правда или ложь", "True or Lie", "Rost yoki yolg‘on"]),
        PromoApp(pkg: "capitalsquiz", emoji: "🏛️", names: ["Столицы мира", "World Capitals", "Dunyo poytaxtlari"]),
        PromoApp(pkg: "flagsquiz", emoji: "🚩", names: ["Флаги мира", "World Flags", "Dunyo bayroqlari"]),
        PromoApp(pkg: "authorsquiz", emoji: "📚", names: ["Авторы и произведения", "Authors & Works", "Mualliflar va asarlar"]),
        PromoApp(pkg: "catsquiz", emoji: "🐱", names: ["Породы кошек", "Cat Breeds", "Mushuk zotlari"]),
        PromoApp(pkg: "dogsquiz", emoji: "🐶", names: ["Породы собак", "Dog Breeds", "It zotlari"]),
        PromoApp(pkg: "dinoquiz", emoji: "🦖", names: ["Динозавры", "Dinosaurs", "Dinozavrlar"]),
        PromoApp(pkg: "rareanimals", emoji: "🐼", names: ["Редкие животные", "Rare Animals", "Noyob hayvonlar"]),
        PromoApp(pkg: "seacreaturesquiz", emoji: "🐙", names: ["Морские обитатели", "Sea Creatures", "Dengiz jonzotlari"]),
        PromoApp(pkg: "weaponsquiz", emoji: "⚔️", names: ["Холодное оружие", "Edged Weapons", "Sovuq qurollar"]),
        PromoApp(pkg: "actorquiz", emoji: "🎬", names: ["Звёзды кино", "Movie Stars", "Kino yulduzlari"]),
        PromoApp(pkg: "autoindicator", emoji: "🚗", names: ["Авто: ошибки на табло", "Dashboard Warning Lights", "Avto: paneldagi xatolar"]),
        PromoApp(pkg: "buildpc", emoji: "🖥️", names: ["Мастер ПК", "PC Builder", "Kompyuter ustasi"]),
        PromoApp(pkg: "comicmaker", emoji: "💬", names: ["Комикс-конструктор", "Comics Maker", "Komiks yaratuvchi"]),
        PromoApp(pkg: "myfamilytree", emoji: "🌳", names: ["Моё древо", "My Family Tree", "Shajaram"]),
        PromoApp(pkg: "myoffice", emoji: "🏢", names: ["Мой офис", "My Office", "Mening ofisim"]),
    ]
    /// На iOS все ссылки ведут на сайт со списком приложений (прямые ссылки App Store добавятся по мере публикации).
    static func open(_ pkg: String) { if let u = URL(string: SITE) { UIApplication.shared.open(u) } }
}
struct CrossPromoRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Txt(T("morePromo"), 13, C.muted, bold: true).padding(.leading, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { ForEach(CrossPromo.all, id: \.pkg) { a in
                    Txt("\(a.emoji) \(a.name())", 13).padding(.horizontal, 12).padding(.vertical, 8).background(C.card).cornerRadius(16).onTapGesture { CrossPromo.open(a.pkg) } } }.padding(.horizontal, 12)
            }
        }.padding(.top, 8)
    }
}
