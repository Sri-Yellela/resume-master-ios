import Foundation
import SwiftUI

/// Resume-editor state. Job state now lives in the services that own it — JobFeedService for the
/// board, LocalApplyQueue for what the user swiped, ApplyService for what the server is holding —
/// so there is one place to look for each rather than a mirrored copy here that can drift.
@MainActor
final class AppState: ObservableObject {
    @Published var activeResume: Resume
    @Published var selectedTemplateID: UUID?

    init() {
        let loaded = ResumeStore.shared.load() ?? Resume.defaultResume
        activeResume = loaded
        selectedTemplateID = loaded.templateID ?? ResumeTemplate.modernID
    }

    func loadResume() -> Resume { ResumeStore.shared.load() ?? Resume.defaultResume }

    func saveResume() {
        activeResume.lastModified = Date()
        activeResume.templateID = selectedTemplateID
        ResumeStore.shared.save(activeResume)
    }
}
