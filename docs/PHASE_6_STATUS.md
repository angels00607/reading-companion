# Phase 6 — Stats

READY FOR HUMAN REVIEW. Branch `codex/phase-6-stats`, starting from approved main `2da5ed96cc62fe9d9bee91cd498602ec23b065b4`. Phase 6 implementation, automated acceptance and native visual self-review are complete. Human functional/visual approval remains pending. PR #7 is unmerged; Phase 7 has not started.

## Aggregation contract

- Books Read counts every non-deleted completed ReadingInstance attached to a non-deleted Book. Rereads count independently; no canonical Book is duplicated. Currently Reading and DNF never count as completions. DNF is excluded from every metric, candidate pool and chart; genuine retained progress is untouched.
- Month/year/physical five-year attribution uses the stored Gregorian finish date only. Unknown finish dates contribute to Lifetime Books Read but cannot be placed in a month/year/chart. No import, creation, review, copied date or operational timestamp is substituted.
- Pages Read uses signed deltas of genuine original Page-mode observations with a known prior position and resolved review state. Percentage, edition denominators and physical Book Review page counts are never converted into reading observations. Corrections adjust the recorded subtotal rather than awarding repeated pages. A negative subtotal cannot establish pages read and remains unknown. No eligible readings means a known zero recorded subtotal; eligible readings without genuine observations mean Unknown. Known subtotals survive mixed coverage.
- Page coverage is complete for a reading only when the original observation sequence begins at genuine page zero, every observation supplies a resolved Page delta, and the reading remains in Page mode. Other sequences have partial coverage, even when a subtotal is available. This measures observed pages, not an inferred full-book total. The UI states the number of readings with evidence and shows “recorded” for partial sums.
- Reading Days uses distinct explicitly recorded calendar activity dates, including eligible ongoing readings, attributed to the activity date itself. Repeated records and multiple readings on one date count once. DNF activity is excluded. Start/finish intervals, progress submission timestamps, imported history and page totals do not generate days. Known dates are a recorded minimum/partial history; absence of records remains Unknown when eligible readings exist. Only no eligible history at all establishes zero. This phase supplies the validated explicit-date repository boundary; it does not add a timer/session workflow or infer activity automatically from progress updates.
- Average rating includes only genuine whole stars 1–5. No Rating and unknown ratings are excluded and counted separately. With no rated readings, the average is Unavailable. Imported half-stars are not rounded.
- One stored Primary Genre per eligible ReadingInstance; no provider list/first genre fallback. Unknown stays a labelled category. Existing Reading History is the manual date/rating/genre/Format correction path.
- Formats use only the explicitly user-chosen ReadingInstance Journal Format: Paperback, Hardcover, Ebook, Audiobook. Unknown remains labelled. No Edition/provider/ISBN/AI/previous-reading inference occurs; rereads can have different Formats.

## Charts and physical Journal

One restrained horizontal bar language exposes direct textual and accessibility values. Month shows genuine completion dates; Year shows genuine monthly completions; Lifetime shows calendar-year completions. These are completion charts, not reconstructed daily page histories. Undated completions are explicitly omitted: positive known counts are recorded subtotals and an empty period is Unknown when undated history prevents establishing zero. No rainbow categories or color-only values.

Journal View is a separate copy-preparation presentation sharing exactly the same aggregation and manual selections. Monthly maps to the documented double page; Yearly to two pages. Lifetime offers a user-chosen five-year window plus individual yearly rows; it does not invent physical volume placement or archive a volume. Undated history remains unplaced. No duplicate entry, competing winner, copied-state system or second Journal Session is introduced.

## Manual choices and persistence

All eligible completed readings in the chosen month are available; no rating algorithm chooses a winner. Selection/edit/clear is explicit and durable. The annual candidate pool consists of eligible selected monthly Best Books in that year. Annual selection is also manual; changing a monthly selection never silently replaces it. A later date/status/deletion correction that invalidates a choice preserves the stored ReadingInstance reference and presents “Review your choice”, including when the Book is unavailable. Ratings/metadata never change choices automatically.

Additive SQLite `local_v7.sql` and Supabase `202610060002_stats.sql` add owner-scoped `best_book_selections` and explicit `reading_activity_dates`. Old migrations/data are unchanged. Choices use revision checks and commit with the durable outbox; explicit activity records deduplicate by reading/date. Cloud tables have owner-only SELECT RLS and deny raw anonymous/authenticated mutation. Unsupported command transport stays closed until Phase 9; no deployment/full sync/backup/restore is implemented.

Derived aggregates are recomputed from one transactionally consistent local snapshot, using four batched queries and grouped observations/activity. There is no per-Book query, repeated provider call or persisted aggregate cache. Timeline grouping is linear in readings plus displayed periods; readings/observations load once per snapshot. Local changes reload through the existing model version and on entering Stats. No network is required.

## Validation and review evidence

Targeted tests cover Month/Year/Lifetime, unknown dates, DNF, rereads, genuine/percentage/unknown/zero/partial pages, explicit day deduplication/attribution, No Rating, Primary Genres, user-only Formats, manual persisted choices and corrections, five-year Journal projection, owner isolation, outbox atomicity and reopen. All Phase 0–5 tests remain present and unchanged.

Native acceptance flows:

| Flow | Evidence |
| --- | --- |
| A — Month | 3 completed readings, 220 recorded pages, 2 recorded days, genres, Formats, chart and explicit Best Book |
| B — Reread | One canonical Book finished in 2026 and 2027, independent period counts, Lifetime counts both |
| C — Incomplete history | Historical/percentage-only completion counts; Pages and Reading Days remain unknown/partial |
| D — Rating | 5 + 3 + No Rating yields 4.0 |
| E — Best Book | No automatic monthly/yearly choice; explicit selection, durable repository reopen, monthly annual pool |
| F — Journal | Separate Monthly/Yearly/five-year Lifetime presentation; shared truth and manual decisions |

