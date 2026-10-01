# Reading Companion --- Master Specification

**Status:** FINAL product specification for Codex implementation\
**Role:** Single source of truth for product behavior, information
architecture, UX rules, and visual direction.

> Reading Companion is a modern, editorial, bookish iPhone app designed
> by someone who loves physical reading journals. The digital product
> prepares and enriches the physical journal rather than replacing it.

## 1. Product purpose

-   StoryGraph is a lightweight bibliographic/status source, not the
    core product.
-   Reading Companion is the source of truth for detailed reading
    activity, progress, journal preparation, Series, Challenges, Stats,
    Favorites, Quotes, Quests, XP, Achievements, and customization.
-   The physical A5 Reading Journal is the polished/final archive.
-   Never require duplicate entry of information the app already knows.
-   Gamification rewards reading and organization and never punishes
    inactivity.
-   No social/community product is required for V1.
-   Mobile-first and specifically iPhone portrait-first.

## 2. Global data-integrity contract

1.  Never fabricate missing facts.
2.  Unknown remains unknown until resolved by a reliable source or the
    user.
3.  Every user-facing factual value has a manual edit path.
4.  User corrections override external/imported/AI values.
5.  Synchronization never silently overwrites user corrections.
6.  External changes use
    `Detect → Notify → Review → User decides → Apply`.
7.  Store provenance where useful.
8.  AI suggestions do not become factual Journal or Challenge data
    without user validation.
9.  If already-copied physical Journal data changes, offer a Journal
    Correction.

### Format

`Format` is user-only data belonging to a Reading Instance. Allowed
values: - Paperback - Hardcover - Ebook - Audiobook

Never infer/import/preselect/suggest Format. It is required for Book
Review `Ready to Journal`.

## 3. Domain model

-   **Book**: canonical work.
-   **Edition**: bibliographic edition, language/title/cover/ISBN/page
    metadata.
-   **ReadingInstance**: one time the user reads the Book.
-   A reread creates another ReadingInstance.
-   Book Page may show latest personal rating; Reading History shows
    each instance.
-   Edition metadata and Journal Format are separate.

## 4. External data

The app must remain functional without StoryGraph. - StoryGraph
conceptual statuses: To Read / Currently Reading / Read. - Progress
lives in Reading Companion. - StoryGraph CSV supports initial import and
later manual reconciliation. - No routine monthly import is required. -
Provider abstraction should support Open Library, Google Books,
StoryGraph import, and Manual data. - Prefer English editions in
search. - If a verified published French edition exists, allow EN/FR
edition selection using real edition metadata. - Never
invent/AI-translate an edition.

## 5. Navigation

Five main tabs: 1. Home 2. Journal 3. Challenges 4. Series 5. Stats

Avatar opens Profile / Achievements / Customisation / Settings. Global
Search/Add is available. My Books is accessible from Home/Search and is
not a sixth tab.

## 6. Home

Purpose: **What am I reading? → What can I do now? → Where am I?**

Order: 1. Header 2. Currently Reading 3. Quick Actions 4. Today's Quest
5. Journal 6. This Month

### Currently Reading

-   One fixed-height visible card; multiple books via horizontal
    swipe/carousel.
-   Cover, title, author, current page/total, progress %, Update
    Progress.
-   Update Progress asks current page and computes pages added.
-   Final page triggers explicit finish confirmation.
-   Reading session/time is optional; timer can be future work.

### Home rules

-   Quick Actions: Add Book, Journal, Challenges.
-   Home shows one primary Quest.
-   Journal block shows compact pending counts / Ready to Journal.
-   Monthly summary: Books / Pages / Reading Days.
-   No recommendations, social feed, giant charts, full challenge/series
    lists, or guilt messaging.
-   Newly unlocked Achievements may surface temporarily.

## 7. Quest Engine

