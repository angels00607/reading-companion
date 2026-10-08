-- Phase 9 durable synchronization metadata. Domain rows remain local-first.
ALTER TABLE outbox ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(attempt_count>=0);
ALTER TABLE outbox ADD COLUMN last_attempt_at TEXT;
ALTER TABLE outbox ADD COLUMN last_error TEXT;
CREATE TABLE sync_receipts (
 owner_id TEXT NOT NULL, mutation_id TEXT NOT NULL, entity_id TEXT NOT NULL,
 revision INTEGER NOT NULL CHECK(revision>=0), acknowledged_at TEXT NOT NULL,
 PRIMARY KEY(owner_id,mutation_id)
);
CREATE TABLE sync_conflicts (
 owner_id TEXT NOT NULL, mutation_id TEXT NOT NULL, entity_id TEXT NOT NULL,
 local_revision INTEGER NOT NULL, server_revision INTEGER,
 reason TEXT NOT NULL CHECK(reason IN ('revision','stale_generation')),
 created_at TEXT NOT NULL, resolved_at TEXT,
 PRIMARY KEY(owner_id,mutation_id)
);
CREATE TABLE sync_tombstones (
 owner_id TEXT NOT NULL, entity_type TEXT NOT NULL, entity_id TEXT NOT NULL,
 deleted_at TEXT NOT NULL, revision INTEGER NOT NULL CHECK(revision>=0),
 mutation_id TEXT NOT NULL UNIQUE,
 PRIMARY KEY(owner_id,entity_type,entity_id)
);
CREATE INDEX sync_conflicts_open ON sync_conflicts(owner_id,resolved_at,created_at);
