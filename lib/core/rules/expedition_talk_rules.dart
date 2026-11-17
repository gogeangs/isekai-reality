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
        PetSpecies.griffin => going
            ? const ['번개처럼 다녀올게!', '날개가 근질근질해']
            : const ['하늘을 한 바퀴 돌고 왔어!'],
        PetSpecies.direwolf => going
            ? const ['아우우… 사냥 시간이야', '냄새를 따라갈게']
            : const ['먹잇감을 잔뜩 물어 왔어'],
        PetSpecies.drake => going
            ? const ['불길이 끓어올라!', '날아서 금방 가지']
            : const ['조금 그을렸지만 괜찮아'],
        PetSpecies.kelpie => going
            ? const ['물길이 있으면 더 좋은데', '찰랑찰랑 출발!']
            : const ['물보라처럼 돌아왔어'],
        PetSpecies.mimic => going
            ? const ['덜컥… 덜컥…', '반짝이는 건 내 거야']
            : const ['상자 안에 뭐가 들었게?'],
        PetSpecies.golem => going
            ? const ['…천천히, 하지만 확실히', '쿵, 쿵, 출발']
            : const ['…돌아왔어. 쿵.'],
        // 묶음 49 #235 영웅 펫
        PetSpecies.wolf => going
            ? const ['바람을 타고 다녀올게!', '아우우— 출발!']
            : const ['바람처럼 돌아왔어!'],
        PetSpecies.turtle => going
            ? const ['천천히 가도 꼭 이기고 올게', '등딱지 단단히!']
            : const ['이끼에 재료를 잔뜩 붙여 왔어'],
        PetSpecies.panther => going
            ? const ['그림자를 밟고 다녀올게', '…소리 없이 간다']
            : const ['아무도 모르게 돌아왔어'],
        PetSpecies.whale => going
            ? const ['안개를 헤엄쳐 갈게~', '뿌우— 출발!']
            : const ['구름 위를 한 바퀴 돌고 왔어~'],
        PetSpecies.phoenix => going
            ? const ['불씨는 꺼지지 않아!', '날개에 불 붙었다!']
            : const ['조금 그을렸지만 더 뜨거워졌어!'],
        PetSpecies.stag => going
            ? const ['새벽빛을 따라갈게', '뿔이 반짝반짝, 출발!']
            : const ['햇살을 한 아름 가져왔어'],
        // 묶음 57 #244 전설 펫
        PetSpecies.pegasus => going
            ? const ['별 사이로 다녀올게!', '날개만 펴면 금방이야']
            : const ['구름 위 바람이 시원했어'],
        PetSpecies.behemoth => going
            ? const ['쿵, 쿵. 천천히 다 쓸어 올게', '땅이 길을 알려 줘']
            : const ['짐이 많아. 다 네 거야'],
        PetSpecies.nightmare => going
            ? const ['어둠은 내 편이야', '…조용히 다녀올게']
            : const ['아무도 날 못 봤어'],
        PetSpecies.leviathan => going
            ? const ['물길을 타고 갈게', '깊은 곳의 노래가 들려']
            : const ['바다 냄새를 가져왔어'],
        PetSpecies.dragon => going
            ? const ['비켜, 내가 간다!', '불꽃 준비 끝']
            : const ['다 태우진 않았어. 아마도'],
        PetSpecies.unicorn => going
            ? const ['빛이 가는 길로 갈게', '뿔이 따뜻해']
            : const ['다친 곳 없지? 다행이야'],
      };
}
