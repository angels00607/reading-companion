# Phase 3 Journal — Human Visual QA

These boards are review material, not design approval. They were generated from
CI run [#37280747592](https://github.com/angels00607/reading-companion/actions/runs/37280747592)
on an iPhone SE (3rd generation). The original captures remain in `captures/` and
in the run's `phase-3-journal-visual-qa` artifact.

## Boards

- `board-light-standard.png` — Light, Standard Dynamic Type: My Journal/refill
  overview; Inbox Ready/Pending/Copied; long title; incomplete and Ready Book
  Reviews; manual Summary and truthful assistant-unavailable boundary; Favorite,
  Quote and No-quote preparation controls; focused Journal Session; pending and
  explicitly resolved Journal Correction.
- `board-dark-standard.png` — Dark, Standard Dynamic Type: the same overview,
  Inbox, Book Review, Favorite/Quote, Journal Session and Correction states as
  the Light board. The approved Dark palette is unchanged.
- `board-light-accessibility-xxxl.png` — Light, Accessibility XXXL: vertical reflow
  of overview, Inbox status cards, Book Review and Journal Session at compact
  iPhone width. Scrolling is intentional and content is not compressed.

## Coverage checklist

| Required state | Evidence |
| --- | --- |
| Journal Inbox — Pending | Light/Dark/AXXXL Inbox boards |
| Journal Inbox — Ready | Light/Dark/AXXXL Inbox boards |
| Copied state | Light/Dark Standard lower Inbox captures |
| Book Review — incomplete | Light/Dark Standard boards |
| Book Review — complete/Ready | Light/Dark Standard and AXXXL boards (`No rating` is explicit) |
| Summary field | Light/Dark Standard and AXXXL Book Review captures |
| Summary Assistant boundary | Light/Dark Standard Book Review captures |
| Favorite / No favorite | Light/Dark Favorite/Quotes captures |
| Quotes / No quote | Light/Dark Favorite/Quotes captures |
| My Journal overview | All three boards |
| Refill usage/capacity | All three boards (`1 of 100`, 99 remaining) |
| Journal Session | Light/Dark Standard and AXXXL boards; bottom navigation hidden |
| Journal Correction pending | Light/Dark Standard boards |
| Journal Correction resolved | Light/Dark Standard boards |
| Long title / compact width | Inbox boards |
| Light Standard | `board-light-standard.png` |
| Dark Standard | `board-dark-standard.png` |
| Accessibility XXXL | `board-light-accessibility-xxxl.png` |

The existing Foundation accessibility findings remain visible in CI and are not
suppressed or reclassified here. Physical-device and full VoiceOver certification
are not claimed.
