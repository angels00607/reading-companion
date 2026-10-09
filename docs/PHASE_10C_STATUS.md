# Phase 10C — iOS Notifications Status

## Implemented

- Owner-scoped GRDB notification preferences with the specified defaults.
- `Achievements & Levels` is independently stored as nullable because no default is
  defined by the authoritative specification. The UI identifies this explicitly and
  records a value only after the user changes its switch.
- A Profile/Settings Notifications screen shows category switches, current iOS
  authorization, contextual permission request, denied guidance and an iOS Settings
  action. Permission is never requested at launch or during onboarding.
- A small `NotificationDeliveryService` abstraction supports deterministic mocks and
  a native `UNUserNotificationCenter` adapter.
- Reconciliation uses stable identifiers, replaces changed requests and cancels stale
  or disabled-category requests. It never creates or resolves Attention Items.

## Actual delivery supported

Only future, exact, verified Series release dates for included entries in Published or
Announced state are locally scheduled. Date-only release facts are delivered at 09:00
local time as a notification timing policy; this does not add a bibliographic event
timestamp. Notification previews deliberately omit book and series names. Existing
stable identifiers allow a corrected date to replace the prior request without a
duplicate.

## Deferred by evidence or infrastructure

- Release Date Changes, Import & System, Challenges, Journal, Quests, and Achievements
  & Levels have preferences and scheduling boundaries but no fabricated delivery.
  The current application has no approved remote event backend or complete future
  trigger contract for them.
- No APNs server or remote push delivery is claimed.
- Notification payloads contain a validated destination kind and entity identifier,
  but the current five-tab navigation shell has no application-wide path router.
  Tapping safely opens the app; automatic deep navigation is deferred rather than
  introducing a broad navigation refactor. Missing/deleted destinations are therefore
  never opened blindly.
- The Phase 9 portable-backup schema remains version 1. Notification preferences are
  durable locally but are not added to the older interchange schema without an
  explicitly versioned backup-format decision.

## Invariants

Notification delivery is not unresolved state. Disabling or dismissing notifications
does not hide, alter, resolve or duplicate Needs Attention items. Historical imported
readings do not produce notification events, XP, Achievements, Quests or Challenge
cascades.

## Validation

Focused repository/coordinator tests cover defaults, persistence, owner isolation,
all category toggles, authorization states, contextual requesting, disabled-category
cancellation, stable identifiers, replacement, Attention independence, historical
isolation and unavailable delivery. Focused UI acceptance covers defaults, accessible
large text and the Needs Attention explanation.

## Review correction — release-date verification boundary

The existing Series model records exact/year/unknown release precision and publication state, but **does not record per-entry verified provenance**. An exact date is not proof that a release date has been verified. Therefore `verifiedNotificationEvents` currently returns no events, preventing unverified alerts. Local delivery infrastructure remains implemented but **actual release alerts are not active** until a separately specified, testable verification source/flag is introduced. The regression test now asserts that an exact, announced, unverified release does not schedule. The app also reconciles pending notifications when it returns to the foreground. Do not advertise verified release alerts as operational in this PR.
