CREATE TABLE notification_preferences (
 owner_id TEXT PRIMARY KEY,
 series_releases INTEGER NOT NULL DEFAULT 1 CHECK(series_releases IN (0,1)),
 release_date_changes INTEGER NOT NULL DEFAULT 1 CHECK(release_date_changes IN (0,1)),
 import_system INTEGER NOT NULL DEFAULT 1 CHECK(import_system IN (0,1)),
 challenges INTEGER NOT NULL DEFAULT 0 CHECK(challenges IN (0,1)),
 journal INTEGER NOT NULL DEFAULT 0 CHECK(journal IN (0,1)),
 quests INTEGER NOT NULL DEFAULT 0 CHECK(quests IN (0,1)),
 achievements_levels INTEGER CHECK(achievements_levels IS NULL OR achievements_levels IN (0,1)),
 updated_at TEXT NOT NULL
);
