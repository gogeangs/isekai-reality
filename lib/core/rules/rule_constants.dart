/// 페이즈 1 게임 규칙의 모든 숫자.
///
/// 기획 문서(인수인계 문서 '페이즈 1' 섹션)의 숫자와 1:1로 맞춘다.
/// 밸런스를 바꿀 때는 이 파일만 고치면 된다.
class RuleConstants {
  RuleConstants._();

  // ---------------------------------------------------------------- 레벨
  /// Lv.n → n+1 에 필요한 경험치 = levelBaseExp + levelStepExp × (n − 1)
  static const int levelBaseExp = 100;
  static const int levelStepExp = 25;

  // ---------------------------------------------------------------- 걸음 목표
  static const int defaultStepGoal = 3000; // 모두 같은 목표 (2026-11-09: 적게 걷는 사람도 충분히 즐기도록)
  static const List<int> stepGoalPresets = [3000, 5000, 8000];
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
  static const int maxKeysCarryOver = 3;

  /// 자기 걸음 목표를 채운 날 주는 보너스 열쇠 (밸런스 A안)
  static const int goalBonusKeys = 1;

  // ---------------------------------------------------------------- 경험치
  static const int dungeonClearExp = 50;
  static const int dungeonFailExp = 10;
  static const double gateBonusMultiplier = 1.5;

  /// 하루에 경험치를 받을 수 있는 던전 횟수 (이월 열쇠를 써도 같음)
  static const int maxDungeonRunsPerDay = 4;

  static const int fieldMonsterExp = 15;
  static const int maxFieldMonstersPerDay = 5;

  static const int newPlaceExp = 30;
  static const int maxNewPlacesPerDay = 3;
  static const int revisitPlaceExp = 5; // 같은 장소는 하루 한 번만

  static const int questExp = 20;
  static const int questsPerDay = 3;

  /// 일일 퀘스트 3개를 모두 마친 날의 추가 경험치 (11-10 결정)
  static const int questAllBonusExp = 30;

  /// 일일 퀘스트 '새 안개 N칸 걷기'
  static const int questNewCells = 20;

  // ---------------------------------------------------------------- 스탯
  static const int statStartValue = 10;
  static const int vitalityStepsPerPoint = 30000; // 체력: 누적 걸음
  // 민첩: 걸음 목표 달성한 날 +1
  // 지력: 도감에 새 몬스터 +1, 새 장소(미궁 입구·물가)를 처음 발견 +1 (2026-11-10)
  // 정신: 7일 연속 접속할 때마다 +1, 여관 휴식을 마친 날 +1 (2026-11-10)
  static const int spiritLoginStreakDays = 7;

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

  /// 공격력 = 전투력 ÷ 4
  static const int attackDivisor = 4;

  /// 필드 몬스터: 지역을 이 크기(미터) 블록으로 나눠 블록마다 하루 한 마리,
  /// 블록에 몬스터가 나올 확률, 만나는 거리(미터)
  static const double fieldSpawnBlockM = 1000;
  static const double fieldSpawnChance = 0.7;
  static const double fieldEncounterRadiusM = 40;

  // ---------------------------------------------------------------- 칭호
  static const int firstStepsThreshold = 1000;
  static const int persistentTravelerDays = 7;
  static const int morningSpiritDays = 7; // 여관 휴식 7일 연속
  static const int codexSageSpecies = 6; // 도감의 현자: 몬스터 6종 모두
  static const int forcedMarchSteps = 15000;
  static const int nightWalkSteps = 3000; // 저녁 8시 이후
  static const int nightWalkDays = 5;
  static const int awakenedLevel = 5;
  static const int lanternKeeperLevel = 10;

  // 탐험 칭호
  static const int gateKeeperGates = 5; // 서로 다른 미궁 입구 5곳
  static const int lakeFriendVisits = 5; // 정령의 호수 서로 다른 날 5번
  static const int brightTownCells = 300; // 안개 300칸 (100m 칸, 약 3km²)

  // ---------------------------------------------------------------- 직업 각성
  static const int jobAwakeningDay = 7;

  // ───────────────────────── 앱 안 시설 (여관 · 잡화상)

  /// 정화 결정: 던전 클리어 3개, 던전 실패 1개, 필드 몬스터 정화 1개
  static const int crystalsPerDungeonClear = 3;
  static const int crystalsPerDungeonFail = 1;
  static const int crystalsPerFieldMonster = 1;

  // ───────────────────────── 여관 (2026-11-10 개편)

  /// 체크인하고 이만큼 지나면 휴식이 끝난다 (언제든, 하루 여러 번)
  static const int restHours = 4;

  /// 휴식을 마친 날 경험치 (하루 한 번)
  static const int restBonusExp = 20;

  /// 연속 휴식 보너스: (연속 일수, 경험치, 정화 결정).
  /// 14일 뒤로는 7일마다 14일째와 같은 보상.
  static const List<(int, int, int)> restStreakRewards = [
    (3, 30, 0),
    (7, 70, 5),
    (14, 100, 10),
  ];
  static const int restStreakRepeatEvery = 7;

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
  static const double lensRadiusM = 150;
}
