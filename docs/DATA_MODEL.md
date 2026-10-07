# Reading Companion --- Proposed Domain Data Model

**Status:** architecture input for Codex audit, not a final database
schema.\
Codex must validate normalization, identifiers, migrations, offline
behavior, and Supabase implementation before coding.

## 1. Core entities

### UserProfile

Purpose: private reader identity/preferences. Suggested fields: - `id` -
`display_name` - `avatar_ref` - `reading_history_since` (year; current
product value 2020) - `preferred_edition_language` (default `en`) -
`appearance_mode` (`system|light|dark`) - `created_at` - `updated_at`

Do not use account creation date as reading-history start.

### Book

Canonical work. Suggested fields: - `id` - `canonical_title` -
`canonical_author_display` - `manual_cover_ref` optional -
`primary_series_id` optional - `created_at` - `updated_at`

A Book must not duplicate merely because it is reread.

### Edition

Bibliographic edition of Book. Suggested fields: - `id` - `book_id` -
`language` - `edition_title` - `cover_ref` - `isbn10` optional -
`isbn13` optional - `page_count` optional - `provider_ids` / provider
mapping - provenance metadata - `created_at` - `updated_at`

Do not map external edition format into Journal Format.

### ReadingInstance

One reading occurrence. Suggested fields: - `id` - `book_id` -
`edition_id` optional - `status`
(`currently_reading|read|dnf`) - `start_date` optional -
`finish_date` optional - `progress_mode` explicit (`page|percentage`) - `current_page` optional in Page mode - `progress_percentage` optional in Percentage mode -
`effective_total_pages` optional/user-overridable - `rating_whole`
optional 1--5 - `journal_format` optional enum
(`paperback|hardcover|ebook|audiobook`) **USER ONLY** -
`primary_genre_id` optional - `is_historical_import` - `created_at` -
`updated_at`

To Read is library membership/intent, as approved in V2; it is not a ReadingInstance status.

### ProgressObservation

Fields: stable observation/mutation ID, ReadingInstance ID, original unit
(`page|percentage`), genuine previous/new value in that unit, optional genuine
Page denominator, base revision, recorded UTC timestamp and requires-review state.
Percentage observations have no page fields. Previous value may be unknown.
Page delta is derived only from two genuine same-unit positions in a resolved observation;
it is never derived from percentage. Unit/value history is immutable.

Completion side effects occur only after explicit finish confirmation.

## 2. Provenance / override model

### FieldProvenance

Could be normalized or embedded depending architecture. Suggested
semantics: - entity type/id - field name - value source - source
reference - confidence - `user_overridden` - `updated_at`

Required behavior: - user override blocks silent external overwrite; -
proposed external change remains reviewable; - rejection
fingerprint/evidence can suppress repeat proposal.

## 3. Journal

### JournalEntry

One journal record associated with a completed ReadingInstance.
Fields: - `id` - `reading_instance_id` - `summary` - Book Review
readiness/copy state - timestamps

Do not create for DNF.

### JournalComponentState

Components reference ReadingInstance directly; a completed JournalEntry is not
a universal prerequisite. Purpose distinguishes preparation from completion work.
DNF cannot generate completion-based work. Completion-flow queries exclude DNF,
and historical-import commands never automatically enqueue Journal Inbox work.
Existing preparation/history is not deleted or reclassified on DNF.
Prefer a reusable component-state model or explicit columns.
Components: - `book_review` - `series` - `challenges` - `favorite` -
`quote`

Each needs enough state to distinguish: - incomplete/pending - ready -
copied/journaled - explicitly none where supported

### JournalCorrection

For values changed after physical copy. Fields: - entity/component
reference - field - previous copied value - current value - status
(`pending|resolved`) - timestamps

### Favorite

May reference Book and/or ReadingInstance according to implementation,
but physical Favorite Books is book-oriented. Need explicit user
add/remove.

### Quote

-   `id`
-   `book_id`
-   `reading_instance_id` optional
-   quote text
-   source/page optional if user supplies it
-   `add_to_physical_journal`
-   `copied_at` optional

Never invent quote text/source.

### JournalVolume / RefillState

Represent physical refill capacities and archive state. Need support
for: - Book Reviews - Reading Log - Series Tracker - Favorites -
Quotes - Stats volumes

Exact schema can be implementation-specific; capacity rules are product
rules.

## 4. Series

### Series

-   `id`
-   `name`
-   `author_display`
-   `user_status_override` optional
-   computed/effective status
-   timestamps

### SeriesEntry

-   `id`
-   `series_id`
-   `book_id` optional if not yet in Library
-   verified title
-   position decimal/string capable of `0.5`, `1.5`
-   entry type (`main|related|companion`)
-   publication state (`published|announced|unconfirmed|unknown`)
-   release precision (`exact|year|unknown`)
-   release value optional
-   `include_in_physical_tracker`
-   provenance

Unconfirmed entries do not count in confirmed total.

## 5. Challenges

### ChallengeDefinition

-   `id`
-   stable key
-   name
-   challenge type
-   versioned content metadata

### ChallengeYearSnapshot

Immutable yearly configuration. - year - active version (`A|B`) - copied
prompt definitions/version references - created_at

Even year A; odd year B.

### ChallengePromptSnapshot

