# Phase 0 — Foundations

Scope: foundations only; no feature-rich screens, live providers, AI, imports,
backup UI, challenge matching engine or gamification engine.
The approved V2 documents remain authoritative.

## Implemented
- Swift package boundaries: ReadingDomain, ReadingData and ReadingUI.
- SwiftUI five-tab preview shell and Light/Dark semantic tokens.
- To Read membership separate from reading occurrences; explicit finish, DNF/resume,
  historical-import suppression, user-only Format and unknown/rating states.
- Date-only Gregorian values and ISO-week keys; immutable yearly snapshot types.
- Provenance/review primitives, reward merge semantics and stable mutation IDs.
- GRDB migration and account-scoped store: Book and outbox commit/rollback together.
- Sequential outbox coordinator; conflicts block later commands across retries.
- Supabase schema/RLS and a minimal book.create RPC proving command authorization,
  generation checks, receipts and transactional change-log writes.
- Keychain credential boundary, deployment configuration and redacted event logging.
- SQLite, native invariant/repository/sync and Supabase RLS test infrastructure.

## Prior baseline validation
Windows and CI SQLite migration checks: 8 tests passed.
macOS CI: Swift/GRDB compilation and all 12 native tests passed.
iOS simulator-target application build passed.
Supabase migration/reset and all 14 database/RLS tests passed.
Evidence: GitHub Actions run 36838179188, code commit 0a8ad76e28e072e87e45fd2f8d954e96cfed564e.
At that baseline, visual/accessibility checks and approved font rendering were unverified.

## Engineering baselines
Swift 6 / Xcode 16+, iOS 17+, GRDB 7.0.0 pinned; XcodeGen generates the app project.
No production cloud resources or Apple capabilities have been provisioned.
The Sign in with Apple direction is retained through the account-session boundary;
the native authorization/onboarding flow is deferred to its feature phase.

## Deliberate scaffolding limits
The cloud transport supports book.create only. Pull application, lifecycle commands,
conflict-resolution UI, retries with scheduling/backoff and restore generation rotation
are future integrations. Unsupported commands fail closed.
The foundational schema is incremental; subsequent phase migrations add Series,
Stats, Quests and full Journal features rather than inventing their implementation now.
No provider can supply Journal Format. A portable restore may preserve explicitly
user-chosen Format as stored data; the provider-setting command cannot set it.
No Challenge TBD content is seeded or inferred.
GitHub backup authentication, AI, reward balancing and push delivery remain deferred.

## Assets and acceptance
Approved source files are now supplied in `/fonts` and preserved byte-for-byte.
Manrope's variable source has PostScript name `Manrope-ExtraLight` and a 200–800
weight axis. App resources use verified 400/500/600 instances: `Manrope-Regular`,
`Manrope-Medium`, `Manrope-SemiBold`. The approved Papernotes WOFF is converted
to CFF OpenType without changing its `PapernotesRegular` name. Hello Baby is
copied unchanged and registers as `HelloBabyRegular`.
All five app fonts passed hosted UIKit registration checks without fallback.
The preparation script verifies approved source checksums and reproduces resources.
Font roles remain locked: Manrope functional; Papernotes and Hello Baby reserved accents.

Simulator QA discovered insufficient landscape native-tab touch height and low-contrast
inactive native labels. The foundation navigation now uses explicit 44-point minimum
targets and semantic foreground colors. Regular text sizes retain a five-column row;
accessibility sizes use full-size labels in a horizontal scrolling row. Both labels and
symbols scale, and the footer reserves scaled height. The heading uses adaptive SwiftUI
Manrope typography. No font-size cap or audit-issue exclusion is used.
All 12 foreground/background token combinations passed static contrast checks,
with a lowest ratio of 6.04:1. Rendered Light/Dark backgrounds and System following a
Dark simulator were checked rather than inferred from requested launch arguments.

## Acceptance result � NOT COMPLETE / NOT READY TO MERGE

