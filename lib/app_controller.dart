import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'app_config.dart';
import 'core/format.dart';
import 'core/geo/geo.dart';
import 'core/geo/route_grid.dart';
import 'core/models/act2_state.dart';
import 'core/models/alchemy_state.dart';
import 'core/models/armory.dart';
import 'core/models/bag_state.dart';
import 'core/models/board_state.dart';
import 'core/models/daily_record.dart';
import 'core/models/garden_state.dart';
import 'core/models/highland_state.dart';
import 'core/models/tavern_state.dart';
import 'core/models/building_state.dart';
import 'core/models/consent_state.dart';
import 'core/models/party_state.dart';
import 'core/models/act3_state.dart';
import 'core/models/act4_state.dart';
import 'core/models/act5_state.dart';
import 'core/models/gather_state.dart';
import 'core/models/drive_state.dart';
import 'core/models/harvest_state.dart';
import 'core/models/job_state.dart';
import 'core/models/lens_state.dart';
import 'core/models/mail_state.dart';
import 'core/models/mastery_state.dart';
import 'core/models/npc_state.dart';
import 'core/models/pet_state.dart';
import 'core/models/player_state.dart';
import 'core/models/stat_alloc.dart';
import 'core/models/training_state.dart';
import 'core/models/vitals.dart';
import 'core/rules/rules.dart';
import 'data/cloud/arca_api.dart';
import 'data/cloud/backup_scrub.dart';
import 'data/cloud/backup_server.dart';
import 'data/cloud/cloud_auth.dart';
import 'data/health/health_source.dart';
import 'data/location/location_source.dart';
import 'data/mail/mail_source.dart';
import 'data/notify/notifier.dart';
import 'data/route/route_tile_source.dart';
import 'data/storage/record_store.dart';
import 'features/bulssi/bulssi_lines.dart';
import 'features/bulssi/bulssi_mood.dart';
import 'features/map/ansan_area.dart';
import 'features/map/korea_area.dart';
import 'features/status/demo_data.dart';

