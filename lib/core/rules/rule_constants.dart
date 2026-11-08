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
  static const int defaultStepGoal = 5000;
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

  static const int sleepGoodMinutes = 7 * 60;
  static const int sleepOkMinutes = 6 * 60;
  static const int sleepGoodExp = 30;
  static const int sleepOkExp = 15;

  static const int studyExpPerTenMinutes = 5;
  static const int maxStudyExpPerDay = 60; // 2시간

  static const int questExp = 20;
  static const int questsPerDay = 3;

  static const int streakBonusEveryDays = 7;
  static const int streakBonusExp = 100;

  // ---------------------------------------------------------------- 스탯
  static const int statStartValue = 10;
  static const int vitalityStepsPerPoint = 30000; // 체력: 누적 걸음
  static const int wisdomStudyMinutesPerPoint = 180; // 지력: 누적 공부 3시간
  // 민첩: 걸음 목표 달성한 날 +1, 정신: 7시간 이상 잔 날 +1

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

  /// 필드 몬스터: 하루 나타나는 수, 만나는 거리(미터)
  static const int fieldSpawnsPerDay = 8;
  static const double fieldEncounterRadiusM = 40;

  // ---------------------------------------------------------------- 칭호
  static const int firstStepsThreshold = 1000;
  static const int persistentTravelerDays = 7;
  static const int morningSpiritDays = 7;
  static const int bookwormStudyMinutes = 600; // 10시간
  static const int forcedMarchSteps = 15000;
  static const int nightWalkSteps = 3000; // 저녁 8시 이후
  static const int nightWalkDays = 5;
  static const int awakenedLevel = 5;
  static const int lanternKeeperLevel = 10;

  // ---------------------------------------------------------------- 직업 각성
  static const int jobAwakeningDay = 7;

  // ───────────────────────── 앱 안 시설 (여관 · 잡화상)

  /// 정화 결정: 던전 클리어 3개, 던전 실패 1개, 필드 몬스터 정화 1개
  static const int crystalsPerDungeonClear = 3;
  static const int crystalsPerDungeonFail = 1;
  static const int crystalsPerFieldMonster = 1;

  /// 여관 체크인 가능 시간 (18시 ~ 22시 59분)
  static const int innOpenHour = 18;
  static const int innCloseHour = 23;

  /// 여관에 체크인하고 다음 날 푹 자면(7시간 이상) 받는 경험치
  static const int innRestExp = 10;

  /// 불씨 물약을 마신 날 던전 스킬 충전 틱 (평소 5)
  static const int potionSkillChargeTicks = 3;

  /// 마법 돋보기로 안개를 걷는 반경 (m)
  static const double lensRadiusM = 150;
}
