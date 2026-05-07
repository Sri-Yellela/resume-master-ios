import Foundation
import SwiftData
@Model final class StoredResume { @Attribute(.unique) var key: String; var data: Data; var updatedAt: Date; init(key:String,data:Data,updatedAt:Date=Date()){self.key=key; self.data=data; self.updatedAt=updatedAt} }
@MainActor final class ResumeStore { static let shared = ResumeStore(); let container: ModelContainer?; private init(){container = try? ModelContainer(for: StoredResume.self)}
    func load()->Resume? { guard let context=container?.mainContext else { return loadDefaults() }; let descriptor=FetchDescriptor<StoredResume>(predicate:#Predicate{$0.key == "active"}); if let stored=try? context.fetch(descriptor).first, let resume=try? JSONDecoder().decode(Resume.self,from:stored.data){return resume}; return loadDefaults() }
    func save(_ resume: Resume){ guard let data=try? JSONEncoder().encode(resume) else { return }; if let context=container?.mainContext { let descriptor=FetchDescriptor<StoredResume>(predicate:#Predicate{$0.key == "active"}); if let existing=try? context.fetch(descriptor).first { existing.data=data; existing.updatedAt=Date() } else { context.insert(StoredResume(key:"active",data:data)) }; try? context.save() } else { UserDefaults.standard.set(data,forKey:"activeResume") } }
    private func loadDefaults()->Resume? { guard let data=UserDefaults.standard.data(forKey:"activeResume") else { return nil }; return try? JSONDecoder().decode(Resume.self,from:data) }
}
