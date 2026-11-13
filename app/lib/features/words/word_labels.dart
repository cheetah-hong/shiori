/// Words of the word screens (단어 시트·고치기·추가·찾기), in one place.
abstract final class WordLabels {
  static const String edit = '고치기';
  static const String editTitle = '단어 고치기';
  static const String addTitle = '단어 추가';
  static const String add = '추가';
  static const String save = '저장';
  static const String cancel = '취소';
  static const String search = '단어 찾기';

  static const String headword = '표제어';
  static const String readings = '읽기';
  static const String pos = '품사';
  static const String meaning = '뜻';
  static const String exampleJa = '예문 (일본어)';
  static const String exampleKo = '예문 번역';
  static const String dropExample = '예문 지우기';

  static const String headwordHelp = '일본어 키보드로 가나·한자를 써요';
  static const String readingsHelp = '여러 개면 / 로 나눠요. 가나 단어는 비워 두세요';
  static const String filled = '사전에서 채움';
  static const String refill = '사전에서 다시 찾기';
  static const String suggestion = '사전:';
  static const String otherMeanings = '다른 뜻:';
  static const String notInDictionary = '사전에 없는 낱말이에요. 읽기와 뜻을 직접 써 주세요';
  static const String kanjiChoices = '한자 표기';
  static const String keepKana = '고르지 않으면 가나 단어로 넣어요';

  static const String keyChanges = '표제어가 바뀌어요. 학습 기록은 그대로 남아요.';
  static const String resetRecord = '학습 기록 처음부터';

  static const String taken = '이미 저장한 단어예요';
  static String takenBody(int lists) =>
      '이 단어 대신 저장된 단어를 재생목록 $lists개에 넣어요. 지금 단어의 학습 기록은 따로 남아요.';
  static const String replace = '저장된 단어로 바꾸기';
  static const String replaced = '저장된 단어로 바꿨어요';
  static String edited(String headword) => '「$headword」 고쳤어요';
  static const String saveFailed = '저장하지 못했어요. 다시 시도해 주세요';
  static String editedResetFailed(String headword) =>
      '「$headword」 고쳤어요. 학습 기록은 지우지 못했어요(단어 메뉴의 「처음부터 다시 학습」으로 다시 할 수 있어요)';
  static const String refillFailed = '사전에서 찾지 못했어요. 다시 시도해 주세요';
  static const String undoFailed = '되돌리지 못했어요';

  static const String stored = '이미 저장한 단어예요';
  static String storedIn(String lists) => '$lists에 있어요 · 저장된 뜻과 학습 기록 그대로 넣어요';
  static const String storedNowhere = '저장된 뜻과 학습 기록 그대로 넣어요';
  static const String link = '이 목록에 넣기';
  static const String alreadyHere = '이미 이 목록에 있어요';
  static const String editStored = '저장된 단어 고치기';
  static const String target = '넣을 재생목록';
  static String newTarget(String name) => '$name (새로 만듦)';
  static const String addFailed = '추가하지 못했어요. 다시 시도해 주세요';

  static const String hiddenNote = '숨긴 단어예요. 학습에 나오지 않아요.';

  static const String direct = '직접 입력';
  static const String photo = '사진으로';
  static const String decks = '기본 단어장';
  static const String addWords = '단어 추가';

  static const String searchHint = '표제어·읽기·뜻';
  static const String thisList = '이 목록';
  static const String allWords = '모든 단어';
  static const String noMatch = '저장한 단어 중에 없어요';
  static const String addDirectly = '직접 추가';
  static const String hidden = '숨김';
  static String count(int n) => '$n개';
}
