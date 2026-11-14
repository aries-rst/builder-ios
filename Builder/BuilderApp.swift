import SwiftUI

@main
struct BuilderApp: App {
    init() { Store.initApp(); Premium.initApp() }
    var body: some Scene { WindowGroup { Root().onAppear { AdManager.initialize() } } }
}
