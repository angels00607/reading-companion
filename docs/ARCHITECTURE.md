# Reading Companion --- Architecture Direction

**Status:** proposed direction for Codex technical audit.\
Do not treat unresolved implementation choices as approved merely
because they appear here.

Phase 9's fine-grained PAT and versioned ZIP/JSON backup decisions were explicitly
approved on 2026-10-07. [The Phase 9 backup contract](PHASE_9_BACKUP_CONTRACT.md)
supersedes older TBD references to those two choices below. Other unresolved choices
and the non-negotiable product rules remain unchanged.

## 1. Architecture goals

The architecture must optimize for: - iPhone-first user experience; -
reliable offline-capable reading workflows; - user data ownership; -
strict protection of manual corrections; - replaceable external metadata
providers; - deterministic domain rules; - safe import/reconciliation; -
testability; - migration/backup longevity.

## 2. High-level shape

``` text
iPhone App
  ├─ Presentation / Design System
  ├─ Domain Layer
  │    ├─ Books & Readings
  │    ├─ Journal
  │    ├─ Series
  │    ├─ Challenges
  │    ├─ Quests / XP / Achievements
  │    ├─ Stats
  │    └─ Attention
  ├─ Local Persistence
  ├─ Sync / Conflict Layer
  ├─ Provider Adapters
  │    ├─ Open Library
  │    ├─ Google Books
  │    ├─ StoryGraph CSV
  │    └─ Manual
  └─ Backup / Export

              ↕ sync

Supabase
  ├─ Auth (method TBD)
  ├─ Live cloud database
  └─ server-side functions/jobs only where justified

Independent backup paths
  ├─ GitHub manual versioned snapshots
  └─ Local portable export
```

## 3. Client technology

Target is an iPhone-first production-quality app.

Codex technical audit must recommend the final client stack. A native
iOS approach is expected to be evaluated first because the product
relies on: - native navigation/sheets; - haptics; - Dynamic Type; -
VoiceOver; - iOS notifications; - offline/local persistence; - polished
iPhone behavior.

Do not lock a framework before audit.

## 4. Layering

Recommended conceptual separation:

### Presentation

Screens and reusable components only. It must not contain authoritative
business rules.

### Domain

Pure/testable rules: - status transitions; - finish confirmation; - DNF
exclusions; - Challenge occupancy/matching decisions; - A/B year rule; -
Journal readiness; - Series effective status; - XP event eligibility; -
Stats inclusion.

### Data

Repositories abstract: - local persistence; - Supabase sync; - provider
data; - import; - backup.

The UI should depend on domain/repository interfaces rather than
provider SDKs directly.

## 5. Local-first / offline direction

Local data should support immediate use of: - Library/My Books; - Book
Page for cached books; - Currently Reading; - Update Progress; -
Journal; - Favorites/Quotes; - local Stats; - pending Attention data.

Offline writes should be queued and synced later.

Codex must propose: - local database technology; - mutation log/outbox
strategy; - conflict detection; - retry/idempotency; - migration
strategy.

Do not implement last-write-wins if it can silently destroy user
overrides.

## 6. Supabase role

Chosen product direction: - live cloud database; - sync/source of cloud
data; - authentication/account support; - cross-device recovery/sync as
architecture permits.

Codex must validate: - auth method; - RLS; - schema; - indexes; -
quotas; - conflict/sync model; - migrations; - deployment/environment
separation.

Supabase is not the GitHub backup.

## 7. Provider abstraction

Define a stable interface such as:

``` text
BookMetadataProvider
  search(query, preferredLanguage)
  fetchBook(providerID)
  fetchEditions(bookID)
  refreshKnownMetadata(...)
```

Candidate adapters: - OpenLibraryProvider - GoogleBooksProvider -
StoryGraphImportProvider - ManualProvider

Provider output must include provenance and uncertainty. Provider
results do not bypass user review/override rules.

StoryGraph live integration is not a V1 dependency.

## 8. AI integration boundary

AI can assist with: - journal summary drafting/revision; - challenge
explanation/analysis; - possibly data-research assistance when product
flow explicitly requests it.

AI must not: - invent missing facts; - auto-confirm Challenges; -
silently write authoritative bibliographic/series data; - infer Journal
Format.

Codex must propose: - provider/model abstraction; - prompt/context
boundaries; - privacy approach; - response validation; - retry/error
behavior; - cost/rate controls where relevant.

Do not assume direct access to existing ChatGPT project conversations.

## 9. Sync and conflicts

Required semantics: - manual user correction has highest authority; -
external changes become proposals; - rejected proposal suppression
depends on evidence fingerprint/source version; - offline local
mutations survive reconnect; - duplicate progress events must not be
created by retries; - completion side effects must be idempotent.

Codex should consider an outbox/event approach for local mutations and
idempotency keys for side effects.

## 10. Domain events

