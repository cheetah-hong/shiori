/// Korean parts of speech of the glossary (`sense.pos`, schema 2) and the
/// classes a word's printed class matches.
library;

import 'package:shiori_core/shiori_core.dart';

/// `sense.pos` codes, as tools/dict/build_ko_glossary.py writes them
/// (tools/dict/testdata/ko_pos_codes.json). 0 is none.
const Map<String, int> koreanPosCodes = {
  '명사': 1,
  '의존 명사': 2,
  '대명사': 3,
  '수사': 4,
  '동사': 5,
  '보조 동사': 6,
  '형용사': 7,
  '보조 형용사': 8,
  '부사': 9,
  '관형사': 10,
  '감탄사': 11,
  '조사': 12,
  '접사': 13,
  '어미': 14,
};

const Set<int> _nouns = {1, 2, 3, 4};
const Set<int> _predicates = {5, 6, 7, 8};

/// Codes of no class of their own (none, 접사, 어미): a hint never moves
/// their senses back.
const Set<int> neutralPosCodes = {0, 13, 14};

/// The Korean codes the senses of a word printed as [pos] are preferred
/// with; empty for none. Japanese verbs and adjectives of both kinds are one
/// class with the Korean ones (在る → 있다 is a Korean adjective, 要る →
/// 필요하다 too).
Set<int> preferredPosCodes(PartOfSpeech? pos) => switch (pos) {
  null => const {},
  PartOfSpeech.noun => _nouns,
  PartOfSpeech.verb ||
  PartOfSpeech.adjective ||
  PartOfSpeech.iAdjective ||
  PartOfSpeech.naAdjective => _predicates,
  PartOfSpeech.adverb || PartOfSpeech.conjunction => const {9},
  PartOfSpeech.prenominal => const {10},
  PartOfSpeech.interjection => const {11},
  PartOfSpeech.particle => const {12},
};
