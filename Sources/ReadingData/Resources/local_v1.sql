CREATE TABLE books (
 id TEXT NOT NULL, owner_id TEXT NOT NULL, title TEXT NOT NULL CHECK(length(trim(title)) > 0),
 author TEXT NOT NULL CHECK(length(trim(author)) > 0), revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0),
 deleted_at TEXT, PRIMARY KEY(owner_id,id)
);
CREATE TABLE library_memberships (
 owner_id TEXT NOT NULL, book_id TEXT NOT NULL, wants_to_read INTEGER NOT NULL DEFAULT 0 CHECK(wants_to_read IN (0,1)),
 added_at TEXT NOT NULL, removed_at TEXT, PRIMARY KEY(owner_id,book_id),
 FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id)
);
CREATE TABLE editions (
 id TEXT NOT NULL, owner_id TEXT NOT NULL, book_id TEXT NOT NULL, language TEXT,
 page_count INTEGER CHECK(page_count > 0), isbn13 TEXT, revision INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,id,book_id),
 FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id)
);
CREATE TABLE readings (
 id TEXT NOT NULL, owner_id TEXT NOT NULL, book_id TEXT NOT NULL, edition_id TEXT,
 status TEXT NOT NULL CHECK(status IN ('currently_reading','read','dnf')),
 current_page INTEGER NOT NULL DEFAULT 0 CHECK(current_page >= 0),
 total_pages INTEGER CHECK(total_pages > 0),
 start_date TEXT, finish_date TEXT,
 rating_state TEXT NOT NULL DEFAULT 'unknown' CHECK(rating_state IN ('unknown','unrated','rated')),
 rating_whole INTEGER, journal_format TEXT CHECK(journal_format IN ('paperback','hardcover','ebook','audiobook')),
 historical INTEGER NOT NULL DEFAULT 0 CHECK(historical IN (0,1)),
 revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0), deleted_at TEXT,
 CHECK(total_pages IS NULL OR current_page <= total_pages),
 CHECK((rating_state = 'rated' AND rating_whole IS NOT NULL AND rating_whole BETWEEN 1 AND 5)
       OR (rating_state <> 'rated' AND rating_whole IS NULL)),
 PRIMARY KEY(owner_id,id),
 FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id),
 FOREIGN KEY(owner_id,edition_id,book_id) REFERENCES editions(owner_id,id,book_id)
);
CREATE INDEX readings_status ON readings(owner_id,status,finish_date);
CREATE INDEX books_search ON books(owner_id,title,author);
CREATE TABLE progress_observations (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, reading_id TEXT NOT NULL,
 mutation_id TEXT NOT NULL, previous_page INTEGER NOT NULL CHECK(previous_page >= 0),
 new_page INTEGER NOT NULL CHECK(new_page >= 0), recorded_at TEXT NOT NULL,
 requires_review INTEGER NOT NULL DEFAULT 0 CHECK(requires_review IN (0,1)),
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,mutation_id),
 FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id)
);
CREATE TABLE field_provenance (
 owner_id TEXT NOT NULL, entity_id TEXT NOT NULL, entity_type TEXT NOT NULL, field TEXT NOT NULL,
 source TEXT NOT NULL, source_ref TEXT, evidence_fingerprint TEXT, user_overridden INTEGER NOT NULL CHECK(user_overridden IN (0,1)),
 PRIMARY KEY(owner_id,entity_type,entity_id,field)
);
CREATE TABLE data_change_proposals (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, entity_id TEXT NOT NULL, entity_type TEXT NOT NULL, field TEXT NOT NULL,
 current_json TEXT NOT NULL, proposed_json TEXT NOT NULL, evidence_fingerprint TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('pending','accepted','kept','edited')),
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,entity_type,entity_id,field,evidence_fingerprint)
);
CREATE TABLE journal_components (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, reading_id TEXT NOT NULL, component TEXT NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('pending','ready','copied','none')), copied_payload TEXT, copied_at TEXT,
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,reading_id,component),
 FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id)
);
CREATE TRIGGER journal_no_dnf BEFORE INSERT ON journal_components
 WHEN (SELECT status FROM readings WHERE owner_id=NEW.owner_id AND id=NEW.reading_id) <> 'read'
 BEGIN SELECT RAISE(ABORT,'Journal requires completed reading'); END;
