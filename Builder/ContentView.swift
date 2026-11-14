import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("🏠").font(.system(size: 64))
            Text("Строитель").font(.largeTitle).bold()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.118, green: 0.137, blue: 0.157))
        .foregroundColor(.white)
    }
}
