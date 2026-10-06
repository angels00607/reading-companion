"""Phase 5 tests exercise actual forward migrations, ownership and snapshot integrity."""
import pathlib, sqlite3, unittest, json
ROOT = pathlib.Path(__file__).resolve().parents[1]

class ChallengesSchemaTests(unittest.TestCase):
 def setUp(self):
  self.db=sqlite3.connect(':memory:')
  for n in range(1,6): self.db.executescript((ROOT/f'Sources/ReadingData/Resources/local_v{n}.sql').read_text())
  self.db.execute("INSERT INTO books(owner_id,id,title,author) VALUES('u','b','Legacy','Author')")
  self.db.execute("INSERT INTO readings(owner_id,id,book_id,status,progress_mode) VALUES('u','r','b','read','page')")
  self.db.execute("INSERT INTO challenge_years VALUES('u','y',2027,'B','immutable original')")
  self.db.execute("INSERT INTO challenge_prompts VALUES('u','p','y','tropes','one','Known',0)")
  self.db.execute("INSERT INTO challenge_assignments VALUES('u','a','p','r','confirmed',88,'old-evidence')")
  self.db.commit();self.db.executescript((ROOT/'Sources/ReadingData/Resources/local_v6.sql').read_text());self.db.execute('PRAGMA foreign_keys=ON')
 def reject(self,sql):
  with self.assertRaises(sqlite3.DatabaseError): self.db.execute(sql)
 def test_forward_upgrade_preserves_original_content_and_assignment(self):
  self.assertEqual(self.db.execute('SELECT content_json FROM challenge_years').fetchone()[0],'immutable original')
  self.assertEqual(self.db.execute('SELECT confidence,evidence_fingerprint,source FROM challenge_assignments').fetchone(),(88,'old-evidence','legacy'))
  self.assertFalse(self.db.execute('PRAGMA foreign_key_check').fetchall())
 def test_update_delete_snapshot_protection(self):
  for sql in ["UPDATE challenge_years SET content_json='changed'","UPDATE challenge_prompts SET text='changed'","DELETE FROM challenge_years","DELETE FROM challenge_prompts"]:self.reject(sql)
 def test_dnf_cannot_receive_new_assignment(self):
  self.db.execute("INSERT INTO readings(owner_id,id,book_id,status,progress_mode) VALUES('u','dnf','b','dnf','page')")
  self.reject("INSERT INTO challenge_assignments(owner_id,id,prompt_id,reading_id,status) VALUES('u','bad','p','dnf','proposed')")
 def test_occupied_prompt_unique(self):
  self.reject("INSERT INTO challenge_assignments(owner_id,id,prompt_id,reading_id,status) VALUES('u','bad','p','r','confirmed')")
 def test_rejection_identity_durable_and_owner_scoped(self):
  self.db.execute("INSERT INTO challenge_rejections VALUES('u','fingerprint','b','p','now')")
  self.reject("INSERT INTO challenge_rejections VALUES('u','fingerprint','b','p','later')")
  self.reject("INSERT INTO challenge_rejections VALUES('another','fingerprint','b','p','now')")
 def test_analysis_owner_links_and_attention_independent(self):
  self.db.execute("INSERT INTO challenge_analysis VALUES('u','y','r','[]')")
  self.reject("INSERT INTO challenge_analysis VALUES('another','y','r','[]')")
  self.db.execute("INSERT INTO attention_items VALUES('u','i','challenges','a','match-review','open','now')")
  self.reject("INSERT INTO attention_items VALUES('u','bad','quest','a','match-review','open','now')")
 def test_catalog_exact_holes_and_no_rewards(self):
  catalog=json.loads((ROOT/'Sources/ReadingDomain/Resources/challenge_catalog_v2.json').read_text(encoding='utf-8'))
  b=catalog['B'];lookup={(p['challenge'],p['key']):p['text'] for p in b}
  self.assertIsNone(lookup['archetype','prompt.10']);self.assertEqual(lookup['archetype','prompt.11'],'The Immortal')
  self.assertEqual(lookup['monthly','12.1'],'Winter Sport');self.assertIsNone(lookup['monthly','12.2']);self.assertIsNone(lookup['monthly','12.3'])
  self.assertTrue(all(p['text'] is None for p in b if p['challenge']=='roulette'))
  self.assertEqual(len([p for p in b if p['challenge']=='roulette']),10)
  self.assertEqual(self.db.execute('SELECT COUNT(*) FROM xp_awards').fetchone()[0],0)

if __name__=='__main__':unittest.main()
