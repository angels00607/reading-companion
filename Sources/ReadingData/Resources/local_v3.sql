-- Books Core, additive only. No historical observations or copied payloads change.
ALTER TABLE books ADD COLUMN cover_ref TEXT;
ALTER TABLE books ADD COLUMN synopsis TEXT;
ALTER TABLE books ADD COLUMN series_name TEXT;
ALTER TABLE books ADD COLUMN genre_suggestion TEXT;
ALTER TABLE editions ADD COLUMN edition_title TEXT;
ALTER TABLE editions ADD COLUMN isbn10 TEXT;
ALTER TABLE editions ADD COLUMN cover_ref TEXT;
ALTER TABLE editions ADD COLUMN publisher TEXT;
ALTER TABLE readings ADD COLUMN primary_genre TEXT;
ALTER TABLE progress_observations ADD COLUMN ordinal INTEGER NOT NULL DEFAULT 0;
ALTER TABLE data_change_proposals ADD COLUMN source TEXT;
CREATE TABLE provider_links (
 owner_id TEXT NOT NULL, book_id TEXT NOT NULL, edition_id TEXT,
 provider TEXT NOT NULL, reference TEXT NOT NULL,
 PRIMARY KEY(owner_id,book_id,provider,reference),
 FOREIGN KEY(owner_id,book_id) REFERENCES books(owner_id,id),
 FOREIGN KEY(owner_id,edition_id,book_id) REFERENCES editions(owner_id,id,book_id)
);
CREATE INDEX provider_identity ON provider_links(owner_id,provider,reference);
CREATE INDEX edition_isbn ON editions(owner_id,isbn13,isbn10);
CREATE INDEX membership_added ON library_memberships(owner_id,removed_at,added_at);
