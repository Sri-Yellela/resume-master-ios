import SwiftUI
@main struct ResumeMasterApp: App { @StateObject var appState = AppState(); var body: some Scene { WindowGroup { RootTabView().environmentObject(appState).preferredColorScheme(nil) } } }
