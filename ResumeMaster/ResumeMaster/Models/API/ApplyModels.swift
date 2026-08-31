import Foundation

// MARK: - Queueing

struct QueueRunRequest: Encodable {
    let jobIds: [String]
    let tool: String
    let mode: String
    // `approvalMode` is deliberately absent. Sending "approved" is REJECTED with 400 by design —
    // it is reserved for the approve endpoint, so no client can submit without previewing first.
}

/// The GENERATION cost budget. Reported so the app can show what is left, rather than letting the
/// user discover the ceiling by being refused at it.
struct QueueCap: Decodable, Equatable {
    let limit: Int?
    let queuedLast24h: Int?
    let remaining: Int?
}

/// The SUBMISSION budget - a different ceiling from the queue cap.
struct DailyCap: Decodable, Equatable {
    let limit: Int?
    let submittedLast24h: Int?
    let remaining: Int?
}

/// 202 from `POST /api/apply/runs`.
///
/// QUEUED, NOT SUBMITTED. The contract calls showing "Applied" here the single most dangerous
/// thing a mobile client can get wrong. Nothing reaches an employer until `POST /api/apply/approve`.
struct RunQueuedResponse: Decodable {
    let ok: Bool?
    let runId: Int?
    /// The ids ACCEPTED after duplicates were dropped. Shorter than what was sent when the server
    /// deduplicated, and the only correct thing to count.
    let queued: [String]
    let totalJobs: Int?
    let mode: String?
    let toolType: String?
    let queueCap: QueueCap?
    let dailyCap: DailyCap?

    private enum CodingKeys: String, CodingKey {
        case ok, runId, queued, totalJobs, mode, toolType, queueCap, dailyCap
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok        = try c.decodeIfPresent(Bool.self, forKey: .ok)
        runId     = try c.decodeIfPresent(Int.self, forKey: .runId)
        queued    = try c.decodeIfPresent([String].self, forKey: .queued) ?? []
        totalJobs = try c.decodeIfPresent(Int.self, forKey: .totalJobs)
        mode      = try c.decodeIfPresent(String.self, forKey: .mode)
        toolType  = try c.decodeIfPresent(String.self, forKey: .toolType)
        queueCap  = try c.decodeIfPresent(QueueCap.self, forKey: .queueCap)
        dailyCap  = try c.decodeIfPresent(DailyCap.self, forKey: .dailyCap)
    }
}

// MARK: - The review inbox

struct PendingResponse: Decodable {
    let pending: [PendingItem]
}

/// One application previewed and awaiting a decision.
struct PendingItem: Decodable, Identifiable, Equatable {
    let runJobId: Int
    let runId: Int?
    let jobId: String
    /// nil when the posting expired after the application was created. The row still names jobId,
    /// so an application is never anonymous even once its target is gone.
    let title: String?
    let company: String?
    let applyUrl: String?
    let createdAt: Double?
    let answerCount: Int?
    /// How many answers came from a FUZZY label match rather than an exact one. Surfaced at list
    /// level so a reviewer sees which applications need attention without opening each.
    let guessCount: Int?
    let screenshotAvailable: Bool?
    let resume: PendingResume?

    var id: Int { runJobId }

    var displayTitle: String { title ?? "Posting no longer listed" }
    var displayCompany: String { company ?? "Unknown company" }
    var needsAttention: Bool { (guessCount ?? 0) > 0 }
}

struct PendingResume: Decodable, Equatable {
    let artifactId: Int?
    let atsScore: Double?
    let available: Bool?
}

// MARK: - Deciding

struct DecisionRequest: Encodable {
    let runJobIds: [Int]
}

/// 202 from `POST /api/apply/approve`.
///
/// Approval creates a NEW run; the ids sent become "superseded" and the submission lives on new
/// runJobIds. The started run is NESTED under `run`, not flattened into this body.
struct ApproveResponse: Decodable {
    let ok: Bool?
    /// The runJobIds actually approved - the ids sent, now superseded.
    let approved: [Int]
    /// How many of the ids sent were not approvable. Non-zero with ok:true is a PARTIAL SUCCESS,
    /// not a failure: re-fetch pending rather than reporting an error.
    let skipped: Int?
    let run: RunQueuedResponse?

    private enum CodingKeys: String, CodingKey { case ok, approved, skipped, run }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok       = try c.decodeIfPresent(Bool.self, forKey: .ok)
        approved = try c.decodeIfPresent([Int].self, forKey: .approved) ?? []
        skipped  = try c.decodeIfPresent(Int.self, forKey: .skipped)
        run      = try c.decodeIfPresent(RunQueuedResponse.self, forKey: .run)
    }
}

struct RejectResponse: Decodable {
    let ok: Bool?
    let rejected: [Int]

