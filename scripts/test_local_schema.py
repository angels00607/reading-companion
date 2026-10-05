"""Execute the actual GRDB migration with Python's SQLite engine."""
import pathlib
import sqlite3
import unittest

SCHEMA = pathlib.Path(__file__).resolve().parents[1] / "Sources/ReadingData/Resources/local_v1.sql"
UPGRADES = [SCHEMA.with_name(f"local_v{version}.sql") for version in (2, 3, 4)]


def upgrade(db):
    db.commit()
    db.execute("PRAGMA foreign_keys=OFF")
    try:
        db.executescript("BEGIN;\n" + "\n".join(path.read_text() for path in UPGRADES))
        if db.execute("PRAGMA foreign_key_check").fetchall():
            raise sqlite3.IntegrityError("Migration broke foreign keys")
        db.commit()
    except Exception:
        db.rollback()
        raise
    finally:
        db.execute("PRAGMA foreign_keys=ON")


class LocalSchemaTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.executescript(SCHEMA.read_text())
        upgrade(self.db)
        self.db.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b','u','Book','Author')")
        self.db.execute("INSERT INTO readings(id,owner_id,book_id,status,progress_mode) VALUES('r','u','b','read','page')")
        self.db.commit()

    def rejected(self, sql):
        with self.assertRaises(sqlite3.DatabaseError):
            self.db.execute(sql)

    def test_ownership_and_edition_relationships(self):
        self.rejected("INSERT INTO readings(id,owner_id,book_id,status,progress_mode) VALUES('x','other','b','read','page')")
        self.db.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b2','u','Other','Author')")
        self.db.execute("INSERT INTO editions(id,owner_id,book_id) VALUES('e','u','b2')")
        self.rejected("UPDATE readings SET edition_id='e' WHERE id='r'")

    def test_to_read_is_not_a_reading_status(self):
        self.rejected("UPDATE readings SET status='to_read'")

    def test_rating_and_unknowns(self):
        self.rejected("UPDATE readings SET rating_state='rated',rating_whole=NULL")
        self.rejected("UPDATE readings SET rating_state='rated',rating_whole=0")
        self.db.execute("UPDATE readings SET rating_state='unrated',rating_whole=NULL,total_pages=NULL")

    def test_xp_is_permanent_and_deduplicated(self):
        self.db.execute("INSERT INTO xp_awards VALUES('u','finish:r',10,'now')")
        self.rejected("INSERT INTO xp_awards VALUES('u','finish:r',10,'now')")
        self.rejected("UPDATE xp_awards SET amount=5")
        self.rejected("DELETE FROM xp_awards")
        self.rejected("INSERT INTO xp_awards VALUES('u','bad',-1,'now')")

    def test_challenge_occupancy_tbd_and_snapshots(self):
        self.rejected("INSERT INTO challenge_years VALUES('u','bad',2027,'A','{}')")
        self.db.execute("INSERT INTO challenge_years VALUES('u','y',2027,'B','{}')")
        self.db.execute("INSERT INTO challenge_prompts VALUES('u','p','y','tropes','one','Known',0)")
        self.db.execute("INSERT INTO challenge_prompts VALUES('u','tbd','y','tropes','two',NULL,1)")
        self.db.execute("INSERT INTO challenge_assignments VALUES('u','a','p','r','confirmed',90,'v1')")
        self.rejected("INSERT INTO challenge_assignments VALUES('u','a2','p','r','confirmed',90,'v1')")
        self.rejected("INSERT INTO challenge_assignments VALUES('u','a3','tbd','r','confirmed',90,'v1')")
        self.rejected("UPDATE challenge_assignments SET prompt_id='tbd' WHERE id='a'")
        self.rejected("UPDATE challenge_years SET content_json='changed'")
        self.rejected("UPDATE challenge_prompts SET text='changed'")

    def test_journal_dnf_exclusion(self):
        self.db.execute("UPDATE readings SET status='dnf'")
        self.rejected("INSERT INTO journal_components(owner_id,id,reading_id,component,state,purpose) VALUES('u','j','r','book_review','ready','completion')")

    def test_journal_preparation_and_in_progress_allowed(self):
        self.db.execute("UPDATE readings SET status='currently_reading'")
        self.db.execute("INSERT INTO journal_components(owner_id,id,reading_id,component,state,purpose) VALUES('u','j','r','quote','pending','preparation')")
        self.db.execute("UPDATE readings SET status='dnf'")
        self.rejected("UPDATE journal_components SET purpose='completion' WHERE id='j'")
        self.db.execute("UPDATE journal_components SET state='none' WHERE id='j'")

    def test_page_values_known_and_unknown(self):
        self.db.execute("UPDATE readings SET current_page=187,total_pages=450")
        self.rejected("UPDATE readings SET current_page=451")
        self.rejected("UPDATE readings SET current_page=-1")
        self.rejected("UPDATE readings SET current_page=1.5")
        self.db.execute("UPDATE readings SET total_pages=NULL,current_page=500")

    def test_percentage_range_unknown_and_no_pages(self):
        self.db.execute("UPDATE readings SET progress_mode='percentage',current_page=NULL,total_pages=NULL")
        for percent in (0,42,46.5,100):
            self.db.execute("UPDATE readings SET progress_percentage=?", (percent,))
            row = self.db.execute("SELECT current_page,total_pages,progress_percentage FROM readings").fetchone()
            self.assertEqual(row,(None,None,percent))
        self.db.execute("UPDATE readings SET progress_percentage=NULL")
        self.rejected("UPDATE readings SET progress_percentage=-1")
        self.rejected("UPDATE readings SET progress_percentage=101")
        self.rejected("UPDATE readings SET current_page=292")
        self.rejected("UPDATE readings SET total_pages=450")

    def test_progress_reaching_end_does_not_finish(self):
        self.db.execute("UPDATE readings SET status='currently_reading',current_page=450,total_pages=450")
        self.assertEqual(self.db.execute("SELECT status FROM readings").fetchone()[0],"currently_reading")
        self.db.execute("UPDATE readings SET progress_mode='percentage',current_page=NULL,total_pages=NULL,progress_percentage=100")
        self.assertEqual(self.db.execute("SELECT status FROM readings").fetchone()[0],"currently_reading")

    def test_format_does_not_select_progress_mode(self):
        self.db.execute("UPDATE readings SET progress_mode='percentage',current_page=NULL,total_pages=NULL,progress_percentage=65,journal_format='paperback'")
        self.db.execute("UPDATE readings SET journal_format='audiobook'")
        self.assertEqual(self.db.execute("SELECT progress_mode,progress_percentage FROM readings").fetchone(),("percentage",65))
        self.db.execute("UPDATE readings SET progress_mode='page',progress_percentage=NULL")
        self.assertEqual(self.db.execute("SELECT journal_format,current_page FROM readings").fetchone(),("audiobook",None))

    def test_observation_units_stats_conflicts_and_immutability(self):
        self.db.execute("INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,new_percentage,recorded_at) VALUES('u','o1','r','m1','percentage',65,'now')")
        self.db.execute("INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,new_percentage,recorded_at,requires_review) VALUES('u','o2','r','m2','percentage',90,'later',1)")
        self.assertIsNone(self.db.execute("SELECT SUM(new_page-previous_page) FROM progress_observations WHERE mode='page' AND requires_review=0").fetchone()[0])
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM progress_observations").fetchone()[0],2)
        self.rejected("UPDATE progress_observations SET mode='page',new_page=292,new_percentage=NULL WHERE id='o1'")
        self.rejected("INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,new_page,new_percentage,recorded_at) VALUES('u','bad','r','mb','percentage',292,65,'now')")
        self.db.execute("INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,previous_page,new_page,recorded_at) VALUES('u','o3','r','m3','page',10,20,'now')")
        self.assertEqual(self.db.execute("SELECT SUM(new_page-previous_page) FROM progress_observations WHERE mode='page' AND requires_review=0").fetchone()[0],10)

    def test_dnf_retains_both_units(self):
        self.db.execute("UPDATE readings SET status='dnf',current_page=183")
        self.assertEqual(self.db.execute("SELECT current_page FROM readings").fetchone()[0],183)
        self.db.execute("UPDATE readings SET progress_mode='percentage',current_page=NULL,progress_percentage=46")
        self.assertEqual(self.db.execute("SELECT status,progress_percentage FROM readings").fetchone(),("dnf",46))

    def test_v1_upgrade_preserves_data_and_references(self):
        old = sqlite3.connect(":memory:")
        old.execute("PRAGMA foreign_keys=ON")
        old.executescript(SCHEMA.read_text())
        old.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b','u','Book','Author')")
        old.execute("INSERT INTO readings(id,owner_id,book_id,status,current_page,total_pages) VALUES('r','u','b','read',187,450)")
        old.execute("INSERT INTO progress_observations VALUES('u','o','r','m',100,187,'now',0)")
        old.execute("INSERT INTO journal_components VALUES('u','j','r','book_review','copied','{}','now')")
        upgrade(old)
        self.assertEqual(old.execute("SELECT progress_mode,current_page,total_pages,progress_percentage FROM readings").fetchone(),("page",187,450,None))
        self.assertEqual(old.execute("SELECT mode,previous_page,new_page,new_percentage FROM progress_observations").fetchone(),("page",100,187,None))
        self.assertEqual(old.execute("SELECT purpose,copied_payload FROM journal_components").fetchone(),("completion","{}"))
        self.assertEqual(old.execute("PRAGMA foreign_key_check").fetchall(),[])

    def test_atomic_book_and_outbox_rollback(self):
        self.db.execute("INSERT INTO outbox VALUES('m','u','b',0,'g',1,'book.create',X'7B7D','pending',1)")
        self.db.commit()
        with self.assertRaises(sqlite3.DatabaseError):
            with self.db:
                self.db.execute("INSERT INTO books VALUES('new','u','New','Author',0,NULL)")
                self.db.execute("INSERT INTO outbox VALUES('m','u','new',0,'g',1,'book.create',X'7B7D','pending',2)")
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM books WHERE id='new'").fetchone()[0], 0)
        self.assertEqual(self.db.execute("PRAGMA integrity_check").fetchone()[0], "ok")

    def test_rejection_evidence_uniqueness(self):
        columns = "(owner_id,id,entity_id,entity_type,field,current_json,proposed_json,evidence_fingerprint,status)"
        self.db.execute(f"INSERT INTO data_change_proposals {columns} VALUES('u','p','b','book','title','1','2','v1','kept')")
        self.rejected(f"INSERT INTO data_change_proposals {columns} VALUES('u','q','b','book','title','1','2','v1','pending')")
        self.db.execute(f"INSERT INTO data_change_proposals {columns} VALUES('u','q','b','book','title','1','3','v2','pending')")


if __name__ == "__main__":
    unittest.main(verbosity=2)
