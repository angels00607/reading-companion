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

Secure platform Keychain adapter and GitHub transport now provide private/exact-repository
preflight, repository-scoped fine-grained PAT storage, explicit revocation/permission/
rate-limit failures, immutable manual versions, idempotent byte-identical retries,
snapshot-pinned history/download and checksum validation before preview. Native setup
UI and real private-repository/device credential verification are still outstanding.

Permanent XP semantic-key union retains current metadata and rejects conflicting source/
amount, invalid decoded awards and overflow. Typed award-evidence validation and actual
transactional restore remain outstanding. Duplicate JSON keys are rejected rather than
silently selecting a value; excessive nesting fails before Foundation decoding.

Added adversarial archive tests and independent Python interoperability validation of
an actual Swift-produced ZIP. Targeted development CI builds the iOS application; it
does not claim a final Phase 9 candidate or A–L acceptance. Existing full regression
and Foundation tests remain available unchanged; tagged Phase 9 development commits
run the relevant new boundary tests instead of repeating the completed Phase 8 matrix.

## Validation

First targeted run [37642617729](https://github.com/angels00607/reading-companion/actions/runs/37642617729)
at `583a01a08e0ad039615ade40bf4721dfbb1da16c` passed 38 Swift boundary tests (24 archive /
14 GitHub), independent Python ZIP/CRC/SHA-256/count interoperability and the iOS build.
Additional JSON, remote history and XP refinements require their next targeted run;
the earlier result is not claimed as validation of those changes. Local Python script
syntax validation passed. No Phase 9 simulator acceptance or visual boards yet.
No Phase 9 schema migration or live Supabase deployment yet.

## Remaining work, in order

1. Integrate native secure GitHub setup and verify the real private-repository/Keychain lifecycle.
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
