# Phase 5 — Challenges

Branch: `codex/phase-5-challenges`; authoritative starting main: `61ef0cafc885a28d1d6b284abbda1dc8eb4d3e25`.

READY FOR HUMAN REVIEW. Implementation and targeted automated/self-visual validation are complete; human functional and visual approval remains pending. No merge or Phase 6 is authorized.

## Acceptance criteria

- Immutable yearly configuration; even=A, odd=B; 2027=B.
- Nine configured types; exact authoritative catalog strings and stable missing slots.
- Independent occupancy, explicit idempotent confirmation, >=70% reliable-evidence proposals, exact compact percentage, one best candidate, reject without reason, next best, material-evidence suppression.
- Manual selection without invented confidence; no implicit displacement.
- Seasonal/Monthly finish-month eligibility; city-only Around the World; Alphabet articles and two-per-Series constraint.
- ISO Monday–Sunday finish-date placement and same-week replacement; completion-only 100 numbered slots.
- Durable offline archive/decisions, owner-scoped additive migrations/outbox, shared Attention and independent Journal component/corrections.
- Light Standard, Dark Standard and Accessibility XXXL visual evidence; no old audit suppression.

## Unresolved catalog and technical boundaries

- Archetype B #10: TBD — DO NOT INFER; identity preserved.
- December B #2/#3: TBD — DO NOT INFER; Winter Sport remains #1.
- Reading Roulette: ten unavailable slots; catalog TBD — DO NOT INFER.
- 52 Weeks rewards: TBD; no XP invented.
- 100 Books rewards: TBD; no XP invented.
- Production semantic matcher and Ask Assistant provider/model remain unavailable injection boundaries. No fabricated analysis or automatic semantic confirmation.
- Full sync/restore, Quests, Gamification, Stats and notification delivery remain later phases.

The user explicitly approved preserving ISO week 53 as unconfigured and date-only finish ties without automatic selection. A manual same-week choice remains available for configured weeks. Finish dates are date-only; operational timestamps are not substituted for chronology.

Historical imported readings never generate automatic proposals, placements, notification or reward cascades. Explicit manual historical assignment remains user-authoritative where finish-date eligibility is known.

Unknown finish dates remain unknown. Explicit manual assignment can target an unscoped Challenge year chosen by the user, but Seasonal, Monthly and 52 Weeks still require an actual qualifying finish date. Alphabet uses title-based manual eligibility, not a manufactured semantic confidence score.

Existing Foundation findings remain visible and deferred to Phase 12. The historical 107 XCTest Dynamic Type findings remain unresolved; no responsible live element has been identified for those findings, instrumentation did not establish a false positive, and no finding has been suppressed. They remain an open accessibility risk requiring Phase 12 and manual native inspection. The mapped Phase 5 Assistant target correction does not resolve or reinterpret that history. No physical-device/VoiceOver certification is claimed.

## Validation

