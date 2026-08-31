import Foundation

/// The swipe feed.
///
/// Two things here are not stylistic choices:
///
/// 1. **It pages by `cursor`, never by `page`.** A swipe feed mutates the set it is paging through:
///    a dislike sets `disliked=1` and the default board excludes disliked rows, so with offset
///    paging every subsequent row shifts up and page 2 skips as many jobs as were swiped on page 1
///    — measured at 6 of 25 with three swipes per page, never shown, with nothing reporting the
///    loss. The cursor anchors to the last row's own sort values, so removals behind it cannot
///    move it.
///
/// 2. **Tier filtering is `tiers_include`, server-side.** `tiers_exclude=gated,account` looks
///    equivalent and is not: a row whose tier is NULL is "not known to be gated", so an exclude
///    list KEEPS it, and an unclassifiable job reaches a phone that cannot finish it.
///    `tiers_include=direct,guest` admits only rows explicitly known to be completable here.
///    Filtering client-side is also wrong — the server pages before the client filters, so hiding
///    rows after the fact yields short pages and a count that disagrees with the list.
@MainActor
final class JobFeedService: ObservableObject {
    static let shared = JobFeedService()

    @Published private(set) var jobs: [Job] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isExhausted = false
    @Published var errorMessage: String?

    /// A snapshot count that shrinks as the user swipes. A progress denominator, not a promise
    /// about how many more are coming — so it is never rendered as "showing N of M".
    @Published private(set) var totalAtLastFetch: Int?

    private let client = APIClient.shared
    private var cursor: String?
    private var seenIDs = Set<String>()

    /// The only tiers this device can carry to a conclusion.
    private static let mobileCompletableTiers = ["direct", "guest"]

    private init() {}

    var isEmpty: Bool { jobs.isEmpty }

    func refresh() async {
        cursor = nil
        seenIDs.removeAll()
        jobs = []
        isExhausted = false
        errorMessage = nil
        await loadNextPage()
    }

    /// Called as the deck runs down. Loads one more page if there is one.
    func loadMoreIfNeeded(remaining: Int) async {
        guard remaining <= 5, !isLoading, !isExhausted else { return }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard !isLoading, !isExhausted else { return }
        isLoading = true
        defer { isLoading = false }

        var query = [
            URLQueryItem(name: "pageSize", value: String(APIConfig.feedPageSize)),
            URLQueryItem(name: "tiers_include", value: Self.mobileCompletableTiers.joined(separator: ",")),
        ]
        // Omit `cursor` for the first page, then follow nextCursor until it is null.
        if let cursor { query.append(URLQueryItem(name: "cursor", value: cursor)) }

        do {
            let page = try await client.get("/api/jobs", query: query, as: JobFeedResponse.self)

            // De-duplicate defensively. The cursor should not re-serve a row, but a feed that
            // shows the same job twice costs the user a second swipe on a decision already made.
            let fresh = page.jobs.filter { seenIDs.insert($0.id).inserted }
            jobs.append(contentsOf: fresh)

            totalAtLastFetch = page.total
            cursor = page.nextCursor
            // nextCursor == nil is the server stating this was the last page, established by
            // over-fetching a row rather than by comparing counts.
            isExhausted = page.nextCursor == nil
            errorMessage = nil

        } catch APIError.cursorInvalid {
            // The cursor belongs to an ordering that no longer applies. Starting over is the
            // documented recovery; rendering an arbitrary slice is not.
            cursor = nil
            seenIDs.removeAll()
            jobs = []
            await loadNextPage()

        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = APIError.transport(error.localizedDescription).userMessage
        }
    }

    /// Drop a job from the local deck once it has been acted on.
    func remove(_ job: Job) {
        jobs.removeAll { $0.id == job.id }
    }

    /// Record a swipe against the board so the server stops serving it back.
    ///
    /// Uses `PATCH /api/jobs/interact`, which sets an ABSOLUTE value, and never the per-id
    /// `/starred` route, which TOGGLES: on a phone network a retried or double-sent toggle
    /// silently undoes the user's swipe and still answers 200. An absolute write is idempotent.
    ///
    /// Fire-and-forget: a failed interaction must not block the next card.
    func recordInteraction(_ job: Job, action: SwipeAction) async {
        struct Interaction: Encodable {
            let jobId: String
            let starred: Bool?
            let disliked: Bool?
        }

        let body: Interaction
        switch action {
        case .dislike:
            body = Interaction(jobId: job.id, starred: nil, disliked: true)
        case .star:
            body = Interaction(jobId: job.id, starred: true, disliked: nil)
        case .queue, .priorityQueue:
            // Queueing is not a board signal — the job's fate now lives in the apply queue, and
            // marking it disliked would hide it from the review the user is about to do.
            return
        case .skip:
            // A skip is a deferral, not a judgement. Writing `disliked` here would quietly make
            // "not now" mean "never".
            return
        }
        _ = try? await client.patch("/api/jobs/interact", body: body, as: InteractResponse.self)
    }
}
