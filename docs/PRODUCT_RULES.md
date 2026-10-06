# Reading Companion --- Product Rules

This file extracts behavior that should become domain logic and
automated tests.

## Priority order

When values conflict: 1. explicit current user value / user override; 2.
previously accepted app value; 3. trusted imported/external proposal
awaiting user acceptance; 4. AI suggestion; 5. unknown.

External data never silently replaces level 1.

## Books, Editions, Readings

-   One canonical `Book` can have many `Edition` records.
-   One `Book` can have many `ReadingInstance` records.
-   Reread = new ReadingInstance.
-   Latest ReadingInstance may drive the Book Page's current personal
    rating.
-   Edition language/title/cover/ISBN/pages may differ.
-   Preferred search edition is English.
-   Offer French only when a verified published French edition exists.

## Journal Format

-   Values: Paperback / Hardcover / Ebook / Audiobook.
-   Belongs to ReadingInstance.
-   Must be explicitly selected by user.
-   Never imported, inferred, suggested, preselected, or copied from
    Edition metadata.
-   Required for Book Review Ready to Journal.

## Status and progress

-   To Read → Currently Reading → Read.
-   Currently Reading → DNF.
-   DNF → Currently Reading via Resume.
-   Page updates compute deltas from genuine prior page position; Percentage updates preserve their own unit.
-   Final page or 100% requires explicit finish confirmation.
-   Do not create completion side effects until confirmation.

## DNF exclusions

A DNF: - does not create Book Review; - does not auto-run Challenge
matching; - does not count as Books Read; - is excluded from Reading
Stats and physical Journal Stats; - gives no completion XP; - retains
progress; - can be resumed.

## Historical imports

Imported historical records: - populate Library/Reading History/Stats
where data exists; - do not replay live completion events; - do not
mass-award XP/Achievements; - do not mass-create Quest progress; - do
not auto-run historical Challenge assignment unless a future explicit
workflow says so.

## Journal

A finished Book creates/enters Journal Inbox. Readiness is per
component, not one global boolean.

Book Review physical fields: - Title - Author - Pages - Rating -
Format - Start - Finish - Summary

Rules: - whole-star rating 1--5 + No rating; - never round half stars
automatically; - manual pages/dates override imported values; -
Challenge pending does not block Book Review readiness; - Favorite and
Quote support explicit "none" states; - physical-copy status is tracked
independently; - later changed copied data creates Journal Correction.

## Series

-   User series status override wins.
-   No generated series image.
-   Fractional positions supported.
-   Unconfirmed future books do not count in confirmed total.
-   Release dates are exact/year/unknown only if verified.
-   Next Book = next included unread series entry.
-   External changes require review.
-   Same rejected correction is suppressed until evidence changes.

## Challenges

### Calendar version

`year % 2 == 0` → A\
`year % 2 == 1` → B

Persist/snapshot yearly configuration so later content edits do not
rewrite history.

### Sequential assignment

For each Challenge/version/year: - confirmed prompt becomes occupied; -
later books can only target free prompts; - Challenges are independent
from one another.

### Automatic proposals

-   Analyze all eligible free prompts.
-   Only propose if confidence ≥70% and evidence is reliable.
-   Display one best proposal at a time with exact percentage.
-   Reject requires no reason.
-   After reject, show next-best eligible ≥70%.
-   Store rejection fingerprint/evidence so identical suggestion does
    not immediately recur.
-   Confirm is always user action.
-   Manual assignment remains available.

### 52 Weeks

-   finish date determines week;
-   no finish date → cannot auto-place;
-   no borrowing between weeks;
-   first chronologically finished eligible book wins tie by default;
-   manual replacement only with another book from same week.

## Quests

-   Activity/behavior only.
-   Never require a book's genre/trope/content.
-   No XP loss or punishment.
-   Must be possible when issued.
-   Use history/cooldowns.
-   Adaptive targets use smoothed activity, not one anomalous week.
-   Daily/Weekly/Monthly current starting volume: 2/3/3.
-   Candidate rerolls: Daily 1/day, Weekly 1/week.
-   Rerolled quest cannot immediately return.

## Stats

-   DNF excluded.
-   ReadingInstance is counting unit for rereads.
-   Exactly one Primary Genre per reading for stats.
-   User genre choice overrides suggestion.
-   No rating is distinct from 0 stars.
-   Best Book Month is manually selected.
-   Book of Year is manually selected from monthly winners/candidates.
-   Comparisons are factual and neutral.
-   Reading Days count days read; never display "missed days" as
    failure.

## XP / Achievements

-   XP permanent.
-   No XP loss.
-   No daily login reward/streak multiplier.
-   No simple page=XP farm.
-   Challenge XP only after Confirm.
-   Import/backup/admin actions award no XP.
-   Levels unlock cosmetics only.
-   Achievements are visible, one-time, with explicit
    condition/progress.
-   No secret achievements.
-   No bronze/silver/gold tier requirement.

### Phase 7 V1 balancing catalog

- Finish Book: 100 XP; Complete Journal work: 40 XP; Confirm Challenge prompt: 30 XP.
- Daily Quest: 20 XP; Weekly Quest: 60 XP; Monthly Quest: 150 XP.
- Every 500 XP advances one level, with no artificial maximum.
- Achievement awards are configurable from 50 through 250 XP according to importance; level-only Achievements award 0 XP.
- These values are implemented through one typed balancing catalog, never duplicated as feature-level constants.
- The XP ledger is append-only and idempotent by stable semantic award key. Historical imports and administrative import/backup actions do not emit awards.

## Attention / notifications

-   Push notification is delivery; AttentionItem is persistent
    unresolved work.
-   Turning push off never hides required AttentionItem.
-   Group bulk update noise.
-   Badge counts meaningful unresolved attention.
-   Informational no-action notifications can expire; unresolved
    AttentionItems persist.

## Imports / reconciliation

Preview groups: - New Books - Possible Updates - Already Up to Date -
Needs Review

Never blind-overwrite enriched/user-corrected data. Matching uncertainty
must be reviewable. Maintain Import History.

## Backup / restore

-   Supabase live data/sync.
-   GitHub manual versioned snapshots, not per-change commits.
-   Local export independent.
-   Restore requires preview and integrity check.
-   High-impact destructive operations require explicit confirmation.
-   Secrets never enter backup payloads.

## UX safety rules

-   Unknown is neutral, not error.
-   No guilt copy.
-   No social/community V1.
-   No unnecessary confirmation for reversible actions; prefer Undo.
-   Red is reserved for genuinely destructive/error semantics.



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
