import '../models/board_state.dart';
import '../models/daily_record.dart';
import 'field_monster_rules.dart';
import 'materials.dart';
import 'monsters.dart';
import 'npc_small_rules.dart';
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
    this.npc,
    this.exp = 0,
    this.tickets = 0,
    this.region,
  });

  /// 묶음 58: 이 지역 등불을 켜야 붙는 지역 되풀이 의뢰 (Region 이름, 발드린은 'baldrin')
  final String? region;

  /// 묶음 53: 3막 지역 의뢰 — 모집권
  final int tickets;

  final String id;
  final String title;

  /// 진행을 세는 수 ([BoardRules.counterValue] 의 키)
  final String counter;
  final int target;
  final int gold;
  final int manaStones;
  final Map<MaterialId, int> materials;
  final String unit;

  /// 묶음 45 #231: 마을 사람 쪽지면 그 사람 (Npc 이름)
  final String? npc;

  /// 마을 사람 쪽지 경험치
  final int exp;

  String get rewardLabel => [
        if (exp > 0) '경험치 $exp',
        if (tickets > 0) '모집권 $tickets',
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

  /// 주간 의뢰 하나당 경험치와 금화 (11-10: 레벨 속도를 맞추려고 60 → 30)
  static const int weeklyExp = 30;
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
        title: '원정 2번',
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

  /// 묶음 53 #243: 3막이 열리면 붙는 지역 의뢰 (발드린 관문). 세는 수는 3막 싸움 · 요새 층
  static final List<ErrandTemplate> regionErrands = [
    ErrandTemplate(
        id: 'baldrinHunt3',
        region: 'baldrin',
        title: '발드린 관문 몬스터 3번 물리치기',
        counter: 'act3Fight',
        target: 3,
        unit: '번',
        gold: 60,
        materials: {MaterialId.ironShard: 2}),
    ErrandTemplate(
        id: 'baldrinFloor2',
        region: 'baldrin',
        title: '문지기 지하 요새 2층 내려가기',
        counter: 'act3Floor',
        target: 2,
        unit: '층',
        gold: 70,
        tickets: 1),
    ErrandTemplate(
        id: 'baldrinPatrol5',
        region: 'baldrin',
        title: '관문 순찰: 다리 너머에서 5번 싸우기',
        counter: 'act3Fight',
        target: 5,
        unit: '번',
        gold: 90,
        manaStones: 2),
    // 묶음 58: 지역 2~5 — 사냥 · 채집(현실 지도의 그 지역 재료) · 던전
    for (final (r, name, dungeon, mat) in [
      ('selenia', '셀레니아 대장터', '흑등 상회 지하 금고', MaterialId.stardust),
      ('elowin', '엘로윈 숲', '고목의 뿌리 미궁', MaterialId.gemEarth),
      ('morval', '모르발 왕도', '잿빛 왕좌의 탑', MaterialId.gemDark),
      ('aurel', '아우렐 성소', '여명의 근원', MaterialId.fireCore),
    ]) ...[
      ErrandTemplate(
          id: '${r}Hunt3',
          region: r,
          title: '$name 몬스터 3번 물리치기',
          counter: 'a3fight:$r',
          target: 3,
          unit: '번',
          gold: 80,
          materials: {mat: 1}),
      ErrandTemplate(
          id: '${r}Gather2',
          region: r,
          title: '현실 지도에서 $name 재료 2번 줍기',
          counter: 'a3gather:$r',
          target: 2,
          unit: '번',
          gold: 70,
          manaStones: 2),
      ErrandTemplate(
          id: '${r}Floor2',
          region: r,
          title: '$dungeon 2층 내려가기',
          counter: 'a3floor:$r',
          target: 2,
          unit: '층',
          gold: 90,
          tickets: 1),
    ],
  ];

  /// 지역 의뢰가 붙을 확률 (3막이 열렸을 때, 새 의뢰마다)
  static const double regionChance = 0.35;

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

  /// 게시판 안내(Lv.4)에서만 붙는 쉬운 의뢰 (묶음 19 #4-2). 무작위로는 안 나온다
  static const guideErrand = ErrandTemplate(
      id: 'guideHunt1',
      title: '몬스터 1마리 사냥',
      counter: 'huntAll',
      target: 1,
      unit: '마리',
      gold: 30);

  static ErrandTemplate? template(String? id, {int level = 1}) {
    for (final t in [...errands, ...urgents, guideErrand, ...NpcSmallRules.boardNotes, ...regionErrands]) {
      if (t.id == id) return forLevel(t, level);
    }
    return null;
  }

  /// 묶음 69 #280: 「○○ ○마리 사냥」 — 그 몬스터가 내 단계에서 거의 안 나오면 그 단계의 비슷한 몬스터로
  static ErrandTemplate forLevel(ErrandTemplate t, int level) {
    if (!t.counter.startsWith('hunt:')) return t;
    final m = Monsters.byName(t.counter.substring(5));
    if (m == null) return t;
    final to = FieldMonsterRules.askFor(m, level);
    if (to == m) return t;
    final name = Monsters.info(m).name;
    final title = t.title.replaceFirst(name, Monsters.info(to).name);
    return ErrandTemplate(
      id: t.id,
      title: title,
      counter: 'hunt:${to.name}',
      target: t.target,
      gold: t.gold,
      manaStones: t.manaStones,
      materials: t.materials,
      unit: t.unit,
      npc: t.npc,
      exp: t.exp,
      tickets: t.tickets,
      region: t.region,
    );
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
      'huntAll' => today.huntCounts.values.fold(0, (a, b) => a + b),
      'dungeonClear' => today.dungeonRuns.where((r) => r.cleared).length,
      'steps' => today.steps,
      _ => today.counters[counter] ?? 0,
    };
  }

  static int progress(ErrandTemplate t, DailyRecord today, int baseline) =>
      (counterValue(today, t.counter) - baseline).clamp(0, t.target);

  /// 날짜가 바뀌었으면 새로 시작하고, 기다리던 빈 칸에 새 의뢰를 올린다
  /// [npcs]: 건물이 열린 마을 사람 (묶음 45 #231: 가끔 그 사람 쪽지가 붙는다)
  static BoardState refresh(BoardState s, DateTime now,
      {List<String> npcs = const [], List<String> regions = const [], int extra = 0}) {
    // 묶음 54: 게시판 ★2 → 칸 하나 · 하루 의뢰 하나 더
    final nSlots = errandSlots + extra;
    final perDay = errandsPerDay + extra;
    final key = DailyRecord.dayKeyOf(now);
    var state = s.day == key
        ? s
        : BoardState(
            day: key,
            slots: List.filled(nSlots, const ErrandSlot()),
          );
    final slots = [...state.slots];
    while (slots.length < nSlots) {
      slots.add(const ErrandSlot());
    }
    var seq = state.seq;
    for (var i = 0; i < slots.length; i++) {
      final slot = slots[i];
      if (!slot.empty) continue;
      final ready = slot.readyAt == null || !now.isBefore(slot.readyAt!);
      final holding = slots.where((x) => !x.empty).length;
      if (!ready || state.doneToday + holding >= perDay) continue;
      final taken = {for (final x in slots) x.templateId};
      final pick = _pickNpcNote(key, seq, taken, npcs) ??
          (regions.isNotEmpty ? _pickRegion(key, seq, taken, regions) : null) ??
          _pickErrand(key, seq, taken);
      seq++;
      slots[i] = ErrandSlot(templateId: pick.id);
    }
    return state.copyWith(slots: slots, seq: seq);
  }

  /// 묶음 45 #231: 길드 의뢰가 새로 붙을 때 가끔 마을 사람 쪽지 (같은 사람 쪽지는 한 장만)
  static ErrandTemplate? _pickNpcNote(
      String day, int seq, Set<String?> taken, List<String> npcs) {
    if (npcs.isEmpty) return null;
    final h = _hash('$day|npcNote|$seq');
    if ((h % 10000) / 10000 >= NpcSmallRules.boardChance) return null;
    final onBoard = {
      for (final id in taken)
        if (template(id)?.npc case final n?) n,
    };
    final free = [
      for (final n in npcs)
        if (!onBoard.contains(n)) n,
    ];
    if (free.isEmpty) return null;
    final who = free[(h ~/ 10007) % free.length];
    final notes = NpcSmallRules.notesOf(who);
    if (notes.isEmpty) return null;
    return notes[(h ~/ 131) % notes.length];
  }

  static ErrandTemplate? _pickRegion(
      String day, int seq, Set<String?> taken, List<String> regions) {
    final h = _hash('$day|region|$seq');
    if ((h % 10000) / 10000 >= regionChance) return null;
    final free = [
      for (final t in regionErrands)
        if (!taken.contains(t.id) && regions.contains(t.region)) t,
    ];
    return free.isEmpty ? null : free[(h ~/ 10007) % free.length];
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