Validated implementation: `facbab551d8d206a7bf249b7702b8834f09b722c`, [candidate run 37458473321](https://github.com/angels00607/reading-companion/actions/runs/37458473321). Final packaging changes documentation/QA only; no duplicate native matrix is required.

| Validation | Result |
| --- | --- |
| Swift | PASS — 92 tests (66 existing + 9 domain + 17 repository) |
| SQLite | PASS — 27 tests (17 baseline + 3 Books + 7 Challenges) |
| Supabase/RLS | PASS — 80 assertions (67 existing + 13 Challenges) |
| iOS build | PASS |
| Challenges native acceptance | PASS — all 4 tests; xcresult records 0 issues |
| Journal, Series, Books Core regression stages | PASS |
| Font registration, included in Books Core | PASS — Manrope-Regular/Medium/SemiBold, PapernotesRegular, HelloBabyRegular |
| Light Standard / Dark Standard / Accessibility XXXL | PASS — native matrix and targeted screenshot self-review |

142 native PNG captures are retained in CI. The three final boards select 90 captures with source filenames, timestamps and SHA-256 hashes in the [capture index](qa/phase-5/capture-index.json). [Provenance and boards](qa/phase-5/README.md) identify the exact validated implementation and artifacts. Targeted final inspection covered 99%/70%, proposal actions, selected manual Book/date and replacement controls at XXXL. No new functional failure or visual regression was found; vertical expansion, wrapping and scrolling remain expected.

The overall Foundation audit is not certified green: historical 107/148 findings remain visible and deferred to Phase 12/manual native inspection, without suppression or a false-positive claim. This packaging does not change application code or existing tests.

The first CI attempt exposed duplicate-title test fixtures in two ISO-week cases. Distinct fictional fixture titles corrected those setup failures; duplicate detection and all prior assertions remain intact. Later inspection corrected December's unavailable-slot display to its month-local #2/#3 identities. No missing catalog content was supplied.

Run `37438742316` reported a 22-point accessible frame during the review flow and failed manual selection where row identifiers overrode nested link identifiers. Shared Challenge links received explicit vertical padding/plain button style and the redundant row identifier was removed. The later activity-level diagnosis below identifies the remaining small control precisely. Native assertions still require 44×44 points. The test scroll helper locates lazily rendered controls before asserting existence, without excluding controls or changing target thresholds. Screenshot inspection also identified vertical dividers in overview/prompt rows; explicit one-point horizontal separators replace them. Archive labels now read the persisted snapshot version directly.

The same run exposed a pre-existing Series acceptance fixture ordering problem: wall-clock seed timestamps can put the required Moonlit Archive row outside the lazy viewport, although its stored Series is present. Only the fixture timestamps are made deterministic, retaining the reviewed first-row hierarchy; production sorting, Series screens and every old test assertion are unchanged. Captured month labels now use the current locale rather than root-locale `M01` strings, and Challenge years render without thousands grouping.

Run `37443973783` at `f83c56d5d205f94eef02f65441deaf7716e033f4` passes the complete visual matrix, manual/same-week replacement and rejection flow. Its one remaining assertion is mapped by the xcresult issue timestamp and adjacent activity records to `challenges.assistant`, not the Review Matches navigation link: Ask Assistant reports a 22-point accessible height. The shared tertiary button reserves 48 points but its transparent label did not define the full interactive shape. A rectangle content shape now covers the existing label frame without changing appearance or thresholds. Matrix tests also assert the Assistant target in all three modes; the final candidate passes these assertions in all three modes. Native archive navigation now preserves its scroll container. An intermediate Swift 6 isolation compile failure was corrected by annotating the shared Challenge link helper `@MainActor`; it was not an accessibility failure.

Self-review of that run's XXXL screenshots found a test-capture limitation: `isHittable` alone did not ensure the requested percentage/actions were inside the captured viewport. The scroll helper now additionally requires the entire target frame inside the visible scroll region. Captures include selected manual/same-week books, confirmed labels and the truthful Assistant unavailable state in all modes. No accessibility finding or threshold was removed.

Run `37447165569` at `6e927b2d27f12aec596a122a573a50e663dbdbed` confirms the Assistant target correction: confirmation, rejection and manual/same-week tests pass, and the matrix's Assistant size assertions pass in all modes. Three capture-helper assertions still fail: two fully visible 87.5-point unavailable messages at y=379.5 were incorrectly required to start in the viewport's upper half, and a one-direction scroll overshot the Archetype gap. Short messages now require their full frame to be visible; overflowing text requires its beginning to be visible and is captured across scroll positions. Missing slots use the same bidirectional fully-visible helper as controls. All 44-point assertions remain intact. An additional compact PNG/manifest/result-database artifact makes review evidence downloadable; the original complete xcresult and attachments, including recordings and failures, remain uploaded unchanged.

## Implementation notes

The catalog resource is copied from `CHALLENGE_CATALOG.md`, retaining Archetype B’s 21 numbered slots including the gap. Generic unavailable UI preserves slot keys; no internal TBD instructions are presented as prompt content.

Snapshots reuse Foundation tables. SQLite v6 and Supabase `202610060001_challenges.sql` preserve all old migrations/data, add analysis/rejection provenance and a general persistent `attention_items` table using the existing category model. Raw cloud mutations remain denied pending Phase 9 command transport.

Confirmed Challenge assignments make only the Challenges Journal component ready. Copied payload changes enter existing `journal_corrections`; Book Review readiness is independent. No second Journal Session is introduced.

Reliable stored semantic candidates retain exact integer confidence and source/reference/explanation/fingerprint. Only the best eligible free candidate at or above 70% is exposed. Confirm is explicit/idempotent. Reject takes no reason and suppresses the canonical Book/prompt/evidence identity; a material evidence revision can propose again while retiring superseded unconfirmed candidates. Confirmed assignments are never replaced by a higher score.

52 Weeks uses ISO week-year and calendar finish dates. Date-only ties have no arbitrary ordering. Explicit same-week replacement is permitted; cross-week borrowing is rejected. 100 Books fills completion slots without semantic analysis or confidence. Explicit clears remain cleared, rather than being silently repopulated. Date corrections preserve confirmed decisions and create eligibility Attention where needed.

Every stored decision uses owner-scoped SQLite transactions and the existing durable outbox. Archive reads the stored configuration, not the current catalog. Production cloud command transport remains denied until Phase 9; this phase does not deploy a production database or claim sync conflict resolution.

## Acceptance evidence map

| Flow | Coverage |
| --- | --- |
| A — Rotation/archive | 2026=A, 2027=B, 2028=A domain/native fixtures; snapshot serialization and persisted offline reopen/immutable guards after catalog evolution |
| B — Proposal/Confirm | Native exact 99% proposal, unavailable Assistant without confirmation, explicit Confirm; repository idempotence/occupied exclusion/higher-score non-replacement |
| C — Reject/next best | Native 99 → 88 → 70 → truthful empty state without reason; repository repeated-evidence suppression and material-evidence renewal |
| D — Manual | Native eligible book/free prompt selection; repository confirms with nil confidence and rejects displacement |
| E — Independence | Native Tropes → Around the World → Monthly candidates for the same completed Book; owner-scoped repository occupancy assertions |
| F — 52 Weeks | Native first finish and explicit same-week replacement; repository Monday/Sunday, ISO year, cross-week rejection, week 53 and date-only ties |
| G — Missing content | Native Archetype B #10, December B #2 and Roulette unavailable states; domain tests explicitly cover both December gaps and retained identities |

DEBUG-only fictional fixtures demonstrate the review contract; they are not production book metadata or evidence. Human visual approval remains pending. The native matrix captures overview, all nine types, archive, rotation, 99/88/70 proposals, rejection/empty, missing content, manual selection/confirmation and same-week replacement in Light Standard, Dark Standard and Light Accessibility XXXL.

Final candidate `37458473321` passes all four Challenges tests, including the corrected capture-helper matrix. Acceptance flows A–G below are covered by the combined native/domain/repository evidence. The final boards are prepared for human review, not human approval or physical-device/VoiceOver certification. PR #6 remains unmerged; Phase 6 has not started.
