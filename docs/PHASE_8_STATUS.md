# Phase 8 — StoryGraph Import / Reconcile

Status: **READY FOR HUMAN REVIEW**. Human functional and visual approval
is still required. PR #9 is unmerged. Phase 9 has not started.

Base: approved Phase 7 main `d5d84d05ab26e437d5c1a4cec6ce25e7b85a79e6`.
Candidate: `f38bb758004181fa18fa215fd65fe4882cb3b65e`.

## Implemented scope

- Native security-scoped CSV selection, bounded UTF-8 parsing and readonly preview.
- StoryGraph adapter; New Books / Possible Updates / Already Up to Date / Needs
  Review, with explicit confirmation and cancellation without writes.
- Conservative, explainable identity matching and persisted unapplied candidates.
  The reader can choose a separate Book, add distinct historical readings to an
  existing Book, or explicitly map occurrences to existing completed readings.
- Atomic historical application, stable source/occurrence identities, retry
  deduplication, immutable committed Import History and durable outbox commands.
- Existing ProposedDataChange / Attention / DataChangeReview for Current vs
  Proposed, override protection, Keep / Accept / manual Edit and evidence-based
  rejection suppression. Accept rechecks the current value actually displayed.
- Profile entry through the existing shell; no extra tab, provider API, AI, cloud
  transport, authentication or backup functionality.

See [the import contract](PHASE_8_IMPORT_CONTRACT.md) for supported headings,
date/rating boundaries, resource limits, identity rules and persistence details.

## Migrations and authority

Additive local `local_v10.sql` and Supabase
`202610080001_storygraph_import.sql` add import_runs, import_candidates and
import_occurrences. Existing migrations are unchanged. Committed history is
immutable; source occurrences are unique and constrained to the same owner/Book
as their ReadingInstance/Edition. Supabase permits owner-only reads and denies raw
authenticated/anonymous writes. Cloud command execution remains closed for Phase 9.

Book, Edition and ReadingInstance remain separate. Rereads share a canonical Book;
To Read is membership intent without a fake reading. Calendar reading dates are
separate from UTC operational timestamps. Unknown dates/pages/genres stay unknown.
Format is neither normalized nor stored from CSV, and no percentage becomes pages.

Confirmation never overwrites accepted facts or user overrides. Accepted corrections
become explicit user-authoritative values. Linked live readings use manual Edit;
import review cannot rewrite their live lifecycle. Import History counts record
confirmation-time outcomes and remain truthful after subsequent review decisions.

## Historical side-effect isolation

Historical application uses dedicated transactional SQL, bypassing live Finish,
completion celebrations, XP awards, Quest activities, Achievement evaluation,
Challenge cascades and Journal Inbox production. Existing legitimate XP is preserved.
Imported completed history remains usable by Library, Reading History and Stats,
without synthetic progress/activity or fabricated date attribution.

Imported Currently Reading awards nothing on import; later genuine user activity
works normally. An imported historical DNF becomes live only on explicit Resume,
without replaying past events. Copied Journal values use existing Corrections when
the reader accepts a changed fact; no parallel physical reconciliation model is added.

## Validation and native acceptance

