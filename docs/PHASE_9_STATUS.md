# Phase 9 — Sync, Backup & Restore

**READY FOR HUMAN REVIEW — PR #10 remains draft and unmerged. Phase 10 has not started.**

Base: approved Phase 8 merge `dd789ff52874721f8537319e99c521114e44f871`.
Branch: `codex/phase-9-sync-backup`.
Validated application SHA: `4803d9c81013e4aa7c082fe82f870154bbea316e`.

## Delivered scope

- Durable local-first sync records retry attempts, immutable request receipts, ordered
  incoming changes, exact server revisions, generation changes, explicit conflicts and
  deletion tombstones. Replay is idempotent and later commands do not pass an unresolved
  conflict.
- Concurrent progress is retained as observations for review. Neither timestamps nor the
  highest observed progress silently wins.
- Portable backup is a strict, typed and versioned logical JSON snapshot inside a ZIP with
  an exact manifest, collection counts, SHA-256 digests and ZIP CRC validation. It covers
  the complete Phase 0–9 domain and enumerated assets while excluding credentials, sync
  cursors, receipts and outbox state.
- Import provides a read-only preview, explicit confirmation, stale-preview rejection,
  transactional application, relationship validation, rollback, post-restore foreign-key
  verification and sync-generation rotation. Historical live events are never replayed.
- Permanent XP merges by semantic award-key union. Conflicting source/amount evidence,
  invalid sources and overflow are rejected rather than silently reconciled.
- Profile → Sync & Backup provides dedicated private-repository setup, fine-grained PAT
  guidance, Keychain-only credential storage, exact repository checks, immutable manual
  GitHub backups, local ZIP export and confirmed restore preview.
- The production Keychain adapter uses `WhenUnlockedThisDeviceOnly`, non-synchronizable
  items and repository isolation. The application entitlement grants only its own
  application identifier / Keychain access group.

The locked decisions in AGENTS.md and
[PHASE_9_BACKUP_CONTRACT.md](PHASE_9_BACKUP_CONTRACT.md) remain authoritative. No
credential, token or authentication material is logged, persisted outside Keychain or
included in an archive.

## Adversarial acceptance A–L

| Flow | Result | Evidence |
| --- | --- | --- |
| A — offline mutation survives restart | PASS | durable SQLite outbox and restart coverage |
| B — lost acknowledgement / retry | PASS | stable mutation ID, attempt metadata and one receipt/effect |
| C — ordered pull / replay | PASS | ordered cursor, durable incoming log and idempotent reapplication |
| D — server conflict | PASS | exact local/server revisions retained; later commands blocked |
| E — concurrent progress | PASS | both observations preserved for review; no max/time winner |
| F — deletion convergence | PASS | quote deletion emits and applies a tombstone idempotently |
| G — portable complete export | PASS | typed JSON/ZIP, assets, manifest and credential exclusion |
| H — hostile/corrupt archive | PASS | digest/CRC/path/symlink/duplicate/depth/size limits enforced |
| I — restore consent | PASS | preview, cancel, explicit confirmation and stale-preview rejection |
| J — atomic restore | PASS | rollback, relationship/FK checks, generation rotation, no old outbox replay |
| K — permanent XP | PASS | semantic award-key union; no historical live-event replay |
| L — GitHub backup boundary | PASS (automated); device check pending | exact private repo, scoped PAT, immutable path, idempotent retry, Keychain lifecycle |

## Final validation

Candidate CI [37793583310](https://github.com/angels00607/reading-companion/actions/runs/37793583310)
passed at the validated application SHA. It ran 229 Swift tests with zero failures,
independent Python ZIP/CRC/SHA-256 interoperability, the normal iOS Simulator application
build, two native production-Keychain lifecycle/isolation tests with zero failures, all
local SQLite schema checks, Supabase reset plus pgTAP/RLS/RPC tests, one Phase 9
functional/visual UI acceptance test and seven isolated accepted Phase 0–8 UI regression
tests. Every listed job and step completed successfully; no failure was skipped or filtered.

The earlier targeted CI [37745298081](https://github.com/angels00607/reading-companion/actions/runs/37745298081)
passed the Phase 9 Swift tests, ZIP interoperability, normal iOS build and both native
Keychain tests for the preceding implementation checkpoint.

## Human visual review material

The candidate produces six labelled screenshots in the `phase-9-visual-review-boards`
artifact: GitHub configuration and export/restore preview states in Light Standard, Dark
Standard and Light Accessibility XXXL. The final artifact was also downloaded to
`work/phase9-final-visual-qa-37793583310/phase9-visual-boards/`. Accessibility XXXL
intentionally reflows and scrolls vertically rather than compressing functional content.

## Explicit limitations and manual device verification

Automated simulator and local Supabase validation do not claim physical-device,
VoiceOver, production-Supabase or live-private-GitHub-repository certification. Before
release, perform this exact manual boundary check:

1. Install a normally signed Release build on a physical device with the approved app
   identifier and app-only Keychain group.
2. Create a dedicated **private** GitHub backup repository.
3. Create an expiring fine-grained PAT restricted only to that repository, with Metadata
   read and Contents read/write; do not grant account-wide or unrelated repository access.
4. In Profile → Sync & Backup, connect that exact owner/repository. Never paste the PAT
   into logs, screenshots or issue text.
5. Background, terminate and relaunch the app; verify a manual backup creates an immutable
   `backups/<UUID>.zip` version and that its preview passes manifest/digest validation.
6. Revoke the PAT and confirm the next operation requires reconnection and clears the
   unusable credential; reconnect with a newly scoped PAT.
7. On a disposable second installation/account, preview and explicitly confirm a restore;
   verify data integrity, permanent XP union and absence of historical side-effect replay.

The previously documented Foundation 107/148 accessibility findings remain open and
deferred to their approved accessibility/Phase 12 work. Nothing is suppressed, filtered,
relabelled or weakened, and Phase 9 human review must not be interpreted as physical-device
or VoiceOver certification.