Quests are activity-based only. Families: frequency, pages, sessions,
progress, completion, journal activity, organization, consistency. - No
content/property prompts such as "read a fantasy". - Template library
with varied wording/targets/difficulty. - Cooldowns prevent
repetition. - Adaptive targets use smoothed recent activity with caps. -
No impossible quests. - No XP loss. - Current starting volume: Daily 2 /
Weekly 3 / Monthly 3. - Home shows one; Quest Center shows all. -
Candidate rerolls: one free Daily/day and one Weekly/week; rejected
quest cannot immediately return. - Exact balancing remains tunable
without changing philosophy.

## 8. Reading lifecycle

Core states: - To Read → Currently Reading → Read - Currently Reading →
DNF - DNF → Resume Reading → Currently Reading

### DNF

DNF is a technical status only: - no Book Review; - no automatic
Challenge analysis; - no Books Read count; - no Stats / Journal Stats; -
no completion XP; - retain progress internally; - resumable later.

### Completion

Explicit confirmation is mandatory. Completion updates reading data,
Journal Inbox, Challenge analysis, Series, XP/Achievements, and journal
readiness.

## 9. Journal

Three areas: 1. Journal Inbox 2. My Journal 3. Journal Session

### Journal Inbox

Finished books enter automatically. Readiness is component-based: - Book
Review - Series - Challenges - Favorite - Quote

Favorite/Quote support explicit `No favorite` / `No quote`. Challenge
review never blocks Book Review readiness.

### Book Review physical fields

-   Title
-   Author
-   Pages
-   Rating
-   Format
-   Start
-   Finish
-   Summary

Rating: whole stars 1--5 or No rating. Pages/dates remain editable; user
values win.

### Summary Assistant

Generate a factual \~40-word, journal-suitable summary with main
characters where appropriate and no spoilers beyond the basic premise.
Allow conversational revision and explicit `Use this summary`. Exact AI
integration is a technical decision; do not assume access to a ChatGPT
project.

### Reading Log

Generated from existing data; no duplicate entry. Physical layout: 20
books/A5 page.

### Favorites & Quotes

-   Favorites feed physical Favorites Books.
-   150 slots; 15 books/page.
-   Multiple digital quotes allowed.
-   Each quote independently markable for physical journal.
-   Physical quotes: 6/page.

### Journal Session

Focus/copy mode: - hide bottom nav, XP, Quests, and notification
distractions; - show exactly what to copy; - Previous / Copied
navigation; - progress through session; - quest progress may appear only
after session completion. Distinguish `Ready` from `Journaled`. Changes
to copied data create a pending Journal Correction.

### My Journal / physical structure

-   Book Reviews: 27 sheets / 54 pages / 100 books / 2 books per page.
-   Reading Log: 20 books/page.
-   Series Tracker: ≤5 → 8 series/page; ≤10 → 4/page; ≤20 → 2/page.
-   Favorites: 150 slots; 15/page.
-   Quotes: 6/page; refill total 25 sheets.
-   Stats: Monthly double page/month; Yearly 2 pages/year; Lifetime 5
    years/volume.
-   Full refill can be archived and a new volume started.

## 10. Series

Purpose: know where the reader is in a series and maintain the physical
tracker.

Filters: - All - Active - Waiting - Completed - Abandoned - Needs
Attention

Statuses: - Active - Waiting - Completed - Abandoned - Unknown

User status override wins.

Rules: - No generated series image; individual book covers only. -
Series Page shows ordered entries with position/title/rating/read
state. - Support positions 0.5, 1, 1.5, 2, etc. - Distinguish main
entries from related/companion entries. - Physical tracker inclusion is
editable. - Future book state: Published / Announced / Unconfirmed /
Unknown. - Unconfirmed does not count in confirmed total. - Release date
can be exact/year/unknown only when verified. - Next Book = next
included unread entry. - `Start Reading` may set that Book to Currently
Reading. - External changes create reviewable Attention Items. -
Rejected correction is not repeated without new evidence. - Physical
tracker mapping: ≤5 / ≤10 / ≤20 with overflow handling. - Sort: Recently
updated / Alphabetical / Progress / Recently read. - Search by series or
book.

