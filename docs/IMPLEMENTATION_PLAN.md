# Reading Companion --- Implementation Plan

## Operating rule

Each phase must: 1. read `AGENTS.md` and relevant `/docs`; 2. define
acceptance criteria; 3. implement only the approved scope; 4. add/update
tests; 5. compile/run tests; 6. document deviations/TBDs; 7. stop for
review before broadening scope.

Do not build the whole app in one pass.

## Pre-Phase --- Technical Audit

**No application implementation yet.**

Codex deliverables: - architecture proposal; - technology choices with
rationale; - final proposed domain/schema model; - local/offline/sync
strategy; - Supabase/RLS/auth plan; - provider architecture; - AI
boundary; - backup/restore design; - test strategy; - risk register; -
decisions requiring approval.

Exit gate: human approval of technical architecture.

## Phase 0 --- Foundations

Implement: - project/repository structure; - environments/config; - core
domain types; - database schema/migrations; - local persistence
foundation; - Supabase foundation; - sync/outbox scaffolding; -
provenance/user-override primitives; - design tokens; - typography
wiring; - base navigation shell; - logging/error foundation; - test
infrastructure.

Do not build feature-rich screens yet.

Exit gate: - builds cleanly; - migrations tested; - Light/Dark tokens
render; - navigation shell works; - core invariants have tests.

## Phase 1 --- App Shell & Shared UI

Implement five-tab shell: - Home - Journal - Challenges - Series - Stats

Implement shared components: - BookRow - BookCover - StatusChip -
ProgressBar - buttons - FilterChip - SegmentedControl - BottomSheet -
Toast - Skeletons - Empty/Error/Offline states - DataChangeReview -
AttentionRow - accessible chart foundation - celebration shell

Exit gate: visual QA before feature expansion.

## Phase 2 --- Books Core

Implement: - Global Search; - local-first results; - external provider
abstraction; - edition selection; - Add Book; - Manual Add; - duplicate
handling; - My Books; - Book Page; - To Read / Currently Reading / Read
/ DNF transitions; - Update Progress; - explicit Finish confirmation; -
Reading History / rereads; - editable Book Info; - Primary Genre
override; - cover override.

Acceptance flow: Search → Add → Start → page 183 → page 257 →
`+74 pages` → final page → confirm → appears Read.

Required tests: - no Format inference; - reread no duplicate Book; - DNF
exclusions; - unknown page handling; - provider/user override priority.

## Phase 3 --- Journal

Implement: - Journal Inbox; - component readiness; - Book Review; -
Summary field/assistant integration boundary; - Favorites; - Quotes; -
Reading Log data; - My Journal/refill capacities; - Journal Session; -
copied state; - Journal Correction.

Acceptance flow: Finish Book → Inbox → complete Book Review → Ready to
Journal → Journal Session → Copied.

## Phase 4 --- Series

Implement: - Series list/filters/sort/search; - statuses; - Series
Page; - fractional timeline; - main vs related; - Next Book; - future
release states; - tracker inclusion/mapping; - Needs Attention; -
Current vs Proposed review; - external update suppression after
rejection.

Tests must cover unconfirmed totals and fractional positions.

## Phase 5 --- Challenges

Implement: - yearly snapshot/config; - A/B deterministic rotation; -
prompt occupancy; - matching proposal model; - ≥70% threshold; - exact
percentage; - Confirm / Reject / Ask Assistant boundary; - next-best
after reject; - manual assignment; - archive; - 52 Weeks special
rules; - configured challenge types.

Do not invent missing challenge prompts.

Tests: - 2027=B; - confirmed prompt occupied; - challenges
independent; - rejection suppression; - 52 Weeks finish-date behavior.

## Phase 6 --- Stats

Implement: - Month / Year / Lifetime; - Books / Pages / Reading Days; -
ratings; - Primary Genres; - Formats; - reading-over-time charts; -
reread handling; - Best Book Month manual selection; - Book of Year
manual selection; - Journal View Monthly/Yearly/Lifetime.

Tests: - DNF excluded; - No Rating not zero; - rereads count as
ReadingInstances; - manual best-book selection.

## Phase 7 --- Profile & Gamification

Implement: - Profile Reader Passport; - XP ledger; - Levels; - Quest
Engine; - cooldown/history/adaptive target foundation; - Achievements; -
Featured Achievements; - Collection; - cosmetics; - Theme presets; -
customization preview.

Do not add currency, rarity economy, streak punishment, or essential
feature locks.