Last completed full validation:
[Actions run 36871299920](https://github.com/angels00607/reading-companion/actions/runs/36871299920),
code `debb05bfbda2ddd7a7177a7fef8fea11e628da27`, iPhone SE (3rd generation) simulator.

| Check | Result |
| --- | --- |
| Native Swift/domain/GRDB suite | 29 passed |
| SQLite migration/invariant suite | 16 passed |
| Supabase migrations/RLS suite | 45 passed |
| iOS simulator application build | Passed |
| Hosted UIKit font registration | Passed; all five resources registered without fallback |
| Foundation UI/accessibility scenarios | 0 of 5 accepted; suite failed |
| Static semantic color contrast | 12 combinations passed; minimum 6.04:1 |

The UI run captured 23 tab/scenario screenshots: all five tabs in default Light,
Dark and System; five in largest-text Dark landscape; Home, Journal and Challenges
in largest-text Light portrait. Dynamic Type audit findings persist: partially
unsupported at default size and unsupported at the largest size. The issue handler
returns false and preserves all failures. XCTest does not identify a live element
for these findings; they are unresolved, not classified as false positives.
No other audit categories reported findings on completed screens, but that does not
constitute full accessibility acceptance. Labels and 44-point target assertions were
checked for reached controls. The largest Light portrait run stopped when XCTest
could not determine the offscreen Series button activation point; Series/Stats
coverage in that scenario is incomplete.

Visual review of exported screenshots also exposed letterboxed landscape rendering.
The subsequent corrective code explicitly declares portrait and both landscape
orientations, removes a redundant Button accessibility grouping override, and scrolls
by viewport geometry before querying an offscreen button's hit point.
These corrections are in `621e4c91594512a39e44231d0f362443d6ae96f0`.
[Verification run 36873922445](https://github.com/angels00607/reading-companion/actions/runs/36873922445)
is still in progress at this handoff: SQLite/Supabase pass; macOS Swift tests and iOS
build steps pass; final simulator acceptance is not yet verified.

Remaining acceptance gates:
- Resolve or substantiate the Dynamic Type audit findings through targeted native
  inspection; do not suppress them merely to obtain a green run.
- Verify full-screen landscape rendering and all five largest-text portrait navigation
  targets after the corrective changes, then obtain a passing complete acceptance run.
- Physical-device and spoken VoiceOver interaction have not been performed. Automated
  labels/traits checks do not replace listening and navigating with VoiceOver.
- Review the final visual/accessibility evidence before accepting Phase 0.

Phase 0 is not fully complete and is not ready to merge. The draft PR remains open;
no merge or Phase 1 work has occurred. All locked domain rules below remain unchanged.
Phase 1 requires review and explicit authorization.

## Corrective pass validation
Corrective code commit 402969c1a8f21a2ab685b59cc6ec6d0d9b049e65 passed:
- 29 native Swift tests, including legacy GRDB upgrade preservation.
- 16 SQLite migration/invariant tests locally and in CI.
- 45 Supabase/RLS tests, including a seeded migration-001 to migration-002 upgrade.
- iOS simulator-target rebuild.
Evidence: GitHub Actions run 36840373918.
The parallel PR run hit a GitHub release-lookup rate limit before Supabase setup;
the CLI is now pinned to verified release 2.119.0 to remove that lookup dependency.
No production changes or Phase 1 work.

Forward migrations retain legacy page values, observations, copied Journal payloads and account ownership. Original migration files remain unchanged. Final visual/accessibility acceptance and human review remain open.


## Phase 0 corrective review — locked progress and domain invariants

- Reading progress has two explicit modes: Page and Percentage. Journal Format is
  separate and user-only; neither concept may determine or change the other.
- Page mode preserves genuine integer position >=0 and optional positive total;
  position may be unknown and cannot exceed a known total.
- Percentage mode preserves an explicit finite value from 0 through 100 inclusive,
  or unknown. It stores no converted page position or denominator; edition page
  metadata remains separately available.
- Never convert percentage into page observations/Pages Read, or persist a computed
  page ratio as explicit user-entered percentage. Only genuine, resolved page
  observations contribute to page statistics; percentage-only Pages Read is unknown.
- Final page and 100% only suggest confirmation. Manual Finish Book requires explicit
  confirmation in either mode, including unknown position/percentage/total.
- DNF retains the last genuine progress in its original unit and all DNF exclusions.
- Observations preserve original unit/value, including after an explicit mode change.
  No historical conversion, synthetic equivalent observation, highest-page-wins,
  highest-percentage-wins or timestamp last-write-wins. Unresolved observations
  remain reviewable. Mode-changing UI is deferred; the foundation clears the new
  current position to unknown rather than converting it.
- Journal components distinguish preparation from completion work. They are not
  universally restricted to Read readings. DNF cannot generate completion-based
  work and is excluded from completion-flow queries; preparation/history is not
  converted into completion work. Historical imports never automatically enter Inbox.
- Series Waiting requires all included published entries to be read and reliable
  evidence of an announced/expected future entry or known ongoing series. Lack of
  confirmation of completion alone is insufficient: ambiguous cases return Unknown.
  Active, Completed, explicit Abandoned and override precedence retain their locked meanings.
- No listening-time/playback behavior, feature screens or Phase 1 implementation.
