# Reading Companion --- Design System

## Visual north star

**Modern Bookish (\~80%) + Digital Reading Journal (\~20%)**

A beautiful modern reading app designed by someone who loves physical
reading journals.

Avoid: - sterile productivity software; - fake scrapbook/tape/sticker
aesthetics; - overly cute/girly styling; - rainbow SaaS dashboards; - UI
that competes with book covers.

Book covers are the richest visual elements.

## Color palette

### Blue family

  Name              HEX         Role
  ----------------- ----------- -------------------------------------
  Frosted Berry     `#E7EAF6`   soft selected/current surface
  Blueberry Cream   `#9EB7D8`   soft accent
  Ripe Blue         `#4F81AA`   links, progress, common interaction
  Berry Peel        `#143D5B`   light-mode primary action
  Midnight Jam      `#030B19`   primary text / dark background

### Plum/Berry family

  Name          HEX         Role
  ------------- ----------- --------------------------------
  Blush Mist    `#ECD0EC`   Journal/special soft surface
  Dusty Mauve   `#BA71A2`   soft berry accent
  Berry         `#7E2A53`   Favorite/reward/special accent
  Plum          `#502A50`   deeper special accent
  Deep Plum     `#461D3A`   high-contrast plum

Approximate use: 75% neutrals+blue / 20% plum / 5% semantic exceptions.

### Light tokens

  Token            Value
  ---------------- -----------
  background       `#F5EEF8`
  surface          `#FFFFFF`
  surface-blue     `#E7EAF6`
  surface-plum     `#ECD0EC`
  text-primary     `#030B19`
  text-secondary   `#4F6272`
  border           `#DCE6EA`
  primary          `#143D5B`
  primary-soft     `#9EB7D8`
  secondary        `#7E2A53`
  secondary-soft   `#BA71A2`

### Dark tokens

  Token              Value
  ------------------ -----------------------
  background         `#030B19`
  surface            approx `#0D1B2A`
  surface-raised     attenuated Berry Peel
  text-primary       `#F5F8FA`
  text-secondary     `#AFC3CF`
  border             `#24445B`
  primary            `#A9BCE3`
  surface-blue       `#242B49`
  primary-strong     `#4F81AA`
  secondary          `#BA71A2`
  secondary-strong   `#7E2A53`

Dark mode is Midnight Blue, not black. Do not make every card Berry
Peel.

The authoritative Dark `surface` remains `#0D1B2A`. Candidate `#151728`
is presentation-only and pending human A/B approval; it must not be used as
the production semantic token until that review is complete.

## Typography

### Manrope

Primary functional typeface, \~85--90% of app: navigation, buttons,
body, metadata, forms, stats, filters, alerts, essential information.

### Papernotes Regular

Restrained handwritten/editorial voice: small Journal phrases,
annotations, labels, empty-state phrases.

### Hello Baby

Rare special-moment display: Achievement Unlocked, Level Up, Book
Completed where appropriate.

Never use expressive fonts for essential information. Do not routinely
combine Papernotes and Hello Baby in the same component.

### Scale

  Role             Size Weight
  ------------ -------- ----------
  Display        32--36 Semibold
  Page Title     26--28 Semibold
  Section        20--22 Semibold
  Card           16--18 Semibold
  Body           15--16 Regular
  Secondary      13--14 Regular
  Caption        11--12 Medium

Manrope weights: Regular / Medium / Semibold; Bold rare.

## Geometry and spacing

-   Standard card radius: 14 px.
-   Primary/secondary button radius: 12 px.
-   Button nominal height: \~48 px.
-   Inputs: 10--12 px radius.
-   Pills/chips: fully rounded only where semantically appropriate.
-   Book covers: 6--8 px radius.
-   Progress bars: 6--8 px.
-   Bottom sheets: 20--24 px top radius.
-   Spacing base: 4/8; common 4, 8, 12, 16, 24, 32.
-   iPhone horizontal margin: \~16 pt.
-   Shadows extremely subtle.
-   Prefer thin borders and open layout over card proliferation.

## Buttons

### Primary

Berry Peel + white in Light; appropriate accessible dark token in Dark.

### Secondary

Transparent/light tint + border.

### Tertiary

Text-like action.

Pills are not default buttons.

## Iconography

