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