## 11. Challenges

Main areas: - My Challenges - Review Matches - Challenge Archive

### A/B calendar rule

-   Even year → A.
-   Odd year → B.
-   Exactly one active version per calendar year.
-   Year configuration is snapshotted for history.
-   2027 therefore uses Version B only.

### Matching

-   Every finished eligible book is analyzed against all eligible
    Challenges for that year.
-   Analyze all free eligible prompts internally.
-   Show only the single most pertinent proposal at a time, with exact
    percentage.
-   Automatic suggestion threshold: ≥70% using reliable information.
-   Under 70%: no suggestion.
-   Distinguish `No match` from `Not enough information`.
-   Confirm / Reject / Ask Assistant.
-   AI never auto-confirms.
-   Reject asks no reason.
-   After Reject, immediately offer next-best eligible ≥70%, if any.
-   Confirmed prompt becomes occupied; later books cannot use it.
-   Manual assignment remains possible.
-   Rejected same suggestion does not recur without new evidence.

### 52 Weeks

-   Finish date determines the week.
-   Empty if no eligible finished book that week.
-   No borrowing across weeks.
-   Tie-break: first book chronologically finished that week auto-fills;
    manual replacement only with another book from same week.

### Challenge content

Use the challenge definitions already supplied by the product owner. Do
not infer missing prompts. Missing December Version B Monthly prompts
remain content to supply/verify.

## 12. Stats

Separate **Reading Stats** from **Journal View**.

### Global rules

-   Exactly one Primary Genre per Reading Instance for stats; editable;
    user override wins.
-   DNF excluded.
-   Rereads are separate Reading Instances.
-   Best Book of Month and Book of Year are manual choices, never
    algorithmic winners.

### Reading Stats

Scopes: - Month - Year - Lifetime

Editorial, data-rich presentation: - Books - Pages - Reading Days -
Ratings - Primary Genres - Formats - Reading over time - Rereads where
relevant

Comparisons are factual and neutral; no red/green moral framing or
"better/worse". No "missed days". Book covers reappear for Best Book /
monthly winners / Book of Year.

### Best Book

Highest-rated books can form the candidate set, but the user chooses.
Monthly winners feed Book of Year candidates; user chooses Book of Year.

### Journal View

Copy-ready physical Monthly / Yearly / Lifetime values. Lifetime
physical view uses 5-year volumes. Unknown historical data remains
unknown.

## 13. Search / Add Book / Book Page

### Global Search

-   Local library results first.
-   External catalogue second.
-   Search Book/work first, not giant edition lists.
-   Compact rows, not cards.
-   Prevent duplicates but allow `Add Anyway`.
-   If verified EN/FR editions exist, choose edition after Book
    selection.
-   No fake FR option when no verified French edition exists.

### Add Book

Choices: - To Read - Currently Reading - Already Read

To Read: status only. Currently Reading: start date defaults Today,
editable; current page 0. Already Read: finish date or Unknown; rating
1--5 or No rating. Do not ask Summary/Format/Favorite/Challenges here.

### Manual Add

Required: - Title - Author

Optional: - Total Pages - Primary Genre - Series - Cover - ISBN

Use progressive disclosure. Manual cover can be added/changed/removed
and is not silently replaced externally.

### Book Page

Header: - cover - title - author - series/position - status - personal
rating

Summary hierarchy: 1. Journal Summary 2. External Book Synopsis 3. No
summary available

Keep Journal Summary and external synopsis as separate fields.

Reading section is status-specific. Reading History reveals rereads.
Journal section shows component states. Series and Challenges show
concise confirmed/pending information. Book Info contains advanced
editable facts.

Primary Genre distinguishes suggestion from user choice. Edition details
may expose language/ISBN/pages; do not expose provider format in a way
that could be confused with Journal Format.

Delete actions distinguish removing a Book from Library from deleting a
Reading Instance / permanent advanced deletion.

## 14. My Books

Name in UI: **My Books**. Views: - All - To Read - Read

