import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var auth = AuthService.shared
    @ObservedObject private var localQueue = LocalApplyQueue.shared
    @ObservedObject private var apply = ApplyService.shared

    @State private var confirmingSignOut = false
    @State private var showingExport = false

    var body: some View {
        NavigationStack {
            Form {
                Section("User") {
                    if case .signedIn(let user) = auth.state, let username = user?.username {
                        LabeledContent("Signed in as", value: username)
                    }
                    TextField("Name", text: $appState.activeResume.name)
                        .onSubmit { appState.saveResume() }
                    Text("Last updated \(appState.activeResume.lastModified.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(DS.ColorToken.textMuted)
                }

                Section {
                    LabeledContent("Waiting for review", value: "\(localQueue.count)")
                    LabeledContent("Ready to send", value: "\(apply.pending.count)")
                    if let cap = apply.queueCap, let limit = cap.limit, let remaining = cap.remaining {
                        LabeledContent("Daily generation limit", value: "\(remaining) of \(limit) left")
                    }
                } header: {
                    Text("Applications")
                } footer: {
                    Text("Nothing is sent to an employer until you approve it in the Review tab.")
                }

                Section("Resume") {
                    // Previously unreachable: ExportView existed with a working PDF renderer but
                    // nothing in the app navigated to it, so the README's export claim could not
                    // be exercised by a user. Presented as a sheet rather than pushed because
                    // ExportView carries its own NavigationStack, and nesting one inside a push
                    // gives two navigation bars.
                    Button("Preview and export PDF") { showingExport = true }
                }

                Section("App") {
                    Text("\(APIConfig.brand) iOS")
                    LabeledContent("API contract", value: APIConfig.contractVersion)
                    Text("Minimum deployment target: iOS 17")
                }

                Section {
                    Button("Sign out", role: .destructive) { confirmingSignOut = true }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExport) { ExportView() }
            .confirmationDialog("Sign out?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) { Task { await auth.signOut() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Jobs waiting for review on this device are kept.")
            }
        }
    }
}
