# Phase 6 — Stats

Branch `codex/phase-6-stats`, starting from approved main `2da5ed96cc62fe9d9bee91cd498602ec23b065b4`. Phase 6 only; no merge or Phase 7. Implementation is undergoing targeted tests and native self-QA; human approval is not claimed.

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

Light Standard, Dark Standard and Accessibility XXXL evidence and final candidate results are pending. Native fixtures are explicit fictional QA data, not production analysis or inferred history. Human review boards will identify the exact tested application SHA.

## Accessibility and retained limitations

Manrope, the five tabs, shared semantic Light/Dark/System tokens, 44-point targets and selected-state labels are preserved. XXXL reflows vertically and scrolls; no essential statistic relies on chart geometry or color. Physical-device/spoken VoiceOver certification remains Phase 12 work.

Existing Foundation findings and all diagnostic history in PHASE_0_STATUS through PHASE_5_STATUS remain untouched: historical 107 nil-element Dynamic Type findings and the documented 148 Foundation failures remain unresolved and deferred; instrumentation did not establish a false positive. No audit/test/threshold is suppressed, removed or weakened. Unchanged historical findings are not re-investigated in Phase 6. Final CI retains their reporting separately from Stats acceptance.

Existing Challenge content/rewards TBDs, AI boundaries, provider limitations, auth/sync/restore and later phases remain exactly as documented. Stats does not implement gamification, rewards, Quests, notifications, imports expansion or playback. Daily history cannot be recovered when absent; physical five-year volume placement is user-selected rather than inferred.
