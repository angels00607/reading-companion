# Phase 10A — Onboarding Status

## Scope

Implemented the five-step first-use flow: Welcome, Reading History Since,
Preferred Edition, Import or Start Fresh, and Library Ready. The flow is local-first,
resumable, and uses the existing StoryGraph CSV import. Notification permission,
Needs Attention, Phase 10B, Phase 11, and Phase 12 remain out of scope.

## Locked behavior preserved

- UI copy is English and uses the shared SwiftUI design system.
- Journal Format is never requested, inferred, or preselected.
- Start Fresh creates no bibliographic, reading, Journal, XP, Achievement, Quest, or
  Challenge data.
- StoryGraph onboarding uses the existing preview/confirmation pipeline, including
  its historical-side-effect protections.
- Completion updates only onboarding preferences and the existing Reader Passport's
  reading-history year; all other passport preferences are preserved.
- Completed onboarding does not reappear. Owners with durable Phase 0–9 data are
  migrated as already configured so the new feature does not block an existing app.
- The Phase 9 portable-backup schema is intentionally unchanged. Adding onboarding
  settings to that versioned interchange format needs an explicit compatible schema
  revision rather than making older backups invalid.

## Product question retained

The authoritative specification models `Reading History Since` as a required year
and does not define an Unknown state. Phase 10A therefore requires a valid four-digit
year. Adding Unknown would require an explicit product/data-model decision.

## Validation

Targeted Phase 10A repository tests cover first opening, step persistence/restart,
preference preservation, Start Fresh, StoryGraph gating/integration, completion
persistence, and absence of historical/gamification side effects. A focused UI
acceptance test covers the first-use route, completion, and relaunch behavior.

Local validation: `swift build` and application-entry type checking pass. A focused
Swift Testing harness executed four repository scenarios successfully. The installed
Command Line Tools do not include the XCTest module or an iOS Simulator runtime, so
the checked-in XCTest and UI acceptance targets require the pull-request runner.
