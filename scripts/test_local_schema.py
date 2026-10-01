"""Execute the actual GRDB migration with Python's SQLite engine."""
import pathlib
import sqlite3
import unittest

SCHEMA = pathlib.Path(__file__).resolve().parents[1] / "Sources/ReadingData/Resources/local_v1.sql"


class LocalSchemaTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(":memory:")
        self.db.execute("PRAGMA foreign_keys=ON")
        self.db.executescript(SCHEMA.read_text())
        self.db.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b','u','Book','Author')")
        self.db.execute("INSERT INTO readings(id,owner_id,book_id,status) VALUES('r','u','b','read')")
        self.db.commit()

    def rejected(self, sql):
        with self.assertRaises(sqlite3.DatabaseError):
            self.db.execute(sql)

    def test_ownership_and_edition_relationships(self):
        self.rejected("INSERT INTO readings(id,owner_id,book_id,status) VALUES('x','other','b','read')")
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
        self.rejected("INSERT INTO journal_components VALUES('u','j','r','book_review','ready',NULL,NULL)")

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
        self.db.execute("INSERT INTO data_change_proposals VALUES('u','p','b','book','title','1','2','v1','kept')")
        self.rejected("INSERT INTO data_change_proposals VALUES('u','q','b','book','title','1','2','v1','pending')")
        self.db.execute("INSERT INTO data_change_proposals VALUES('u','q','b','book','title','1','3','v2','pending')")


if __name__ == "__main__":
    unittest.main(verbosity=2)
