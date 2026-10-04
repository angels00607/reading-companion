# Phase 3 — Journal

## Scope and acceptance

Phase 3 implements Journal only on `codex/phase-3-journal`, based on authoritative
main `fc37bf97`. The required flow is explicit Finish → Journal Inbox → complete
Book Review → Ready → focused Journal Session → explicit Copied. A later edit to
copied data creates a Journal Correction that remains pending until explicitly
resolved. Phase 4 has not started and this branch must not be merged before human
functional and visual review.

## Implemented model and UI

- Live, explicit completion creates one idempotent `JournalEntry` and independent
  Book Review, Series, Challenges, Favorite and Quote component states. DNF and
  historical completion remain excluded by the existing origin/status rules.
- Book Review reuses Book and ReadingInstance title, author, rating, Format and
  dates; Summary and effective physical page count are Journal preparation data.
  Summary, explicit whole-star/No Rating and user-selected Format are required for
  Ready. Unknown page count and calendar dates remain valid and are never invented.
- Summary is manually usable offline. `SummaryAssistant` remains an injection
  boundary with a truthful unavailable implementation; no AI provider, secret or
  implicit write is introduced. A future suggestion must still require an explicit
  “Use this summary” product action before becoming authoritative.
- Favorite preserves pending, selected and explicit none. It is book-oriented, so
  rereads do not duplicate the favorite record. Quotes are user text, support an
  optional user source, multiple records and independent physical selection;
  component pending is distinct from explicit No quote.
- Journal tab presents Journal Inbox, My Journal usage and a focused full-screen
  iOS Journal Session. Ready and Copied are distinct; opening a session changes
  nothing and only the Copied button records the snapshot and advances.
- Edits after copying compare the authoritative review with its copied snapshot.
  Each changed field becomes a pending correction showing copied/current values;
  resolution is explicit and non-destructive.
- Series and Challenges component rows are established but stay pending. No Series,
  Challenge, Stats, XP or Quest engine is fabricated.

## Capacity and persistence

The authoritative review refill capacity is exactly 100 (not 108). Reading Log is
20 books/page, Favorites 150/refill and 15/page, and Quotes 6/page. Current volume
usage and remaining reviews are shown. Copied reviews retain a stable `volume_id`;
archiving is permitted only when the current review capacity is full, preserves all
history, and creates the next stable volume.

Additive `local_v4.sql` and `202610040001_journal.sql` add Journal entries, volumes,
Favorites, Quotes and Corrections with owner-scoped identities and relational links.
Supabase tables enable owner RLS. Journal mutations enter the existing durable
outbox; unsupported Phase 9 cloud transport continues to fail closed.

## Validation and visual QA

Local validation completed:

- Swift package build: pass.
- SQLite v1→v4 migration/invariants: 16 tests pass.
- Books schema regression tests: 3 tests pass.
- Xcode project generation: pass.

CI #37237643919 passes the complete 58-test Swift/XCTest suite, iOS simulator build,
Supabase migration/RLS tests, SQLite checks, official Journal acceptance flow and
Journal visual capture run. Phase 3 adds
domain/data coverage for readiness, exact capacities, idempotent completion,
Favorite/Quote decisions, Ready/Copied separation and Corrections. CI produces
Light Standard, Dark Standard and Accessibility XXXL captures in the
`phase-3-journal-visual-qa` artifact. Labelled contact sheets and their source
captures are in `docs/qa/phase-3/`. Human approval is not claimed.

The existing Foundation accessibility audit remains unfiltered with unchanged
thresholds. Its previously documented Phase 1/2 findings, physical-device review,
and full spoken VoiceOver certification remain deferred to Phase 12; Phase 3 does
not suppress or relabel them.

## Known limits and genuine TBDs

- Production Summary Assistant provider/model, conversational revision UX and
  approved credentials/configuration remain TBD; manual Summary is complete.
- Series and Challenges readiness producers belong to Phases 4 and 5.
- Full cloud sync, conflict application and authentication belong to later phases.
- Exact future physical placement for structures without sufficient authoritative
  data is not fabricated. Reading Log is derived data; Phase 6 Stats is not begun.
- Physical-device and human visual approval are still required. Do not merge until
  the Phase 3 review is explicitly approved.
