/// 페이즈 1 게임 규칙의 모든 숫자.
///
/// 기획 문서(인수인계 문서 '페이즈 1' 섹션)의 숫자와 1:1로 맞춘다.
/// 밸런스를 바꿀 때는 이 파일만 고치면 된다.
class RuleConstants {
  RuleConstants._();

  // ---------------------------------------------------------------- 레벨
  /// Lv.n → n+1 에 필요한 경험치 = levelBaseExp + levelStepExp × (n − 1)
  /// 11-10: 퀘스트 보상이 늘어 약 10% 올림 (100·25 → 110·28),
  /// 같은 날 주간 의뢰를 넣으며 5% 더 올림 (110·28 → 118·29)
  static const int levelBaseExp = 118;
  static const int levelStepExp = 29;

  // ---------------------------------------------------------------- 걸음 목표
  static const int defaultStepGoal = 3000; // 모두 같은 목표 (2026-11-09: 적게 걷는 사람도 충분히 즐기도록)
  static const int minStepGoal = 3000;
  static const int maxStepGoal = 10000;

  /// 맞춤 목표를 제안하기 전에 지켜보는 날 수
  static const int adaptiveObserveDays = 3;

  /// 이 날 수만큼 연속 달성하면 한 단계 올리기를 권한다
  static const int raiseSuggestStreak = 3;
  static const int raiseSuggestAmount = 1000;

  // ---------------------------------------------------------------- 던전 게이지
  static const int stepsPerKey = 2500;
  static const int maxKeysEarnedPerDay = 4; // 10,000보

  /// 자기 걸음 목표를 채운 날 주는 보너스 열쇠 (밸런스 A안)
  static const int goalBonusKeys = 1;

  // ---------------------------------------------------------------- 경험치
  static const int dungeonClearExp = 50;
  static const int dungeonFailExp = 10;

  static const int fieldMonsterExp = 15;
  /// 하루 사냥 보상이 그대로인 마리 수 (11-11 #69: 그 뒤에도 사냥은 되고 보상만 줄어든다)
  static const int maxFieldMonstersPerDay = 5;

  /// 6~15마리째는 경험치·마석 절반, 16마리째부터 10% (숨은 규칙)
  static const int fieldHalfUntil = 15;
  static const double fieldHalf = 0.5;
  static const double fieldTail = 0.1;

  /// [n] 번째(1부터) 사냥의 경험치·마석 배율
  static double fieldFactor(int n) => n <= maxFieldMonstersPerDay
      ? 1
      : n <= fieldHalfUntil
          ? fieldHalf
          : fieldTail;

  /// 그날 [count] 마리를 사냥했을 때 보상 단위 합
  static double fieldUnits(int count) {
    var u = 0.0;
    for (var i = 1; i <= count; i++) {
      u += fieldFactor(i);
    }
    return u;
  }

  // 묶음 81 #380: 새 장소 · 다시 찾기 경험치 · 미궁 입구 1.5배 없음 (「새 장소」 기능은 진행하지 않음)

  static const int questExp = 20;
  static const int questsPerDay = 3;

  /// 일일 퀘스트 3개를 모두 마친 날의 추가 경험치 (11-10 결정)
  static const int questAllBonusExp = 30;

  // ---------------------------------------------------------------- 스탯
  static const int statStartValue = 10;
  // 민첩: 걸음 목표 달성한 날 +1
  // 지력: 도감에 새 몬스터 +1, 새 장소(미궁 입구·물가)를 처음 발견 +1 (2026-11-10)
  // 정신: 7일 연속 접속할 때마다 +1, 여관 휴식을 마친 날 +1 (2026-11-10)

  // ---------------------------------------------------------------- 전투
  // 자동 전투: 1틱(약 1초)마다 서로 한 번씩 공격한다.
  // '보통으로 생활한 사람'의 전투력을 기준으로 몬스터를 맞춘다.

  /// 던전 층마다 기준 공격 횟수 (층당 10~15초)
  static const int floorHitsToClear = 12;
  static const int bossHitsToClear = 20;

  /// 기준 체력을 이 틱 수에 걸쳐 잃도록 몬스터 공격력을 정한다
  /// (스킬 없이 보통 사람이 보스까지 이기고 체력 20% 정도 남음)
  static const int dungeonHpBudgetTicks = 80;
  static const double bossAttackMultiplier = 1.3;