part 'controller/act2.dart';
part 'controller/act3.dart';
part 'controller/act3_region.dart';
part 'controller/act3_regions.dart';
part 'controller/act4.dart';
part 'controller/act5.dart';
part 'controller/ads.dart';
part 'controller/alchemy.dart';
part 'controller/bag_hold.dart';
part 'controller/cloud.dart';
part 'controller/battle.dart';
part 'controller/board.dart';
part 'controller/inquiry.dart';
part 'controller/legal.dart';
part 'controller/party.dart';
part 'controller/buildings.dart';
part 'controller/drive.dart';
part 'controller/expedition.dart';
part 'controller/fair.dart';
part 'controller/explore.dart';
part 'controller/garden.dart';
part 'controller/gather.dart';
part 'controller/harvest.dart';
part 'controller/hero_pets.dart';
part 'controller/highland.dart';
part 'controller/jobs.dart';
part 'controller/jobs57.dart';
part 'controller/lens.dart';
part 'controller/mail.dart';
part 'controller/market.dart';
part 'controller/mastery.dart';
part 'controller/npc.dart';
part 'controller/npc_small.dart';
part 'controller/pets.dart';
part 'controller/settings.dart';
part 'controller/shop_bag.dart';
part 'controller/tavern.dart';
part 'controller/smithy.dart';
part 'controller/stats.dart';
part 'controller/training.dart';
part 'controller/tutorial.dart';
part 'controller/village.dart';
part 'controller/vitals.dart';
part 'controller/walk_rewards.dart';
part 'controller/estate_dev.dart';
part 'controller/chat.dart';

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
        json: {
          'pets': DemoData.pets(today: now).toJson(),
          // 예시 모드는 채집 도구를 이미 가졌다 (묶음 22)
          'harvest': {'granted': true},
          // 묶음 31: 예시 모드는 스킬 페이지 안내를 이미 본 것으로
          'jobs': {
            'v31': true,
            'pageOpen': true,
            'pageIntro': true,
            'masteryShown': {for (final m in Mastery.values) m.name: 4},
          },
          // 묶음 34: 예시 모드는 잿빛 틈 한마디를 이미 들은 것으로
          'act2': {'announced': 6},
          // 묶음 35: 예시 모드는 마을 소개·쉼터 카드를 본 것으로 (넓은 마을 미리 보기는 켬)
          'village': {
            'seen': ['intro', 'farewell', 'shelterCard', 'trainingCard', 'gardenCard'],
          },
        },
      ),
      health: FakeHealthSource(granted: false),
      stepGoal: 8000, // 예시 기록과 같은 목표
      clock: clock,
    )
      ..walkEvents = false // 예시 모드는 걸음 주머니·길가 알림을 띄우지 않는다
      ..villagePreviewWide = true // 묶음 35: 시설 12곳부터의 넓은 마을을 미리 보기
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

  /// 묶음 55 #245: 로그인 · 기록 백업 · 서버 시간 (Firebase 설정이 없는 빌드 · 테스트는 null)
  CloudAuth? cloudAuth;
  BackupServer? backupServer;
  ServerClock? serverClock;

  /// 묶음 56: 아르카 서버 (파티 · 문의). Firebase 설정이 없는 빌드 · 테스트는 null
  ArcaApi? arcaApi;

  /// 묶음 57: 처음 시작 · 바뀐 약관 동의 창을 띄울지 (앱은 켬, 시험은 필요할 때만)
  bool consentGate = false;

  /// 묶음 57: 방금 끝난 필드 전투 (전리품 하나 더 · 금화)
  Battle? _lootBattle;

  /// 묶음 57: 방금 잡은 몬스터가 그날 5번째 (한 번만 하는 한마디)
  bool _fifthLine = false;
  bool _wordsFetched = false;
  String? _pendingInvite;
  String? _pendingGuildInvite;
  int? _chestN;
  bool _chestTrap = false;
  ConsentState _consent = const ConsentState();
  PartyView? _partyView;
  PartyLocal _partyLocal = const PartyLocal();
  String? _partyError;
  bool _partyBusy = false;
  String? _partyNotice;

  /// 묶음 61 #250: 가짜 위치가 마지막으로 잡힌 때 · 띠를 보였는지 (이번 실행) · 최대 시간당 걸음 (잠깐 보관)
  DateTime? _mockAt;
  bool _mockBannerShown = false;
  bool _mockBannerPending = false;
  ({String day, DateTime at, int max})? _maxHourCache;

  /// 하루 기록에 남기는 「손으로 입력한 걸음」 (함께하는 기능에서만 뺌)
  static const manualStepsKey = 'manualSteps';
  DateTime? _partyPingAt;

  /// 서버 기록으로 바꾼 뒤 앱을 처음부터 다시 띄움 (main 이 정함, 없으면 그 자리에서 다시 읽음)
  Future<void> Function()? onRestored;
  CloudState _cloud = const CloudState();

  /// 묶음 53: 지금 하는 3막 싸움 · 주민 대화 횟수 (앱을 켠 동안)
  A3Enc? _a3Enc;
  final Map<String, int> _a3Talk = {};
  // 묶음 58: 거래소 · 심층 순위
  bool _marketBusy = false;
  String? _marketError;

  /// 묶음 65: 공성전 알림을 보인 것 (이 휴대폰만)
  // 묶음 68 #275: 대화 · 친구
  ChatMe? _chatMe;
  String? _chatError;
  String? _chatOpenRoom;
  String? _pendingFriendCode;
  final Map<String, List<ChatLine>> _chatLines = {};
  final Set<String> _chatMoreRooms = {};

  // 묶음 65 #255: 영지 관리
  EstateDevView? _estateDev;

  // 묶음 65 #252: 걸음 보상 한 줄 (잠깐만 보임)
  String? _walkLine;
  DateTime? _walkLineAt;

  final Set<String> _siegeSeen = {};
  bool _siegeSeenLoaded = false;

  /// 묶음 61: 거래 지갑 금화 (서버가 들고 있음, 마지막으로 받은 값)
  int? _walletGold;
  Region? _deepRegion;
  bool _cloudBusy = false;
  BackupInfo? _serverChoice;

  /// 앱을 새 기록으로 다시 띄울 때 예전 컨트롤러를 멈춘다 (위치 구독 끊기)
  void retire() {
    _locationSub?.cancel();
    _locationSub = null;
  }

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

  /// 시험·캡처용: 남녀 모습만 바꿔 본다 (저장하지 않음)
  @visibleForTesting
  void debugLook(HeroLook look) {
    _profile = _profile.copyWith(look: look);
    notifyListeners();
  }
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

  Future<void> _saveSeenTitles() => store.saveJson(_titlesKey, {
        'seen': [for (final t in _seenTitles) t.name],
        'listed': [for (final t in _listedTitles) t.name],
      });

  /// 프로필 칭호 목록에서 이미 보여 준 칭호 (묶음 26 #177: 처음 볼 때 한 번 빛남)
  Set<TitleId> _listedTitles = {};

  /// 얻은 칭호, 새로 얻은 것부터 (묶음 26 #177)
  List<TitleId> get titlesNewestFirst {
    final earned = player.titles;
    return [
      for (final t in earned)
        if (!_seenTitles.contains(t)) t,
      for (final t in _seenTitles.toList().reversed)
        if (earned.contains(t)) t,
    ];
  }

  /// 프로필 목록에서 아직 보여 주지 않은 칭호인지
  bool titleIsNewInList(TitleId t) => !_listedTitles.contains(t);

  /// 지금 얻은 칭호를 모두 보여 준 것으로
  Future<void> markTitlesListed() async {
    final earned = player.titles;
    if (earned.every(_listedTitles.contains)) return;
    _listedTitles = {..._listedTitles, ...earned};
    await _saveSeenTitles();
  }

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
    // 묶음 55 #245: 로그인 상태 · 마지막 서버 시간 차이 (그 뒤 서버 시간을 새로 받음)
    await _loadCloud();
    await _loadConsent();
    unawaited(refreshServerTime());
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
    // 묶음 55: 서버 기록으로 바꾼 뒤 다시 읽을 때 (처음 화면이 아님)
    _needsAwakening = false;
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
    _vitals = const Vitals(); // 처음 각성은 HP·기력 가득
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
    await _fillJobMp(); // 묶음 30: 새 MP도 가득
    if (_tiredUntil != null) await _setTired(null);
    notifyListeners();
    return before;
  }

  /// 레벨업 연출을 닫았을 때
  Future<void> acknowledgeLevelUp() async {
    final from = _profile.lastSeenLevel ?? player.level.level;
    await updateProfile(_profile.copyWith(lastSeenLevel: player.level.level));
    // 묶음 57: Lv.20 보조 각인 2단계 (한 번 알림)
    if (from < JobPairRules.imprintDeepLevel &&
        player.level.level >= JobPairRules.imprintDeepLevel &&
        _jobs.awakened) {
      await _saveJobs(_jobs.copyWith(newJobs: [..._jobs.newJobs, 'deep']));
    }
    // 묶음 34: 새 분신의 잿빛 틈이 열렸으면 첫 펫 한마디
    _checkAct2();
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
    _codexSeen = feel['codexSeen'] is List ? {for (final v in feel['codexSeen'] as List) '$v'} : null;
    _codexAnnounced =
        feel['codexNoticed'] is List ? {for (final v in feel['codexNoticed'] as List) '$v'} : null;
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
    _jobs = await _load(_jobsKey, JobState.fromJson, const JobState());
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
      _gates28 = gates['v28'] == true;
      _harvestAll = gates['harvestAll'] == true;
      _alchemyKept = gates['alchemyKept'] == true;
    }
    final prophecy = await _load(_prophecyKey, (j) => j, null);
    _prophecy = ((prophecy?['got'] as num?) ?? 0).toInt().clamp(0, 3);
    // 묶음 23: 한 번만 주는 선물은 안내 기록과 따로. 예전 기록은 받은 것으로 옮긴다
    final gifts = await _load(_giftsKey, (j) => j, null);
    if (gifts == null) {
      _gifts = {
        if (_introsSeen.contains('freeWeapon')) Gift.firstWeapon,
        if (_harvest.granted) Gift.firstTools,
      };
      await _saveGifts();
    } else {
      _gifts = {for (final x in (gifts['got'] as List?) ?? const []) '$x'};
    }
    _lens = await _load(_lensKey, LensState.fromJson, const LensState());
    // 묶음 25 #171: 초반 내 둘레 몬스터의 그날 기준 자리
    final near = await _load(_nearKey, (j) => j, null);
    if (near != null &&
        near['day'] is String &&
        near['lat'] is num &&
        near['lng'] is num) {
      _nearDay = near['day'] as String;
      _nearAnchor = GeoPoint(
          (near['lat'] as num).toDouble(), (near['lng'] as num).toDouble());
    }
    // 묶음 26 #179: 안내·튜토리얼 몬스터·꽃 자리 (그날 한 번 정하면 고정)
    final pins = await _load(_pinsKey, (j) => j, null);
    if (pins != null && pins['day'] is String && pins['spots'] is Map) {
      _pinsDay = pins['day'] as String;
      _pins = {
        for (final e in (pins['spots'] as Map).entries)
          if (e.value is List && (e.value as List).length == 2)
            '${e.key}': GeoPoint(((e.value as List)[0] as num).toDouble(),
                ((e.value as List)[1] as num).toDouble()),
      };
    }
    await sync();
    // 묶음 28 #181: 이미 넘은 레벨의 기능은 안내 없이 그대로 연다
    if (!_legacyGates && !_gates28) await _migrateGates28();
    // 묶음 27 #176: 숨은 숙련도 (없으면 지금까지 한 횟수로 시작 값을 채운다)
    await _loadMastery();
    // 묶음 31: 스킬 두 갈래·스킬 페이지 (예전 기록 옮기기)
    await _migrateSkills31();
    await _migrateJobs57(); // 묶음 57 #249 직업 개편
    await _markFirstWeaponGift(); // 묶음 59: 예전 공짜 첫 무기에 「받은 선물」 표시
    // 묶음 34 2막: 진행 (없으면 처음부터. Lv.12 이상 예전 계정은 분노의 잿빛 틈부터)
    _act2 = await _load(_act2Key, Act2State.fromJson, const Act2State());
    // 묶음 35: 마을 (없으면 처음부터: 소개·마을 사람 첫 한마디를 한 번씩)
    final village = await _load(_villageKey, (j) => j, null);
    // 묶음 36: 마을 사람 이름 바꿈(토비→미나 · 브론→도르군 · 엘라→엘리엘) — 만난 기록은 그대로 이어 감
    String renamed(String k) => VillageRules.renamed[k] ?? k;
    _village = {
      for (final x in (village?['seen'] as List?) ?? const [])
        '$x'.startsWith('met:') ? 'met:${renamed('$x'.substring(4))}' : '$x'
    };
    _npcVisits = {
      for (final e in ((village?['visits'] as Map?) ?? const {}).entries)
        if (e.value is num) renamed('${e.key}'): (e.value as num).toInt(),
    };
    _act2Ready = true;
    // 묶음 44 #225: 이미 열린 건물은 완공 그림 그대로 (연출 없음)
    await _migrateBuilt44();
    await _migrateBuilt43();
    _checkAct2();
    // 묶음 42 #226: 마을 사람 친해지기 (없으면 지금까지 기록으로 시작 점수를 어림)
    await _loadNpc();
    // 묶음 43 #228: 훈련장 (하루 훈련 · 펫 훈련 · 시련)
    _training = await _load(_trainingKey, TrainingState.fromJson, const TrainingState());
    // 묶음 48 #230: 약초밭 (예전 Lv.9 이상은 완공 그림 그대로)
    _garden = await _load(_gardenKey, GardenState.fromJson, const GardenState());
    await _migrateBuilt48();
    // 묶음 50 #146: 하이랜드 (없으면 처음부터. 예전 Lv.17 이상은 첫 섬이 뜰 때 첫 장면 한 번)
    _highland = await _load(_highlandKey, HighlandState.fromJson, const HighlandState());
    // 묶음 51 #242: 주점 (없으면 처음부터. 만남·거래소는 마을 기록 'meet'·'market')
    _tavern = await _load(_tavernKey, TavernState.fromJson, const TavernState());
    // 묶음 52 #243: 3막 (없으면 처음부터, 3막이 열리기 전 걸음은 셈하지 않음)
    _act3 = await _load(_act3Key, Act3State.fromJson, const Act3State());
    _act4 = await _load(_act4Key, Act4State.fromJson, const Act4State());
    // 묶음 59: 이미 3막을 끝낸 계정은 4막이 열림 (4막 기록이 없어도 그대로, #124)
    if (_act3.has('act3End') && !_act4.opened) {
      _act4 = _act4.copyWith(opened: true, chapter: 1, chapterSteps: _history.fold<int>(0, (t, r) => t + r.steps));
      await store.saveJson(_act4Key, _act4.toJson());
    }
    // 묶음 60: 5막 (4막을 끝낸 계정은 열림, 기록이 없어도 그대로 #124)
    _act5 = await _load(_act5Key, Act5State.fromJson, const Act5State());
    if (_act4.done && !_act5.opened) {
      _act5 = _act5.copyWith(opened: true, chapter: 1, chapterSteps: _history.fold<int>(0, (t, r) => t + r.steps));
      await store.saveJson(_act5Key, _act5.toJson());
    }
    // 묶음 54: 건물 레벨업 (없으면 모두 ★1)
    _buildings = await _load(_buildingsKey, BuildingState.fromJson, const BuildingState());
    // 묶음 69 #279: 정기 공성전 일정 (서버가 알려 준 것)
    await _loadSiegeSchedule();
    // 묶음 56: 파티 (발자국 표 · 깃발 · 함께 잡은 몬스터)
    _partyLocal = await _load(_partyKey, PartyLocal.fromJson, const PartyLocal());
    // 묶음 32 #189: 기운(속성 점수) — 처음이면 남은 기록으로 한 번 세고, 대사 없이
    final aura = await _load(_auraKey, (j) => j, null);
    if (aura == null || aura['v32'] != true) {
      await _seedAura();
    } else {
      _auraAnnounced = aura['main'] as String?;
      _elementSeed = {
        for (final e in ((aura['seed'] as Map?) ?? const {}).entries)
          if (ElementRules.parse('${e.key}') case final el?)
            el: (e.value as num).toDouble(),
      };
    }
    final titles = await store.loadJson(_titlesKey);
    _seenTitles = titles == null
        ? {...player.titles}
        : {
            for (final n in (titles['seen'] as List? ?? const []))
              if (TitleRules.parse(n as String) case final t?) t,
          };
    // 묶음 26 #177: 예전 기록은 지금 가진 칭호를 이미 보여 준 것으로 (빛나지 않게)
    final listed = titles?['listed'] as List?;
    _listedTitles = listed == null
        ? {...player.titles}
        : {
            for (final n in listed)
              if (TitleRules.parse(n as String) case final t?) t,
          };
    if (titles == null || listed == null) await _saveSeenTitles();
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
    // 묶음 56: 기록을 다 읽은 뒤 한 번 더 (걸음으로 쌓이는 것들 — 켜는 중에는 건너뜀)
    await refreshVitals();
    await checkLegalNotices();
    notifyListeners();
  }

  Future<void> sync() async {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    _history = await store.loadHistory();

    // 묶음 23 #167: 건강 앱은 잠금 밖에서 기다리고, 받은 걸음만 최신 기록에 합친다.
    // (기다리는 사이 원정 보상 등이 저장돼도 덮어쓰지 않게)
    final y = _find(yesterday);
    DailyRecord? yHealth;
    if (_healthGranted && y != null) {
      yHealth = await _withHealth(y, yesterday, today)
          .then<DailyRecord?>((r) => r)
          .catchError((_) => null)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
    }
    final base = _find(today) ?? DailyRecord(date: today, stepGoal: stepGoal);
    DailyRecord? tHealth;
    if (_healthGranted) {
      tHealth = await _withHealth(base, today, now)
          .then<DailyRecord?>((r) => r)
          .catchError((_) => null)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
    }

    await _serial(() async {
      _history = await store.loadHistory();
      final yNow = _find(yesterday);
      if (yNow != null && yHealth != null) {
        await store.upsert(_withQuests(_healthOnto(yNow, yHealth)));
      }
      final tNow =
          _find(today) ?? DailyRecord(date: today, stepGoal: stepGoal);
      final merged = tHealth == null ? tNow : _healthOnto(tNow, tHealth);
      await store.upsert(_withQuests(merged.copyWith(openedApp: true)));
      _history = await store.loadHistory();
      // 묶음 27 #176: 걷기·탐험 숙련도 (열쇠 게이지 보너스·단계 대사)
      await _checkWalkMastery();
      await refreshVitals();
    });
    // 묶음 70 #293: 처음 셀 때는 지금까지 발견한 것을 모두 본 것으로
    if (_codexSeen == null || _codexAnnounced == null) {
      _codexSeen ??= codexEntries.keys.toSet();
      _codexAnnounced ??= codexEntries.keys.toSet();
      await _saveFeel();
    }
    notifyListeners();
  }

  /// 건강 앱에서 읽은 칸(걸음·밤 걸음·아침 걸음·걸음 물약 게이지)만 [latest] 에 합친다
  DailyRecord _healthOnto(DailyRecord latest, DailyRecord health) {
    var out = latest.copyWith(
        steps: health.steps,
        stepsAfter8pm: health.stepsAfter8pm,
        stepsMorning: health.stepsMorning,
        stepsNight: health.stepsNight,
        stepsDawn: health.stepsDawn);
    final bonus = health.counters['gaugeBonus'];
    if (bonus != null && bonus > (out.counters['gaugeBonus'] ?? 0)) {
      out = out.copyWith(counters: {...out.counters, 'gaugeBonus': bonus});
    }
    // 묶음 61: 손으로 입력한 걸음 (건강 앱 값 그대로)
    final manual = health.counters[manualStepsKey];
    if (manual != null && manual != out.counters[manualStepsKey]) {
      out = out.copyWith(counters: {...out.counters, manualStepsKey: manual});
    }
    return out;
  }

  // ───────────── 오늘 기록 쓰기 줄 세우기 (묶음 23 #167)
  // 읽고-고치고-저장하는 일은 한 번에 하나씩. 안에서 다시 부르면 그대로 이어서 한다.
  static final Object _lockZoneKey = Object();
  Future<void> _lockTail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    if (Zone.current[_lockZoneKey] == this) return job();
    final prev = _lockTail;
    final done = Completer<void>();
    _lockTail = done.future;
    // 앞의 일이 오래 걸려도(멈춰도) 앱이 굳지 않게 15초 뒤에는 이어 간다
    return prev
        .timeout(const Duration(seconds: 15), onTimeout: () {})
        .then((_) => runZoned(job, zoneValues: {_lockZoneKey: this}))
        .whenComplete(done.complete);
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

  /// 초반(Lv.2~5) 내 둘레 몬스터 (묶음 25 #171): 그날 처음 위치를 잡은 곳
  // 숨은 숙련도 (묶음 27 #176)
  static const _masteryKey = 'mastery';
  MasteryState _mastery = const MasteryState();

  /// 직업 각성·새 MP·직업 스킬 (묶음 30 #55·#183)
  static const _jobsKey = 'jobs';
  JobState _jobs = const JobState();

  /// 순례자가 방금 숨은 물건을 찾았는지
  bool _jobFind = false;
  int _lastTreasureGold = 0;

  /// 먼 눈을 쓸 때 이미 지도에 있던 몬스터 (그 수식어는 그대로)
  Set<String>? _farSightSeen;

  /// 방금 강화 실패가 무사했는지
  bool _lastEnhanceSafe = false;

  /// 묶음 32 #189: 예전 기록에서 한 번 센 속성 점수 · 마지막으로 알린 주 속성
  static const _auraKey = 'aura';
  Map<Element, double> _elementSeed = const {};
  String? _auraAnnounced;
  bool _masteryReady = false;
  (String, DateTime)? _shownMastery;

  static const _pinsKey = 'guidePins';
  String? _pinsDay;
  Map<String, GeoPoint> _pins = const {};
  /// 묶음 35 마을: 본 소개·한마디·만난 마을 사람·쉼터 ('village')
  static const _villageKey = 'village';
  Set<String> _village = {};
  Map<String, int> _npcVisits = {};

  /// 묶음 42 #226: 마을 사람 친해지기 · 부탁 · 사연 ('npc')
  static const _npcKey = 'npc';
  NpcState _npc = const NpcState();
  bool _npcReady = false;

  /// 묶음 43 #228: 훈련장 ('training')
  static const _trainingKey = 'training';
  TrainingState _training = const TrainingState();

  /// 묶음 48 #230: 약초밭 ('garden')
  static const _gardenKey = 'garden';
  GardenState _garden = const GardenState();

  /// 묶음 50 #146: 하이랜드 ('highland')
  static const _highlandKey = 'highland';
  HighlandState _highland = const HighlandState();

  /// 묶음 52 #243: 3막 ('act3')
  static const _act3Key = 'act3';
  Act3State _act3 = const Act3State();
  // 묶음 59 #246: 4막 · 길드
  static const _act4Key = 'act4';
  static const _act5Key = 'act5';
  Act5State _act5 = const Act5State();
  ErbardView? _erbardView;
  String? _erbardError;
  bool _erbardBusy = false;
  _ErbardFight? _erbardFight;
  String? _erbardHunt;
  Act4State _act4 = const Act4State();
  GuildView? _guildView;
  bool _guildBusy = false;
  String? _guildError;
  bool _raidGiant = false;
  List<({String id, String title, String body, DateTime from})> _notices = const [];
  Set<String> _noticeSeen = const {};
  String? _suspended;

  /// 묶음 51 #242: 주점 ('tavern')
  static const _tavernKey = 'tavern';
  TavernState _tavern = const TavernState();

  /// 묶음 54: 건물 레벨업 ('buildings')
  static const _buildingsKey = 'buildings';

  /// 묶음 56: 파티 ('party')
  static const _partyKey = 'party';
  BuildingState _buildings = const BuildingState();

  /// 마지막으로 예약한 섬 알림 때 (같으면 다시 예약하지 않음)
  DateTime? _skyNoticeAt;

  /// 방금 훈련을 마친 펫 이름 (위쪽 띠 한 번)
  String? _petTrainedNotice;

  /// 묶음 45 #232: 전용 퀘스트 다음 단계 한마디 (위쪽 띠 한 번)
  (Npc, String)? _relicStageNotice;

  /// 묶음 45 #231: 새 작은 부탁 (위쪽 띠 한 번)
  Npc? _smallNotice;

  /// 방금 꺼낸 직업 소식의 문장 그림 (묶음 35)
  String? _jobNoticeArt;

  /// 마을 그림을 넓게(좌우로 끌기) 미리 보기 — 예시 모드
  bool villagePreviewWide = false;

  /// 묶음 34 2막: 쓰러뜨린 분신 · 본체 단계 · 결말 · 그날 잿빛 틈
  static const _act2Key = 'act2';
  Act2State _act2 = const Act2State();
  bool _act2Ready = false;

  static const _nearKey = 'nearAnchor';
  String? _nearDay;
  GeoPoint? _nearAnchor;

  /// 한 번만 주는 선물을 받았는지 (묶음 23: 안내 기록과 따로, [Gift])
  static const _giftsKey = 'gifts';
  Set<String> _gifts = {};
  bool _hpTipShown = true;

  static const featureLevel = {
    Feature.stats: 2,
    Feature.smithy: 3,
    Feature.board: 4,
    Feature.harvest: 5,
    Feature.lens: 6,
    Feature.alchemy: 7,
    Feature.ore: 8,
    Feature.wood: 9,
    Feature.relic: 10,
  };

  /// 묶음 28 #181: 이 저장 방식으로 옮겼는지 (아니면 열 때 한 번 옮긴다)
  bool _gates28 = true;

  /// 업데이트 때 이미 Lv.7 이상이던 사람: 채집 자리를 모두 그대로 연다
  bool _harvestAll = false;

  /// 업데이트 때 이미 연금술 공방을 쓰던 사람: Lv.7 전이어도 열어 둔다
  bool _alchemyKept = false;

  /// 모은 예언 조각 수 (고대 유물, 0~3)
  static const _prophecyKey = 'prophecy';
  int _prophecy = 0;
  int? _lastProphecy;

  /// 안내가 지도에서 비출 채집 자리 (첫 물약 안내의 약초 덤불)
  String? _guideSpotId;

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

  // 묶음 47 #240: 가방이 가득 찼을 때 (창을 띄울 차례 · 우편함에 맡긴 수)
  bool _bagHoldNew = false;
  int _bagMailed = 0;

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

  /// 묶음 75 #327: 방금 전투에서 얻은 알 등급 (결과 창에서 보여 줌)
  EggGrade? _battleEgg;

  /// 묶음 75 #327: 가방이 가득해 의뢰 알을 우편함에 넣었는지
  bool _eggMailed = false;

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
  // 묶음 70 #293: 도감에서 본 칸 · 위쪽 띠로 알린 칸 ('m:<몬스터>' / 'p:<펫>'). null = 아직 셈 전
  Set<String>? _codexSeen;
  Set<String>? _codexAnnounced;

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
/// 묶음 35: tired = 원정에서 져서 쉬는 중인 펫
enum ExpeditionCheck { ok, needsLocation, notEnoughMp, busy, tired, training }

