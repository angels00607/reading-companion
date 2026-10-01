# Phase 1 — App Shell & Shared UI

## Scope

Phase 1 implements presentation-only SwiftUI foundations. It does not add search,
book creation, reading transitions, progress mutation, provider/database access,
statistics, synchronization workflows, rewards or any other Phase 2+ behavior.

## Implemented

- Refined five-tab shell for Home, Journal, Challenges, Series and Stats.
- Expanded centralized semantic Light/Dark colors, spacing, geometry and typography.
- Reusable BookRow, BookCover, StatusChip and Page/Percentage-aware visual ProgressBar.
- Primary, secondary and tertiary buttons; FilterChip and SegmentedControl.
- BottomSheet, Toast, SkeletonRow, Empty/Error/Offline states and OfflineBanner.
- Presentation-only DataChangeReview and AttentionRow primitives.
- Accessible chart foundation with direct labels and values.
- Reduce-Motion-aware reusable celebration shell without reward logic.
- Clearly labelled preview/test fixtures covering long text, loading and state variants.
- Light, Dark and compact accessibility-size previews.

## Acceptance criteria

- Components use centralized semantic tokens and functional Manrope typography.
- Expressive fonts carry no essential control, navigation or factual information.
- Controls use 44-point minimum targets where interactive.
- Text grows vertically and representative long text is included in fixtures.
- State meaning includes text and/or symbols rather than color alone.
- Chart values are available as direct accessibility labels.
- Existing Phase 0 Dynamic Type XCTest findings remain unsuppressed and are still an
  open Phase 12 risk.
- All five Phase 0 tabs and locked domain/data invariants remain unchanged.

## Validation status

- Local `swift build`: passed.
- Local SQLite migration/invariant suite: 16 tests passed.
- Swift/XCTest, iOS application build, hosted font registration, UI audits and
  Supabase/RLS: require the GitHub macOS/Linux runners because this machine has only
  Apple Command Line Tools and cannot resolve XCTest or run `xcodebuild`.
- Visual QA is performed from the five tab/scenario screenshot artifacts produced by
  CI. Dynamic Type audit findings must be reported separately from functional checks.

Phase 1 is not approved or merged until its dedicated PR receives human review.
Do not begin Phase 2.
