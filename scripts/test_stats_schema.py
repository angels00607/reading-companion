"""Phase 6 forward upgrade, private ownership and persisted manual choice checks."""
import pathlib, sqlite3, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class StatsSchemaTests(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect(':memory:')
  for n in range(1,7):self.db.executescript((ROOT/f'Sources/ReadingData/Resources/local_v{n}.sql').read_text())
  self.db.execute("INSERT INTO books(owner_id,id,title,author) VALUES('u','b','Legacy','Author')")
  self.db.execute("INSERT INTO readings(owner_id,id,book_id,status,progress_mode,progress_percentage,finish_date) VALUES('u','r','b','read','percentage',100,NULL)")
  self.db.commit();self.db.executescript((ROOT/'Sources/ReadingData/Resources/local_v7.sql').read_text());self.db.execute('PRAGMA foreign_keys=ON')
 def reject(self,sql):
  with self.assertRaises(sqlite3.DatabaseError):self.db.execute(sql)
 def test_upgrade_preserves_unknown_dates_and_original_unit(self):
  self.assertEqual(self.db.execute('SELECT progress_mode,current_page,progress_percentage,finish_date FROM readings').fetchone(),('percentage',None,100,None))
  self.assertEqual(self.db.execute('SELECT count(*) FROM reading_activity_dates').fetchone()[0],0)
  self.assertFalse(self.db.execute('PRAGMA foreign_key_check').fetchall())
 def test_manual_month_and_year_independent_unique_and_clearable(self):
  self.db.execute("INSERT INTO best_book_selections VALUES('u','m','month','2026-09','r',1,'now','now')")
  self.db.execute("INSERT INTO best_book_selections VALUES('u','y','year','2026','r',1,'now','now')")
  self.reject("INSERT INTO best_book_selections VALUES('u','dup','month','2026-09','r',1,'now','now')")
  self.db.execute("UPDATE best_book_selections SET reading_id=NULL,revision=2 WHERE id='m'")
  self.assertEqual(self.db.execute("SELECT reading_id FROM best_book_selections WHERE id='y'").fetchone()[0],'r')
 def test_cross_owner_selection_and_activity_rejected(self):
  self.reject("INSERT INTO best_book_selections VALUES('other','m','month','2026-09','r',1,'now','now')")
  self.reject("INSERT INTO reading_activity_dates VALUES('other','r','2026-09-01','user','Explicit date','now')")
 def test_scope_period_validation(self):
  for scope,period in [('lifetime','2026'),('month','2026-13'),('month','2026'),('year','2026-09')]:
   self.reject(f"INSERT INTO best_book_selections VALUES('u','bad','{scope}','{period}','r',1,'now','now')")
 def test_activity_requires_user_evidence_and_date_unique(self):
  self.reject("INSERT INTO reading_activity_dates VALUES('u','r','2026-09-01','provider','ISBN','now')")
  self.reject("INSERT INTO reading_activity_dates VALUES('u','r','2026-09-01','user','','now')")
  self.db.execute("INSERT INTO reading_activity_dates VALUES('u','r','2026-09-01','user','Explicit date','now')")
  self.reject("INSERT INTO reading_activity_dates VALUES('u','r','2026-09-01','user','Retry','now')")
 def test_data_does_not_generate_rewards_or_aggregates(self):
  self.assertEqual(self.db.execute('SELECT count(*) FROM xp_awards').fetchone()[0],0)
  self.assertEqual(self.db.execute('SELECT count(*) FROM best_book_selections').fetchone()[0],0)
if __name__=='__main__':unittest.main()