No dedicated Currently Reading view. List only; no grid/list toggle. One
Book = one row even with rereads (`Read 2×`).

### All

Sort: - Recently Added - Title A--Z / Z--A - Author A--Z / Z--A - Pages
shortest/longest

Status filter may include To Read / Currently Reading / Read / DNF.

### To Read

Deliberately simple. Sort: Title / Author / Pages. Unknown page counts
always last. No priority/mood/TBR productivity system.

### Read

Sort: - Recently Finished - Oldest - Title - Author - Rating - Pages

Filters: - Year - Rating - Primary Genre - Format - Series vs
Standalone - Favorite

Filters combine. Local search: title/author/series. DNF accessible
through search/filter, not promoted. Use progressive loading/local
indexing/DB-side sorting for large libraries.

## 15. Profile / XP / Achievements / Collection

### Profile

Private Reader Passport; no social profile. `Reading History Since` is
2020 for current product data and is not account creation date. Profile
shows: - avatar/frame - name - reading since - level/XP - Books / Pages
/ Achievements - Favorite Books - favorite series/author/genre where
configured - 3 Featured Achievements

### XP / Levels

-   Permanent XP; no reset/loss.
-   Sources: Reading / Journal / Challenges / Quests / Milestones.
-   No page=XP linear farming.
-   Tier/cap approach allowed.
-   Challenge XP only after Confirm.
-   No daily login/streak multiplier.
-   Ordinary XP is discreet; explicit reward UI for Quest
    completion/Achievement/Level Up.
-   Levels unlock cosmetics only; no essential feature locks.
-   Exact thresholds are balancing work, not locked product behavior.

### Achievements

-   All visible; no secret achievements.
-   One-time.
-   Locked state shows condition/progress.
-   No bronze/silver/gold tier system.
-   Level-only achievements may award 0 XP.
-   User chooses Featured Achievements.

### Collection / Customisation

Categories: - Backgrounds - Accents - Frames - Cards - Decorations -
Themes

States: - Equipped - Unlocked - Locked

No currency, loot, rarity economy, paywall, limited offer. Themes are
presets and can be individually modified. Customization never changes
functional typography, layout, navigation, accessibility contrast,
semantic colors, book-cover fidelity, information hierarchy, or core
button geometry.

## 16. Notifications & Needs Attention

Notification ≠ persistent Attention Item.

Central `AttentionItem` categories: - Journal - Series - Challenges -
Books - Import

Internal priority: - Required - Review - Optional

Needs Attention filters: - All - Journal - Series - Challenges - Books

External change review uses one reusable Current vs Proposed component
with Source + Accept / Keep / Edit. Group noisy
sync/import/challenge/journal updates. Informational no-action
notifications can expire; unresolved Attention Items persist. Badge
reflects meaningful unresolved attention, not unread noise.

Default push: - Series & New Releases: ON - Release Date Changes: ON -
Import & System: ON - Challenges: OFF - Journal: OFF - Quests: OFF -
Achievements & Levels: independent setting

Disabling push never hides required Attention Items.

## 17. Settings & Data

Settings: - Account & Profile - Reading Preferences - StoryGraph &
Imports - Notifications - Data & Backup - Appearance - About

### Reading Preferences

-   Preferred Book Edition: English.
-   Journal Formats fixed: Paperback / Hardcover / Ebook / Audiobook.
-   User can manage Primary Genres.
-   Deleting an in-use genre requires reassignment.

### StoryGraph

-   Initial import + manual Reconcile.
-   Preview groups: New Books / Possible Updates / Already Up to Date /
    Needs Review.
-   Never blindly overwrite enriched app data.
-   Historical import is not live event replay.
-   Maintain Import History.

### Data ownership

User reading data belongs to the user and remains exportable. No
destructive sync.

### Backup direction

Chosen architecture direction: - local/iPhone =
immediate/offline-capable state/cache; - Supabase = live cloud
database/sync; - periodic/manual cloud snapshots/backups as
implemented; - GitHub = manual, punctual, versioned backup snapshots,
not a commit on every app change; - Local Export = independent portable
backup.

