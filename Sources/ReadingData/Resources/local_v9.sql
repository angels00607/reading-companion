-- Additive lifecycle metadata: preserve all existing ledgers and Quest history.
CREATE TABLE gamification_activity (
 owner_id TEXT NOT NULL, semantic_key TEXT NOT NULL, family TEXT NOT NULL
 CHECK(family IN ('pages','progress','completion','journalActivity','organization','frequency')),
 entity_id TEXT NOT NULL, quantity INTEGER NOT NULL CHECK(quantity>0),
 activity_date TEXT NOT NULL, occurred_at TEXT NOT NULL,
 PRIMARY KEY(owner_id,semantic_key)
);
CREATE INDEX gamification_activity_period ON gamification_activity(owner_id,family,occurred_at);
CREATE TRIGGER gamification_activity_no_update BEFORE UPDATE ON gamification_activity BEGIN SELECT RAISE(ABORT,'Live activity is immutable'); END;
CREATE TRIGGER gamification_activity_no_delete BEFORE DELETE ON gamification_activity BEGIN SELECT RAISE(ABORT,'Live activity is immutable'); END;
CREATE TABLE quest_lifecycle (
 owner_id TEXT NOT NULL, quest_id TEXT NOT NULL, slot INTEGER NOT NULL CHECK(slot BETWEEN 0 AND 2),
 baseline INTEGER NOT NULL CHECK(baseline>=0), created_at TEXT NOT NULL,
 PRIMARY KEY(owner_id,quest_id), FOREIGN KEY(owner_id,quest_id) REFERENCES quest_instances(owner_id,id)
);
