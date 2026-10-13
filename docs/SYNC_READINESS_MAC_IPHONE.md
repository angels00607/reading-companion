# iPhone–Mac synchronization: implementation gates

Status: **audit only; synchronization is not enabled**.

## Verified existing foundations
- Shared domain: MutationEnvelope, SyncTransport, SyncPullTransport, SyncCoordinator, FullSyncCoordinator and reviewable conflicts.
- LocalStore: owner-scoped SQLite, durable outbox, remote-change cursor.
- Mac: independently generated local owner UUID in Application Support/ReadingCompanion/local-owner.txt; local UUID.sqlite database.
- Mac Series operations save/edit/delete records locally. Do not assume they emit cloud mutations.
- Chosen auth direction: Google OAuth (Gmail accounts). Configure Google Cloud OAuth credentials and Supabase Google provider before enabling sign-in. A local UUID is not proof of a cloud account identity.

## Blockers before live sync
1. Authenticate the same account on both platforms; securely map it to the cloud owner ID.
2. Back up and transactionally reconcile existing local data with that owner, with explicit user approval. Never silently replace local data.
3. Audit **every** Mac mutation (book, reading, review, series, entry, link, edit, deletion) for durable idempotent outbox coverage.
4. Verify Supabase schema, row-level security, authorization, revision/generation handling, mutation idempotency and cloud transport.
5. Propagate deletions using explicit tombstones or equivalent events; absence from a list is not a deletion.
6. Preserve manual overrides; conflicting reading progress must be reviewed, not resolved by highest value or last timestamp.
7. Retry offline changes after restart without duplication. Advance pull cursors only after successful atomic application.
8. Keep auth tokens in secure storage and out of logs, repositories and backups.

## Delivery order
- Gate A: inventory existing transport/schema, add regression tests for currently missing series outbox coverage.
- Gate B: Sign in with Google on both platforms; account mapping and local-data migration.
- Gate C: sync one book between two distinct local databases, authenticated against an isolated Supabase test project.
- Gate D: readings, progress, journal reviews and conflicts.
- Gate E: series, entries, book links, edits and deletion events.
- Gate F: offline/concurrent edits, replay, restart, account switching, restore and security acceptance.

## Acceptance tests
- Offline book creation on A appears exactly once on B after reconnection.
- Reading marked Read on B updates linked series progress on A.
- Competing manual values and progress observations remain reviewable; no silent overwrite.
- Series deletion never deletes linked books or reading history.
- Signing in never discards existing Mac data.
- Different authenticated accounts cannot access one another's data (RLS).
- Both iOS and macOS builds and tests pass before enabling live sync.

**Current status:** Mac library, journal and series remain local-only. Shared sync protocols alone do not imply functioning cross-device synchronization.
