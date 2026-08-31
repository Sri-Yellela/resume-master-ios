import Foundation

/// The free half of the queue.
///
/// A right-swipe lands here and nowhere else. This is the whole reason it exists: on the server,
/// `POST /api/apply/runs` GENERATES a tailored resume per job — about $0.04 each — and swiping is
/// about a second per job. Wiring the swipe straight to that endpoint would mean five idle minutes
/// of thumbing costs roughly 60 jobs and $2.40, spent before the user has read anything. So the
/// gesture writes a row here, which costs nothing, and the spend happens later at an explicit tap
/// in the review queue.
///
/// It also persists. An in-memory queue loses the user's swipes on app termination, which on a
/// phone happens constantly — and a queue the user cannot trust to still be there is a queue they
/// stop using.
@MainActor
final class LocalApplyQueue: ObservableObject {
    static let shared = LocalApplyQueue()

    /// Just enough to render the row and to queue it later. Not the whole job: this is a durable
    /// local cache, and a stale copy of a full posting would be worse than re-fetching one.
    struct Entry: Codable, Identifiable, Equatable {
        let jobId: String
        let title: String
        let company: String
        let applyUrl: String?
        let queuedAt: Date
        /// True when the user threw the card rather than nudging it. Sorts to the top; it has
        /// never meant "send this now".
        var prioritised: Bool

        var id: String { jobId }
    }

    @Published private(set) var entries: [Entry] = []

    private let defaultsKey = "localApplyQueue.v1"

    private init() { load() }

    var count: Int { entries.count }

    func contains(_ jobId: String) -> Bool { entries.contains { $0.jobId == jobId } }

    /// Add a job. Returns false if the job cannot be completed on this device, which the caller
    /// surfaces rather than silently dropping.
    @discardableResult
    func add(_ job: Job, prioritised: Bool) -> Bool {
        // Defence in depth. The feed already asks the server for completable tiers only, but a
        // queue that a phone cannot resolve is the exact failure this app must not create, so the
        // check is repeated at the point of write rather than trusted from upstream.
        guard job.automationTier.isCompletableOnMobile else { return false }

        if let existing = entries.firstIndex(where: { $0.jobId == job.id }) {
            // Re-swiping an already-queued job promotes it; it never duplicates the row, and it
            // never demotes one the user already threw.
            if prioritised { entries[existing].prioritised = true }
        } else {
            entries.append(Entry(
                jobId: job.id,
                title: job.title,
                company: job.company,
                applyUrl: job.applyUrl ?? job.url,
                queuedAt: Date(),
                prioritised: prioritised))
        }
        sortAndSave()
        return true
    }

    func remove(_ jobIds: [String]) {
        let doomed = Set(jobIds)
        entries.removeAll { doomed.contains($0.jobId) }
        save()
    }

    func removeAll() {
        entries.removeAll()
        save()
    }

    private func sortAndSave() {
        // Prioritised first, then oldest first: a queue the user has been adding to all week
        // should hand back the thing they queued first, not the thing they queued last.
        entries.sort { lhs, rhs in
            lhs.prioritised == rhs.prioritised
                ? lhs.queuedAt < rhs.queuedAt
                : lhs.prioritised && !rhs.prioritised
        }
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        entries = decoded
    }
}
