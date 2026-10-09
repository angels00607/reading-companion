ALTER TABLE attention_items ADD COLUMN priority TEXT NOT NULL DEFAULT 'review' CHECK(priority IN ('required','review','optional'));
ALTER TABLE attention_items ADD COLUMN title TEXT NOT NULL DEFAULT 'Review needed';
ALTER TABLE attention_items ADD COLUMN detail TEXT NOT NULL DEFAULT '';
ALTER TABLE attention_items ADD COLUMN source TEXT;
ALTER TABLE attention_items ADD COLUMN action_id TEXT;
ALTER TABLE attention_items ADD COLUMN resolved_at TEXT;

UPDATE attention_items SET title = CASE category
  WHEN 'journal' THEN 'Review a Journal correction'
  WHEN 'series' THEN 'Review a Series update'
  WHEN 'challenges' THEN 'Review a Challenge decision'
  WHEN 'books' THEN 'Review book information'
  WHEN 'import' THEN 'Review imported data'
END,
detail = CASE reason
  WHEN 'finish-order' THEN 'Choose the correct weekly finishing order.'
  WHEN 'match-review' THEN 'Confirm or reject the suggested Challenge match.'
  WHEN 'eligibility-changed' THEN 'Review an assignment affected by changed reading data.'
  ELSE 'Compare the current value with the proposed value.'
END,
action_id = entity_id;

CREATE INDEX attention_unresolved_priority ON attention_items(owner_id,status,priority,created_at);
