import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart'
    show BoardRules, EquipSlot, EquipmentRules;
import '../../theme/app_colors.dart';
import '../bulssi/bulssi_bubble.dart';
import 'spotlight.dart';
import 'targets.dart';

/// Lv.3~6 기능 안내 (묶음 19 #4-2).
///
/// Lv.1~2 튜토리얼처럼 단계마다 누를 곳 하나만 밝게 + 손가락, 말풍선 하나,
/// 「건너뛰기」는 언제든. 밝힌 곳은 실제 버튼을 그대로 누르게 비워 둔다.
///
/// 단계는 저장하지 않고 지금 상태(무기를 가졌는지, 입었는지 …)로 매번 정한다.
/// 그래서 이미 해 본 단계는 저절로 건너뛰고, 앱을 껐다 켜도 이어서 한다.
/// 끝나거나 건너뛰면 그 기능 안내는 다시 나오지 않는다 ([AppController.markFeatureIntro]).

/// 앱 껍데기(아래 메뉴)와 안내를 잇는 다리
class TourBridge extends ChangeNotifier {
  final GlobalKey<NavigatorState> navKey =
      GlobalKey<NavigatorState>(debugLabel: 'rootNav');

  int _tab = 2;
  int get tab => _tab;
  set tab(int t) {
    if (_tab == t) return;
    _tab = t;
    _later();
  }

  /// 아래 메뉴 칸 열기 (껍데기가 넣어 준다)
  void Function(int tab)? openTab;

  /// 껍데기 창(레벨업·칭호 등)이 떠 있으면 안내를 잠깐 숨긴다
  bool _paused = false;
  bool get paused => _paused;
  set paused(bool v) {
    if (_paused == v) return;
    _paused = v;
    _later();
  }

  /// 밀어 올린 화면 이름 (맨 위가 마지막)
  final Map<Route<dynamic>, String> _names = {};
  final List<Route<dynamic>> _stack = [];

  void _push(Route<dynamic> r) {
    _stack.add(r);
    _later();
  }

  void _pop(Route<dynamic> r) {
    _stack.remove(r);
    _names.remove(r);
    _later();
  }

  void name(Route<dynamic> r, String n) {
    if (_names[r] == n) return;
    _names[r] = n;
    _later();
  }

  /// 맨 위 화면: 'home' (아래 메뉴), 알려진 화면 이름, 모르는 화면이면 null
  String? get top {
    if (_stack.isEmpty) return 'home';
    final r = _stack.last;
    if (r.isFirst) return 'home';
    return _names[r];
  }

  /// 맨 위가 창(시트·대화창)인지
  bool get topIsPopup => _stack.isNotEmpty && _stack.last is PopupRoute;

  void popToRoot() =>
      navKey.currentState?.popUntil((r) => r.isFirst);

  /// 화면이 굴러가는 등 자리가 바뀌었을 때 다시 찾게
  void poke() => _later();

  bool _scheduled = false;
  void _later() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      notifyListeners();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

final tourBridge = TourBridge();

/// 화면이 바뀌는 것을 안내에 알린다
class TourObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      tourBridge._push(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      tourBridge._pop(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      tourBridge._pop(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) tourBridge._pop(oldRoute);
    if (newRoute != null) tourBridge._push(newRoute);
  }
}

/// 안내가 알아보는 화면에 이름표를 단다 (대장간·게시판·돋보기·앨범)
class TourScreenMark extends StatelessWidget {
  const TourScreenMark({super.key, required this.name, required this.child});

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final r = ModalRoute.of(context);
    if (r != null) tourBridge.name(r, name);
    return child;
  }
}

/// 상태 화면에서 빛낼 장비 칸 (Lv.3 안내 끝)
final ValueNotifier<EquipSlot?> tourGlowSlot = ValueNotifier<EquipSlot?>(null);

