/// 1234567 → '1,234,567'
String comma(int n) => n
    .toString()
    .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// 430 → '7시간 10분', 420 → '7시간'
String hoursMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return '$h시간';
  if (h == 0) return '$m분';
  return '$h시간 $m분';
}

/// 한글 단어 단위 줄바꿈 (CSS word-break: keep-all 처럼).
/// 단어 안 글자 사이에 줄바꿈 금지 문자(U+2060)를 넣어
/// '정 / 화', '요.' 만 다음 줄로 넘어가는 일을 막는다.
String keepAll(String s) {
  final out = StringBuffer();
  final chars = s.runes.toList();
  for (var i = 0; i < chars.length; i++) {
    out.writeCharCode(chars[i]);
    if (i + 1 < chars.length && !_isSpace(chars[i]) && !_isSpace(chars[i + 1])) {
      out.write('\u2060');
    }
  }
  return out.toString();
}

bool _isSpace(int c) => c == 0x20 || c == 0x0A || c == 0x09;

/// 이름 끝 받침에 맞춰 조사를 붙인다 (11-11 #52).
/// [pair] 는 '이/가', '을/를', '은/는', '와/과', '으로/로' 중 하나.
/// josa('큰쥐', '을/를') → '큰쥐를', josa('슬라임', '이/가') → '슬라임이'
/// 숫자·영어로 끝나면 읽는 소리로 정한다 (3 → 삼, L → 엘).
String josa(String word, String pair) {
  final parts = pair.split('/');
  final withBatchim = parts[0], without = parts[1];
  final b = _batchim(word);
  if (pair == '으로/로') {
    // 받침이 없거나 ㄹ 받침이면 '로'
    return '$word${b == 0 || b == 8 ? without : withBatchim}';
  }
  return '$word${b == 0 ? without : withBatchim}';
}

/// 마지막 글자의 받침 번호 (0 = 없음, 8 = ㄹ). 글자가 아닌 끝 문자는 건너뛴다.
int _batchim(String word) {
  final runes = word.runes.toList();
  for (var i = runes.length - 1; i >= 0; i--) {
    final c = runes[i];
    if (c >= 0xAC00 && c <= 0xD7A3) return (c - 0xAC00) % 28;
    if (c >= 0x30 && c <= 0x39) {
      // 영 일 이 삼 사 오 육 칠 팔 구
      const d = [21, 8, 0, 16, 0, 0, 1, 8, 8, 0];
      return d[c - 0x30];
    }
    final ch = String.fromCharCode(c).toLowerCase();
    if (RegExp(r'[a-z]').hasMatch(ch)) {
      if (ch == 'l' || ch == 'r') return 8; // 엘, 알
      if (ch == 'm' || ch == 'n') return 4; // 엠, 엔
      return 0;
    }
  }
  return 0;
}
