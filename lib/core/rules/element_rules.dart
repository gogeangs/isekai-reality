import '../models/daily_record.dart';

/// 속성 10종 (11-11 #63). 무속성은 null.
/// 이름은 저장 기록의 키라 바꾸지 않는다 (앞의 6개는 11-11 #57 물약 때부터 있던 것).
enum Element { fire, water, wind, earth, light, dark, ice, thunder, metal, poison }

extension ElementName on Element {
  String get label => switch (this) {
        Element.fire => '불',
        Element.water => '물',
        Element.ice => '얼음',
        Element.wind => '바람',
        Element.thunder => '번개',
        Element.earth => '대지',
        Element.metal => '금속',
        Element.poison => '독',
        Element.light => '빛',
        Element.dark => '어둠',
      };

  /// 아이콘 그림 (없으면 화면에서 색 동그라미로)
  String get asset => 'assets/images/icon_el_$name.webp';
}

/// 속성 상성 (11-11 #63 확정). 숫자는 게임에 보여 주지 않는다.
class ElementRules {
  ElementRules._();

  /// 강함·약함 배율 (숨김)
  static const double strong = 1.3;
  static const double weak = 0.7;

  /// 방어(저항) 속성 장비: 그 속성 피해 ×0.8
  static const double guard = 0.8;

  /// 주 속성: 그 속성 공격 +5%, 그 속성에게 받는 피해 -5%
  static const double mainBonus = 0.05;

  /// 주 속성이 되는 최소 점수
  static const double mainMin = 30;

  /// 속성 칭호가 열리는 점수
  static const double titleScore = 100;

  /// 공격 속성 무기로 사냥하면 그 속성 점수
  static const double weaponScore = 2;

  /// 무기 속성이 없으면 몬스터를 이기는 속성들이 나눠 받는 점수
  static const double beatScore = 1;

  /// 내 주 속성에 강한 속성의 몬스터가 더 자주 (필드)
  static const double challengeWeight = 1.5;

  /// 공격 속성 → (강함, 약함)
  static const Map<Element, (Set<Element>, Set<Element>)> table = {
    Element.fire: (
      {Element.wind, Element.ice, Element.metal, Element.dark},
      {Element.water, Element.earth}
    ),
    Element.water: (
      {Element.fire, Element.earth},
      {Element.thunder, Element.ice, Element.poison}
    ),
    Element.ice: ({Element.water, Element.wind}, {Element.fire, Element.metal}),
    Element.wind: (
      {Element.water, Element.poison},
      {Element.fire, Element.ice, Element.earth}
    ),
    Element.thunder: (
      {Element.water, Element.metal, Element.wind},
      {Element.earth}
    ),
    Element.earth: (
      {Element.fire, Element.thunder, Element.wind, Element.poison},
      {Element.water, Element.ice}
    ),
    Element.metal: ({Element.earth, Element.ice}, {Element.fire, Element.thunder}),
    Element.poison: (
      {Element.water},
      {Element.metal, Element.light, Element.wind, Element.earth}
    ),
    Element.light: ({Element.dark, Element.poison}, {Element.light}),
    Element.dark: ({Element.light, Element.metal}, {Element.fire, Element.dark}),
  };

  /// [attack] 속성이 [target] 에게 주는 배율 (무속성은 1)
  static double multiplier(Element? attack, Element? target) {
    if (attack == null || target == null) return 1;
    final (s, w) = table[attack]!;
    if (s.contains(target)) return strong;
    if (w.contains(target)) return weak;
    return 1;
  }

  /// [target] 에게 강한 공격 속성들
  static List<Element> beats(Element target) => [
        for (final e in Element.values)
          if (table[e]!.$1.contains(target)) e,
      ];

  /// 사냥 한 번에 오르는 점수
  static Map<Element, double> huntScore(Element? monster, Element? weapon) {
    if (weapon != null) return {weapon: weaponScore};
    if (monster == null) return const {};
    final b = beats(monster);
    if (b.isEmpty) return const {};
    return {for (final e in b) e: beatScore / b.length};
  }

  /// 점수 1위 (최소 점수 이상, 같으면 앞 순서)
  static Element? mainOf(Map<Element, double> scores) {
    Element? best;
    var top = mainMin - 1e-9;
    for (final e in Element.values) {
      final v = scores[e] ?? 0;
      if (v > top) {
        top = v;
        best = e;
      }
    }
    return best;
  }

  /// [main] 에게 강한 속성 (필드에 더 자주 나온다)
  static Set<Element> challengers(Element? main) =>
      main == null ? const {} : beats(main).toSet();

  /// 걷기 속성 점수 (1,000보마다, 숨은 값)
  static const double stepScore = 0.5;

  /// 묶음 32 #189: 그 밖에 쌓이는 곳 (숨은 값)
  static const double waterScore = 1; // 물가 채집·물가 장소
  static const double oreScore = 0.5; // 광석 채집 → 금속
  static const double woodScore = 0.5; // 나무·약초 채집 → 대지
  static const double potionScore = 1; // 속성 물약 끓이기
  static const double imbueScore = 3; // 대장간 속성 부여

  /// 주 속성이 처음 생기거나 바뀔 때 한마디
  static String auraLine(Element e) => switch (e) {
        Element.fire => '요즘 너한테서 따뜻한 불 냄새가 나.',
        Element.water => '요즘 너한테서 시원한 물 냄새가 나.',
        Element.ice => '요즘 네 곁에 있으면 서늘한 바람이 불어.',
        Element.wind => '요즘 너, 바람처럼 가벼워 보여.',
        Element.thunder => '요즘 너한테서 찌릿한 기운이 느껴져.',
        Element.earth => '요즘 너한테서 흙 냄새가 나. 든든해.',
        Element.light => '요즘 너한테서 아침 햇살 같은 빛이 나.',
        Element.dark => '요즘 너, 밤하늘처럼 조용한 기운이 있어.',
        Element.metal => '요즘 너한테서 단단한 쇠 냄새가 나.',
        Element.poison => '요즘 너한테서 쌉싸름한 풀 냄새가 나.',
      };

  /// 기록에 적힌 점수 (counters 'el:<속성>' 은 10배로 적혀 있다)
  static Map<Element, double> scoresFrom(List<DailyRecord> history) {
    final out = <Element, double>{};
    for (final r in history) {
      // 묶음 32 #189: 밤 1,000보마다 어둠 0.5 · 이른 아침 1,000보마다 빛 0.5 (예전 기록 포함)
      final night = r.nightSteps ~/ 1000, dawn = r.dawnSteps ~/ 1000;
      if (night > 0) {
        out[Element.dark] = (out[Element.dark] ?? 0) + night * stepScore;
      }
      if (dawn > 0) {
        out[Element.light] = (out[Element.light] ?? 0) + dawn * stepScore;
      }
      r.counters.forEach((k, v) {
        if (!k.startsWith('el:')) return;
        final e = parse(k.substring(3));
        if (e != null) out[e] = (out[e] ?? 0) + v / 10;
      });
    }
    return out;
  }

  static Element? parse(String? name) {
    if (name == null) return null;
    for (final e in Element.values) {
      if (e.name == name) return e;
    }
    return null;
  }

}
