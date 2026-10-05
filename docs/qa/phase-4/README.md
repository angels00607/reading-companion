# Phase 4 Series — Human Visual QA

These boards are presentation material for human review, not design approval.
They use the CI-rendered compact iPhone captures from the reviewed Phase 4 branch.

## Boards

| Board | Appearance | Dynamic Type | Representative states |
| --- | --- | --- | --- |
| `board-light-standard.png` | Light | Standard | list; selected/unselected status filters; alphabetical sort; long Series name; Series Page; Next Book; tracker; Needs Attention; fractional main/related timeline; Current/Proposed; rejected/suppressed; entry 25 |
| `board-dark-standard.png` | Dark | Standard | the same primary list, page, timeline, review, suppression, and >20-entry states in the locked Dark palette |
| `board-light-accessibility-xxxl.png` | Light | Accessibility XXXL | compact-width list and Series Page with vertical reflow, long Series/Book names, timeline, fractional position, and tracker controls |

## Required-state checklist

| Required review item | Evidence |
| --- | --- |
| Series list | all three boards, List panel |
| Search / filters / sort | Standard boards, Search · Filter · Sort panel; Accessibility board, List panel |
| Active | Standard List and Series Page panels |
| Waiting | Standard Search · Filter · Sort and List panels |
| Completed | Standard List lower panel |
| Unknown | Standard List lower panel |
| Abandoned | Standard List panel |
| Series Page | all three boards |
| Fractional timeline | Series Page / Timeline panels, position 1.5 |
| Main vs related | Timeline panels, labelled chips |
| Next Book | Series Page panels |
| Future release state | Waiting fixture in list plus future-entry acceptance fixture; exact/year/unknown preservation is covered by automated tests |
| Unknown release / final total | Timeline `Release unknown` and list/page `Final total unknown` |
| >20-entry Series | Series Page `Page 1 of 25` and Timeline End · Entry 25 panels |
| Physical tracker mapping | Series Page continuation summary and timeline inclusion toggles |
| Needs Attention | Series Page / Timeline panels |
| Current vs Proposed | Standard Current vs Proposed panels |
| Rejected / suppressed | Standard Rejected / Suppressed panels |
| Long Series name | List and Series Page panels |
| Long Book title | Next Book and fractional related-entry panels |
| Light Mode | Light Standard and Accessibility XXXL boards |
| Dark Mode | Dark Standard board |
| Compact iPhone width | every board (iPhone SE, 375 pt wide) |

The complete original screenshots and XCTest result bundle are retained by CI in
the `phase-4-series-visual-qa` artifact. The historical Foundation accessibility
audit remains separate, visible, and unsuppressed.
