# Phase 7 — Profile & Gamification

## Status

Implementation candidate prepared from remote main `1b5e6809db4ec4f8062eadbcb50260662d1636cd`.
Human Visual QA is not yet approved. Phase 8 has not started.

## Implemented

- Private Reader Passport with avatar/frame, name, Reading History Since, level/XP,
  Books/Pages/Achievements, favorites and exactly three configurable Featured Achievements.
- Central `GamificationBalance` catalog with the locked V1 values and unlimited
  500-XP levels. Levels unlock cosmetics only.
- Permanent, non-negative, append-only XP ledger with stable semantic award-key
  idempotency and immutable source metadata.
- Activity-only Daily/Weekly/Monthly Quest catalog and 2/3/3 active volume,
  conservative median-based targets, caps, cooldown history and persisted free rerolls.
- All Achievements visible with explicit locked conditions/progress, one-time unlocks,
  configurable 0 or 50–250 XP, and three Featured selections.
- Collection categories and Locked/Unlocked/Equipped states, theme preset preview and
  restrained reward/Level Up treatment. No currency, rarity, loot, offer or paywall model.
- Home surfaces one primary Quest; Profile links to Quest Center, Achievements and Collection.

## Data and migration

- Local additive migration `local_v8.sql`.
- Supabase additive migration `202610070001_profile_gamification.sql` with owner RLS.
- Migration creates no XP, Quest, Achievement or cosmetic history from existing books.
- Existing immutable Phase 0 XP storage remains authoritative and is not rewritten.

## Validation state

- Swift package build: passed locally.
- SQLite Phase 7 migration/invariant tests: 5 passed locally.
- Existing SQLite suites: 33 passed locally (17 foundation, 3 Books, 7 Challenges, 6 Stats).
- Swift/XCTest and iOS acceptance are assigned to the macOS CI runner because this
  workstation currently exposes Command Line Tools without the XCTest SDK or Xcode app.
- Final CI candidate, regression matrix and visual boards are recorded below after the
  single final run.

## Deliberate limitations / later work

- Phase 7 does not replay historical imports and does not integrate Phase 8 import events.
- Physical-device and VoiceOver certification remain Phase 12 work.
- Existing documented Foundation accessibility findings remain visible and unchanged.
- The V1 catalogs are deliberately small, stable and configurable; adding future catalog
  content must preserve the locked philosophy and does not alter the Phase 7 data model.
