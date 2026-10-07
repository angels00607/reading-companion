# Phase 9 — Sync, Backup & Restore

**IN PROGRESS — NOT READY FOR HUMAN REVIEW. Do not merge. Phase 10 not started.**

Base: approved Phase 8 merge `dd789ff52874721f8537319e99c521114e44f871`.
Branch: `codex/phase-9-sync-backup`.

## Work-session checkpoint

The approved PAT and versioned ZIP/JSON decisions are locked in AGENTS.md and the
[backup contract](PHASE_9_BACKUP_CONTRACT.md). Older Phase 0–8 reports remain historical
evidence; their unresolved findings and other TBDs have not been rewritten.

Implemented archive boundary: versioned manifest, coarse privacy-safe source description,
actual collection counts, SHA-256, ZIP CRC, exact inventory, resource bounds, path/symlink/
duplicate rejection and readonly validation. Versioned logical JSON remains independent
of internal SQLite. The codec has no restore writes or live-event replay path.

Added adversarial archive tests and independent Python interoperability validation of
an actual Swift-produced ZIP. Targeted development CI builds the iOS application; it
does not claim a final Phase 9 candidate or A–L acceptance. Existing full regression
and Foundation tests remain available unchanged; tagged Phase 9 development commits
run the relevant new boundary tests instead of repeating the completed Phase 8 matrix.

## Validation

Targeted Swift/iOS validation: pending first run. No Phase 9 simulator acceptance or
visual boards yet. No Phase 9 schema migration or live Supabase deployment yet.

## Remaining work, in order

1. Complete secure GitHub PAT transport/private repository checks and manual versions.
2. Typed complete portable export and preview/atomic restore, including valid XP union,
   overrides, cross-owner/relationship checks, rollback and no historical event replay.
3. Full durable sync transport/pull, receipts/retry, conflicts/review and tombstones.
4. Settings/Profile surfaces and all mandatory A–L functional acceptance flows.
5. One complete Swift/iOS/SQLite/Supabase/regression candidate and native three-mode QA.

No new product approval is requested. Email OTP, missing Challenge catalog content and
other already documented provider/AI limitations remain deferred. The Foundation
107/148 findings remain unresolved: no responsible live element identified,
instrumentation did not establish a false positive, no suppression or threshold change.
They remain open Phase 12/manual native inspection risks.
