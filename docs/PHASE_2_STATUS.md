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
Title/author corrections entered during external Add are recorded as manual
overrides in the same transaction; untouched fields retain their provider source.
The first adapter refreshes work title/cover/synopsis. Fetching changed author
records and edition refresh proposals is not implemented; manual corrections remain
available. In-memory HTTP caching is bounded to the provider instance lifetime,
not an approved indefinite freshness policy for a future multi-provider engine.

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

Automated evidence: [CI #110](https://github.com/angels00607/reading-companion/actions/runs/36987677905)
on application/test commit `0405605b75c63597705ef363e99645da16575995`.
Subsequent commits add documentation/QA boards and preserve repository LF line
endings; no semantic application/test source changes follow the tested commit.

| Check | Result |
| --- | --- |
| Swift domain/data/shared UI suite | 52 tests pass, including the 32 baseline tests |
| SQLite invariants / additive migration | 16 existing + 3 new tests pass |
| Supabase migrations / ownership / RLS | 56 tests pass |
| iOS simulator application build | Pass |
| Hosted approved-font registration | Pass, no fallback |
| Official Search → Add → Start → 183 → 257 → +74 → final page → confirm → Read | Pass |
| Light / Dark / compact Accessibility XXXL Books Core visual tests | All 3 pass |
| Existing unfiltered foundation acceptance | Fails; findings remain open, detailed below |
| Local diff check | Pass |

Font tests verify Manrope-Regular, Manrope-Medium, Manrope-SemiBold,
PapernotesRegular and HelloBabyRegular. Existing approved font assets are unchanged.

BooksCoreAcceptanceTests produces 83 named captures: 13 screen states × top/lower ×
3 display scenarios, plus 5 official-flow milestones. Visible identified Phase 2
buttons keep their label/44-point assertions. DEBUG fixture routes are labelled QA
metadata and are never enabled on ordinary/Release launches.
[Human Visual QA boards](qa/phase-2/README.md) and the run's `phase-2-books-visual-qa`
artifact retain the captures. The boards were inspected: long text wraps, forms
scroll vertically, Dark prompts are legible and completion remains explicit.
This inspection is not human visual approval or complete Phase 12 certification.
All existing Phase 0/1 test thresholds and accessibility audits remain unchanged.

Required coverage maps to `BooksCoreTests` (official flow/reread, Format isolation,
DNF, unknown progress/manual finish, percentage bounds/no conversion, provider
priority, duplicate identity, conflict replay/resolution and durable reopen),
`BooksAtomicTests` (rollback, user provenance, completed-reading filters, uncertain
identity and ISBN edition reuse), and `ProviderTests` (real adapter decoding,
discarded external format, real language records and offline library operation).
The pre-existing domain, shared UI, migration and RLS tests remain in the full suite.

### Corrective QA evidence

- Initial populated-field replacement left the caret at the beginning, producing
  `400257` instead of `400`. The saved screenshot established invalid fixture input,
  not an automatic-finish defect. The test now positions the caret at the end and
  asserts the exact live input. No acceptance assertion was removed.
- The keyboard obscured the progress save target on compact devices. A native
  `Done` command dismisses focus, retains Manrope and has a 44-point target.
- Navigation text had a 44-point outer layout reservation but the live accessibility
  button retained its 22-point text height. The target now belongs to its label and
  content shape; the test still requires 44 points and reports identity/label/frame.
- Empty field prompts used the system placeholder color, visibly too faint in Dark
  captures. Books forms now use the approved secondary-text semantic token.
- Read filters now match a completed reading rather than an active reread's metadata.
- CI #106 first demonstrates the complete official UI flow. CI #110 then passes
  all four Books Core UI tests after the target corrections, with captured
  `+74 pages`, explicit finish confirmation and `Read`.

## Limits / TBDs and deviations

- Phase 1 baseline CI #92 retains 147 findings: 90 Dynamic Type, 30 potential clipping,
  18 contrast detections, 9 undersized targets. The earlier 107 nil-element Dynamic
  Type diagnostic history remains in PHASE_0_STATUS. No false positive is established,
  no finding suppressed. Phase 12/manual native inspection remains required.
- Final CI #110 reproduces those 147 audit findings plus the single background-
  coverage assertion below (148 foundation failures total). Default and largest-size
  foundation stages both ran. Their results are not relabelled as passing.
- Full foundation runs also report a Dark Accessibility XXXL landscape background-
  coverage assertion: 0.2143 versus the unchanged >0.25 threshold, on Home. The
  same assertion and exact 0.21428571428571427 measurement are present in the
  pre-Phase-2 Phase 1 CI #88, #90 and final CI #92 logs. The Phase 1 final capture
  and CI #110 capture are both 1334 x 750 pixels and have the same 584 x 750-pixel
  black strip (x=750...1333), the same 438,000 black pixels and the same 227,072
  Dark-background pixels.
- This test launches the Phase 1 `FoundationShell` diagnostics route before rotating
  the simulator; it does not instantiate the Phase 2 `BooksHome` release route.
  In CI #110, XCTest reports a 667 x 375-point landscape window and full-window
  `ScrollView`, while the exported 1334 x 750 bitmap contains rendered application
  pixels only through x=749. The concrete cause is therefore the QA host/export
  presentation retaining the portrait-width backing after rotation, not safe-area
  handling, fixed-height content, scroll sizing, background attachment, or the
  Phase 2 navigation/content layout. This is a pre-existing Phase 1 QA-capture
  limitation, also consistent with the landscape export limitation recorded in
  `PHASE_0_STATUS.md`; Phase 2 did not introduce it.
- No Release/native layout evidence reproduces the uncovered region: the native
  accessibility hierarchy spans the full landscape window. Physical-device visual
  acceptance is still not claimed. No UI code, preview layout, audit threshold,
  assertion, suppression, or filter was changed to make this metric pass, and no
  replacement capture was generated because the rendered layout did not change.
- Physical device / spoken VoiceOver / complete Phase 12 acceptance is not claimed.
- No Favorite filter is fabricated before Phase 3 Favorite data exists. Series filter
  uses a user-entered series name, not a Phase 4 series engine. Journal/Series/
  Challenges/Stats tabs retain the approved Phase 1 preview shell.
- Genre is a nullable per-reading user choice; managing/deleting the full genre
  catalogue belongs to later Settings work. Unknown remains valid.
- Add with its selected intent and optional manual facts commits atomically with
  its commands; Book/Edition corrections also commit in one transaction. Failure
  rolls back the full operation. User-entered Manual Add genre is preserved for
  the user's reading; external genre categories cannot determine that override.
- No StoryGraph import, backup/restore, onboarding, notifications, AI, listening-time
  progress or future completion side effects. Challenge TBD content remains untouched.

Phase 2 Books Core is implemented and its required functional/visual acceptance
tests pass. CI #116 at the final implementation commit passes Swift tests, iOS build,
all four Books Core UI tests, evidence export, SQLite tests (including the Books
schema) and Supabase checks. Overall CI remains red because the retained foundation
audit and the separately documented historical QA-export landscape assertion remain
visible and unsuppressed. With no new Phase 2 regression identified, the implementation
is ready for human visual approval; acceptance remains required before merge.
No merge or Phase 3 work has been performed or authorized.
