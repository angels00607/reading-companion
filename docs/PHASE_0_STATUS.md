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
Device visual/accessibility checks and approved font rendering remain unverified.
The Phase 0 exit gate remains open for those acceptance checks and human review.

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
Font binaries were not supplied. Registration/font-role wiring is present; approved,
licensed assets and PostScript-name verification are needed for typography visual QA.
No screenshot or device QA is claimed.
Phase 1 or any broader feature work requires review and explicit authorization.

## Corrective pass validation
16 SQLite migration/invariant tests passed locally. Native and Supabase corrective tests and iOS rebuild are pending CI. Prior baseline results above are not evidence for the corrected code.

Forward migrations retain legacy page values, observations, copied Journal payloads and account ownership. Original migration files remain unchanged. No specification deviations are intended. Font assets/device visual/accessibility QA and human acceptance remain open.


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
