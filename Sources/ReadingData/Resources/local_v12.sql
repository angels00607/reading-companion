CREATE TABLE sync_incoming (
 owner_id TEXT NOT NULL, sequence INTEGER NOT NULL, mutation_id TEXT NOT NULL,
 entity_id TEXT NOT NULL, revision INTEGER NOT NULL, generation TEXT NOT NULL,
 kind TEXT NOT NULL, payload BLOB NOT NULL, deleted_at TEXT, applied_at TEXT NOT NULL,
 PRIMARY KEY(owner_id,sequence), UNIQUE(owner_id,mutation_id)
);
