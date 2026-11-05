"""Unit tests for build_app_asset.py on a tiny made-up JMdict file (no network).

  python3 -m unittest discover -s tools/dict -p 'test_*.py'
"""
from __future__ import annotations

import gzip
import hashlib
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import build_app_asset as asset  # noqa: E402

# Same shape as JMdict_e: internal DTD with entities, creation comment, entries.
TINY_JMDICT = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE JMdict [
<!ENTITY n "noun (common) (futsuumeishi)">
<!ENTITY num "numeric">
]>
<!-- JMdict created: 2026-01-02 -->
<JMdict>
<entry>
<ent_seq>1</ent_seq>
<k_ele><keb>二</keb><ke_pri>news1</ke_pri><ke_pri>nf01</ke_pri></k_ele>
<r_ele><reb>に</reb><re_pri>news1</re_pri><re_pri>nf01</re_pri></r_ele>
<sense><pos>&num;</pos><gloss>two</gloss></sense>
</entry>
<entry>
<ent_seq>2</ent_seq>
<k_ele><keb>空</keb></k_ele>
<r_ele><reb>そら</reb></r_ele>
<sense><pos>&n;</pos><gloss>sky</gloss></sense>
</entry>
</JMdict>
"""


class BuildAppAssetTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.source = self.tmp / "JMdict_e.gz"
        self.source.write_bytes(gzip.compress(TINY_JMDICT.encode("utf-8"), mtime=0))
        self.source_sha = hashlib.sha256(self.source.read_bytes()).hexdigest()
        self.out = self.tmp / "assets" / "dict"

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_writes_the_gzip_and_the_edition_where_the_app_reads_them(self) -> None:
        edition = asset.build_asset(self.source, self.out, built_on="2026-11-05")
        self.assertEqual(sorted(p.name for p in self.out.iterdir()),
                         ["jmdict-full-lean.edition.json", "jmdict-full-lean.sqlite.gz"])
        on_disk = json.loads((self.out / "jmdict-full-lean.edition.json").read_text(encoding="utf-8"))
        self.assertEqual(on_disk, edition)

    def test_edition_records_the_source_and_the_build_day(self) -> None:
        edition = asset.build_asset(self.source, self.out, built_on="2026-11-05")
        self.assertEqual(edition["variant"], "full-lean")
        self.assertEqual(edition["source_sha256"], self.source_sha)
        self.assertEqual(edition["jmdict_created"], "2026-01-02")
        self.assertEqual(edition["built_on"], "2026-11-05")

    def test_the_gzip_holds_a_lean_database_with_its_meta(self) -> None:
        edition = asset.build_asset(self.source, self.out, built_on="2026-11-05")
        raw = gzip.decompress((self.out / "jmdict-full-lean.sqlite.gz").read_bytes())
        self.assertEqual(edition["sqlite_bytes"], len(raw))
        self.assertEqual(edition["sqlite_sha256"], hashlib.sha256(raw).hexdigest())
        db_path = self.tmp / "check.sqlite"
        db_path.write_bytes(raw)
        with sqlite3.connect(db_path) as db:
            meta = dict(db.execute("SELECT key, value FROM meta"))
            self.assertEqual(meta["source_sha256"], self.source_sha)
            self.assertEqual(meta["entries"], "all")
            self.assertEqual(meta["glosses"], "none")
            self.assertEqual(db.execute("SELECT count(*) FROM sense").fetchone()[0], 0)
            self.assertEqual(db.execute("SELECT count(*) FROM entry").fetchone()[0], 2)

    def test_same_source_and_day_give_the_same_files(self) -> None:
        asset.build_asset(self.source, self.out, built_on="2026-11-05")
        first = (self.out / "jmdict-full-lean.sqlite.gz").read_bytes()
        asset.build_asset(self.source, self.out, built_on="2026-11-05")
        self.assertEqual((self.out / "jmdict-full-lean.sqlite.gz").read_bytes(), first)

    def test_a_different_source_than_expected_stops_without_writing(self) -> None:
        with self.assertRaises(SystemExit):
            asset.build_asset(self.source, self.out, built_on="2026-11-05", expect_sha256="0" * 64)
        self.assertFalse(self.out.exists() and any(self.out.iterdir()))

    def test_a_malformed_build_day_is_refused(self) -> None:
        with self.assertRaises(SystemExit):
            asset.build_asset(self.source, self.out, built_on="5 Nov")


if __name__ == "__main__":
    unittest.main()