Useful events may include: - `ReadingStarted` -
`ReadingProgressUpdated` - `BookCompletionConfirmed` -
`ReadingMarkedDNF` - `ReadingResumed` - `JournalComponentCompleted` -
`JournalCopied` - `ChallengeAssignmentConfirmed` - `QuestCompleted` -
`AchievementUnlocked` - `SeriesDataChangeProposed`

Historical imports must not emit live equivalents that trigger
gamification/completion cascades.

## 11. Attention architecture

Use persistent `AttentionItem` for unresolved work. Push/in-app
notifications are delivery/history, not the authoritative unresolved
state.

One reusable `ProposedDataChange` / `DataChangeReview` flow should
serve: - Series updates; - Book metadata updates; - Import
reconciliation.

## 12. Backup architecture

### GitHub

Manual, punctual, versioned snapshots. Not continuous sync and not one
commit per app mutation.

### Local export

Independent portable backup.

### Manifest

Include: - backup format version; - schema version; - app version; -
timestamp; - source device; - entity counts; - integrity/checksum data.

Restore: 1. select backup; 2. parse/validate; 3. integrity check; 4.
preview contents/impact; 5. explicit confirmation; 6.
transactional/rollback-safe application; 7. post-restore validation.

Never include credentials/tokens.

## 13. Security

Technical audit must address: - Supabase RLS; - secure credential
storage (e.g. platform secure storage where appropriate); - secrets
outside repository; - least-privilege provider credentials; - backup
secret exclusion; - input validation; - safe file import; - privacy of
reading data.

## 14. Performance

Plan for hundreds to thousands of Books. - local indexed search; -
DB-side sort/filter; - progressive loading; - optimized cover
thumbnails/cache; - no N+1 provider calls; - cached provider metadata; -
efficient Stats aggregation.

## 15. Testing architecture

Required layers: - domain unit tests; - repository/data tests; -
migration tests; - import/reconcile fixtures; - sync/conflict tests; -
UI/component tests; - accessibility tests where tooling permits; -
end-to-end critical flows.

Critical end-to-end flows: 1. Search → Add → Start → Update → Finish →
Read. 2. Finish → Journal Inbox → Ready → Journal Session → Copied. 3.
Reread without duplicate Book. 4. DNF exclusions. 5. Challenge
sequential confirm/reject. 6. StoryGraph historical import without live
side effects. 7. Offline progress → reconnect → no data
loss/duplication. 8. External proposal → Keep Current → no silent
recurrence. 9. Backup → preview → restore validation.

## 16. Decisions Codex must return for approval before Phase 0

-   final iOS stack;
-   local database;
-   sync/outbox/conflict design;
-   Supabase auth approach;
-   schema/RLS strategy;
-   provider priority/matching approach;
-   AI integration approach;
-   GitHub backup authentication approach;
-   backup serialization format;
-   notification delivery architecture;
-   environment/configuration strategy;
-   test stack;
-   observability/logging approach.

Do not code the application before these decisions are reviewed.



## V2 post-audit locked resolutions
- Native Swift + SwiftUI: approved.
- SQLite via GRDB: approved.
- Supabase cloud direction: approved.
- V1 Book/Edition/Series records are private/user-owned.
- `To Read` is library membership/intent, separate from `ReadingInstance`; starting reading creates a ReadingInstance.
- Book Review refill capacity is exactly **100 books**; do not derive 108 from page arithmetic.
- Historical completed imports do **not** automatically enter Journal Inbox.
- Reading start/finish dates are date-only calendar values; operational timestamps are UTC instants.
- 52 Weeks uses ISO 8601 Monday–Sunday weeks and is a deterministic exception to manual semantic Challenge confirmation.
- A user may manually `Finish Book` when total pages are unknown.
- Series effective status:
  - Abandoned = explicit user choice.
  - Active = at least one included published entry remains unread.
  - Waiting = all currently published/included entries are read AND a future entry is announced/expected or the series is known to be ongoing; missing completion confirmation alone is insufficient.
  - Completed = all included confirmed entries are read and the series is confirmed complete.
  - Unknown = insufficient reliable data.
  - user override wins.
- Digital Series has no 20-entry limit. Physical >20 uses Type 3 plus continuation; never truncate.
- Progress conflicts must never use highest-page-wins, highest-percentage-wins or timestamp last-write-wins; preserve observations and review unresolved conflicts.
- Restore must never reduce legitimate permanent XP; deduplicate/merge valid awards using stable semantic award keys.
- Selected monthly Best Books form the primary Book of Year candidate pool; Book of Year remains a manual choice.
- Never fabricate daily page distribution or Reading Days from only start/finish/total values.
- Sign in with Apple is the approved authentication direction; email OTP remains TBD.
- GitHub backup must be secure/private/manual; exact GitHub auth mechanism is deferred to Phase 9.
- Missing Challenge content in `CHALLENGE_CATALOG.md` remains TBD and must not be inferred.

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
