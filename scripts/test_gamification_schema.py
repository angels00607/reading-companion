"""Phase 7 additive migration, permanent XP, Quest and private-profile checks."""
import pathlib,sqlite3,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Phase7SchemaTests(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect(':memory:')
  self.db.execute('PRAGMA foreign_keys=ON')
  for n in range(1,10):self.db.executescript((ROOT/f'Sources/ReadingData/Resources/local_v{n}.sql').read_text())
 def reject(self,sql):
  with self.assertRaises(sqlite3.DatabaseError):self.db.execute(sql)
 def test_profile_and_exact_featured_payload_are_private_rows(self):
  self.db.execute("INSERT INTO reader_profiles VALUES('u','Reader','person.crop.circle.fill',2020,'[]',NULL,NULL,NULL,'[\"a\",\"b\",\"c\"]','now')")
  self.assertEqual(self.db.execute('SELECT reading_since FROM reader_profiles').fetchone()[0],2020)
 def test_xp_ledger_and_metadata_are_permanent_and_idempotent(self):
  self.db.execute("INSERT INTO xp_awards VALUES('u','finish:r',100,'now')");self.db.execute("INSERT INTO xp_award_metadata VALUES('u','finish:r','finishBook')")
  self.reject("INSERT INTO xp_awards VALUES('u','finish:r',100,'later')");self.reject("UPDATE xp_awards SET amount=0");self.reject("DELETE FROM xp_award_metadata")
 def test_quests_validate_progress_and_cadence(self):
  self.db.execute("INSERT INTO quest_instances VALUES('u','q','pages.genuine','daily','2026-10-06','Turn pages','recorded pages',10,4,NULL,NULL)")
  self.reject("UPDATE quest_instances SET progress=11")
  self.reject("INSERT INTO quest_instances VALUES('u','x','x','yearly','2026','x','x',1,0,NULL,NULL)")
 def test_achievement_unlock_and_cosmetic_states_have_no_economy(self):
  self.db.execute("INSERT INTO achievement_progress VALUES('u','books.first',1,'now')");self.db.execute("INSERT INTO user_cosmetics VALUES('u','frame.classic','equipped','now')")
  self.reject("INSERT INTO user_cosmetics VALUES('u','bad','rare','now')")
  self.assertFalse(self.db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name IN ('currency','loot','offers')").fetchall())
 def test_clean_upgrade_does_not_retroactively_award(self):
  self.assertEqual(self.db.execute('SELECT count(*) FROM xp_awards').fetchone()[0],0);self.assertEqual(self.db.execute('SELECT count(*) FROM quest_instances').fetchone()[0],0)
 def test_live_activity_is_owner_scoped_unique_and_immutable(self):
  self.db.execute("INSERT INTO gamification_activity VALUES('u','progress:o','progress','r',1,'2026-10-05','now')")
  self.reject("INSERT INTO gamification_activity VALUES('u','progress:o','progress','r',1,'2026-10-05','later')")
  self.reject("UPDATE gamification_activity SET quantity=9")
  self.reject("DELETE FROM gamification_activity")
  self.reject("INSERT INTO gamification_activity VALUES('u','bad','sessions','r',1,'2026-10-05','now')")
 def test_lifecycle_preserves_history_and_enforces_owner_fk_and_slot(self):
  self.db.execute("INSERT INTO quest_instances VALUES('u','q','progress.record','daily','2026-10-05','Record','updates',1,0,NULL,NULL)")
  self.db.execute("INSERT INTO quest_lifecycle VALUES('u','q',0,0,'now')")
  self.reject("INSERT INTO quest_lifecycle VALUES('other','q',0,0,'now')")
  self.reject("UPDATE quest_lifecycle SET slot=3")
  self.reject("UPDATE quest_lifecycle SET baseline=-1")
  self.assertEqual(self.db.execute('SELECT COUNT(*) FROM quest_instances').fetchone()[0],1)
 def test_cosmetic_catalog_and_level_are_enforced_in_storage(self):
  self.reject("INSERT INTO user_cosmetics VALUES('u','invented','equipped','now')")
  self.reject("INSERT INTO user_cosmetics VALUES('u','accent.berry','equipped','now')")
  self.db.execute("INSERT INTO xp_awards VALUES('u','finish:r',100,'now')")
  for n in range(4):self.db.execute("INSERT INTO xp_awards VALUES('u',?,100,'now')",(f'finish:{n}',))
  self.db.execute("INSERT INTO user_cosmetics VALUES('u','accent.berry','equipped','now')")
  self.assertEqual(self.db.execute('SELECT state FROM user_cosmetics').fetchone()[0],'equipped')
 def test_v8_upgrade_preserves_earned_state_without_live_backfill(self):
  old=sqlite3.connect(':memory:');old.execute('PRAGMA foreign_keys=ON')
  for n in range(1,9):old.executescript((ROOT/f'Sources/ReadingData/Resources/local_v{n}.sql').read_text())
  old.execute("INSERT INTO xp_awards VALUES('u','quest:earned',20,'before')")
  old.execute("INSERT INTO xp_award_metadata VALUES('u','quest:earned','dailyQuest')")
  old.execute("INSERT INTO quest_instances VALUES('u','earned','progress.record','daily','2026-10-05','Record','updates',1,1,'before',NULL)")
  old.execute("INSERT INTO achievement_progress VALUES('u','books.first',1,'before')")
  old.execute("INSERT INTO user_cosmetics VALUES('u','frame.classic','equipped','before')")
  old.executescript((ROOT/'Sources/ReadingData/Resources/local_v9.sql').read_text())
  self.assertEqual(old.execute('SELECT amount FROM xp_awards').fetchall(),[(20,)])
  self.assertEqual(old.execute('SELECT completed_at FROM quest_instances').fetchone()[0],'before')
  self.assertEqual(old.execute('SELECT unlocked_at FROM achievement_progress').fetchone()[0],'before')
  self.assertEqual(old.execute('SELECT state FROM user_cosmetics').fetchone()[0],'equipped')
  self.assertEqual(old.execute('SELECT count(*) FROM gamification_activity').fetchone()[0],0)
if __name__=='__main__':unittest.main()