/// 맨 위 화면에서 [key] 를 단 위젯 (가려졌으면 null)
Element? elementOfKey(Key key) {
  Element? found;
  void visit(Element e) {
    if (found != null) return;
    if (e.widget.key == key) {
      final route = ModalRoute.of(e);
      if (route == null || route.isCurrent) {
        found = e;
        return;
      }
    }
    e.visitChildElements(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildElements(visit);
  return found;
}

/// 맨 위 화면에서 [key] 를 단 위젯의 화면 위 자리
Rect? rectOfKey(Key key) {
  final e = elementOfKey(key);
  final box = e?.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// 한 단계: 누를 곳·말·누르면 할 일
class TourStep {
  const TourStep(
    this.line, {
    this.hole,
    this.onTap,
    this.round = false,
    this.label = '눌러 보세요',
    this.button,
    this.scrollTo,
    this.wait = false,
  });

  final String line;

  /// 밝게 비출 곳. null 이면 어둡게 하지 않고 말풍선만
  final Rect? hole;

  /// null 이면 밝힌 곳 아래 실제 버튼을 그대로 누른다
  final VoidCallback? onTap;
  final bool round;
  final String label;

  /// 말풍선 아래 버튼 (글, 누르면)
  final (String, VoidCallback)? button;

  /// 밝힐 곳이 화면 밖이면 이 위젯이 보이게 굴린다
  final Key? scrollTo;

  /// 누를 곳이 아직 그려지지 않았다 (잠시 뒤 다시 찾는다)
  final bool wait;
}

class FeatureTourLayer extends StatefulWidget {
  const FeatureTourLayer({super.key, required this.controller});

  final AppController controller;

  static const tStatus = 0, tBag = 1, tMap = 2, tVillage = 3;

  @override
  State<FeatureTourLayer> createState() => _FeatureTourLayerState();
}

class _FeatureTourLayerState extends State<FeatureTourLayer> {
  AppController get c => widget.controller;
  TourBridge get b => tourBridge;

  Timer? _retry;
  int _tries = 0;
  String _lastSig = '';

  /// 한 번만 하는 자동 이동 (예: 무기를 입으면 상태 화면으로)
  final Set<String> _once = {};

  /// 안내를 시작할 때 이미 해 본 기능인지 (그러면 바로 끝)
  final Map<Feature, bool> _startedDone = {};

  @override
  void initState() {
    super.initState();
    b.addListener(_changed);
    tutorialMonsterRect.addListener(_changed);
    // 화면이 바뀐 뒤(카드를 고르는 등)마다 다시 본다. 바뀐 게 없으면 다시 그리지 않는다
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (!_alive || _queued) return;
      if (_shownFeature == null && c.pendingFeatureIntro == null) return;
      _queued = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _queued = false;
        if (_alive && mounted) _compute();
      });
    });
  }

  bool _alive = true;

  @override
  void dispose() {
    _alive = false;
    b.removeListener(_changed);
    tutorialMonsterRect.removeListener(_changed);
    _retry?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) _queue();
  }

  void _openTab(int t) => b.openTab?.call(t);

  /// 그리는 중에는 상태를 바꾸지 않는다: 다음 화면에서
  void _guide({bool? hunt, bool? harvest, EquipSlot? glow, bool clearGlow = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (hunt != null) c.guideHunt = hunt;
      if (harvest != null) c.guideHarvest = harvest;
      if (glow != null) tourGlowSlot.value = glow;
      if (clearGlow) tourGlowSlot.value = null;
    });
  }

  void _goHome(int t) {
    b.popToRoot();
    _openTab(t);
  }

  void _doOnce(String id, VoidCallback f) {
    if (_once.contains(id)) return;
    _once.add(id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) f();
    });
  }

  Future<void> _finish(Feature f) async {
    tourGlowSlot.value = null;
    c.guideHunt = false;
    c.guideHarvest = false;
    _once.clear();
    await c.markFeatureIntro(f);
  }

  /// 홈 칸 [t] 에 있는 [key] 를 비추고, 다른 칸이면 아래 메뉴 칸부터
  TourStep _homeTarget(int t, Key key, String navLine, String line,
      {bool round = false}) {
    if (b.top != 'home') {
      return TourStep(navLine, button: ('가 보기', () => _goHome(t)));
    }
    if (b.tab != t) {
      return TourStep(navLine,
          hole: rectOf(tutorialNavKeys[t])?.inflate(4),
          wait: rectOf(tutorialNavKeys[t]) == null);
    }
    final r = rectOfKey(key);
    return TourStep(line,
        hole: r?.inflate(4), round: round, scrollTo: key, wait: r == null);
  }

  /// 마을의 시설 [facility] 로 들어가기
  TourStep _toFacility(String screen, String key, String navLine, String line) {
    if (b.top == screen) return const TourStep('');
    return _homeTarget(FeatureTourLayer.tVillage, Key(key), navLine, line);
  }

  /// 맨 위 화면의 [key] 를 비춘다
  TourStep _here(Key key, String line, {String label = '눌러 보세요'}) {
    final r = rectOfKey(key);
    return TourStep(line,
        hole: r?.inflate(4), scrollTo: key, wait: r == null, label: label);
  }

  TourStep? _step(Feature f) {
    switch (f) {
      case Feature.smithy:
        return _smithy(f);
      case Feature.board:
        return _board(f);
      case Feature.harvest:
        return _harvest(f);
      case Feature.lens:
        return _lens(f);
    }
  }

  // ───────────── Lv.3 대장간: 첫 무기 고르기 → 만들기 → 입기 → 상태 무기 칸

  TourStep? _smithy(Feature f) {
    final items = c.armory.items
        .where((i) => EquipmentRules.info(i.base).slot == EquipSlot.weapon);
    final worn = c.armory.wornIn(EquipSlot.weapon);
    _startedDone.putIfAbsent(f, () => worn != null);
    if (_startedDone[f]!) {
      _doOnce('end', () => _finish(f));
      return null;
    }
    if (items.isEmpty) {
      if (!c.firstWeaponFree) {
        _doOnce('end', () => _finish(f));
        return null;
      }
      if (b.top != 'smithy') {
        return _toFacility('smithy', 'facility_smithy',
            '대장간이 열렸어! 마을로 가 보자.', '대장간을 눌러 봐!');
      }
      if (rectOfKey(const Key('firstWeaponCraft')) != null) {
        return _here(const Key('firstWeaponCraft'),
            '좋아! 첫 무기는 내가 낼게. 만들어 보자!');
      }
      return _here(const Key('firstWeaponPicker'),
          '마음에 드는 무기를 하나 골라 봐! 고르면 휘두르는 모습을 볼 수 있어.',
          label: '골라 보세요');
    }
    if (worn == null) {
      if (rectOfKey(const Key('equipNow')) != null) {
        return _here(const Key('equipNow'), '멋지다! 바로 입어 보자.');
      }
      final pick = items.first;
      if (rectOfKey(Key('pick_${pick.uid}')) != null) {
        return _here(Key('pick_${pick.uid}'), '방금 만든 무기를 골라 입자!');
      }
      return _homeTarget(FeatureTourLayer.tStatus, const Key('gearSlot_weapon'),
          '상태 화면에서 무기를 입어 보자!', '무기 칸을 눌러 봐!');
    }
    // 다 입었다: 상태 화면 무기 칸이 빛난다
    if (b.top != 'home' || b.tab != FeatureTourLayer.tStatus) {
      if (b.topIsPopup || b.top == null) return null;
      _doOnce('toStatus', () => _goHome(FeatureTourLayer.tStatus));
    }
    if (tourGlowSlot.value != EquipSlot.weapon) _guide(glow: EquipSlot.weapon);
    final r = rectOfKey(const Key('gearSlot_weapon'));
    return TourStep('무기 칸이 빛나지? 이제 전투에서 이 무기로 싸워!',
        hole: r?.inflate(6),
        wait: r == null,
        label: '확인',
        onTap: () => _finish(f));
  }

  // ───────────── Lv.4 게시판: 쉬운 의뢰 받기 → 지도에서 깨기 → 빨간 점 → 보상

  TourStep? _board(Feature f) {
    final bd = c.board;
    _startedDone.putIfAbsent(f, () => bd.doneToday > 0);
    if (_startedDone[f]! || bd.doneToday > 0) {
      _doOnce('end', () => _finish(f));
      return null;
    }
    int? accepted;
    for (var i = 0; i < bd.slots.length; i++) {
      if (bd.slots[i].accepted) accepted = i;
    }
    if (accepted == null) {
      _guide(hunt: false);
      if (b.top != 'board') {
        return _toFacility('board', 'facility_board',
            '의뢰 게시판이 열렸어! 마을로 가 보자.', '의뢰 게시판을 눌러 봐!');
      }
      _doOnce('errand', c.prepareGuideErrand);
      var slot = bd.slots
          .indexWhere((s) => s.templateId == BoardRules.guideErrand.id);
      if (slot < 0) slot = bd.slots.indexWhere((s) => s.templateId != null);
      if (slot < 0) {
        _doOnce('end', () => _finish(f));
        return null;
      }
      return _here(Key('errandAccept_$slot'), '쉬운 의뢰부터 받아 보자!');
    }
    if (c.questRewardsReady == 0) {
      // 지도에서 깨기
      if (b.topIsPopup || (b.top != 'home' && b.top != 'board')) return null;
      _guide(hunt: true);
      if (b.top != 'home' || b.tab != FeatureTourLayer.tMap) {
        _doOnce('toMap', () => _goHome(FeatureTourLayer.tMap));
        return const TourStep('', wait: true);
      }
      final r = tutorialMonsterRect.value;
      return TourStep(
          r == null
              ? '지도에서 몬스터 하나만 잡아 보자! 의뢰가 저절로 세어져.'
              : '바로 옆에 몬스터가 있어! 하나만 잡아 보자.',
          hole: r,
          round: true);
    }
    _guide(hunt: false);
    if (b.top != 'board') {
      if (b.top == 'home' && b.tab != FeatureTourLayer.tVillage) {
        final nav = rectOf(tutorialNavKeys[FeatureTourLayer.tVillage]);
        return TourStep('의뢰를 다 했어! 마을에 빨간 점이 생겼지? 눌러 봐.',
            hole: nav?.inflate(4), wait: nav == null);
      }
      return _toFacility('board', 'facility_board',
          '의뢰를 다 했어! 마을로 가 보자.', '의뢰 게시판에서 보상을 받자!');
    }
    return _here(Key('errandClaim_$accepted'), '보상을 받자!');
  }

  // ───────────── Lv.5 채집: 첫 도구 만들기 → 가까운 꽃 → 미니게임 → 얻은 것

  TourStep? _harvest(Feature f) {
    _startedDone.putIfAbsent(f, () => c.harvestTotal > 0);
    if (_startedDone[f]!) {
      _doOnce('end', () => _finish(f));
      return null;
    }
    if (!c.harvestToolsReady) {
      if (b.top != 'smithy') {
        return _toFacility('smithy', 'facility_smithy',
            '이제 꽃이랑 버섯을 딸 수 있어! 먼저 대장간에서 도구를 만들자.',
            '대장간을 눌러 봐!');
      }
      return _here(const Key('firstToolMake'), '채집 도구도 내가 낼게. 만들어 보자!');
    }
    if (c.harvestTotal == 0) {
      if (b.top == null) return null; // 미니게임 중
      if (b.topIsPopup) {
        if (rectOfKey(const Key('harvestGame')) != null) {
          return _here(const Key('harvestGame'), '미니게임으로 따면 더 많이 얻을 수 있어!');
        }
        return null;
      }
      if (!c.hasLocation) {
        return TourStep('위치를 켜면 가까운 꽃밭이랑 버섯이 지도에 보여. 걸으면서 찾아 봐!',
            button: ('알겠어', () => _finish(f)));
      }
      _guide(harvest: true);
      if (b.top != 'home' || b.tab != FeatureTourLayer.tMap) {
        _doOnce('toMap', () => _goHome(FeatureTourLayer.tMap));
        return const TourStep('', wait: true);
      }
      final r = tutorialMonsterRect.value;
      return TourStep('바로 옆에 꽃이 피었어! 눌러 봐.', hole: r, round: true);
    }
    // 얻은 것 확인: 가방
    if (b.topIsPopup || b.top == null) return null;
    if (b.top != 'home' || b.tab != FeatureTourLayer.tBag) {
      if (b.top != 'home') {
        return TourStep('딴 것은 가방에 들어갔어! 확인해 보자.',
            button: ('가방 보기', () => _goHome(FeatureTourLayer.tBag)));
      }
      final nav = rectOf(tutorialNavKeys[FeatureTourLayer.tBag]);
      return TourStep('딴 것은 가방에 들어갔어! 확인해 보자.',
          hole: nav?.inflate(4), wait: nav == null);
    }
    return TourStep('여기 들어왔어! 꽃이랑 버섯은 물약을 만들 때 써.',
        button: ('알겠어', () => _finish(f)));
  }

  // ───────────── Lv.6 돋보기: 지도 돋보기 → 감정 → 앨범 첫 사진

  TourStep? _lens(Feature f) {
    _startedDone.putIfAbsent(f, () => c.album.isNotEmpty);
    if (_startedDone[f]!) {
      _doOnce('end', () => _finish(f));
      return null;
    }
    if (b.top == 'album') {
      return TourStep('첫 사진이야! 감정할 때마다 여기 모여.',
          button: ('알겠어', () => _finish(f)));
    }
    if (b.top == 'lens') {
      if (b.topIsPopup) return null;
      if (c.album.isNotEmpty) {
        return _here(const Key('lensAlbum'), '감정한 모습은 앨범에 남아! 열어 볼까?');
      }
      if (rectOfKey(const Key('lensToFilter')) != null) {
        return _here(const Key('lensToFilter'), '어떤 종족일까? 눌러 봐!');
      }
      return _here(const Key('appraise'),
          '사람 얼굴을 비추고 눌러 봐! 오늘 한 번은 무료야.');
    }
    if (b.top != 'home' && b.top != null) {
      return TourStep('지도에 마법 돋보기가 생겼어!',
          button: ('가 보기', () => _goHome(FeatureTourLayer.tMap)));
    }
    if (b.top == null) return null;
    return _homeTarget(FeatureTourLayer.tMap, const Key('mapLens'),
        '지도에 마법 돋보기가 생겼어! 지도로 가 보자.',
        '사람을 비추면 숨은 이세계 종족이 보여. 눌러 봐!',
        round: true);
  }

  void _scheduleRetry(String sig) {
    if (sig != _lastSig) {
      _lastSig = sig;
      _tries = 0;
    }
    if (_tries >= 16) return;
    _tries++;
    _retry?.cancel();
    _retry = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _queue();
    });
  }

  // 단계는 그린 뒤에 정한다 (그리는 중에는 화면 위 자리를 찾을 수 없다)
  TourStep? _shown;
  Feature? _shownFeature;
  bool _queued = false;

  void _queue() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) _compute();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  static bool _same(TourStep? a, TourStep? b) {
    if (a == null || b == null) return a == b;
    return a.line == b.line &&
        a.hole == b.hole &&
        a.round == b.round &&
        a.label == b.label &&
        a.button?.$1 == b.button?.$1 &&
        (a.onTap == null) == (b.onTap == null);
  }

  void _compute() {
    final f = c.pendingFeatureIntro;
    TourStep? step;
    if (f == null) {
      if (tourGlowSlot.value != null) tourGlowSlot.value = null;
    } else if (!b.paused && !c.holdNotices && c.ready) {
      step = _step(f);
      if (step != null && step.wait) {
        _scheduleRetry('${f.name}:${step.line}');
      }
      final key = step?.scrollTo;
      final h = step?.hole;
      final size = MediaQuery.sizeOf(context);
      if (key != null &&
          h != null &&
          // 누를 곳이 거의 다 화면 밖일 때만 굴린다 (큰 칸은 그대로)
          (h.top > size.height - 120 || h.bottom < 90)) {
        final e = elementOfKey(key);
        if (e != null && e.mounted) {
          Scrollable.ensureVisible(e,
              alignment: 0.4, duration: const Duration(milliseconds: 250));
          _scheduleRetry('${f.name}:scroll');
        }
      }
      if (step != null && step.line.isEmpty) step = null;
    }
    if (!_same(step, _shown) || f != _shownFeature) {
      setState(() {
        _shown = step;
        _shownFeature = f;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        _queue();
        final step = _shown;
        final f = _shownFeature;
        if (step == null || f == null || c.pendingFeatureIntro != f) {
          return const SizedBox.shrink();
        }
        return Material(
          type: MaterialType.transparency,
          child: _TourView(
            step: step,
            onSkip: () => _finish(f),
          ),
        );
      },
    );
  }
}

