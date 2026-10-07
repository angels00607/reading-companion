-- Phase 8: normalized import evidence only; raw CSV and external Format are not stored.
CREATE TABLE import_runs (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, fingerprint TEXT NOT NULL,
 completed_at TEXT NOT NULL, rows_count INTEGER NOT NULL CHECK(rows_count>=0),
 new_books INTEGER NOT NULL CHECK(new_books>=0), new_readings INTEGER NOT NULL CHECK(new_readings>=0),
 review_count INTEGER NOT NULL CHECK(review_count>=0), unchanged_count INTEGER NOT NULL CHECK(unchanged_count>=0),
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,fingerprint)
);
CREATE TABLE import_candidates (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, run_id TEXT NOT NULL, candidate_json TEXT NOT NULL,
 fingerprint TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('pending','resolved','kept')),
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,fingerprint),
 FOREIGN KEY(owner_id,run_id) REFERENCES import_runs(owner_id,id)
);
CREATE UNIQUE INDEX reading_book_identity ON readings(owner_id,id,book_id);
CREATE TABLE import_occurrences (
 owner_id TEXT NOT NULL, source_identity TEXT NOT NULL, occurrence INTEGER NOT NULL CHECK(occurrence>=0),
 book_id TEXT NOT NULL, reading_id TEXT, edition_id TEXT,
 PRIMARY KEY(owner_id,source_identity,occurrence),
 FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id),
 FOREIGN KEY(owner_id,reading_id,book_id) REFERENCES readings(owner_id,id,book_id),
 FOREIGN KEY(owner_id,edition_id,book_id) REFERENCES editions(owner_id,id,book_id)
);
CREATE INDEX import_pending ON import_candidates(owner_id,status);
CREATE INDEX import_reading ON import_occurrences(owner_id,reading_id);
CREATE TRIGGER import_history_no_update BEFORE UPDATE ON import_runs BEGIN SELECT RAISE(ABORT,'Import history is committed evidence'); END;
CREATE TRIGGER import_history_no_delete BEFORE DELETE ON import_runs BEGIN SELECT RAISE(ABORT,'Import history is committed evidence'); END;
