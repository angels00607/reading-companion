# Phase 7 — Profile & Gamification

## Status and review boundary

**READY FOR HUMAN FUNCTIONAL AND VISUAL REVIEW.** The five production blockers
are complete. Human approval is pending; PR #8 is not merged. Phase 8 has not
started. Main remains the approved Phase 6 merge
`1b5e6809db4ec4f8062eadbcb50260662d1636cd`.

Validated application: `20de2d471540ccafa6ade17f542abc8e208f26ab`.
Subsequent acceptance-test and documentation/QA commits do not change the
application, migrations, functional typography or prior-phase UI.

## Completed production blockers

1. Normal startup, Home and Quest Center generate and use persisted current
   2 Daily / 3 Weekly / 3 Monthly slots without seeds. Actual reading, explicit
   reading-day, Journal and manual organization commands advance eligible goals.
   History, creation baselines, completion and once-only XP survive reopening.
2. Local-day, ISO Monday–Sunday week and calendar-month boundaries govern current
   sets. Cooldown uses elapsed periods, including rejected templates, without a
   fallback bypass. Selected-slot rerolls enforce one Daily/day, one Weekly/week,
   none Monthly, persist the quota and exclude immediate return. Targets use only
   genuine available history and conservative remaining-day caps. Legacy history
   informs targets without replaying events, progress or ordinary XP.
3. All five existing catalog Achievement conditions evaluate automatically from
   genuine nonhistorical facts and permanent awards. Unlocks and XP are monotonic
   and idempotent. Import, DNF completion, missing dates and percentage-to-pages
   conversion do not manufacture activity. Errors preserve Progress unknown.
4. Collection provides ephemeral preview, unchanged Cancel and validated Apply,
   persisted across process reopening. Known keys, actual level eligibility and
   one equipped item/category are enforced. Themes modify decorative Passport
   surfaces only; preset categories remain individually editable. Essential
   reading features have no level gate. Configured Featured selections are
   exactly three genuinely unlocked Achievements.
5. Production acceptance A–J covers real repository commands, durable reopening,
   controlled calendar boundaries and live native interactions. Visual replay
   uses those same commands, never assigned Quest/Achievement progress or arbitrary
   XP. The final boards were produced only after the functional blockers passed.

Detailed mechanics: [PHASE_7_LIFECYCLE.md](PHASE_7_LIFECYCLE.md).

## Additive migrations

- Existing Phase 7 foundations: `local_v8.sql` and
  `202610070001_profile_gamification.sql`.
- This completion adds `local_v9.sql` and
  `202610070002_live_gamification.sql`: immutable owner-scoped activity,
  Quest slot/creation-baseline metadata, private RLS and cosmetic key/level guards.
- Earlier migrations and the immutable permanent XP ledger are preserved. No
  migration backfills historical imports or ordinary completion/Journal XP.
- Upgrade validation preserves existing v8 records; cross-owner access, mutation
  of immutable facts and invalid cosmetic writes are tested.

## Validation evidence

| Check | Result and provenance |
| --- | --- |
| Full Swift regression | **139 passed**, including **23 Phase 7 tests**, complete production matrix and final test-only runs |
| SQLite migrations/invariants | **42 passed**: 17 Foundation, 3 Books, 7 Challenges, 6 Stats, 9 Gamification; candidate run below |
| Supabase migrations/RLS | **121 passed**, 10 files, including 14 new lifecycle assertions; candidate run below |
| iOS Simulator build | **PASS** on production and final Passport application runs |
| Native font registration | **PASS**, unchanged approved resources, candidate run |
| Phase 7 native acceptance | **3 passed**: clean production launch, persistent cosmetic/theme Cancel/Apply/reopen, and 15-route three-mode matrix |
| Light Standard / Dark Standard / Light Accessibility XXXL | **PASS**, production matrix plus targeted final Passport correction; screenshots inspected |
| Books / Challenges native regression | **4 passed**, candidate run |
| Foundation default / largest-size audits | **FAIL — known retained Foundation accessibility findings**; retained findings, no suppression or threshold change |