Functional icons: SF Symbols or one coherent outline family. Custom line
art only for app-specific concepts: - Journal - Quest - Achievement -
Challenge - Series - XP/Level - Book of Month/Year - Collection

Graphic vocabulary: - book / open book / pages / bookmark; - restrained
4-point sparkle; - subtle star/moon only as accents; - handwritten
underline/circle/arrow sparingly.

Avoid: - bees; - compasses; - giant library illustrations; -
people/mascots; - masking tape/sticker scrapbook; - detailed fantasy
quills; - 3D icons; - emoji as UI icons.

## Component rules

-   `BookRow`: Search/My Books/import; dense, row-based.
-   `BookCover`: preserve artwork; consistent aspect ratio/radius;
    neutral fallback.
-   `StatusChip`: text/symbol + color, never color-only.
-   `ProgressBar`: reading = Ripe Blue; XP may use rare Ripe Blue→Berry
    gradient.
-   `BottomSheet`: sort/filter/rating/format/quick actions.
-   `DataChangeReview`: reusable Current vs Proposed + Source +
    Accept/Keep/Edit.
-   `Toast`: one global feedback/Undo system.
-   `FeatureCelebration`: Book Completed/Achievement/Level Up family.
-   `AccessibleChart`: labels/VoiceOver/direct values.

## Bottom navigation

Fixed native-like iOS bar, five tabs with icon + label. No floating
giant pill. Inactive blue-gray. Active Berry Peel/Ripe Blue; Dark active
Blueberry.

## Book covers

Never recolor book covers. Covers should visually outrank gamification.
No generated series artwork.

## Screen rules

### Home

Currently Reading is visually dominant but compact. Avoid stacking giant
cards. Quick Actions compact. Monthly summary open/light.

### Journal

Most editorial area. Slight paper feel permitted. Ready to Journal uses
light Blush + Plum rather than generic green. Journal Session removes
distractions.

### Challenges

Dense rows/grids. Blue progress; Plum proposal/review. No giant
match-score circle.

### Series

No series image. Typographic cards and timeline. Waiting must not look
Completed.

### Stats

Editorial, not SaaS dashboard. Large primary number; open secondary
metrics. Few chart types. No rainbow charts. Covers for Best Book
moments.

### Search / My Books

Rows rather than cards. Covers lead visual hierarchy.

### Profile / Collection

Private Reader Passport. Achievements collectible but elegant. No
game-shop economy.

### Settings / Data

Native rows; almost no expressive typography. Trust and clarity first.

## Motion

Three levels: 1. Functional 2. Feedback 3. Celebration

Typical duration: 180--300 ms. No permanent decorative animation.
Celebrations short and skippable.

Examples: - Update Progress: bar animates + brief `+74 pages`. -
Favorite: small scale + Berry fill. - Challenge Confirm: state
transition + check. - Book Completed: short sparkle treatment. -
Achievement/Level Up: stronger but still restrained.

## Haptics

-   Selection: filters, segmented controls, rating.
-   Light impact: Favorite, Update Progress, checkbox.
-   Success: completion, challenge confirm, journal copied, achievement.
-   Warning: genuine attention only. No haptics for scrolling/routine
    navigation.

## Loading / offline / errors

-   Skeletons for structured loading.
-   Spinner for isolated operation.
-   Offline banner is non-blocking.
-   Local reading workflows remain available where data is cached/local.
-   Unknown is not an error.
-   Error tone is precise, calm, non-cutesy.
-   Prefer Undo for reversible actions.

## Accessibility

-   Test all contrast combinations.
-   Pale palette colors are surfaces/decorations, not body text.
-   Never encode state by color alone.
-   Dynamic Type.
-   Text-bearing components grow vertically.
-   44×44 pt minimum touch targets.
-   Semantic VoiceOver labels.
-   Accessible charts.
-   Reduce Motion.
-   Safe areas / Home Indicator / keyboard avoidance.
-   System / Light / Dark.
-   iPhone portrait-first; landscape functional; dedicated iPad UI
    later.

## Customisation boundaries

Can customize: - Background - Accent - Profile Frame - Card Style -
Decorations - Theme preset

Cannot customize: - functional typography; - layout/navigation; -
accessibility contrast; - semantic colors; - information hierarchy; -
book-cover fidelity; - core button geometry.

Themes are presets, not locked bundles.
