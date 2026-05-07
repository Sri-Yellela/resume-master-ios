import Foundation

enum SwipeAction: String, Codable, Equatable, CaseIterable {
    case queue, apply, star, dislike, skip
    var badgeTitle: String { switch self { case .queue: "Queued for auto-apply"; case .apply: "Application sent"; case .star: "Saved to starred"; case .dislike, .skip: "Skipped" } }
}
