-- Built by tools/dict/build_examples.py --sample-sql from
-- tools/dict/testdata/tatoeba_sample/ (made-up sentences) and the JMdict test
-- fixture of packages/dict_jmdict. Do not edit.
PRAGMA user_version = 1;
CREATE TABLE example (
  entry INTEGER NOT NULL,   -- JMdict ent_seq
  reading TEXT NOT NULL,    -- the entry's reading the sentence uses; '' = any
  sentence INTEGER NOT NULL,-- Tatoeba sentence number
  ja TEXT NOT NULL,
  ko TEXT,                  -- Korean translation of this sentence
  en TEXT,                  -- English translation, only without ko
  surface TEXT,             -- the word as written in the sentence, when the index gives it
  PRIMARY KEY (entry, reading)
) WITHOUT ROWID;
INSERT INTO "example" VALUES(1049180,'',114,'コーヒーを飲みます。',NULL,NULL,NULL);
INSERT INTO "example" VALUES(1178960,'',108,'服を汚してしまった。',NULL,NULL,'汚して');
INSERT INTO "example" VALUES(1245280,'から',102,'箱は空です。',NULL,'The box is empty.','空');
INSERT INTO "example" VALUES(1245290,'',101,'空が青いです。','하늘이 파랗습니다.',NULL,'空');
INSERT INTO "example" VALUES(1319210,'しち',105,'七時に起きます。',NULL,NULL,NULL);
INSERT INTO "example" VALUES(1319210,'なな',106,'七回聞きました。',NULL,NULL,NULL);
INSERT INTO "example" VALUES(1381820,'',110,'静かにしなさい。','조용히 하세요.',NULL,'静かに');
INSERT INTO "example" VALUES(1416700,'',104,'棚に本があります。',NULL,NULL,NULL);
INSERT INTO "example" VALUES(1512670,'',107,'図書館で勉強しました。',NULL,'I studied at the library.',NULL);
INSERT INTO "example" VALUES(1522150,'',103,'毎日本を読みます。',NULL,'I read books every day.',NULL);
INSERT INTO "example" VALUES(1542790,'',109,'夕方は静かです。',NULL,'It is quiet in the evening.',NULL);
INSERT INTO "example" VALUES(2028990,'',104,'棚に本があります。',NULL,NULL,NULL);
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
INSERT INTO "meta" VALUES('built_on','2026-11-12');
INSERT INTO "meta" VALUES('examples','12');
INSERT INTO "meta" VALUES('jmdict_created','2026-11-04');
INSERT INTO "meta" VALUES('schema','1');
INSERT INTO "meta" VALUES('source','tatoeba');
INSERT INTO "meta" VALUES('tatoeba.edition','2026-11-07');
INSERT INTO "meta" VALUES('tatoeba.license','CC BY 2.0 FR');
INSERT INTO "meta" VALUES('tatoeba.license_url','https://creativecommons.org/licenses/by/2.0/fr/');
INSERT INTO "meta" VALUES('tatoeba.url','https://tatoeba.org');
INSERT INTO "meta" VALUES('variant','one-per-reading');