GitHub action:
`Settings → Data & Backup → GitHub Backup → Back Up to GitHub`

Show last backup timestamp/source device. Restore requires preview +
integrity check before destructive application. Secrets/tokens never
stored in code/repository/clear text.

Full backup conceptually includes: - library - readings - journal -
series - challenges - stats selections - quotes - profile -
gamification - settings - manifest/schema/app version/counts

## 18. Onboarding

Short and useful: 1. Welcome 2. Reading History Since 3. Preferred
Edition 4. Import from StoryGraph or Start Fresh 5. Library Ready

Do not use a long marketing carousel. Do not force mass cleanup of
imported data. Do not ask Format during import. Do not configure
Challenges manually in onboarding. Do not require customization.
Historical import does not trigger mass live events. Ask notification
permission contextually later, not at first launch. Exact authentication
method remains technical TBD.

## 19. Visual direction

North Star: **Modern Bookish (≈80%) + Digital Reading Journal (≈20%).**

Avoid: - sterile white/gray productivity UI; - fake scrapbook; -
girly/cute overload; - rainbow SaaS dashboards; - decorative competition
with book covers.

Book covers are the richest visual elements.

### Color source palette

Blue: - Frosted Berry `#E4F3F4` - Blueberry Cream `#91C9E2` - Ripe Blue
`#4F81AA` - Berry Peel `#143D5B` - Midnight Jam `#030B19`

Plum/Berry: - Blush Mist `#ECD0EC` - Dusty Mauve `#BA71A2` - Berry
`#7E2A53` - Plum `#502A50` - Deep Plum `#461D3A`

Approximate visual balance: 75% neutrals+blue / 20% plum / 5% semantic
exception colors.

### Light tokens

-   background `#F8FAFB`
-   surface `#FFFFFF`
-   surface-blue `#E4F3F4`
-   surface-plum `#ECD0EC`
-   text-primary `#030B19`
-   text-secondary `#4F6272`
-   border `#DCE6EA`
-   primary `#143D5B`
-   primary-soft `#91C9E2`
-   secondary `#7E2A53`
-   secondary-soft `#BA71A2`

### Dark tokens

-   background `#030B19`
-   surface approx `#0D1B2A`
-   surface-raised attenuated Berry Peel
-   text-primary `#F5F8FA`
-   text-secondary `#AFC3CF`
-   border `#24445B`
-   primary `#91C9E2`
-   primary-strong `#4F81AA`
-   secondary `#BA71A2`
-   secondary-strong `#7E2A53`

### Typography

-   Manrope: functional UI, ≈85--90%.
-   Papernotes Regular: restrained Journal/editorial voice.
-   Hello Baby: rare special moments.
-   No additional serif.

Scale: - Display 32--36 Semibold - Page Title 26--28 Semibold - Section
20--22 Semibold - Card 16--18 Semibold - Body 15--16 Regular - Secondary
13--14 Regular - Caption 11--12 Medium

Essential information never depends on expressive fonts.

## 20. Component language

-   Standard card radius: 14 px.
-   Buttons: radius 12 px; approx 48 px height; not pills.
-   Pills only for chips/filters/badges.
-   Inputs: 10--12 px radius.
-   Book covers: 6--8 px radius.
-   Progress bars: 6--8 px.
-   Bottom sheets: 20--24 px top radius.
-   4/8 spacing system; common 4, 8, 12, 16, 24, 32.
-   Main iPhone horizontal margin ≈16 pt.
-   Minimal shadows; thin borders.
-   SF Symbols/coherent outline icons for functional UI.
-   Custom line art only for app-specific concepts.
-   Signature motif: bookmark + page + restrained 4-point sparkle.
-   Avoid bees, compasses, giant libraries, people, mascots,
    sticker/tape scrapbook language, 3D icons, emoji UI icons.

## 21. Screen-specific visual rules

### Home

