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

part 'controller/ads.dart';
part 'controller/alchemy.dart';
part 'controller/battle.dart';
part 'controller/board.dart';
part 'controller/drive.dart';
part 'controller/expedition.dart';
part 'controller/explore.dart';
part 'controller/gather.dart';
part 'controller/harvest.dart';
part 'controller/lens.dart';
part 'controller/mail.dart';
part 'controller/pets.dart';
part 'controller/settings.dart';
part 'controller/shop_bag.dart';
part 'controller/smithy.dart';
part 'controller/stats.dart';
part 'controller/tutorial.dart';
part 'controller/vitals.dart';

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
  /// 묶음 20 #160: 튜토리얼 중에도 모아 두었다가 끝난 뒤 #131 순서로
  bool get holdNotices => _holdNotices > 0 || inTutorial;
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

  // ───────────────────────────────────────────── 설정

  /// 이름 바꾸기 가격 (11-11 #53): 처음 1번 무료, 그다음 금화 300
  static const int renameGold = 300;

  // ───────────────────────────────────────────── 탐험

  /// 위치 권한을 물어봤는지 (묶음 18 #148)
  bool _locationAsked = false;

  HuntReward _lastReward = const HuntReward();

  // ───────────── Lv.3~6 기능 안내 (묶음 19 #4-2)

  static const guideHuntId = 'guide-hunt';
  bool _guideHunt = false;

  // ───────────── 튜토리얼 (묶음 15 #104, Lv.1~2)

  static const _tutorialKey = 'tutorial';

  /// 방금 각성했는지 (연출은 이때만 보여 준다)
  bool _justAwakened = false;
  int _tutorial = 0;

  static const tutorialHuntId = 'tutorial-1';
  static const tutorialExpeditionId = 'tutorial-2';
  static bool isTutorialSpawn(String id) => id.startsWith('tutorial-');

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

  /// 채집 안내 중이면 바로 옆에 꽃 자리 하나 (#143)
  bool _harvestTutorial = false;

  /// 원정 결과를 정하는 중 (동행 펫 사냥 경험치를 주지 않는다)
  bool _resolving = false;

  // ───────────────────────────────────────────── 가방 칸 (11-11 #48)

  static const _bagKey = 'bag';
  BagState _bag = const BagState();

  // ───────────── 보상형 광고 (묶음 15 #103). 숫자 규칙은 화면에 보이지 않는다

  /// 광고를 끝까지 보면 true. 앱이 채워 넣는다 (테스트·광고 없는 빌드는 null)
  Future<bool> Function(String placement)? watchAd;

  int _bagOverflow = 0;

  // ───────────────────────────────────────────── 스탯 5종 (11-11 #50)

  static const _statsKey = 'stats';
  StatAlloc _alloc = const StatAlloc();

  static const _lifeLines = {
    StatKind.strength: '요즘 힘이 불끈불끈 솟는 것 같지 않아?',
    StatKind.agility: '어? 왠지 몸이 가벼워진 것 같아!',
    StatKind.intellect: '머리가 맑아진 느낌이야. 뭔가 더 잘 보여!',
    StatKind.vitality: '숨이 덜 차는 것 같아. 튼튼해졌나 봐!',
    StatKind.luck: '오늘따라 운이 좋은 것 같아!',
  };

  String? _shownLifeLine;


  // ───────────────────────────────────────────── 정령 이별 · 펫 (11-11 #37·#38)

  static const _petsKey = 'pets';
  PetState _pets = const PetState();

  bool _newEgg = false;

  LetterInfo? _newLetter;


  // ───────────────────────────────────────────── 연금술 공방 (11-11 #57·#58)

  static const _alchemyKey = 'alchemy';
  AlchemyState _alc = const AlchemyState();

  final _consumed = Expando<bool>();

  /// 공방 물약을 전투 밖에서 마신다. 못 마시면 이유.
  ///
  /// 11-11 #74: 전투·속성·탐험 물약은 종류마다 하나씩 걸린다. 같은 종류를 또
  /// 마시면 새 물약으로 바뀐다. 회복·마나는 바로 듣는다.
  /// 마신 뒤 덧붙여 알려 줄 말 (예: 유인 물약을 같은 날 또 마셨을 때)
  String? drinkNote;


  // ───────────────────────────────────────────── 걸음 주머니 · 길가 · 상인 (11-11 #59)

  static const _gatherKey = 'gather';
  GatherState _gather = const GatherState();

  /// 걸음 주머니·길가의 발견·떠돌이 상인을 만들지 (예시 모드는 끔)
  bool walkEvents = true;

  bool _newPouch = false;

  static GeoPoint _merchantSpot(GeoPoint from, double meters, double angle) {
    const mPerDegLat = 111320.0;
    final dLat = meters * math.cos(angle) / mPerDegLat;
    final dLng = meters *
        math.sin(angle) /
        (mPerDegLat * math.cos(from.lat * math.pi / 180));
    return GeoPoint(from.lat + dLat, from.lng + dLng);
  }

  // 지도에서 보여 달라는 자리 (위쪽 띠를 눌렀을 때, 11-11 #84)
  GeoPoint? _mapFocus;

  // ───────────────────────────────────────────── 우편 (11-11 #65)

  static const _mailKey = 'mail';
  MailState _mail = const MailState();

  /// 운영 우편을 가져오는 곳 (1차: 앱에 담은 목록, 2차: 서버)
  List<MailSource> mailSources = const [AssetMailSource()];

  // ───────────────────────────────────────────── 승객 확인 (11-11 #61)

  static const _driveKey = 'drive';
  DriveState _drive = const DriveState();

  DateTime? _fastSince;
  DateTime? _slowSince;

  /// 마지막으로 움직인 때 (채집 미니게임은 멈춰 있어야 한다)
  DateTime? _lastMovingAt;

  // ───────────────────────────────────────────── 채집 (11-11 #56)

  static const _harvestKey = 'harvest';
  HarvestState _harvest = const HarvestState();

  String? _spotsKey;
  List<HarvestSpot> _spotsCache = const [];

  String? _lastRelicLore;

  // ───────────────────────────────────────────── 마법 돋보기 「감정」 (11-11 #60)

  static const _lensKey = 'lens';
  LensState _lens = const LensState();

  // ───────────────────────────────────────────── 대장간 · 장비 (11-10 #27)

  static const _armoryKey = 'armory';
  Armory _armory = const Armory();

  // ───────────────────────────────────────────── 의뢰 게시판 (11-10 #26)

  static const _boardKey = 'board';
  BoardState _board = const BoardState();

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

  // ───────────────────────────────────────────── HP · 정령 MP · 여관 · 정령 원정

  Vitals _vitals = const Vitals();

  bool _refreshing = false;

  bool _justRested = false;

  // ───────────── 전투 손맛 설정 (11-11 #75): 진동 · 효과음 · 2배속 · 첫 중독 안내

  static const _feelKey = 'feel';
  bool _vibrate = true;
  bool _sound = true;
  bool _fastBattle = false;
  bool _poisonTipSeen = false;
  bool _petCodexSeen = false;
  bool _petCodexAnnounced = false;

  /// 맞춤형 광고 허용 (묶음 15 #103). null = 아직 묻지 않음 → 처음 광고 볼 때 묻는다
  bool? _adPersonal;

  // ───────────── 패배의 벌 · 지친 상태 (11-11 #75)

  static const _tiredKey = 'tired';
  DateTime? _tiredUntil;

  /// 정령(펫)의 한마디
  static const tiredLine = '오늘은 좀 쉬어야겠어. 여관에 들르자.';

  // ───────────── 정령 원정

  final _routes = <String, ExpeditionRoute>{};
  final _routeJobs = <String, Future<ExpeditionRoute>>{};

  /// 원정 경험치 (결과 카드에 보여 준다)
  int _lastExpeditionExp = 0;

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  /// 나눈 파일(lib/controller)에서 화면에 알릴 때
  void _notify() => notifyListeners();
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