class _TourView extends StatelessWidget {
  const _TourView({required this.step, required this.onSkip});

  final TourStep step;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final h = step.hole;
    // 밝힌 곳이 아래쪽이면 말풍선은 위로, 아니면 아래로 (가리지 않게)
    final bubbleTop = h != null && h.center.dy > size.height * 0.55;
    final bubble = Column(mainAxisSize: MainAxisSize.min, children: [
      // 말풍선은 아래 버튼을 막지 않는다 (말풍선 버튼만 눌린다)
      IgnorePointer(
          child: BulssiBubble(
              key: const Key('tourLine'), line: step.line, size: 52)),
      if (step.button != null) ...[
        const SizedBox(height: 8),
        GoldButtonLite(
          key: const Key('tourButton'),
          label: step.button!.$1,
          onPressed: step.button!.$2,
        ),
      ],
    ]);
    return Stack(fit: StackFit.expand, children: [
      if (h != null)
        step.onTap == null
            ? HoleSpotlight(hole: h, round: step.round, label: step.label)
            : Spotlight(
                hole: h,
                onTap: step.onTap,
                round: step.round,
                label: step.label,
                dim: 0.6),
      Positioned(
        left: 14,
        right: 14,
        top: bubbleTop ? pad.top + 96 : null,
        bottom: bubbleTop
            ? null
            : h != null && h.bottom > size.height - pad.bottom - 120
                ? size.height - h.top + 16
                : pad.bottom + 96,
        child: bubble,
      ),
      Positioned(
        right: 10,
        top: pad.top + 56,
        child: TextButton(
          key: const Key('tourSkip'),
          onPressed: onSkip,
          child: const Text('건너뛰기',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      ),
    ]);
  }
}

/// 말풍선 아래 작은 금빛 버튼
class GoldButtonLite extends StatelessWidget {
  const GoldButtonLite({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: const Color(0xFF1A1405),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10)),
        onPressed: onPressed,
        child: Text(label,
            maxLines: 1,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );
}

/// 밝힌 곳은 아래 실제 버튼을 그대로 누르게 두고, 나머지만 막는 어두운 막
class HoleSpotlight extends StatelessWidget {
  const HoleSpotlight(
      {super.key,
      required this.hole,
      this.round = false,
      this.label = '눌러 보세요'});

