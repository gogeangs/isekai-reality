import '../models/board_state.dart';
import '../models/daily_record.dart';
import 'materials.dart';
import 'quest_rules.dart';
import 'town_rules.dart';

/// 수시·긴급 의뢰 하나의 모양
class ErrandTemplate {
  const ErrandTemplate({
    required this.id,
    required this.title,
    required this.counter,
    required this.target,
    this.gold = 0,
    this.manaStones = 0,
    this.materials = const {},
    this.unit = '',
  });

  final String id;
  final String title;

  /// 진행을 세는 수 ([BoardRules.counterValue] 의 키)
  final String counter;
  final int target;
  final int gold;
  final int manaStones;
  final Map<MaterialId, int> materials;
  final String unit;

  String get rewardLabel => [
        if (gold > 0) '금화 $gold',
        if (manaStones > 0) '마석 $manaStones',
        for (final e in materials.entries)
          '${Materials.info(e.key).name} ${e.value}',
      ].join(' + ');
}

/// 긴급 의뢰 보상의 종류
enum UrgentPrize { key, rareMaterial }

/// 의뢰 게시판 규칙 (제안서 4장, 11-10 확정).
/// 경험치는 일일·주간에서만 주고, 수시·긴급은 금화·재료만 준다.
class BoardRules {
  BoardRules._();

  // ───────────────────────── 주간 (월요일 시작, 자동 진행)

  /// 주간 의뢰 하나당 경험치와 금화
  static const int weeklyExp = 60;
  static const int weeklyGold = 80;

  /// 주간 의뢰를 시작한 주 (이보다 앞선 주에는 보상을 주지 않는다)
  static final DateTime weeklyStart = DateTime(2026, 11, 9);

  /// 그 주에 날마다 쌓인 진행으로 주간 의뢰 3개를 계산한다
  static List<QuestProgress> weekly(List<DailyRecord> week) {
    var steps = 0, clears = 0, field = 0;
    for (final r in week) {
      steps += r.steps;
      clears += r.dungeonRuns.where((x) => x.cleared).length;
      field += r.fieldMonstersPurified;
    }
    return [
      QuestProgress(title: '이번 주 2만 보 걷기', current: steps, target: 20000, unit: '보'),
      QuestProgress(title: '던전 5번 클리어', current: clears, target: 5, unit: '번'),
      QuestProgress(
          title: '필드 몬스터 15마리 사냥', current: field, target: 15, unit: '마리'),
    ];
  }

  /// [history] 의 [i] 번째 날까지 이번 주 기록
  static List<DailyRecord> _weekUpTo(List<DailyRecord> history, int i) {
    final start = TownRules.weekStart(history[i].date);
    return [
      for (var k = 0; k <= i; k++)
        if (!history[k].date.isBefore(start)) history[k],
    ];
  }

  /// [i] 번째 날에 새로 마친 주간 의뢰 수
  static int weeklyCompletedOn(List<DailyRecord> history, int i) {
    if (history[i].date.isBefore(weeklyStart)) return 0;
    final upTo = _weekUpTo(history, i);
    final before = upTo.sublist(0, upTo.length - 1);
    final now = weekly(upTo).where((q) => q.completed).length;
    final prev = weekly(before).where((q) => q.completed).length;
    return now - prev;
  }

  /// 오늘이 속한 주의 주간 의뢰
  static List<QuestProgress> thisWeek(List<DailyRecord> history) =>
      history.isEmpty ? weekly(const []) : weekly(_weekUpTo(history, history.length - 1));

  /// 이번 주 남은 날 (오늘 포함)
  static int daysLeftInWeek(DateTime today) => 8 - today.weekday;

  // ───────────────────────── 수시 (수락, 동시에 2개, 하루 4개, 끝내면 2시간 뒤 새로)

  static const int errandSlots = 2;
  static const int errandsPerDay = 4;
  static const Duration errandCooldown = Duration(hours: 2);

  static const List<ErrandTemplate> errands = [
    ErrandTemplate(
        id: 'slime3',
        title: '슬라임 3마리 사냥',
        counter: 'hunt:ashSlime',
        target: 3,
        unit: '마리',
        gold: 30,
        materials: {MaterialId.slimeJelly: 2}),
    ErrandTemplate(
        id: 'rat3',
        title: '큰쥐 3마리 사냥',
        counter: 'hunt:giantRat',
        target: 3,
        unit: '마리',
        gold: 30,
        materials: {MaterialId.ratHide: 2}),
    ErrandTemplate(
        id: 'modded2',
        title: '수식어 붙은 몬스터 2마리 사냥',
        counter: 'modded',
        target: 2,
        unit: '마리',
        gold: 50,
        manaStones: 2),
    ErrandTemplate(
        id: 'dungeon1',
        title: '던전 1번 클리어',
        counter: 'dungeonClear',
        target: 1,
        unit: '번',
        gold: 40,
        materials: {MaterialId.batWing: 2}),
    ErrandTemplate(
        id: 'expedition2',
        title: '정령 원정 2번',
        counter: 'expedition',
        target: 2,
        unit: '번',
        gold: 40),
    ErrandTemplate(
        id: 'steps3000',
        title: '3,000보 더 걷기',
        counter: 'steps',
        target: 3000,
        unit: '보',
        gold: 60),
  ];

