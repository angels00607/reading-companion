CREATE TABLE onboarding_state (
 owner_id TEXT PRIMARY KEY,
 step TEXT NOT NULL CHECK(step IN ('welcome','readingHistorySince','preferredEdition','importOrStartFresh','libraryReady','completed')),
 reading_history_since INTEGER CHECK(reading_history_since IS NULL OR reading_history_since BETWEEN 1000 AND 9999),
 preferred_edition_language TEXT CHECK(preferred_edition_language IS NULL OR preferred_edition_language IN ('en','fr')),
 library_choice TEXT CHECK(library_choice IS NULL OR library_choice IN ('storyGraphImport','startFresh')),
 completed_at TEXT,
 updated_at TEXT NOT NULL
);

-- Owners with durable Phase 0–9 data already used the app before onboarding existed.
-- Mark them complete without changing their library, history, or gamification data.
INSERT OR IGNORE INTO onboarding_state(owner_id,step,reading_history_since,preferred_edition_language,library_choice,completed_at,updated_at)
SELECT owner_id,'completed',COALESCE(reading_since,2020),'en','startFresh',updated_at,updated_at FROM reader_profiles;
INSERT OR IGNORE INTO onboarding_state(owner_id,step,reading_history_since,preferred_edition_language,library_choice,completed_at,updated_at)
SELECT DISTINCT owner_id,'completed',2020,'en','startFresh',strftime('%Y-%m-%dT%H:%M:%SZ','now'),strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM books;
INSERT OR IGNORE INTO onboarding_state(owner_id,step,reading_history_since,preferred_edition_language,library_choice,completed_at,updated_at)
SELECT DISTINCT owner_id,'completed',2020,'en','storyGraphImport',completed_at,completed_at FROM import_runs;
INSERT OR IGNORE INTO onboarding_state(owner_id,step,reading_history_since,preferred_edition_language,library_choice,completed_at,updated_at)
SELECT DISTINCT owner_id,'completed',2020,'en','startFresh',strftime('%Y-%m-%dT%H:%M:%SZ','now'),strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM series;
INSERT OR IGNORE INTO onboarding_state(owner_id,step,reading_history_since,preferred_edition_language,library_choice,completed_at,updated_at)
SELECT DISTINCT owner_id,'completed',2020,'en','startFresh',strftime('%Y-%m-%dT%H:%M:%SZ','now'),strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM challenge_years;
INSERT OR IGNORE INTO onboarding_state(owner_id,step,reading_history_since,preferred_edition_language,library_choice,completed_at,updated_at)
SELECT DISTINCT owner_id,'completed',2020,'en','startFresh',strftime('%Y-%m-%dT%H:%M:%SZ','now'),strftime('%Y-%m-%dT%H:%M:%SZ','now') FROM xp_awards;