/// Lv.1~2 튜토리얼 단계 (묶음 15 #104). 저장 값 순서이므로 바꾸지 않는다.
/// done: 끝났거나 기존 사용자 · hunt: 바로 옆 몬스터와 첫 전투 ·
/// bag: 결과·가방 보기 · expedition: 정령 원정으로 두 번째 몬스터
/// 저장값은 순서 번호라 새 단계는 끝에 붙인다
enum TutorialStep { done, hunt, bag, expedition, intro }

/// 레벨에 따라 여는 기능 (묶음 16)
/// 레벨로 열리는 기능과 그 안내. stats 는 Lv.2 능력치 나누기 안내 (묶음 25 #165)
enum Feature {
  stats,
  smithy,
  board,
  harvest,
  lens,
  // 묶음 28 #181: Lv.7 약초 덤불·연금술 공방 · Lv.8 광석 · Lv.9 나무·물가 · Lv.10 고대 유물
  alchemy,
  ore,
  wood,
  relic,
}

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

/// 한 번만 주는 선물 (묶음 23). 저장 이름이라 바꾸지 않는다
class Gift {
  Gift._();

  /// 대장간 첫 무기 무료 (Lv.3)
  static const firstWeapon = 'firstWeapon';

  /// 채집 도구 한 벌 (대장간 무료 칸 · 기존 사용자 우편, 둘 중 하나만)
  static const firstTools = 'firstTools';
}
