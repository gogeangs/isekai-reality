import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'core/format.dart';
import 'core/geo/geo.dart';
import 'core/geo/route_grid.dart';
import 'core/models/alchemy_state.dart';
import 'core/models/armory.dart';
import 'core/models/bag_state.dart';
import 'core/models/board_state.dart';
import 'core/models/daily_record.dart';
import 'core/models/gather_state.dart';
import 'core/models/drive_state.dart';
import 'core/models/harvest_state.dart';
import 'core/models/lens_state.dart';
import 'core/models/mail_state.dart';
import 'core/models/pet_state.dart';
import 'core/models/player_state.dart';
import 'core/models/stat_alloc.dart';
import 'core/models/vitals.dart';
import 'core/rules/rules.dart';
import 'data/health/health_source.dart';
import 'data/location/location_source.dart';
import 'data/mail/mail_source.dart';
import 'data/notify/notifier.dart';
import 'data/route/route_tile_source.dart';
import 'data/storage/record_store.dart';
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
        // 예시 모드는 Lv.14라 정령과 이미 헤어지고 부엉이와 함께한다 (11-11 #37)
        json: {'pets': DemoData.pets(today: now).toJson()},
      ),
      health: FakeHealthSource(granted: false),
      stepGoal: 8000, // 예시 기록과 같은 목표
      clock: clock,
    )
      ..walkEvents = false // 예시 모드는 걸음 주머니·길가 알림을 띄우지 않는다
      ..quietTitles = true; // 예시 모드는 처음 칭호들을 축하 창 대신 띠로
  }

  final RecordStore store;
  final HealthSource health;

  /// 위치 (없으면 지도 탐험 없이 동작)
  final LocationSource? location;


  /// 휴대폰 알림 (없으면 앱 안에서만 알려 준다)
  final Notifier? notifier;

  /// 큰길·철로 격자. 있으면 필드 몬스터가 차도·철로 위에 나오지 않는다 (지금은 안산만).
  RoadMask? roads;

  /// 장소 종류 격자 (묶음 13 C7, OSM). 없으면 채집 자리를 고르게, 배경은 기본
  PlaceGrid? lands;

  /// 그 자리의 장소 종류 (격자가 없으면 null)
  LandKind? landAt(GeoPoint p) => lands?.kindAt(p);

  /// 전국 제외 구역 (학교·병원·묘지 둘레). 그 안에는 몬스터를 두지 않는다.
  ExclusionIndex? exclusions;

  /// 원정 길 조각 (11-11 #42). 없으면 원정은 직선으로 날아간다.
  RouteTileSource routeTiles = const NoRouteTiles();

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

  PlayerState get player => PlayerState.fromHistory(
      name: _profile.name,
      history: _history,
      expCap: inTutorial ? LevelRules.totalExpToReach(2) - 1 : null);

  /// 튜토리얼에서 모아 둔 경험치까지 센 값
  int get _fullExp =>
      PlayerState.fromHistory(name: _profile.name, history: _history).totalExp;

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

  /// 칭호 축하 창 대신 위쪽 띠로만 (예시 모드)
  bool quietTitles = false;

  /// 칭호 하나만 알린 것으로 (축하 연출을 하나씩, 11-11 #85)
  Future<void> acknowledgeTitle(TitleId t) async {
    _seenTitles = {..._seenTitles, t};
    await _saveSeenTitles();
    notifyListeners();
  }

  /// 전투 화면이 열려 있는 동안 칭호 축하 같은 큰 연출을 미룬다 (11-11 #85)
  bool get holdNotices => _holdNotices > 0;
  int _holdNotices = 0;
  void holdNoticesWhile(bool on) {
    _holdNotices = (_holdNotices + (on ? 1 : -1)).clamp(0, 99);
    // 화면을 닫는 중(dispose)에 불릴 수 있어 한 박자 뒤에 알린다
    if (!on) Future<void>.microtask(notifyListeners);
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

  // 이용 연령 (11-11 #86): 만 14세 미만으로 확인되면 이용할 수 없다
  static const _ageKey = 'age';
  bool _ageBlocked = false;
  bool get ageBlocked => _ageBlocked;

  Future<void> blockForAge() async {
    _ageBlocked = true;
    await store.saveJson(_ageKey, {'blocked': true});
    notifyListeners();
  }

  /// 시작하다 생긴 오류 (묶음 16 #124). 있으면 화면이 「다시 시도」를 보여 준다
  String? get startError => _startError;
  String? _startError;

  /// 읽지 못해 기본값으로 시작한 기록 이름 (나머지 기록은 그대로 지킨다)
  List<String> get loadIssues => List.unmodifiable(_loadIssues);
  final List<String> _loadIssues = [];

  /// 시작 (묶음 16 #124): 기록 하나를 못 읽어도 앱은 켜진다. 그래도 멈추면
  /// 무한 로딩 대신 「다시 시도」 화면 + 오류 기록
  Future<void> init() async {
    _startError = null;
    notifyListeners();
    try {
      await _init().timeout(const Duration(seconds: 40));
    } catch (e, st) {
      _startError = '$e';
      await _logStartError(e, st);
      notifyListeners();
    }
  }

  Future<void> _logStartError(Object e, StackTrace st) async {
    try {
      final old = await store.loadJson(_startErrorsKey);
      final list = [...((old?['list'] as List?) ?? const [])];
      list.add({
        'at': _clock().toIso8601String(),
        'error': '$e',
        'stack': st.toString().split('\n').take(8).join('\n'),
        'build': const String.fromEnvironment('APP_BUILD'),
      });
      while (list.length > 5) {
        list.removeAt(0);
      }
      await store.saveJson(_startErrorsKey, {'list': list});
    } catch (_) {}
  }

  static const _startErrorsKey = 'startErrors';

  /// 저장 기록 하나를 읽는다. 틀린 기록이면 원본을 따로 남기고(지우지 않음) 기본값으로
  Future<T> _load<T>(String key, T Function(Map<String, dynamic>) parse,
      T fallback) async {
    Map<String, dynamic>? raw;
    try {
      raw = await store.loadJson(key);
      if (raw == null) return fallback;
      return parse(raw);
    } catch (e) {
      _loadIssues.add(key);
      try {
        if (raw != null) await store.saveJson('$key.broken', raw);
      } catch (_) {}
      return fallback;
    }
  }

  Future<void> _init() async {
    _loadIssues.clear();
    _ageBlocked = await _load(_ageKey, (j) => j['blocked'] == true, false);
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
    SpiritKind spirit = SpiritKind.fire,
    String? spiritName,
  }) async {
    final sn = spiritName?.trim();
    _profile = PlayerProfile(
      name: name.trim(),
      look: look,
      lastSeenLevel: 1,
      spiritKind: spirit,
      spiritName: sn == null || sn.isEmpty ? spirit.defaultName : sn,
    );
    _vitals = const Vitals(); // 처음 각성은 HP·MP 가득
    await store.saveProfile(_profile);
    // 묶음 15 #104: 새로 시작하는 사람만 Lv.1~2 튜토리얼 (기존 사용자는 그대로)
    if (player.level.level < 2 && player.history.every((d) => d.fieldMonstersPurified == 0)) {
      // 묶음 16 #140: 지도가 이세계로 물드는 연출부터
      await _setTutorial(TutorialStep.intro);
      _justAwakened = true;
      // 묶음 16 #141~#144: 새로 시작하는 사람만 레벨에 따라 기능이 열린다
      await store.saveJson(_gatesKey, {'legacy': false, 'seen': <String>[]});
    }
    _needsAwakening = false;
    await _startPlaying();
  }

  /// 레벨 업하면 HP·정령(펫) MP를 가득 채우고 지친 상태를 푼다 (묶음 14 #102).
  /// 레벨 업 창을 띄울 때 한 번 부른다(여러 레벨이 한꺼번에 올라도 한 번).
  /// 전투 중에는 부르지 않는다: 창은 전투·결과 화면을 닫은 뒤에 뜬다.
  /// 채우기 전 값을 돌려준다 (막대가 차오르는 연출용).
  Future<({int hp, int maxHp, int mp, int mpMax})> levelUpHeal() async {
    final before = (hp: hp, maxHp: maxHp, mp: mp, mpMax: mpMax);
    _vitals = Vitals(
      hp: null,
      lastMaxHp: maxHp,
      mp: null,
      mpAt: _clock(),
      stepsDay: _vitals.stepsDay,
      stepsCounted: _vitals.stepsCounted,
      restStartedAt: _vitals.restStartedAt,
      expeditions: _vitals.expeditions,
      compassReady: _vitals.compassReady,
    );
    await store.saveVitals(_vitals);
    if (_tiredUntil != null) await _setTired(null);
    notifyListeners();
    return before;
  }

  /// 레벨업 연출을 닫았을 때
  Future<void> acknowledgeLevelUp() async {
    await updateProfile(_profile.copyWith(lastSeenLevel: player.level.level));
  }

  Future<void> _startPlaying() async {
    // 건강 데이터 권한·위치는 늦으면 기다리지 않는다 (화면 먼저, 뒤에서 채운다)
    final perm = health.requestPermission().catchError((_) => false);
    _healthGranted =
        await perm.timeout(const Duration(seconds: 8), onTimeout: () {
      // 늦게 허용되면 그때 걸음을 채운다
      unawaited(perm.then((granted) async {
        if (granted && !_healthGranted && _ready) {
          _healthGranted = true;
          try {
            await sync();
          } catch (_) {}
        }
      }));
      return false;
    });
    try {
      _vitals = await store.loadVitals();
    } catch (_) {
      _loadIssues.add('vitals');
      _vitals = const Vitals();
    }
    _alloc = await _load(_statsKey, StatAlloc.fromJson, const StatAlloc());
    _armory = await _load(_armoryKey, Armory.fromJson, const Armory());
    final feel = await _load(_feelKey, (j) => j, const <String, dynamic>{});
    _vibrate = feel['vibrate'] != false;
    _sound = feel['sound'] != false;
    _fastBattle = feel['fast'] == true;
    _poisonTipSeen = feel['poisonTip'] == true;
    _petCodexSeen = feel['petCodex'] == true;
    _petCodexAnnounced = feel['petCodexNotice'] == true;
    _adPersonal = feel['adPersonal'] is bool ? feel['adPersonal'] as bool : null;
    _tutorial = await _load(
        _tutorialKey, (j) => (j['step'] as num?)?.toInt() ?? 0, 0);
    // 묶음 18 #150: 연출 단계에서 앱을 껐다 켜면 첫 전투부터 이어서
    if (_tutorial == TutorialStep.intro.index && !_justAwakened) {
      _tutorial = TutorialStep.hunt.index;
      await store.saveJson(_tutorialKey, {'step': _tutorial});
    }
    _tiredUntil = await _load(_tiredKey,
        (j) => DateTime.tryParse('${j['until'] ?? ''}'), null);
    _board = await _load(_boardKey, BoardState.fromJson, const BoardState());
    _bag = await _load(_bagKey, BagState.fromJson, const BagState());
    _pets = await _load(_petsKey, PetState.fromJson, const PetState());
    _alc = await _load(_alchemyKey, AlchemyState.fromJson, const AlchemyState());
    _gather = await _load(_gatherKey, GatherState.fromJson, const GatherState());
    _harvest =
        await _load(_harvestKey, HarvestState.fromJson, const HarvestState());
    _drive = await _load(_driveKey, DriveState.fromJson, const DriveState());
    // 오래전에 막힌 화면은 풀어 둔다 (위치가 꺼져 있으면 끝을 알 수 없다)
    if (_drive.mode != DriveMode.none &&
        (_drive.askedAt == null ||
            _clock().difference(_drive.askedAt!) > const Duration(minutes: 30))) {
      _drive = _drive.copyWith(mode: DriveMode.none);
    }
    _mail = await _load(_mailKey, MailState.fromJson, const MailState());
    final gates = await _load(_gatesKey, (j) => j, null);
    if (gates == null) {
      // 이번 묶음 전부터 하던 사람: 기능을 잠그지 않는다
      _legacyGates = true;
      _introsSeen = {for (final f in Feature.values) f.name};
      _hpTipShown = true;
      await _saveGates();
    } else {
      _legacyGates = gates['legacy'] != false;
      _introsSeen = {
        for (final x in (gates['seen'] as List?) ?? const []) '$x'
      };
      _hpTipShown = gates['hpTip'] == true || _legacyGates;
    }
    _lens = await _load(_lensKey, LensState.fromJson, const LensState());
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
    // 위치 권한은 오래 기다리지 않는다 (늦으면 화면 먼저, 뒤에서 마저 채운다)
    try {
      await _startExploring()
          .catchError((_) {})
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
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
      final closed = await _withHealth(y, yesterday, today)
          .catchError((_) => y)
          .timeout(const Duration(seconds: 8), onTimeout: () => y);
      await store.upsert(_withQuests(closed));
    }

    var todayRecord =
        _find(today) ?? DailyRecord(date: today, stepGoal: stepGoal);
    if (_healthGranted) {
      final base = todayRecord;
      todayRecord = await _withHealth(base, today, now)
          .catchError((_) => base)
          .timeout(const Duration(seconds: 8), onTimeout: () => base);
    }
    await store.upsert(_withQuests(todayRecord.copyWith(openedApp: true)));

    _history = await store.loadHistory();
    await refreshVitals();
    notifyListeners();
  }

  // ───────────────────────────────────────────── 불씨 색 (11-11 묶음 13: 날씨 기능은 뺐다. 기기 시간만)

  /// 불씨 빛 색 (낮 황금, 밤 보라)
  BulssiMood get bulssiMood => BulssiMoods.of(now: _clock());

  // ───────────────────────────────────────────── 설정

  /// 이름 바꾸기 가격 (11-11 #53): 처음 1번 무료, 그다음 금화 300
  static const int renameGold = 300;
  int get renameCost => _profile.renames == 0 ? 0 : renameGold;

  /// 이미 쓰는 이름인지 (11-11 #72): 마을 사람·정령·펫 이름과 겹치면 안 된다.
  /// (다른 모험가와의 중복 확인은 서버가 생기면 #49에서 더한다)
  bool nameTaken(String name) {
    final n = name.trim();
    if (n.isEmpty) return false;
    return {
      MailRules.hart,
      MailRules.mina,
      MailRules.dorgun,
      MailRules.eliel,
      _profile.spiritName,
      for (final p in _pets.pets) p.name,
    }.contains(n);
  }

  /// 내 이름을 바꾼다. 빈 이름·같은 이름이면 그대로, 금화가 모자라면 false.
  Future<bool> renameHero(String name) async {
    final n = name.trim();
    if (n.isEmpty || n == _profile.name || nameTaken(n)) return false;
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
    _ageBlocked = false;
    notifyListeners();
  }

  Future<void> updateProfile(PlayerProfile profile) async {
    _profile = profile;
    await store.saveProfile(profile);
    notifyListeners();
  }

  // ───────────────────────────────────────────── 탐험

  /// 위치 권한을 물어봤는지 (묶음 18 #148)
  bool _locationAsked = false;

  /// 위치를 받았는지
  bool get hasLocation => _lastFix != null;

  /// 위치를 쓸 수 없는 상태 (권한 거부 등). 위치 기능이 없는 기기(시험)는 false
  bool get locationDenied =>
      location != null && _locationAsked && !_locationGranted;

  /// 「다시 시도」: 위치 권한을 다시 묻고 위치를 받는다
  Future<void> retryLocation() async {
    try {
      await _startExploring().timeout(const Duration(seconds: 10));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _startExploring() async {
    final source = location;
    if (source == null) return;
    _locationGranted = await source.requestPermission();
    _locationAsked = true;
    if (!_locationGranted) return;
    await _locationSub?.cancel();
    _locationSub = source.fixes().listen(handleFix);
  }

  /// 위치가 바뀔 때: 가까운 장소를 방문으로 기록한다 (안개는 11-10에 없앴다)
  Future<void> handleFix(LocationFix fix) async {
    _lastFix = fix;
    await _watchSpeed(fix);
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
          level: p.level.level, atGate: atGate, rng: _random, day: _clock()),
      rng: _random,
      startHp: hp,
      skillChargeTicks: _skillTicks(p),
      gear: gear,
      petSkill: companionPet?.info.skill,
      petAdult: companionPet?.adult ?? false,
      potions: battlePotions,
      autoHp: _alc.autoHp,
      autoCure: _alc.autoCure,
      resist: activeResists,
      skillElement: companionPet?.element,
      mainElement: mainElement,
      weaponPotion: weaponPotionElement,
      telegraphs: true,
      heroSkills: true,
    );
  }

  int _skillTicks(PlayerState p) {
    final ex = expedition;
    if (ex != null && !ex.finished) {
      return Battle.skillUnavailable; // 동료가 원정을 가 있다
    }
    return TownRules.potionActive(p.today)
        ? RuleConstants.potionSkillChargeTicks
        : RuleConstants.skillChargeTicks;
  }

  /// 전투가 끝났거나 중간에 나왔을 때 남은 HP를 저장한다
  Future<void> keepBattleHp(Battle battle) async {
    await _consumeBattlePotions(battle);
    _vitals = _vitals.copyWith(hp: battle.playerHp, lastMaxHp: maxHp);
    await store.saveVitals(_vitals);
    notifyListeners();
  }

  /// 던전이 끝났을 때 결과를 기록한다. 받은 경험치를 돌려준다.
  Future<int> finishDungeon(Battle battle, {required bool atGate}) async {
    if (!battle.isOver) return 0;
    await keepBattleHp(battle);
    await _wear(EquipmentRules.dungeonWear);
    await _spendBattleBuffs();
    final today = await _todayRecord();
    final run = DungeonRun(
        cleared: battle.phase == BattlePhase.cleared, atGate: atGate);
    var exp = today.dungeonRuns.length < RuleConstants.maxDungeonRunsPerDay
        ? ExpRules.dungeonRunExp(run)
        : 0;
    var mana = run.cleared
        ? RuleConstants.crystalsPerDungeonClear
        : RuleConstants.crystalsPerDungeonFail;
    // 지친 상태 (11-11 #75): 경험치·마석 -20% (숨김)
    final tiredExp = tired ? exp - _tiredCut(exp) : 0;
    final tiredMana = tired ? mana - _tiredCut(mana) : 0;
    exp -= tiredExp;
    mana -= tiredMana;
    if (run.cleared && _pets.farewellDone) {
      await _maybeEgg(PetRules.dungeonEggChance, 'dungeon');
    }
    if (run.cleared) await _maybeNote(AlchemyRules.noteFromDungeon);
    final loot = LootRules.dungeon(
        cleared: run.cleared, rng: _random, boss: battle.floors.last.monster);
    // 던전 전용 재료 (11-11 #59)
    GatherRules.dungeon(run.cleared, _random)
        .forEach((k, v) => loot[k] = (loot[k] ?? 0) + v);
    final fit = _fitBag(loot);
    final mats = fit.kept;
    await _save(today.copyWith(
      dungeonRuns: [...today.dungeonRuns, run],
      purifiedMonsterIds: _addMonsters(today, battle.purified),
      huntCounts: _addCounts(today, battle.purified),
      gains: DailyRecord.addCounts(today.gains,
          HuntReward.ledger(materials: mats, gold: fit.gold)),
      counters: DailyRecord.addCounts(today.counters, {
        if (FieldMonsterRules.isNight(_clock()))
          'nightHunts': battle.purified.length,
        ..._elementCounters(battle.purified),
        if (tiredExp > 0) TownRules.tiredExpKey: tiredExp,
        if (tiredMana > 0) TownRules.tiredManaKey: tiredMana,
      }),
    ));
    if (!run.cleared) await _defeated();
    if (companionPet != null && battle.purified.isNotEmpty) {
      await _givePetExp(
          companionPet!.uid, PetRules.expPerHunt * battle.purified.length);
    }
    _lastReward = HuntReward(
      exp: exp,
      manaStones: mana,
      gold: fit.gold,
      materials: mats,
    );
    return exp;
  }

  HuntReward _lastReward = const HuntReward();

  /// 방금 끝난 사냥·던전의 보상 (결과 화면에 보여 준다)
  HuntReward get lastReward => _lastReward;

  /// 오늘 아직 사냥하지 않은 필드 몬스터 (11-11 #69: 5마리 뒤에도 계속 나온다)
  List<FieldSpawn> get todaySpawns {
    final today = player.today;
    final done = {...?today?.purifiedSpawnIds, ...?today?.fledSpawnIds};
    for (final away in activeExpeditions) {
      done.add(away.spawnId);
    }
    // 묶음 18 #150: 튜토리얼 중에는 튜토리얼 몬스터만
    if (inTutorial) {
      return _tutorialSpawns(
              _lastFix?.point ?? fallbackCenter ?? area.bounds.center)
          .where((s) => !done.contains(s.id))
          .toList();
    }
    final center = _lastFix?.point ?? fallbackCenter;
    if (center == null) return const [];
    return FieldMonsterRules.spawnsFor(area, _clock(),
            center: center,
            roads: roads,
            exclusions: exclusions,
            level: player.level.level,
            luckBonus: StatRules.modifierBonus(combatStats),
            favored: ElementRules.challengers(mainElement),
            land: lands?.kindAt)
        .followedBy(calledSpawns) // 부르는 물약 (11-11 #57)
        .followedBy(_tutorialSpawns(center))
        .where((s) => !done.contains(s.id))
        .toList();
  }

  // ───────────── 튜토리얼 (묶음 15 #104, Lv.1~2)

  static const _tutorialKey = 'tutorial';

  /// 방금 각성했는지 (연출은 이때만 보여 준다)
  bool _justAwakened = false;
  int _tutorial = 0;

  /// 지금 튜토리얼 단계 (끝났거나 기존 사용자면 [TutorialStep.done])
  TutorialStep get tutorialStep => TutorialStep.values[
      _tutorial.clamp(0, TutorialStep.values.length - 1)];

  bool get inTutorial => tutorialStep != TutorialStep.done;

  Future<void> _setTutorial(TutorialStep step) async {
    _tutorial = step.index;
    await store.saveJson(_tutorialKey, {'step': _tutorial});
    notifyListeners();
  }

  /// 튜토리얼 건너뛰기 (진행·물건은 그대로)
  Future<void> skipTutorial() => _setTutorial(TutorialStep.done);

  /// 가방을 열어 받은 것을 봤을 때
  Future<void> tutorialBagSeen() async {
    if (tutorialStep == TutorialStep.bag) {
      await _setTutorial(TutorialStep.expedition);
    }
  }

  static const tutorialHuntId = 'tutorial-1';
  static const tutorialExpeditionId = 'tutorial-2';
  static bool isTutorialSpawn(String id) => id.startsWith('tutorial-');

  /// 튜토리얼 몬스터: 첫째는 바로 옆(걸어갈 필요 없음), 둘째는 조금 떨어진 곳(정령 원정)
  /// 묶음 18 #148: 첫째는 내 위치 바로 위쪽(약 30m), 둘째는 걸어가기엔 조금 먼
  /// 위쪽(약 250m). 둘 다 화면 위쪽 절반에 오도록 북쪽에 둔다. #149 하늘 슬라임
  List<FieldSpawn> _tutorialSpawns(GeoPoint center) => switch (tutorialStep) {
        TutorialStep.hunt || TutorialStep.intro || TutorialStep.bag => [
            if (tutorialStep != TutorialStep.bag)
              FieldSpawn(
                  id: tutorialHuntId,
                  monster: MonsterId.slime,
                  point: GeoPoint(center.lat + 0.00027, center.lng)),
          ],
        TutorialStep.expedition => [
            FieldSpawn(
                id: tutorialExpeditionId,
                monster: MonsterId.slime,
                point: GeoPoint(center.lat + 0.0021, center.lng + 0.0008)),
          ],
        _ => const [],
      };

  /// 연출을 보고 「어? 바로 옆에 뭔가 있어!」를 눌렀을 때 (#140)
  Future<void> finishIntro() async {
    if (tutorialStep != TutorialStep.intro) return;
    await _setTutorial(TutorialStep.hunt);
    final s = tutorialSpawn;
    if (s != null) requestMapFocus(s.point);
  }

  // ───────────────────────────── 레벨에 따라 여는 기능 (묶음 16 #141~#144)
  static const _gatesKey = 'gates';

  /// 이번 묶음 전부터 하던 사람: 열린 기능은 그대로 (잠그지 않음)
  bool _legacyGates = true;
  Set<String> _introsSeen = {};
  bool _hpTipShown = true;

  static const featureLevel = {
    Feature.smithy: 3,
    Feature.board: 4,
    Feature.harvest: 5,
    Feature.lens: 6,
  };

  bool featureOpen(Feature f) =>
      _legacyGates || player.level.level >= featureLevel[f]!;

  /// 초반 재료만 떨어뜨리는지 (새로 시작한 사람 Lv.5까지, #129)
  bool get earlyLoot => !_legacyGates && player.level.level <= 5;

  /// 게시판 전체(주간·긴급)는 Lv.5부터 (새로 시작한 사람만)
  bool get boardFull => _legacyGates || player.level.level >= 5;

  /// 막 열린 기능의 안내 (레벨업 창 등을 닫은 뒤 한 번)
  Feature? get pendingFeatureIntro {
    if (_legacyGates || inTutorial || pendingLevelUp != null) return null;
    for (final f in Feature.values) {
      if (featureOpen(f) && !_introsSeen.contains(f.name)) return f;
    }
    return null;
  }

  /// 채집 안내 중이면 바로 옆에 꽃 자리 하나 (#143)
  bool _harvestTutorial = false;

  Future<void> markFeatureIntro(Feature f) async {
    _introsSeen = {..._introsSeen, f.name};
    _harvestTutorial = f == Feature.harvest;
    _spotsKey = null;
    await _saveGates();
    notifyListeners();
  }

  Future<void> _saveGates() => store.saveJson(_gatesKey, {
        'legacy': _legacyGates,
        'seen': _introsSeen.toList(),
        'hpTip': _hpTipShown,
      });

  /// 처음으로 HP가 절반 아래가 됐을 때 한 번 회복 팁 (#141)
  bool takeHpTip() {
    if (_hpTipShown || _legacyGates || maxHp <= 0 || hp * 2 >= maxHp) {
      return false;
    }
    _hpTipShown = true;
    unawaited(_saveGates());
    return true;
  }

  /// 튜토리얼 첫 몬스터 (지금 단계가 아니면 null)
  FieldSpawn? get tutorialSpawn {
    for (final s in todaySpawns) {
      if (isTutorialSpawn(s.id)) return s;
    }
    return null;
  }

  /// 튜토리얼 몬스터를 잡았을 때: 첫째 → 가방 보기, 둘째 → Lv.2 (두 마리째에 딱 오르게)
  Future<void> _tutorialPurified(String spawnId) async {
    if (spawnId == tutorialHuntId && tutorialStep == TutorialStep.hunt) {
      // 묶음 18 #151: 원정에서 바로 돌아오기에 쓸 마석 1개는 꼭 받는다
      if (player.manaStones < 1) await _grant(0, 1, const {});
      await _setTutorial(TutorialStep.bag);
    } else if (spawnId == tutorialExpeditionId) {
      final need = LevelRules.totalExpToReach(2) - _fullExp;
      if (need > 0) {
        final today = await _todayRecord();
        await _save(today.copyWith(
            gains: {...today.gains, 'exp': (today.gains['exp'] ?? 0) + need}));
      }
      await _setTutorial(TutorialStep.done);
    }
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
      petSkill: companionPet?.info.skill,
      petAdult: companionPet?.adult ?? false,
      potions: battlePotions,
      autoHp: _alc.autoHp,
      autoCure: _alc.autoCure,
      resist: activeResists,
      skillElement: companionPet?.element,
      mainElement: mainElement,
      weaponPotion: weaponPotionElement,
      telegraphs: true,
      heroSkills: true,
    );
  }

  /// 필드 전투가 끝났을 때. 잡으면 보상, 황금빛이 도망치면 오늘은 다시 나오지 않는다.
  Future<int> finishFieldBattle(FieldSpawn spawn, Battle battle) async {
    await keepBattleHp(battle);
    if (battle.ticks > 0) {
      await _wear(EquipmentRules.fieldWear);
      await _spendBattleBuffs();
    }
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
      await _defeated();
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
    if (isTutorialSpawn(spawnId)) {
      final got = await _recordFieldPurifyInner(spawnId, monster, point,
          mods: mods, count: count, today: today);
      await _tutorialPurified(spawnId);
      return got;
    }
    return _recordFieldPurifyInner(spawnId, monster, point,
        mods: mods, count: count, today: today);
  }

  Future<int> _recordFieldPurifyInner(
    String spawnId,
    MonsterId monster,
    GeoPoint point, {
    required List<ModifierId> mods,
    required int count,
    required DailyRecord today,
  }) async {
    // 11-11 #69: 하루 5마리 뒤에도 사냥은 되고 경험치·마석만 줄어든다 (숨은 규칙)
    const paid = true;
    final n = today.fieldMonstersPurified;
    final factor = RuleConstants.fieldFactor(n + 1);
    final incense = TownRules.incenseActive(today)
        ? RuleConstants.incenseExpMultiplier
        : 1;
    // 규칙이 하루 기록에서 계산하는 몫 (이 마리 수만큼 늘어나는 것)
    int ruleExp(int c) =>
        (RuleConstants.fieldUnits(c) * RuleConstants.fieldMonsterExp * incense)
            .round();
    final baseExp = ruleExp(n + 1) - ruleExp(n);
    // 수식어·속성 보너스와 마리 수 (11-11: 기록에 남겨 경험치에 더한다)
    var exp = (RuleConstants.fieldMonsterExp *
            incense *
            factor *
            (ModifierRules.expMultiplier(mods) + Monsters.info(monster).expBonus) *
            count)
        .round();
    // 승객 모드 (11-11 #61): 사냥 보상 절반 (원정은 보낼 때 승객이었으면)
    final half = passengerMode || _drive.passengerSpawns.contains(spawnId);
    if (half) exp = exp ~/ 2;
    // 지친 상태 (11-11 #75, 숨김): 경험치 -20%
    final tiredNow = tired;
    final tiredExp = tiredNow ? exp - _tiredCut(exp) : 0;
    exp -= tiredExp;
    // 기본 마석 1개는 규칙(하루 5마리)으로 계산하고, 나머지는 기록에 더한다
    final mats = <MaterialId, int>{};
    var extraMana = 0, gold = 0;
    if (paid) {
      for (var i = 0; i < count; i++) {
        LootRules.field(monster, _random,
                early: earlyLoot,
                rareBonus: StatRules.rareDropBonus(combatStats) +
                    (plentyActive ? LootRules.dropsOf(monster).chance * 0.5 : 0))
            .forEach((k, v) => mats[k] = (mats[k] ?? 0) + v);
        // 풍요의 물약: 재료 +1
        if (plentyActive) {
          final d = LootRules.dropsOf(monster);
          final extra = d.common[_random.nextInt(d.common.length)];
          mats[extra] = (mats[extra] ?? 0) + 1;
        }
      }
      final b = ModifierRules.bonus(monster, mods, _random);
      b.materials.forEach((k, v) => mats[k] = (mats[k] ?? 0) + v);
      extraMana = ((((count - 1) * RuleConstants.crystalsPerFieldMonster) +
                  b.manaStones) *
              factor)
          .floor();
      gold = b.gold;
      if (half) {
        for (final k in [...mats.keys]) {
          final v = mats[k]! ~/ 2;
          v > 0 ? mats[k] = v : mats.remove(k);
        }
        extraMana ~/= 2;
        gold ~/= 2;
      }
      // 가방이 가득하면 남는 재료는 금화로 (11-11 #48)
      final fit = _fitBag(mats);
      mats
        ..clear()
        ..addAll(fit.kept);
      gold += fit.gold;
    }
    final fieldMana = (RuleConstants.fieldUnits(n + 1) *
                RuleConstants.crystalsPerFieldMonster)
            .floor() -
        (RuleConstants.fieldUnits(n) * RuleConstants.crystalsPerFieldMonster)
            .floor() +
        extraMana;
    final tiredMana = tiredNow ? fieldMana - _tiredCut(fieldMana) : 0;
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
        if (exp + tiredExp != baseExp) Wallet.exp: exp + tiredExp - baseExp,
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
        ..._elementCounters(List.filled(count, monster)),
        if (tiredExp > 0) TownRules.tiredExpKey: tiredExp,
        if (tiredMana > 0) TownRules.tiredManaKey: tiredMana,
      }),
    ));
    _lastReward = HuntReward(
      exp: exp,
      manaStones: fieldMana - tiredMana,
      gold: gold,
      materials: mats,
    );
    await _rollFieldEgg(ModifierRules.gradeOf(mods));
    switch (ModifierRules.gradeOf(mods)) {
      case ModGrade.rare:
        await _maybeNote(AlchemyRules.noteFromRare);
      case ModGrade.legend:
        await _maybeNote(AlchemyRules.noteFromLegend);
      default:
        break;
    }
    if (!_resolving && companionPet != null) {
      await _givePetExp(companionPet!.uid, PetRules.expPerHunt * count);
    }
    return exp;
  }

  /// 많이 사냥한 날 가끔 정령(펫)이 넌지시 (6마리째부터 세 번에 한 번, 숫자는 말하지 않는다)
  String? get tiredHuntLine {
    final n = player.today?.fieldMonstersPurified ?? 0;
    if (n <= RuleConstants.maxFieldMonstersPerDay || n % 3 != 0) return null;
    return '오늘은 많이 싸웠어. 좀 쉬어도 돼.';
  }

  /// 원정 결과를 정하는 중 (동행 펫 사냥 경험치를 주지 않는다)
  bool _resolving = false;

  // ───────────────────────────────────────────── 여관 · 잡화상 (앱 안 시설)

  /// 잡화상에서 물건을 산다. 사지 못하면 그 이유를 돌려준다.
  Future<PurchaseCheck> buy(ShopItem item) async {
    final today = await _todayRecord();
    final fix = _lastFix;
    await refreshVitals();
    final check = canBuy(item, hasLocation: fix != null);
    if (check != PurchaseCheck.ok) return check;

    await _save(today.copyWith(
      goldPurchases: [...today.goldPurchases, item.name],
    ));
    return PurchaseCheck.ok;
  }

  /// 살 수 있는지 (가방 칸까지 본다)
  /// 잡화상에 보이는 물건 (묶음 16 #144: 감정 돋보기는 Lv.6에 열린다)
  List<ShopItemInfo> get shopItems => [
        for (final i in TownRules.items)
          if (i.item != ShopItem.raceLens || featureOpen(Feature.lens)) i,
      ];

  PurchaseCheck canBuy(ShopItem item, {bool? hasLocation}) {
    final mat = TownRules.info(item).material;
    final have = mat != null
        ? player.materialCount(mat)
        : TownRules.bagItems.contains(item)
            ? bagCount(item)
            : -1;
    return TownRules.canBuy(_history, item,
        hasLocation: hasLocation ?? _lastFix != null,
        level: player.level.level,
        bagRoom: have < 0 || _roomFor(have));
  }

  /// [have] 개 있는 것에 하나 더 넣을 자리가 있는지
  bool _roomFor(int have) =>
      (have > 0 && have % BagRules.stackMax != 0) || bagFree > 0;

  // ───────────────────────────────────────────── 가방 칸 (11-11 #48)

  static const _bagKey = 'bag';
  BagState _bag = const BagState();

  /// 가방 칸 수
  int get bagCapacity => BagRules.capacity(
      goldExpansions: _bag.goldExpansions,
      extraSlots: _bag.extraSlots,
      singleSlots: _bag.singleSlots);

  /// 쓰고 있는 칸 (예전 저장본은 칸보다 많을 수 있다. 그래도 다 남긴다)
  int get bagUsed => BagRules.usedSlots(
        materials: player.materials,
        items: {
          for (final i in TownRules.bagItems)
            if (bagCount(i) > 0) i: bagCount(i),
        },
        armory: _armory,
        eggs: _pets.eggs.length,
        extraStacks: [..._alc.potions.values, ..._extraBagCounts()],
      );

  /// 빈칸 (넘치면 0)
  int get bagFree => math.max(0, bagCapacity - bagUsed);

  /// 다음 한 칸 가격 (더 늘릴 수 없으면 null). 묶음 15 #106: 한 칸씩, 열수록 오른다
  int? get bagExpandCost => bagCapacity >= BagRules.maxSlots
      ? null
      : BagRules.slotCost(_bag.singleSlots);

  /// 다음 칸을 광고로도 열 수 있는지 (한 칸씩 연 것 중 첫째·둘째 칸)
  bool get bagSlotByAd =>
      bagExpandCost != null && _bag.singleSlots < BagRules.adSlots;

  /// 가방을 한 칸 늘린다. [byAd] 면 광고를 끝까지 본 뒤 (첫째·둘째 칸만)
  Future<bool> expandBag({bool byAd = false}) async {
    final cost = bagExpandCost;
    if (cost == null) return false;
    if (byAd) {
      if (!bagSlotByAd || !await _watchAd('bag_slot')) return false;
    } else {
      if (player.gold < cost) return false;
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {Wallet.gold: cost})));
    }
    _bag = _bag.copyWith(singleSlots: _bag.singleSlots + 1);
    await store.saveJson(_bagKey, _bag.toJson());
    notifyListeners();
    return true;
  }

  // ───────────── 보상형 광고 (묶음 15 #103). 숫자 규칙은 화면에 보이지 않는다

  /// 광고를 끝까지 보면 true. 앱이 채워 넣는다 (테스트·광고 없는 빌드는 null)
  Future<bool> Function(String placement)? watchAd;

  bool get adsReady => watchAd != null;

  Future<bool> _watchAd(String placement) async {
    final w = watchAd;
    if (w == null) return false;
    try {
      return await w(placement);
    } catch (_) {
      return false;
    }
  }

  /// 원정 시간 절반 (남은 시간의 절반). 튜토리얼 원정에는 없다
  bool canHalveExpedition(Expedition ex) =>
      adsReady &&
      !ex.finished &&
      !isTutorialSpawn(ex.spawnId) &&
      !ex.adUsed.contains('half') &&
      ex.returnAt.isAfter(_clock());

  Future<bool> adHalveExpedition(Expedition ex) async {
    if (!canHalveExpedition(ex) || !await _watchAd('expedition_half')) {
      return false;
    }
    final now = _clock();
    final left = ex.returnAt.difference(now);
    final done = ex.shortened(left ~/ 2, now, ad: 'half');
    _vitals = _vitals.copyWith(expeditions: [
      for (final e in _vitals.expeditions)
        e.spawnId == ex.spawnId && e.petUid == ex.petUid ? done : e,
    ]);
    await store.saveVitals(_vitals);
    final who = ex.petName ?? _profile.spiritName;
    unawaited(notifier?.schedule(_notifyIdFor(ex.petUid), done.returnAt,
        '${josa(who, '이/가')} 돌아왔어요', '원정 결과를 확인해 보세요!'));
    await refreshVitals();
    return true;
  }

  // ───────────── 바로 돌아오기 (묶음 18 #151)

  /// 마석 개수: 남은 시간 10분마다 1개(시작한 10분도 1개), 최대 6개. 튜토리얼은 1개
  int rushCost(Expedition ex) {
    if (isTutorialSpawn(ex.spawnId)) return 1;
    final left = ex.returnAt.difference(_clock()).inSeconds;
    return VitalRules.rushCost(left);
  }

  bool canRush(Expedition ex) =>
      !ex.finished && ex.returnAt.isAfter(_clock());

  bool canRushByAd(Expedition ex) =>
      adsReady &&
      canRush(ex) &&
      !isTutorialSpawn(ex.spawnId) &&
      !ex.adUsed.contains('rush');

  /// 마석(또는 광고)으로 지금 바로 돌아오게 한다. 성공하면 true
  Future<bool> rushExpedition(Expedition ex, {bool byAd = false}) async {
    if (!canRush(ex)) return false;
    if (byAd) {
      if (!canRushByAd(ex) || !await _watchAd('expedition_rush')) return false;
    } else {
      final cost = rushCost(ex);
      if (player.manaStones < cost) return false;
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(
              today.spends, {Wallet.manaStone: cost})));
    }
    final now = _clock();
    final done = ex.shortened(ex.returnAt.difference(now), now,
        ad: byAd ? 'rush' : null);
    _vitals = _vitals.copyWith(expeditions: [
      for (final e in _vitals.expeditions)
        e.spawnId == ex.spawnId && e.petUid == ex.petUid ? done : e,
    ]);
    await store.saveVitals(_vitals);
    unawaited(notifier?.cancel(_notifyIdFor(ex.petUid)));
    await refreshVitals();
    notifyListeners();
    return true;
  }

  /// 원정 보상 두 배 (기본 보상만, 펫이 더 가져온 것은 빼고)
  bool canDoubleExpedition(Expedition ex) =>
      adsReady &&
      ex.cleared == true &&
      !isTutorialSpawn(ex.spawnId) &&
      ex.baseReward.isNotEmpty &&
      !ex.adUsed.contains('double');

  Future<bool> adDoubleExpedition(Expedition ex) async {
    if (!canDoubleExpedition(ex) || !await _watchAd('expedition_double')) {
      return false;
    }
    final b = ex.baseReward;
    final mats = <MaterialId, int>{
      for (final e in b.entries)
        if (Materials.byName(e.key) case final m?) m: e.value,
    };
    await _grant(b[Wallet.gold] ?? 0, b[Wallet.manaStone] ?? 0, mats);
    final exp = b['exp'] ?? 0;
    if (exp > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          gains: {...today.gains, 'exp': (today.gains['exp'] ?? 0) + exp}));
    }
    _markAd(ex, 'double');
    await store.saveVitals(_vitals);
    notifyListeners();
    return true;
  }

  void _markAd(Expedition ex, String ad) {
    _vitals = _vitals.copyWith(expeditions: [
      for (final e in _vitals.expeditions)
        e.spawnId == ex.spawnId && e.petUid == ex.petUid
            ? e.copy(adUsed: {...e.adUsed, ad})
            : e,
    ]);
  }

  /// 여관 휴식 시간 줄이기: 광고 한 번에 1시간 (줄어든 만큼 HP·MP가 바로 더 찬다)
  bool get canShortenRest => adsReady && resting && restLeft > Duration.zero;

  Future<bool> adShortenRest() async {
    if (!canShortenRest || !await _watchAd('rest_shorten')) return false;
    final at = _vitals.restStartedAt;
    if (at == null) return false;
    _vitals = _vitals.copyWith(
        restStartedAt: at.subtract(const Duration(hours: 1)));
    await store.saveVitals(_vitals);
    unawaited(notifier?.schedule(
      NotifyId.rest,
      _vitals.restStartedAt!.add(const Duration(hours: RuleConstants.restHours)),
      '푹 쉬었어요',
      'HP와 $companionName의 MP가 가득 찼어요. 앱을 열어 휴식 보너스를 받으세요!',
    ));
    await refreshVitals();
    return true;
  }

  int _bagOverflow = 0;

  /// 가방이 가득 차 금화로 바꾼 값 (알림을 띄우고 0으로)
  int takeBagOverflow() {
    final g = _bagOverflow;
    _bagOverflow = 0;
    return g;
  }

  int get pendingBagOverflow => _bagOverflow;

  ({Map<MaterialId, int> kept, int gold}) _fitBag(
      Map<MaterialId, int> incoming) {
    if (incoming.isEmpty) return (kept: incoming, gold: 0);
    final fit = BagRules.fit(
        incoming: incoming, have: player.materials, freeSlots: bagFree);
    _bagOverflow += fit.gold;
    return fit;
  }

  /// 재료를 버린다
  Future<bool> discardMaterial(MaterialId m, int n) async {
    if (n <= 0 || player.materialCount(m) < n) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {m.name: n})));
    return true;
  }

  /// 가방 물건을 버린다
  Future<bool> discardItem(ShopItem item, int n) async {
    if (n <= 0 || bagCount(item) < n) return false;
    await _count(TownRules.dropKey(item), n);
    return true;
  }

  /// 입지 않은 장비를 버린다
  Future<bool> discardEquip(String uid) async {
    final item = _armory.byUid(uid);
    if (item == null || _armory.isWorn(item)) return false;
    await _saveArmory(_armory.copyWith(
        items: [for (final i in _armory.items) if (i.uid != uid) i]));
    return true;
  }

  /// 잡화상에서 재료를 판다
  Future<bool> sellMaterial(MaterialId m, int n) async {
    if (n <= 0 || player.materialCount(m) < n) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {m.name: n}),
      gains: DailyRecord.addCounts(
          today.gains, {Wallet.gold: n * BagRules.materialPrice(m)}),
    ));
    return true;
  }

  /// 잡화상에서 가방 물건을 판다 (산 값의 절반)
  Future<bool> sellItem(ShopItem item, int n) async {
    if (n <= 0 || bagCount(item) < n) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      counters: DailyRecord.addCounts(
          today.counters, {TownRules.dropKey(item): n}),
      gains: DailyRecord.addCounts(
          today.gains, {Wallet.gold: n * BagRules.itemPrice(item)}),
    ));
    return true;
  }

  /// 잡화상에서 입지 않은 장비를 판다
  Future<bool> sellEquip(String uid) async {
    final item = _armory.byUid(uid);
    if (item == null || _armory.isWorn(item)) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      gains: DailyRecord.addCounts(
          today.gains, {Wallet.gold: BagRules.equipPrice(item)}),
    ));
    await _saveArmory(_armory.copyWith(
        items: [for (final i in _armory.items) if (i.uid != uid) i]));
    return true;
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

  UseCheck canUse(ShopItem item) {
    // 정령이 떠난 뒤 정령 물약은 펫 간식: 여러 개 줘도 된다
    if (item == ShopItem.bulssiPotion && farewellDone) {
      if (bagCount(item) <= 0) return UseCheck.none;
      return companionPet == null ? UseCheck.none : UseCheck.ok;
    }
    return TownRules.canUse(_history, item,
        hpFull: hp >= maxHp,
        mpFull: mp >= mpMax,
        compassReady: _vitals.compassReady);
  }

  /// 물건 이름 (정령이 떠난 뒤 정령 물약은 「펫 간식」)
  String itemName(ShopItem item) =>
      item == ShopItem.bulssiPotion && farewellDone
          ? '펫 간식'
          : TownRules.info(item).name;

  String itemDescription(ShopItem item) =>
      item == ShopItem.bulssiPotion && farewellDone
          ? '데리고 다니는 펫에게 주면 펫 경험치 +${PetRules.expSnack}, '
              '친밀도 +${PetRules.bondPerSnack}. 준 날은 던전 스킬이 빨리 차요.'
          : TownRules.info(item).description;

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
    if (item == ShopItem.bulssiPotion && companionPet != null) {
      final pet = companionPet!;
      await _savePets(_pets.replace(pet.copyWith(
        exp: pet.exp + PetRules.expSnack,
        bond: math.min(PetRules.maxBond, pet.bond + PetRules.bondPerSnack),
      )));
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
      shownStats + StatRules.evenShare(unspentPoints) + buffStats;

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


  // ───────────────────────────────────────────── 정령 이별 · 펫 (11-11 #37·#38)

  static const _petsKey = 'pets';
  PetState _pets = const PetState();

  PetState get pets => _pets;

  /// 정령이 떠났는지 (Lv.11)
  bool get farewellDone => _pets.farewellDone;

  /// 데리고 다니는 펫 (정령이 떠나기 전에는 null)
  Pet? get companionPet => _pets.farewellDone ? _pets.companionPet : null;

  /// 말풍선·원정에 나오는 동료 이름 (정령 또는 데리고 다니는 펫)
  String get companionName => companionPet?.name ?? _profile.spiritName;

  /// 처음 함께한 정령 이름 (떠난 뒤 프로필·기록에)
  String get firstSpiritName => _pets.firstSpiritName ?? _profile.spiritName;

  Future<void> _savePets(PetState p) async {
    _pets = p;
    await store.saveJson(_petsKey, p.toJson());
    notifyListeners();
  }

  /// 이별 연출을 보여 줄 때인지: Lv.11 이상, 아직 함께, 정령 원정이 없음
  bool get farewellPending =>
      !_pets.farewellDone &&
      player.level.level >= PetRules.farewellLevel &&
      _vitals.expeditions.isEmpty;

  /// 정령 짝 펫 (첫 펫 확률을 조금 올린다)
  PetSpecies get _favoredSpecies => switch (_profile.spiritKind) {
        SpiritKind.fire => PetSpecies.lizard,
        SpiritKind.water => PetSpecies.toad,
        SpiritKind.plant => PetSpecies.owl,
      };

  /// 이별 때 깨어날 펫 (연출에서 한 번 뽑아 이름을 짓게 한다)
  PetSpecies rollFirstPet() => PetRules.rollSpecies(_random,
      favored: _favoredSpecies, element: mainElement);

  /// 이별 때 가방에 알이 있었는지 (없으면 정령이 선물 알을 남긴다)
  bool get hasEggForFarewell => _pets.eggs.isNotEmpty;

  /// 정령이 떠나고 첫 펫이 태어난다. 가방의 알 하나를 쓰고, 없으면 선물 알.
  Future<Pet> completeFarewell(PetSpecies species, String name) async {
    final now = _clock();
    final p = _pets;
    final eggs = [...p.eggs];
    if (eggs.isNotEmpty) eggs.removeAt(0);
    final pet = Pet(
      uid: 'pet${p.nextId}',
      species: species,
      name: name.trim().isEmpty ? PetRules.info(species).name : name.trim(),
      bornAt: now,
    );
    await _savePets(p.copyWith(
      eggs: eggs,
      pets: [...p.pets, pet],
      companion: pet.uid,
      farewellAt: now,
      firstSpiritName: _profile.spiritName,
      firstSpiritKind: _profile.spiritKind.name,
      nextId: p.nextId + 1,
      // 태어난 뒤 걸음부터 센다
      stepsDay: player.today?.dayKey,
      stepsCounted: player.today?.steps ?? 0,
      // 이별 전에 이미 지나간 날의 편지는 보내지 않는다
      skippedLetters: [
        for (final l in PetRules.letters)
          if (_letterDue(l)) l.id,
      ],
    ));
    return pet;
  }

  /// 확률로 알 하나 (Lv.11 전에는 한 번만, 정령이 떠난 뒤에는 [chance])
  Future<bool> _maybeEgg(double chance, String source) async {
    if (_random.nextDouble() >= chance) return false;
    final p = _pets;
    await _savePets(p.copyWith(
      eggs: [...p.eggs, PetEgg(id: 'egg${p.nextId}', source: source, element: mainElement?.name)],
      firstEggFound: true,
      nextId: p.nextId + 1,
    ));
    _newEgg = true;
    return true;
  }

  Future<void> _rollFieldEgg(ModGrade grade) async {
    if (!_pets.farewellDone) {
      if (_pets.firstEggFound || _pets.eggs.isNotEmpty) return;
      await _maybeEgg(PetRules.firstEggChance, 'field');
      return;
    }
    await _maybeEgg(PetRules.fieldEggChance(grade), 'field');
  }

  bool _newEgg = false;

  /// 방금 알을 얻었는지 (한 번 알려 주고 false)
  bool takeNewEgg() {
    final v = _newEgg;
    _newEgg = false;
    return v;
  }

  /// 알을 품는다 (정령이 떠난 뒤에만, 한 번에 하나)
  Future<bool> incubateEgg(String eggId) async {
    if (!_pets.farewellDone) return false;
    if (_pets.eggs.any((e) => e.incubatedAt != null)) return false;
    final now = _clock();
    await _savePets(_pets.copyWith(eggs: [
      for (final e in _pets.eggs) e.id == eggId ? e.incubate(now) : e,
    ]));
    unawaited(notifier?.schedule(NotifyId.hatch, now.add(PetRules.hatchTime),
        '알이 깨어나려 해요', '가방에서 알을 확인하고 이름을 지어 주세요!'));
    return true;
  }

  /// 품은 알이 다 되었는지
  bool eggReady(PetEgg e) =>
      e.incubatedAt != null &&
      !_clock().isBefore(e.incubatedAt!.add(PetRules.hatchTime));

  PetEgg? get readyEgg {
    for (final e in _pets.eggs) {
      if (eggReady(e)) return e;
    }
    return null;
  }

  int hatchManaCost(PetEgg e) => e.incubatedAt == null
      ? 0
      : PetRules.hatchManaCost(e.incubatedAt!, _clock());
  int hatchGoldCost(PetEgg e) => e.incubatedAt == null
      ? 0
      : PetRules.hatchGoldCost(e.incubatedAt!, _clock());

  /// 마석이나 금화로 바로 깨운다
  Future<bool> hatchNow(String eggId, {required bool useMana}) async {
    PetEgg? egg;
    for (final e in _pets.eggs) {
      if (e.id == eggId) egg = e;
    }
    if (egg == null || egg.incubatedAt == null) return false;
    final cost = useMana ? hatchManaCost(egg) : hatchGoldCost(egg);
    if (useMana ? player.manaStones < cost : player.gold < cost) return false;
    if (cost > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends,
              {useMana ? Wallet.manaStone : Wallet.gold: cost})));
    }
    final done = _clock().subtract(PetRules.hatchTime);
    await _savePets(_pets.copyWith(eggs: [
      for (final e in _pets.eggs) e.id == eggId ? e.incubate(done) : e,
    ]));
    unawaited(notifier?.cancel(NotifyId.hatch));
    return true;
  }

  /// 다 된 알에서 펫이 태어난다. 펫이 6마리면 null.
  Future<Pet?> hatch(String eggId, String name, {PetSpecies? species}) async {
    final p = _pets;
    if (p.pets.length >= PetRules.maxPets) return null;
    PetEgg? egg;
    for (final e in p.eggs) {
      if (e.id == eggId) egg = e;
    }
    if (egg == null || !eggReady(egg)) return null;
    final s = species ??
        PetRules.rollSpecies(_random, element: ElementRules.parse(egg.element));
    final pet = Pet(
      uid: 'pet${p.nextId}',
      species: s,
      name: name.trim().isEmpty ? PetRules.info(s).name : name.trim(),
      bornAt: _clock(),
    );
    await _savePets(p.copyWith(
      eggs: [for (final e in p.eggs) if (e.id != eggId) e],
      pets: [...p.pets, pet],
      nextId: p.nextId + 1,
    ));
    return pet;
  }

  /// 펫 경험치·친밀도를 더한다
  Future<void> _givePetExp(String uid, int exp, {int bond = 0}) async {
    final pet = _pets.byUid(uid);
    if (pet == null) return;
    await _savePets(_pets.replace(pet.copyWith(
      exp: pet.exp + exp,
      bond: math.min(PetRules.maxBond, pet.bond + bond),
    )));
  }

  /// 동행 펫이 함께 걸은 걸음 (100보마다 경험치 1)
  Future<void> _petSteps() async {
    final pet = companionPet;
    final today = player.today;
    if (pet == null || today == null) return;
    final day = today.dayKey;
    final counted = _pets.stepsDay == day ? _pets.stepsCounted : 0;
    // 승객 모드 (11-11 #61): 차 안의 걸음은 펫 경험치에 세지 않는다
    if (passengerMode) {
      await _savePets(_pets.copyWith(
          stepsDay: day, stepsCounted: math.max(counted, today.steps)));
      return;
    }
    final gained = (today.steps - counted) ~/ 100;
    if (gained <= 0) {
      if (_pets.stepsDay != day) {
        await _savePets(_pets.copyWith(stepsDay: day, stepsCounted: 0));
      }
      return;
    }
    await _savePets(_pets
        .replace(pet.copyWith(exp: pet.exp + gained * PetRules.expPer100Steps))
        .copyWith(stepsDay: day, stepsCounted: counted + gained * 100));
  }

  /// 주간 의뢰를 모두 끝낸 주 2번마다 알 하나 (정령이 떠난 뒤)
  Future<void> _checkBoardEggs() async {
    final at = _pets.farewellAt;
    if (at == null || _history.isEmpty) return;
    final perWeek = BoardRules.weekly(const []).length;
    final done = <String, int>{};
    for (var i = 0; i < _history.length; i++) {
      final r = _history[i];
      if (r.date.isBefore(DateTime(at.year, at.month, at.day))) continue;
      final n = BoardRules.weeklyCompletedOn(_history, i);
      if (n <= 0) continue;
      final w = TownRules.weekStart(r.date).toIso8601String().substring(0, 10);
      done[w] = (done[w] ?? 0) + n;
    }
    final fullWeeks = [
      for (final e in done.entries)
        if (e.value >= perWeek) e.key,
    ]..sort();
    final due = fullWeeks.length ~/ PetRules.boardEggEveryWeeks;
    final given = _pets.boardEggWeeks.length;
    if (due <= given) return;
    var p = _pets;
    for (var k = given; k < due; k++) {
      p = p.copyWith(
        eggs: [...p.eggs, PetEgg(id: 'egg${p.nextId}', source: 'board', element: mainElement?.name)],
        nextId: p.nextId + 1,
        boardEggWeeks: [...p.boardEggWeeks, fullWeeks[(k + 1) * 2 - 1]],
      );
    }
    await _savePets(p);
    _newEgg = true;
  }

  /// 데리고 다닐 펫을 고른다
  Future<void> setCompanion(String uid) async {
    if (_pets.byUid(uid) == null) return;
    await _savePets(_pets.copyWith(companion: uid));
  }

  /// 펫 이름을 바꾼다 (무료)
  Future<void> renamePet(String uid, String name) async {
    final pet = _pets.byUid(uid);
    if (pet == null || name.trim().isEmpty) return;
    await _savePets(_pets.replace(pet.copyWith(name: name.trim())));
  }

  /// 재료를 먹이로 준다 (일반 +3, 귀한 +15, 친밀도 +1)
  Future<bool> feedMaterial(String uid, MaterialId m) async {
    final pet = _pets.byUid(uid);
    if (pet == null || player.materialCount(m) <= 0) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {m.name: 1})));
    final base =
        Materials.info(m).rare ? PetRules.expRareFood : PetRules.expCommonFood;
    // 같은 속성 재료는 경험치 1.5배 (11-11 #63)
    final same = pet.element != null && Materials.elementOf(m) == pet.element;
    await _givePetExp(
        uid, same ? (base * PetRules.sameElementFood).round() : base,
        bond: PetRules.bondPerFood);
    return true;
  }

  /// 펫 간식을 준다 (동행 펫이 아니어도)
  Future<bool> feedSnack(String uid) async {
    final pet = _pets.byUid(uid);
    if (pet == null || bagCount(ShopItem.bulssiPotion) <= 0) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        itemsUsed: [...today.itemsUsed, ShopItem.bulssiPotion.name]));
    await _givePetExp(uid, PetRules.expSnack, bond: PetRules.bondPerSnack);
    return true;
  }

  /// 자연으로 돌려보낸다: 마석 (5 + 레벨 × 2) + 좋아하던 재료 3개.
  /// 마지막 한 마리와 원정 중인 펫은 돌려보낼 수 없다.
  Future<bool> releasePet(String uid) async {
    final pet = _pets.byUid(uid);
    if (pet == null || _pets.pets.length <= 1 || isAway(uid)) return false;
    await _grant(0, PetRules.releaseMana(pet.level),
        {pet.info.favorite: PetRules.releaseMaterials});
    final rest = [for (final p in _pets.pets) if (p.uid != uid) p];
    await _savePets(PetState.fromJson({
      ..._pets.toJson(),
      'pets': [for (final p in rest) p.toJson()],
      'companion': _pets.companion == uid ? rest.first.uid : _pets.companion,
    }));
    return true;
  }

  // ───────────── 정령 편지

  /// 각성한 날부터 며칠째인지 (첫날 = 1)
  int get awakenedDays {
    if (_history.isEmpty) return 0;
    final first = _history.first.date;
    final now = _clock();
    return DateTime(now.year, now.month, now.day)
            .difference(DateTime(first.year, first.month, first.day))
            .inDays +
        1;
  }

  bool _letterDue(LetterInfo l) =>
      (l.level != null && player.level.level >= l.level!) ||
      (l.days != null && awakenedDays >= l.days!);

  LetterInfo? _newLetter;

  /// 새로 온 편지 (한 번 알려 주고 null)
  LetterInfo? takeNewLetter() {
    final l = _newLetter;
    _newLetter = null;
    return l;
  }

  LetterInfo? get pendingLetter => _newLetter;

  /// 받은 편지 (받은 순서)
  List<LetterInfo> get receivedLetters => [
        for (final id in _pets.letters)
          for (final l in PetRules.letters)
            if (l.id == id) l,
      ];

  Future<void> _checkLetters() async {
    if (!_pets.farewellDone) return;
    for (final l in PetRules.letters) {
      if (_pets.letters.contains(l.id) || _pets.skippedLetters.contains(l.id)) {
        continue;
      }
      if (!_letterDue(l)) continue;
      // 11-11 #65: 편지와 선물은 우편함으로 (편지 탭에 계속 남는다)
      await _sendMail(MailItem(
        id: 'spirit_${l.id}',
        kind: MailKind.letter,
        from: firstSpiritName,
        title: l.title,
        body: l.body,
        gifts: {
          if (l.gold > 0) Wallet.gold: l.gold,
          if (l.manaStones > 0) Wallet.manaStone: l.manaStones,
          if (l.snacks > 0) 'item:${ShopItem.bulssiPotion.name}': l.snacks,
          if (l.compasses > 0) 'item:${ShopItem.expeditionCompass.name}': l.compasses,
          if (l.recipeNotes > 0) 'note': l.recipeNotes,
          if (l.eggs > 0) 'egg': l.eggs,
        },
        sentAt: _clock(),
      ));
      await _savePets(_pets.copyWith(letters: [..._pets.letters, l.id]));
      _newLetter = l;
    }
  }


  // ───────────────────────────────────────────── 연금술 공방 (11-11 #57·#58)

  static const _alchemyKey = 'alchemy';
  AlchemyState _alc = const AlchemyState();

  AlchemyState get alchemy => _alc;

  Future<void> _saveAlc(AlchemyState a) async {
    _alc = a;
    await store.saveJson(_alchemyKey, a.toJson());
    notifyListeners();
  }

  /// 가방 칸을 쓰는 그 밖의 것 (나중에 더할 자리)
  List<int> _extraBagCounts() => [_gather.pouches];

  /// 읽지 않은 레시피 쪽지
  int get recipeNotes => _pets.recipeNotes;

  Future<void> _maybeNote(double chance) async {
    if (_random.nextDouble() >= chance) return;
    await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
  }

  /// 레시피 책에 보이는 물약 (처음부터 공개 + 발견 + 쪽지)
  List<PotionId> get knownRecipes => [
        for (final p in AlchemyRules.all)
          if (p.public ||
              _alc.discovered.contains(p.id.name) ||
              _alc.noted.contains(p.id.name))
            p.id,
      ];

  /// 재료·개수를 아는지 (쪽지로만 알면 아직 만들어 보지 않은 것)
  bool recipeDiscovered(PotionId id) =>
      AlchemyRules.info(id).public || _alc.discovered.contains(id.name);

  /// 쪽지를 읽는다: 아직 모르는 물약 하나의 재료·개수 (순서는 빼고)
  Future<PotionId?> readNote() async {
    if (_pets.recipeNotes <= 0) return null;
    final unknown = [
      for (final p in AlchemyRules.all)
        if (!p.public &&
            !_alc.discovered.contains(p.id.name) &&
            !_alc.noted.contains(p.id.name))
          p.id,
    ];
    if (unknown.isEmpty) return null;
    final id = unknown[_random.nextInt(unknown.length)];
    await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes - 1));
    await _saveAlc(_alc.copyWith(noted: [..._alc.noted, id.name]));
    return id;
  }

  /// 다음 가마솥 값 (더 살 수 없으면 null)
  int? get cauldronGold => AlchemyRules.cauldronGold(_alc.cauldrons);
  int get cauldronStone => AlchemyRules.cauldronStone(_alc.cauldrons);

  Future<bool> buyCauldron() async {
    final gold = cauldronGold;
    final stone = cauldronStone;
    if (gold == null || player.gold < gold) return false;
    if (player.materialCount(MaterialId.labyrinthStone) < stone) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
      Wallet.gold: gold,
      if (stone > 0) MaterialId.labyrinthStone.name: stone,
    })));
    await _saveAlc(_alc.copyWith(cauldrons: _alc.cauldrons + 1));
    return true;
  }

  /// 가마솥 [slot] 에 재료를 넣고 끓인다 (넣은 순서가 중요)
  Future<bool> startBrew(int slot, List<MaterialId> put) async {
    if (slot < 0 || slot >= _alc.cauldrons || _alc.brews.containsKey(slot)) {
      return false;
    }
    if (put.isEmpty || put.length > AlchemyRules.maxIngredients) return false;
    final need = <MaterialId, int>{};
    for (final m in put) {
      need[m] = (need[m] ?? 0) + 1;
    }
    for (final e in need.entries) {
      if (player.materialCount(e.key) < e.value) return false;
    }
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(
            today.spends, {for (final e in need.entries) e.key.name: e.value})));
    final match = AlchemyRules.match(put);
    final minutes = match == null
        ? AlchemyRules.suspiciousMinutes
        : AlchemyRules.info(match.id).minutes;
    final now = _clock();
    final ready = now.add(Duration(minutes: minutes));
    await _saveAlc(_alc.copyWith(brews: {
      ..._alc.brews,
      slot: Brew(put: [for (final m in put) m.name], startedAt: now, readyAt: ready),
    }));
    unawaited(notifier?.schedule(
        200 + slot, ready, '물약이 다 끓었어요', '연금술 공방에서 가마솥을 확인해 보세요!'));
    return true;
  }

  bool brewReady(int slot) {
    final b = _alc.brews[slot];
    return b != null && !_clock().isBefore(b.readyAt);
  }

  /// 다 끓은 물약을 꺼낸다
  Future<BrewResult?> collectBrew(int slot) async {
    final b = _alc.brews[slot];
    if (b == null || !brewReady(slot)) return null;
    final put = [
      for (final n in b.put)
        if (Materials.byName(n) case final m?) m,
    ];
    final brews = {..._alc.brews}..remove(slot);
    var a = _alc.copyWith(brews: brews);
    final match = AlchemyRules.match(put);
    BrewResult result;
    if (match == null) {
      final key = '?:${AlchemyRules.comboKey(put)}';
      a = a.add(key, 1);
      result = BrewResult(suspicious: key, count: 1);
    } else {
      final info = AlchemyRules.info(match.id);
      final isNew = !recipeDiscovered(match.id);
      // 품질 3등급 (11-11 #74): 숙련도 보너스는 연금술사 직업 각성 뒤에 더한다
      final q = AlchemyRules.quality(perfect: match.perfect, put: put);
      a = a.copyWith(
          mastery: a.mastery +
              AlchemistRules.brewPoints +
              (q == PotionQuality.best ? AlchemistRules.bestBonusPoints : 0));
      if (info.shopItem != null && q == PotionQuality.normal) {
        // 잡화상과 같은 물약은 같은 물건으로 가방에
        final today = await _todayRecord();
        await _save(today.copyWith(
            counters: DailyRecord.addCounts(today.counters,
                {TownRules.giftKey(info.shopItem!): info.yields})));
      } else {
        a = a.add(AlchemyRules.keyOf(match.id, q), info.yields);
      }
      if (isNew) a = a.copyWith(discovered: [...a.discovered, match.id.name]);
      result = BrewResult(
          potion: match.id,
          perfect: match.perfect,
          quality: q,
          count: info.yields,
          discovered: isNew);
    }
    await _saveAlc(a);
    return result;
  }

  // ───────────── 물약 이름·효과

  /// 공방 물약 키 → 이름
  String potionName(String key) {
    if (key.startsWith('?:')) return '수상한 물약';
    final k = AlchemyRules.parseKey(key);
    if (k == null) return key;
    // 품질 (11-11 #74): 좋음·최상만 이름에 붙인다
    return '${AlchemyRules.info(k.id).name}'
        '${k.quality == PotionQuality.normal ? '' : ' (${k.quality.label})'}';
  }

  String potionDescription(String key) {
    if (key.startsWith('?:')) {
      if (!_alc.knownSuspicious.contains(key)) return '마시기 전에는 무슨 효과인지 몰라요.';
      final e = AlchemyRules.suspiciousEffect(_putOf(key));
      return e.stat == null
          ? '마시면 HP가 ${e.amount}% 차요. (수상한 물약)'
          : '10분 동안 ${e.stat!.label} +${e.amount}. (수상한 물약)';
    }
    final k = AlchemyRules.parseKey(key);
    if (k == null) return '';
    return '${AlchemyRules.info(k.id).description} 품질: ${k.quality.label}'
        '${k.quality == PotionQuality.normal ? '' : ' (효과가 더 크고 오래가요)'}';
  }

  List<MaterialId> _putOf(String key) => [
        for (final n in key.substring(2).split('+'))
          if (Materials.byName(n) case final m?) m,
      ];

  /// 원정 MP가 [need] 만큼 모자랄 때 마실 수 있는 마나 물약 (11-11 #64).
  /// 한 병으로 채우는 가장 작은 물약이 먼저, 한 병으로 안 되면 적은 병 수부터.
  List<ManaOption> manaOptions(int need) {
    if (need <= 0) return const [];
    final out = <ManaOption>[];
    for (final item in const [ShopItem.manaSmall, ShopItem.mana]) {
      final n = bagCount(item);
      if (n <= 0) continue;
      final per = math.max(1, (mpMax * TownRules.info(item).mpRatio).round());
      out.add(ManaOption(
          name: itemName(item), count: n, perBottle: per,
          bottles: (need / per).ceil(), item: item));
    }
    for (final e in _alc.potions.entries) {
      final info = _infoOf(e.key);
      if (info == null || info.kind != PotionKind.mana || e.value <= 0) continue;
      final m = _qualityMult(e.key);
      final per = math.max(1, (mpMax * info.mpRatio * m).round());
      out.add(ManaOption(
          name: potionName(e.key), count: e.value, perBottle: per,
          bottles: (need / per).ceil(), key: e.key));
    }
    out.sort((a, b) {
      final c = a.bottles.compareTo(b.bottles);
      return c != 0 ? c : a.perBottle.compareTo(b.perBottle);
    });
    return out;
  }

  /// [o] 를 한 병 마신다
  Future<bool> drinkMana(ManaOption o) async {
    if (o.item != null) return await useItem(o.item!) == UseCheck.ok;
    return await drinkPotion(o.key!) == null;
  }

  PotionInfo? _infoOf(String key) {
    final k = AlchemyRules.parseKey(key);
    return k == null ? null : AlchemyRules.info(k.id);
  }

  /// 품질 배율 (보통 1, 좋음 1.25, 최상 1.5)
  double _qualityMult(String key) =>
      AlchemyRules.parseKey(key)?.quality.mult ?? 1.0;

  /// 전투에 가져가는 회복·상태이상 물약 (잡화상 물약 + 공방 물약)
  List<BattlePotion> get battlePotions {
    final out = <BattlePotion>[];
    for (final item in [ShopItem.healSmall, ShopItem.heal]) {
      final n = bagCount(item);
      if (n > 0) {
        out.add(BattlePotion(
            key: 'shop:${item.name}',
            name: TownRules.info(item).name,
            count: n,
            hpRatio: TownRules.info(item).hpRatio));
      }
    }
    for (final e in _alc.potions.entries) {
      final info = _infoOf(e.key);
      if (info == null) continue;
      final m = _qualityMult(e.key);
      final cure = switch (info.id) {
        PotionId.antidote => CureKind.poison,
        PotionId.burnSalve => CureKind.burn,
        PotionId.clearEye => CureKind.dazzle,
        PotionId.thaw => CureKind.freeze,
        _ => null,
      };
      if (cure == null && info.hpRatio <= 0) continue;
      out.add(BattlePotion(
          key: 'alc:${e.key}',
          name: potionName(e.key),
          count: e.value,
          hpRatio: info.hpRatio * m,
          cure: cure));
    }
    return out;
  }

  final _consumed = Expando<bool>();

  /// 전투에서 마신 물약을 가방에서 뺀다 (한 번만)
  Future<void> _consumeBattlePotions(Battle battle) async {
    if (battle.potionsUsed.isEmpty || _consumed[battle] == true) return;
    _consumed[battle] = true;
    var a = _alc;
    final used = <String>[];
    battle.potionsUsed.forEach((key, n) {
      if (key.startsWith('shop:')) {
        for (var i = 0; i < n; i++) {
          used.add(key.substring(5));
        }
      } else if (key.startsWith('alc:')) {
        a = a.add(key.substring(4), -n);
      }
    });
    if (used.isNotEmpty) {
      final today = await _todayRecord();
      await _save(today.copyWith(itemsUsed: [...today.itemsUsed, ...used]));
    }
    await _saveAlc(a);
  }

  /// 공방 물약을 전투 밖에서 마신다. 못 마시면 이유.
  ///
  /// 11-11 #74: 전투·속성·탐험 물약은 종류마다 하나씩 걸린다. 같은 종류를 또
  /// 마시면 새 물약으로 바뀐다. 회복·마나는 바로 듣는다.
  /// 마신 뒤 덧붙여 알려 줄 말 (예: 유인 물약을 같은 날 또 마셨을 때)
  String? drinkNote;

  Future<String?> drinkPotion(String key) async {
    drinkNote = null;
    if (_alc.count(key) <= 0) return '가방에 없어요';
    final now = _clock();
    final buffs = [for (final b in _alc.buffs) if (_buffActive(b, now)) b];
    var a = _alc.copyWith(buffs: buffs);
    if (key.startsWith('?:')) {
      final e = AlchemyRules.suspiciousEffect(_putOf(key));
      if (e.stat == null) {
        await refreshVitals();
        _vitals = _vitals.copyWith(
            hp: math.min(maxHp, hp + (maxHp * e.amount / 100).round()),
            lastMaxHp: maxHp);
        await store.saveVitals(_vitals);
      } else {
        a = a.copyWith(buffs: [
          for (final b in a.buffs)
            if (!b.key.startsWith('?:')) b,
          ActiveBuff(
              key: '?:${e.stat!.name}',
              until: now.add(AlchemyRules.suspiciousDuration),
              amount: e.amount),
        ]);
      }
      a = a.add(key, -1).copyWith(knownSuspicious: {
        ...a.knownSuspicious,
        key,
      }.toList());
      await _saveAlc(a);
      return null;
    }
    final info = _infoOf(key);
    if (info == null) return '알 수 없는 물약이에요';
    final m = _qualityMult(key);
    Duration dur(Duration d) => Duration(seconds: (d.inSeconds * m).round());
    final battles = (info.battles * m).round();
    ActiveBuff? next;
    switch (info.kind) {
      case PotionKind.heal:
        await refreshVitals();
        if (hp >= maxHp) return '이미 가득해요';
        _vitals = _vitals.copyWith(
            hp: math.min(maxHp, hp + (maxHp * info.hpRatio * m).round()),
            lastMaxHp: maxHp);
        await store.saveVitals(_vitals);
      case PotionKind.mana:
        await refreshVitals();
        if (mp >= mpMax) return '이미 가득해요';
        _vitals = _vitals.copyWith(
            mp: math.min(mpMax, mp + (mpMax * info.mpRatio * m).round()));
        await store.saveVitals(_vitals);
      case PotionKind.care:
        return '전투 중에만 마실 수 있어요';
      case PotionKind.buff:
        next = ActiveBuff(
            key: info.id.name,
            until: now.add(const Duration(days: 30)),
            battles: battles,
            amount: (AlchemyRules.buffStat * m).round());
      case PotionKind.resist:
        next = ActiveBuff(
            key: info.id.name,
            until: now.add(const Duration(days: 30)),
            battles: battles,
            amount: (AlchemyRules.resistCut * 100 * m).round());
      case PotionKind.weapon:
        next = ActiveBuff(
            key: info.id.name,
            until: now.add(const Duration(days: 30)),
            battles: battles);
      case PotionKind.special:
        switch (info.id) {
          case PotionId.plenty:
            next = ActiveBuff(
                key: 'plenty', until: now.add(dur(info.duration)));
          case PotionId.steps:
            final today = await _todayRecord();
            next = ActiveBuff(
              key: info.id.name,
              until: DateTime(now.year, now.month, now.day + 1),
              day: today.dayKey,
              stepsFrom: today.steps,
              stepsCap: (info.steps * m).round(),
              amount: TownRules.gaugeBonusOn(today),
            );
          case PotionId.callMonsters || PotionId.callModified:
            final day = player.today?.dayKey ?? '';
            final already = a.calledDays[info.id.name] == day;
            // 11-11 A3: 유인 물약은 하루 1번만 부르고, 채집 자리 1.5배는 마실 때마다 다시
            if (already && info.id != PotionId.callMonsters) {
              return '오늘은 이미 불렀어요';
            }
            if (already) {
              drinkNote = '오늘은 이미 불렀어요. 채집 자리만 늘었어요.';
            } else {
              final center = _lastFix?.point;
              if (center == null) return '위치를 켜 주세요';
              a = a.copyWith(
                calledDays: {...a.calledDays, info.id.name: day},
                called: [
                  for (final c in a.called)
                    if (c.id.startsWith(day)) c,
                  ..._callSpawns(center, day, info.id == PotionId.callModified,
                      a.called.length),
                ],
              );
            }
            // 유인 물약 (11-11 #74): 30분 동안 채집 자리 1.5배
            if (info.id == PotionId.callMonsters) {
              next = ActiveBuff(
                  key: info.id.name, until: now.add(dur(info.duration)));
            }
          default:
            return '지금은 마실 수 없어요';
        }
    }
    if (next != null) {
      // 같은 종류는 새 물약으로 바뀐다
      final slot = info.slot;
      a = a.copyWith(buffs: [
        for (final b in a.buffs)
          if (_slotOf(b) != slot) b,
        next,
      ]);
      _spotsKey = null; // 유인 물약이면 채집 자리를 다시 만든다
    }
    await _saveAlc(a.add(key, -1));
    return null;
  }

  /// 물약 효과가 아직 남았는지 (전투 수 · 걸음 · 시간)
  bool _buffActive(ActiveBuff b, [DateTime? at]) {
    if (b.battles != null) return b.battles! > 0;
    if (b.stepsCap != null) {
      final today = player.today;
      if (today == null || b.day != today.dayKey) return false;
      return today.steps - (b.stepsFrom ?? 0) < b.stepsCap!;
    }
    return b.until.isAfter(at ?? _clock());
  }

  /// 걸린 물약의 종류 (수상한 물약은 따로)
  PotionSlot? _slotOf(ActiveBuff b) {
    final id = AlchemyRules.byName(b.key);
    return id == null ? null : AlchemyRules.info(id).slot;
  }

  /// 전투·속성 물약은 전투가 끝날 때마다 남은 횟수가 하나 준다 (11-11 #74)
  Future<void> _spendBattleBuffs() async {
    if (!_alc.buffs.any((b) => b.battles != null)) return;
    await _saveAlc(_alc.copyWith(buffs: [
      for (final b in _alc.buffs)
        if (b.battles == null)
          b
        else if (b.battles! > 1)
          b.withBattles(b.battles! - 1),
    ]));
  }

  /// 걸음 물약 효과 설명 (남은 전투 · 걸음 · 시간)
  String buffLeftLabel(ActiveBuff b) {
    if (b.battles != null) return '전투 ${b.battles}번 남음';
    if (b.stepsCap != null) {
      final walked = (player.today?.steps ?? 0) - (b.stepsFrom ?? 0);
      return '${comma(math.max(0, b.stepsCap! - walked))}보 남음';
    }
    final left = b.until.difference(_clock()).inMinutes;
    return '${math.max(1, left)}분 남음';
  }

  /// 걸린 물약의 이름 (수상한 물약은 스탯)
  String buffName(ActiveBuff b) {
    if (b.key.startsWith('?:')) return '수상한 물약';
    final id = AlchemyRules.byName(b.key);
    return id == null ? b.key : AlchemyRules.info(id).name;
  }

  /// 공격 속성 물약의 속성 (없으면 null)
  Element? get weaponPotionElement {
    for (final b in activeBuffs) {
      final id = AlchemyRules.byName(b.key);
      if (id == null) continue;
      final info = AlchemyRules.info(id);
      if (info.kind == PotionKind.weapon) return info.element;
    }
    return null;
  }

  /// 유인 물약이 걸려 있는지 (채집 자리 1.5배)
  bool get lureActive => activeBuffs.any((b) => b.key == PotionId.callMonsters.name);

  List<CalledSpawn> _callSpawns(
      GeoPoint center, String day, bool modified, int start) {
    final n = modified ? AlchemyRules.callModCount : AlchemyRules.callCount;
    final out = <CalledSpawn>[];
    for (var i = 0; i < n; i++) {
      final r = AlchemyRules.callRadiusM * math.sqrt(_random.nextDouble());
      final t = _random.nextDouble() * 2 * math.pi;
      final lat = center.lat + r * math.cos(t) / 111320.0;
      final lng = center.lng +
          r * math.sin(t) / (111320.0 * math.cos(center.lat * math.pi / 180));
      final monster = FieldMonsterRules.pickCommon(
          _random.nextDouble(), _random.nextDouble(),
          night: FieldMonsterRules.isNight(_clock()));
      final mods = <String>[];
      if (modified) {
        final grade = _random.nextDouble() < AlchemyRules.callModRareChance
            ? ModGrade.rare
            : ModGrade.common;
        mods.add(ModifierRules.pick(grade, monster, _random).name);
      }
      out.add(CalledSpawn(
          id: '$day#call${start + i}',
          monster: monster.name,
          lat: lat,
          lng: lng,
          mods: mods));
    }
    return out;
  }

  /// 부르는 물약으로 나온 오늘의 몬스터
  List<FieldSpawn> get calledSpawns {
    final day = player.today?.dayKey ?? '';
    return [
      for (final c in _alc.called)
        if (c.id.startsWith(day))
          if (Monsters.byName(c.monster) case final m?)
            FieldSpawn(
              id: c.id,
              monster: m,
              point: GeoPoint(c.lat, c.lng),
              modifiers: [
                for (final n in c.mods)
                  if (ModifierRules.byName(n) case final x?) x,
              ],
            ),
    ];
  }

  /// 지금 걸린 버프·저항
  List<ActiveBuff> get activeBuffs =>
      [for (final b in _alc.buffs) if (_buffActive(b)) b];

  /// 물약 버프로 더해지는 스탯
  Stats get buffStats {
    var st = Stats.zero;
    for (final b in activeBuffs) {
      final name = b.key.startsWith('?:') ? b.key.substring(2) : null;
      final id = name == null ? AlchemyRules.byName(b.key) : null;
      final kind = name != null
          ? StatKindInfo.parse(name)
          : (id == null ? null : AlchemyRules.info(id).stat);
      if (kind == null) continue;
      st = st + Stats.zero.withValue(kind, b.amount);
    }
    return st;
  }

  Map<Element, double> get activeResists => {
        for (final b in activeBuffs)
          if (AlchemyRules.byName(b.key) case final id?)
            if (AlchemyRules.info(id).kind == PotionKind.resist)
              if (AlchemyRules.info(id).element case final el?) el: b.amount / 100,
      };

  bool get plentyActive => activeBuffs.any((b) => b.key == 'plenty');

  // ───────────── 공방 변환 (11-11 #74)

  /// 변환대에서 진행 중인 것 (없으면 null)
  ConvertJob? get convertJob => _alc.convert;

  bool get convertReady {
    final j = _alc.convert;
    return j != null && !_clock().isBefore(j.readyAt);
  }

  /// 연금술사 숙련도 단계 (직업 각성 뒤에 효과가 생긴다)
  AlchemistRank get alchemistRank => AlchemistRules.rankOf(_alc.mastery);

  /// 변환할 수 있는지 (금화·재료·마석·물약, 시간이 드는 변환은 변환대가 비어야 한다)
  bool canConvert(ConvertPlan p) {
    if (p.minutes > 0 && _alc.convert != null) return false;
    if (player.gold < p.gold || player.manaStones < p.giveManaStones) return false;
    for (final e in p.give.entries) {
      if (player.materialCount(e.key) < e.value) return false;
    }
    if (p.givePotion != null && _alc.count(p.givePotion!) <= 0) return false;
    return true;
  }

  /// 변환을 시작한다. 분해는 바로 끝난다.
  Future<bool> startConvert(ConvertPlan p) async {
    if (!canConvert(p)) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {
        for (final e in p.give.entries) e.key.name: e.value,
        if (p.gold > 0) Wallet.gold: p.gold,
        if (p.giveManaStones > 0) Wallet.manaStone: p.giveManaStones,
      }),
    ));
    var a = _alc;
    if (p.givePotion != null) a = a.add(p.givePotion!, -1);
    if (p.minutes == 0) {
      await _saveAlc(a);
      await _grant(0, p.getManaStones, p.get);
      return true;
    }
    final now = _clock();
    final ready = now.add(Duration(minutes: p.minutes));
    await _saveAlc(a.copyWith(
      mastery: a.mastery + AlchemistRules.convertPoints,
      convert: ConvertJob(
        kind: p.kind.name,
        get: {for (final e in p.get.entries) e.key.name: e.value},
        getManaStones: p.getManaStones,
        startedAt: now,
        readyAt: ready,
      ),
    ));
    unawaited(notifier?.schedule(
        260, ready, '변환이 끝났어요', '연금술 공방 변환대에서 꺼내 가세요!'));
    return true;
  }

  /// 다 된 변환을 꺼낸다
  Future<ConvertJob?> collectConvert() async {
    final j = _alc.convert;
    if (j == null || !convertReady) return null;
    await _saveAlc(_alc.copyWith(clearConvert: true));
    await _grant(0, j.getManaStones, {
      for (final e in j.get.entries)
        if (Materials.byName(e.key) case final m?) m: e.value,
    });
    return j;
  }

  // ───────────── 재료 가공 (11-11 #59)

  bool canProcess(ProcessRecipe r) =>
      player.gold >= r.gold && ProcessRules.use(r, player.materials) != null;

  /// 하위 재료를 상위 재료로 바꾼다 (바로 끝남)
  Future<bool> process(ProcessRecipe r) async {
    final use = ProcessRules.use(r, player.materials);
    if (use == null || player.gold < r.gold) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {
        for (final e in use.entries) e.key.name: e.value,
        if (r.gold > 0) Wallet.gold: r.gold,
      }),
      gains: DailyRecord.addCounts(today.gains, {r.output.name: r.count}),
    ));
    return true;
  }

  /// 공방 물약을 버린다
  Future<bool> discardPotion(String key, int n) async {
    if (_alc.count(key) < n || n <= 0) return false;
    await _saveAlc(_alc.add(key, -n));
    return true;
  }

  /// 자동 마시기 설정
  Future<void> setAutoUse({int? hpPercent, bool? cure}) async =>
      _saveAlc(_alc.copyWith(autoHp: hpPercent, autoCure: cure));


  // ───────────────────────────────────────────── 걸음 주머니 · 길가 · 상인 (11-11 #59)

  static const _gatherKey = 'gather';
  GatherState _gather = const GatherState();

  GatherState get gather => _gather;

  Future<void> _saveGather(GatherState g) async {
    _gather = g;
    await store.saveJson(_gatherKey, g.toJson());
    notifyListeners();
  }

  /// 걸음 주머니·길가의 발견·떠돌이 상인을 만들지 (예시 모드는 끔)
  bool walkEvents = true;

  /// 걸음 주머니·무작위 이벤트를 걸음에 맞춰 만든다 (앱을 열 때·화면을 볼 때)
  Future<void> _checkWalkEvents() async {
    final today = player.today;
    if (today == null || !walkEvents) return;
    final now = _clock();
    var g = _gather;
    if (g.day != today.dayKey) {
      g = g.copyWith(
          day: today.dayKey,
          pouchesGiven: 0,
          stepsChecked: 0,
          findsToday: 0,
          merchantToday: 0);
    }
    // 승객 모드 (11-11 #61): 차 안에서 늘어난 걸음은 주머니·발견에 세지 않는다
    if (passengerMode) {
      g = g.copyWith(
          pouchesGiven: math.max(g.pouchesGiven, GatherRules.pouchesFor(today.steps)),
          stepsChecked: today.steps -
              (today.steps - g.stepsChecked) % GatherRules.findSteps);
    }
    // 걸음 주머니
    final due = GatherRules.pouchesFor(today.steps);
    var newPouch = false;
    if (due > g.pouchesGiven) {
      g = g.copyWith(
          pouches: g.pouches + (due - g.pouchesGiven), pouchesGiven: due);
      newPouch = true;
    }
    // 길가의 발견 · 떠돌이 상인
    var notifyFind = false, notifyMerchant = false;
    var checked = g.stepsChecked;
    while (today.steps - checked >= GatherRules.findSteps) {
      checked += GatherRules.findSteps;
      final open = g.findUntil != null && g.findUntil!.isAfter(now);
      if (!open &&
          g.findsToday < GatherRules.findsPerDay &&
          _random.nextDouble() < GatherRules.findChance) {
        g = g.copyWith(
            findUntil: now.add(GatherRules.findValid),
            findsToday: g.findsToday + 1);
        notifyFind = true;
      }
      if (checked % GatherRules.merchantSteps < GatherRules.findSteps &&
          g.merchantToday < GatherRules.merchantPerDay &&
          _random.nextDouble() < GatherRules.merchantChance) {
        // 상인은 내 근처(60~120m)에 선다 (11-11 #84)
        final here = _lastFix?.point ?? fallbackCenter;
        final at = here == null
            ? null
            : _merchantSpot(here, 60 + _random.nextDouble() * 60,
                _random.nextDouble() * math.pi * 2);
        g = g.copyWith(
          merchantUntil: now.add(GatherRules.merchantStay),
          merchantToday: g.merchantToday + 1,
          merchantLat: at?.lat,
          merchantLng: at?.lng,
          sold: const [],
          offers: {
            for (final e in GatherRules.offers(_random).entries)
              e.key.name: e.value,
          },
          noteOffer: _random.nextDouble() < GatherRules.noteOfferChance,
        );
        notifyMerchant = true;
      }
    }
    g = g.copyWith(stepsChecked: checked);
    if (g.toJson().toString() != _gather.toJson().toString()) await _saveGather(g);
    if (newPouch) _newPouch = true;
    final quiet = GatherRules.quietHour(now) || !g.notify;
    if (notifyFind && !quiet) {
      unawaited(notifier?.schedule(NotifyId.find, now.add(const Duration(seconds: 2)),
          '길가에서 반짝이는 것을 발견했어!', '30분 안에 열어 보면 받을 수 있어요.'));
    }
    if (notifyMerchant && !quiet) {
      unawaited(notifier?.schedule(
          NotifyId.merchant,
          now.add(const Duration(seconds: 2)),
          '떠돌이 상인이 나타났어!',
          '20분 동안만 귀한 재료를 팔아요.'));
    }
  }

  bool _newPouch = false;
  bool takeNewPouch() {
    final v = _newPouch;
    _newPouch = false;
    return v;
  }

  /// 길가의 발견이 열려 있는지
  bool get findOpen =>
      _gather.findUntil != null && _gather.findUntil!.isAfter(_clock());

  /// 떠돌이 상인이 있는지
  bool get merchantHere =>
      !inTutorial && // 묶음 18 #150
      _gather.merchantUntil != null &&
      _gather.merchantUntil!.isAfter(_clock());

  static GeoPoint _merchantSpot(GeoPoint from, double meters, double angle) {
    const mPerDegLat = 111320.0;
    final dLat = meters * math.cos(angle) / mPerDegLat;
    final dLng = meters *
        math.sin(angle) /
        (mPerDegLat * math.cos(from.lat * math.pi / 180));
    return GeoPoint(from.lat + dLat, from.lng + dLng);
  }

  /// 떠돌이 상인이 선 자리 (없으면 null). 예전 기록처럼 자리가 없으면 내 위치.
  GeoPoint? get merchantPoint {
    if (!merchantHere) return null;
    final g = _gather;
    if (g.merchantLat != null && g.merchantLng != null) {
      return GeoPoint(g.merchantLat!, g.merchantLng!);
    }
    return _lastFix?.point ?? fallbackCenter;
  }

  /// 상인이 떠나기까지 남은 분 (없으면 0)
  int get merchantMinutesLeft => merchantHere
      ? (_gather.merchantUntil!.difference(_clock()).inSeconds + 59) ~/ 60
      : 0;

  /// 이번 상인에게서 이미 샀는지 ([m] 이 null 이면 레시피 쪽지)
  bool merchantSold(MaterialId? m) => _gather.sold.contains(m?.name ?? 'note');

  // 지도에서 보여 달라는 자리 (위쪽 띠를 눌렀을 때, 11-11 #84)
  GeoPoint? _mapFocus;
  void requestMapFocus(GeoPoint p) {
    _mapFocus = p;
    notifyListeners();
  }

  GeoPoint? takeMapFocus() {
    final p = _mapFocus;
    _mapFocus = null;
    return p;
  }

  /// 걸음 주머니를 연다
  Future<({Map<MaterialId, int> mats, int gold, bool note})?> openPouch() async {
    if (_gather.pouches <= 0) return null;
    final r = GatherRules.openPouch(_random);
    await _saveGather(_gather.copyWith(pouches: _gather.pouches - 1));
    await _grant(r.gold, 0, r.mats);
    if (r.note) await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
    return r;
  }

  /// 길가의 발견을 연다 (30분이 지나면 null)
  Future<({Map<MaterialId, int> mats, int gold, bool note})?> openFind() async {
    if (!findOpen) return null;
    final r = GatherRules.openFind(_random);
    await _saveGather(_gather.copyWith(clearFind: true));
    await _grant(r.gold, 0, r.mats);
    if (r.note) await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
    return r;
  }

  /// 떠돌이 상인에게서 산다 ([m] 이 null 이면 레시피 쪽지)
  Future<bool> buyFromMerchant(MaterialId? m) async {
    if (!merchantHere) return false;
    final price = m == null
        ? (_gather.noteOffer ? GatherRules.notePrice : null)
        : _gather.offers[m.name];
    if (price == null || player.gold < price || merchantSold(m)) return false;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {Wallet.gold: price})));
    // 한 번만 살 수 있다: 팔린 것은 「팔렸어요」로 남긴다 (11-11 #84)
    if (m == null) {
      await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
    } else {
      await _grant(0, 0, {m: 1});
    }
    await _saveGather(
        _gather.copyWith(sold: [..._gather.sold, m?.name ?? 'note']));
    return true;
  }

  /// 걸을 때 알림 켜고 끄기 (설정)
  Future<void> setWalkNotify(bool on) => _saveGather(_gather.copyWith(notify: on));

  // ───────────────────────────────────────────── 우편 (11-11 #65)

  static const _mailKey = 'mail';
  MailState _mail = const MailState();

  /// 운영 우편을 가져오는 곳 (1차: 앱에 담은 목록, 2차: 서버)
  List<MailSource> mailSources = const [AssetMailSource()];

  MailState get mail => _mail;

  Future<void> _saveMail(MailState m) async {
    _mail = m;
    await store.saveJson(_mailKey, m.toJson());
    notifyListeners();
  }

  /// 새 우편이 있는지 (읽지 않았거나 받을 선물이 있으면 빨간 점)
  bool get hasNewMail => _mail.mails.any((m) => !m.read || m.hasGifts);

  /// 선물 탭: 받을 선물이 남은 우편 (사라질 날이 가까운 것부터)
  List<MailItem> get giftMails => [
        for (final m in _mail.mails)
          if (m.hasGifts) m,
      ]..sort((a, b) => (a.expiresAt ?? DateTime(9999))
          .compareTo(b.expiresAt ?? DateTime(9999)));

  /// 우편함 한 목록 (11-11 #100): 선물과 편지를 함께, 새것부터
  List<MailItem> get allMails => [..._mail.mails]
    ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  /// 편지·공지 (새것부터)
  List<MailItem> get letterMails => [
        for (final m in _mail.mails)
          if (m.kind != MailKind.reward) m,
      ]..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  /// 우편을 보낸다 (같은 id는 한 번만)
  Future<bool> _sendMail(MailItem m) async {
    if (_mail.sent.contains(m.id)) return false;
    await _saveMail(_mail.copyWith(
      mails: [m, ..._mail.mails],
      sent: [..._mail.sent, m.id],
    ));
    return true;
  }

  Future<void> readMail(String id) async {
    if (!_mail.mails.any((m) => m.id == id && !m.read)) return;
    await _saveMail(_mail.copyWith(mails: [
      for (final m in _mail.mails) m.id == id ? m.copyWith(read: true) : m,
    ]));
  }

  /// 우편 선물을 받는다. 받은 것 글을 돌려준다 (못 받으면 null).
  /// 가방이 가득하면 넘치는 물건은 금화로, 금화·마석·경험치는 늘 받는다.
  Future<String?> claimMail(String id) async {
    final i = _mail.mails.indexWhere((m) => m.id == id);
    if (i < 0 || !_mail.mails[i].hasGifts) return null;
    final m = _mail.mails[i];
    final got = <String>[];
    var gold = 0, mana = 0, exp = 0, notes = 0, eggs = 0;
    final mats = <MaterialId, int>{};
    final items = <ShopItem, int>{};
    m.gifts.forEach((k, v) {
      if (k == Wallet.gold) {
        gold += v;
      } else if (k == Wallet.manaStone) {
        mana += v;
      } else if (k == Wallet.exp) {
        exp += v;
      } else if (k == 'note') {
        notes += v;
      } else if (k == 'egg') {
        eggs += v;
      } else if (k.startsWith('item:')) {
        for (final it in ShopItem.values) {
          if (it.name == k.substring(5)) items[it] = (items[it] ?? 0) + v;
        }
      } else if (Materials.byName(k) case final mat?) {
        mats[mat] = (mats[mat] ?? 0) + v;
      }
    });
    // 물건: 칸이 없으면 금화로
    final today = await _todayRecord();
    final counters = <String, int>{};
    var itemGold = 0;
    for (final e in items.entries) {
      var have = bagCount(e.key);
      for (var n = 0; n < e.value; n++) {
        if (_roomFor(have)) {
          counters[TownRules.giftKey(e.key)] = (counters[TownRules.giftKey(e.key)] ?? 0) + 1;
          have++;
        } else {
          itemGold += BagRules.itemPrice(e.key);
        }
      }
      got.add('${itemName(e.key)} ${e.value}');
    }
    if (counters.isNotEmpty || exp > 0) {
      await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters, counters),
        gains: exp > 0 ? DailyRecord.addCounts(today.gains, {Wallet.exp: exp}) : null,
      ));
    }
    if (gold + itemGold > 0 || mana > 0 || mats.isNotEmpty) {
      await _grant(gold + itemGold, mana, mats);
    }
    if (notes > 0 || eggs > 0) {
      final p = _pets;
      await _savePets(p.copyWith(
        recipeNotes: p.recipeNotes + notes,
        eggs: [
          ...p.eggs,
          for (var n = 0; n < eggs; n++)
            PetEgg(id: 'egg${p.nextId + n}', source: 'mail', element: mainElement?.name),
        ],
        nextId: p.nextId + eggs,
        firstEggFound: p.firstEggFound || eggs > 0,
      ));
    }
    if (gold > 0) got.add('금화 $gold');
    if (mana > 0) got.add('마석 $mana');
    if (exp > 0) got.add('경험치 $exp');
    for (final e in mats.entries) {
      got.add('${Materials.info(e.key).name} ${e.value}');
    }
    if (notes > 0) got.add('레시피 쪽지 $notes');
    if (eggs > 0) got.add('알 $eggs');
    if (itemGold > 0) got.add('(가방이 가득해 금화 $itemGold로)');
    // 11-11 #100: 받은 뒤에도 편지는 계속 보관한다 (보상 우편도 편지처럼)
    await _saveMail(_mail.copyWith(mails: [
      for (final x in _mail.mails)
        if (x.id != id) x else x.copyWith(claimed: true, read: true),
    ]));
    return got.join(', ');
  }

  /// 모두 받기
  Future<int> claimAllMail() async {
    var n = 0;
    for (final m in giftMails) {
      if (await claimMail(m.id) != null) n++;
    }
    return n;
  }

  /// 우편 보내기·정리 (앱을 열 때·화면을 볼 때)
  Future<void> _checkMail() async {
    final now = _clock();
    // 30일 지나도록 받지 않은 물건이 든 편지는 사라진다 (받은 편지는 계속 보관)
    bool gone(MailItem m) =>
        m.hasGifts && m.expiresAt != null && now.isAfter(m.expiresAt!);
    if (_mail.mails.any(gone)) {
      await _saveMail(_mail.copyWith(mails: [
        for (final m in _mail.mails)
          if (!gone(m)) m,
      ]));
    }
    // 운영 우편 (공지·보상)
    for (final src in mailSources) {
      for (final m in await src.fetch(now)) {
        await _sendMail(m);
      }
    }
    await _checkNpcLetters();
  }

  Future<void> _npc(NpcLetter l) => _sendMail(MailItem(
        id: l.id,
        kind: MailKind.letter,
        from: l.from,
        title: l.title,
        body: l.body,
        gifts: l.gifts,
        sentAt: _clock(),
      ));

  Future<void> _checkNpcLetters() async {
    var errands = 0, shopping = 0;
    for (final r in _history) {
      errands += (r.counters['errandDone'] ?? 0) + (r.counters['urgentDone'] ?? 0);
      shopping += r.goldPurchases.length;
    }
    for (final e in NpcLetter.errandThanks.entries) {
      if (errands >= e.key) await _npc(e.value);
    }
    if (shopping >= 10) await _npc(NpcLetter.minaThanks);
    if (player.level.level >= 3) await _npc(NpcLetter.minaRumor);
    if (_armory.crafts >= 1) await _npc(NpcLetter.dorgunFirst);
    if (_alc.discovered.isNotEmpty) await _npc(NpcLetter.elielFirst);
    if (urgent != null) await _npc(NpcLetter.hartUrgent);
  }

  /// 어제까지 다 하고 못 받은 수시·긴급 의뢰 보상을 우편으로 (날이 바뀔 때)
  Future<void> _mailExpiredBoard() async {
    final old = _board;
    final todayKey = DailyRecord.dayKeyOf(_clock());
    if (old.day.isEmpty || old.day == todayKey) return;
    DailyRecord? rec;
    for (final r in _history) {
      if (r.dayKey == old.day) rec = r;
    }
    if (rec != null) {
      for (var i = 0; i < old.slots.length; i++) {
        final s = old.slots[i];
        final t = BoardRules.template(s.templateId);
        if (t == null || !s.accepted) continue;
        if (BoardRules.progress(t, rec, s.baseline) < t.target) continue;
        await _sendMail(MailItem(
          id: 'board_${old.day}_$i',
          kind: MailKind.reward,
          from: MailRules.hart,
          title: '받지 못한 의뢰 보상: ${t.title}',
          body: '기한이 끝나 우편으로 보내네. 다음엔 게시판에서 바로 받아 가게.',
          gifts: {
            if (t.gold > 0) Wallet.gold: t.gold,
            if (t.manaStones > 0) Wallet.manaStone: t.manaStones,
            for (final e in t.materials.entries) e.key.name: e.value,
          },
          sentAt: _clock(),
          expiresAt: _clock().add(MailRules.rewardKeep),
        ));
      }
      final day = DateTime.tryParse(old.day);
      final u = day == null ? null : BoardRules.urgentFor(day.add(const Duration(hours: 23)));
      if (u != null &&
          old.urgentAccepted &&
          !old.urgentDone &&
          BoardRules.progress(u.quest, rec, old.urgentBaseline) >= u.quest.target) {
        await _sendMail(MailItem(
          id: 'urgent_${old.day}',
          kind: MailKind.reward,
          from: MailRules.hart,
          title: '받지 못한 긴급 의뢰 보상',
          body: '긴급 의뢰를 끝내 놓고 보상을 잊었더군. 우편으로 보내네.',
          gifts: {
            if (u.quest.gold > 0) Wallet.gold: u.quest.gold,
            if (u.prize == UrgentPrize.rareMaterial) u.rare.name: 1,
          },
          sentAt: _clock(),
          expiresAt: _clock().add(MailRules.rewardKeep),
        ));
      }
    }
    await _saveBoard(board);
  }

  // ───────────────────────────────────────────── 승객 확인 (11-11 #61)

  static const _driveKey = 'drive';
  DriveState _drive = const DriveState();

  /// 차량 속도 감지 상태
  DriveMode get driveMode => _drive.mode;

  /// 승객이라고 답하고 차로 이동하는 중 (보상 제한)
  bool get passengerMode => _drive.mode == DriveMode.passenger;

  /// 화면을 가리는 중 (묻기·안전 운전)
  bool get driveBlocked =>
      _drive.mode == DriveMode.asking || _drive.mode == DriveMode.driving;

  Future<void> _saveDrive(DriveState d) async {
    _drive = d;
    await store.saveJson(_driveKey, d.toJson());
    notifyListeners();
  }

  DateTime? _fastSince;
  DateTime? _slowSince;

  /// 마지막으로 움직인 때 (채집 미니게임은 멈춰 있어야 한다)
  DateTime? _lastMovingAt;

  /// 최근 10초 동안 멈춰 있는지
  bool get standingStill {
    if (_lastFix == null) return false;
    final m = _lastMovingAt;
    return m == null || _clock().difference(m) >= HarvestRules.stillFor;
  }

  Future<void> _watchSpeed(LocationFix fix) async {
    final now = _clock();
    if (fix.speedMps > HarvestRules.stillSpeedMps) _lastMovingAt = now;
    if (fix.speedMps >= DriveRules.carSpeedMps) {
      _slowSince = null;
      _fastSince ??= now;
      if (_drive.mode == DriveMode.none &&
          now.difference(_fastSince!) >= DriveRules.carFor) {
        // 차에 타기 전까지 걸은 걸음은 먼저 센다
        await _petSteps();
        await _checkWalkEvents();
        await _saveDrive(_drive.copyWith(mode: DriveMode.asking, askedAt: now));
      }
    } else {
      _fastSince = null;
      if (fix.speedMps < DriveRules.endSpeedMps) {
        _slowSince ??= now;
        if (_drive.mode != DriveMode.none &&
            now.difference(_slowSince!) >= DriveRules.endAfter) {
          await _endTrip();
        }
      } else {
        _slowSince = null;
      }
    }
    // 묻는 화면에 답이 없으면 안전 운전 화면
    if (_drive.mode == DriveMode.asking &&
        _drive.askedAt != null &&
        now.difference(_drive.askedAt!) >= DriveRules.askTimeout) {
      await _saveDrive(_drive.copyWith(mode: DriveMode.driving));
    }
  }

  Future<void> _endTrip() async {
    if (passengerMode) {
      // 차 안에서 늘어난 걸음은 주머니·펫 경험치에 넣지 않는다
      await _petSteps();
      await _checkWalkEvents();
    }
    await _saveDrive(_drive.copyWith(mode: DriveMode.none));
  }

  /// 「승객이에요」/「운전 중이에요」
  Future<void> answerDrive({required bool passenger}) => _saveDrive(
      _drive.copyWith(mode: passenger ? DriveMode.passenger : DriveMode.driving));

  /// 오래 답이 없을 때 (화면에서 부른다)
  Future<void> driveTimeout() async {
    if (_drive.mode == DriveMode.asking) {
      await _saveDrive(_drive.copyWith(mode: DriveMode.driving));
    }
  }

  // ───────────────────────────────────────────── 채집 (11-11 #56)

  static const _harvestKey = 'harvest';
  HarvestState _harvest = const HarvestState();

  HarvestState get harvest => _harvest;

  Future<void> _saveHarvest(HarvestState h) async {
    _harvest = h;
    await store.saveJson(_harvestKey, h.toJson());
    notifyListeners();
  }

  String? _spotsKey;
  List<HarvestSpot> _spotsCache = const [];

  /// 지도에 보이는 채집 자리 (지금 위치 둘레 3km)
  List<HarvestSpot> get harvestSpots {
    if (inTutorial) return const []; // 묶음 18 #150
    final center = _lastFix?.point ?? fallbackCenter;
    if (center == null) return const [];
    final lure = lureActive;
    final night = HarvestRules.isNight(_clock());
    final key = '${(center.lat * 1000).round()}_${(center.lng * 1000).round()}'
        '${lure ? 'L' : ''}${night ? 'N' : ''}${lands == null ? '' : 'P'}'
        '${_legacyGates ? '' : 'v${player.level.level}${_harvestTutorial ? 'T' : ''}'}';
    if (key != _spotsKey) {
      _spotsKey = key;
      _spotsCache = HarvestRules.spotsAround(center,
          roads: roads,
          exclusions: exclusions,
          places: area.places,
          excluded: area.isExcluded,
          density: lure ? AlchemyRules.lureHarvest : 1,
          night: night,
          land: lands?.kindAt);
      // 묶음 16 #143: 새로 시작한 사람은 Lv.5에 채집이 열리고, 처음엔 꽃·버섯 자리만
      if (!_legacyGates) {
        final lv = player.level.level;
        _spotsCache = lv < 5
            ? const []
            : [
                if (_harvestTutorial && _lastFix != null)
                  HarvestSpot(
                      id: 'tutorial-harvest',
                      kind: HarvestKind.flower,
                      point: GeoPoint(_lastFix!.point.lat + 0.00008,
                          _lastFix!.point.lng + 0.00006)),
                for (final x in _spotsCache)
                  if (lv >= 7 ||
                      x.kind == HarvestKind.flower ||
                      x.kind == HarvestKind.mushroom)
                    x,
              ];
      }
    }
    return _spotsCache;
  }

  /// 마지막으로 받은 위치
  GeoPoint? get lastPoint => _lastFix?.point;

  /// 가까이 있는 채집 자리 (40m 안)
  HarvestSpot? get nearbyHarvest {
    final fix = _lastFix;
    if (fix == null) return null;
    HarvestSpot? best;
    double? bd;
    for (final s in harvestSpots) {
      final d = s.point.distanceTo(fix.point);
      if (d <= HarvestRules.reachM && (bd == null || d < bd)) {
        best = s;
        bd = d;
      }
    }
    return best;
  }

  int harvestCharges(HarvestSpot s) => _harvest.chargesOf(s.id, _clock());

  /// 다음 하나가 차기까지
  Duration? harvestRefill(HarvestSpot s) =>
      _harvest.spots[s.id]?.untilNext(_clock());

  /// 도구 내구도 (처음 채집 전에는 새 도구로 친다)
  int toolDurability(HarvestTool t) => _harvest.granted
      ? _harvest.durability(t)
      : HarvestRules.toolMaxFor(_harvest.tierOf(t));

  /// 도구 최대 내구도 (등급에 따라)
  int toolMaxOf(HarvestTool t) => HarvestRules.toolMaxFor(_harvest.tierOf(t));

  ToolTier toolTier(HarvestTool t) => _harvest.tierOf(t);
  Element? toolElement(HarvestTool t) => _harvest.elementOf(t);

  /// 미니게임이 쉬워지는 정도 (도구 등급, 숨김)
  int harvestEase(HarvestKind k) =>
      _harvest.tierOf(HarvestRules.info(k).tool).index;

  /// 채집가 직업 (#55 각성 뒤, 지금은 늘 false. 규칙만 준비)
  bool get gatherer => false;

  /// 도구를 다음 등급으로 (대장간: 곡괭이·도끼, 공방: 낫·낚싯대·붓)
  CraftCheck canUpgradeTool(HarvestTool t) {
    final cost = HarvestRules.upgradeCost(_harvest.tierOf(t));
    if (cost == null) return CraftCheck.maxed;
    final p = player;
    for (final e in cost.mats.entries) {
      if (p.materialCount(e.key) < e.value) return CraftCheck.materials;
    }
    if (p.gold < cost.gold) return CraftCheck.gold;
    return CraftCheck.ok;
  }

  Future<bool> upgradeTool(HarvestTool t) async {
    if (canUpgradeTool(t) != CraftCheck.ok) return false;
    final tier = _harvest.tierOf(t);
    final cost = HarvestRules.upgradeCost(tier)!;
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
      for (final e in cost.mats.entries) e.key.name: e.value,
      Wallet.gold: cost.gold,
    })));
    final next = ToolTier.values[tier.index + 1];
    await _saveHarvest(_harvest.copyWith(
      tiers: {..._harvest.tiers, t.name: next.index},
      // 새 도구라 내구도를 다 채운다
      tools: {..._harvest.tools, t.name: HarvestRules.toolMaxFor(next)},
    ));
    return true;
  }

  /// 도구에 속성을 입힌다: 빛나는 속성 코어 1개 + 금화 100 (11-11 #83, #63과 같다).
  /// 그 속성의 귀한 재료가 더 잘 나온다 (숨김).
  Future<bool> imbueTool(HarvestTool t, Element e) async {
    final core = EquipmentRules.imbueCore(e);
    if (player.materialCount(core) < 1 || player.gold < EquipmentRules.imbueGold) {
      return false;
    }
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends,
            {core.name: 1, Wallet.gold: EquipmentRules.imbueGold})));
    await _saveHarvest(
        _harvest.copyWith(elements: {..._harvest.elements, t.name: e.name}));
    return true;
  }

  HarvestCheck canHarvest(HarvestSpot s, {bool minigame = false}) {
    final fix = _lastFix;
    if (fix == null || s.point.distanceTo(fix.point) > HarvestRules.reachM) {
      return HarvestCheck.far;
    }
    if (driveBlocked) return HarvestCheck.passenger;
    if (harvestCharges(s) <= 0) return HarvestCheck.empty;
    if (!minigame) return HarvestCheck.ok;
    if (passengerMode) return HarvestCheck.passenger;
    if (!standingStill) return HarvestCheck.moving;
    if (toolDurability(s.info.tool) <= 0) return HarvestCheck.noTool;
    return HarvestCheck.ok;
  }

  /// 채집한다. [grade] 가 quick 이면 빠른 채집, 아니면 미니게임 결과.
  Future<Map<MaterialId, int>?> harvestAt(HarvestSpot s, HarvestGrade grade) async {
    final minigame = grade != HarvestGrade.quick;
    if (canHarvest(s, minigame: minigame) != HarvestCheck.ok) return null;
    if (s.id == 'tutorial-harvest') {
      // 채집 안내 끝: 다음부터는 보통 자리만
      _harvestTutorial = false;
      _spotsKey = null;
    }
    final now = _clock();
    var h = _harvest;
    if (!h.granted) {
      h = h.copyWith(granted: true, tools: {
        for (final t in HarvestTool.values) t.name: toolMaxOf(t),
      });
    }
    final charge = h.spots[s.id] ??
        SpotCharge(charges: HarvestRules.maxCharges, at: now);
    final tool = s.info.tool;
    // 한 종류에서 완벽을 많이 쌓았으면 빠른 채집도 「좋음」 (11-11 #83, 숨김)
    final effective =
        !minigame && h.mastered(s.kind) ? HarvestGrade.good : grade;
    final streak = !minigame
        ? h.streak
        : grade == HarvestGrade.perfect
            ? h.streak + 1
            : 0;
    final mats = HarvestRules.yieldOf(s.kind, effective, _random,
        factor: passengerMode ? 0.5 : 1,
        tier: h.tierOf(tool),
        streak: grade == HarvestGrade.perfect ? h.streak : 0,
        element: h.elementOf(tool),
        month: now.month);
    final relic = s.kind == HarvestKind.relic;
    h = h.copyWith(
      spots: {...h.spots, s.id: charge.use(now)},
      tools: minigame
          ? {...h.tools, tool.name: math.max(0, h.durability(tool) - 1)}
          : h.tools,
      total: h.total + 1,
      streak: streak,
      perfects: grade == HarvestGrade.perfect
          ? {...h.perfects, s.kind.name: (h.perfects[s.kind.name] ?? 0) + 1}
          : h.perfects,
      relics: relic ? h.relics + 1 : h.relics,
    ).pruned(now);
    // 묶음 13 C8: 유물 이야기는 보류. 이야기 칸만 비우고 유물·재료는 그대로
    _lastRelicLore = relic && HarvestRules.relicLore.isNotEmpty
        ? HarvestRules.relicLore[(h.relics - 1) % HarvestRules.relicLore.length]
        : null;
    await _saveHarvest(h);
    await _grant(0, 0, mats);
    if (relic) {
      final today = await _todayRecord();
      await _save(today.copyWith(
          counters: DailyRecord.addCounts(today.counters, {'relicDug': 1})));
    }
    return mats;
  }

  String? _lastRelicLore;

  /// 방금 캔 고대 유물의 이야기 (없으면 null)
  String? get lastRelicLore => _lastRelicLore;

  /// 도구 수리: 금화 30 + 재료 1 (곡괭이·도끼는 대장간, 낫·낚싯대·붓은 공방)
  Future<bool> repairTool(HarvestTool t) async {
    if (!_harvest.granted || _harvest.durability(t) >= toolMaxOf(t)) {
      return false;
    }
    final m = HarvestRules.repairMaterial(t);
    if (player.gold < HarvestRules.repairGold || player.materialCount(m) <= 0) {
      return false;
    }
    final today = await _todayRecord();
    await _save(today.copyWith(
        spends: DailyRecord.addCounts(
            today.spends, {Wallet.gold: HarvestRules.repairGold, m.name: 1})));
    await _saveHarvest(_harvest.copyWith(
        tools: {..._harvest.tools, t.name: toolMaxOf(t)}));
    return true;
  }

  // ───────────────────────────────────────────── 속성 점수 (11-11 #63, 숨김)

  /// 사냥한 몬스터로 오르는 속성 점수 (기록 counters 'el:fire' 에 10배로 적는다)
  Map<String, int> _elementCounters(List<MonsterId> monsters) {
    final out = <String, int>{};
    final weapon = gear.attackElement;
    for (final m in monsters) {
      ElementRules.huntScore(Monsters.info(m).element, weapon).forEach((e, v) {
        out['el:${e.name}'] = (out['el:${e.name}'] ?? 0) + (v * 10).round();
      });
    }
    return out;
  }

  /// 속성 점수 (화면에 숫자로 보여 주지 않는다)
  Map<Element, double> get elementScores => ElementRules.scoresFrom(_history);

  /// 주 속성 (점수 1위, 30점부터)
  Element? get mainElement => ElementRules.mainOf(elementScores);

  // ───────────────────────────────────────────── 마법 돋보기 「감정」 (11-11 #60)

  static const _lensKey = 'lens';
  LensState _lens = const LensState();

  LensState get lens => _lens;

  /// 도감 「종족」에 남은 종족
  Set<Race> get racesSeen => {
        for (final n in _lens.seen)
          if (LensRules.parse(n) case final r?) r,
      };

  /// 오늘 보상을 더 받을 수 있는 감정 횟수
  int get lensRewardsLeft {
    final day = DailyRecord.dayKeyOf(_clock());
    final used = _lens.day == day ? _lens.rewardedToday : 0;
    return math.max(0, LensRules.rewardedPerDay - used);
  }

  /// 감정을 끝낸다: 마법 돋보기 1개를 쓰고 보상을 준다. 돋보기가 없으면 null.
  /// 처음 본 종족은 도감에 남고 경험치 +20, 하루 3번까지 30% 재료·5% 레시피 쪽지.
  Future<AppraiseResult?> appraise(List<Race> races) async {
    if (races.isEmpty || bagCount(ShopItem.raceLens) <= 0) return null;
    final today = await _todayRecord();
    final firsts = <Race>[
      for (final r in {...races})
        if (!_lens.seen.contains(r.name)) r,
    ];
    final exp = firsts.length * LensRules.firstExp;
    final rewarded = lensRewardsLeft > 0;
    MaterialId? mat;
    var note = false;
    if (rewarded) {
      if (_random.nextDouble() < LensRules.materialChance) {
        mat = LensRules.info(races[_random.nextInt(races.length)]).material;
      }
      note = _random.nextDouble() < LensRules.noteChance;
    }
    await _save(today.copyWith(
      itemsUsed: [...today.itemsUsed, ShopItem.raceLens.name],
      gains: exp > 0
          ? DailyRecord.addCounts(today.gains, {Wallet.exp: exp})
          : today.gains,
    ));
    final day = today.dayKey;
    final now = _clock();
    final photo = AlbumPhoto(
      id: 'p${now.microsecondsSinceEpoch}',
      races: [for (final r in races) r.name],
      at: now,
      firsts: [for (final r in firsts) r.name],
    );
    _lens = _lens.copyWith(
      album: [..._lens.album, photo],
      seen: [..._lens.seen, for (final r in firsts) r.name],
      counts: {
        ..._lens.counts,
        for (final r in {...races})
          r.name: (_lens.counts[r.name] ?? 0) +
              races.where((x) => x == r).length,
      },
      day: day,
      rewardedToday:
          (_lens.day == day ? _lens.rewardedToday : 0) + (rewarded ? 1 : 0),
    );
    await store.saveJson(_lensKey, _lens.toJson());
    if (mat != null) await _grant(0, 0, {mat: 1});
    if (note) await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + 1));
    notifyListeners();
    return AppraiseResult(
        races: races,
        firsts: firsts,
        exp: exp,
        material: mat,
        note: note,
        albumId: photo.id);
  }

  /// 감정 앨범 (11-11 #97)
  List<AlbumPhoto> get album => _lens.album;

  /// 앨범 사진에 찍은 사진 파일을 붙인다
  Future<void> attachAlbumFile(String id, String file) async {
    _lens = _lens.copyWith(album: [
      for (final p in _lens.album) p.id == id ? p.withFile(file) : p,
    ]);
    await store.saveJson(_lensKey, _lens.toJson());
    notifyListeners();
  }

  /// 앨범에서 지운다 (지운 사진의 파일 이름, 없으면 null). 감정한 종족 기록은 그대로.
  Future<String?> deleteAlbumPhoto(String id) async {
    String? file;
    for (final p in _lens.album) {
      if (p.id == id) file = p.file;
    }
    _lens = _lens.copyWith(album: [
      for (final p in _lens.album)
        if (p.id != id) p,
    ]);
    await store.saveJson(_lensKey, _lens.toJson());
    notifyListeners();
    return file;
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

  /// 첫 무기는 공짜 (묶음 16 #141): 새로 시작한 사람이 무기를 아직 안 가졌을 때 한 번
  bool get firstWeaponFree =>
      !_legacyGates &&
      featureOpen(Feature.smithy) &&
      !_introsSeen.contains('freeWeapon') &&
      !_armory.items.any(
          (i) => EquipmentRules.info(i.base).slot == EquipSlot.weapon);

  bool _isFreeCraft(EquipBase base, MaterialId? rare) =>
      rare == null &&
      firstWeaponFree &&
      EquipmentRules.info(base).slot == EquipSlot.weapon &&
      !EquipmentRules.isBossGear(base);

  /// 만들 수 있는지 (재료·마석). [rare] 는 더 넣을 귀한 재료.
  CraftCheck canCraft(EquipBase base, {MaterialId? rare}) {
    final info = EquipmentRules.info(base);
    final p = player;
    if (_isFreeCraft(base, rare)) {
      return bagFree <= 0 ? CraftCheck.bagFull : CraftCheck.ok;
    }
    for (final e in info.recipe.entries) {
      if (p.materialCount(e.key) < e.value) return CraftCheck.materials;
    }
    if (rare != null) {
      final need = (info.recipe[rare] ?? 0) + 1;
      if (p.materialCount(rare) < need) return CraftCheck.materials;
    }
    if (p.manaStones < info.manaStones) return CraftCheck.manaStones;
    if (bagFree <= 0) return CraftCheck.bagFull;
    return CraftCheck.ok;
  }

  /// 대장간에서 장비를 만든다. 만든 장비를 돌려준다 (못 만들면 null).
  Future<EquipItem?> craft(EquipBase base, {MaterialId? rare}) async {
    if (canCraft(base, rare: rare) != CraftCheck.ok) return null;
    final info = EquipmentRules.info(base);
    final free = _isFreeCraft(base, rare);
    final used = free
        ? <String, int>{}
        : <String, int>{
            for (final e in info.recipe.entries) e.key.name: e.value,
            if (rare != null) rare.name: (info.recipe[rare] ?? 0) + 1,
          };
    if (free) {
      _introsSeen = {..._introsSeen, 'freeWeapon'};
      await _saveGates();
    } else {
      final today = await _todayRecord();
      await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
          ...used,
          if (info.manaStones > 0) Wallet.manaStone: info.manaStones,
        }),
      ));
    }
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

  // ───────────── 보스 장비 만들기 (11-11 #82)

  /// 대장장이 직업 (#55 직업 각성 뒤 열림, 지금은 늘 false)
  bool get blacksmith => false;

  /// 이 세트의 보스를 잡아 봤는지 (못 잡은 보스의 세트는 그림자로 숨김)
  bool bossSetOpen(BossSet s) =>
      purifiedEver.contains(BossGearRules.info(s).boss);

  /// 이 부위를 이미 만든 적이 있는지 (가진 것 중에)
  bool hasBossPart(EquipBase base) => _armory.items.any((i) => i.base == base);

  CraftCheck canCraftBoss(EquipBase base) {
    final set = BossGearRules.setOf(base);
    if (set == null || !bossSetOpen(set)) return CraftCheck.materials;
    final info = BossGearRules.info(set);
    final c = BossGearRules.cost(EquipmentRules.info(base).slot,
        blacksmith: blacksmith);
    final p = player;
    if (p.materialCount(MaterialId.bossShard) < c.shards ||
        p.materialCount(info.material) < c.mats) {
      return CraftCheck.materials;
    }
    if (p.gold < c.gold) return CraftCheck.gold;
    if (bagFree <= 0) return CraftCheck.bagFull;
    return CraftCheck.ok;
  }

  /// 보스 장비를 만든다. 실패하면 금화 절반과 조각 일부를 잃고 전용 재료는 돌려받는다.
  /// 처음부터 그 보스 속성이 입혀져 있다 (일반 장비처럼 바꾸기·추출·강화 가능).
  Future<BossCraftResult?> craftBoss(EquipBase base) async {
    if (canCraftBoss(base) != CraftCheck.ok) return null;
    final set = BossGearRules.info(BossGearRules.setOf(base)!);
    final slot = EquipmentRules.info(base).slot;
    final c = BossGearRules.cost(slot, blacksmith: blacksmith);
    final failed = _random.nextDouble() < BossGearRules.failChance(blacksmith: blacksmith);
    final today = await _todayRecord();
    if (failed) {
      final loss = BossGearRules.failLoss(slot, blacksmith: blacksmith);
      await _save(today.copyWith(
        spends: DailyRecord.addCounts(today.spends, {
          MaterialId.bossShard.name: loss.shards,
          Wallet.gold: loss.gold,
        }),
      ));
      return BossCraftResult(
          line: BossGearRules.failLines[_random.nextInt(BossGearRules.failLines.length)]);
    }
    final used = <String, int>{
      MaterialId.bossShard.name: c.shards,
      set.material.name: c.mats,
    };
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {...used, Wallet.gold: c.gold}),
    ));
    final a = _armory;
    final grade = EquipmentRules.rollGrade(_random, rare: true, crafts: a.crafts);
    final item = EquipItem(
      uid: 'eq${a.nextId}',
      base: base,
      grade: grade,
      extras: EquipmentRules.rollExtras(grade, _random),
      materialsUsed: used,
      element: set.element,
    );
    await _saveArmory(a.copyWith(
      items: [...a.items, item],
      crafts: a.crafts + 1,
      nextId: a.nextId + 1,
    ));
    return BossCraftResult(item: item);
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

  /// 대장간 장비 속성 작업 (11-11 #74, NPC 도르군).
  /// 실패하면 금화만 잃고 빛나는 속성 코어는 돌려받는다. 장비와 원래 속성은 그대로.
  Future<SmithResult> smith(String uid, SmithAction act, {Element? to}) async {
    final item = _armory.byUid(uid);
    if (item == null) return SmithResult.cannot;
    final el = item.element;
    final coreEl = switch (act) {
      SmithAction.apply || SmithAction.change => to,
      SmithAction.extract || SmithAction.upgrade => el,
    };
    final ok = switch (act) {
      SmithAction.apply => el == null && to != null,
      SmithAction.change => el != null && to != null && to != el,
      SmithAction.extract => el != null,
      SmithAction.upgrade => el != null && item.elementLevel < SmithRules.maxLevel,
    };
    if (!ok || coreEl == null) return SmithResult.cannot;
    final core = EquipmentRules.imbueCore(coreEl);
    final gold = SmithRules.gold(act);
    final cores = SmithRules.cores(act);
    if (player.gold < gold || player.materialCount(core) < cores) {
      return SmithResult.cannot;
    }
    final failed = _random.nextDouble() <
        SmithRules.failChance(act, level: item.elementLevel);
    final today = await _todayRecord();
    await _save(today.copyWith(
      spends: DailyRecord.addCounts(today.spends, {
        Wallet.gold: gold,
        if (!failed && cores > 0) core.name: cores,
      }),
    ));
    if (failed) return SmithResult.failed;
    switch (act) {
      case SmithAction.apply:
        await _saveArmory(_armory.replace(item.copyWith(element: to, elementLevel: 0)));
      case SmithAction.change:
        await _saveArmory(_armory.replace(item.copyWith(element: to)));
      case SmithAction.extract:
        await _saveArmory(_armory.replace(item.copyWith(clearElement: true)));
        await _grant(0, 0, {core: 1});
      case SmithAction.upgrade:
        await _saveArmory(_armory.replace(
            item.copyWith(elementLevel: item.elementLevel + 1)));
    }
    return SmithResult.ok;
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

  /// 받을 수 있는 의뢰 보상 수 (묶음 16 #130 마을 탭 빨간 점)
  int get questRewardsReady {
    var n = 0;
    final b = board;
    for (var i = 0; i < b.slots.length; i++) {
      final s = b.slots[i];
      final t = BoardRules.template(s.templateId);
      if (t != null && s.accepted && errandProgress(i) >= t.target) n++;
    }
    final u = urgent;
    if (u != null &&
        b.urgentAccepted &&
        !b.urgentDone &&
        urgentProgress >= u.quest.target) {
      n++;
    }
    return n;
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
    await _maybeNote(AlchemyRules.noteFromErrand);
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
    await _maybeNote(AlchemyRules.noteFromErrand);
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
    final fit = _fitBag(materials);
    final today = await _todayRecord();
    await _save(today.copyWith(
      gains: DailyRecord.addCounts(
          today.gains,
          HuntReward.ledger(
              extraManaStones: manaStones,
              gold: gold + fit.gold,
              materials: fit.kept)),
    ));
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
  int get mpMax =>
      StatRules.maxMp(combatStats + gear.stats) +
      PetRules.mpMaxBonus(_pets.pets.length);

  /// 시간당 MP 회복 (두 번째 펫부터 +2, 11-11 #38)
  int get mpRegenPerHour =>
      RuleConstants.mpRegenPerHour + PetRules.mpRegenBonus(_pets.pets.length);

  /// 여관에서 쉬는 중이면 체크인 시각
  DateTime? get restStartedAt => _vitals.restStartedAt;
  bool get resting => _vitals.restStartedAt != null;

  /// 휴식이 얼마나 지났는지 (0 → 1)
  double get restProgress => resting
      ? TownRules.restProgress(_vitals.restStartedAt!, _clock())
      : 0;

  /// 휴식이 끝나기까지 남은 시간
  Duration get restLeft => resting
      ? TownRules.restLeft(_vitals.restStartedAt!, _clock())
      : Duration.zero;

  /// 진행 중이거나 결과를 아직 보지 않은 원정 (펫마다 하나, 11-11 #38)
  List<Expedition> get expeditions => _vitals.expeditions;

  /// 데리고 다니는 동료(정령 또는 동행 펫)의 원정
  Expedition? get expedition {
    final uid = farewellDone ? companionPet?.uid : null;
    for (final e in _vitals.expeditions) {
      if (e.petUid == uid) return e;
    }
    return null;
  }

  /// 아직 돌아오지 않은 원정
  List<Expedition> get activeExpeditions =>
      [for (final e in _vitals.expeditions) if (!e.finished) e];

  /// 돌아와서 결과를 기다리는 원정 (여러 개가 한꺼번에 끝날 수 있다)
  List<Expedition> get finishedExpeditions =>
      [for (final e in _vitals.expeditions) if (e.finished) e];

  /// 원정 중인 펫 uid (정령은 null)
  bool isAway(String? petUid) =>
      _vitals.expeditions.any((e) => e.petUid == petUid);

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
    } catch (e, st) {
      // 묶음 16 #124: 시간에 따른 갱신이 실패해도 앱은 계속 (오류만 남긴다)
      await _logStartError(e, st);
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
        VitalRules.regenMp(v.mp ?? mpMax, v.mpAt ?? now, now,
            max: mpMax, perHour: mpRegenPerHour);
    if (newMp != v.mp || newAt != v.mpAt) {
      v = v.copyWith(mp: newMp, mpAt: newAt);
      changed = true;
    }

    // 쉬는 동안: 시작할 때 HP·MP에서 가득까지 시간에 맞춰 고르게 (묶음 15 #107)
    final restAt = v.restStartedAt;
    if (restAt != null && !TownRules.restDone(restAt, now)) {
      final f = TownRules.restProgress(restAt, now);
      final hp0 = v.restHp0 ?? curHp;
      final mp0 = v.restMp0 ?? (v.mp ?? mpMax);
      final hpNow = math.max(curHp, TownRules.restFill(hp0, max, f));
      final mpNow = math.max(v.mp ?? mpMax, TownRules.restFill(mp0, mpMax, f));
      if (hpNow != curHp ||
          mpNow != (v.mp ?? mpMax) ||
          v.restHp0 == null ||
          v.restMp0 == null) {
        curHp = hpNow;
        v = v.copyWith(
            hp: hpNow, mp: mpNow, mpAt: now, restHp0: hp0, restMp0: mp0);
        changed = true;
      }
    }

    // 여관 휴식이 끝났으면 HP·MP를 모두 채우고 기록한다
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

    // 돌아온 원정 마무리 (여러 마리가 한꺼번에 돌아올 수 있다)
    for (final ex in [...v.expeditions]) {
      if (!ex.finished && !now.isBefore(ex.returnAt)) {
        await _resolveExpedition(ex);
      }
    }
    await _mailExpiredBoard();
    await _checkLetters();
    await _checkMail();
    await _petSteps();
    await _checkBoardEggs();
    await _checkWalkEvents();
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
    _vitals = _vitals.copyWith(
        restStartedAt: now, restHp0: hp, restMp0: mp);
    await store.saveVitals(_vitals);
    // 여관에 들르면 지친 상태가 바로 풀린다 (11-11 #75)
    if (_tiredUntil != null) await _setTired(null);
    unawaited(notifier?.schedule(
      NotifyId.rest,
      now.add(const Duration(hours: RuleConstants.restHours)),
      '푹 쉬었어요',
      'HP와 $companionName의 MP가 가득 찼어요. 앱을 열어 휴식 보너스를 받으세요!',
    ));
    notifyListeners();
    return true;
  }

  /// 휴식을 그만둔다 (보상 없이). 그때까지 찬 HP·MP는 그대로 (묶음 15 #107)
  Future<void> stopResting() async {
    if (!resting) return;
    await refreshVitals();
    if (!resting) return;
    _stopResting();
    await store.saveVitals(_vitals);
    notifyListeners();
  }

  // ───────────── 전투 손맛 설정 (11-11 #75): 진동 · 효과음 · 2배속 · 첫 중독 안내

  static const _feelKey = 'feel';
  bool _vibrate = true;
  bool _sound = true;
  bool _fastBattle = false;
  bool _poisonTipSeen = false;
  bool _petCodexSeen = false;
  bool _petCodexAnnounced = false;

  /// 도감 펫 탭이 열렸는지 (묶음 15 #116): 정령과 이별한 뒤(알 부화가 가능해진 뒤)에만.
  /// 그 전에는 알이 있어도 숨긴다 (펫이 드러나지 않게)
  bool get petCodexOpen => _pets.farewellDone;

  /// 펫 탭에 새 표시 (아직 열어 보지 않았으면)
  bool get petCodexNew => petCodexOpen && !_petCodexSeen;

  /// 「새 도감이 열렸어요」를 아직 알리지 않았으면 true
  bool get petCodexToAnnounce => petCodexOpen && !_petCodexAnnounced;

  Future<void> markPetCodexSeen() async {
    if (_petCodexSeen) return;
    _petCodexSeen = true;
    await _saveFeel();
  }

  Future<void> markPetCodexAnnounced() async {
    if (_petCodexAnnounced) return;
    _petCodexAnnounced = true;
    await _saveFeel();
  }

  bool get vibrate => _vibrate;
  bool get sound => _sound;
  bool get fastBattle => _fastBattle;

  /// 처음 중독됐을 때 해독제 안내를 이미 보여 줬는지
  bool get poisonTipSeen => _poisonTipSeen;

  Future<void> _saveFeel() async {
    await store.saveJson(_feelKey, {
      'vibrate': _vibrate,
      'sound': _sound,
      'fast': _fastBattle,
      'poisonTip': _poisonTipSeen,
      'petCodex': _petCodexSeen,
      'petCodexNotice': _petCodexAnnounced,
      'adPersonal': _adPersonal,
    });
    notifyListeners();
  }

  /// 맞춤형 광고 허용 (묶음 15 #103). null = 아직 묻지 않음 → 처음 광고 볼 때 묻는다
  bool? _adPersonal;
  bool? get adPersonal => _adPersonal;

  Future<void> setAdPersonal(bool on) async {
    _adPersonal = on;
    await _saveFeel();
    notifyListeners();
  }

  Future<void> setVibrate(bool on) async {
    _vibrate = on;
    await _saveFeel();
  }

  Future<void> setSound(bool on) async {
    _sound = on;
    await _saveFeel();
  }

  Future<void> setFastBattle(bool on) async {
    _fastBattle = on;
    await _saveFeel();
  }

  Future<void> markPoisonTipSeen() async {
    if (_poisonTipSeen) return;
    _poisonTipSeen = true;
    await _saveFeel();
  }

  // ───────────── 패배의 벌 · 지친 상태 (11-11 #75)

  static const _tiredKey = 'tired';
  DateTime? _tiredUntil;

  /// 지친 상태인지 (패배 뒤 1시간, 여관에 들르면 풀림). 경험치·마석이 줄어드는 정도는 숨김.
  bool get tired => _tiredUntil != null && _clock().isBefore(_tiredUntil!);

  /// 지친 상태가 풀리는 때
  DateTime? get tiredUntil => tired ? _tiredUntil : null;

  /// 정령(펫)의 한마디
  static const tiredLine = '오늘은 좀 쉬어야겠어. 여관에 들르자.';

  int _tiredCut(int v) => (v * RuleConstants.tiredRewardMultiplier).round();

  Future<void> _setTired(DateTime? until) async {
    _tiredUntil = until;
    await store.saveJson(
        _tiredKey, {if (until != null) 'until': until.toIso8601String()});
  }

  /// 졌을 때: 입은 장비 내구도가 더 깎이고, 1시간 지친다 (겹치지 않고 시간만 다시).
  /// 금화·아이템은 잃지 않는다.
  Future<void> _defeated() async {
    await _wear(RuleConstants.defeatExtraWear);
    await _setTired(_clock().add(RuleConstants.tiredFor));
  }

  void _stopResting() {
    final restAt = _vitals.restStartedAt;
    if (restAt != null) {
      // 그때까지 찬 만큼은 그대로 가지고 간다 (묶음 15 #107)
      final f = TownRules.restProgress(restAt, _clock());
      final hp0 = _vitals.restHp0 ?? hp;
      final mp0 = _vitals.restMp0 ?? mp;
      _vitals = _vitals.copyWith(
          hp: math.max(hp, TownRules.restFill(hp0, maxHp, f)),
          mp: math.max(mp, TownRules.restFill(mp0, mpMax, f)),
          mpAt: _clock());
      _vitals = _vitals.copyWith(clearRest: true);
      unawaited(store.saveVitals(_vitals));
      unawaited(notifier?.cancel(NotifyId.rest));
    }
  }

  // ───────────── 정령 원정

  final _routes = <String, ExpeditionRoute>{};
  final _routeJobs = <String, Future<ExpeditionRoute>>{};

  String? _routeKey(FieldSpawn spawn) {
    final from = _lastFix?.point;
    if (from == null) return null;
    // 50m 안에서 움직인 것은 같은 출발점으로 본다
    return '${spawn.id}@${(from.lat / 0.0005).round()},${(from.lng / 0.0005).round()}';
  }

  /// 찾아 둔 원정 길 (아직 찾는 중이거나 위치를 모르면 null)
  ExpeditionRoute? routeFor(FieldSpawn spawn) {
    final k = _routeKey(spawn);
    return k == null ? null : _routes[k];
  }

  /// 원정 길을 찾는다. 길 조각을 받지 못했거나, 길이 이어지지 않거나,
  /// 직선의 3배를 넘으면 직선.
  Future<ExpeditionRoute> prepareRoute(FieldSpawn spawn) {
    final k = _routeKey(spawn);
    final from = _lastFix?.point;
    if (k == null || from == null) {
      return Future.value(ExpeditionRoute.straight(
          from ?? spawn.point, spawn.point));
    }
    if (_routes[k] case final r?) return Future.value(r);
    return _routeJobs[k] ??= () async {
      final to = spawn.point;
      final straight = from.distanceTo(to);
      ExpeditionRoute route;
      try {
        final keys = RouteGrid.tilesAround(from, to,
            marginM: math.min(1500.0, math.max(300.0, straight)));
        final loaded = await Future.wait([
          for (final key in keys)
            routeTiles.load(key).then((v) => MapEntry(key, v)),
        ]).timeout(const Duration(seconds: 15));
        final grid = RouteGrid({
          for (final e in loaded)
            if (e.value case final v?) e.key: v,
        });
        route = grid.tiles.isEmpty
            ? ExpeditionRoute.straight(from, to)
            : RouteFinder.find(grid, from, to);
      } catch (_) {
        route = ExpeditionRoute.straight(from, to);
      }
      _routes[k] = route;
      _routeJobs.remove(k);
      notifyListeners();
      return route;
    }();
  }

  /// 원정을 보낼 수 있는 펫 (정령이 떠나기 전에는 비어 있다: 정령이 간다)
  List<Pet> get idlePets => [
        for (final p in _pets.pets)
          if (!isAway(p.uid)) p,
      ];

  /// 길에서 멀리 떨어진 물가 몬스터인지 (두꺼비 특기)
  bool _waterside(ExpeditionRoute? route) {
    if (route == null || !route.followsRoads || route.points.length < 3) {
      return false;
    }
    final pts = route.points;
    return pts[pts.length - 2].distanceTo(pts.last) > PetRules.watersideM;
  }

  /// [spawn] 으로 원정을 보낼 수 있는지 (거리·MP·시간 포함).
  /// 길을 찾아 두었으면 길 거리로, 아니면 직선 거리로 계산한다.
  /// [petUid] 는 보낼 펫 (정령이 떠난 뒤, 없으면 동행 펫).
  ExpeditionPlan planExpedition(FieldSpawn spawn, {String? petUid}) {
    // 튜토리얼 원정: 짧게, MP 걱정 없이 (묶음 15 #104)
    if (isTutorialSpawn(spawn.id)) {
      return ExpeditionPlan(
          activeExpeditions.any((e) => e.spawnId == spawn.id)
              ? ExpeditionCheck.busy
              : ExpeditionCheck.ok,
          distanceM: 250,
          mpCost: 0,
          oneWay: const Duration(seconds: 10),
          followsRoads: false,
          routeReady: true);
    }
    final from = _lastFix?.point;
    if (from == null) return const ExpeditionPlan(ExpeditionCheck.needsLocation);
    final pet = farewellDone
        ? (petUid == null ? companionPet : _pets.byUid(petUid))
        : null;
    final route = routeFor(spawn);
    final dist = route?.lengthM ?? from.distanceTo(spawn.point);
    final water = _waterside(route);
    var cost = VitalRules.expeditionCost(dist);
    var base = VitalRules.expeditionOneWay(dist);
    if (pet != null) {
      cost = math.max(
          1,
          (cost *
                  PetRules.mpFactor(pet.species,
                      adult: pet.adult, bond: pet.bond, waterside: water))
              .round());
      final t = PetRules.travelTimeFactor(pet.species,
              adult: pet.adult, bond: pet.bond) *
          PetRules.waterTimeFactor(pet.species,
              adult: pet.adult, bond: pet.bond, waterside: water);
      base = Duration(seconds: (base.inSeconds * t).round());
    }
    // 원정 나침반을 써 두었으면 이동 시간 절반
    final oneWay = _vitals.compassReady ? base ~/ 2 : base;
    ExpeditionCheck check;
    if (farewellDone && pet == null) {
      check = ExpeditionCheck.busy;
    } else if (isAway(pet?.uid)) {
      check = ExpeditionCheck.busy;
    } else if (activeExpeditions.any((e) => e.spawnId == spawn.id)) {
      check = ExpeditionCheck.busy;
    } else if (mp < cost) {
      // 안개 대신 MP로만 거리를 막는다 (11-10, 최대 MP 60 = 약 3km)
      check = ExpeditionCheck.notEnoughMp;
    } else {
      check = ExpeditionCheck.ok;
    }
    return ExpeditionPlan(check,
        distanceM: dist,
        mpCost: cost,
        oneWay: oneWay,
        followsRoads: route?.followsRoads ?? false,
        routeReady: route != null,
        petUid: pet?.uid);
  }

  /// 정령(또는 펫)을 보낸다. MP는 보내는 순간 쓴다.
  Future<ExpeditionCheck> sendSpirit(FieldSpawn spawn, {String? petUid}) async {
    await refreshVitals();
    final route = isTutorialSpawn(spawn.id)
        ? ExpeditionRoute.straight(_lastFix?.point ?? spawn.point, spawn.point)
        : await prepareRoute(spawn);
    final plan = planExpedition(spawn, petUid: petUid);
    if (plan.check != ExpeditionCheck.ok) return plan.check;
    final pet = plan.petUid == null ? null : _pets.byUid(plan.petUid!);
    final now = _clock();
    // 승객 모드에서 보낸 원정은 보상 절반 (11-11 #61)
    if (passengerMode) {
      await _saveDrive(_drive.copyWith(
          passengerSpawns: [..._drive.passengerSpawns, spawn.id]));
    }
    final arrive = now.add(plan.oneWay);
    final ex = Expedition(
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
      route: route.followsRoads
          ? [for (final p in route.points) (p.lat, p.lng)]
          : const [],
      petUid: pet?.uid,
      petName: pet?.name,
    );
    _vitals = _vitals.copyWith(
      mp: mp - plan.mpCost,
      mpAt: mp >= mpMax ? now : _vitals.mpAt,
      expeditions: [..._vitals.expeditions, ex],
      compassReady: false, // 나침반은 한 번 쓰면 끝
    );
    await store.saveVitals(_vitals);
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters, {'expedition': 1})));
    final who = pet?.name ?? _profile.spiritName;
    unawaited(notifier?.schedule(
      _notifyIdFor(pet?.uid),
      ex.returnAt,
      '${josa(who, '이/가')} 돌아왔어요',
      '${spawn.info.name} 원정 결과를 확인해 보세요!',
    ));
    notifyListeners();
    return ExpeditionCheck.ok;
  }

  /// 원정 알림 id: 정령은 원래 id, 펫은 펫마다
  int _notifyIdFor(String? petUid) {
    if (petUid == null) return NotifyId.expedition;
    final i = _pets.pets.indexWhere((p) => p.uid == petUid);
    return 100 + (i < 0 ? 0 : i);
  }

  /// 원정 결과를 확인했을 때 (결과 카드를 닫으면). [ex] 가 없으면 끝난 원정 모두.
  Future<void> acknowledgeExpedition([Expedition? ex]) async {
    bool drop(Expedition e) =>
        e.finished &&
        (ex == null || (e.spawnId == ex.spawnId && e.petUid == ex.petUid));
    final keep = [
      for (final e in _vitals.expeditions)
        if (!drop(e)) e,
    ];
    if (keep.length == _vitals.expeditions.length) return;
    _vitals = _vitals.copyWith(expeditions: keep);
    await store.saveVitals(_vitals);
    notifyListeners();
  }

  /// 원정 경험치 (결과 카드에 보여 준다)
  int _lastExpeditionExp = 0;
  int get lastExpeditionExp => _lastExpeditionExp;

  /// 돌아온 정령의 전투 결과를 정한다. 정령은 각성자의 전투력으로 싸우고
  /// 각성자의 HP는 쓰지 않는다. 지면 MP만 잃고, 몬스터는 그대로 남는다.
  Future<void> _resolveExpedition(Expedition ex) async {
    _resolving = true;
    try {
      await _resolveExpeditionInner(ex);
    } finally {
      _resolving = false;
    }
  }

  Future<void> _resolveExpeditionInner(Expedition ex) async {
    final monster = Monsters.byName(ex.monster) ?? MonsterId.ashSlime;
    final mods = [
      for (final n in ex.mods)
        if (ModifierRules.byName(n) case final m?) m,
    ];
    final p = player;
    final pet = ex.petUid == null ? null : _pets.byUid(ex.petUid!);
    final power = pet == null
        ? 1.0
        : PetRules.powerFactor(pet.species,
            adult: pet.adult,
            bond: pet.bond,
            night: FieldMonsterRules.isNight(ex.arriveAt));
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
      power: power,
      petSkill: pet?.info.skill,
      petAdult: pet?.adult ?? false,
      potions: battlePotions,
      autoHp: _alc.autoHp,
      autoCure: _alc.autoCure,
      resist: activeResists,
      skillElement: pet?.element,
      mainElement: mainElement,
      weaponPotion: weaponPotionElement,
    ).runToEnd(useSkills: true);
    await _consumeBattlePotions(battle);
    // 튜토리얼 원정은 실패하지 않는다
    final cleared =
        battle.phase == BattlePhase.cleared || isTutorialSpawn(ex.spawnId);
    final escaped =
        battle.phase == BattlePhase.escaped && !isTutorialSpawn(ex.spawnId);
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
    var r = _lastReward;
    final base = r; // 광고 두 배는 기본 보상만 (펫이 더 가져온 것 제외)
    if (cleared && pet != null) {
      // 호문쿨루스: 재료를 더 가져온다
      final extra = PetRules.extraMaterials(pet.species, _random,
          adult: pet.adult, bond: pet.bond);
      if (extra > 0 && r.exp > 0) {
        final more = <MaterialId, int>{};
        for (var i = 0; i < extra; i++) {
          LootRules.field(monster, _random, early: earlyLoot)
              .forEach((k, v) => more[k] = (more[k] ?? 0) + v);
        }
        await _grant(0, 0, more);
        final mats = {...r.materials};
        more.forEach((k, v) => mats[k] = (mats[k] ?? 0) + v);
        r = HuntReward(
            exp: r.exp, manaStones: r.manaStones, gold: r.gold, materials: mats);
      }
      await _givePetExp(pet.uid, PetRules.expPerExpedition);
    }
    final done = ex.withResult(cleared,
            escaped: escaped,
            newSpecies: cleared && isNew,
            reward: cleared
                ? {
                    if (r.exp > 0) 'exp': r.exp,
                    if (r.manaStones > 0) Wallet.manaStone: r.manaStones,
                    if (r.gold > 0) Wallet.gold: r.gold,
                    for (final e in r.materials.entries) e.key.name: e.value,
                  }
                : const {},
            baseReward: cleared
                ? {
                    if (base.exp > 0) 'exp': base.exp,
                    if (base.manaStones > 0) Wallet.manaStone: base.manaStones,
                    if (base.gold > 0) Wallet.gold: base.gold,
                    for (final e in base.materials.entries) e.key.name: e.value,
                  }
                : const {});
    _vitals = _vitals.copyWith(expeditions: [
      for (final e in _vitals.expeditions)
        e.spawnId == ex.spawnId && e.petUid == ex.petUid ? done : e,
    ]);
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
    var out = record.copyWith(
        steps: steps, stepsAfter8pm: after8, stepsMorning: morning);
    // 걸음 물약 (11-11 #74): 마신 뒤 걸은 걸음의 절반만큼 게이지가 더 찬다
    for (final b in _alc.buffs) {
      if (b.key != PotionId.steps.name || b.day != record.dayKey) continue;
      final walked = (steps - (b.stepsFrom ?? steps)).clamp(0, b.stepsCap ?? 0);
      final bonus = b.amount + (walked * AlchemyRules.stepBoost).round();
      if (bonus > TownRules.gaugeBonusOn(out)) {
        out = out.copyWith(counters: {...out.counters, 'gaugeBonus': bonus});
      }
    }
    return out;
  }
}

