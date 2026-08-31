import Foundation

/// The paid half of the queue, and the approval flow.
///
/// Three server states, and the difference between them is the whole product:
///
///   local queue  ->  POST /api/apply/runs  ->  held_review  ->  POST /api/apply/approve
///   (free)           (GENERATES a resume)     (previewed)       (THE moment of submission)
///
/// A 202 from `runs` means QUEUED, NOT SUBMITTED. The contract names showing "Applied" there as
/// the single most dangerous thing a mobile client can get wrong, and it is right: nothing reaches
/// an employer until `approve`.
@MainActor
final class ApplyService: ObservableObject {
    static let shared = ApplyService()

    @Published private(set) var pending: [PendingItem] = []
    @Published private(set) var queueCap: QueueCap?
    @Published private(set) var readiness: ReadinessResponse?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published var notice: String?

    private let client = APIClient.shared

    private init() {}

    /// What is left of today's generation budget, or nil if not yet known.
    var queueRemaining: Int? { queueCap?.remaining }

    // MARK: - Readiness

    func loadReadiness() async {
        do {
            readiness = try await client.get("/api/apply/readiness", as: ReadinessResponse.self)
        } catch APIError.unavailable(let reason) {
            // 503 is a STATE, not a failure. Render it; do not retry it in a loop.
            readiness = ReadinessResponse(available: false, reason: reason)
        } catch {
            readiness = nil
        }
    }

    // MARK: - The review inbox

    func loadPending() async {
        do {
            // Capped at 100 rows, newest first, with no pagination parameter — so this is the
            // whole inbox, not a page of it.
            pending = try await client.get("/api/apply/pending", as: PendingResponse.self).pending
            errorMessage = nil
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = APIError.transport(error.localizedDescription).userMessage
        }
    }

    func review(runJobId: Int) async throws -> RunJobReviewResponse {
        try await client.get("/api/apply/run-jobs/\(runJobId)/review", as: RunJobReviewResponse.self)
    }

    // MARK: - Preparing (this is where money is spent)

    /// Move locally-queued jobs onto the server, which previews each one and generates its resume.
    ///
    /// Returns the ids the server ACCEPTED. That is `queued`, not what was sent: the server drops
    /// duplicates, so reporting the sent count would overstate what happened.
    func prepare(jobIds: [String]) async -> [String] {
        guard !jobIds.isEmpty else { return [] }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        var accepted: [String] = []

        // The endpoint takes at most 25 ids per call, so a larger selection is chunked rather
        // than truncated — silently dropping the tail would leave jobs in the local queue with
        // no indication why they never moved.
        for chunk in stride(from: 0, to: jobIds.count, by: APIConfig.maxJobsPerRun).map({
            Array(jobIds[$0 ..< min($0 + APIConfig.maxJobsPerRun, jobIds.count)])
        }) {
            do {
                let response = try await client.post(
                    "/api/apply/runs",
                    body: QueueRunRequest(jobIds: chunk, tool: "auto_apply", mode: "auto"),
                    as: RunQueuedResponse.self,
                    // A retry on a flaky connection would otherwise queue the run twice, and
                    // every queued job costs a resume generation.
                    idempotencyKey: UUID().uuidString)

                accepted.append(contentsOf: response.queued)
                if let cap = response.queueCap { queueCap = cap }

            } catch APIError.queueCapReached(let used, let limit, let remaining, let message) {
                // Surface the cap with its real numbers and stop. Never fail silently at the
                // ceiling, and never keep hammering it with the remaining chunks.
                queueCap = QueueCap(limit: limit, queuedLast24h: used, remaining: remaining)
                errorMessage = message.isEmpty
                    ? "Daily limit reached: \(used) of \(limit) queued in the last 24 hours. \(accepted.count) prepared before stopping."
                    : message
                break

            } catch let error as APIError {
                errorMessage = error.userMessage
                break
            } catch {
                errorMessage = APIError.transport(error.localizedDescription).userMessage
                break
            }
        }

        if !accepted.isEmpty {
            notice = "\(accepted.count) prepared for review. Nothing has been sent yet."
            await loadPending()
        }
        return accepted
    }

    // MARK: - Deciding

    /// THE moment of submission. Only ever reached from an explicit tap on a reviewed application.
    func approve(runJobIds: [Int]) async {
        guard !runJobIds.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            let response = try await client.post(
                "/api/apply/approve",
                body: DecisionRequest(runJobIds: runJobIds),
                as: ApproveResponse.self)

            let sent = response.approved.count
            let skipped = response.skipped ?? 0
            notice = skipped > 0
                // A non-zero skip with ok:true is a partial success, not a failure.
                ? "\(sent) submitted. \(skipped) were no longer awaiting a decision."
                : "\(sent) submitted."

            if let cap = response.run?.queueCap { queueCap = cap }

        } catch APIError.noApprovableJobs {
            // Usually another device got there first. Re-fetch rather than showing an error.
            notice = "Those applications were already decided elsewhere."
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = APIError.transport(error.localizedDescription).userMessage
        }

        await loadPending()
    }

    func reject(runJobIds: [Int]) async {
        guard !runJobIds.isEmpty else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            let response = try await client.post(
                "/api/apply/reject",
                body: DecisionRequest(runJobIds: runJobIds),
                as: RejectResponse.self)
            notice = "\(response.rejected.count) discarded. Nothing was sent."
        } catch APIError.noApprovableJobs {
            notice = "Those applications were already decided elsewhere."
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = APIError.transport(error.localizedDescription).userMessage
        }

        await loadPending()
    }
}
