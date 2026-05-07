import SwiftUI

struct ResumeTemplate: Identifiable, Equatable { let id: UUID; var name: String; var accent: Color; var style: TemplateStyle
    static let classicID = UUID(uuidString:"11111111-1111-1111-1111-111111111111")!
    static let modernID = UUID(uuidString:"22222222-2222-2222-2222-222222222222")!
    static let minimalID = UUID(uuidString:"33333333-3333-3333-3333-333333333333")!
    static let executiveID = UUID(uuidString:"44444444-4444-4444-4444-444444444444")!
    static let creativeID = UUID(uuidString:"55555555-5555-5555-5555-555555555555")!
    static let technicalID = UUID(uuidString:"66666666-6666-6666-6666-666666666666")!
    static let all = [ResumeTemplate(id:classicID,name:"Classic",accent:Color(red:0.05,green:0.15,blue:0.32),style:.classic), ResumeTemplate(id:modernID,name:"Modern",accent:DS.ColorToken.primary,style:.modern), ResumeTemplate(id:minimalID,name:"Minimal",accent:DS.ColorToken.textMuted,style:.minimal), ResumeTemplate(id:executiveID,name:"Executive",accent:Color(red:0.73,green:0.55,blue:0.25),style:.executive), ResumeTemplate(id:creativeID,name:"Creative",accent:Color(red:0.77,green:0.25,blue:0.55),style:.creative), ResumeTemplate(id:technicalID,name:"Technical",accent:Color(red:0.18,green:0.55,blue:0.29),style:.technical)] }
enum TemplateStyle: String, Codable { case classic, modern, minimal, executive, creative, technical }
