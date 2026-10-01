# Phase 0 â€” Foundations

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
Manrope's variable source has PostScript name `Manrope-ExtraLight` and a 200â€“800
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

## Acceptance result — NOT COMPLETE / NOT READY TO MERGE

Final completed validation for this review:
[Actions run #66 / 36875002478](https://github.com/angels00607/reading-companion/actions/runs/36875002478),
code/documentation head `5fa3b8a067b13adc1857ab086359f79b9e7c56aa`, iPhone SE
(3rd generation) simulator. Workflow completed with failure; artifacts were exported
as `foundation-acceptance-results` (artifact 11170305375).

| Check | Result |
| --- | --- |
| Native Swift/domain/GRDB suite | 29 passed |
| SQLite migration/invariant suite | 16 passed |
| Supabase migrations/RLS suite | 45 passed |
| iOS simulator application build | Passed |
| Hosted UIKit font registration | Passed; all five resources registered without fallback |
| Foundation UI/accessibility scenarios | 0 of 5 accepted; Dynamic Type failures |
| Static semantic color contrast | 12 combinations passed; minimum 6.04:1 |

The complete run reached and activated Home, Journal, Challenges, Series and Stats
in each of the five scenarios: default Light/Dark/System, largest-text Light portrait
and largest-text Dark landscape. Each button appears in five tap events. The previous
offscreen Series/Stats activation error did not recur. Navigation, label, touch-size,
heading and rendered-appearance assertions recorded no failures in this run.

Dynamic Type audit findings persist: partially unsupported at default size and
unsupported at the largest size. All five scenarios fail for those findings. The
issue handler returns false and preserves failures. XCTest does not identify a live
element for these findings; they are unresolved, not classified as false positives.
No other audit categories reported findings, but this does not establish full
accessibility acceptance. Physical-device and spoken VoiceOver testing remain
unperformed.

The corrective code explicitly declares portrait and both landscape orientations,
removes a redundant Button accessibility grouping override, and scrolls by viewport
geometry before querying an offscreen button's hit point. These changes compiled and
ran in #66. The earlier letterboxed screenshots are superseded by the exported #66
captures; visual confirmation of full-screen landscape rendering remains a review gate.

Remaining acceptance gates:
- Resolve or substantiate the Dynamic Type audit findings through targeted native
  inspection; do not suppress them merely to obtain a green run.
- Review the exported #66 landscape captures to confirm full-screen rendering, then
  obtain a passing complete acceptance run after resolving Dynamic Type. Largest-text
  portrait navigation now reaches all five tabs.
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


## Phase 0 corrective review â€” locked progress and domain invariants

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

## Focused Dynamic Type diagnosis of run #66

No further layout, typography, accessibility-semantic or test-gate changes were made
in this diagnostic pass. The exact completed #66 logs and both xcresult SQLite
reports were inspected, along with all 25 named tab/scenario screenshots and the
exported serialized UI snapshots.

Evidence:
- Default xcresult: 75 assertion failures, all `Dynamic Type font sizes are partially
  unsupported`.
- Largest-size xcresult: 32 assertion failures, all `Dynamic Type font sizes are
  unsupported`.
- All 107 report the same detailed description: `User will not be able to change
  the font size of this element`. The callback prints `AUDIT ELEMENT: unknown`
  for every finding, meaning the optional live element is nil.
- Structured TestIssues/UserInfo contain no affected accessibility identifier,
  label or element bounds. Source locations point to the audit invocation, not
  to an application view.
- The 23 exported UI snapshots contain only the UIApplication root, empty
  identifiers and no child elements or labels. They cannot map the findings to
  Home/Journal/Challenges/Series/Stats, the heading, or the preview text.
- Default and largest-size portrait screenshots visibly show text scaling.
  That proves resizing in those captured states, not correct behavior at every
  size or during the auditor's checks. It does not invalidate the failures.
- Landscape captures still show a black/cropped presentation. This separate
  visual finding is not evidence identifying the Dynamic Type culprit and was
  not used to justify another layout change in this focused pass.

Conclusion: the existing XCTest result has a confirmed diagnostic limitation:
its failures cannot be mapped to a specific failing live element from the supplied
logs, issue records and snapshots. An XCTest false positive is NOT established;
a genuine app failure remains possible. The 107 findings remain blocking and
unsuppressed. Do not change another UI component based on this evidence alone.

Next necessary diagnostic evidence is a native Accessibility Inspector audit with
its highlighted element and font-size behavior, or targeted additional native
instrumentation capturing identified live elements and their dimensions/category
before and during the audit. Then reproduce the identified failure and make the
smallest correction. Existing five-tab navigation, minimum targets, full scaling,
Manrope, appearance modes, labels and selected traits remain unchanged.

No correction was justified in this pass, so no replacement acceptance run is
claimed. After a mapped correction, rerun the complete 29/16/45-test foundation
suite plus font registration and both UI stages, and inspect its screenshots.
Phase 0 remains open; no Phase 1 work or merge.
