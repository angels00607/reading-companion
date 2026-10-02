"""Phase 2 migration and invariants against the same SQL shipped to GRDB."""
import pathlib
import sqlite3
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

def database():
    db = sqlite3.connect(':memory:')
    db.executescript((ROOT / 'Sources/ReadingData/Resources/local_v1.sql').read_text())
    db.executescript((ROOT / 'Sources/ReadingData/Resources/local_v2.sql').read_text())
    db.execute('PRAGMA foreign_keys=ON')
    return db

class BooksSchemaTests(unittest.TestCase):
    def test_upgrade_preserves_history_and_provenance(self):
        db = database()
        db.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b','u','Old','Author')")
        db.execute("INSERT INTO readings(id,owner_id,book_id,status,progress_mode,progress_percentage) VALUES('r','u','b','dnf','percentage',57.5)")
        db.execute("INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,new_percentage,recorded_at) VALUES('u','o','r','m','percentage',57.5,'now')")
        db.execute("INSERT INTO field_provenance VALUES('u','b','book','title','manual',NULL,NULL,1)")
        db.commit()
        db.executescript((ROOT / 'Sources/ReadingData/Resources/local_v3.sql').read_text())
        self.assertEqual(db.execute('SELECT progress_percentage,current_page,total_pages FROM readings').fetchone(), (57.5,None,None))
        self.assertEqual(db.execute('SELECT new_percentage,new_page FROM progress_observations').fetchone(), (57.5,None))
        self.assertEqual(db.execute('SELECT user_overridden FROM field_provenance').fetchone(), (1,))
        self.assertFalse(db.execute('PRAGMA foreign_key_check').fetchall())

    def test_provider_link_cannot_cross_owner_or_book(self):
        db = database(); db.executescript((ROOT / 'Sources/ReadingData/Resources/local_v3.sql').read_text())
        db.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b','u','Book','Author')")
        with self.assertRaises(sqlite3.IntegrityError):
            db.execute("INSERT INTO provider_links VALUES('other','b',NULL,'ol','work')")
        self.assertEqual(db.execute('SELECT COUNT(*) FROM readings').fetchone()[0], 0)

    def test_progress_units_and_observations_still_immutable(self):
        db = database(); db.executescript((ROOT / 'Sources/ReadingData/Resources/local_v3.sql').read_text())
        db.execute("INSERT INTO books(id,owner_id,title,author) VALUES('b','u','Book','Author')")
        db.execute("INSERT INTO readings(id,owner_id,book_id,status,progress_mode) VALUES('r','u','b','currently_reading','percentage')")
        with self.assertRaises(sqlite3.IntegrityError): db.execute("UPDATE readings SET current_page=42 WHERE id='r'")
        db.execute("INSERT INTO progress_observations(owner_id,id,reading_id,mutation_id,mode,new_percentage,recorded_at) VALUES('u','o','r','m','percentage',99.25,'now')")
        with self.assertRaises(sqlite3.IntegrityError): db.execute("UPDATE progress_observations SET new_percentage=100 WHERE id='o'")

if __name__ == '__main__': unittest.main()
