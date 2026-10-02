# Phase 2 — Books Core

## Scope and acceptance criteria

Branch `codex/phase-2-books-core` starts from authoritative main `158e807`.
AGENTS.md and every docs file were read before implementation; existing domain,
GRDB migrations and approved Phase 1 components were inspected.

Required acceptance: Search → Add → Start → page 183 → page 257 → genuine
`+74 pages` → final page → explicit confirm → appears Read. Tests must demonstrate
no Format inference, reread without duplicate Book, DNF exclusions, unknown pages,
provider/user override priority, page/percentage bounds and original-unit history.
Human visual approval is required before merge. No Phase 3 or merge is authorized.

## Implemented

- Local-first Global Search; work-level external results; real edition selection,
  English ordering without invented French options; Add as To Read, Currently
  Reading or explicitly Already Read; progressive Manual Add.
- My Books outside the five tabs: All / To Read / Read, lists, local search,
  database-side sorting/filtering and progressive retrieval.
- Book Page, start/reread, page and fractional percentage progress, genuine delta,
  optional genuine page total, manual Finish with unknown progress, explicit final
  page/100% confirmation, DNF/resume, Reading History and per-reading corrections.
- Editable work and edition facts; per-reading user-only Format and Primary Genre;
  cover URL/photo/remove overrides; external synopsis separate from future Journal.
- Private UUID identities; account-scoped relational GRDB persistence; mutations
  and outbox write atomically. Provider differences become persistent proposals;
  Keep/Accept/Edit is explicit, stale proposals are rejected, fingerprinted rejected
  evidence does not recur unchanged. Progress conflicts remain reviewable.
- Shared components/tokens/typography/navigation reused; optional artwork input
  added to existing BookCover/BookRow without changing their design. Fractional
  percentage accessibility labels now preserve their supplied precision.

## Persistence / provider behavior

Additive local_v3 and cloud 202610020001 add catalog facts, provider identity links,
reading Primary Genre and observation ordering. v1/v2 SQL remains unchanged. Cloud
provider links have owner-only SELECT RLS and no authenticated/anonymous raw writes.
New Books Core commands queue durably; the Phase 0 transport still supports only
book.create and fails closed for unsupported commands. Full Phase 9 sync is not built.
Local-only installation owner identity is persisted in Application Support until
the approved Apple authentication integration; it is not a credential or cloud session.

Open Library is an interchangeable first adapter from the documented provider
direction; no cross-provider ranking is claimed approved. Search is work-first,
debounced; requests bounded/throttled/cached with timeouts. Editions fetch at most
200 existing records. Unfetched/unknown editions do not imply a missing translation.
Manual Add and cached local workflows work without network. Google Books priority,
cross-provider scoring and additional adapters remain TBD rather than inferred.
Sources are recorded per field; no provider contract includes user Format.

Exact single provider work identity reuses a Book; contradictory ISBN/work identity,
ambiguous repeats and manual title/author matches require explicit reuse or Add Anyway.
New editions do not create new Books; rereads create new ReadingInstances. No
destructive merge or deletion is implemented. Cover removal is an explicit empty
override, distinct from unknown/no override, so edition/provider fallback cannot
silently replace it. Local photos are per-owner assets; cloud media transport is deferred.

Progress mode is chosen at start; changing mode on an existing reading remains
deferred as documented. History never converts units. Conflicts do not use maxima
or timestamps; explicit review preserves original observations. Completing a reading
does not dispatch future Journal/Challenge/XP consumers in Phase 2.

## Validation and Human Visual QA

Local: 16 existing SQLite tests and 3 new additive migration tests pass; diff check passes.
Swift, iOS/font/UI and Supabase/RLS results are pending macOS/Linux CI validation.
BooksCoreAcceptanceTests demonstrates the official flow and produces named captures
for 13 screen states in Light, Dark and compact Accessibility XXXL, including top
and lower captures. DEBUG fixture routes are labelled QA metadata and are never
enabled on ordinary/Release launches. Screenshots/contact sheets will be linked here.
All existing Phase 0/1 test thresholds and accessibility audits remain unchanged.

## Limits / TBDs and deviations

- Phase 1 baseline CI #92 retains 147 findings: 90 Dynamic Type, 30 potential clipping,
  18 contrast detections, 9 undersized targets. The earlier 107 nil-element Dynamic
  Type diagnostic history remains in PHASE_0_STATUS. No false positive is established,
  no finding suppressed. Phase 12/manual native inspection remains required.
- Physical device / spoken VoiceOver / complete Phase 12 acceptance is not claimed.
- No Favorite filter is fabricated before Phase 3 Favorite data exists. Series filter
  uses a user-entered series name, not a Phase 4 series engine. Journal/Series/
  Challenges/Stats tabs retain the approved Phase 1 preview shell.
- Genre is a nullable per-reading user choice; managing/deleting the full genre
  catalogue belongs to later Settings work. Unknown remains valid.
- Add-state steps and Book/Edition edit steps currently commit as individual durable
  commands; a later step error reports saved local state explicitly, not a false
  rollback or success. This must be assessed in final validation and review.
- No StoryGraph import, backup/restore, onboarding, notifications, AI, listening-time
  progress or future completion side effects. Challenge TBD content remains untouched.

Phase 2 implementation is awaiting automated and human visual review. Do not merge.
