/// 계절 (묶음 14 A4): 기기 날짜 기준, 국내 계절
enum Season { spring, summer, autumn, winter }

class SeasonRules {
  SeasonRules._();

  /// 봄 3~5월 · 여름 6~8월 · 가을 9~11월 · 겨울 12~2월
  static Season of(DateTime t) => switch (t.month) {
        3 || 4 || 5 => Season.spring,
        6 || 7 || 8 => Season.summer,
        9 || 10 || 11 => Season.autumn,
        _ => Season.winter,
      };
}