Currently Reading is dominant but compact; Frosted surface, Ripe Blue
progress, Berry Peel action. Quick Actions are compact. Avoid
card-on-card monotony.

### Journal

Most editorial area. Papernotes can appear more. Ready to Journal uses
Blush/Plum rather than green. Journal Session is distraction-free.

### Challenges

Dense rows/grids/checks, fewer covers/cards. Ripe Blue for progress,
Plum for proposed/review. Exact `% MATCH` is compact, not a giant score.

### Series

Typographic cards, no series artwork. Timeline supports fractional
positions. Waiting is not visually treated as Completed.

### Stats

Editorial rather than dashboard-like. Large key number + open metrics.
Few chart types. Blue primary data, Berry selected highlight. No rainbow
charts. Journal View is copy-ready.

### Search / Add / Book Page

Search uses dense rows, not cards. Add flow is intentionally short. Book
Page is dominated by cover + personal reading state. Unknown is a
designed state.

### My Books

List only. Rows, not cards. Covers ≈50--55 px; nominal row ≈78--86 px
but grows for Dynamic Type.

### Profile / Collection

Reader Passport, not social profile. Achievements are collectible
illustrated badges. Collection is visual but has no game economy.

### Settings / Data

Native rows and minimal decoration. Trust/clarity over personality. Red
reserved for truly destructive actions.

### Onboarding

Spacious, short, lightly expressive; Manrope remains functional.

## 22. Motion, haptics, loading, offline, errors

Motion: - Functional - Feedback - Celebration

Typical duration: 180--300 ms. Celebrations remain short and skippable.
Reduce Motion converts complex motion to fades/static decoration.

Haptics: - Selection: filters/segments/rating - Light impact:
Favorite/Update/checkbox - Success:
completion/confirm/copied/achievement - Warning: genuine attention only

Loading: - skeletons for structured content; - spinners for isolated
operations; - prevent duplicate submissions.

Offline: - non-blocking banner; - local Reading Progress, Journal,
Library, local Stats, Favorites, Quotes remain usable where data is
local/cached; - external catalogue search may be unavailable while local
search continues; - queue offline edits for later sync.

Errors: - inline field - contextual feature - critical operation
Critical errors explain whether existing data changed. Avoid
"Oops!"/emoji tone. Unknown ≠ error.

## 23. Accessibility

-   Appropriate contrast for all token combinations.
-   Pale colors are surfaces/decorations, not primary body text.
-   Never communicate state by color alone.
-   Dynamic Type supported.
-   Minimum touch target 44×44 pt.
-   Semantic VoiceOver labels for covers, progress, achievements,
    rating, charts.
-   Charts expose readable values.
-   Safe areas, Home Indicator, keyboard avoidance.
-   System / Light / Dark.
-   Landscape functional, not specially designed for V1.
-   iPad-specific UI is future work.

## 24. Reusable components

At minimum: - BookRow - BookCover - StatusChip - ProgressBar -
PrimaryButton / SecondaryButton / TertiaryButton - FilterChip -
SegmentedControl - BottomSheet - JournalComponentState -
DataChangeReview - AttentionRow - AchievementBadge - CosmeticTile -
StatMetric - AccessibleChart - Toast - SkeletonRow / SkeletonSection -
OfflineBanner - EmptyState - FeatureCelebration

## 25. Technical/content validation still required

These are not permission to change product behavior: - finalize DB
schema/migrations; - validate Supabase auth, quotas, offline/sync
conflict strategy, deployment; - define secure GitHub backup auth and
serialization/manifest; - validate metadata-provider
priority/matching/provenance; - choose AI provider/model and
privacy/context approach; - implement push delivery; - balance exact
XP/level thresholds; - author complete Achievement/Cosmetic catalogue; -
supply/verify missing challenge content, especially December Version B
Monthly prompts; - run
accessibility/offline/migration/import/restore/large-library performance
testing.

## 26. Implementation readiness

**READY FOR IMPLEMENTATION**, subject to technical architecture audit
before coding.
