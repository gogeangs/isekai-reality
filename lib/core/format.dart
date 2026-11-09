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
