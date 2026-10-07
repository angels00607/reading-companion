# Phase 7 production lifecycle

Normal store opening, Home and Quest Center call `currentQuests`; DEBUG state
assignment is not required. Active volume is 2 Daily / 3 Weekly / 3 Monthly.
Current sets survive reopening. Older periods and rejected instances remain in
`quest_instances`; only current non-rejected, registered slots are active.

## Periods and cooldown

Calendar boundaries use the device's local time zone. Daily keys are local dates;
Weekly keys use ISO week-year and Monday–Sunday; Monthly keys are calendar months.
ISO week 53 is valid for Quests. The separate Challenge week-53 decision remains
unchanged and is not inferred from Quest behavior.

`cooldownPeriods = N` means N **intervening quiet periods**, for the same template
and cadence. A template used in day D with cooldown 1 is excluded on D and D+1,
then eligible on D+2. Weekly/monthly use actual calendar week/month distances.
Rejected templates count as used. No row-count shortcut, insertion-order proxy,
or fallback bypasses the cooldown. Distinct templates in an activity family may
rotate; this is a template cooldown, not a global family ban. Current/future
period history cannot make a template eligible early.

One free reroll per local day and one per ISO week; none for Monthly. The command
checks current period, incomplete selected instance and remaining quota in one
transaction. It marks only that instance rejected and creates one replacement
with the same logical slot and a fresh progress baseline. Failure to obtain a
safe replacement consumes nothing. Persisted rejection history is the quota;
reopening does not reset it. Period rollover resets the relevant quota only.

## Truthful activity and conservative targets

Real command transactions record immutable, owner-scoped activity facts with
stable event keys. Resolved, changed progress observations count updates; only
positive genuine Page-mode deltas count pages. Percentages are never converted.
Explicit user reading-day records count distinct local dates, not invented days
derived from starts/finishes. A backdated date is a Stats fact, not new current
Quest activity. Confirmed, nonhistorical finish commands count completion; DNF
does not. Actual nonhistorical Book Review copy commands count Journal works.
Manual library additions and changed Favorite decisions count organization;
automatic provider/import/reconciliation commands do not. Organization counts
distinct book IDs per period, preventing repeated toggles from multiplying it.
There is no genuine session recorder, so Session templates are ineligible.

Generation prefers evidenced eligible families and family variety. Before there
is history, small fixed progress/organization action goals provide reachable
sets; they do not claim past activity. Targets remain in the typed catalog,
smoothed from actual recorded activity where available and capped. Day goals
are bounded by 1 Daily / 7 Weekly / remaining calendar days Monthly (also by the
conservative catalog cap). A day already recorded when a goal is created cannot
be counted again. Unsupported candidates are omitted, never fabricated.

Each instance records an aggregate baseline at creation, including rerolls. Only
subsequent real activity advances it; preexisting facts do not instantly complete
a new slot. Progress and completion timestamps are monotonic. Quest XP uses
`quest:<instance UUID>`, once. Award history is permanent and never reduced.

## Achievements and levels

The five V1 conditions evaluate transactionally from the verified live finish
and Journal award keys, completed persisted Quests and permanent XP level.
Historical import has no backfill migration or replay. Existing legitimate live
awards remain facts. Catalog progress is known from these aggregates; database
read failures show the visible catalog with **Progress unknown**, not fake zero.
Unlock timestamps/progress are monotonic; `achievement:<catalog key>` deduplicates
configured 50–250 XP, with 0 XP for the Level-only condition. Level is always
`floor(total XP / 500) + 1`; no reading feature depends on level. Live feedback is
shown on Passport surfaces, never during Journal copying. Loading old state does
not manufacture a new celebration.

## Equipment and previews

The repository derives Locked/Unlocked from the real XP level and validates the
exact V1 catalog key before saving. Equipment mutation serializes within the
store and clears other equipped choices in that category. The current catalog
contains one item per category; the key constraint plus catalog validation also
prevents additional arbitrary choices. SQLite/Supabase additionally reject
unknown and ineligible keys. Expanding the catalog needs matching storage rules.

Preview is ephemeral SwiftUI state and issues no persistence command. Cancel
dismisses it; Apply calls the validated transactional equipment command. The one
V1 Modern Bookish preset equips its existing Level-1 background and frame only.
It never bypasses higher-level unlocks. Categories remain individually editable.
Only decorative Passport/preview surfaces change: background, decorative accent,
frame, card border and sparkle. Fonts, semantic action/status/progress colors,
navigation, hierarchy, button geometry and cover rendering retain their tokens.

## Evidence boundary

Production repository acceptance A–G and I uses normal commands and persisted
store reopening with a controlled clock for calendar tests. Native acceptance A
uses a clean isolated persistent store without seeds. Native H/J exercises actual
Preview → Cancel / Apply → process reopen. Visual scenarios replay normal
add/start/update/confirm/copy commands; they never assign XP, Quest progress or
Achievement progress. Instrumented Quest input invokes those same commands.
Screenshots illustrate these scenarios; they are not a substitute for the
production acceptance assertions or physical-device/VoiceOver certification.

Local v9 and `202610070002_live_gamification.sql` are additive; v1–v8 and previous
Supabase migrations remain intact. Full cloud command transport, multi-device
merge and backup/restore execution remain Phase 9 work. The documented Foundation
findings and all Challenge TBDs remain unchanged and deferred as documented.
