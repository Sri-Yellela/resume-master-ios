# Draft - iOS

![Swift](https://img.shields.io/badge/Swift-FA7343?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-000000?style=flat&logo=apple&logoColor=white)
![iOS](https://img.shields.io/badge/iOS_17+-000000?style=flat&logo=apple&logoColor=white)

Native iOS client for [Draft](https://github.com/Sri-Yellela/draft). Swipe a job
feed, review each application before it is sent, and build, template and export your resume.

It is a client over the same JSON API the web app uses — not a wrapper around it. The web client is
a desktop-shaped tiled dock with almost no responsive design, so nothing is shared visually.

## How applying works

Three states, and the boundaries between them are the point:

| Stage | Where | Costs | Sends |
|---|---|---|---|
| **Swipe right** | this device | nothing | no |
| **Prepare** (a tap in Review) | server generates a tailored resume and previews the form | ~$0.04 per job | no |
| **Approve** (a tap per application) | server submits | — | **yes** |

**No gesture ever submits an application.** A swipe is free and reversible; only an explicit tap on
a reviewed application sends anything, and that screen shows every field that will be submitted
alongside the rule that produced it.

Two deliberate consequences:

- **A right-swipe costs nothing.** Generation is deferred to the Prepare step, because swiping is
  about a second per job — wiring the gesture to generation would mean five idle minutes of
  thumbing costs roughly 60 jobs and $2.40 before the user has read anything.
- **The daily limit is shown, not discovered.** The server caps queueing at 40 per 24 hours
  (`APPLY_DAILY_QUEUE_CAP`). The Review tab shows what is left rather than letting you find the
  ceiling by being refused at it.

### Jobs you will not see

The feed asks the server for `tiers_include=direct,guest` — only employers whose apply flow can be
completed on a phone. Workday, Meta, Amazon and anything else behind a portal login or an identity
check (`automation_tier` `gated` / `account`, and anything unclassified) is filtered out
**server-side**, because the desktop handoff those need borrows an authenticated browser session
through a Chrome extension, and there is no extension on iOS. Queueing one here would park it in a
state this device could never resolve. Finish those on desktop.

### Eligibility answers

Work authorisation, sponsorship, years of experience and custom answers are attestations. They are
read from your stored profile and are never inferred, never gestured, and not editable from a swipe.
Where a posting carries no signal, the card shows nothing rather than guessing.

## UI Interactions
- Rotating card stack with velocity-sensitive swipe gestures
- Soft swipe right: add to the review queue
- Hard throw right: add to the review queue, prioritised to the top
- Diagonal swipe: star / save
- Left swipe: skip / dismiss
- Gmail-style swipe actions on resume sections
- iMessage-style action receipt badges

## The API contract

`Contract/` holds a vendored copy of the server's OpenAPI contract, pinned by checksum.

```bash
node scripts/verify-contract.mjs      # assert the vendored copy matches CHECKSUMS.json
```

It is generated on the server by executing `mapJobRow.js`, so it cannot disagree with what the API
emits. When it changes, re-copy all three files from the server repo's `contract/` directory and
re-run the check. This answers "is my copy current?" — it cannot answer "has the server changed
since I copied?", which is `test/mobileApiContract.test.js` in the server repo.

Currently pinned: **v1.1.0**.

## Getting Started

### Requirements
- Mac with Xcode 15+
- iOS 17+ device or simulator
- A Draft account (the app signs in against the live API; there is no offline mode for the feed)
- Apple Developer account (free for simulator, $99/yr for device + App Store)

### Run on Simulator
1. Clone the repo
2. `node scripts/verify-contract.mjs` to confirm the contract copy is current
3. Open `ResumeMaster/ResumeMaster.xcodeproj` in Xcode
4. Select an iOS 17 simulator
5. Press Command-R, and sign in

### Adding or removing source files

The Xcode project is generated, and a file on disk that the target does not know about compiles
into nothing while looking perfectly present in a diff — which is exactly how two files shipped
broken once already.

```bash
node scripts/sync-xcode-project.mjs           # rebuild the target's file list from disk
node scripts/sync-xcode-project.mjs --check   # CI: fail if it is stale
```

### Archive for App Store

Not yet possible. Missing, in the order they will block you:

- `DEVELOPMENT_TEAM` is unset, so the project does not sign
- there is no app icon (no `Assets.xcassets`)
- there is no `PrivacyInfo.xcprivacy`, now required for submission

Simulator builds are unaffected.

## Related Repos
- [Draft (web + backend)](https://github.com/Sri-Yellela/draft)
- [Draft Android](https://github.com/Sri-Yellela/resume-master-android)