## Phase 8 --- StoryGraph Import / Reconcile

Implement: - CSV selection/parsing; - matching; - initial historical
import; - preview categories; - reconciliation; - user-override
protection; - Needs Review; - Import History.

Critical acceptance: Large historical import does **not** replay Book
Completed, XP, Achievements, Quests, or automatic historical Challenge
cascades.

## Phase 9 --- Sync, Backup & Restore

Implement/finish: - Supabase sync; - offline mutation queue; - conflict
resolution; - GitHub manual backup; - local full export; -
manifest/integrity; - restore preview; - transactional restore.

Adversarial test: update progress offline → reconnect → no
lost/duplicated reading data.

## Phase 10 --- Onboarding, Notifications & Attention

Implement: - Welcome; - Reading History Since; - Preferred Edition; -
Import vs Start Fresh; - Library Ready; - contextual notification
permission; - push settings/defaults; - Notification history if
included; - Needs Attention central UI; - meaningful badge counts.

## Phase 11 --- Polish

Implement/refine: - motion; - haptics; - skeletons; - transitions; -
Book Completed; - Achievement; - Level Up; - empty/error/offline
states; - final visual consistency.

Respect Reduce Motion.

## Phase 12 --- Accessibility & Responsive QA

Verify: - Dynamic Type; - VoiceOver; - contrast; - Reduce Motion; -
44×44 targets; - Dark Mode; - smallest supported iPhone widths; - long
titles/authors/series; - keyboard avoidance; - charts.

## Phase 13 --- Data Integrity QA

Explicit adversarial cases: - provider pages differ from user pages; -
StoryGraph proposes different date after user correction; - unknown
Series remains unknown; - Format never prefilled; - DNF excluded
everywhere required; - reread does not duplicate Book; - historical
import does not award live rewards; - rejected Challenge suggestion does
not immediately recur; - rejected external correction does not silently
return without new evidence.

## Phase 14 --- Personal Beta

Use the app for real reading over multiple weeks. Classify feedback: -
BUG - UX ISSUE - V1 REQUIREMENT - V2 IDEA

Do not automatically add every idea to V1.

## Phase 15 --- V1 Stabilization

-   fix bugs/crashes;
-   performance;
-   migrations;
-   sync;
-   restore;
-   accessibility;
-   data integrity;
-   freeze new features;
-   release candidate QA.

## First Codex prompt

Use this after committing this Kickoff Pack:

> Read `AGENTS.md` and every file in `/docs` before making
> implementation decisions.
>
> Do not implement the application yet.
>
> Perform a technical architecture audit of Reading Companion. Identify
> the required client architecture, domain boundaries, database model,
> local persistence strategy, Supabase requirements,
> synchronization/conflict strategy, provider architecture, AI boundary,
> backup/restore approach, reusable UI system, testing strategy,
> security concerns, and unresolved technical decisions.
>
> Preserve all locked product behavior. Do not invent missing
> requirements. If a requirement is explicitly TBD, present technical
> options and a recommendation without treating the choice as approved.
>
> Return: 1. proposed architecture; 2. proposed technology stack; 3.
> proposed schema/domain refinements; 4. offline/sync design; 5.
> security/RLS plan; 6. provider/import design; 7. backup/restore
> design; 8. test strategy; 9. risks and tradeoffs; 10. decisions
> requiring approval before Phase 0.
>
> Stop after the audit and wait for approval.



## V2 — Audit closure prompt

After committing V2, send Codex:

> The initial architecture audit has been reviewed. The approved decisions and clarifications are now incorporated into `AGENTS.md` and `/docs`, including `CHALLENGE_CATALOG.md`.
>
> Do not implement the application yet.
>
> Re-read `AGENTS.md` and every file in `/docs`. Treat the updated documentation as authoritative.
>
> Produce a concise final Architecture Decision Record (ADR) for Reading Companion. Do not repeat the full audit.
>
> The ADR must:
> 1. list the architecture decisions now approved for Phase 0;
> 2. identify only genuine blockers that would prevent Phase 0 from starting;
> 3. distinguish blockers from decisions safely deferred to later phases;
> 4. confirm that the proposed Phase 0 data model and sync foundations preserve all non-negotiable product rules;
> 5. explicitly confirm that missing Challenge content marked TBD will not be inferred;
> 6. state whether the repository is `READY FOR PHASE 0`.
>
> Do not make repository changes and do not write application code. Stop after the ADR and wait for approval.

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

