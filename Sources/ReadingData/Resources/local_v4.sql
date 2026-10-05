CREATE TABLE journal_entries (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, reading_id TEXT NOT NULL, book_id TEXT NOT NULL,
 summary TEXT, page_count INTEGER CHECK(page_count IS NULL OR page_count>0), volume_id TEXT, created_at TEXT NOT NULL,
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,reading_id),
 FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id),
 FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id)
);
CREATE TABLE favorites (
 owner_id TEXT NOT NULL, book_id TEXT NOT NULL, decision TEXT NOT NULL CHECK(decision IN ('pending','selected','none')),
 volume_id TEXT, copied_at TEXT, PRIMARY KEY(owner_id,book_id),
 FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id)
);
CREATE TABLE quotes (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, book_id TEXT NOT NULL, reading_id TEXT,
 quote_text TEXT NOT NULL CHECK(length(trim(quote_text))>0), source TEXT,
 include_in_journal INTEGER NOT NULL CHECK(include_in_journal IN (0,1)), volume_id TEXT, copied_at TEXT,
 PRIMARY KEY(owner_id,id), FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id),
 FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id)
);
CREATE TABLE journal_volumes (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, number INTEGER NOT NULL CHECK(number>0),
 archived INTEGER NOT NULL DEFAULT 0 CHECK(archived IN (0,1)), created_at TEXT NOT NULL, archived_at TEXT,
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,number)
);
CREATE TABLE journal_corrections (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, reading_id TEXT NOT NULL, component TEXT NOT NULL,
 field TEXT NOT NULL, previous_value TEXT NOT NULL, current_value TEXT NOT NULL,
 status TEXT NOT NULL CHECK(status IN ('pending','resolved')), created_at TEXT NOT NULL, resolved_at TEXT,
 PRIMARY KEY(owner_id,id), FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id)
);
CREATE INDEX journal_inbox_state ON journal_components(owner_id,component,state);
CREATE INDEX journal_correction_state ON journal_corrections(owner_id,status,created_at);
CREATE INDEX quote_physical ON quotes(owner_id,include_in_journal,copied_at);