/// 대장간 속성 작업 결과 (11-11 #74)
enum SmithResult { ok, failed, cannot }

/// 대장간에서 만들거나 강화할 수 있는지
enum CraftCheck { ok, materials, manaStones, gold, maxed, bagFull }

/// 보스 장비 만들기 결과 (실패면 item 이 null 이고 line 이 대장장이의 말)
class BossCraftResult {
  const BossCraftResult({this.item, this.line});
  final EquipItem? item;
  final String? line;
  bool get ok => item != null;
}

/// 가마솥에서 꺼낸 것
class BrewResult {
  const BrewResult(
      {this.potion,
      this.perfect = false,
      this.quality = PotionQuality.normal,
      this.suspicious,
      this.count = 1,
      this.discovered = false});

  final PotionId? potion;
  final bool perfect;

  /// 품질 (11-11 #74)
  final PotionQuality quality;

  /// 수상한 물약 키 (맞지 않는 조합)
  final String? suspicious;
  final int count;

  /// 이번에 처음 만든 물약 (레시피 책에 올랐다)
  final bool discovered;
}

/// 정령 원정을 보낼 수 있는지
enum ExpeditionCheck { ok, needsLocation, notEnoughMp, busy }

/// Lv.1~2 튜토리얼 단계 (묶음 15 #104). 저장 값 순서이므로 바꾸지 않는다.
/// done: 끝났거나 기존 사용자 · hunt: 바로 옆 몬스터와 첫 전투 ·
/// bag: 결과·가방 보기 · expedition: 정령 원정으로 두 번째 몬스터
/// 저장값은 순서 번호라 새 단계는 끝에 붙인다
enum TutorialStep { done, hunt, bag, expedition, intro }

