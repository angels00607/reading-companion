# Phase 10B — Needs Attention Status

## Scope

Implemented a persistent, owner-scoped Needs Attention system and one central review
screen. It reuses existing Books, Series, Journal, Challenges and StoryGraph review
flows and does not add a sixth tab. Notifications, Phase 10C, Phase 11 and Phase 12
remain out of scope.

## Behavior

- Categories are Journal, Series, Challenges, Books and Import. The visible filters
  are All, Journal, Series, Challenges and Books; Import remains accessible in All.
- Priorities are Required, Review and Optional. The unresolved count includes all
  categories and orders required decisions first.
- Stable category/entity/reason keys prevent duplicate rows. Resolved evidence is
  not silently reopened; explicit restart is supported.
- Book and Series provider proposals, genuine Journal corrections, Challenge review
  states and StoryGraph conflicts create attention only when the underlying flow
  already requires a decision. Existing decisions resolve the linked item.
- Keep/reject actions preserve user values. Unsupported Edit actions remain visibly
  unavailable rather than pretending to succeed.
- Existing historical-import exclusions and gamification rules are unchanged; no
  historical attention, XP, Achievement or Quest is fabricated.

## Compatibility

The Phase 9 portable-backup schema remains version 1. Its existing attention identity,
category, entity, reason, status and creation timestamp remain compatible. Phase 10B's
additional descriptive metadata uses migration defaults when an older archive is
restored; changing the portable schema requires a separately versioned decision.

## Validation

Targeted repository tests cover persistence, owner isolation, filters, priorities,
deduplication, resolution/restart and preservation of Book/Series values after Keep.
A focused UI acceptance test covers the central list, Import-through-All behavior and
the absence of a sixth tab. Local Swift build passes. This workstation's Swift XCTest
module is unavailable, so checked-in XCTest/UI targets require the pull-request runner.
