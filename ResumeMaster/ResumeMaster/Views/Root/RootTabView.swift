import SwiftUI
struct RootTabView: View { init(){ let appearance=UITabBarAppearance(); appearance.configureWithTransparentBackground(); appearance.backgroundColor=UIColor(DS.ColorToken.surface); appearance.shadowColor=.clear; UITabBar.appearance().standardAppearance=appearance; UITabBar.appearance().scrollEdgeAppearance=appearance }
    var body: some View { TabView { JobsView().tabItem{Image(systemName:"briefcase")}; ResumeBuilderView().tabItem{Image(systemName:"doc.text")}; TemplatesView().tabItem{Image(systemName:"rectangle.stack")}; ProfileView().tabItem{Image(systemName:"person")} }.tint(DS.ColorToken.primary) }
}