Development self-QA run [37626658397](https://github.com/angels00607/reading-companion/actions/runs/37626658397)
passed 29 Phase 8 Swift tests, the iOS build and all three native acceptance tests:
historical import/reconciliation, cancel-without-commit and the Light / Dark /
Accessibility XXXL matrix. Local validation passed all 50 SQLite tests.

The functional flow loads the fictional CSV through the real parser, previews and
confirms it, checks three readings with zero XP/Quest/Achievement/Challenge/Inbox
cascades, visits the Library and unknown-date/Format Reading History, protects an
actual manual title correction, previews the next import, keeps its title, accepts
the safe historical finish-date correction and checks both committed history rows.
The matrix additionally exercises ambiguous identity and unsupported date/rating
review, scrolling and action target frames. Reread and incomplete-history evidence
comes from actual imported records, not assigned UI states.

Final full candidate run [37632080171](https://github.com/angels00607/reading-companion/actions/runs/37632080171)
completed successfully on candidate/application SHA
`f38bb758004181fa18fa215fd65fe4882cb3b65e`:

| Check | Result |
| --- | --- |
| Full Swift suite | 168 passed, including all 29 Phase 8 tests |
| iOS simulator build | Passed |
| SQLite | 50 passed: Foundation 17, Books 3, Challenges 7, Stats 6, Gamification 9, Imports 8 |
| Supabase migrations / RLS | 135 pgTAP assertions passed across 11 files; seeded v1 upgrade passed |
| Native font registration | Passed; five approved bundled fonts registered without fallback |
| Phase 8 acceptance | All 3 passed, including Light Standard / Dark Standard / Accessibility XXXL |
| Existing native regression | Books Core, Journal, Series, Challenges, Stats and Profile/Gamification passed |

Registered PostScript names: Manrope-Regular, Manrope-Medium, Manrope-SemiBold,
PapernotesRegular and HelloBabyRegular. Phase 8 continues to use functional Manrope.
Foundation default/XXXL audits were not rerun; their unchanged tests remain available
through the explicit foundations stage. Candidate success is not a claim that their
deferred findings have been resolved.

## QA evidence and diagnostic history

The final [board index](qa/phase8/README.md) contains
[Light Standard](qa/phase8/Light-Standard.png),
[Dark Standard](qa/phase8/Dark-Standard.png) and
[Accessibility XXXL](qa/phase8/Accessibility-XXXL.png).
[PROVENANCE.json](qa/phase8/PROVENANCE.json) identifies all 63 original captures from
final candidate run 37632080171, review-evidence artifact 11488257243, application SHA
`f38bb758004181fa18fa215fd65fe4882cb3b65e`, on iPhone SE (3rd generation), with
timestamps, native dimensions and SHA-256 checksums. All three boards were inspected;
no new Phase 8 visual defect was found. Enlarged content reflows vertically and
requires scrolling; Current vs Proposed and actions remain reachable.
Screenshots are native simulator captures, arranged with proportional resizing and
external captions. No app pixels or facts are edited.
The debug-only QA inputs and SQL safety summary are absent from release UI.

Initial targeted compilation found a missing return in a new import display helper;
it was corrected. Two targeted test expectations incorrectly compared legitimate
prior XP with zero and transient hydrated XP UUIDs with permanent award identity;
they were corrected to check unchanged permanent keys/amounts. No award rules changed.

Native run 37623334731 could not tap the nested SwiftUI debug Menu proxy because
XCTest requested an unsupported AX scroll-to-visible action. Its exported live
hierarchy and entry screenshot identified the visible navigation-bar button at
`{{288,20},{71,44}}` on iPhone SE. The fixture helper now taps that exact live frame
after asserting existence, on-screen bounds and minimum target size. Production UI,
accessibility findings and thresholds were unchanged. Run 37626658397 subsequently
passed the complete three-test acceptance/matrix. This diagnosis concerns the debug
fixture entry only and establishes nothing about the deferred Foundation findings.

Final packaging adds status/QA evidence and preserves the original unchanged-line
endings in SharedComponents.swift to keep its review diff focused on the new optional
canAccept gate. Its normalized source is byte-identical to the validated candidate;
no application behavior changes after that candidate and no duplicate CI is launched.

## Limitations and deferred items

- The supported export contract is explicit; compatibility with every future CSV
  variant or an unprovided private export is not claimed. Ambiguous dates,
  fractional ratings, inconsistent counts and unsupported statuses remain unapplied
  Needs Review; no guessed dates, rounded rating or partial corruption is introduced.
  A reader can Keep the row, correct the source and re-import, or use manual editing.
- The native acceptance loads a fixture at the adapter boundary. Manual Files-provider
  selection/security-scope behavior on a physical device is not certified.
- Simulator reflow/target checks are not physical-device or spoken VoiceOver
  certification. Those checks remain Phase 12 work.
- The documented Foundation 107/148 findings remain unresolved, with their complete
  diagnostic history and tests preserved. No responsible live element was identified;
  instrumentation did not establish a false positive; no finding was suppressed.
  They remain an open accessibility risk requiring Phase 12/manual native inspection.
  This phase does not rerun or reinterpret those audits.
- Missing Challenge content, ISO week 53 and date-only completion ties, provider/AI,
  auth, cloud sync and backup/restore TBDs remain exactly as previously documented.
  No missing Challenge content is inferred and no later-phase behavior is approved here.

No new product decision or unresolved Phase 8 functional issue was found. The final
candidate passed; human review remains the acceptance gate. Do not merge this PR
or begin Phase 9 without the next explicit instruction.
