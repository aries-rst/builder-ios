import SwiftUI
// Заглушки экранов, которые ещё не портированы (убираются по мере переноса)
struct PlotScreen: View { var body: some View { Page { TopBar(T("mPlot"), { go("home") }) } } }
struct FenceScreen: View { var body: some View { Page { TopBar(T("mFence"), { go("home") }) } } }
struct FoundScreen: View { var body: some View { Page { TopBar(T("mFound"), { go("home") }) } } }
struct WallsScreen: View { var body: some View { Page { TopBar(T("mWalls"), { go("home") }) } } }
struct RoofScreen: View { var body: some View { Page { TopBar(T("mRoof"), { go("home") }) } } }
struct FinishScreen: View { var body: some View { Page { TopBar(T("mFinish"), { go("home") }) } } }
struct EngScreen: View { var body: some View { Page { TopBar(T("mEng"), { go("home") }) } } }
struct ExtraScreen: View { var body: some View { Page { TopBar(T("mExtra"), { go("home") }) } } }
struct EstimateScreen: View { var body: some View { Page { TopBar(T("mEstimate"), { go("home") }) } } }
struct ScheduleScreen: View { var body: some View { Page { TopBar(T("mSchedule"), { go("home") }) } } }
struct RoomsScreen: View { var body: some View { Page { TopBar(T("mRooms"), { go("home") }) } } }
struct View3DScreen: View { var body: some View { Page { TopBar("3D", { go("home") }) } } }
struct StakingScreen: View { var body: some View { Page { TopBar(T("mStaking"), { go("home") }) } } }