The single complete candidate is
[run 37596754723](https://github.com/angels00607/reading-companion/actions/runs/37596754723)
at `fc235e11bae15c925d61e0ef02e53da7e3e99f9c`.
The final genuine-history adapter is verified by full Swift regression, iOS build
and Phase 7 native acceptance in
[run 37599213808](https://github.com/angels00607/reading-companion/actions/runs/37599213808)
at `b49d3e500e25c29c1332baa30a86d4f67094d974`. Unchanged migrations, fonts and
earlier native regression reuse the complete candidate's evidence. The
acceptance-test-only head `cd59bdb741de30320e0a5b770a1c8640462366e2` explicitly
verifies reopened reroll quotas, monthly history and the 499/500/501 boundary:
full 139 Swift tests and the identical iOS application build pass in
[run 37599619408](https://github.com/angels00607/reading-companion/actions/runs/37599619408).
No second complete native/Foundation cycle was launched. Final documentation/QA
packaging skips identical CI.

Font registration preserves `Manrope-Regular`, `Manrope-Medium`,
`Manrope-SemiBold`, `PapernotesRegular` and `HelloBabyRegular`. Manrope is the
functional typeface. Source and bundled font binaries were not changed.

## Production acceptance A–J

| Flow | Result | Evidence |
| --- | --- | --- |
| A — clean launch | PASS | Normal unseeded 2/3/3 repository generation and isolated persistent native launch |
| B — live completion/once-only XP/reopen | PASS | Real progress command, stable observation replay and file-backed reopen |
| C — period rollover/history | PASS | Controlled local day, ISO week and calendar month rollover; history retained |
| D — selected reroll/quota/reopen | PASS | Untouched sibling slot, same-slot replacement, current-period quota, no Monthly reroll or immediate return; file-backed reopen |
| E — elapsed cooldown | PASS | Real calendar distances and production generation, independent of insertion order |
| F — automatic Achievement/once-only XP/reopen | PASS | Real add/start/update/confirm/copy commands, five catalog conditions, award-key deduplication and file-backed reopen |
| G — 500 XP/cosmetics-only gates | PASS | Exact 499/500/501 boundary, real finish-based level unlock and accessible Library |
| H — preview/Cancel/Apply/reopen | PASS | Actual native preview with unchanged Cancel, validated Apply, process reopen; repository persistence |
| I — locked/unknown rejection | PASS | Locked native control, atomic repository rejection, unchanged equipment and storage guards |
| J — theme boundary/persistence | PASS | Actual native theme preview/Cancel/Apply/reopen in the existing shell; decorative-token implementation and individually editable categories |

Separate tests verify percentage, import, unresolved-history and DNF exclusions,
known-date target adaptation, no fake sessions, conservative late-period day
targets and preservation of distinct Stats records without duplicate day credit.

## Final visual evidence

[Review index](qa/phase7/README.md),
[Light Standard](qa/phase7/Light-Standard.png),
[Dark Standard](qa/phase7/Dark-Standard.png),
[Accessibility XXXL](qa/phase7/Accessibility-XXXL.png),
[per-capture provenance/checksums](qa/phase7/PROVENANCE.json).

One final set uses 57 selected real native captures on iPhone SE (3rd generation),
19 panels per board. It includes Passport identity/XP, Featured selections,
current cadence sets, consumed reroll, actual progress/completion, Achievement
conditions, locked/unlocked Collection, Theme Preview/Apply and a live Level Up.
Native content is unmodified; only contact-sheet labels/frame are added.

Mapped new Phase 7 XXXL word compression and Passport name/XP number wrapping
were corrected through vertical expansion at accessibility sizes. Standard
hierarchy, five tabs, 44-point targets, Manrope, appearance modes and semantics
remain intact. The native preview-scrolling harness fault was mapped to dismissal
of the sheet and corrected by scrolling the actual active surface; no finding or
threshold was weakened. The final inspection also mapped four malformed favorite separators (`Â·`).
Only these Passport strings were corrected at the validated application SHA.
[Run 37601146010](https://github.com/angels00607/reading-companion/actions/runs/37601146010)
passes the iOS build and one targeted native test across all three modes, checking
the exact corrected label. Unit/domain, schema, fonts and unrelated routes were
unchanged, so their passed evidence is reused. The final boards replace 12
Passport captures from this run and retain 48 unchanged-route captures from the
complete production matrix; each source SHA/run/artifact is explicit in provenance.
All final panels were inspected: full-width XXXL identity/XP, corrected favorite
labels, truthful activity progress, distinct locks, preview/applied surfaces and
scrolling expansion are preserved. No new unresolved Phase 7 functional or visual
problem was detected.

## Diagnostic history and limitations

The previous NOT READY status is preserved verbatim in
[PHASE_7_DIAGNOSTIC_HISTORY.md](PHASE_7_DIAGNOSTIC_HISTORY.md). Its fixture boards
remain available at historical head `902091b68c4bc483e3a610cc79d95a158a49e124`;
they are not substituted for production acceptance. Runs `37593346065` and
`37595099765` retain the native replay/harness evidence and correction history.

- **107 XCTest Dynamic Type findings remain unresolved; no responsible live
  element has been identified; instrumentation did not establish a false
  positive; no finding has been suppressed.** The later **148 Foundation findings**
  and their complete documented history remain visible and deferred. This is an
  open accessibility risk requiring Phase 12/manual native inspection; it was
  not reinvestigated during this completion. Existing accessibility tests and
  thresholds are retained, so the full candidate is not globally green.
- Physical-device/spoken VoiceOver and comprehensive accessibility certification
  remain Phase 12 work. The native evidence uses macOS CI, not the Windows host.
  The requested final matrix is Light Standard / Dark Standard / Light XXXL;
  no Dark XXXL certification is claimed.
- Session templates remain ineligible without a genuine session recorder.
  Missing activity/date data is not reconstructed. Historical imports never
  replay live awards or completion cascades.
- Full cloud command transport/multi-device conflict integration and executable
  backup/restore remain later-phase work; owner RLS and additive sync foundations
  are present, not claimed as a completed production cloud service.
- All existing Challenge content/reward, week-53 and same-date tie TBDs remain
  exactly as documented. No missing catalog content or future requirement is
  inferred. No new product decision requiring approval was introduced.
- Human functional and visual approval remains pending. PR #8 is ready for
  review only; no merge or Phase 8 work is authorized by this status.
