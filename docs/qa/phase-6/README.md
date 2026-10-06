# Phase 6 human review evidence

Final validated application: `04b3d44ef059e09a6362fab06e2fdaf5ce8953b8`, branch `codex/phase-6-stats`.

[Final candidate 37481241019](https://github.com/angels00607/reading-companion/actions/runs/37481241019) validates the final application, four Stats acceptance tests and approved font registration. Its Stats result database records five successful tests and zero issues. Candidate artifacts: complete `phase-6-stats-visual-qa` (`11421732305`) and compact `phase-6-stats-review-evidence` (`11422156243`).

[Corrected self-QA 37477717630](https://github.com/angels00607/reading-companion/actions/runs/37477717630) at `46d5f2dc14427501c76738e3d70e59caef913d2c` validates all four Stats UI tests, including the full Light Standard / Dark Standard / Light Accessibility XXXL matrix. Its result database records zero issues. Artifacts: complete `phase-6-stats-visual-qa` (`11421331192`) and compact `phase-6-stats-review-evidence` (`11421530945`).

The final candidate adds explicit primary-number captures and real five-tab-shell verification in all three modes. Relative to the self-QA application, production Stats UI, aggregation, migrations and fonts are unchanged. The application difference is a DEBUG-only fictional historical-percentage fixture, verified by an additional repository test and acceptance Flow C; remaining differences are tests and CI selection. The full visual matrix is therefore reused rather than repeated after evidence packaging.

Native device: iPhone SE (3rd generation), portrait, 375 × 667 points. There are 266 unique named Stats screenshots across these two runs. Boards select 40 panels per mode (120 total): 108 self-QA captures and 12 final-candidate primary-number/shell captures. [capture-index.json](capture-index.json) identifies each native source filename, timestamp, SHA-256, application SHA, run and artifact. Screenshots are resized uniformly; board headings and captions sit outside application images. No synthetic UI is included. XXXL screenshots represent successive scrolling viewports, not truncated text layouts.

- [Light Standard](board-light-standard.png)
- [Dark Standard](board-dark-standard.png)
- [Accessibility XXXL](board-light-accessibility-xxxl.png)

Coverage includes Month/Year/Lifetime, primary Books count, genuine/partial/unknown Pages and Reading Days, ratings, long Primary Genre, mixed Formats, completion charts, manual monthly and yearly selections/candidates, reread history and separate Monthly/Yearly/five-year Journal summaries. Fictional books have no supplied cover artwork; the existing neutral cover fallback is shown without inventing artwork.

Self-review of the final boards and targeted full-resolution XXXL primary values is complete. The display number now uses the approved 36-point Manrope role and still scales fully with Dynamic Type. The long-genre fixture apostrophe and singular undated-history note are corrected. Text contrasts on the used semantic backgrounds meet 4.5:1 (minimum checked ratio 5.04:1); native acceptance preserves 44-point targets and selected-state semantics. No new unresolved Stats visual issue was identified.

Human functional/visual approval remains pending. This evidence does not claim physical-device or spoken VoiceOver certification. Existing Foundation findings, tests and diagnostic history remain visible and deferred to Phase 12, without suppression or a false-positive claim.

[Phase 6 status](../../PHASE_6_STATUS.md).
