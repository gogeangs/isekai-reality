import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'core/format.dart';
import 'core/geo/geo.dart';
import 'core/models/armory.dart';
import 'core/models/board_state.dart';
import 'core/models/daily_record.dart';
import 'core/models/player_state.dart';
import 'core/models/stat_alloc.dart';
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

  // 칭호 얻음 알림 (11-11 #41)
  static const _titlesKey = 'titles';
  Set<TitleId> _seenTitles = {};

  /// 새로 얻었지만 아직 알려 주지 않은 칭호 (없으면 null)
  TitleId? get newTitle {
    for (final t in player.titles) {
      if (!_seenTitles.contains(t)) return t;
    }
    return null;
  }

  Future<void> acknowledgeTitles() async {
    _seenTitles = {..._seenTitles, ...player.titles};
    await _saveSeenTitles();
    notifyListeners();
  }

  Future<void> _saveSeenTitles() => store.saveJson(
      _titlesKey, {'seen': [for (final t in _seenTitles) t.name]});

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
    final alloc = await store.loadJson(_statsKey);
    _alloc = alloc == null ? const StatAlloc() : StatAlloc.fromJson(alloc);
    final armory = await store.loadJson(_armoryKey);
    _armory = armory == null ? const Armory() : Armory.fromJson(armory);
    final board = await store.loadJson(_boardKey);
    _board = board == null ? const BoardState() : BoardState.fromJson(board);
    await sync();
    final titles = await store.loadJson(_titlesKey);
    _seenTitles = titles == null
        ? {...player.titles}
        : {
            for (final n in (titles['seen'] as List? ?? const []))
              if (TitleRules.parse(n as String) case final t?) t,
          };
    if (titles == null) await _saveSeenTitles();
    if (_alloc.seenLife == null) {
      // 예전 저장본·처음 각성: 지금 생활 보너스까지는 이미 알려 준 것으로 친다
      _alloc = _alloc.copyWith(seenLife: StatRules.lifeBonus(_history));
      await store.saveJson(_statsKey, _alloc.toJson());
    }
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

  /// 이름 바꾸기 가격 (11-11 #53): 처음 1번 무료, 그다음 금화 300
  static const int renameGold = 300;
  int get renameCost => _profile.renames == 0 ? 0 : renameGold;

  /// 내 이름을 바꾼다. 빈 이름·같은 이름이면 그대로, 금화가 모자라면 false.
  Future<bool> renameHero(String name) async {
    final n = name.trim();
    if (n.isEmpty || n == _profile.name) return false;
    final cost = renameCost;
    if (player.gold < cost) return false;
    if (cost > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost})));
    }
    await updateProfile(
        _profile.copyWith(name: n, renames: _profile.renames + 1));
    return true;
  }

  // 정령 이름·종류는 각성 때 정하면 바꿀 수 없다 (11-11 #53)

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
    _board = const BoardState();
    _armory = const Armory();
    _alloc = const StatAlloc();
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
      stats: combatStats,
      floors: BattleRules.dungeonFloors(
          level: p.level.level, atGate: atGate, rng: _random),
      rng: _random,
      startHp: hp,
      skillChargeTicks: _skillTicks(p),
      gear: gear,
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
    await _wear(EquipmentRules.dungeonWear);
    final today = await _todayRecord();
    final run = DungeonRun(
        cleared: battle.phase == BattlePhase.cleared, atGate: atGate);
    final exp = today.dungeonRuns.length < RuleConstants.maxDungeonRunsPerDay
        ? ExpRules.dungeonRunExp(run)
        : 0;
    final mats = LootRules.dungeon(cleared: run.cleared, rng: _random);
    await _save(today.copyWith(
      dungeonRuns: [...today.dungeonRuns, run],
      purifiedMonsterIds: _addMonsters(today, battle.purified),
      huntCounts: _addCounts(today, battle.purified),
      gains: DailyRecord.addCounts(
          today.gains, HuntReward.ledger(materials: mats)),
      counters: FieldMonsterRules.isNight(_clock())
          ? DailyRecord.addCounts(
              today.counters, {'nightHunts': battle.purified.length})
          : null,
    ));
    _lastReward = HuntReward(
      exp: exp,
      manaStones: run.cleared
          ? RuleConstants.crystalsPerDungeonClear
          : RuleConstants.crystalsPerDungeonFail,
      materials: mats,
    );
    return exp;
  }

  HuntReward _lastReward = const HuntReward();

  /// 방금 끝난 사냥·던전의 보상 (결과 화면에 보여 준다)
  HuntReward get lastReward => _lastReward;

  /// 오늘 아직 정화하지 않은 필드 몬스터.
  /// 하루 상한(5마리)을 채우면 더 나오지 않는다.
  List<FieldSpawn> get todaySpawns {
    final today = player.today;
    if (today != null &&
        today.fieldMonstersPurified >= RuleConstants.maxFieldMonstersPerDay) {
      return const [];
    }
    final done = {...?today?.purifiedSpawnIds, ...?today?.fledSpawnIds};
    final away = expedition;
    if (away != null && !away.finished) done.add(away.spawnId);
    final center = _lastFix?.point ?? fallbackCenter;
    if (center == null) return const [];
    return FieldMonsterRules.spawnsFor(area, _clock(),
            center: center,
            roads: roads,
            exclusions: exclusions,
            level: player.level.level,
            luckBonus: StatRules.modifierBonus(combatStats))
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
      stats: combatStats,
      floors: BattleRules.fieldFoes(
          level: p.level.level,
          monster: spawn.monster,
          mods: spawn.modifiers,
          spawnId: spawn.id),
      rng: _random,
      startHp: hp,
      skillChargeTicks: _skillTicks(p),
      gear: gear,
    );
  }

  /// 필드 전투가 끝났을 때. 잡으면 보상, 황금빛이 도망치면 오늘은 다시 나오지 않는다.
  Future<int> finishFieldBattle(FieldSpawn spawn, Battle battle) async {
    await keepBattleHp(battle);
    if (battle.ticks > 0) await _wear(EquipmentRules.fieldWear);
    _lastReward = const HuntReward();
    if (battle.phase == BattlePhase.escaped) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          fledSpawnIds: [...today.fledSpawnIds, spawn.id]));
      return 0;
    }
    if (battle.phase == BattlePhase.failed) {
      final today = await _todayRecord();
      if (!today.lostSpawnIds.contains(spawn.id)) {
        await _save(
            today.copyWith(lostSpawnIds: [...today.lostSpawnIds, spawn.id]));
      }
      return 0;
    }
    if (battle.phase != BattlePhase.cleared) return 0;
    return _recordFieldPurify(spawn.id, spawn.monster, spawn.point,
        mods: spawn.modifiers, count: battle.floors.length);
  }

  /// 필드 몬스터 정화를 기록한다 (직접 잡았든 정령이 잡았든 같다).
  /// 하루 5마리까지만 경험치·마석·재료를 준다.
  ///
  /// 수식어(11-10): 경험치 보너스, 마석·금화·재료 추가. 무리·분열·동료는 마리 수만큼
  /// 받지만 하루 5마리 제한에는 1마리로 센다.
  Future<int> _recordFieldPurify(
    String spawnId,
    MonsterId monster,
    GeoPoint point, {
    List<ModifierId> mods = const [],
    int count = 1,
  }) async {
    final today = await _todayRecord();
    _lastReward = const HuntReward();
    if (today.purifiedSpawnIds.contains(spawnId)) return 0;
    final paid =
        today.fieldMonstersPurified < RuleConstants.maxFieldMonstersPerDay;
    final baseExp = paid
        ? (RuleConstants.fieldMonsterExp *
                (TownRules.incenseActive(today)
                    ? RuleConstants.incenseExpMultiplier
                    : 1))
            .round()
        : 0;
    // 수식어·속성 보너스와 마리 수 (11-11: 기록에 남겨 경험치에 더한다)
    final exp = paid
        ? (baseExp *
                (ModifierRules.expMultiplier(mods) +
                    Monsters.info(monster).expBonus) *
                count)
            .round()
        : 0;
    // 기본 마석 1개는 규칙(하루 5마리)으로 계산하고, 나머지는 기록에 더한다
    final mats = <MaterialId, int>{};
    var extraMana = 0, gold = 0;
    if (paid) {
      for (var i = 0; i < count; i++) {
        LootRules.field(monster, _random,
                rareBonus: StatRules.rareDropBonus(combatStats))
            .forEach((k, v) => mats[k] = (mats[k] ?? 0) + v);
      }
      final b = ModifierRules.bonus(monster, mods, _random);
      b.materials.forEach((k, v) => mats[k] = (mats[k] ?? 0) + v);
      extraMana = (count - 1) * RuleConstants.crystalsPerFieldMonster +
          b.manaStones;
      gold = b.gold;
    }
    final modKey = ModifierRules.recordInCodex(mods)
        ? ModifierRules.codexKey(monster, mods)
        : null;
    await _save(today.copyWith(
      fieldMonstersPurified: today.fieldMonstersPurified + 1,
      purifiedSpawnIds: [...today.purifiedSpawnIds, spawnId],
      purifiedMonsterIds: _addMonsters(today, [monster]),
      huntCounts: _addCounts(today, List.filled(count, monster)),
      gains: DailyRecord.addCounts(today.gains, {
        ...HuntReward.ledger(
            extraManaStones: extraMana, gold: gold, materials: mats),
        if (exp > baseExp) Wallet.exp: exp - baseExp,
      }),
      modHunts: modKey == null
          ? null
          : DailyRecord.addCounts(today.modHunts, {modKey: 1}),
      counters: DailyRecord.addCounts(today.counters, {
        if (mods.isNotEmpty) 'modded': 1,
        if (ModifierRules.gradeOf(mods).index >= ModGrade.rare.index)
          'rarePlus': 1,
        for (final m in mods) 'mod:${m.name}': 1,
        if (FieldMonsterRules.isNight(_clock())) 'nightHunts': count,
        if (today.lostSpawnIds.contains(spawnId)) 'revenge': 1,
      }),
    ));
    _lastReward = HuntReward(
      exp: exp,
      manaStones:
          paid ? RuleConstants.crystalsPerFieldMonster + extraMana : 0,
      gold: gold,
      materials: mats,
    );
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
      goldPurchases: [...today.goldPurchases, item.name],
    ));
    return PurchaseCheck.ok;
  }

  /// 마석 [count] 개를 금화로 판다 (1개에 금화 10). 모자라면 false.
  Future<bool> sellManaStones(int count) async {
    final today = await _todayRecord();
    if (!TownRules.canSell(_history, count)) return false;
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {Wallet.manaStone: count}),
      gains: DailyRecord.addCounts(today.gains,
          {Wallet.gold: count * RuleConstants.goldPerManaStone}),
    ));
    return true;
  }

  /// 가방에 든 개수
  int bagCount(ShopItem item) => TownRules.bagCount(_history, item);

  UseCheck canUse(ShopItem item) => TownRules.canUse(_history, item,
      hpFull: hp >= maxHp,
      mpFull: mp >= mpMax,
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
          mp: math.min(mpMax, mp + (mpMax * info.mpRatio).round()));
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

  // ───────────────────────────────────────────── 스탯 5종 (11-11 #50)

  static const _statsKey = 'stats';
  StatAlloc _alloc = const StatAlloc();

  /// 포인트로 올린 값
  Stats get allocatedStats => _alloc.allocated;

  /// 지금까지 받은 포인트 중 아직 나누지 않은 것
  int get unspentPoints =>
      math.max(0, StatRules.pointsFor(player.level.level) - _alloc.allocated.total);

  /// 화면에 보이는 스탯 (시작 값 + 생활 보너스 + 포인트). 합계만 보여 준다.
  Stats get shownStats => player.stats + _alloc.allocated;

  /// 전투에 쓰는 스탯: 아직 나누지 않은 포인트는 고르게 나눈 것처럼 친다
  Stats get combatStats =>
      shownStats + StatRules.evenShare(unspentPoints);

  /// 초기화 비용 (처음 1번 무료)
  int get statResetCost => StatRules.resetCost(_alloc.resets);
  int get statResets => _alloc.resets;

  /// 포인트를 나눈다. [add] 의 합이 남은 포인트보다 많으면 false.
  Future<bool> allocateStats(Stats add) async {
    if (add.total <= 0 || add.total > unspentPoints) return false;
    for (final k in StatKind.values) {
      if (add.of(k) < 0) return false;
    }
    _alloc = _alloc.copyWith(allocated: _alloc.allocated + add);
    await store.saveJson(_statsKey, _alloc.toJson());
    await refreshVitals();
    notifyListeners();
    return true;
  }

  /// 포인트로 올린 값만 되돌린다 (생활 보너스는 그대로). 금화가 모자라면 false.
  Future<bool> resetStats() async {
    if (_alloc.allocated.total == 0) return false;
    final cost = statResetCost;
    if (player.gold < cost) return false;
    if (cost > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost})));
    }
    _alloc = _alloc.copyWith(allocated: Stats.zero, resets: _alloc.resets + 1);
    await store.saveJson(_statsKey, _alloc.toJson());
    await refreshVitals();
    notifyListeners();
    return true;
  }

  /// 생활 보너스가 올라서 정령이 할 한 줄 (이유는 말하지 않는다). 없으면 null.
  String? get lifeBonusLine {
    final seen = _alloc.seenLife;
    if (seen == null) return null;
    final now = StatRules.lifeBonus(_history);
    for (final k in StatKind.values) {
      if (now.of(k) > seen.of(k)) return _lifeLines[k];
    }
    return null;
  }

  static const _lifeLines = {
    StatKind.strength: '요즘 힘이 불끈불끈 솟는 것 같지 않아?',
    StatKind.agility: '어? 왠지 몸이 가벼워진 것 같아!',
    StatKind.intellect: '머리가 맑아진 느낌이야. 뭔가 더 잘 보여!',
    StatKind.vitality: '숨이 덜 차는 것 같아. 튼튼해졌나 봐!',
    StatKind.luck: '오늘따라 운이 좋은 것 같아!',
  };

  String? _shownLifeLine;

  /// 상태 화면에 보여 줄 생활 보너스 한 줄. 한 번 보여 주면 알려 준 것으로 기록하고
  /// 이번에 앱을 켜 둔 동안만 남긴다.
  String? get statusLifeLine {
    final line = lifeBonusLine;
    if (line != null && line != _shownLifeLine) {
      _shownLifeLine = line;
      Future.microtask(acknowledgeLifeBonus);
    }
    return _shownLifeLine;
  }

  /// 정령 한 줄을 보여 줬을 때
  Future<void> acknowledgeLifeBonus() async {
    _alloc = _alloc.copyWith(seenLife: StatRules.lifeBonus(_history));
    await store.saveJson(_statsKey, _alloc.toJson());
    notifyListeners();
  }

  // ───────────────────────────────────────────── 대장간 · 장비 (11-10 #27)

  static const _armoryKey = 'armory';
  Armory _armory = const Armory();

  /// 가진 장비와 입은 장비
  Armory get armory => _armory;

  /// 입은 장비의 힘
  GearBonus get gear => EquipmentRules.bonusOf(_armory.worn);

  Future<void> _saveArmory(Armory a) async {
    _armory = a;
    await store.saveJson(_armoryKey, a.toJson());
    // 최대 HP가 바뀌었을 수 있다
    await refreshVitals();
    notifyListeners();
  }

  /// 만들 수 있는지 (재료·마석). [rare] 는 더 넣을 귀한 재료.
  CraftCheck canCraft(EquipBase base, {MaterialId? rare}) {
    final info = EquipmentRules.info(base);
    final p = player;
    for (final e in info.recipe.entries) {
      if (p.materialCount(e.key) < e.value) return CraftCheck.materials;
    }
    if (rare != null) {
      final need = (info.recipe[rare] ?? 0) + 1;
      if (p.materialCount(rare) < need) return CraftCheck.materials;
    }
    if (p.manaStones < info.manaStones) return CraftCheck.manaStones;
    return CraftCheck.ok;
  }

  /// 대장간에서 장비를 만든다. 만든 장비를 돌려준다 (못 만들면 null).
  Future<EquipItem?> craft(EquipBase base, {MaterialId? rare}) async {
    if (canCraft(base, rare: rare) != CraftCheck.ok) return null;
    final info = EquipmentRules.info(base);
    final used = <String, int>{
      for (final e in info.recipe.entries) e.key.name: e.value,
      if (rare != null) rare.name: (info.recipe[rare] ?? 0) + 1,
    };
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {
        ...used,
        if (info.manaStones > 0) Wallet.manaStone: info.manaStones,
      }),
    ));
    final a = _armory;
    final grade =
        EquipmentRules.rollGrade(_random, rare: rare != null, crafts: a.crafts);
    final item = EquipItem(
      uid: 'eq${a.nextId}',
      base: base,
      grade: grade,
      extras: EquipmentRules.rollExtras(grade, _random),
      materialsUsed: used,
    );
    await _saveArmory(a.copyWith(
      items: [...a.items, item],
      crafts: a.crafts + 1,
      nextId: a.nextId + 1,
    ));
    return item;
  }

  /// 강화할 수 있는지
  CraftCheck canEnhance(EquipItem item) {
    if (item.enhance >= EquipmentRules.maxEnhance) return CraftCheck.maxed;
    final cost = EquipmentRules.enhanceCost(item.enhance + 1);
    final p = player;
    if (p.manaStones < cost.manaStones) return CraftCheck.manaStones;
    if (p.gold < cost.gold) return CraftCheck.gold;
    return CraftCheck.ok;
  }

  /// 강화한다. 성공하면 true. 실패해도 장비는 그대로 (비용만 쓴다).
  Future<bool?> enhance(String uid) async {
    final item = _armory.byUid(uid);
    if (item == null || canEnhance(item) != CraftCheck.ok) return null;
    final to = item.enhance + 1;
    final cost = EquipmentRules.enhanceCost(to);
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends,
          {Wallet.manaStone: cost.manaStones, Wallet.gold: cost.gold}),
    ));
    final ok = _random.nextDouble() < EquipmentRules.enhanceChance(to);
    await _saveArmory(_armory.replace(item.copyWith(
      enhance: ok ? to : item.enhance,
      enhanceManaSpent: item.enhanceManaSpent + cost.manaStones,
    )));
    return ok;
  }

  /// 내구도를 다 고친다
  Future<bool> repair(String uid) async {
    final item = _armory.byUid(uid);
    if (item == null) return false;
    final cost = EquipmentRules.repairCost(item);
    if (cost <= 0 || player.gold < cost) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost}),
    ));
    await _saveArmory(_armory.replace(
        item.copyWith(durability: EquipmentRules.maxDurability)));
    return true;
  }

  /// 분해한다 (재료 절반과 마석 1, 강화 마석 절반을 돌려받는다)
  Future<bool> disassemble(String uid) async {
    final item = _armory.byUid(uid);
    if (item == null) return false;
    final back = EquipmentRules.salvage(item);
    await _grant(0, back.manaStones, back.materials);
    final a = _armory;
    await _saveArmory(a.copyWith(
      items: [for (final i in a.items) if (i.uid != uid) i],
      equipped: {
        for (final e in a.equipped.entries)
          if (e.value != uid) e.key: e.value,
      },
    ));
    return true;
  }

  /// 입는다 (같은 부위의 장비는 벗는다)
  Future<void> equip(String uid) async {
    final item = _armory.byUid(uid);
    if (item == null) return;
    await _saveArmory(
        _armory.copyWith(equipped: {..._armory.equipped, item.slot: uid}));
  }

  Future<void> unequip(EquipSlot slot) async {
    await _saveArmory(_armory.copyWith(equipped: {
      for (final e in _armory.equipped.entries)
        if (e.key != slot) e.key: e.value,
    }));
  }

  /// 싸울 때마다 입은 장비의 내구도가 준다
  Future<void> _wear(int n) async {
    final worn = _armory.worn;
    if (worn.isEmpty) return;
    var a = _armory;
    for (final item in worn) {
      a = a.replace(item.copyWith(
          durability: math.max(0, item.durability - n)));
    }
    _armory = a;
    await store.saveJson(_armoryKey, a.toJson());
  }

  // ───────────────────────────────────────────── 의뢰 게시판 (11-10 #26)

  static const _boardKey = 'board';
  BoardState _board = const BoardState();

  /// 지금 시각의 게시판 (날짜가 바뀌었거나 기다리던 의뢰가 올라왔으면 반영)
  BoardState get board => BoardRules.refresh(_board, _clock());

  Future<void> _saveBoard(BoardState b) async {
    _board = b;
    await store.saveJson(_boardKey, b.toJson());
    notifyListeners();
  }

  /// 수시 의뢰 진행 (수락한 뒤로 센 수)
  int errandProgress(int slot) {
    final s = board.slots[slot];
    final t = BoardRules.template(s.templateId);
    final today = player.today;
    if (t == null || !s.accepted || today == null) return 0;
    return BoardRules.progress(t, today, s.baseline);
  }

  Future<void> acceptErrand(int slot) async {
    final b = board;
    final s = b.slots[slot];
    final t = BoardRules.template(s.templateId);
    if (t == null || s.accepted) return;
    final today = await _todayRecord();
    final slots = [...b.slots];
    slots[slot] = ErrandSlot(
      templateId: t.id,
      accepted: true,
      baseline: BoardRules.counterValue(today, t.counter),
    );
    await _saveBoard(b.copyWith(slots: slots));
  }

  /// 다 한 수시 의뢰의 보상을 받는다. 2시간 뒤 새 의뢰가 올라온다.
  Future<bool> claimErrand(int slot) async {
    final b = board;
    final s = b.slots[slot];
    final t = BoardRules.template(s.templateId);
    if (t == null || !s.accepted || errandProgress(slot) < t.target) {
      return false;
    }
    await _grant(t.gold, t.manaStones, t.materials);
    await _count('errandDone');
    final slots = [...b.slots];
    slots[slot] =
        ErrandSlot(readyAt: _clock().add(BoardRules.errandCooldown));
    await _saveBoard(b.copyWith(slots: slots, doneToday: b.doneToday + 1));
    return true;
  }

  /// 수시 의뢰를 포기한다 (보상 없이, 2시간 뒤 새 의뢰)
  Future<void> abandonErrand(int slot) async {
    final b = board;
    final slots = [...b.slots];
    slots[slot] =
        ErrandSlot(readyAt: _clock().add(BoardRules.errandCooldown));
    await _saveBoard(b.copyWith(slots: slots));
  }

  /// 오늘 떠 있는 긴급 의뢰 (아직 안 떴거나 없는 날은 null)
  ({
    ErrandTemplate quest,
    DateTime appearsAt,
    UrgentPrize prize,
    MaterialId rare,
  })? get urgent {
    final u = BoardRules.urgentFor(_clock());
    if (u == null || _clock().isBefore(u.appearsAt)) return null;
    return u;
  }

  int get urgentProgress {
    final u = urgent;
    final today = player.today;
    if (u == null || !board.urgentAccepted || today == null) return 0;
    return BoardRules.progress(u.quest, today, board.urgentBaseline);
  }

  Future<void> acceptUrgent() async {
    final u = urgent;
    if (u == null || board.urgentAccepted) return;
    final today = await _todayRecord();
    await _saveBoard(board.copyWith(
      urgentAccepted: true,
      urgentBaseline: BoardRules.counterValue(today, u.quest.counter),
    ));
  }

  Future<bool> claimUrgent() async {
    final u = urgent;
    final b = board;
    if (u == null || !b.urgentAccepted || b.urgentDone) return false;
    if (urgentProgress < u.quest.target) return false;
    if (u.prize == UrgentPrize.key) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          counters: DailyRecord.addCounts(today.counters, {'bonusKeys': 1})));
      await _grant(u.quest.gold, 0, const {});
    } else {
      await _grant(u.quest.gold, 0, {u.rare: 1});
    }
    await _count('urgentDone');
    await _saveBoard(b.copyWith(urgentDone: true));
    return true;
  }

  /// 오늘 기록의 수 하나를 늘린다 (생활 보너스·의뢰용)
  Future<void> _count(String key, [int n = 1]) async {
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters, {key: n})));
  }

  Future<void> _grant(
      int gold, int manaStones, Map<MaterialId, int> materials) async {
    final today = await _todayRecord();
    await _save(today.copyWith(
      gains: DailyRecord.addCounts(
          today.gains,
          HuntReward.ledger(
              extraManaStones: manaStones, gold: gold, materials: materials)),
    ));
  }

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

  /// 전투용 최대 HP (장비 포함)
  int get maxHp {
    final p = player;
    return Battle.playerMaxHpWith(
        level: p.level.level, stats: combatStats, gear: gear);
  }

  /// 지금 HP (전투 사이에 이어진다. 0이면 싸울 수 없다)
  int get hp => math.min(maxHp, _vitals.hp ?? maxHp);

  /// 정령 MP (원정에 쓴다)
  int get mp => math.min(mpMax, _vitals.mp ?? mpMax);

  /// 최대 MP (지능, 11-11 #50)
  int get mpMax => StatRules.maxMp(combatStats + gear.stats);

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
    final max = maxHp;
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
        VitalRules.regenMp(v.mp ?? mpMax, v.mpAt ?? now, now, max: mpMax);
    if (newMp != v.mp || newAt != v.mpAt) {
      v = v.copyWith(mp: newMp, mpAt: newAt);
      changed = true;
    }

    // 여관 휴식이 끝났으면 HP·MP를 모두 채우고 기록한다
    final restAt = v.restStartedAt;
    if (restAt != null && TownRules.restDone(restAt, now)) {
      v = v.copyWith(
          hp: max, mp: mpMax, mpAt: now, clearRest: true);
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
      mpAt: mp >= mpMax ? now : _vitals.mpAt,
      expedition: Expedition(
        spawnId: spawn.id,
        monster: spawn.monster.name,
        mods: [for (final m in spawn.modifiers) m.name],
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
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters, {'expedition': 1})));
    final ret = _vitals.expedition!.returnAt;
    unawaited(notifier?.schedule(
      NotifyId.expedition,
      ret,
      '${josa(_profile.spiritName, '이/가')} 돌아왔어요',
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
    final mods = [
      for (final n in ex.mods)
        if (ModifierRules.byName(n) case final m?) m,
    ];
    final p = player;
    final battle = Battle.forPlayer(
      level: p.level.level,
      stats: combatStats,
      floors: BattleRules.fieldFoes(
          level: p.level.level,
          monster: monster,
          mods: mods,
          spawnId: ex.spawnId),
      rng: math.Random(ex.spawnId.hashCode),
      gear: gear,
    ).runToEnd(useSkills: true);
    final cleared = battle.phase == BattlePhase.cleared;
    final escaped = battle.phase == BattlePhase.escaped;
    if (escaped) {
      final today = await _todayRecord();
      await _save(
          today.copyWith(fledSpawnIds: [...today.fledSpawnIds, ex.spawnId]));
    }
    final isNew = !purifiedEver.contains(monster);
    if (cleared) await _count('expeditionWin');
    _lastExpeditionExp = cleared
        ? await _recordFieldPurify(ex.spawnId, monster, GeoPoint(ex.lat, ex.lng),
            mods: mods, count: battle.floors.length)
        : 0;
    final r = _lastReward;
    _vitals = _vitals.copyWith(
        expedition: ex.withResult(cleared,
            escaped: escaped,
            newSpecies: cleared && isNew,
            reward: cleared
                ? {
                    if (r.exp > 0) 'exp': r.exp,
                    if (r.manaStones > 0) Wallet.manaStone: r.manaStones,
                    if (r.gold > 0) Wallet.gold: r.gold,
                    for (final e in r.materials.entries) e.key.name: e.value,
                  }
                : const {}));
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

  /// 도감 '수식어' 칸: 희귀·전설 수식어 몬스터별 사냥 수
  Map<String, int> get modHuntTotals {
    final m = <String, int>{};
    for (final r in _history) {
      r.modHunts.forEach((k, v) => m[k] = (m[k] ?? 0) + v);
    }
    return m;
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
    // 오전 5~8시 걸음 (숨은 생활 보너스)
    final five = DateTime(dayStart.year, dayStart.month, dayStart.day, 5);
    final eight = DateTime(dayStart.year, dayStart.month, dayStart.day, 8);
    final morning = end.isAfter(five)
        ? await health.stepsBetween(five, end.isBefore(eight) ? end : eight)
        : 0;
    return record.copyWith(
        steps: steps, stepsAfter8pm: after8, stepsMorning: morning);
  }
}

/// 대장간에서 만들거나 강화할 수 있는지
enum CraftCheck { ok, materials, manaStones, gold, maxed }

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
