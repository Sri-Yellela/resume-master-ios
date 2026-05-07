import Foundation
import SwiftUI
@MainActor final class AppState: ObservableObject { @Published var jobs:[Job]=Job.mockJobs; @Published var queue:[Job]=[]; @Published var starred:[Job]=[]; @Published var activeResume: Resume; @Published var selectedTemplateID: UUID?
    init(){let loaded=ResumeStore.shared.load() ?? Resume.defaultResume; activeResume=loaded; selectedTemplateID=loaded.templateID ?? ResumeTemplate.modernID}
    func handle(action:SwipeAction, for job:Job){switch action{case .queue: if !queue.contains(job){queue.append(job)}; case .apply: if !queue.contains(job){queue.append(job)}; case .star: if !starred.contains(job){starred.append(job)}; case .dislike,.skip: break}; jobs.removeAll{$0.id==job.id}; if jobs.count < 5 { jobs.append(contentsOf: Job.mockJobs.shuffled().prefix(3)) } }
    func loadResume()->Resume { ResumeStore.shared.load() ?? Resume.defaultResume }
    func saveResume(){ activeResume.lastModified=Date(); activeResume.templateID=selectedTemplateID; ResumeStore.shared.save(activeResume) }
}
