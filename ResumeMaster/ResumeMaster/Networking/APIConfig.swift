import Foundation

/// Where the app talks to, and the one contract version it was written against.
enum APIConfig {
    /// The public brand. One place, so a screen and the home-screen icon cannot disagree.
    static let brand = "Draft"

    /// Bare apex, no www — see docs/BRAND.md in the server repository.
    static let baseURL = URL(string: "https://jobsviadraft.com")!

    /// The vendored contract this client was built against — see Contract/ and
    /// scripts/verify-contract.mjs. Bump only together with a re-copy of those files.
    static let contractVersion = "1.1.0"

    /// How many jobs to pull per cursor page. The feed is swiped roughly one job per second,
    /// so a page needs to outlast a burst without making the first paint wait on a large body.
    static let feedPageSize = 25

    /// POST /api/apply/runs accepts at most 25 job ids per call.
    static let maxJobsPerRun = 25
}
