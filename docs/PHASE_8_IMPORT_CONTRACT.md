# Phase 8 — StoryGraph import contract

## Input boundary

The native Files picker reads a security-scoped CSV into bounded memory and releases
the scope immediately. Parsing/preview runs away from the main actor. The original
file is not copied into the app, repository, outbox or cloud. CSV is UTF-8, optionally
with BOM, with quoted fields, doubled quotes, CRLF and embedded newlines. It is never
evaluated as spreadsheet formulas or HTML. Unsupported headers, malformed quoting,
ragged rows, invalid encoding and resource-limit violations fail before any write.

Limits are per import, not library limits: 10 MB, 10,000 source rows, 200 columns,
100,000 characters per cell and 25,000 expanded reading occurrences. An over-limit
file is rejected completely, never truncated. No provider requests are made.

Required headings are Title, Authors and Read Status, compared case-insensitively.
Recognized optional facts are ISBN/UID, Read Count, Dates Read, Last Date Read and
Star Rating. The exported Authors display is preserved, not split into guessed
canonical authors. ISBN checksums are validated; non-ISBN UIDs are source identities,
not fabricated editions. Unrecognized columns are discarded. In particular Format,
binding, moods, tags, reviews and contributors do not become Journal Format, Primary
Genre, summary, Series or Challenge evidence.

Supported Dates Read ranges use YYYY/MM/DD-YYYY/MM/DD, comma separated for rereads;
either endpoint can be absent. Only unambiguous year-first Last Date Read is accepted
when ranges are absent. Day-first/month-first or otherwise unrecognized dates remain
unapplied Needs Review evidence; they are never guessed. Explicit ranges can establish
the occurrence count when Read Count is absent. A stated Read with no dates retains
unknown dates; an explicit count can preserve undated rereads. Contradictory counts,
invalid chronology, unsupported statuses and non-whole-star ratings require review.
Zero rating means explicit No Rating; empty rating means Unknown. Half/quarter stars
are not rounded. Those unsupported rows can be kept unapplied or corrected in the
source and re-imported; manual Book/Reading correction remains available.

The export headings are corroborated by a reader's first-hand export description in
[Openreads issue 525](https://github.com/mateusz-bak/openreads/issues/525). StoryGraph's
[official export announcement](https://roadmap.thestorygraph.com/requests-ideas/posts/export-csv)
confirms CSV export. Neither is treated as a versioned official API guarantee. Tests
use explicit fictional fixtures. Compatibility with every future export variant or
a user's private export is not claimed.

## Matching and application

Preview uses the existing four product groups: New Books, Possible Updates, Already
Up to Date and Needs Review. A title/author similarity or ISBN match is evidence for
explicit identity review; it never silently merges works. Previously accepted import
identity links are reusable. Competing identities/contradictory rows in one file are
reviewed; exact duplicate rows are applied once. Book, Edition and ReadingInstance
remain separate; a checksum-valid supplied ISBN can create/reuse an Edition without
inventing language, artwork or page counts.

Confirmation rechecks a fingerprint of local facts, provenance and review state in
the same transaction as application. A stale preview fails unchanged. New records,
identity links, committed history, proposals, Attention and the outbox commit together;
a failure rolls everything back. Exact file retries reuse the committed ImportRun.
Known source occurrence links prevent repeated lifecycle records on later exports.

Ambiguous rows stay persisted and unapplied until explicit identity resolution. The
reader chooses a separate work, an existing canonical Book with **distinct** historical
readings, or an ordered mapping to existing completed readings. A mapping validates
owner, Book, reading status and one-to-one occurrence identity. It does not change the
mapped reading's origin or user Format. Changed status/count evidence never deletes,
resets or silently converts accepted local readings; it remains reviewable, with
explicit additional-history/Keep decisions and existing manual reading correction.

To Read on a newly imported Book is membership intent and creates no reading. Supplied
Read and DNF records are historical. Imported Currently Reading has unknown progress
and emits no start/progress/completion activity; only subsequent genuine user commands
are live. Explicitly resuming an imported DNF activates future live commands without
replaying past progress, finish or XP. Source links/provenance remain preserved.

## Reconciliation and side-effect isolation

Existing accepted local facts and user overrides are never overwritten by confirmation.
Differences become the existing ProposedDataChange model plus persistent Import Attention,
displayed through shared DataChangeReview. Current is read from live local data. Accept
checks the exact displayed-value fingerprint; a later unseen edit causes a stale failure.
Keep preserves local data and suppresses the same entity/field/source-evidence fingerprint.
A materially changed proposed value is eligible again. Keeping an unsupported candidate
also suppresses its normalized evidence, independent of source row position or Format.

An accepted correction is explicitly user-authoritative. Import field acceptance is
limited to Book title/author and historical reading dates/whole-star rating. A linked
live reading uses the existing manual Edit path; import cannot rewrite its lifecycle.
Copied physical information uses existing Journal Corrections, never a second system.
No imported value clears or populates Format, Primary Genre or reading observations.

Historical application bypasses normal Finish, Journal Inbox, Challenge completion,
gamification activity and Achievement producers. Refreshing Quests/Achievements still
excludes imported completed history. Genuine prior XP remains permanent. Historical
Read remains usable by Library, Reading History and Stats; unknown pages/days/date
attribution remain truthful, with no percentage conversion or synthetic activity.

Import History contains committed operations only. Counts describe source rows, Books,
readings, rows queued for review and unchanged rows **at confirmation**, not mutable
totals after later decisions. Durable normalized candidates/proposals retain decisions;
raw CSV is unnecessary. UTC operational timestamps are distinct from date-only readings.

## Persistence and deferred boundaries

Additive local v10 and Supabase 202610080001 introduce private import_runs,
import_candidates and import_occurrences, composite owner/Book/reading relationships,
deduplication and immutable committed history. Existing migrations are untouched.
Supabase enables owner-only SELECT RLS and denies raw authenticated/anonymous writes.
Durable versioned import commands/snapshots use the existing outbox; unsupported cloud
command transport remains closed until Phase 9. No auth, cloud deployment, backup,
restore, live StoryGraph API or AI integration is added.

All Foundation findings and Challenge/provider/AI/auth/backup TBDs remain unchanged.
Native evidence is simulator evidence; physical-device and spoken VoiceOver certification
remain Phase 12 work. No missing Challenge content is inferred.
