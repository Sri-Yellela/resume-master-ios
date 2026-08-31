import Foundation

/// One page of `GET /api/jobs`.
struct JobFeedResponse: Decodable {
    let success: Bool
    let jobs: [Job]

    /// Opaque. Pass back as `?cursor=` for the next page. **nil means this is the last page** —
    /// the server establishes that by over-fetching one row, so it is a fact, not an inference.
    let nextCursor: String?

    /// Which mode answered THIS request, "cursor" or "offset". When it is "cursor", `page` and
    /// `totalPages` are meaningless — there is no page number to be on.
    let paging: String?

    /// The count of matching rows AT THIS MOMENT. On a swipe feed it shrinks as the user swipes,
    /// so it is a progress denominator, not a promise about how many more are coming.
    let total: Int?

    private enum CodingKeys: String, CodingKey {
        case success, jobs, nextCursor, paging, total
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success    = try c.decodeIfPresent(Bool.self, forKey: .success) ?? true
        jobs       = try c.decodeIfPresent([Job].self, forKey: .jobs) ?? []
        nextCursor = try c.decodeIfPresent(String.self, forKey: .nextCursor)
        paging     = try c.decodeIfPresent(String.self, forKey: .paging)
        total      = try c.decodeIfPresent(Int.self, forKey: .total)
    }
}
