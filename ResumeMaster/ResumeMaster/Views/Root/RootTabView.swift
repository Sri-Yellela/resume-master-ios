import SwiftUI

struct RootTabView: View {
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var localQueue = LocalApplyQueue.shared
    @ObservedObject private var apply = ApplyService.shared

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(DS.ColorToken.surface)
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        Group {
            switch auth.state {
            case .unknown:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.ColorToken.background.ignoresSafeArea())
            case .signedOut:
                LoginView()
            case .signedIn:
                tabs
            }
        }
        .task { await auth.restore() }
    }

    private var tabs: some View {
        TabView {
            JobsView()
                .tabItem { Image(systemName: "briefcase") }

            ReviewQueueView()
                .tabItem { Image(systemName: "tray.full") }
                // The badge is the counterweight to how easy swiping is: a user who swipes 40 and
                // reviews 0 has applied to nothing, and an unbadged tab is an easy thing not to open.
                .badge(reviewBadge)

            ResumeBuilderView()
                .tabItem { Image(systemName: "doc.text") }

            TemplatesView()
                .tabItem { Image(systemName: "rectangle.stack") }

            ProfileView()
                .tabItem { Image(systemName: "person") }
        }
        .tint(DS.ColorToken.primary)
    }

    private var reviewBadge: Int {
        localQueue.count + apply.pending.count
    }
}
