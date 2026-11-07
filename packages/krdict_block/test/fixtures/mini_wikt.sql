-- Built by tools/dict/build_wikt_glossary.py --sample-sql from
-- tools/dict/testdata/wikt_sample_*.jsonl (made-up entries). Do not edit.
PRAGMA user_version = 2;
CREATE TABLE ja (
  key TEXT NOT NULL,
  reading TEXT NOT NULL,
  kind INTEGER NOT NULL,
  pos INTEGER NOT NULL,
  ending TEXT NOT NULL,
  sense_id INTEGER NOT NULL REFERENCES sense(id)
);
INSERT INTO "ja" VALUES('ゆきやま','',2,0,'',1);
INSERT INTO "ja" VALUES('月路','',1,0,'',2);
INSERT INTO "ja" VALUES('月路','',1,0,'',3);
INSERT INTO "ja" VALUES('月道','つきみち',0,0,'',4);
INSERT INTO "ja" VALUES('月道','つきみち',0,0,'',5);
INSERT INTO "ja" VALUES('雪森','ゆきもり',0,0,'',6);
INSERT INTO "ja" VALUES('雪森','ゆきもり',0,0,'',7);
INSERT INTO "ja" VALUES('雪森','ゆきもり',0,0,'',8);
INSERT INTO "ja" VALUES('雪森る','ゆきもりる',0,0,'',9);
INSERT INTO "ja" VALUES('風森','',1,0,'だ',10);
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
INSERT INTO "meta" VALUES('built_on','2026-11-07');
INSERT INTO "meta" VALUES('keys','10');
INSERT INTO "meta" VALUES('krdict_sqlite_sha256','07fad78fc86575be513d0b4b155042e79e4a4a20489b126904423ff2054c4f08');
INSERT INTO "meta" VALUES('schema','2');
INSERT INTO "meta" VALUES('senses','10');
INSERT INTO "meta" VALUES('sources','wiktionary');
INSERT INTO "meta" VALUES('variant','lean');
INSERT INTO "meta" VALUES('wiktionary.edition','2026-11-01');
INSERT INTO "meta" VALUES('wiktionary.en_edition','2026-10-01');
INSERT INTO "meta" VALUES('wiktionary.license','CC BY-SA 4.0');
INSERT INTO "meta" VALUES('wiktionary.license_url','https://creativecommons.org/licenses/by-sa/4.0/');
INSERT INTO "meta" VALUES('wiktionary.name','위키낱말사전');
INSERT INTO "meta" VALUES('wiktionary.publisher','위키낱말사전(한국어판·영어판) 기여자');
CREATE TABLE sense (
  id INTEGER PRIMARY KEY,
  word TEXT NOT NULL,
  level INTEGER,
  sense_no INTEGER NOT NULL,
  source INTEGER NOT NULL,
  synonyms TEXT NOT NULL,
  pos INTEGER NOT NULL
);
INSERT INTO "sense" VALUES(1,'눈산',NULL,1,1,'눈산',0);
INSERT INTO "sense" VALUES(2,'달길',NULL,1,1,'달길|월로',0);
INSERT INTO "sense" VALUES(3,'월로',NULL,1,1,'달길|월로',0);
INSERT INTO "sense" VALUES(4,'달길',NULL,1,1,'달길|월로',0);
INSERT INTO "sense" VALUES(5,'월로',NULL,1,1,'달길|월로',0);
INSERT INTO "sense" VALUES(6,'눈숲',NULL,1,1,'눈숲|설삼',0);
INSERT INTO "sense" VALUES(7,'설삼',NULL,1,1,'눈숲|설삼',0);
INSERT INTO "sense" VALUES(8,'겨울 숲',NULL,2,1,'겨울 숲',0);
INSERT INTO "sense" VALUES(9,'눈으로 덮다',NULL,1,1,'눈으로 덮다',0);
INSERT INTO "sense" VALUES(10,'바람차다',NULL,1,1,'바람차다',0);
CREATE INDEX ja_key ON ja(key);
CREATE INDEX ja_reading ON ja(reading) WHERE kind = 0;