    private enum CodingKeys: String, CodingKey { case ok, rejected }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok       = try c.decodeIfPresent(Bool.self, forKey: .ok)
        rejected = try c.decodeIfPresent([Int].self, forKey: .rejected) ?? []
    }
}

/// `GET /api/apply/readiness`. A 503 here is a STATE, not a failure - render it, do not retry it.
struct ReadinessResponse: Decodable {
    let available: Bool
    let reason: String?
}

// MARK: - Provenance

/// One field the automation filled, WITH THE RULE THAT PRODUCED IT.
///
/// The provenance distinction is the entire point of showing this: `label_fuzzy` is a guess;
/// `handler_exact`, `field_map_exact` and `custom_answer` are not. Flattening them away turns a
/// reviewable application into a rubber stamp.
struct ResolvedAnswer: Decodable, Identifiable, Equatable {
    let field: String?
    let type: String?
    let value: String?
    let provenance: String?
    let confidence: Double?
    let matchedOn: String?
    let skipped: Bool?

    var id: String { (field ?? "?") + "|" + (provenance ?? "") }

    /// True when this answer came from a fuzzy label match and therefore needs a human to look.
    var isGuess: Bool { provenance == "label_fuzzy" }

    var provenanceLabel: String {
        switch provenance {
        case "handler_exact":   return "Exact field match"
        case "field_map_exact": return "Exact field map"
        case "custom_answer":   return "Your saved answer"
        case "label_fuzzy":     return "Guessed from a similar label"
        case .none:             return "No rule recorded"
        case .some(let other):  return other.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    private enum CodingKeys: String, CodingKey {
        case field, name, label, type, value, provenance, confidence
        case matchedOn = "matched_on"
        case skipped
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // Producers on the server spell this `field`, `label` or `name` depending on the path
        // that wrote the row, so accept all three rather than showing a blank line.
        field = try c.decodeIfPresent(String.self, forKey: .field)
            ?? c.decodeIfPresent(String.self, forKey: .label)
            ?? c.decodeIfPresent(String.self, forKey: .name)
        type       = try c.decodeIfPresent(String.self, forKey: .type)
        // A value may arrive as a string, a number or a bool.
        if let s = try? c.decodeIfPresent(String.self, forKey: .value) { value = s }
        else if let d = try? c.decodeIfPresent(Double.self, forKey: .value) { value = d.formatted() }
        else if let b = try? c.decodeIfPresent(Bool.self, forKey: .value) { value = b ? "Yes" : "No" }
        else { value = nil }
        provenance = try c.decodeIfPresent(String.self, forKey: .provenance)
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence)
        matchedOn  = try c.decodeIfPresent(String.self, forKey: .matchedOn)
        skipped    = try c.decodeIfPresent(Bool.self, forKey: .skipped)
    }
}

/// `GET /api/apply/run-jobs/{runJobId}/review` - what approving actually shows.
struct RunJobReviewResponse: Decodable {
    let runJobId: Int
    let runId: Int?
    let jobId: String
    let title: String?
    let company: String?
    let status: String?
    let mode: String?
    let reasonCode: String?
    let reasonDetail: String?
    let answers: [ResolvedAnswer]
    /// The LABELS of required fields left blank. A hold saying "required fields were left empty"
    /// without saying which is a hold the candidate cannot act on.
    let missingRequired: [String]
    let resume: PendingResume?
    let screenshotAvailable: Bool?

    private enum CodingKeys: String, CodingKey {
        case runJobId, runId, jobId, title, company, status, mode, reasonCode, reasonDetail
        case answers, missingRequired, resume, screenshotAvailable
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        runJobId        = try c.decode(Int.self, forKey: .runJobId)
        runId           = try c.decodeIfPresent(Int.self, forKey: .runId)
        jobId           = try c.decodeIfPresent(String.self, forKey: .jobId) ?? ""
        title           = try c.decodeIfPresent(String.self, forKey: .title)
        company         = try c.decodeIfPresent(String.self, forKey: .company)
        status          = try c.decodeIfPresent(String.self, forKey: .status)
        mode            = try c.decodeIfPresent(String.self, forKey: .mode)
        reasonCode      = try c.decodeIfPresent(String.self, forKey: .reasonCode)
        reasonDetail    = try c.decodeIfPresent(String.self, forKey: .reasonDetail)
        answers         = try c.decodeIfPresent([ResolvedAnswer].self, forKey: .answers) ?? []
        missingRequired = try c.decodeIfPresent([String].self, forKey: .missingRequired) ?? []
        resume          = try c.decodeIfPresent(PendingResume.self, forKey: .resume)
        screenshotAvailable = try c.decodeIfPresent(Bool.self, forKey: .screenshotAvailable)
    }

    var guesses: [ResolvedAnswer] { answers.filter(\.isGuess) }
    var confirmed: [ResolvedAnswer] { answers.filter { !$0.isGuess } }
}
