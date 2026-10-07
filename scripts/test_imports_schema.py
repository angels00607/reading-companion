"""Phase 8 additive migration, historical isolation and owner-scoped identity checks."""
import pathlib,sqlite3,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class ImportSchemaTests(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect(':memory:');self.db.execute('PRAGMA foreign_keys=ON')
  for n in range(1,11):self.db.executescript((ROOT/f'Sources/ReadingData/Resources/local_v{n}.sql').read_text(encoding='utf-8'))
 def reject(self,sql):
  with self.assertRaises(sqlite3.DatabaseError):self.db.execute(sql)
 def test_upgrade_does_not_replay_history(self):
  for t in ('xp_awards','gamification_activity','journal_entries','challenge_assignments','import_runs'):
   self.assertEqual(self.db.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0],0)
 def test_history_idempotent_and_immutable(self):
  self.db.execute("INSERT INTO import_runs VALUES('u','r','fp','now',1,1,1,0,0)")
  self.reject("INSERT INTO import_runs VALUES('u','r2','fp','now',1,1,1,0,0)")
  self.reject("UPDATE import_runs SET new_books=0");self.reject('DELETE FROM import_runs')
 def test_pending_evidence_requires_owning_run(self):
  self.db.execute("INSERT INTO import_runs VALUES('u','r','fp','now',1,0,0,1,0)")
  self.reject("INSERT INTO import_candidates VALUES('other','c','r','{}','cf','pending')")
  self.db.execute("INSERT INTO import_candidates VALUES('u','c','r','{}','cf','pending')")
  self.reject("UPDATE import_candidates SET status='accepted-silently'")
 def test_occurrence_deduplication_and_owner_isolation(self):
  self.db.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b','u','Book','Author')")
  self.db.execute("INSERT INTO import_occurrences VALUES('u','uid',0,'b',NULL,NULL)")
  self.reject("INSERT INTO import_occurrences VALUES('u','uid',0,'b',NULL,NULL)")
  self.reject("INSERT INTO import_occurrences VALUES('other','uid',0,'b',NULL,NULL)")
 def test_history_counts_cannot_be_negative(self):
  self.reject("INSERT INTO import_runs VALUES('u','r','fp','now',1,-1,0,0,0)")
 def test_no_raw_csv_format_or_secrets_columns(self):
  for t in ('import_runs','import_candidates','import_occurrences'):
   self.assertFalse({'journal_format','raw_csv','token'} & {r[1] for r in self.db.execute(f'PRAGMA table_info({t})')})
 def test_seeded_v9_upgrade_preserves_manual_facts_and_permanent_xp(self):
  db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON')
  for n in range(1,10):db.executescript((ROOT/f'Sources/ReadingData/Resources/local_v{n}.sql').read_text(encoding='utf-8'))
  db.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b','u','Corrected title','Author')")
  db.execute("INSERT INTO readings(id,owner_id,book_id,status,progress_mode,current_page,historical,journal_format) VALUES('r','u','b','read','page',NULL,1,'paperback')")
  db.execute("INSERT INTO xp_awards VALUES('u','legitimate-award',100,'now')")
  db.executescript((ROOT/'Sources/ReadingData/Resources/local_v10.sql').read_text(encoding='utf-8'))
  self.assertEqual(db.execute('SELECT current_page,finish_date,journal_format,historical FROM readings').fetchone(),(None,None,'paperback',1))
  self.assertEqual(db.execute('SELECT title FROM books').fetchone()[0],'Corrected title')
  self.assertEqual(db.execute('SELECT amount FROM xp_awards').fetchone()[0],100)
  self.assertFalse(db.execute('PRAGMA foreign_key_check').fetchall())
 def test_occurrence_cannot_link_reading_to_another_book(self):
  self.db.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b1','u','One','Author'),('b2','u','Two','Author')")
  self.db.execute("INSERT INTO readings(id,owner_id,book_id,status,progress_mode,current_page,historical) VALUES('r','u','b1','read','page',NULL,1)")
  self.reject("INSERT INTO import_occurrences VALUES('u','uid',1,'b2','r',NULL)")
if __name__=='__main__':unittest.main()
