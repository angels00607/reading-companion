# Reading Companion --- Codex Project Rules

## Authority

`docs/MASTER_SPEC.md` is the product source of truth. This file contains
the non-negotiable implementation rules Codex must keep in mind at all
times.

If implementation convenience conflicts with the Master Spec, the Master
Spec wins. Do not silently change product behavior. If a technical
constraint makes a locked requirement impossible, stop and document the
conflict before changing behavior.

## Non-negotiable data rules

-   Never invent missing bibliographic, edition, series, release,
    reading, journal, challenge, or statistics data.
-   Unknown is a valid state. Preserve it explicitly until reliable data
    or the user resolves it.
-   Every user-facing factual value that may be wrong must have a manual
    correction path.
-   User-entered or user-corrected values override imports,
    synchronization, AI suggestions, and external providers.
-   Never silently overwrite a user override.
-   External changes follow: **Detect → Notify → Review → User decides →
    Apply**.
-   Track provenance where useful: value, source, source reference,
    confidence, user override flag, updated timestamp.
-   Rejected external corrections must not be proposed repeatedly unless
    new evidence/source information appears.

## Core domain separation

-   `Book` = canonical work.
-   `Edition` = bibliographic edition of a Book.
-   `ReadingInstance` = one occasion on which the user reads a Book.
-   Rereading creates a new `ReadingInstance`, never a duplicate `Book`.
-   Journal Format belongs to the reading, not the Book.

## Format rule

Journal Format is **USER-ONLY DATA**. - Never infer, import, preselect,
suggest, or auto-fill it from StoryGraph, ISBN, Edition metadata, AI,
previous behavior, or any provider. - Allowed values: `Paperback`,
`Hardcover`, `Ebook`, `Audiobook`. - It is required for a Book Review to
become `Ready to Journal`. - It remains editable.

## Reading rules

-   Core statuses: `To Read`, `Currently Reading`, `Read`; `DNF` is a
    technical reading status.
-   Progress is tracked in this app.
-   Reaching the final page or 100% requires explicit finish confirmation.
-   DNF:
    -   is removed from Currently Reading;
    -   preserves last progress internally;
    -   creates no Book Review;
    -   triggers no automatic Challenge analysis;
    -   does not count as Books Read;
    -   is excluded from Stats and physical Journal Stats;
    -   gives no completion XP;
    -   can be resumed later.
-   Imported historical readings are historical records, not retroactive
    live events.

## Journal rules

-   The app prepares the physical Reading Journal; it does not replace
    it.
-   Never ask for the same reading information twice.
-   Journal readiness is component-based.
-   Challenge review never blocks Book Review readiness.
-   If data already copied to paper changes, offer a pending Journal
    Correction.
-   Rating uses whole stars 1--5 plus `No rating`; never silently round
    half-star external values.

## Challenges vs Quests

-   Challenges describe properties/content of books.
-   Quests describe user reading activity/behavior.
-   Keep their models, logic, UX, and visual language separate.
-   Challenge suggestions require reliable information and at least 70%
    confidence.
-   AI/provider suggestions never auto-confirm a Challenge.
-   Confirmed prompts are occupied sequentially.
-   Even calendar year → Version A; odd calendar year → Version B.
-   Historical yearly challenge configuration must be snapshotted.
-   For 52 Weeks, finish date determines the week; no borrowing between
    weeks.

## Gamification

-   XP is permanent. Never remove XP.
-   No punishment for inactivity.
-   No guilt messaging or aggressive streak mechanics.
-   Historical imports do not create mass completion XP, achievements,
    quests, or challenge events.
-   Administrative actions such as import/backup do not award XP.

## External data

-   The app must work without live StoryGraph integration.
-   StoryGraph CSV import/reconcile is supported.
-   Use provider abstraction for book metadata.
-   External providers are suggestions/data sources, not authorities
    over user corrections.
-   Do not promise unsupported StoryGraph APIs or direct ChatGPT-project
    access.

## UI / product rules

-   Entire app UI is English.
-   iPhone portrait-first.
-   Five main tabs: `Home`, `Journal`, `Challenges`, `Series`, `Stats`.
-   My Books is not a sixth tab.
-   Book covers are the primary source of visual variety.
-   Do not add social/community features to V1.
-   Unknown/missing data is neutral, not an error.
-   No state may be communicated by color alone.
-   Functional typography is Manrope.
-   Papernotes Regular and Hello Baby are expressive accents only and
    never carry essential information.
-   Light/Dark/System appearance supported.
-   Minimum touch target: 44 × 44 pt.
-   Support Dynamic Type, VoiceOver, Reduce Motion, safe areas, keyboard
    avoidance, and accessible charts.

## Engineering behavior

-   Reuse shared components rather than implementing screen-specific
    duplicates.
-   Sensitive operations such as restore, destructive delete, import
    resolution, and external corrections require confirmed results
    rather than optimistic UI.
-   Prefer local/offline-capable reading workflows.
-   Never store secrets/tokens in source code, repository content, or
    clear-text backups.
-   Do not implement a feature that is explicitly TBD as though it were
    approved.
-   Do not add new product requirements without documenting and
    requesting approval.
-   Tests must cover the non-negotiable product rules, not only
    happy-path UI behavior.

## Before coding

Read: 1. `AGENTS.md` 2. `docs/MASTER_SPEC.md` 3. `docs/PRODUCT_RULES.md`
4. `docs/DESIGN_SYSTEM.md` 5. `docs/DATA_MODEL.md` 6.
`docs/ARCHITECTURE.md` 7. `docs/CHALLENGE_CATALOG.md`
8. `docs/IMPLEMENTATION_PLAN.md`

For the first Codex task, **do not implement the app yet**. Audit the
proposed architecture, identify unresolved technical decisions, and
return a technical proposal for approval.



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

## Phase 9 approved backup decisions

- V1 GitHub backup uses a fine-grained personal access token, minimum required
  permissions and one dedicated private backup repository. GitHub App authentication
  is not part of V1. Tokens belong only in iOS Keychain/secure platform credentials;
  never source, repository content, logs, portable exports or backups. Expiration and
  revocation must be handled explicitly.
- Portable backups use a versioned ZIP containing authoritative versioned JSON and
  required user-owned assets. The manifest includes backup format/schema/app versions,
  UTC creation time, a privacy-safe source description, entity counts and SHA-256 file
  checksums. The interchange schema is independent of SQLite. Restore validates the
  manifest and all checksums before any application.
- These two decisions were explicitly approved by the user on 2026-10-07 and supersede
  older references to them as Phase 9 TBD. Other TBDs and Foundation findings remain.

