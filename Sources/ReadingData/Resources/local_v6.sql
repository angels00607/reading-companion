-- Additive Phase 5. Original snapshots and migrations are never rewritten.
ALTER TABLE challenge_assignments ADD COLUMN source TEXT NOT NULL DEFAULT 'legacy';
ALTER TABLE challenge_assignments ADD COLUMN evidence_json TEXT;
ALTER TABLE challenge_assignments ADD COLUMN created_at TEXT;
CREATE TABLE challenge_rejections (
 owner_id TEXT NOT NULL, rejection_key TEXT NOT NULL, book_id TEXT NOT NULL, prompt_id TEXT NOT NULL,
 rejected_at TEXT NOT NULL, PRIMARY KEY(owner_id,rejection_key),
 FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id),
 FOREIGN KEY(owner_id,prompt_id) REFERENCES challenge_prompts(owner_id,id)
);
CREATE TABLE attention_items (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, category TEXT NOT NULL CHECK(category IN ('journal','series','challenges','books','import')),
 entity_id TEXT NOT NULL, reason TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('open','resolved')),
 created_at TEXT NOT NULL, PRIMARY KEY(owner_id,id), UNIQUE(owner_id,category,entity_id,reason)
);
CREATE INDEX challenge_reading_state ON challenge_assignments(owner_id,reading_id,status);
CREATE INDEX attention_open ON attention_items(owner_id,category,status);
CREATE TRIGGER challenge_reading_guard BEFORE INSERT ON challenge_assignments
 WHEN NOT EXISTS(SELECT 1 FROM readings WHERE owner_id=NEW.owner_id AND id=NEW.reading_id AND status='read' AND deleted_at IS NULL)
 BEGIN SELECT RAISE(ABORT,'Challenge requires a completed reading'); END;
CREATE TRIGGER challenge_reading_guard_update BEFORE UPDATE ON challenge_assignments
 WHEN NOT EXISTS(SELECT 1 FROM readings WHERE owner_id=NEW.owner_id AND id=NEW.reading_id AND status='read' AND deleted_at IS NULL)
 BEGIN SELECT RAISE(ABORT,'Challenge requires a completed reading'); END;
CREATE TRIGGER challenge_year_no_delete BEFORE DELETE ON challenge_years
 BEGIN SELECT RAISE(ABORT,'Year snapshots are immutable'); END;
CREATE TRIGGER challenge_prompt_no_delete BEFORE DELETE ON challenge_prompts
 BEGIN SELECT RAISE(ABORT,'Prompt snapshots are immutable'); END;

CREATE TABLE challenge_analysis (
 owner_id TEXT NOT NULL, year_id TEXT NOT NULL, reading_id TEXT NOT NULL, evidence_json TEXT NOT NULL,
 PRIMARY KEY(owner_id,year_id,reading_id),
 FOREIGN KEY(owner_id,year_id) REFERENCES challenge_years(owner_id,id),
 FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id)
);
