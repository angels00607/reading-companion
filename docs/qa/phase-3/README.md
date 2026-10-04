# Phase 3 Journal — Human Visual QA

These boards are review material, not design approval. They were generated from
CI run [#37237643919](https://github.com/angels00607/reading-companion/actions/runs/37237643919)
on an iPhone SE (3rd generation). The original captures remain in `captures/` and
in the run's `phase-3-journal-visual-qa` artifact.

## Boards

- `board-light-standard.png` — Light, Standard Dynamic Type: My Journal/refill
  overview; Inbox Ready/Pending/Copied; long title; incomplete and Ready Book
  Reviews; manual Summary and truthful assistant-unavailable boundary; Favorite,
  Quote and No-quote preparation controls; focused Journal Session; pending and
  explicitly resolved Journal Correction.
- `board-dark-standard.png` — Dark, Standard Dynamic Type: My Journal/refill and
  Inbox Ready/Pending/Copied, including lower content and long-title behavior.
- `board-light-accessibility-xxxl.png` — Light, Accessibility XXXL: vertical reflow
  of overview and Inbox at compact iPhone width. Scrolling is intentional.

## Coverage checklist

| Required state | Evidence |
| --- | --- |
| Journal Inbox — Pending | Light/Dark/AXXXL Inbox boards |
| Journal Inbox — Ready | Light/Dark/AXXXL Inbox boards |
| Copied state | Light/Dark/AXXXL lower Inbox captures |
| Book Review — incomplete | Light Standard board |
| Book Review — complete/Ready | Light Standard board (`No rating` is explicit) |
| Summary field | Light Standard Book Review captures |
| Summary Assistant boundary | Light Standard Book Review captures |
| Favorite / No favorite | Light Standard Favorite/Quotes capture |
| Quotes / No quote | Light Standard Favorite/Quotes capture |
| My Journal overview | All three boards |
| Refill usage/capacity | All three boards (`1 of 100`, 99 remaining) |
| Journal Session | Light Standard board; bottom navigation hidden |
| Journal Correction pending | Light Standard board |
| Journal Correction resolved | Light Standard board |
| Long title / compact width | Inbox boards |
| Light Standard | `board-light-standard.png` |
| Dark Standard | `board-dark-standard.png` |
| Accessibility XXXL | `board-light-accessibility-xxxl.png` |

The existing Foundation accessibility findings remain visible in CI and are not
suppressed or reclassified here. Physical-device and full VoiceOver certification
are not claimed.
