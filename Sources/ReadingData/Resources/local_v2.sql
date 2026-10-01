-- Forward migration. Existing page observations are copied, never converted.
DROP TRIGGER journal_no_dnf;
CREATE TABLE readings_v2 (
 id TEXT NOT NULL, owner_id TEXT NOT NULL, book_id TEXT NOT NULL, edition_id TEXT,
 status TEXT NOT NULL CHECK(status IN ('currently_reading','read','dnf')),
 progress_mode TEXT NOT NULL CHECK(progress_mode IN ('page','percentage')),
 current_page INTEGER CHECK(current_page IS NULL OR (current_page>=0 AND typeof(current_page)='integer')),
 total_pages INTEGER CHECK(total_pages IS NULL OR (total_pages>0 AND typeof(total_pages)='integer')),
 progress_percentage REAL CHECK(progress_percentage>=0 AND progress_percentage<=100),
 start_date TEXT, finish_date TEXT,
 rating_state TEXT NOT NULL DEFAULT 'unknown' CHECK(rating_state IN ('unknown','unrated','rated')),
 rating_whole INTEGER, journal_format TEXT CHECK(journal_format IN ('paperback','hardcover','ebook','audiobook')),
 historical INTEGER NOT NULL DEFAULT 0 CHECK(historical IN (0,1)),
 revision INTEGER NOT NULL DEFAULT 0 CHECK(revision>=0), deleted_at TEXT,
 CHECK(total_pages IS NULL OR current_page IS NULL OR current_page<=total_pages),
 CHECK((progress_mode='page' AND progress_percentage IS NULL)
   OR (progress_mode='percentage' AND current_page IS NULL AND total_pages IS NULL)),
 CHECK((rating_state='rated' AND rating_whole IS NOT NULL AND rating_whole BETWEEN 1 AND 5)
   OR (rating_state<>'rated' AND rating_whole IS NULL)),
 PRIMARY KEY(owner_id,id),
 FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id),
 FOREIGN KEY(owner_id,edition_id,book_id) REFERENCES editions(owner_id,id,book_id)
);
INSERT INTO readings_v2
 SELECT id,owner_id,book_id,edition_id,status,'page',current_page,total_pages,NULL,
 start_date,finish_date,rating_state,rating_whole,journal_format,historical,revision,deleted_at FROM readings;
CREATE TABLE progress_observations_v2 (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, reading_id TEXT NOT NULL,
 mutation_id TEXT NOT NULL, mode TEXT NOT NULL CHECK(mode IN ('page','percentage')),
 previous_page INTEGER CHECK(previous_page IS NULL OR (previous_page>=0 AND typeof(previous_page)='integer')),
 new_page INTEGER CHECK(new_page IS NULL OR (new_page>=0 AND typeof(new_page)='integer')),
 total_pages INTEGER CHECK(total_pages IS NULL OR (total_pages>0 AND typeof(total_pages)='integer')),
 previous_percentage REAL CHECK(previous_percentage>=0 AND previous_percentage<=100),
 new_percentage REAL CHECK(new_percentage>=0 AND new_percentage<=100),
 recorded_at TEXT NOT NULL, base_revision INTEGER NOT NULL DEFAULT 0 CHECK(base_revision>=0),
 requires_review INTEGER NOT NULL DEFAULT 0 CHECK(requires_review IN (0,1)),
 CHECK((mode='page' AND new_page IS NOT NULL AND previous_percentage IS NULL AND new_percentage IS NULL)
   OR (mode='percentage' AND new_percentage IS NOT NULL AND previous_page IS NULL AND new_page IS NULL AND total_pages IS NULL)),
 CHECK(total_pages IS NULL OR new_page IS NULL OR new_page<=total_pages),
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,mutation_id),
 FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id)
);
INSERT INTO progress_observations_v2(owner_id,id,reading_id,mutation_id,mode,previous_page,new_page,recorded_at,requires_review)
 SELECT owner_id,id,reading_id,mutation_id,'page',previous_page,new_page,recorded_at,requires_review FROM progress_observations;
DROP TABLE progress_observations;
DROP TABLE readings;
ALTER TABLE readings_v2 RENAME TO readings;
ALTER TABLE progress_observations_v2 RENAME TO progress_observations;
CREATE INDEX readings_status ON readings(owner_id,status,finish_date);
CREATE TRIGGER progress_original_unit BEFORE UPDATE OF mode,previous_page,new_page,total_pages,previous_percentage,new_percentage ON progress_observations
 BEGIN SELECT RAISE(ABORT,'Original progress observations are immutable'); END;
ALTER TABLE journal_components ADD COLUMN purpose TEXT NOT NULL DEFAULT 'completion' CHECK(purpose IN ('preparation','completion'));
CREATE TRIGGER journal_no_dnf BEFORE INSERT ON journal_components
 WHEN NEW.purpose='completion' AND
 (SELECT status FROM readings WHERE owner_id=NEW.owner_id AND id=NEW.reading_id)='dnf'
 BEGIN SELECT RAISE(ABORT,'DNF cannot generate completion Journal work'); END;
CREATE TRIGGER journal_no_dnf_update BEFORE UPDATE ON journal_components
 WHEN NEW.purpose='completion' AND
 (SELECT status FROM readings WHERE owner_id=NEW.owner_id AND id=NEW.reading_id)='dnf'
 BEGIN SELECT RAISE(ABORT,'DNF cannot generate completion Journal work'); END;
