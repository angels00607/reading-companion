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
-- Defense in depth for the six V1 keys; one key per category plus the PK
-- enforces one equipped choice. Future catalog additions need a matching migration.
CREATE TRIGGER cosmetic_eligibility_insert BEFORE INSERT ON user_cosmetics
WHEN NEW.cosmetic_key NOT IN ('background.midnight','accent.berry','frame.classic','card.frosted','decoration.sparkle','theme.modern-bookish') OR (CASE NEW.cosmetic_key
 WHEN 'background.midnight' THEN 1 WHEN 'accent.berry' THEN 2
 WHEN 'frame.classic' THEN 1 WHEN 'card.frosted' THEN 3
 WHEN 'decoration.sparkle' THEN 4 WHEN 'theme.modern-bookish' THEN 1 ELSE 2147483647 END)
 > (SELECT COALESCE(SUM(amount),0)/500+1 FROM xp_awards WHERE owner_id=NEW.owner_id)
BEGIN SELECT RAISE(ABORT,'Unknown or locked cosmetic'); END;
CREATE TRIGGER cosmetic_eligibility_update BEFORE UPDATE ON user_cosmetics
WHEN NEW.cosmetic_key NOT IN ('background.midnight','accent.berry','frame.classic','card.frosted','decoration.sparkle','theme.modern-bookish') OR (CASE NEW.cosmetic_key
 WHEN 'background.midnight' THEN 1 WHEN 'accent.berry' THEN 2
 WHEN 'frame.classic' THEN 1 WHEN 'card.frosted' THEN 3
 WHEN 'decoration.sparkle' THEN 4 WHEN 'theme.modern-bookish' THEN 1 ELSE 2147483647 END)
 > (SELECT COALESCE(SUM(amount),0)/500+1 FROM xp_awards WHERE owner_id=NEW.owner_id)
BEGIN SELECT RAISE(ABORT,'Unknown or locked cosmetic'); END;