Final validated application: `04b3d44ef059e09a6362fab06e2fdaf5ce8953b8`. [Candidate run 37481241019](https://github.com/angels00607/reading-companion/actions/runs/37481241019) is the single full final candidate. Final packaging changes only this status document and QA boards/index/provenance; it does not change application source, tests, migrations or build configuration, and does not repeat the native matrix.

| Validation | Result |
| --- | --- |
| Full Swift regression | PASS — 116 tests: 92 existing + 12 Stats domain + 12 Stats repository; zero failures |
| SQLite migrations/schema | PASS — 33 tests: 17 baseline + 3 Books + 7 Challenges + 6 Stats |
| Supabase migrations/RLS | PASS — 92 assertions in 8 files, including the existing seeded upgrade and 12 Stats assertions |
| iOS simulator build | PASS — native Xcode build |
| Font registration | PASS — all five approved bundled fonts registered without fallback |
| Final Stats native acceptance | PASS — four tests: Month/manual-year choice, reread/unknown/Journal reuse, primary values in three modes, real five-tab shell in three modes |
| Books/Challenges functional regression | PASS — official Books acceptance and three Challenges functional flows |
| Corrected Stats visual matrix | PASS — all four Stats UI tests in self-QA run 37477717630, including the complete Light/Dark/XXXL matrix |
| Historical Foundation default and largest-size audits | FAIL — retained contrast/Dynamic Type audit findings; no suppression, threshold change or renewed diagnostic investigation |

The candidate's Stats/font xcresult database contains five successful tests and zero issues. The corrected self-QA Stats database also contains zero issues. The overall native CI job remains red because both retained Foundation audit stages fail; it is not certified globally green.

Native font metadata/registration confirms `Manrope-Regular`, `Manrope-Medium`, `Manrope-SemiBold` (family Manrope), `PapernotesRegular` (family Papernotes) and `HelloBabyRegular` (family Hello Baby). Stats uses functional Manrope; no font assets, original source fonts or approved Journal typography were modified.

Flows A–F above pass through combined native/domain/repository evidence. Flow C's final fictional stored reading is explicitly historical and Percentage-only, completed authoritatively without page/activity observations or retroactive live events. A dedicated repository test verifies those flags and unknown metrics; the final native flow verifies its presentation. Manual selection tests include durable offline reopen, stale revisions, invalid-choice preservation and rollback when outbox insertion fails.

[Review boards and provenance](qa/phase-6/README.md): [Light Standard](qa/phase-6/board-light-standard.png), [Dark Standard](qa/phase-6/board-dark-standard.png), [Accessibility XXXL](qa/phase-6/board-light-accessibility-xxxl.png). There are 40 panels per board, 120 selected native captures from 266 unique named captures on iPhone SE (3rd generation). Each selected capture records its run, application SHA, artifact, original filename, timestamp and SHA-256.

The full corrected matrix was captured at `46d5f2dc14427501c76738e3d70e59caef913d2c`; the final candidate supplies primary-number and actual-shell captures in all three modes. Production Stats UI, aggregation, migrations and fonts are identical between these applications. Only the DEBUG historical fixture, tests and CI selection differ; provenance explicitly distinguishes both sources.

Self-review corrected the primary number from 52 points to the approved 36-point Display role, a malformed apostrophe in the long-genre QA fixture and singular undated-history wording. Full Dynamic Type scaling remains enabled. All final boards and targeted full-resolution XXXL primary values were inspected: open editorial metrics, restrained labelled bars, manual Book moments, explicit Unknown/recorded coverage, readable Dark hierarchy and scrolling long titles/genres are preserved. Checked foreground/background token combinations meet 4.5:1, with a minimum ratio of 5.04:1. No new unresolved Stats functional or visual problem was detected. Fictional covers use the established neutral fallback when no artwork is supplied.

Native self-QA artifacts: `11421331192` (complete xcresult/attachments) and `11421530945` (compact evidence), run `37477717630`. Final candidate artifacts: `11421732305` (complete Stats/font xcresult), `11422156243` (compact evidence) and `11423210185` (original regression/Foundation results). Native fixtures are explicit fictional QA data, not production analysis or inferred history. Human approval is not claimed.

## Accessibility and retained limitations

Manrope, the five tabs, shared semantic Light/Dark/System tokens, 44-point targets and selected-state labels are preserved. XXXL reflows vertically and scrolls; no essential statistic relies on chart geometry or color. Physical-device/spoken VoiceOver certification remains Phase 12 work.

Existing Foundation findings and all diagnostic history in PHASE_0_STATUS through PHASE_5_STATUS remain untouched: historical 107 nil-element Dynamic Type findings and the documented 148 Foundation failures remain unresolved and deferred. No responsible live element has been identified; instrumentation did not establish a false positive. No finding, audit, test or threshold is suppressed, removed or weakened. This remains an open accessibility risk requiring Phase 12/manual native inspection. Unchanged historical findings were not re-investigated in Phase 6. Final CI retains their reporting separately from Stats acceptance.

Existing Challenge content/rewards TBDs, AI boundaries, provider limitations, auth/sync/restore and later phases remain exactly as documented. Stats does not implement gamification, rewards, Quests, notifications, imports expansion or playback. Daily history cannot be recovered when absent; physical five-year volume placement is user-selected rather than inferred.
