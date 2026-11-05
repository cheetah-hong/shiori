-- Built by tools/dict/build_ko_glossary.py --sample-sql from
-- tools/dict/testdata/krdict_sample.json (made-up entries). Do not edit.
PRAGMA user_version = 1;
CREATE TABLE ja (
  key TEXT NOT NULL,
  reading TEXT NOT NULL,
  kind INTEGER NOT NULL,
  pos INTEGER NOT NULL,
  ending TEXT NOT NULL,
  sense_id INTEGER NOT NULL REFERENCES sense(id)
);
INSERT INTO "ja" VALUES('食堂','しょくどう',0,0,'',1);
INSERT INTO "ja" VALUES('れすとらん','',2,1,'',1);
INSERT INTO "ja" VALUES('食道','しょくどう',0,0,'',2);
INSERT INTO "ja" VALUES('有名','ゆうめい',0,0,'だ',3);
INSERT INTO "ja" VALUES('勉強','べんきょう',0,0,'',4);
INSERT INTO "ja" VALUES('ただ','',2,0,'',5);
INSERT INTO "ja" VALUES('単に','たんに',0,1,'',5);
INSERT INTO "ja" VALUES('ただ','',2,0,'',6);
INSERT INTO "ja" VALUES('専ら','もっぱら',0,1,'',6);
INSERT INTO "ja" VALUES('ひたすら','',2,0,'',7);
INSERT INTO "ja" VALUES('ただ','',2,0,'',8);
INSERT INTO "ja" VALUES('只','ただ',0,0,'',9);
INSERT INTO "ja" VALUES('無料','むりょう',0,1,'',9);
INSERT INTO "ja" VALUES('只','ただ',0,0,'',10);
INSERT INTO "ja" VALUES('唯','ただ',0,0,'',10);
INSERT INTO "ja" VALUES('喫茶店','きっさてん',0,0,'',11);
INSERT INTO "ja" VALUES('かふぇ','',2,0,'',12);
INSERT INTO "ja" VALUES('喫茶店','きっさてん',0,1,'',12);
INSERT INTO "ja" VALUES('皿','さら',0,0,'',13);
INSERT INTO "ja" VALUES('皿','さら',0,0,'',14);
INSERT INTO "ja" VALUES('器','うつわ',0,1,'',14);
INSERT INTO "ja" VALUES('味わい','あじわい',0,0,'',15);
INSERT INTO "ja" VALUES('味','あじ',0,0,'',16);
INSERT INTO "ja" VALUES('味','あじ',0,0,'',17);
INSERT INTO "ja" VALUES('掛ける','かける',0,0,'',18);
INSERT INTO "ja" VALUES('座る','すわる',0,0,'',19);
INSERT INTO "ja" VALUES('掛ける','かける',0,0,'',20);
INSERT INTO "ja" VALUES('腰掛ける','こしかける',0,1,'',20);
INSERT INTO "ja" VALUES('掛ける','かける',0,0,'',21);
INSERT INTO "ja" VALUES('近い','ちかい',0,0,'',22);
INSERT INTO "ja" VALUES('近い','ちかい',0,0,'',23);
INSERT INTO "ja" VALUES('鼻','はな',0,0,'',24);
INSERT INTO "ja" VALUES('花','はな',0,0,'',25);
INSERT INTO "ja" VALUES('ちぇこ語','ちぇこご',0,0,'',26);
INSERT INTO "ja" VALUES('たばこ','',2,0,'',27);
INSERT INTO "ja" VALUES('村','そん',0,0,'',28);
INSERT INTO "ja" VALUES('村','むら',0,0,'',28);
INSERT INTO "ja" VALUES('一番','いちばん',0,0,'',29);
INSERT INTO "ja" VALUES('どきどき','',2,0,'',30);
INSERT INTO "ja" VALUES('どきどき','',2,1,'する',30);
INSERT INTO "ja" VALUES('掠る','かする',0,0,'',31);
INSERT INTO "ja" VALUES('辞書','じしょ',0,0,'',32);
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
INSERT INTO "meta" VALUES('built_on','2026-11-05');
INSERT INTO "meta" VALUES('keys','42');
INSERT INTO "meta" VALUES('krdict.edition','2026-10-19');
INSERT INTO "meta" VALUES('krdict.license','CC BY-SA 2.0 KR');
INSERT INTO "meta" VALUES('krdict.license_url','https://creativecommons.org/licenses/by-sa/2.0/kr/');
INSERT INTO "meta" VALUES('krdict.name','한국어기초사전');
INSERT INTO "meta" VALUES('krdict.publisher','국립국어원');
INSERT INTO "meta" VALUES('schema','1');
INSERT INTO "meta" VALUES('senses','32');
INSERT INTO "meta" VALUES('sources','krdict');
INSERT INTO "meta" VALUES('variant','lean');
CREATE TABLE sense (
  id INTEGER PRIMARY KEY,
  word TEXT NOT NULL,
  level INTEGER,
  sense_no INTEGER NOT NULL,
  source INTEGER NOT NULL,
  synonyms TEXT NOT NULL
);
INSERT INTO "sense" VALUES(1,'식당',1,1,0,'');
INSERT INTO "sense" VALUES(2,'식도',3,1,0,'');
INSERT INTO "sense" VALUES(3,'유명하다',1,1,0,'');
INSERT INTO "sense" VALUES(4,'공부',1,1,0,'');
INSERT INTO "sense" VALUES(5,'다만',2,1,0,'단지');
INSERT INTO "sense" VALUES(6,'단지',2,1,0,'다만');
INSERT INTO "sense" VALUES(7,'그저',2,1,0,'');
INSERT INTO "sense" VALUES(8,'그저',2,2,0,'');
INSERT INTO "sense" VALUES(9,'공짜',1,1,0,'');
INSERT INTO "sense" VALUES(10,'한갓',3,1,0,'');
INSERT INTO "sense" VALUES(11,'찻집',3,1,0,'');
INSERT INTO "sense" VALUES(12,'카페',1,1,0,'');
INSERT INTO "sense" VALUES(13,'접시',3,1,0,'');
INSERT INTO "sense" VALUES(14,'그릇',1,1,0,'');
INSERT INTO "sense" VALUES(15,'맛',1,1,0,'');
INSERT INTO "sense" VALUES(16,'맛',1,2,0,'');
INSERT INTO "sense" VALUES(17,'미각',1,1,0,'');
INSERT INTO "sense" VALUES(18,'걸다',1,1,0,'');
INSERT INTO "sense" VALUES(19,'앉다',1,1,0,'');
INSERT INTO "sense" VALUES(20,'앉다',1,2,0,'');
INSERT INTO "sense" VALUES(21,'곱하다',2,1,0,'');
INSERT INTO "sense" VALUES(22,'가깝다',1,1,0,'');
INSERT INTO "sense" VALUES(23,'가깝다',1,2,0,'');
INSERT INTO "sense" VALUES(24,'코',1,1,0,'');
INSERT INTO "sense" VALUES(25,'꽃',1,1,0,'');
INSERT INTO "sense" VALUES(26,'체코어',NULL,1,0,'');
INSERT INTO "sense" VALUES(27,'담배',2,1,0,'');
INSERT INTO "sense" VALUES(28,'마을',1,1,0,'');
INSERT INTO "sense" VALUES(29,'제일',1,1,0,'');
INSERT INTO "sense" VALUES(30,'두근두근',3,1,0,'');
INSERT INTO "sense" VALUES(31,'스치다',2,1,0,'');
INSERT INTO "sense" VALUES(32,'사전',NULL,1,0,'');
CREATE INDEX ja_key ON ja(key);
CREATE INDEX ja_reading ON ja(reading) WHERE kind = 0;
