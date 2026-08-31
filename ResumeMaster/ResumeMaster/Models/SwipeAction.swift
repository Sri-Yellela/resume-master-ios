import Foundation

enum SwipeAction: String, Codable, Equatable, CaseIterable {
    case queue, priorityQueue, star, dislike, skip
    var badgeTitle: String { switch self { case .queue: "Queued for review"; case .priorityQueue: "Queued first - review to send"; case .star: "Saved to starred"; case .dislike, .skip: "Skipped" } }
}