/// 레벨에 따라 여는 기능 (묶음 16)
enum Feature { smithy, board, harvest, lens }

class ExpeditionPlan {
  const ExpeditionPlan(
    this.check, {
    this.distanceM = 0,
    this.mpCost = 0,
    this.oneWay = Duration.zero,
    this.followsRoads = false,
    this.routeReady = true,
    this.petUid,
  });

  /// 보낼 펫 (정령이면 null)
  final String? petUid;

  final ExpeditionCheck check;

  /// 길을 따라가는지 (아니면 직선으로 날아간다)
  final bool followsRoads;

  /// 길찾기가 끝났는지 (끝나기 전에는 직선 거리로 미리 보여 준다)
  final bool routeReady;
  final double distanceM;
  final int mpCost;

  /// 한쪽 길 시간 (돌아오기까지는 두 배)
  final Duration oneWay;
}

/// 감정 결과
class AppraiseResult {
  const AppraiseResult({
    required this.races,
    this.firsts = const [],
    this.exp = 0,
    this.material,
    this.note = false,
    this.albumId,
  });

  final List<Race> races;

  /// 앨범에 남은 사진 id (11-11 #97)
  final String? albumId;

  /// 처음 감정한 종족 (도감에 새로 남음)
  final List<Race> firsts;
  final int exp;
  final MaterialId? material;
  final bool note;
}

/// 원정 MP를 채울 마나 물약 하나 (11-11 #64)
class ManaOption {
  const ManaOption({
    required this.name,
    required this.count,
    required this.perBottle,
    required this.bottles,
    this.item,
    this.key,
  });

  final String name;

  /// 가방에 있는 수
  final int count;

  /// 한 병에 차는 MP
  final int perBottle;

  /// 모자란 MP를 채우려면 마셔야 하는 병 수
  final int bottles;

  /// 잡화상 물약 (또는 공방 물약 [key])
  final ShopItem? item;
  final String? key;
}

/// 채집할 수 있는지 (11-11 #56)
enum HarvestCheck { ok, far, empty, moving, noTool, passenger }
