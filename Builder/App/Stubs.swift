import SwiftUI
// Заглушки экранов, которые ещё не портированы (убираются по мере переноса)
struct PlotScreen: View { var body: some View { Page { TopBar(T("mPlot"), { go("home") }) } } }
struct FenceScreen: View { var body: some View { Page { TopBar(T("mFence"), { go("home") }) } } }
struct RoomsScreen: View { var body: some View { Page { TopBar(T("mRooms"), { go("home") }) } } }
struct View3DScreen: View { var body: some View { Page { TopBar("3D", { go("home") }) } } }
struct StakingScreen: View { var body: some View { Page { TopBar(T("mStaking"), { go("home") }) } } }
