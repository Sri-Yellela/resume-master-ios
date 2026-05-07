import Foundation

struct Job: Identifiable, Codable, Equatable {
    let id: UUID
    var company: String
    var role: String
    var location: String
    var salary: String?
    var tags: [String]
    var matchScore: Int
    var logoColor: String
    var description: String
    var postedDate: Date
    init(id: UUID = UUID(), company: String, role: String, location: String, salary: String? = nil, tags: [String], matchScore: Int, logoColor: String, description: String, postedDate: Date = Date()) { self.id=id; self.company=company; self.role=role; self.location=location; self.salary=salary; self.tags=tags; self.matchScore=matchScore; self.logoColor=logoColor; self.description=description; self.postedDate=postedDate }
    static let mockJobs: [Job] = [
        Job(company:"Google", role:"iOS Software Engineer", location:"Mountain View, CA", salary:"$158k - $214k", tags:["Hybrid","Full-time","Swift"], matchScore:94, logoColor:"#4285F4", description:"Build high-quality native iOS experiences used by millions of people while collaborating with product, design, and infrastructure teams."),
        Job(company:"Stripe", role:"Product Engineer", location:"San Francisco, CA", salary:"$170k - $230k", tags:["Backend","Full-time","Fintech"], matchScore:91, logoColor:"#635BFF", description:"Design and build product surfaces for payments, billing, and financial infrastructure from technical design through production rollout."),
        Job(company:"Linear", role:"Product Designer", location:"Remote", salary:"$140k - $190k", tags:["Remote","Design Systems","B2B"], matchScore:89, logoColor:"#5E6AD2", description:"Craft fast, focused product experiences for modern software teams across interaction design, systems thinking, and visual polish."),
        Job(company:"Notion", role:"Mobile Product Manager", location:"New York, NY", salary:"$150k - $210k", tags:["Hybrid","Product","AI"], matchScore:86, logoColor:"#111111", description:"Lead mobile roadmap planning for productivity workflows and partner with engineering and research to launch useful features."),
        Job(company:"Figma", role:"Design Systems Engineer", location:"San Francisco, CA", salary:"$165k - $220k", tags:["Frontend","Design","Systems"], matchScore:92, logoColor:"#A259FF", description:"Bridge design and engineering by building reusable components, documentation, and tooling for collaborative interface design."),
        Job(company:"Airbnb", role:"Senior iOS Engineer", location:"Remote US", salary:"$180k - $245k", tags:["Remote","SwiftUI","Travel"], matchScore:88, logoColor:"#FF5A5F", description:"Create polished mobile guest and host experiences with SwiftUI, performance-minded architecture, and strong product collaboration."),
        Job(company:"OpenAI", role:"Product Designer, Mobile", location:"San Francisco, CA", salary:"$170k - $240k", tags:["AI","Mobile","Design"], matchScore:84, logoColor:"#10A37F", description:"Design responsible AI product experiences for mobile users and prototype interaction patterns with engineering partners."),
        Job(company:"Dropbox", role:"Staff Frontend Engineer", location:"Seattle, WA", salary:"$175k - $235k", tags:["Hybrid","Collaboration","React"], matchScore:82, logoColor:"#0061FF", description:"Lead frontend architecture for collaboration workflows, mentor engineers, and improve quality across shared product surfaces."),
        Job(company:"Canva", role:"Template Experience Engineer", location:"Austin, TX", salary:"$135k - $180k", tags:["Creative Tools","Full-time","UX"], matchScore:87, logoColor:"#00C4CC", description:"Build editing and template experiences that help people create beautiful documents quickly across web and mobile surfaces."),
        Job(company:"Shopify", role:"Developer Experience PM", location:"Remote", salary:"$145k - $200k", tags:["Remote","Platform","Commerce"], matchScore:80, logoColor:"#95BF47", description:"Shape developer workflows for commerce APIs and tooling, balancing customer insight, technical constraints, and platform strategy.")]
}
