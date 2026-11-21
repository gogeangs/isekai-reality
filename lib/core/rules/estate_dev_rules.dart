import 'erbard_rules.dart';
import 'materials.dart';

/// 묶음 65 (2/2) #255 영지 관리: 시설 · 특산물 · 번영 단계 · 영주의 정책 (이름 · 그림만. 숫자는 서버가 정하고 화면에 안 보임)
class FacilityInfo2 {
  const FacilityInfo2(this.id, this.name, this.line);
  final String id;
  final String name;
  final String line;
  String get image => 'assets/images/fac_$id.webp';
}

class PolicyInfo {
  const PolicyInfo(this.id, this.name, this.line);
  final String id;
  final String name;
  final String line;
  String get image => 'assets/images/policy_$id.webp';
}

class EstateDevRules {
  EstateDevRules._();

  static const List<FacilityInfo2> facilities = [
    FacilityInfo2('wall', '성벽', '다음 공성전에 이 영지 수비대가 더 단단해져요'),
    FacilityInfo2('tower', '감시탑', '다음 공성전에 이 영지 수비대가 더 단단해져요'),
    FacilityInfo2('market', '시장', '거래소 수수료 몫이 조금 더 들어와요'),
    FacilityInfo2('light', '빛의 성당', '날마다 성스러운 백합이 길드 창고로 와요'),
    FacilityInfo2('metal', '드워프 광산', '날마다 청동 광석이 길드 창고로 와요'),
    FacilityInfo2('earth', '엘프 목재소', '날마다 엘프 고목 가지가 길드 창고로 와요'),
    FacilityInfo2('dark', '결정 우물', '날마다 안개 결정이 길드 창고로 와요'),
    FacilityInfo2('fire', '용암 용광로', '날마다 용암석이 길드 창고로 와요'),
  ];

  static FacilityInfo2 facility(String id) => facilities.firstWhere((f) => f.id == id, orElse: () => facilities.first);

  /// 이 영지에 지을 수 있는 시설 (공통 셋 + 그 지방 특산 하나)
  static List<String> buildable(EstateInfo e) => ['wall', 'tower', 'market', if (e.province != null) specialOf(e.province!)];

  static String specialOf(Province p) => switch (p) {
        Province.light => 'light',
        Province.metal => 'metal',
        Province.earth => 'earth',
        Province.dark => 'dark',
        Province.fire => 'fire',
      };

  static const List<MaterialId> specialties = [
    MaterialId.lightRelic,
    MaterialId.metalOre,
    MaterialId.earthWood,
    MaterialId.darkCrystal,
    MaterialId.fireStone,
  ];

  /// 번영 단계 이름
  static const List<String> stages = ['마을', '고을', '도시'];

  static const List<PolicyInfo> policies = [
    PolicyInfo('defense', '방어 우선', '다음 공성전에 수비대가 단단해져요'),
    PolicyInfo('plenty', '풍요', '특산물이 더 많이 나와요'),
    PolicyInfo('trade', '교역', '거래소 수수료 몫이 더 들어와요'),
  ];

  static PolicyInfo policy(String id) => policies.firstWhere((p) => p.id == id, orElse: () => policies[1]);

  static const int maxLevel = 3;

  /// 지도 아이콘 크기 (번영 단계가 오를수록)
  static double iconScale(int stage) => switch (stage) { 2 => 1.25, 1 => 1.12, _ => 1.0 };

  static String? errorText(String code) => switch (code) {
        'no_treasury' => '길드 금고 금화가 모자라요.',
        'no_mats' => '길드원이 기부한 재료가 모자라요.',
        'no_slot' => '시설 칸이 다 찼어요. 번영도가 오르면 칸이 늘어나요.',
        'max' => '이미 가장 높은 단계예요.',
        'donate_limit' => '오늘은 이 영지에 더 기부할 수 없어요.',
        'take_limit' => '오늘 받을 수 있는 만큼 다 받았어요.',
        'empty' => '창고에 남은 게 없어요.',
        'chosen' => '이번엔 이미 정책을 정했어요. 다음 공성전이 끝나면 다시 고를 수 있어요.',
        'not_yet' => '정책은 공성전이 끝난 뒤에 정해요.',
        'siege_lock' => '공성전 중에는 시설을 지을 수 없어요.',
        'not_staff' => '길드장 · 부길드장만 할 수 있어요.',
        'not_yours' => '우리 길드 영지가 아니에요.',
        _ => null,
      };
}
