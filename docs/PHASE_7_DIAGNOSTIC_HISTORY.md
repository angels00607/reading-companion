# Phase 7 — Profile & Gamification

## Status

**NOT READY FOR HUMAN FUNCTIONAL / VISUAL ACCEPTANCE.**

Phase 6 remains approved and merged at `1b5e6809db4ec4f8062eadbcb50260662d1636cd`.
The existing Phase 7 branch is a partial implementation candidate. The continuation
verified its existing evidence and corrected two mapped review-fixture defects.
No PR has been merged. Phase 8 has not started.

## Existing foundations — not complete production journeys

- Private Reader Passport with avatar/frame, name, Reading History Since, level/XP,
  Books/Pages/Achievements, favorites and exactly three configurable Featured Achievements.
- Central `GamificationBalance` catalog with the locked V1 values and unlimited
  500-XP levels. Levels unlock cosmetics only.
- Permanent, non-negative, append-only XP ledger with stable semantic award-key
  idempotency and immutable source metadata.
- Live Finish Book, Book Review Copied and proposal-confirmation award hooks.
- Activity-only Quest templates, adaptive-target helper and Quest persistence APIs.
  Production generation, live activity integration, period filtering and actual
  cooldown / reroll quota enforcement remain incomplete; see blockers below.
- All Achievements visible with explicit locked conditions/progress, one-time unlocks,
  configurable 0 or 50–250 XP, and three Featured selections.
- Collection categories and Locked/Unlocked/Equipped display / storage. Theme preview
  and interactive equipment are not implemented. The existing Level Up display is static.
  No currency, rarity, loot, offer or paywall model.
- Home can display one supplied Quest; Profile links to Quest Center, Achievements and Collection.

The prior status overstated production coverage. Stored fixtures and helper APIs
do not establish completed production Quest / Achievement / customization journeys.

## Data and migration

- Local additive migration `local_v8.sql`.
- Supabase additive migration `202610070001_profile_gamification.sql` with owner RLS.
- Migration creates no XP, Quest, Achievement or cosmetic history from existing books.
- Existing immutable Phase 0 XP storage remains authoritative and is not rewritten.

## Validation state

