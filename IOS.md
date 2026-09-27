# iOS — living work doc

**Repo:** `resume-master-ios` · **Backend:** `../draft` ·
**Contract:** `../draft/contract/mobile-api.v1.json` (read the version from the file)

**Last reconciled:** 2026-09-07. SwiftUI, iOS 17+, Xcode 15+, project at
`ResumeMaster/ResumeMaster.xcodeproj`.

> ⚠ **Re-derive state from the repo before starting.** The desktop equivalent of this doc has been
> stale three times. Also note the iOS working tree was committed by another session mid-sweep as
> `aad5a3a`, so anything below may already have moved.

---

## Status

| Phase | State | Blocked on |
|---|---|---|
| **Phase 1** — audit | **OPEN — never run** | **a Mac with Xcode** |
| Everything after | not started | Phase 1 |

**This repo has had no dedicated session.** Everything below was found incidentally by the
cross-repo corruption sweep, which could inspect files but not build or run anything. Treat it as
leads, not as an audit.

**iOS is behind Android by two phases.** Android's Phase 1 and 2a are complete; iOS has neither.

---

## ⛔ The four constraints — identical to Android, non-negotiable

**1 · A SWIPE QUEUES, IT NEVER SUBMITS.** The README documents *"Hard throw right: immediate
apply."* On Android that line was the visible tip of a **five-place** implementation that reached a
badge reading **"Application sent"** for 2.5 seconds having sent nothing. Trace the equivalent here
and report every occurrence — do not fix the README and stop. Velocity may distinguish a stronger
signal; the stronger signal must also only queue.

**2 · GENERATION IS DEFERRED TO APPROVAL.** Right-swipe costs nothing. `APPLY_DAILY_APPROVAL_CAP`
(30) bounds spend; both caps are typed response fields carrying `limit` and `remaining` — render
`remaining`, never swallow it.

**3 · GATED JOBS CANNOT BE COMPLETED ON A PHONE.** No extension exists on iOS, so the desktop
handoff has no analogue. `unknown` is also `completableOnMobile: false`. Filter server-side via
`tiers_include`/`tiers_exclude`, never client-side.

**4 · ELIGIBILITY ANSWERS ARE NEVER GESTURED.** Attestations come from the stored profile only.

---

## OPEN — Phase 1 audit

