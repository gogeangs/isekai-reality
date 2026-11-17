// 묶음 57: 이름 금칙어 (assets/data/banned_words.txt = 서버 firebase/functions/src/banned_words.txt).
// 서버 판정이 기준이고, 앱은 같은 목록으로 먼저 거른다. 걸린 말이 무엇인지는 보여 주지 않는다.

abstract final class NameRules {
  static const bannedMessage = '쓸 수 없는 말이 들어 있어요';

  static List<String> _part = const [];
  static List<String> _whole = const [];

  /// 지금 목록 (앱을 켤 때 함께 넣은 파일, 서버에서 바뀐 목록을 받으면 그것)
  static bool get loaded => _part.isNotEmpty || _whole.isNotEmpty;

  static final _keep = RegExp(r'[^a-zㄱ-ㆎ가-힣]');

  /// 비교용: 공백 · 특수문자 · 숫자 · 이모지 빼고, 영어는 소문자
  static String normalize(String s) => s.toLowerCase().replaceAll(_keep, '');

  /// 목록 글을 읽는다 (「## … [전체]」 아래는 이름 전체일 때만)
  static void load(String text) {
    final part = <String>[], whole = <String>[];
    var whole0 = false;
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('##')) {
        whole0 = line.contains('[전체]');
        continue;
      }
      if (line.startsWith('#')) continue;
      final w = normalize(line);
      if (w.isEmpty) continue;
      (whole0 ? whole : part).add(w);
    }
    _part = part;
    _whole = whole;
  }

  /// 금칙어가 들어 있는지
  static bool banned(String name) {
    final n = normalize(name);
    if (n.isEmpty) return false;
    if (_whole.contains(n)) return true;
    for (final w in _part) {
      if (n.contains(w)) return true;
    }
    return false;
  }
}
