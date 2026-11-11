import 'dart:math' as math;

import 'element_rules.dart';
import 'pet_rules.dart';

/// 원정 중 지도 위 작은 말풍선 (11-11 #89)
///
/// 남은 거리·시간, 목표 몬스터, 시간대, 펫 성격(#38)에 맞춰 한 줄을 고른다.
/// (날씨 기능은 묶음 13에서 뺐다)
/// 1~2분에 한 번, 여러 마리면 한 번에 하나만.
class ExpeditionTalkRules {
  ExpeditionTalkRules._();

  /// 다음 말풍선까지 (60~120초)
  static Duration nextGap(math.Random rng) =>
      Duration(seconds: 60 + rng.nextInt(61));

  /// 말풍선이 떠 있는 시간
  static const Duration showFor = Duration(seconds: 4);

  /// 지도 발자국·길 색 (펫 속성 색, 무속성·정령은 금색)
  static String colorKey(Element? e) => switch (e) {
        null => 'gold',
        Element.water || Element.ice => 'sky',
        Element.fire => 'orange',
        Element.dark => 'purple',
        Element.wind => 'mint',
        Element.poison => 'lime',
        Element.light || Element.thunder => 'pale',
        Element.earth || Element.metal => 'gold',
      };

  static int colorValue(String key) => switch (key) {
        'sky' => 0xFF7FD3FF,
        'orange' => 0xFFFF9A4D,
        'purple' => 0xFFB58BFF,
        'mint' => 0xFF7FE8C4,
        'lime' => 0xFFB6E36A,
        'pale' => 0xFFFFF1B8,
        _ => 0xFFF5D06A,
      };

  /// 한 줄 고르기
  ///
  /// [going] 가는 중 / 돌아오는 중, [progress] 0~1 (이번 구간에서 간 정도),
  /// [minutesLeft] 이번 구간 남은 분, [monster] 목표 몬스터 이름,
  /// [hour] 지금 시 (기기 시간),
  /// [species] 펫 종류 (정령이면 null).
  static String line({
    required math.Random rng,
    required bool going,
    required double progress,
    required int minutesLeft,
    required String monster,
    required int hour,
    PetSpecies? species,
  }) {
    final pool = <String>[];
    if (going) {
      if (progress >= 0.8) {
        pool.addAll(['거의 다 왔어!', '$monster, 저기 보인다!']);
      } else if (progress <= 0.2) {
        pool.addAll(['다녀올게!', '$monster 잡으러 출발!']);
      } else {
        pool.addAll([
          '$monster 냄새가 나…',
          if (minutesLeft >= 10) '길이 꽤 머네' else '조금만 더!',
        ]);
      }
    } else {
      pool.addAll([
        progress >= 0.8 ? '곧 도착해!' : '돌아가는 중이야',
        '가방이 묵직해',
      ]);
    }
    if (hour >= 19 || hour < 5) {
      pool.add('밤길은 조금 무서워');
    } else if (hour < 9) {
      pool.add('아침 공기가 상쾌해');
    }
    final mine = _personal(species, going);
    if (mine.isNotEmpty) {
      // 펫 성격 대사는 조금 더 자주
      pool
        ..addAll(mine)
        ..add(mine[rng.nextInt(mine.length)]);
    }
    return pool[rng.nextInt(pool.length)];
  }

  /// 펫 성격(#38)에 맞는 대사
  static List<String> _personal(PetSpecies? s, bool going) => switch (s) {
        null => const [],
        PetSpecies.crow => going
            ? const ['까악! 하늘에서 보면 금방이야', '반짝이는 거 없나…']
            : const ['반짝이는 거 주웠어, 까악!'],
        PetSpecies.blackCat => going
            ? const ['…귀찮지만 가 줄게', '밤이면 더 잘할 텐데']
            : const ['낮잠 자고 싶어…'],
        PetSpecies.toad => going
            ? const ['개굴, 물가가 좋은데', '폴짝폴짝!']
            : const ['개굴~ 다녀왔어'],
        PetSpecies.owl => going
            ? const ['부엉, 약점이 보여', '천천히, 정확하게']
            : const ['부엉, 오늘도 배웠어'],
        PetSpecies.lizard => going
            ? const ['꼬리가 뜨끈뜨끈해!', '불씨 준비 완료!']
            : const ['따뜻한 데서 쉬고 싶어'],
        PetSpecies.homunculus => going
            ? const ['재료… 재료…', '목표 확인. 이동 중.']
            : const ['재료를 많이 챙겼어'],
      };
}
