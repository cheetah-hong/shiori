import 'package:shiori_core/src/models/list_equality.dart';
import 'package:shiori_core/src/models/captured_entry.dart';
import 'package:shiori_core/src/models/part_of_speech.dart';

/// A textbook the learner collects pages from.
final class Textbook {
  const Textbook({
    required this.id,
    required this.title,
    required this.createdAt,
    this.templateId,
  });

  final String id;
  final String title;
  final DateTime createdAt;

  /// Template the pages of this book were parsed with, if known.
  final String? templateId;

  Textbook copyWith({String? title}) => Textbook(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    templateId: templateId,
  );

  @override
  bool operator ==(Object other) =>
      other is Textbook &&
      other.id == id &&
      other.title == title &&
      other.createdAt == createdAt &&
      other.templateId == templateId;

  @override
  int get hashCode => Object.hash(id, title, createdAt, templateId);
}

/// A chapter of a textbook. Word books call them `DAY 01`, `DAY 02`, ...
final class TextbookDay {
  const TextbookDay({
    required this.textbookId,
    required this.number,
    required this.title,
  });

  final String textbookId;
  final int number;
  final String title;

  String get key => '$textbookId#$number';

  @override
  bool operator ==(Object other) =>
      other is TextbookDay &&
      other.textbookId == textbookId &&
      other.number == number &&
      other.title == title;

  @override
  int get hashCode => Object.hash(textbookId, number, title);
}

/// A saved word (content). Its learning state lives in a separate `ReviewCard`.
final class Word {
  const Word({
    required this.id,
    required this.textbookId,
    required this.headword,
    required this.readings,
    required this.meaning,
    required this.createdAt,
    this.day,
    this.no,
    this.pos,
    this.example,
    this.page,
  });

  final String id;
  final String textbookId;
  final int? day;

  /// Number printed in the textbook, for example `0016`.
  final String? no;
  final String headword;
  final List<String> readings;
  final PartOfSpeech? pos;
  final String meaning;
  final Example? example;

  /// Page the word was captured from.
  final int? page;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is Word &&
      other.id == id &&
      other.textbookId == textbookId &&
      other.day == day &&
      other.no == no &&
      other.headword == headword &&
      listEquals(other.readings, readings) &&
      other.pos == pos &&
      other.meaning == meaning &&
      other.example == example &&
      other.page == page &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    textbookId,
    day,
    no,
    headword,
    Object.hashAll(readings),
    pos,
    meaning,
    example,
    page,
    createdAt,
  );

  @override
  String toString() => 'Word($id $headword)';
}

/// A textbook with how many words it holds and the days they are on, for the
/// shelf. Words without a day count but add no day.
final class TextbookStats {
  const TextbookStats({
    required this.textbook,
    required this.wordCount,
    required this.days,
  });

  final Textbook textbook;
  final int wordCount;

  /// Day numbers, each once, ascending.
  final List<int> days;

  @override
  bool operator ==(Object other) =>
      other is TextbookStats &&
      other.textbook == textbook &&
      other.wordCount == wordCount &&
      listEquals(other.days, days);

  @override
  int get hashCode => Object.hash(textbook, wordCount, Object.hashAll(days));

  @override
  String toString() =>
      'TextbookStats(${textbook.id}, words: $wordCount, days: $days)';
}