Candidate [run 37521560931](https://github.com/angels00607/reading-companion/actions/runs/37521560931)
on `4212f17df261b4813361f14bec2996a8dd04f5e3`:

- Full Swift regression: **127 passed**, including **11 Phase 7 tests**.
- iOS Simulator build and approved font registration: **passed**.
- SQLite: **38 passed** (17 Foundation, 3 Books, 7 Challenges, 6 Stats, 5 Gamification).
- Supabase / RLS: **107 passed**, 9 test files.
- Books / Challenges native functional regression: **4 passed**.
- Phase 7 fixture acceptance: **failed**, as mapped below. It did not exercise
  complete production Quest / Achievement / customization flows.
- Foundation default / accessibility stages retain the documented open findings.

Correction [run 37587259525](https://github.com/angels00607/reading-companion/actions/runs/37587259525)
on `f12fbc25654011154ab5fe480ea0976ceda6033b`:

- Targeted Phase 7 Swift tests and iOS build: **passed**.
- Light Standard / Dark Standard / Accessibility XXXL fixture acceptance: **passed**.
- Screenshot inspection confirms that the seeded Quests and Achievements render.
  It also exposed compressed words in horizontal Quest / Achievement / Collection
  rows at XXXL and a grouped year (`2,020`) in the Passport.
- Database commands, schema and font resources are unchanged by this correction;
  successful candidate evidence is reused. No duplicate full matrix was launched.
- Native validation uses macOS CI. The current workstation is Windows and cannot
  perform native iOS simulator / physical-device / VoiceOver certification.

## Mapped fixture defects and correction

- Candidate run `37521560931` failed 12 screen-presence assertions. Its retained
  XCTest snapshot identifies `phase7.quests` as type **46 (ScrollView)**, whereas
  the test queried `otherElements`. The same construction is used for Passport,
  Achievements and Collection. Reward retains its existing celebration query.
- The Quest screenshot was genuinely empty: `ProfileVisualQA` constructed the
  state-owning `QuestCenter` with an empty array before loading its fixture. The
  destination retained that initial array despite the later parent update.
- Correction `f12fbc25654011154ab5fe480ea0976ceda6033b` loads repository data before
  constructing destinations, queries actual ScrollViews and adds explicit seeded
  Quest / Achievement-content assertions. No audit finding or threshold is weakened.
- Original logs / attachments remain diagnostic evidence. The original empty Quest
  capture must not be presented as an acceptable final visual board.

## Targeted visual correction

`d6b455483b353cb9560cc8e96eb68f0352131628` stacks the three Phase 7 card/row
types vertically at accessibility sizes and displays the reading-history year
without number grouping. Standard-size hierarchy, Manrope, labels, semantics,
touch targets, appearance tokens and navigation are preserved.

[Run 37588608227](https://github.com/angels00607/reading-companion/actions/runs/37588608227)
validates this UI correction using the targeted Phase 7 Swift / iOS / fixture
matrix. **Passed:** 11 targeted Swift tests, iOS build and the single XCTest
fixture-acceptance test across five routes in Light Standard, Dark Standard and
Light Accessibility XXXL. All 27 named captures were inspected through the
three [diagnostic boards](qa/phase7/README.md). The identified compressed words
now have full-width text space and the Passport year is `2020`.
No database code or earlier-phase UI was changed. The repeated targeted UI pass
is justified by the mapped new Phase 7 reflow issue, rather than a redundant full
regression or Foundation audit cycle.

Boards are diagnostic candidate evidence, not approval of incomplete production
flows. Source application SHA, run, artifact, device, filenames, timestamps and
checksums are recorded in [PROVENANCE.json](qa/phase7/PROVENANCE.json). Final
documentation / QA packaging does not modify application code and requires no
new native matrix.

## Remaining Phase 7 functional blockers

1. **Production Quest lifecycle:** candidate generation is called by the fictional
   QA seed and reroll UI, not normal startup or live activity. No production caller
   advances Quest progress from reading / Journal events. Clean normal launches
   therefore have no generated Quests.
2. **Periods / cooldown / rerolls:** UI reads all persisted periods; the used-reroll
   check is not scoped to the current day/week. `cooldownPeriods` is declared but
   the helper excludes the last 12 rows instead of evaluating elapsed periods.
   Daily frequency targets can exceed one day when given a session median above one,
   conflicting with the non-impossible-Quest rule.
3. **Automatic Achievements:** award hooks do not update or evaluate conditions.
   The only current non-test `saveAchievementProgress` caller is the fictional seed.
4. **Customization:** Collection rows have no equip or preview action. There is no
   theme-preview / cancel / apply journey. The repository accepts a catalog key
   without verifying its unlock level or enforcing one equipped item per category.
5. **Acceptance coverage:** screenshots / presence assertions do not verify live
   Quest completion, rollover, quota enforcement, automatic unlocks or equipment
   persistence. These require targeted implementation and acceptance coverage.

These are Phase 7 implementation / validation gaps, not deferred Phase 12 findings.
Passing existing helper / migration tests cannot establish Phase 7 completion.

## Deliberate limitations / later work

- Phase 7 does not replay historical imports and does not integrate Phase 8 import events.
- Physical-device and VoiceOver certification remain Phase 12 work.
- Foundation history remains intact: **107 unresolved Dynamic Type findings**, no
  mapped responsible live element, and instrumentation did not establish a false
  positive. The later **148 Foundation findings** remain visible and deferred as
  documented. No finding is suppressed by this continuation.
- Missing Challenge content and reward TBDs remain exactly as documented. No content,
  historical XP, import behavior or backup behavior is inferred.
- Human Visual QA is not yet approved for Phase 7.
- The V1 catalogs are deliberately small, stable and configurable; adding future catalog
  content must preserve the locked philosophy and does not alter the Phase 7 data model.