CREATE TABLE challenge_years (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, year INTEGER NOT NULL,
 version TEXT NOT NULL CHECK((year % 2 = 0 AND version='A') OR (year % 2 <> 0 AND version='B')),
 content_json TEXT NOT NULL, PRIMARY KEY(owner_id,id), UNIQUE(owner_id,year)
);
CREATE TRIGGER challenge_snapshot_no_update BEFORE UPDATE ON challenge_years
 BEGIN SELECT RAISE(ABORT,'Year snapshots are immutable'); END;
CREATE TABLE challenge_prompts (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, year_id TEXT NOT NULL, challenge_key TEXT NOT NULL,
 prompt_key TEXT NOT NULL, text TEXT, is_tbd INTEGER NOT NULL CHECK(is_tbd IN (0,1)),
 CHECK(is_tbd=1 OR (text IS NOT NULL AND length(trim(text))>0)),
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,year_id,challenge_key,prompt_key),
 FOREIGN KEY(owner_id,year_id) REFERENCES challenge_years(owner_id,id)
);
CREATE TRIGGER challenge_prompt_no_update BEFORE UPDATE ON challenge_prompts
 BEGIN SELECT RAISE(ABORT,'Prompt snapshots are immutable'); END;
CREATE TABLE challenge_assignments (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, prompt_id TEXT NOT NULL, reading_id TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('proposed','confirmed','rejected')),
 confidence INTEGER CHECK(confidence BETWEEN 0 AND 100), evidence_fingerprint TEXT,
 PRIMARY KEY(owner_id,id),
 FOREIGN KEY(owner_id,prompt_id) REFERENCES challenge_prompts(owner_id,id),
 FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id)
);
CREATE UNIQUE INDEX one_confirmed_prompt ON challenge_assignments(owner_id,prompt_id) WHERE status='confirmed';
CREATE TRIGGER challenge_no_tbd BEFORE INSERT ON challenge_assignments
 WHEN (SELECT is_tbd FROM challenge_prompts WHERE owner_id=NEW.owner_id AND id=NEW.prompt_id)=1
 BEGIN SELECT RAISE(ABORT,'TBD prompt is unavailable'); END;
CREATE TRIGGER challenge_no_tbd_update BEFORE UPDATE ON challenge_assignments
 WHEN (SELECT is_tbd FROM challenge_prompts WHERE owner_id=NEW.owner_id AND id=NEW.prompt_id)=1
 BEGIN SELECT RAISE(ABORT,'TBD prompt is unavailable'); END;
CREATE TABLE xp_awards (
 owner_id TEXT NOT NULL, semantic_key TEXT NOT NULL, amount INTEGER NOT NULL CHECK(amount>=0),
 awarded_at TEXT NOT NULL, PRIMARY KEY(owner_id,semantic_key)
);
CREATE TRIGGER xp_no_update BEFORE UPDATE ON xp_awards BEGIN SELECT RAISE(ABORT,'XP is permanent'); END;
CREATE TRIGGER xp_no_delete BEFORE DELETE ON xp_awards BEGIN SELECT RAISE(ABORT,'XP is permanent'); END;
CREATE TABLE outbox (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, entity_id TEXT NOT NULL, expected_revision INTEGER NOT NULL,
 generation TEXT NOT NULL, command_version INTEGER NOT NULL, kind TEXT NOT NULL, payload BLOB NOT NULL,
 state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','review')), ordinal INTEGER NOT NULL UNIQUE
);
CREATE INDEX outbox_pending ON outbox(owner_id,state,ordinal);
CREATE TABLE sync_state (
 owner_id TEXT PRIMARY KEY, generation TEXT NOT NULL, pull_cursor INTEGER NOT NULL DEFAULT 0
);
