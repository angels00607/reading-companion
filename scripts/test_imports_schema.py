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
if __name__=='__main__':unittest.main()
