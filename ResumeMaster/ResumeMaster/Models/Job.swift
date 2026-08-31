import Foundation

/// What the candidate will face at the apply destination, known at browse time.
///
/// The whole reason this is on every job: a `gated` or `account` job CANNOT be completed from a
/// phone. The gated handoff's security property is a desktop browser holding the user's portal
/// session, borrowed for one gesture under the extension's activeTab. There is no extension on
/// iOS, so a row queued from here would park in a state this device can never resolve.
enum AutomationTier: String, Codable, Equatable {
    case direct     // single-page ATS apply, no account
    case guestApply // a guest path exists; the run may still hold for review
    case account    // self-service account required - holds at login_required
    case gated      // account plus CAPTCHA or identity check - desktop handoff only
    case unknown    // not looked at: a promise in NEITHER direction

    /// Whether this device can actually carry the application to a conclusion.
    var isCompletableOnMobile: Bool {
        switch self {
        case .direct, .guestApply: return true
        case .account, .gated, .unknown: return false
        }
    }

    var desktopOnlyReason: String? {
        switch self {
        case .direct, .guestApply: return nil
        case .account:  return "This employer requires an account on their portal. Finish on desktop."
        case .gated:    return "This employer uses a login and an identity check. Finish on desktop."
        case .unknown:  return "We have not checked this employer's apply flow yet. Finish on desktop."
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String?.self)
        // A null tier means the row predates migration 078 and has not been recomputed. The
        // contract is emphatic: read it exactly as `unknown`, never as `direct`. An absent signal
        // is not a safe one.
        switch raw {
        case "direct":  self = .direct
        case "guest":   self = .guestApply
        case "account": self = .account
        case "gated":   self = .gated
        // Anything else - including null, and a value added to the enum after this build shipped -
        // is unknown. A closed decoder that threw here would take the whole feed down over one row.
        default:        self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self == .guestApply ? "guest" : rawValue)
    }
}

/// The job shape from `GET /api/jobs`, as published in Contract/mobile-api.v1.json.
///
/// Derived on the server by executing `mapJobRow.js`, so it cannot disagree with what the server
/// actually emits. Fields are camelCase. Every optional here is optional in the contract.
struct Job: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let company: String
    let location: String
    let url: String
    let applyUrl: String?
    let description: String?
    let summary: String?

    let automationTier: AutomationTier

    let salaryMin: Double?
    let salaryMax: Double?
    /// ISO 4217 where stated. null means the posting gave no currency - NOT that it is USD.
    let salaryCurrency: String?

    let remote: Bool
    let workplaceType: String?
    let experienceLevel: String?
    let contractType: String?
    let skills: [String]
    let matchScore: Double?
    let postedAt: String?
    let companyIconUrl: String?

    /// TRI-STATE, all three. null means no signal yet, and MUST render as absent - never as
    /// "does not sponsor". These are also attestations, so they are never gestured: they inform
    /// the card, they do not become an answer.
    let isH1bSponsor: Bool?
    let requiresWorkAuth: Bool?
    let isClearanceRequired: Bool?

    let starred: Bool
    let disliked: Bool
    let visited: Bool

    /// Where the row was INGESTED from. NOT the ATS the candidate will face - the contract flags
    /// `sourcePlatform` as a known defect for that purpose. Use `automationTier` instead.
    let source: String

    private enum CodingKeys: String, CodingKey {
        case id, title, company, location, url, applyUrl, description, summary, automationTier
        case salaryMin, salaryMax, salaryCurrency, remote, workplaceType, experienceLevel
        case contractType, skills, matchScore, postedAt, companyIconUrl
        case isH1bSponsor, requiresWorkAuth, isClearanceRequired
        case starred, disliked, visited, source
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self, forKey: .id)
        title           = try c.decodeIfPresent(String.self, forKey: .title) ?? "Untitled role"
        company         = try c.decodeIfPresent(String.self, forKey: .company) ?? "Unknown company"
        location        = try c.decodeIfPresent(String.self, forKey: .location) ?? ""
        url             = try c.decodeIfPresent(String.self, forKey: .url) ?? ""
        applyUrl        = try c.decodeIfPresent(String.self, forKey: .applyUrl)
        description     = try c.decodeIfPresent(String.self, forKey: .description)
        summary         = try c.decodeIfPresent(String.self, forKey: .summary)
        automationTier  = (try? c.decode(AutomationTier.self, forKey: .automationTier)) ?? .unknown
        salaryMin       = try c.decodeIfPresent(Double.self, forKey: .salaryMin)
        salaryMax       = try c.decodeIfPresent(Double.self, forKey: .salaryMax)
        salaryCurrency  = try c.decodeIfPresent(String.self, forKey: .salaryCurrency)
        remote          = try c.decodeIfPresent(Bool.self, forKey: .remote) ?? false
        workplaceType   = try c.decodeIfPresent(String.self, forKey: .workplaceType)
        experienceLevel = try c.decodeIfPresent(String.self, forKey: .experienceLevel)
        contractType    = try c.decodeIfPresent(String.self, forKey: .contractType)
        skills          = try c.decodeIfPresent([String].self, forKey: .skills) ?? []
        matchScore      = try c.decodeIfPresent(Double.self, forKey: .matchScore)
        postedAt        = try c.decodeIfPresent(String.self, forKey: .postedAt)
        companyIconUrl  = try c.decodeIfPresent(String.self, forKey: .companyIconUrl)
        isH1bSponsor        = try c.decodeIfPresent(Bool.self, forKey: .isH1bSponsor)
        requiresWorkAuth    = try c.decodeIfPresent(Bool.self, forKey: .requiresWorkAuth)
        isClearanceRequired = try c.decodeIfPresent(Bool.self, forKey: .isClearanceRequired)
        starred         = try c.decodeIfPresent(Bool.self, forKey: .starred) ?? false
        disliked        = try c.decodeIfPresent(Bool.self, forKey: .disliked) ?? false
        visited         = try c.decodeIfPresent(Bool.self, forKey: .visited) ?? false
        source          = try c.decodeIfPresent(String.self, forKey: .source) ?? ""
    }
}

// MARK: - Display helpers

extension Job {
    /// Salary as posted, or nil. Never invents a currency: the contract is explicit that a null
    /// currency does not mean USD, so an unlabelled range is shown without a symbol.
    var salaryText: String? {
        let unit = salaryCurrency.map { code -> String in
            ["USD": "$", "GBP": "GBP ", "EUR": "EUR "][code] ?? "\(code) "
        } ?? ""
        func short(_ value: Double) -> String { "\(unit)\(Int(value / 1000))k" }
        switch (salaryMin, salaryMax) {
        case let (min?, max?): return "\(short(min)) - \(short(max))"
        case let (min?, nil):  return "From \(short(min))"
        case let (nil, max?):  return "Up to \(short(max))"
        default:               return nil
        }
    }

    /// Short chips for the card. Deliberately excludes the tri-state eligibility flags: those are
    /// attestations, and a chip reading "H-1B" beside a null would be a claim the data cannot make.
    var chips: [String] {
        var out: [String] = []
        if remote { out.append("Remote") }
        if let workplaceType, !workplaceType.isEmpty, !remote { out.append(workplaceType.capitalized) }
        if let experienceLevel, !experienceLevel.isEmpty { out.append(experienceLevel.capitalized) }
        if let contractType, !contractType.isEmpty { out.append(contractType.capitalized) }
        return out + skills.prefix(max(0, 4 - out.count))
    }

    var matchPercent: Int? { matchScore.map { Int($0.rounded()) } }
}
