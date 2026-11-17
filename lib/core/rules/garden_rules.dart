import 'harvest_rules.dart';
import 'materials.dart';

/// 씨앗 하나 (묶음 48 #230)
class SeedInfo {
  const SeedInfo(this.seed, this.steps, this.rarity);

  final MaterialId seed;

  /// 다 자라는 데 드는 걸음 (심은 뒤 걸은 걸음)
  final int steps;

  /// 0 흔한 · 1 보통 · 2 귀한
  final int rarity;
}

/// 마을 새 건물 「약초밭」 (묶음 48 #230). 씨앗을 심으면 그 뒤에 걸은 걸음으로 자란다
/// (한 걸음이 밭 모든 칸에 함께, 시간으로는 안 자람). 다 자란 것은 시들지 않는다.
/// 확률·크기는 숨은 값(처음 값, 테스트로 조정). 걸음은 내가 걸은 값이라 「약 ○보 더」로 보여 준다.
class GardenRules {
  GardenRules._();

  /// 열리는 레벨 (#225 공사 중 규칙: Lv.6 터 닦기 · 7 뼈대 · 8 거의 완성 · 9 완공)
  static const int openLevel = 9;

  /// 밭 칸: 처음 3칸 → 포포 2번 부탁 4칸 · 3번 부탁 5칸 · 4번 부탁 6칸
  static const int startPlots = 3;
  static const int maxPlots = 6;

  /// 포포 부탁을 [done] 개 끝냈을 때 밭 칸 수
  static int plotsFor(int done) => switch (done) {
        >= 4 => 6,
        3 => 5,
        2 => 4,
        _ => startPlots,
      };

  static const List<SeedInfo> seeds = [
    SeedInfo(MaterialId.herbSeed, 2000, 0),
    SeedInfo(MaterialId.flowerSeed, 4000, 1),
    SeedInfo(MaterialId.sporeSeed, 4000, 1),
    SeedInfo(MaterialId.glowSeed, 8000, 2),
  ];

  static bool isSeed(MaterialId m) => seeds.any((s) => s.seed == m);

  static SeedInfo? seedOf(MaterialId m) {
    for (final s in seeds) {
      if (s.seed == m) return s;
    }
    return null;
  }

  /// 포포의 이슬병: 밭이 조금 덜 걸어도 자람 (드는 걸음 배율)
  static const double dewFactor = 0.8;

  /// 다 자라는 데 드는 걸음
  static int need(MaterialId seed, {bool dew = false}) {
    final s = seedOf(seed)?.steps ?? 2000;
    return dew ? (s * dewFactor).round() : s;
  }

  /// 자란 정도 → 그림 단계: 0 새싹 · 1 자람 · 2 다 자람
  static int stageOf(int walked, int need) {
    if (walked >= need) return 2;
    if (walked * 2 >= need) return 1;
    return 0;
  }

  /// 거두면 나오는 재료 (꽃 씨앗은 그 달 꽃잎)
  static MaterialId yieldOf(MaterialId seed, int month) => switch (seed) {
        MaterialId.flowerSeed => HarvestRules.seasonPetal(month),
        MaterialId.sporeSeed => MaterialId.shadeMushroom,
        MaterialId.glowSeed => MaterialId.sunPollen,
        _ => MaterialId.herb,
      };

  /// 거두면 그 재료 몇 개
  static const int harvestCount = 2;

  /// 채집 숙련도로 가끔 하나 더 (큰 숙련도 장인 기준)
  static const double masteryExtra = 0.15;

  /// 포포 단짝: 거둘 때 가끔 하나 더
  static const double popoExtra = 0.25;

  /// 거두면 채집 숙련도 · 대지 속성 점수
  static const double masteryOnce = 1;
  static const double earthScore = 0.5;

  // ───────────── 씨앗 얻는 곳

  /// 채집할 때 가끔 그 자리의 씨앗 (약초 덤불 → 약초 씨앗 · 꽃 → 꽃 씨앗 · 버섯 → 버섯 포자)
  static const double gatherChance = 0.15;

  static MaterialId? gatherSeed(HarvestKind k) => switch (k) {
        HarvestKind.herb => MaterialId.herbSeed,
        HarvestKind.flower => MaterialId.flowerSeed,
        HarvestKind.mushroom => MaterialId.sporeSeed,
        _ => null,
      };

  /// 감정 보상으로 가끔 빛나는 씨앗 (감정 보상이 남은 날, 다른 재료가 안 나왔을 때)
  static const double appraiseGlow = 0.08;

  /// 주간 의뢰를 모두 끝낸 주마다 빛나는 씨앗 하나 (약초밭이 열린 주부터)
  static const int weeklyGlow = 1;

  /// 약초밭이 처음 열릴 때 포포가 나눠 주는 씨앗
  static const Map<String, int> starterSeeds = {'herbSeed': 2};

  // ───────────── 문구

  static const String openedLine = '약초밭이 열렸어! 포포가 씨앗을 나눠 줬대. 심고 걸으면 자라!';
  static const String guide = '씨앗을 심고 걸으면 자라요! 한 걸음이 밭 모든 칸에 함께 닿아요!';
  static const String readyLine = '다 자랐어요! 얼른 거둬 주세요! 반짝반짝해요!';
  static const String emptyLine = '빈 칸이 있어요! 씨앗을 심어 볼래요?';
}