  final Rect hole;
  final bool round;
  final String label;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return Stack(fit: StackFit.expand, children: [
      _HoleBlocker(
        hole: hole,
        round: round,
        child: Spotlight(hole: hole, onTap: null, round: round, dim: 0.6,
            showFinger: false),
      ),
      Positioned(
        left: (hole.center.dx - 10).clamp(8.0, w - 150),
        top: hole.bottom - 6,
        child: IgnorePointer(
            child: FingerHint(key: const Key('tourFinger'), label: label)),
      ),
    ]);
  }
}

class _HoleBlocker extends SingleChildRenderObjectWidget {
  const _HoleBlocker({required this.hole, required this.round, super.child});

  final Rect hole;
  final bool round;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHoleBlocker(hole, round);

  @override
  void updateRenderObject(BuildContext context, _RenderHoleBlocker r) {
    r
      ..hole = hole
      ..round = round;
  }
}

class _RenderHoleBlocker extends RenderProxyBox {
  _RenderHoleBlocker(this.hole, this.round);

  Rect hole;
  bool round;

  bool _inHole(Offset global) {
    if (round) {
      final r = hole.longestSide / 2;
      return (global - hole.center).distanceSquared <= r * r;
    }
    return hole.contains(global);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    final global = localToGlobal(position);
    if (_inHole(global)) return false; // 아래 버튼으로 그대로
    result.add(BoxHitTestEntry(this, position));
    return true; // 나머지는 막는다
  }
}
