-- Phase 6 additive facts and manual decisions. Old progress/date data stays untouched.
CREATE TABLE best_book_selections (
 owner_id TEXT NOT NULL, id TEXT NOT NULL, scope TEXT NOT NULL CHECK(scope IN ('month','year')),
 period TEXT NOT NULL, reading_id TEXT, revision INTEGER NOT NULL DEFAULT 1 CHECK(revision>=1),
 created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
 CHECK((scope='month' AND length(period)=7 AND period GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]' AND CAST(substr(period,6,2) AS INTEGER) BETWEEN 1 AND 12)
    OR (scope='year' AND length(period)=4 AND period GLOB '[0-9][0-9][0-9][0-9]')),
 PRIMARY KEY(owner_id,id), UNIQUE(owner_id,scope,period),
 FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id)
);
CREATE TABLE reading_activity_dates (
 owner_id TEXT NOT NULL, reading_id TEXT NOT NULL, activity_date TEXT NOT NULL,
 source TEXT NOT NULL CHECK(source='user'), source_reference TEXT NOT NULL CHECK(length(trim(source_reference))>0),
 recorded_at TEXT NOT NULL,
 CHECK(length(activity_date)=10 AND activity_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
 PRIMARY KEY(owner_id,reading_id,activity_date),
 FOREIGN KEY(owner_id,reading_id) REFERENCES readings(owner_id,id)
);
CREATE INDEX stats_completed ON readings(owner_id,status,deleted_at,finish_date);
CREATE INDEX stats_activity_date ON reading_activity_dates(owner_id,activity_date);