```
AUDIT-FIRST. Report and stop. Change nothing except the constraint-1 violation.

1 · DOES IT BUILD?
Open in Xcode; report the result verbatim on failure. If the toolchain is unavailable, SAY SO —
do not report a syntax check as a build. Android's "it assembles" was unknown for three sessions
because nobody could distinguish the two.

2 · ⛔ THE BUILD TARGET — the sharpest known finding
32 Swift files on disk, 30 in the Sources build phase. The two omitted are
Data/JobRepository.swift and Services/LinkedInAuthService.swift — THE ENTIRE NETWORK AND AUTH
SURFACE IS NEVER COMPILED. Commit f8be63c "feat: JobRepository.swift — consumes /api/jobs" has zero
effect on the built app; so does 37ba107.

⛔ Do NOT simply add them to the target. That breaks the build immediately on
`invalid redeclaration of 'Job'` — see item 3. Deciding which Job is canonical is the same decision
as the contract-typed model, so it belongs to Phase 2, not to a quick fix.

3 · TWO `struct Job` IN ONE MODULE
Data/JobRepository.swift:4 (13 fields, id: String) and Models/Job.swift:3 (10 fields, id: UUID).
The desktop canonical shape is 37 fields. Four definitions across the project, no shared source.
Report which should survive; do not resolve it here.

4 · ENCODING
Android carried a literal PowerShell escape (`r`n) in three places, two of which broke its version
catalog, plus a BOM on 55 of 57 files. Same generation process. 35 BOMs found here.
Info.plist and project.pbxproj are the dangerous ones — a BOM sits in front of pbxproj's mandatory
// !$*UTF8*$! magic header. Both were TESTED and downgraded to RISK: plistlib parses Info.plist with
the BOM intact, and the pbxproj header survives it. Re-verify with Xcode itself, which is the only
parser that matters. Full sweep prompt: ../draft/docs/CORRUPTION_SWEEP.md

5 · SILENT FAILURES ALREADY FOUND (Shape 3)
  Views/Preview/ExportView.swift:4 — `try? data.write(to: url)` then sets shareURL and shows an
    "exported" badge regardless. A write failure is swallowed and success reported anyway; the user
    gets a share sheet pointing at a file that may not exist.
  Persistence/ResumeStore.swift:6 — save(): `guard let data = try? encode else { return }` then
    `try? context.save()`. Two silent failure paths, no return value. AppState.saveResume() cannot
    tell. Résumé edits silently lost.
  Persistence/ResumeStore.swift:5 — load(): `try? context.fetch(...)` falls through to
    loadDefaults() on failure. A fetch error SILENTLY REPLACES the user's saved résumé with the
    default one, indistinguishable from a first run. This is the same shape as Android's process-
    death loss, which was invisible because the app reopened showing the seeded résumé.
  JobRepository.swift:25-33 — JobSearchResponse declares attribution, sources and total
    non-optional, so the server's cache-empty board (which omits attribution) fails to decode and a
    successful HTTP 200 empty board reports as "Could not load jobs."

6 · SNAKE_CASE vs CAMELCASE
JobRepository.swift:4-17 declares `let salary_min: Double?` etc. and decodes with JSONDecoder's
default key strategy against camelCase JSON — always nil. Identical to Android's bug in a different
language. Currently harmless only because the file is not compiled.

7 · ⛔ EIGHT CONTRACT FIELDS ARRIVE ABSENT, NOT NULL
Eight fields have no null coalescing server-side, so JSON.stringify DELETES them. A Swift
`Decodable` THROWS on a missing key it would happily accept as nil. This is crash-on-first-decode
and it is worse on iOS than on Android. The contract types them optional; honour that.

8 · AUTH — the credential distinction that trips people
  POST /api/auth/login        -> authContext   SESSION-BOUND. DO NOT PERSIST.
  GET  /api/auth/mobile-token -> token         sessionLess, durable. THIS is the credential.
A login-issued token stores session_sid = req.sessionID and is swept by revokeBrowserAuthContexts;
the mobile mint stores NULL and that sweep never touches it. Persisting the login token produces
intermittent, untraceable sign-outs.
Flow: login → GET /api/auth/mobile-token → persist in the KEYCHAIN (never UserDefaults) →
Authorization: Bearer. Idle 7d sliding, absolute 90d. POST /api/auth/revoke-mobile-token to sign out.
LinkedInAuthManager is profile-import only and is explicitly NOT a session.
Check for a YOUR_DOMAIN.com placeholder base URL — Android had one in its LinkedIn manager and its
deep-link host while using the real domain elsewhere.

9 · SCREEN INVENTORY
Every screen: what it is, its state source, wired or static. Android had 13 screens, 0 wired to a
server, everything from MockData, and NO REVIEW QUEUE SCREEN AT ALL — swiping right wrote to a list
nothing rendered. Report specifically whether a review/approval surface exists here.

10 · ADMIN SURFACES
Android shipped 6 ungated admin screens of fabricated data with Delete/Suspend/Impersonate controls
that hit nothing. Owner decision there was a BUILD FLAVOUR, not deletion. Report whether an
equivalent exists here; do not build or delete it.

11 · README ACCURACY
Report every claim the code does not support. Note "Velocity-sensitive" is GENUINELY TRUE on iOS —
SwipeCardModifier.finish() computes predictedEndTranslation and tests velocity > minimumVelocity —
so do NOT carry Android's finding across. The README also links resume-master-web with a
YOUR_USERNAME placeholder; the real repo is github.com/Sri-Yellela/draft.

12 · STORE READINESS
Signing, bundle identifier, provisioning, App Store Connect state, and the App Store privacy
manifest. The declaration must not contradict https://jobsviadraft.com/privacy.

OUTPUT: MOBILE_STATE_IOS.md in this repo — what the code is, whether it builds (verbatim failure if
not), encoding findings, screen inventory, the networking and auth answers, model-vs-contract
mismatches, README claims unsupported, store gaps, and A SIZING VERDICT: "update a working app",
"revive a stale but sound app", or "a high-fidelity UI shell over fixtures".
Then STOP. Propose no plan.
```

---

## After Phase 1 — the expected order

Same as Android's, which is now proven: **toolchain → auth → contract-typed API layer (including
`automationTier`) → persistence.** No feed until those land. Then the swipe feed, then the review
queue.

Android's Phase 2a report is the reference implementation:
`../draft/docs/aj2-android-phase2a.md`. Two lessons from it likely to apply here:

- **Persistence needs a process-death test with a real file-backed store.** An in-memory database
  cannot outlive the process that made it, so it cannot express the claim. Mutating hydration to
  always seed must FAIL the test.
- **A shared repository, not one per view.** Android's builder and preview each held their own
  mock-seeded instance, so "Export as PDF" shipped the mock résumé. iOS has `AppState` and
  `ResumeStore` — check the same thing.