  // ───────────────────────── 긴급 (하루 25%, 오전 9시~오후 6시에 떠서 자정까지)

  static const double urgentChance = 0.25;
  static const int urgentGold = 100;

  static const List<ErrandTemplate> urgents = [
    ErrandTemplate(
        id: 'enraged1',
        title: '분노한 몬스터 1마리 사냥',
        counter: 'mod:enraged',
        target: 1,
        unit: '마리',
        gold: urgentGold),
    ErrandTemplate(
        id: 'rarePlus1',
        title: '희귀 이상 수식어 몬스터 1마리 사냥',
        counter: 'rarePlus',
        target: 1,
        unit: '마리',
        gold: urgentGold),
    ErrandTemplate(
        id: 'dungeon2',
        title: '던전 2번 클리어',
        counter: 'dungeonClear',
        target: 2,
        unit: '번',
        gold: urgentGold),
  ];

  static ErrandTemplate? template(String? id) {
    for (final t in [...errands, ...urgents]) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// 오늘의 긴급 의뢰 (없는 날은 null): (의뢰, 뜨는 시각, 보상 종류, 귀한 재료)
  static ({
    ErrandTemplate quest,
    DateTime appearsAt,
    UrgentPrize prize,
    MaterialId rare,
  })? urgentFor(DateTime day) {
    final key = DailyRecord.dayKeyOf(day);
    final h = _hash('$key|urgent');
    if ((h % 10000) / 10000 >= urgentChance) return null;
    final h2 = _hash('$key|urgent2');
    final rares = Materials.rares;
    return (
      quest: urgents[h2 % urgents.length],
      // 오전 9시 ~ 오후 6시 사이, 10분 단위
      appearsAt: DateTime(day.year, day.month, day.day, 9)
          .add(Duration(minutes: (h2 ~/ 7) % 54 * 10)),
      prize: (h2 ~/ 3) % 2 == 0 ? UrgentPrize.key : UrgentPrize.rareMaterial,
      rare: rares[(h2 ~/ 11) % rares.length],
    );
  }

  // ───────────────────────── 진행

  /// 오늘 기록에서 세는 수
  static int counterValue(DailyRecord today, String counter) {
    if (counter.startsWith('hunt:')) {
      return today.huntCounts[counter.substring(5)] ?? 0;
    }
    return switch (counter) {
      'dungeonClear' => today.dungeonRuns.where((r) => r.cleared).length,
      'steps' => today.steps,
      _ => today.counters[counter] ?? 0,
    };
  }

  static int progress(ErrandTemplate t, DailyRecord today, int baseline) =>
      (counterValue(today, t.counter) - baseline).clamp(0, t.target);

  /// 날짜가 바뀌었으면 새로 시작하고, 기다리던 빈 칸에 새 의뢰를 올린다
  static BoardState refresh(BoardState s, DateTime now) {
    final key = DailyRecord.dayKeyOf(now);
    var state = s.day == key
        ? s
        : BoardState(
            day: key,
            slots: List.filled(errandSlots, const ErrandSlot()),
          );
    final slots = [...state.slots];
    while (slots.length < errandSlots) {
      slots.add(const ErrandSlot());
    }
    var seq = state.seq;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (!slot.empty) continue;
      final ready = slot.readyAt == null || !now.isBefore(slot.readyAt!);
      final holding = slots.where((x) => !x.empty).length;
      if (!ready || state.doneToday + holding >= errandsPerDay) continue;
      final taken = {for (final x in slots) x.templateId};
      final pick = _pickErrand(key, seq, taken);
      seq++;
      slots[i] = ErrandSlot(templateId: pick.id);
    }
    return state.copyWith(slots: slots, seq: seq);
  }

  static ErrandTemplate _pickErrand(String day, int seq, Set<String?> taken) {
    final start = _hash('$day|errand|$seq') % errands.length;
    for (var k = 0; k < errands.length; k++) {
      final t = errands[(start + k) % errands.length];
      if (!taken.contains(t.id)) return t;
    }
    return errands[start];
  }

  /// 실행할 때마다 같은 값을 내는 문자열 해시 (FNV-1a 32비트)
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }
}