  /// 필드 몬스터: 6번쯤 때리면 정화, 거의 지지 않음
  static const int fieldHitsToClear = 6;
  static const int fieldHpBudgetTicks = 60;

  /// 스킬 '불씨의 일격': 5틱마다 충전, 공격력 4배
  static const int skillChargeTicks = 5;
  static const int skillDamageMultiplier = 4;

  /// 필드 몬스터: 지역을 이 크기(미터) 블록으로 나눠 블록마다 하루 한 마리,
  /// 블록에 몬스터가 나올 확률, 만나는 거리(미터)
  static const double fieldSpawnBlockM = 500; // 11-11 #80: 1km → 500m (가까이 3~4배 촘촘히)

  /// 패배의 벌 (11-11 #75): 입은 장비 내구도 더 깎임, 지친 상태 1시간 (경험치·마석 -20%, 숨김)
  static const int defeatExtraWear = 2;
  static const Duration tiredFor = Duration(hours: 1);
  static const double tiredRewardMultiplier = 0.8;
  static const double fieldSpawnChance = 0.7;
  static const double fieldEncounterRadiusM = 40;

  /// 정화의 향을 피운 날의 필드 몬스터 경험치 배수 (11-10)
  static const double incenseExpMultiplier = 1.5;

  /// 내 둘레 이 거리(미터) 안의 블록에만 몬스터를 둔다 (11-10 전국 확대).
  /// 정령 원정의 최대 거리(MP 60 = 3km)와 같게.
  static const double fieldSpawnRadiusM = 3000;

  // ---------------------------------------------------------------- 칭호
  static const int firstStepsThreshold = 1000;
  static const int persistentTravelerDays = 7;
  static const int morningSpiritDays = 7; // 여관 휴식 7일 연속
  static const int forcedMarchSteps = 15000;
  static const int nightWalkSteps = 3000; // 저녁 8시 이후
  static const int nightWalkDays = 5;
  static const int awakenedLevel = 5;
  static const int lanternKeeperLevel = 10;

  // 탐험 칭호
  static const int gateKeeperGates = 5; // 서로 다른 미궁 입구 5곳
  static const int lakeFriendVisits = 5; // 정령의 호수 서로 다른 날 5번

  /// 칭호 '동네의 빛': 필드 몬스터 누적 정화 수 (11-10, 안개를 없애며 바꿈)
  static const int townLightMonsters = 30;

  // ---------------------------------------------------------------- 직업 각성

  // ───────────────────────── 앱 안 시설 (여관 · 잡화상)

  /// 마석 (예전 정화 결정과 같은 양): 던전 클리어 3개, 던전 실패 1개, 필드 몬스터 1개.
  /// 이름은 예전 그대로 둔다 (11-10 마석·금화).
  static const int crystalsPerDungeonClear = 3;
  static const int crystalsPerDungeonFail = 1;
  static const int crystalsPerFieldMonster = 1;

  /// 잡화상에서 마석 1개를 팔면 받는 금화 (11-10 확정)
  static const int goldPerManaStone = 10;

  /// 예전 결정 가격 → 금화 가격 배수 (지금 가격 = 예전 가격 × 10)
  static const int goldPriceMultiplier = 10;

  // ───────────────────────── 여관 (2026-11-10 개편)

  // 여관 회복은 InnRules (묶음 81 #373: 있는 동안 시간당 20%, 상한 없음)

  // 묶음 80 #367: 휴식 보너스 경험치 · 연속 휴식 보상(경험치 · 마석)은 없앰

  // ───────────────────────── HP · MP (2026-11-10)

  /// 걸음 1,000보마다 최대 HP의 10% 회복
  static const int hpRegenSteps = 1000;
  static const double hpRegenRatio = 0.10;

  /// 정령의 기력 (MP)
  static const int mpMax = 60;
  static const int mpRegenPerHour = 10;

  // ───────────────────────── 정령 원정 (2026-11-10)

  /// 거리 100m마다 MP 2 (갔다 오는 것까지)
  static const int expeditionMpPer100m = 2;

  /// 1km마다 10분 (한쪽 길), 아무리 가까워도 3분
  static const int expeditionMinutesPerKm = 10;
  static const int expeditionMinMinutes = 3;

  /// 정령 물약을 마신 날 던전 스킬 충전 틱 (평소 5)
  static const int potionSkillChargeTicks = 3;

  /// 마법 돋보기로 안개를 걷는 반경 (m)
}
