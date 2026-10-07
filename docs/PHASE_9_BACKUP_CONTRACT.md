# Phase 9 — backup boundary and approved decisions

## Approved on 2026-10-07

V1 uses a fine-grained personal access token restricted to one dedicated private
backup repository. Request only repository Metadata read and Contents read/write;
no account, administration, workflow, issue or organization permissions. Only secure
platform credential storage may retain the token. It must never enter source,
repository content, logs, export JSON or ZIPs. Expiration/revocation needs an explicit
reconnect result. GitHub App authentication is outside V1.

The portable format is a versioned ZIP, with authoritative versioned JSON and needed
user-owned assets. Its manifest records format/schema/app versions, creation UTC,
privacy-safe source description, entity counts and SHA-256 metadata. These approvals
supersede older Phase 9 TBD references in the architecture; other TBDs are unchanged.

## Archive boundary implemented in this checkpoint

`manifest.json` describes `data.json` and each `assets/<lowercase UUID>.<extension>`
file. Portable format and logical JSON schema currently have independent version 1
identifiers; they are not SQLite migration numbers. JSON has `schemaVersion` and
logical `entities` collections. The archive codec preserves their exact bytes and
derives the manifest counts. It does not execute SQL or reinterpret unknowns,
calendar dates, percentage/page units, source provenance or XP.

The codec accepts only known logical collection names and rejects credential-shaped
fields recursively. This is defense in depth, **not** a completed domain exporter:
the exporter must still use strict per-entity field allowlists and include every
required relationship and referenced user asset. Outbox/session/SQLite collections
are deliberately outside portable data. Token bytes must never be passed to it.

Source description is the coarse `iOS` or `macOS` platform, without a device name,
hardware ID or account identifier. A private local archive contains personal reading
data; GitHub transport must require a private repository. This V1 ZIP boundary is
not password encryption, and checksums detect corruption rather than authenticate
an archive's author. A hostile archive can recompute its own checksums; later typed
restore validation must therefore verify domain facts, ownership, catalog references
and valid semantic XP awards rather than trusting checksums as authorization.

Reader and writer share the same validation gate: exact inventory, no duplicate
paths, no symlinks/directories, no absolute/traversal/Windows paths, supported versions,
manifest metadata, declared lengths, ZIP CRC, SHA-256 and actual collection counts.
Reading happens in bounded memory and never extracts archive paths onto the filesystem.
Resource limits reject the entire operation without truncation: 128 MiB packed/expanded,
64 MiB per entry, 1 MiB manifest and 10,000 entries. These are per-operation safety
limits, not library limits. Standard stored/deflated ZIP entries are supported;
multi-volume/ZIP64 are rejected in V1. Central-directory count is checked to reject
silent partial iteration. These bounds and memory use need large-library validation.

## Still required before Phase 9 acceptance

- Secure PAT adapter/private-repository preflight, revocation handling and versioned
  manual upload/history.
- Typed full-domain export, referenced asset inventory and independent local sharing.
- Restore preview, cancel, explicit approval, ownership/relationship validation,
  stale-state guard, transactional rollback and permanent semantic-key XP union.
- Sync generation/receipts, full command transport/pull, owned-edit conflict review,
  tombstones and all A–L acceptance flows.
- One final complete regression/native candidate, then native Light/Dark/XXXL boards.

No app UI changed at this checkpoint. Historical Foundation 107/148 findings, the
absence of an identified live failing element and the lack of established false
positive remain documented. No finding/test/threshold is suppressed; native/manual
accessibility certification stays in Phase 12. Missing Challenge content is not inferred.