-   snapshot id
-   challenge year snapshot id
-   stable prompt key
-   display text
-   ordering
-   special rules metadata

### ChallengeAssignment

-   prompt snapshot id
-   reading_instance_id
-   status (`proposed|confirmed|rejected`)
-   confidence exact percentage optional
-   explanation/evidence
-   source/provenance
-   rejection fingerprint
-   timestamps

Only confirmed assignment occupies a prompt.

## 6. Quests / gamification

### QuestTemplate

-   stable key
-   family
-   cadence eligibility
-   target logic
-   difficulty metadata
-   cooldown metadata
-   wording variants

### QuestInstance

-   template id
-   cadence (`daily|weekly|monthly`)
-   period
-   target
-   progress
-   status
-   XP reward
-   reroll metadata

### XPEvent

Ledger-style recommended: - id - type/source - source entity id -
amount - created_at

XP must never be negative.

Phase 7 implementation uses the existing immutable `xp_awards` ledger keyed by
`(owner_id, semantic_key)` and an equally immutable one-to-one source metadata row.
This preserves the Phase 0 restore/merge contract while adding stable award-source
classification. A retry with the same semantic key is a no-op; no migration creates
retroactive awards.

### AchievementDefinition

-   stable key
-   name
-   condition definition
-   XP reward optional
-   visual asset key
-   category

### UserAchievement

-   achievement id
-   unlocked_at
-   featured flag/order

### CosmeticDefinition

-   key
-   category (`background|accent|frame|card|decoration|theme`)
-   unlock condition
-   light/dark assets/tokens
-   metadata

### UserCosmetic

-   cosmetic id
-   unlocked_at
-   equipped state as appropriate

No currency/rarity/paywall fields are required by product.

Phase 7 persists private `reader_profiles`, period-keyed `quest_instances`,
with additive `quest_lifecycle` slot/creation-baseline metadata and immutable
`gamification_activity` facts for real live commands. Local v9 and Supabase
`202610070002_live_gamification.sql` add these without rewriting prior migrations
or backfilling ordinary XP. Exact periods, cooldowns, rerolls, derived Achievement
conditions and cosmetic eligibility are specified in [PHASE_7_LIFECYCLE.md](PHASE_7_LIFECYCLE.md).
Phase 7 also preserves
monotonic `achievement_progress`, and `user_cosmetics`. Quest rows preserve reroll
history rather than deleting rejected candidates. Locked cosmetics are derived from
the catalog and level; only unlocked/equipped state is persisted.

## 7. Stats selections

### BestBookSelection

-   scope (`month|year`)
-   period
-   selected book/reading id
-   created/updated timestamps

Month choice is manual. Year choice is manual and should be consistent
with product candidate rules.

Primary Genre should be normalized via a user-manageable Genre entity or
controlled user list.

## 8. Attention / notifications

### AttentionItem

-   `id`
-   category (`journal|series|challenges|books|import`)
-   priority (`required|review|optional`)
-   entity reference
-   reason/type
-   status (`open|resolved|dismissed` where allowed)
-   created_at
-   resolved_at

Persistent unresolved action.

### NotificationEvent

Optional separate store: - informational delivery/history - may expire
after read/time - must not replace AttentionItem.

### ProposedDataChange

Useful reusable model: - entity/field - current value - proposed value -
source - source reference - confidence - evidence/fingerprint - status
(`pending|accepted|kept|edited`) - timestamps

Supports `DataChangeReview`.

## 9. Imports

### ImportRun

-   id
-   source (`storygraph_csv`, etc.)
-   started/completed timestamps
-   counts
-   status
-   historical flag

### ImportCandidate / ImportMatch

Need enough data for: - New Book - Possible Update - Already Up to
Date - Needs Review - match confidence - chosen resolution

Import application must preserve user overrides.

## 10. Backup metadata

### BackupManifest

Portable serialization metadata: - schema version - app version -
created_at - source device label - entity counts - checksums/integrity
metadata - backup format version

Never include auth tokens/secrets.

## 11. Primary relationships

``` text
User
 ├─ Books (library relationship as architecture decides)
 │   ├─ Editions
 │   └─ ReadingInstances
 │       ├─ ProgressEvents
 │       └─ JournalEntry
 │           ├─ JournalComponentStates
 │           ├─ Quotes
 │           └─ JournalCorrections
 ├─ Series
 │   └─ SeriesEntries → Books
 ├─ ChallengeYearSnapshots
 │   └─ PromptSnapshots
 │       └─ ChallengeAssignments → ReadingInstances
 ├─ QuestInstances
 ├─ XPEvents
 ├─ UserAchievements
 ├─ UserCosmetics
 ├─ BestBookSelections
 ├─ AttentionItems
 ├─ ProposedDataChanges
 └─ ImportRuns
```

## 12. Required invariants for tests

-   Reread never duplicates Book.
-   External provider cannot populate `journal_format`.
-   DNF cannot create completion XP/Book Review/Stats contribution.
-   Historical import cannot replay live completion side effects.
-   User override cannot be silently overwritten.
-   Confirmed Challenge prompt cannot receive another automatic
    assignment.
-   Odd/even A/B rule deterministic.
-   Unconfirmed series entry excluded from confirmed total.
-   No Rating is nullable/explicit state, not zero.
-   Unknown page count remains valid.
-   Restore never applies before preview/integrity validation.



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
