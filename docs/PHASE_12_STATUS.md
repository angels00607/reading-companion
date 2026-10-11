# Phase 12 — Accessibility & Responsive QA Status

## Scope audited

- Shared controls and presentations first: covers, rows, status chips, progress,
  buttons, filters, segmented controls, sheets, toasts, loading and state views,
  review cards, attention rows, charts and celebrations.
- The five production tabs with seeded long titles, authors, genres and Series data.
- Secondary Books, Journal, Series, Challenges, Stats, Profile/Achievements,
  onboarding, Needs Attention, import, backup and notification paths by static review
  and their existing focused acceptance coverage.
- Light, Dark and System appearance; standard and Accessibility XXXL Dynamic Type;
  compact iPhone width selected by CI; portrait and landscape; keyboard and safe-area
  behavior; Reduce Motion; touch targets; accessible chart values.

## Corrected findings

1. The shared Toast combined its action with its message, preventing VoiceOver from
   exposing the action independently. It now contains separate readable and actionable
   elements.
2. Shared segmented controls remained horizontal at accessibility sizes. They now
   reflow vertically and expose explicit selected/not-selected values.
3. The five-tab shell removed visible labels at accessibility sizes. Labels now remain
   present, wrap vertically and preserve 44 × 44 pt minimum targets.
4. The Home currently-reading carousel used fixed-width, fixed-height nested scrolling
   at accessibility sizes. It now becomes a vertically expanding list for large text.
5. Series timeline rows and Journal Correction headings could crowd long content. They
   now reflow vertically while preserving all state text and controls.
6. Achievement icons and progress produced fragmented VoiceOver output. Each badge now
   exposes one name plus a complete unlocked/locked and progress value.
7. The numeric onboarding keyboard had no explicit dismissal action. A 44 × 44 pt
   keyboard toolbar action is now available, matching shared form behavior.
8. Dark plum surfaces used the decorative berry accent for small functional text at
   less than 4.5:1. A derived `onPlum` semantic foreground now uses the existing
   approved primary text in Dark Mode while retaining the approved Light appearance.
   No authoritative palette value was changed.
9. Status chips now allow vertical text growth and continue to communicate state with
   text and a symbol, never color alone.

## Automated evidence

- Platform-independent WCAG relative-luminance and contrast tests cover every semantic
  body-text combination used by the shared UI. Required text pairs use a 4.5:1 floor.
- Targeted component tests cover contrast reference values and the existing Reduce
  Motion presentation policy.
- A native font test verifies that every functional Manrope weight scales from the
  standard category through Accessibility XXXL while retaining its registered font.
- `Phase12AccessibilityAcceptanceTests` runs the unfiltered XCTest accessibility audit
  categories for contrast, Dynamic Type, hit regions, descriptions, clipped text and
  traits across the real five-tab shell and representative secondary screens.
- CI changes content size at simulator level, retains screenshots and result bundles,
  and includes a dark System-appearance check. The existing CI device selector prefers
  an available iPhone SE.
- `swift build`: PASS locally.
- `swift test --filter SharedComponentTests`: not executable on this host because the
  selected Command Line Tools installation does not provide the `XCTest` module. This
  is recorded as an environment limitation, not a passing test.
- Native iOS UI execution is delegated to the single PR CI run because this host has
  no full Xcode installation selected.

## Preserved behavior

- No reading, Journal, Series, Challenge, Stats, import, synchronization, XP,
  Achievement, Quest, notification or Attention rules changed.
- The approved five-tab architecture, typography, colors and component hierarchy are
  preserved. Phase 13 data-integrity work has not started.

## Limitations requiring human or device verification

- XCTest accessibility audits do not certify the subjective quality of a complete
  physical VoiceOver navigation session. Labels, values, traits and grouping are
  automated; final spoken order and usability remain a human device check.
- Simulator captures do not certify display behavior on every physical iPhone panel,
  hardware haptics, Switch Control or external keyboards.
- Landscape is validated as functional rather than redesigned, consistent with the
  Master Spec. Dedicated iPad UI remains future work.
