CREATE TABLE series (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, name TEXT NOT NULL CHECK(length(trim(name))>0), author TEXT,
 user_status_override TEXT CHECK(user_status_override IS NULL OR user_status_override IN ('active','waiting','completed','abandoned','unknown')),
 evidence_json TEXT NOT NULL, final_total_known INTEGER NOT NULL DEFAULT 0 CHECK(final_total_known IN (0,1)),
 updated_at TEXT NOT NULL, PRIMARY KEY(owner_id,id)
);
CREATE TABLE series_entries (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, series_id TEXT NOT NULL, book_id TEXT, title TEXT NOT NULL CHECK(length(trim(title))>0),
 position TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('main','related','companion')),
 publication TEXT NOT NULL CHECK(publication IN ('published','announced','unconfirmed','unknown')),
 release_precision TEXT NOT NULL CHECK(release_precision IN ('exact','year','unknown')), release_value TEXT,
 included INTEGER NOT NULL DEFAULT 1 CHECK(included IN (0,1)), tracker_included INTEGER NOT NULL DEFAULT 1 CHECK(tracker_included IN (0,1)),
 PRIMARY KEY(owner_id,id), FOREIGN KEY(owner_id,series_id) REFERENCES series(owner_id,id), FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id)
);
CREATE TABLE series_rejections (
 owner_id TEXT NOT NULL, series_id TEXT NOT NULL, field TEXT NOT NULL, evidence_fingerprint TEXT NOT NULL, rejected_at TEXT NOT NULL,
 PRIMARY KEY(owner_id,series_id,field,evidence_fingerprint), FOREIGN KEY(owner_id,series_id) REFERENCES series(owner_id,id)
);
CREATE INDEX series_name ON series(owner_id,name);
CREATE INDEX series_entry_order ON series_entries(owner_id,series_id,position);
CREATE INDEX series_proposal_state ON data_change_proposals(owner_id,entity_type,status);
