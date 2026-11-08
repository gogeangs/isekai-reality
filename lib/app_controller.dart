import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'core/geo/geo.dart';
import 'core/models/daily_record.dart';
import 'core/models/player_state.dart';
import 'core/rules/rules.dart';
import 'data/health/health_source.dart';
import 'data/location/location_source.dart';
import 'data/storage/record_store.dart';
import 'data/weather/weather_source.dart';
import 'features/bulssi/bulssi_mood.dart';
import 'features/map/gojan_area.dart';
import 'features/status/demo_data.dart';

/// 저장소 · 건강 앱 · 화면을 잇는 앱의 중심.
///
/// 앱을 열 때마다 [sync] 로 오늘(과 어제 마감) 걸음·수면을 건강 앱에서 읽어
/// 하루 기록에 반영하고 저장한다. 게임 안에서 생긴 기록(던전, 공부 등)은 그대로 둔다.
class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    required this.health,
    this.location,
    this.weatherSource,
    this.area = GojanArea.area,
    DateTime Function()? clock,
    math.Random? random,
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? math.Random();

  /// 건강 앱 없이 2주치 예시 기록으로 화면을 보는 모드
  factory AppController.demo({DateTime Function()? clock}) {
    final now = (clock ?? DateTime.now)();
    return AppController(
      store: InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', stepGoal: 8000),
        // 예시 모드는 처음부터 레벨업 연출이 뜨지 않도록 확인한 레벨을 비워 둔다
        history: DemoData.twoWeeks(today: now),
      ),
      health: FakeHealthSource(granted: false),
      weatherSource: FakeWeatherSource(
          const WeatherNow(kind: WeatherKind.clear, temperatureC: 12)),
      clock: clock,
    );
  }

  final RecordStore store;
  final HealthSource health;

  /// 위치 (없으면 지도 탐험 없이 동작)
  final LocationSource? location;

  /// 날씨 (없으면 불씨 색은 시간으로만 정한다)
  final WeatherSource? weatherSource;

  /// 탐험 지역 (페이즈 1: 고잔동)
  final ExploreArea area;
  final DateTime Function() _clock;

  /// 전투의 피해량 흔들림 (테스트에서는 고정 시드)
  final math.Random _random;

  Set<String> _revealedCells = {};
  bool _locationGranted = false;
  LocationFix? _lastFix;
  GamePlace? _lastDiscovery;
  StreamSubscription<LocationFix>? _locationSub;

  bool get locationGranted => _locationGranted;
  LocationFix? get lastFix => _lastFix;
  Set<String> get revealedCells => Set.unmodifiable(_revealedCells);
  double get revealedRatio =>
      ExplorationRules.revealedRatio(area, _revealedCells);

  /// 처음 방문해서 새로 발견한 장소 (화면에서 알림을 띄우고 [clearDiscovery])
  GamePlace? get lastDiscovery => _lastDiscovery;

  /// 지금까지 한 번이라도 방문한 장소 id
  Set<String> get everVisitedPlaceIds =>
      {for (final r in _history) ...r.visitedPlaceIds};

  PlayerProfile _profile = const PlayerProfile(name: '각성자');
  List<DailyRecord> _history = [];
  bool _ready = false;
  bool _needsAwakening = false;
  bool _healthGranted = false;

  bool get ready => _ready;

  /// 처음 실행이라 각성 화면(이름·외형)을 보여 줘야 하는지
  bool get needsAwakening => _needsAwakening;
  bool get healthGranted => _healthGranted;
  PlayerProfile get profile => _profile;
  List<DailyRecord> get history => List.unmodifiable(_history);

  PlayerState get player =>
      PlayerState.fromHistory(name: _profile.name, history: _history);

  /// 확인하지 않은 레벨업. 없으면 null.
  ({int from, int to})? get pendingLevelUp {
    final seen = _profile.lastSeenLevel;
    final now = player.level.level;
    if (seen == null || now <= seen) return null;
    return (from: seen, to: now);
  }

  Future<void> init() async {
    final saved = await store.loadProfile();
    if (saved == null) {
      // 처음 실행: 각성 화면에서 이름과 외형을 정한 뒤 시작한다
      _needsAwakening = true;
      _ready = true;
      notifyListeners();
      return;
    }
    _profile = saved;
    await _startPlaying();
  }

  /// 각성 화면에서 '깨어나기'를 눌렀을 때
  Future<void> awaken({required String name, required HeroLook look}) async {
    _profile = PlayerProfile(name: name.trim(), look: look, lastSeenLevel: 1);
    await store.saveProfile(_profile);
    _needsAwakening = false;
    await _startPlaying();
  }

  /// 레벨업 연출을 닫았을 때
  Future<void> acknowledgeLevelUp() async {
    await updateProfile(_profile.copyWith(lastSeenLevel: player.level.level));
  }

  Future<void> _startPlaying() async {
    _healthGranted = await health.requestPermission();
    _revealedCells = await store.loadRevealedCells(area.id);
    await sync();
    await _startExploring();
    // 예전 저장본처럼 확인한 레벨이 없으면 지금 레벨부터 센다 (연출 없이)
    if (_profile.lastSeenLevel == null) {
      _profile = _profile.copyWith(lastSeenLevel: player.level.level);
      await store.saveProfile(_profile);
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> sync() async {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    _history = await store.loadHistory();

    // 어제 기록이 있으면 하루 전체 걸음으로 마감한다 (밤에 앱을 안 열었을 때 대비)
    final y = _find(yesterday);
    if (_healthGranted && y != null) {
      final closed = await _withHealth(y, yesterday, today);
      await store.upsert(_withQuests(closed));
    }

    var todayRecord =
        _find(today) ?? DailyRecord(date: today, stepGoal: _profile.stepGoal);
    if (_healthGranted) {
      todayRecord = await _withHealth(todayRecord, today, now);
    }
    await store.upsert(_withQuests(todayRecord.copyWith(openedApp: true)));

    _history = await store.loadHistory();
    notifyListeners();
    unawaited(refreshWeather());
  }

  // ───────────────────────────────────────────── 날씨 · 불씨 색

  WeatherNow? _weather;
  DateTime? _weatherAt;

  WeatherNow? get weather => _weather;

  /// 불씨 빛 색 (맑음 황금, 비 하늘색, 밤 보라, 눈 흰색)
  BulssiMood get bulssiMood => BulssiMoods.of(weather: _weather, now: _clock());

  /// 상태창 위쪽에 보이는 날씨 이름
  String get weatherLabel {
    final w = _weather;
    if (w == null) return '날씨 확인 중';
    final t = w.temperatureC;
    return t == null ? w.kind.koreanName : '${w.kind.koreanName} ${t.round()}°';
  }

  /// 30분에 한 번만 새로 읽는다. 실패해도 게임은 그대로.
  Future<void> refreshWeather({bool force = false}) async {
    final source = weatherSource;
    if (source == null) return;
    final now = _clock();
    final last = _weatherAt;
    if (!force && last != null && now.difference(last).inMinutes < 30) return;
    _weatherAt = now;
    final w = await source.current(_lastFix?.point ?? area.bounds.center);
    if (w != null) {
      _weather = w;
      notifyListeners();
    }
  }

  // ───────────────────────────────────────────── 설정

  /// 걸음 목표를 바꾼다. 오늘 기록에도 바로 적용한다 (지난날은 그대로).
  Future<void> setStepGoal(int goal) async {
    final clamped = goal
        .clamp(RuleConstants.minStepGoal, RuleConstants.maxStepGoal)
        .toInt();
    await updateProfile(_profile.copyWith(stepGoal: clamped));
    if (_history.isEmpty) return;
    final today = await _todayRecord();
    await _save(today.copyWith(stepGoal: clamped));
  }

  /// 불씨가 권하는 걸음 목표 (권할 게 없으면 null).
  /// 첫 3~6일: 평소 걸음에 맞춘 목표 / 그 뒤: 3일 연속 달성하면 1,000보 올리기.
  int? get stepGoalSuggestion {
    if (_history.length < 2) return null;
    final done = _history.sublist(0, _history.length - 1); // 오늘은 아직 진행 중
    final goal = _profile.stepGoal;
    final raise = StepGoalRules.suggestRaise(done, goal);
    if (raise != null) return raise;
    if (done.length >= RuleConstants.adaptiveObserveDays &&
        done.length < RuleConstants.jobAwakeningDay) {
      final initial = StepGoalRules.suggestInitialGoal(done);
      if (initial != null && initial != goal) return initial;
    }
    return null;
  }

  Future<void> renameHero(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    await updateProfile(_profile.copyWith(name: n));
  }

  Future<void> renameSpirit(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    await updateProfile(_profile.copyWith(spiritName: n));
  }

  /// 테스트 결과 모으기용 하루별 기록 (CSV). 위치 좌표·이름은 넣지 않는다.
  String exportRecordsCsv() {
    final p = player;
    final b = StringBuffer(
        '날짜,걸음,목표,수면분,공부분,던전,던전클리어,필드몬스터,새장소,다시방문,경험치,레벨\n');
    var total = 0;
    for (var i = 0; i < _history.length; i++) {
      final r = _history[i];
      total += p.dailyExp[i].total;
      b.writeln([
        r.dayKey,
        r.steps,
        r.stepGoal,
        r.sleepMinutes ?? '',
        r.studyMinutes,
        r.dungeonRuns.length,
        r.dungeonRuns.where((x) => x.cleared).length,
        r.fieldMonstersPurified,
        r.newPlacesVisited,
        r.placesRevisited,
        p.dailyExp[i].total,
        LevelRules.fromTotalExp(total).level,
      ].join(','));
    }
    b.writeln('# 밝힌 비율 ${(revealedRatio * 100).toStringAsFixed(1)}%, '
        '직업 ${p.job?.koreanName ?? '-'}, 칭호 ${p.titles.length}개, '
        '도감 ${purifiedEver.length}종');
    return b.toString();
  }

  /// 데이터 동의 철회: 기기에 저장한 모든 기록을 지우고 처음(각성)으로 돌아간다.
  /// 건강 앱·위치 권한 자체는 휴대폰 설정에서 끈다.
  Future<void> resetAll() async {
    await _locationSub?.cancel();
    _locationSub = null;
    await store.clearAll();
    _history = [];
    _revealedCells = {};
    _lastFix = null;
    _lastDiscovery = null;
    _profile = const PlayerProfile(name: '각성자');
    _needsAwakening = true;
    notifyListeners();
  }

  /// '공부 기록' 버튼
  Future<void> logStudy(int minutes) async {
    final today = _history.isEmpty ? null : _history.last;
    if (today == null || minutes <= 0) return;
    final updated = today.copyWith(studyMinutes: today.studyMinutes + minutes);
    await store.upsert(_withQuests(updated));
    _history = await store.loadHistory();
    notifyListeners();
  }

  Future<void> updateProfile(PlayerProfile profile) async {
    _profile = profile;
    await store.saveProfile(profile);
    notifyListeners();
  }

  // ───────────────────────────────────────────── 탐험

  Future<void> _startExploring() async {
    final source = location;
    if (source == null) return;
    _locationGranted = await source.requestPermission();
    if (!_locationGranted) return;
    await _locationSub?.cancel();
    _locationSub = source.fixes().listen(handleFix);
  }

  /// 위치가 바뀔 때: 안개를 걷고, 가까운 장소를 방문으로 기록한다
  Future<void> handleFix(LocationFix fix) async {
    _lastFix = fix;
    if (ExplorationRules.countsAsExploring(fix)) {
      final cell = area.cellIdOf(fix.point);
      if (cell != null && _revealedCells.add(cell)) {
        await store.saveRevealedCells(area.id, _revealedCells);
      }
      for (final place in ExplorationRules.placesInReach(area, fix.point)) {
        await _visitPlace(place);
      }
    }
    notifyListeners();
  }

  void clearDiscovery() {
    _lastDiscovery = null;
    notifyListeners();
  }

  Future<void> _visitPlace(GamePlace place) async {
    final now = _clock();
    if (_history.isEmpty ||
        _history.last.dayKey != DailyRecord.dayKeyOf(now)) {
      await sync(); // 자정이 지났으면 오늘 기록부터 만든다
    }
    final today = _history.last;
    if (today.visitedPlaceIds.contains(place.id)) return;

    final visitedBefore = _history
        .sublist(0, _history.length - 1)
        .any((r) => r.visitedPlaceIds.contains(place.id));
    final updated = today.copyWith(
      visitedPlaceIds: [...today.visitedPlaceIds, place.id],
      newPlacesVisited:
          visitedBefore ? today.newPlacesVisited : today.newPlacesVisited + 1,
      placesRevisited:
          visitedBefore ? today.placesRevisited + 1 : today.placesRevisited,
    );
    await store.upsert(updated);
    _history = await store.loadHistory();
    if (!visitedBefore) _lastDiscovery = place;
  }

  // ───────────────────────────────────────────── 던전 · 필드 몬스터

  /// 지금 싸울 수 있는지. 차량 속도로 움직이는 중에는 전투하지 않는다.
  bool get canFightNow {
    final fix = _lastFix;
    return fix == null || ExplorationRules.countsAsExploring(fix);
  }

  /// 지금 미궁 입구 근처인지 (던전 보상 1.5배, 장소 전용 몬스터)
  bool get atGate {
    final fix = _lastFix;
    if (fix == null) return false;
    return ExplorationRules.placesInReach(area, fix.point)
        .any((p) => p.kind == PlaceKind.labyrinthGate);
  }

  /// 오늘 경험치를 받을 수 있는 던전 횟수가 남았는지
  bool get dungeonExpLeftToday =>
      (player.today?.dungeonRuns.length ?? 0) <
      RuleConstants.maxDungeonRunsPerDay;

  /// 던전을 연다. 열쇠가 없거나 이동 중이면 null.
  /// 열쇠는 전투가 끝날 때([finishDungeon]) 쓴다. 중간에 나가면 쓰지 않는다.
  Battle? startDungeon() {
    final p = player;
    if (p.gauge.keysAvailable <= 0 || !canFightNow) return null;
    return Battle.forPlayer(
      level: p.level.level,
      stats: p.stats,
      floors: BattleRules.dungeonFloors(
          level: p.level.level, atGate: atGate, rng: _random),
      rng: _random,
      skillChargeTicks: TownRules.potionActive(p.today)
          ? RuleConstants.potionSkillChargeTicks
          : RuleConstants.skillChargeTicks,
    );
  }

  /// 던전이 끝났을 때 결과를 기록한다. 받은 경험치를 돌려준다.
  Future<int> finishDungeon(Battle battle, {required bool atGate}) async {
    if (!battle.isOver) return 0;
    final today = await _todayRecord();
    final run = DungeonRun(
        cleared: battle.phase == BattlePhase.cleared, atGate: atGate);
    final exp = today.dungeonRuns.length < RuleConstants.maxDungeonRunsPerDay
        ? ExpRules.dungeonRunExp(run)
        : 0;
    await _save(today.copyWith(
      dungeonRuns: [...today.dungeonRuns, run],
      purifiedMonsterIds: _addMonsters(today, battle.purified),
    ));
    return exp;
  }

  /// 오늘 아직 정화하지 않은 필드 몬스터.
  /// 하루 상한(5마리)을 채우면 더 나오지 않는다.
  List<FieldSpawn> get todaySpawns {
    final today = player.today;
    if (today != null &&
        today.fieldMonstersPurified >= RuleConstants.maxFieldMonstersPerDay) {
      return const [];
    }
    final done = today?.purifiedSpawnIds.toSet() ?? const <String>{};
    return FieldMonsterRules.spawnsFor(area, _clock())
        .where((s) => !done.contains(s.id))
        .toList();
  }

  /// 지금 위치에서 만난 필드 몬스터 (없으면 null)
  FieldSpawn? get nearbySpawn {
    final fix = _lastFix;
    if (fix == null) return null;
    return FieldMonsterRules.encounter(
        area: area, spawns: todaySpawns, fix: fix);
  }

  Battle? startFieldBattle(FieldSpawn spawn) {
    if (!canFightNow) return null;
    final p = player;
    return Battle.forPlayer(
      level: p.level.level,
      stats: p.stats,
      floors: [BattleRules.fieldFoe(level: p.level.level, monster: spawn.monster)],
      rng: _random,
    );
  }

  /// 필드 전투가 끝났을 때. 정화하면 그 자리의 안개도 걷힌다.
  Future<int> finishFieldBattle(FieldSpawn spawn, Battle battle) async {
    if (battle.phase != BattlePhase.cleared) return 0;
    final today = await _todayRecord();
    if (today.purifiedSpawnIds.contains(spawn.id)) return 0;
    final exp =
        today.fieldMonstersPurified < RuleConstants.maxFieldMonstersPerDay
            ? RuleConstants.fieldMonsterExp
            : 0;
    final cell = area.cellIdOf(spawn.point);
    if (cell != null && _revealedCells.add(cell)) {
      await store.saveRevealedCells(area.id, _revealedCells);
    }
    await _save(today.copyWith(
      fieldMonstersPurified: today.fieldMonstersPurified + 1,
      purifiedSpawnIds: [...today.purifiedSpawnIds, spawn.id],
      purifiedMonsterIds: _addMonsters(today, [spawn.monster]),
    ));
    return exp;
  }

  // ───────────────────────────────────────────── 여관 · 잡화상 (앱 안 시설)

  /// 잡화상에서 물건을 산다. 사지 못하면 그 이유를 돌려준다.
  /// 마법 돋보기는 사는 즉시 지금 위치 주변 안개를 걷는다.
  Future<PurchaseCheck> buy(ShopItem item) async {
    final today = await _todayRecord();
    final fix = _lastFix;
    final check =
        TownRules.canBuy(_history, item, hasLocation: fix != null);
    if (check != PurchaseCheck.ok) return check;

    if (item == ShopItem.magicLens && fix != null) {
      var changed = false;
      for (final cell in _cellsAround(fix.point, RuleConstants.lensRadiusM)) {
        changed = _revealedCells.add(cell) || changed;
      }
      if (changed) await store.saveRevealedCells(area.id, _revealedCells);
    }
    await _save(today.copyWith(
      shopPurchases: [...today.shopPurchases, item.name],
    ));
    return PurchaseCheck.ok;
  }

  /// [center] 에서 [radiusM] 안에 걸치는 지역 칸 id
  Set<String> _cellsAround(GeoPoint center, double radiusM) {
    const step = 25.0;
    final cells = <String>{};
    const latPerM = 1 / 111320.0;
    final lngPerM = 1 / (111320.0 * math.cos(center.lat * math.pi / 180));
    for (var dy = -radiusM; dy <= radiusM; dy += step) {
      for (var dx = -radiusM; dx <= radiusM; dx += step) {
        if (dx * dx + dy * dy > radiusM * radiusM) continue;
        final cell = area.cellIdOf(GeoPoint(
            center.lat + dy * latPerM, center.lng + dx * lngPerM));
        if (cell != null) cells.add(cell);
      }
    }
    return cells;
  }

  /// 게임 시계 (테스트에서는 고정 시각)
  DateTime get now => _clock();

  /// 여관 체크인이 지금 열려 있는지 (18시 ~ 23시)
  bool get innOpen => TownRules.innOpen(_clock());

  /// 여관에 체크인한다. 시간이 아니거나 이미 했으면 false.
  Future<bool> restAtInn() async {
    if (!innOpen) return false;
    final today = await _todayRecord();
    if (today.restedAtInn) return false;
    await _save(today.copyWith(restedAtInn: true));
    return true;
  }

  /// 지금까지 정화한 몬스터 종류 (도감)
  Set<MonsterId> get purifiedEver => {
        for (final r in _history)
          for (final name in r.purifiedMonsterIds)
            if (Monsters.byName(name) case final id?) id,
      };

  List<String> _addMonsters(DailyRecord today, List<MonsterId> ids) => {
        ...today.purifiedMonsterIds,
        for (final id in ids) id.name,
      }.toList();

  Future<DailyRecord> _todayRecord() async {
    if (_history.isEmpty ||
        _history.last.dayKey != DailyRecord.dayKeyOf(_clock())) {
      await sync(); // 자정이 지났으면 오늘 기록부터 만든다
    }
    return _history.last;
  }

  Future<void> _save(DailyRecord record) async {
    await store.upsert(_withQuests(record));
    _history = await store.loadHistory();
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  DailyRecord? _find(DateTime day) {
    final key = DailyRecord.dayKeyOf(day);
    for (final r in _history) {
      if (r.dayKey == key) return r;
    }
    return null;
  }

  DailyRecord _withQuests(DailyRecord r) =>
      r.copyWith(questsCompleted: QuestRules.completedCount(r));

  Future<DailyRecord> _withHealth(
    DailyRecord record,
    DateTime dayStart,
    DateTime end,
  ) async {
    final steps = await health.stepsBetween(dayStart, end);
    final eightPm =
        DateTime(dayStart.year, dayStart.month, dayStart.day, 20);
    final after8 =
        end.isAfter(eightPm) ? await health.stepsBetween(eightPm, end) : 0;
    final sleep = await health.sleepMinutesForNightBefore(dayStart);
    return record.copyWith(
      steps: steps,
      stepsAfter8pm: after8,
      sleepMinutes: sleep,
    );
  }
}
