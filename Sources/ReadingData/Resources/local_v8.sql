-- Phase 7 private profile and permanent gamification state.
CREATE TABLE reader_profiles (
 owner_id TEXT PRIMARY KEY, display_name TEXT NOT NULL, avatar_symbol TEXT NOT NULL,
 reading_since INTEGER NOT NULL CHECK(reading_since BETWEEN 1000 AND 9999),
 favorite_books_json TEXT NOT NULL DEFAULT '[]', favorite_series TEXT, favorite_author TEXT, favorite_genre TEXT,
 featured_achievement_keys_json TEXT NOT NULL DEFAULT '[]', updated_at TEXT NOT NULL
);
CREATE TABLE xp_award_metadata (owner_id TEXT NOT NULL, semantic_key TEXT NOT NULL, source TEXT NOT NULL,
 PRIMARY KEY(owner_id,semantic_key), FOREIGN KEY(owner_id,semantic_key) REFERENCES xp_awards(owner_id,semantic_key));
CREATE TRIGGER xp_metadata_no_update BEFORE UPDATE ON xp_award_metadata BEGIN SELECT RAISE(ABORT,'XP metadata is permanent'); END;
CREATE TRIGGER xp_metadata_no_delete BEFORE DELETE ON xp_award_metadata BEGIN SELECT RAISE(ABORT,'XP metadata is permanent'); END;
CREATE TABLE quest_instances (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, template_key TEXT NOT NULL, cadence TEXT NOT NULL CHECK(cadence IN ('daily','weekly','monthly')),
 period_key TEXT NOT NULL, title TEXT NOT NULL, unit TEXT NOT NULL, target INTEGER NOT NULL CHECK(target>0),
 progress INTEGER NOT NULL CHECK(progress>=0 AND progress<=target), completed_at TEXT, rerolled_at TEXT,
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,cadence,period_key,template_key)
);
CREATE TABLE achievement_progress (
 owner_id TEXT NOT NULL, achievement_key TEXT NOT NULL, progress INTEGER NOT NULL CHECK(progress>=0), unlocked_at TEXT,
 PRIMARY KEY(owner_id,achievement_key)
);
CREATE TABLE user_cosmetics (
 owner_id TEXT NOT NULL, cosmetic_key TEXT NOT NULL, state TEXT NOT NULL CHECK(state IN ('unlocked','equipped')),
 updated_at TEXT NOT NULL, PRIMARY KEY(owner_id,cosmetic_key)
);
CREATE INDEX quest_periods ON quest_instances(owner_id,cadence,period_key);
CREATE INDEX xp_awarded_at_v7 ON xp_awards(owner_id,awarded_at);
