import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'core/geo/geo.dart';
import 'core/models/daily_record.dart';
import 'core/models/player_state.dart';
import 'core/models/vitals.dart';
import 'core/rules/rules.dart';
import 'data/health/health_source.dart';
import 'data/location/location_source.dart';
import 'data/notify/notifier.dart';
import 'data/storage/record_store.dart';
import 'data/weather/weather_source.dart';
import 'features/bulssi/bulssi_mood.dart';
import 'features/map/ansan_area.dart';
import 'features/map/korea_area.dart';
import 'features/status/demo_data.dart';

/// 저장소 · 건강 앱 · 화면을 잇는 앱의 중심.
///
/// 앱을 열 때마다 [sync] 로 오늘(과 어제 마감) 걸음을 건강 앱에서 읽어
/// 하루 기록에 반영하고 저장한다. 게임 안에서 생긴 기록(던전 등)은 그대로 둔다.
/// HP · 정령 MP · 여관 휴식 · 정령 원정은 [Vitals] 로 따로 저장한다.
class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    required this.health,
    this.location,
    this.weatherSource,
    this.notifier,
    this.roads,
    this.exclusions,
    this.area = KoreaArea.area,
    this.fallbackCenter = AnsanArea.center,
    this.stepGoal = RuleConstants.defaultStepGoal,
    DateTime Function()? clock,
    math.Random? random,
  })  : _clock = clock ?? DateTime.now,
        _random = random ?? math.Random();

  /// 건강 앱 없이 2주치 예시 기록으로 화면을 보는 모드
  factory AppController.demo({DateTime Function()? clock}) {
    final now = (clock ?? DateTime.now)();
    return AppController(
      store: InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        // 예시 모드는 처음부터 레벨업 연출이 뜨지 않도록 확인한 레벨을 비워 둔다
        history: DemoData.twoWeeks(today: now),
      ),
      health: FakeHealthSource(granted: false),
      stepGoal: 8000, // 예시 기록과 같은 목표
      clock: clock,
    );
  }

  final RecordStore store;
  final HealthSource health;

  /// 위치 (없으면 지도 탐험 없이 동작)
  final LocationSource? location;

  /// 날씨 (없으면 불씨 색은 시간으로만 정한다)
  final WeatherSource? weatherSource;

  /// 휴대폰 알림 (없으면 앱 안에서만 알려 준다)
  final Notifier? notifier;

  /// 큰길·철로 격자. 있으면 필드 몬스터가 차도·철로 위에 나오지 않는다 (지금은 안산만).
  RoadMask? roads;

  /// 전국 제외 구역 (학교·병원·묘지 둘레). 그 안에는 몬스터를 두지 않는다.
  ExclusionIndex? exclusions;

  /// 위치를 아직 모를 때 몬스터를 둘 자리 (예시·테스트용, 실제 앱은 null)
  final GeoPoint? fallbackCenter;

  /// 하루 걸음 목표. 모든 각성자에게 같다 (2026-11-09 결정, 설정에서 바꾸지 않음).
  /// 일일 퀘스트 'N보 걷기', 목표 달성 보너스 열쇠, '끈기의 여행자' 칭호가 이 값을 쓴다.
  final int stepGoal;

  /// 탐험 지역 (11-10부터 전국, 장소는 없음)
  final ExploreArea area;
  final DateTime Function() _clock;

  /// 전투의 피해량 흔들림 (테스트에서는 고정 시드)
  final math.Random _random;

  bool _locationGranted = false;
  LocationFix? _lastFix;
  GamePlace? _lastDiscovery;
  StreamSubscription<LocationFix>? _locationSub;

  bool get locationGranted => _locationGranted;
  LocationFix? get lastFix => _lastFix;

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

  /// 대표 칭호 (고른 것이 없으면 자동)
  TitleId? get equippedTitle => TitleRules.equipped(player.titles,
      chosen: TitleRules.parse(_profile.equippedTitle));

  /// 대표 칭호를 고른다. 얻지 못한 칭호는 고를 수 없다.
  Future<bool> setEquippedTitle(TitleId id) async {
    if (!player.titles.contains(id)) return false;
    await updateProfile(_profile.copyWith(equippedTitle: id.name));
    return true;
  }

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
  Future<void> awaken({
    required String name,
    required HeroLook look,
    bool weatherEnabled = true,
    SpiritKind spirit = SpiritKind.fire,
    String? spiritName,
  }) async {
    final sn = spiritName?.trim();
    _profile = PlayerProfile(
      name: name.trim(),
      look: look,
      lastSeenLevel: 1,
      weatherEnabled: weatherEnabled,
      spiritKind: spirit,
      spiritName: sn == null || sn.isEmpty ? spirit.defaultName : sn,
    );
    _vitals = const Vitals(); // 처음 각성은 HP·MP 가득
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
    _vitals = await store.loadVitals();
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
        _find(today) ?? DailyRecord(date: today, stepGoal: stepGoal);
    if (_healthGranted) {
      todayRecord = await _withHealth(todayRecord, today, now);
    }
    await store.upsert(_withQuests(todayRecord.copyWith(openedApp: true)));

    _history = await store.loadHistory();
    await refreshVitals();
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
    if (!_profile.weatherEnabled) return '날씨 꺼짐';
    final w = _weather;
    if (w == null) return '날씨 확인 중';
    final t = w.temperatureC;
    return t == null ? w.kind.koreanName : '${w.kind.koreanName} ${t.round()}°';
  }

  /// 30분에 한 번만 새로 읽는다. 실패해도 게임은 그대로.
  Future<void> refreshWeather({bool force = false}) async {
    final source = weatherSource;
    if (source == null || !_profile.weatherEnabled) return;
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
        '날짜,걸음,목표,던전,던전클리어,필드몬스터,새장소,다시방문,새안개,휴식,경험치,레벨\n');
    var total = 0;
    for (var i = 0; i < _history.length; i++) {
      final r = _history[i];
      total += p.dailyExp[i].total;
      b.writeln([
        r.dayKey,
        r.steps,
        r.stepGoal,
        r.dungeonRuns.length,
        r.dungeonRuns.where((x) => x.cleared).length,
        r.fieldMonstersPurified,
        r.newPlacesVisited,
        r.placesRevisited,
        r.newCellsRevealed,
        r.restsCompleted,
        p.dailyExp[i].total,
        LevelRules.fromTotalExp(total).level,
      ].join(','));
    }
    b.writeln('# 칭호 ${p.titles.length}개, '
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
    _lastFix = null;
    _lastDiscovery = null;
    _vitals = const Vitals();
    _profile = const PlayerProfile(name: '각성자');
    _needsAwakening = true;
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

  /// 위치가 바뀔 때: 가까운 장소를 방문으로 기록한다 (안개는 11-10에 없앴다)
  Future<void> handleFix(LocationFix fix) async {
    _lastFix = fix;
    if (ExplorationRules.countsAsExploring(fix)) {
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
  /// HP가 0이면 싸울 수 없다 (여관에서 쉬거나 물약·걷기로 채운다).
  /// 여관에서 쉬는 중이었다면 싸우는 순간 휴식이 끝난다 (화면에서 먼저 묻는다).
  Battle? startDungeon() {
    final p = player;
    if (p.gauge.keysAvailable <= 0 || !canFightNow || hp <= 0) return null;
    _stopResting();
    return Battle.forPlayer(
      level: p.level.level,
      stats: p.stats,
      floors: BattleRules.dungeonFloors(
          level: p.level.level, atGate: atGate, rng: _random),
      rng: _random,
      startHp: hp,
      skillChargeTicks: _skillTicks(p),
    );
  }

  int _skillTicks(PlayerState p) {
    if (expedition != null && !expedition!.finished) {
      return Battle.skillUnavailable; // 정령이 원정을 가 있다
    }
    return TownRules.potionActive(p.today)
        ? RuleConstants.potionSkillChargeTicks
        : RuleConstants.skillChargeTicks;
  }

  /// 전투가 끝났거나 중간에 나왔을 때 남은 HP를 저장한다
  Future<void> keepBattleHp(Battle battle) async {
    _vitals = _vitals.copyWith(hp: battle.playerHp, lastMaxHp: maxHp);
    await store.saveVitals(_vitals);
    notifyListeners();
  }

  /// 던전이 끝났을 때 결과를 기록한다. 받은 경험치를 돌려준다.
  Future<int> finishDungeon(Battle battle, {required bool atGate}) async {
    if (!battle.isOver) return 0;
    await keepBattleHp(battle);
    final today = await _todayRecord();
    final run = DungeonRun(
        cleared: battle.phase == BattlePhase.cleared, atGate: atGate);
    final exp = today.dungeonRuns.length < RuleConstants.maxDungeonRunsPerDay
        ? ExpRules.dungeonRunExp(run)
        : 0;
    await _save(today.copyWith(
      dungeonRuns: [...today.dungeonRuns, run],
      purifiedMonsterIds: _addMonsters(today, battle.purified),
      huntCounts: _addCounts(today, battle.purified),
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
    final done = {...?today?.purifiedSpawnIds};
    final away = expedition;
    if (away != null && !away.finished) done.add(away.spawnId);
    final center = _lastFix?.point ?? fallbackCenter;
    if (center == null) return const [];
    return FieldMonsterRules.spawnsFor(area, _clock(),
            center: center, roads: roads, exclusions: exclusions)
        .where((s) => !done.contains(s.id))
        .toList();
  }

  /// 지금 위치에서 만난 필드 몬스터 (없으면 null)
  FieldSpawn? get nearbySpawn {
    final fix = _lastFix;
    if (fix == null) return null;
    return FieldMonsterRules.encounter(
        area: area, spawns: todaySpawns, fix: fix, exclusions: exclusions);
  }

  Battle? startFieldBattle(FieldSpawn spawn) {
    if (!canFightNow || hp <= 0) return null;
    _stopResting();
    final p = player;
    return Battle.forPlayer(
      level: p.level.level,
      stats: p.stats,
      floors: [BattleRules.fieldFoe(level: p.level.level, monster: spawn.monster)],
      rng: _random,
      startHp: hp,
      skillChargeTicks: _skillTicks(p),
    );
  }

  /// 필드 전투가 끝났을 때. 정화하면 그 자리의 안개도 걷힌다.
  Future<int> finishFieldBattle(FieldSpawn spawn, Battle battle) async {
    await keepBattleHp(battle);
    if (battle.phase != BattlePhase.cleared) return 0;
    return _recordFieldPurify(spawn.id, spawn.monster, spawn.point);
  }

  /// 필드 몬스터 정화를 기록한다 (직접 잡았든 정령이 잡았든 같다).
  /// 하루 5마리까지만 경험치·결정을 준다.
  Future<int> _recordFieldPurify(
      String spawnId, MonsterId monster, GeoPoint point) async {
    final today = await _todayRecord();
    if (today.purifiedSpawnIds.contains(spawnId)) return 0;
    final exp =
        today.fieldMonstersPurified < RuleConstants.maxFieldMonstersPerDay
            ? (RuleConstants.fieldMonsterExp *
                    (TownRules.incenseActive(today)
                        ? RuleConstants.incenseExpMultiplier
                        : 1))
                .round()
            : 0;
    await _save(today.copyWith(
      fieldMonstersPurified: today.fieldMonstersPurified + 1,
      purifiedSpawnIds: [...today.purifiedSpawnIds, spawnId],
      purifiedMonsterIds: _addMonsters(today, [monster]),
      huntCounts: _addCounts(today, [monster]),
    ));
    return exp;
  }

  // ───────────────────────────────────────────── 여관 · 잡화상 (앱 안 시설)

  /// 잡화상에서 물건을 산다. 사지 못하면 그 이유를 돌려준다.
  Future<PurchaseCheck> buy(ShopItem item) async {
    final today = await _todayRecord();
    final fix = _lastFix;
    await refreshVitals();
    final check = TownRules.canBuy(_history, item,
        hasLocation: fix != null, level: player.level.level);
    if (check != PurchaseCheck.ok) return check;

    await _save(today.copyWith(
      shopPurchases: [...today.shopPurchases, item.name],
    ));
    return PurchaseCheck.ok;
  }

  /// 가방에 든 개수
  int bagCount(ShopItem item) => TownRules.bagCount(_history, item);

  UseCheck canUse(ShopItem item) => TownRules.canUse(_history, item,
      hpFull: hp >= maxHp,
      mpFull: mp >= RuleConstants.mpMax,
      compassReady: _vitals.compassReady);

  /// 원정 나침반을 써 두었는지 (다음 원정 이동 시간 절반)
  bool get compassReady => _vitals.compassReady;

  /// 가방에서 물약을 꺼내 마신다
  Future<UseCheck> useItem(ShopItem item) async {
    await refreshVitals();
    final check = canUse(item);
    if (check != UseCheck.ok) return check;
    final info = TownRules.info(item);
    if (info.hpRatio > 0) {
      _vitals = _vitals.copyWith(
          hp: math.min(maxHp, hp + (maxHp * info.hpRatio).round()),
          lastMaxHp: maxHp);
    }
    if (info.mpRatio > 0) {
      _vitals = _vitals.copyWith(
          mp: math.min(RuleConstants.mpMax,
              mp + (RuleConstants.mpMax * info.mpRatio).round()));
    }
    if (item == ShopItem.expeditionCompass) {
      _vitals = _vitals.copyWith(compassReady: true);
    }
    await store.saveVitals(_vitals);
    final today = await _todayRecord();
    await _save(today.copyWith(itemsUsed: [...today.itemsUsed, item.name]));
    return UseCheck.ok;
  }

  /// 게임 시계 (테스트에서는 고정 시각)
  DateTime get now => _clock();

  /// 날씨 조회를 켜고 끈다. 끄면 받아 둔 날씨도 버린다.
  Future<void> setWeatherEnabled(bool on) async {
    await updateProfile(_profile.copyWith(weatherEnabled: on));
    if (on) {
      await refreshWeather(force: true);
    } else {
      _weather = null;
      _weatherAt = null;
      notifyListeners();
    }
  }

  // ───────────────────────────────────────────── HP · 정령 MP · 여관 · 정령 원정

  Vitals _vitals = const Vitals();

  /// 전투용 최대 HP
  int get maxHp => player.maxHp;

  /// 지금 HP (전투 사이에 이어진다. 0이면 싸울 수 없다)
  int get hp => math.min(maxHp, _vitals.hp ?? maxHp);

  /// 정령 MP (원정에 쓴다)
  int get mp => math.min(RuleConstants.mpMax, _vitals.mp ?? RuleConstants.mpMax);

  /// 여관에서 쉬는 중이면 체크인 시각
  DateTime? get restStartedAt => _vitals.restStartedAt;
  bool get resting => _vitals.restStartedAt != null;

  /// 휴식이 끝나기까지 남은 시간
  Duration get restLeft => resting
      ? TownRules.restLeft(_vitals.restStartedAt!, _clock())
      : Duration.zero;

  /// 진행 중이거나 결과를 아직 보지 않은 원정
  Expedition? get expedition => _vitals.expedition;

  /// 다음 HP 회복까지 남은 걸음
  int get stepsToNextHeal => VitalRules.stepsToNextHeal(
      player.today?.steps ?? 0,
      _vitals.stepsDay == player.today?.dayKey ? _vitals.stepsCounted : 0);

  /// 시간·걸음에 따라 HP·MP를 채우고, 끝난 휴식과 원정을 마무리한다.
  /// 앱을 열 때, 화면을 볼 때 부른다.
  Future<void> refreshVitals() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await _refreshVitals();
    } finally {
      _refreshing = false;
    }
  }

  bool _refreshing = false;

  Future<void> _refreshVitals() async {
    final now = _clock();
    final p = player;
    final max = p.maxHp;
    var v = _vitals;
    var changed = false;

    // 처음이거나 레벨이 올라 최대 HP가 늘었으면 그만큼 지금 HP도 늘린다
    var curHp = v.hp ?? max;
    final lastMax = v.lastMaxHp;
    if (lastMax != max) {
      if (lastMax != null && max > lastMax) curHp += max - lastMax;
      curHp = math.min(curHp, max);
      v = v.copyWith(hp: curHp, lastMaxHp: max);
      changed = true;
    }

    // 걷기 회복: 1,000보마다 10%
    final today = p.today;
    if (today != null) {
      final counted = v.stepsDay == today.dayKey ? v.stepsCounted : 0;
      final (healed, used) = VitalRules.regenHpFromSteps(
        hp: curHp,
        maxHp: max,
        stepsToday: today.steps,
        stepsCounted: counted,
      );
      if (healed != curHp || used != counted || v.stepsDay != today.dayKey) {
        curHp = healed;
        v = v.copyWith(hp: healed, stepsDay: today.dayKey, stepsCounted: used);
        changed = true;
      }
    }

    // MP 자연 회복
    final (newMp, newAt) =
        VitalRules.regenMp(v.mp ?? RuleConstants.mpMax, v.mpAt ?? now, now);
    if (newMp != v.mp || newAt != v.mpAt) {
      v = v.copyWith(mp: newMp, mpAt: newAt);
      changed = true;
    }

    // 여관 휴식이 끝났으면 HP·MP를 모두 채우고 기록한다
    final restAt = v.restStartedAt;
    if (restAt != null && TownRules.restDone(restAt, now)) {
      v = v.copyWith(
          hp: max, mp: RuleConstants.mpMax, mpAt: now, clearRest: true);
      _vitals = v;
      await store.saveVitals(v);
      _justRested = true;
      final rec = await _todayRecord();
      await store.upsert(
          _withQuests(rec.copyWith(restsCompleted: rec.restsCompleted + 1)));
      _history = await store.loadHistory();
    }

    _vitals = v;
    if (changed) await store.saveVitals(v);

    // 돌아온 원정 마무리
    final ex = v.expedition;
    if (ex != null && !ex.finished && !now.isBefore(ex.returnAt)) {
      await _resolveExpedition(ex);
    }
    notifyListeners();
  }

  bool _justRested = false;

  /// 방금 휴식을 마쳤는지 (화면에서 한 번 알려 주고 [clearJustRested])
  bool get justRested => _justRested;
  void clearJustRested() {
    _justRested = false;
    notifyListeners();
  }

  /// 여관에 체크인한다. 언제든, 하루 여러 번. 이미 쉬는 중이면 false.
  Future<bool> restAtInn() async {
    if (resting) return false;
    await refreshVitals();
    final now = _clock();
    _vitals = _vitals.copyWith(restStartedAt: now);
    await store.saveVitals(_vitals);
    unawaited(notifier?.schedule(
      NotifyId.rest,
      now.add(const Duration(hours: RuleConstants.restHours)),
      '푹 쉬었어요',
      'HP와 ${_profile.spiritName}의 MP가 가득 찼어요. 앱을 열어 휴식 보너스를 받으세요!',
    ));
    notifyListeners();
    return true;
  }

  /// 휴식을 그만둔다 (보상 없이)
  Future<void> stopResting() async {
    if (!resting) return;
    _stopResting();
    await store.saveVitals(_vitals);
    notifyListeners();
  }

  void _stopResting() {
    if (_vitals.restStartedAt != null) {
      _vitals = _vitals.copyWith(clearRest: true);
      unawaited(store.saveVitals(_vitals));
      unawaited(notifier?.cancel(NotifyId.rest));
    }
  }

  // ───────────── 정령 원정

  /// [spawn] 으로 정령을 보낼 수 있는지 (거리·MP·시간 포함)
  ExpeditionPlan planExpedition(FieldSpawn spawn) {
    final from = _lastFix?.point;
    if (from == null) return const ExpeditionPlan(ExpeditionCheck.needsLocation);
    final dist = from.distanceTo(spawn.point);
    final cost = VitalRules.expeditionCost(dist);
    final base = VitalRules.expeditionOneWay(dist);
    // 원정 나침반을 써 두었으면 이동 시간 절반
    final oneWay = _vitals.compassReady ? base ~/ 2 : base;
    ExpeditionCheck check;
    if (expedition != null && !expedition!.finished) {
      check = ExpeditionCheck.busy;
    } else if (mp < cost) {
      // 안개 대신 MP로만 거리를 막는다 (11-10, 최대 MP 60 = 약 3km)
      check = ExpeditionCheck.notEnoughMp;
    } else {
      check = ExpeditionCheck.ok;
    }
    return ExpeditionPlan(check, distanceM: dist, mpCost: cost, oneWay: oneWay);
  }

  /// 정령을 보낸다. MP는 보내는 순간 쓴다.
  Future<ExpeditionCheck> sendSpirit(FieldSpawn spawn) async {
    await refreshVitals();
    final plan = planExpedition(spawn);
    if (plan.check != ExpeditionCheck.ok) return plan.check;
    final now = _clock();
    final arrive = now.add(plan.oneWay);
    _vitals = _vitals.copyWith(
      mp: mp - plan.mpCost,
      mpAt: mp >= RuleConstants.mpMax ? now : _vitals.mpAt,
      expedition: Expedition(
        spawnId: spawn.id,
        monster: spawn.monster.name,
        lat: spawn.point.lat,
        lng: spawn.point.lng,
        fromLat: _lastFix?.point.lat,
        fromLng: _lastFix?.point.lng,
        distanceM: plan.distanceM,
        mpCost: plan.mpCost,
        startedAt: now,
        arriveAt: arrive,
        returnAt: arrive.add(plan.oneWay),
      ),
      compassReady: false, // 나침반은 한 번 쓰면 끝
    );
    await store.saveVitals(_vitals);
    final ret = _vitals.expedition!.returnAt;
    unawaited(notifier?.schedule(
      NotifyId.expedition,
      ret,
      '${_profile.spiritName}이(가) 돌아왔어요',
      '${spawn.info.name} 원정 결과를 확인해 보세요!',
    ));
    notifyListeners();
    return ExpeditionCheck.ok;
  }

  /// 원정 결과를 확인했을 때 (결과 카드를 닫으면)
  Future<void> acknowledgeExpedition() async {
    final ex = expedition;
    if (ex == null || !ex.finished) return;
    _vitals = _vitals.copyWith(clearExpedition: true);
    await store.saveVitals(_vitals);
    notifyListeners();
  }

  /// 원정 경험치 (결과 카드에 보여 준다)
  int _lastExpeditionExp = 0;
  int get lastExpeditionExp => _lastExpeditionExp;

  /// 돌아온 정령의 전투 결과를 정한다. 정령은 각성자의 전투력으로 싸우고
  /// 각성자의 HP는 쓰지 않는다. 지면 MP만 잃고, 몬스터는 그대로 남는다.
  Future<void> _resolveExpedition(Expedition ex) async {
    final monster = Monsters.byName(ex.monster) ?? MonsterId.ashSlime;
    final p = player;
    final battle = Battle.forPlayer(
      level: p.level.level,
      stats: p.stats,
      floors: [BattleRules.fieldFoe(level: p.level.level, monster: monster)],
      rng: math.Random(ex.spawnId.hashCode),
    ).runToEnd(useSkills: true);
    final cleared = battle.phase == BattlePhase.cleared;
    _lastExpeditionExp = cleared
        ? await _recordFieldPurify(ex.spawnId, monster, GeoPoint(ex.lat, ex.lng))
        : 0;
    _vitals = _vitals.copyWith(expedition: ex.withResult(cleared));
    await store.saveVitals(_vitals);
  }

  /// 지금까지 정화한 몬스터 종류 (도감)
  Set<MonsterId> get purifiedEver => {
        for (final r in _history)
          for (final name in r.purifiedMonsterIds)
            if (Monsters.byName(name) case final id?) id,
      };

  Map<String, int> _addCounts(DailyRecord today, List<MonsterId> ids) {
    final m = {...today.huntCounts};
    for (final id in ids) {
      m[id.name] = (m[id.name] ?? 0) + 1;
    }
    return m;
  }

  /// 몬스터 종류별 사냥 수 (도감). 11-10 이전 기록은 사냥한 날 하루에 1마리로 센다.
  Map<MonsterId, int> get huntTotals {
    final totals = <MonsterId, int>{};
    for (final r in _history) {
      if (r.huntCounts.isNotEmpty) {
        r.huntCounts.forEach((name, n) {
          final id = Monsters.byName(name);
          if (id != null) totals[id] = (totals[id] ?? 0) + n;
        });
      } else {
        for (final name in r.purifiedMonsterIds) {
          final id = Monsters.byName(name);
          if (id != null) totals[id] = (totals[id] ?? 0) + 1;
        }
      }
    }
    return totals;
  }

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
    return record.copyWith(steps: steps, stepsAfter8pm: after8);
  }
}

/// 정령 원정을 보낼 수 있는지
enum ExpeditionCheck { ok, needsLocation, notEnoughMp, busy }

class ExpeditionPlan {
  const ExpeditionPlan(
    this.check, {
    this.distanceM = 0,
    this.mpCost = 0,
    this.oneWay = Duration.zero,
  });

  final ExpeditionCheck check;
  final double distanceM;
  final int mpCost;

  /// 한쪽 길 시간 (돌아오기까지는 두 배)
  final Duration oneWay;
}
