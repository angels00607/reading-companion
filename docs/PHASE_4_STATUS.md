# Phase 4 — Series

## Scope and implemented behavior

Phase 4 implements the user-owned Series domain on `codex/phase-4-series`, based
on approved Phase 3 main `ff37e22b`. It adds the Series list, local search,
effective-status filters, sorting, Series Page, ordered timeline, Next Book,
physical tracker mapping, and explicit external-change review. The presentation
is typographic: there is no Series artwork, generated collage, or borrowed Book
cover masquerading as a Series image. Phase 5 has not started.

Series and SeriesEntry have stable UUID identities. A SeriesEntry links a Book to
its Series placement without duplicating the Book. Position and main/related kind
are independent stored facts. Decimal positions preserve and numerically order
values such as 0.5, 1, 1.5, and 2. Long Series and Book titles reflow rather than
using fixed-height rows.

## Status, totals, Next Book, and releases

The effective-status rule is implemented in the domain layer with user override
first: explicit Abandoned wins; unread included published entries produce Active;
all included published entries read plus reliable ongoing/future evidence produces
Waiting; all included confirmed entries read plus reliable completion produces
Completed; insufficient evidence produces Unknown. Missing completion confirmation
alone never produces Waiting.

Confirmed totals include only published or announced confirmed entries; rumored,
expected-unconfirmed, and unknown entries do not inflate the total. Whether the
final total is known remains explicit, so the UI can truthfully show “Final total
unknown.” Next Book is the first position-ordered, included, unread, published
entry. It does not select a later main entry or an unpublished future entry.
Release precision is represented as exact date, year, or unknown and is never
fabricated into finer precision.

## Persistence and external review

Additive SQLite `local_v5.sql` and Supabase
`202610050001_series.sql` migrations add owner-scoped Series, SeriesEntry, and
Series rejection records. Existing migrations are unchanged. Supabase tables use
owner RLS. Stored Series list, search/filter/sort, page data, tracker choices, and
review decisions remain locally usable offline.

External metadata is proposed rather than silently authoritative. Meaningful
changes retain current and proposed values and provenance, reuse the shared
AttentionRow/DataChangeReview language, and require explicit accept or reject.
Rejection fingerprints suppress the same proposal/evidence pair; materially
changed evidence can become eligible for review again. User status overrides and
tracker choices are not cleared by provider refresh.

## Tracker and Journal integration

The digital Series model is unlimited. Physical mapping uses Type 1 through 5
included entries, Type 2 through 10, Type 3 through 20, and Type 3 plus deterministic
continuation sections above 20. No digital entry is truncated. Tracker inclusion
is explicit and remains distinct from digital Series truth.

Phase 4 makes only the existing Journal Series component meaningful. Eligible
completed included Books can make that component ready; Book Review and Challenges
states remain independent. No global Journal-ready boolean or second correction
system was introduced.

## Tests and acceptance evidence

Automated tests cover decimal ordering and kind independence, unconfirmed and
unknown totals, the complete status truth table and override priority, Next Book,
release precision, unlimited digital timelines and every physical mapping tier,
offline repository behavior, non-destructive proposals, rejection suppression
with changed evidence, and Journal component independence.

Local validation:

- `swift build --target ReadingData`: pass.
- `swift build --target ReadingUI`: pass.
- SQLite v1→v5 migration/invariants: 17 tests pass.
- Books schema regressions: 3 tests pass.
- Xcode project generation and diff checks: pass.

CI exercises the full Swift/XCTest suite, iOS simulator build, SQLite migrations,
Supabase migration/RLS tests, Phase 3 Journal regression, and the Phase 4 Series
acceptance flow. The flow demonstrates normal Series → ordered timeline → Next
Book boundary; Waiting and Unknown evidence; external review and identical-evidence
suppression; and a 25-entry Series with Type 3 continuation and an intact entry 25.

## Human Visual QA

The labelled review boards and source-capture checklist are in
`docs/qa/phase-4/`. They cover Light Standard, Dark Standard, and Light
Accessibility XXXL on compact iPhone width, including deliberately long names,
fractional main/related entries, future and unknown states, all effective statuses,
Next Book, >20 entries, physical mapping, Needs Attention, Current/Proposed, and
the rejected/suppressed result. CI also retains the original captures in the
`phase-4-series-visual-qa` artifact. These are review materials; human visual
approval is not claimed.

## Known limits, genuine TBDs, and accessibility

- Provider-specific production Series ingestion and ambiguous cross-provider
  identity resolution remain later integration work; ambiguity is not auto-merged.
- Full cloud sync/outbox transport remains Phase 9. Local owner identity and local
  Series behavior are complete for this phase.
- Physical-device testing and full spoken VoiceOver certification remain later
  accessibility work.
- The historical Foundation accessibility findings remain visible, unfiltered,
  and governed by unchanged thresholds. Phase 4 does not suppress, weaken, or
  relabel them; their planned remediation remains Phase 12.
- Challenge matching/readiness is Phase 5 and Stats, gamification, import,
  notifications, onboarding, backup/restore, and new AI behavior remain out of
  scope.

Phase 4 is ready for human functional and visual review only. The PR must not be
merged without explicit approval.
