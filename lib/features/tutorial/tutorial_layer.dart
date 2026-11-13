import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/vitals.dart' show Expedition;
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../battle/field_battle_screen.dart';
import '../bulssi/bulssi_bubble.dart';
import '../map/expedition_sheet.dart';
import 'spotlight.dart';
import 'targets.dart';

/// 첫 튜토리얼 (묶음 18 #150·#148·#151): 아래 메뉴까지 덮는 한 겹.
///
/// - 단계마다 누를 곳 하나만 동그랗게 밝게 + 손가락. 나머지는 눌리지 않는다.
/// - 정령 말풍선은 아래쪽에 하나. 「건너뛰기」는 오른쪽 위 작은 글자.
/// - 위치를 받은 뒤 시작. 위치를 못 받으면 화면 가운데 슬라임으로 진행.
class TutorialLayer extends StatefulWidget {
  const TutorialLayer({
    super.key,
    required this.controller,
    required this.tab,
    required this.openTab,
    required this.showResults,
  });

  final AppController controller;

  /// 지금 보고 있는 아래 메뉴 칸
  final int tab;
  final ValueChanged<int> openTab;
  final Future<void> Function() showResults;

  static const tBag = 1, tMap = 2;

  @override
  State<TutorialLayer> createState() => _TutorialLayerState();
}

class _TutorialLayerState extends State<TutorialLayer> {
  AppController get c => widget.controller;

  /// 위치를 기다리기 시작한 때 (오래 걸리면 가운데 슬라임으로)
  DateTime? _waitSince;
  Timer? _tick;
  bool _sendOpen = false;
  int _retries = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    tutorialMonsterRect.addListener(_changed);

  }

  @override
  void dispose() {
    tutorialMonsterRect.removeListener(_changed);
    _tick?.cancel();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// 위치를 기다리는 중인지 (위치 기능이 있는 기기에서만)
  bool get _locating {
    if (c.hasLocation || c.location == null || c.locationDenied) {
      _waitSince = null;
      return false;
    }
    if (_waitSince == null) {
      _waitSince = DateTime.now();
      // 12초 뒤 다시 그려 「위치를 켜 주세요」로
      _tick?.cancel();
      _tick = Timer(const Duration(seconds: 12), () {
        if (mounted) setState(() {});
      });
    }
    return DateTime.now().difference(_waitSince!) < const Duration(seconds: 12);
  }

  /// 위치 없이 진행 중 (거부했거나 오래 못 받음)
  bool get _noLocation => !c.hasLocation && c.location != null;

  /// 몬스터를 비출 자리: 지도 위 자리, 없으면 화면 위쪽 가운데
  Rect _monsterHole(Size size) =>
      tutorialMonsterRect.value ??
      Rect.fromCenter(
          center: Offset(size.width / 2, size.height * 0.36),
          width: 110,
          height: 110);

  Future<void> _hunt(FieldSpawn spawn) async {
    if (_busy) return;
    _busy = true;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FieldBattleScreen(controller: c, spawn: spawn)));
    _busy = false;
  }

  Future<void> _send(FieldSpawn spawn) async {
    if (_busy) return;
    _busy = true;
    await c.sendSpirit(spawn);
    _busy = false;
    if (mounted) setState(() => _sendOpen = false);
  }

  Future<void> _rush(Expedition ex) async {
    if (_busy) return;
    _busy = true;
    final done = await showRushSheet(context, c, ex);
    _busy = false;
    if (done && mounted) await widget.showResults();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final step = c.tutorialStep;
    if (step == TutorialStep.done) return const SizedBox.shrink();
    if (step == TutorialStep.intro) {
      return IsekaiIntro(key: const Key('isekaiIntro'), onDone: c.finishIntro);
    }

    String line;
    Rect? hole;
    bool round = true;
    double dim = 0.7;
    VoidCallback? onTap;
    Widget? extra;
    String label = '눌러 보세요';
    final spawn = c.tutorialSpawn;
    final away = [
      for (final e in c.activeExpeditions)
        if (AppController.isTutorialSpawn(e.spawnId)) e
    ];
    final back = c.finishedExpeditions
        .any((e) => AppController.isTutorialSpawn(e.spawnId));

    if ((step == TutorialStep.hunt || step == TutorialStep.expedition) &&
        spawn != null &&
        _locating) {
      line = '잠깐, 네가 어디 있는지 찾고 있어…';
    } else if (step == TutorialStep.hunt && spawn != null) {
      line = '바로 옆에 뭔가 있어! 눌러 봐!';
      hole = _monsterHole(size);
      onTap = () => _hunt(spawn);
      extra = _slimeAt(hole);
    } else if (step == TutorialStep.bag) {
      if (widget.tab != TutorialLayer.tBag) {
        line = '방금 얻은 걸 가방에서 확인해 보자!';
        hole = rectOf(tutorialNavKeys[TutorialLayer.tBag])?.inflate(4);
        round = false;
        onTap = () => widget.openTab(TutorialLayer.tBag);
      } else {
        line = '마석이랑 젤리가 들어왔어! 이제 지도로 돌아가자.';
        hole = rectOf(tutorialNavKeys[TutorialLayer.tMap])?.inflate(4);
        round = false;
        onTap = () async {
          await c.tutorialBagSeen();
          widget.openTab(TutorialLayer.tMap);
        };
        // 가방 안 얻은 것(반짝이는 마석·젤리)이 보이게 덜 어둡게
        dim = 0.35;
      }
    } else if (step == TutorialStep.expedition) {
      if (widget.tab != TutorialLayer.tMap) {
        line = '지도로 돌아가자!';
        hole = rectOf(tutorialNavKeys[TutorialLayer.tMap])?.inflate(4);
        round = false;
        onTap = () => widget.openTab(TutorialLayer.tMap);
      } else if (back) {
        line = '돌아왔어! 눌러서 결과를 받아 줘.';
        hole = rectOf(tutorialStripKey)?.inflate(6);
        round = false;
        onTap = widget.showResults;
      } else if (away.isNotEmpty) {
        line = '다녀오는 데 시간이 좀 걸려… 나를 누르면 서두를 수 있어!';
        hole = rectOf(tutorialStripKey)?.inflate(6);
        round = false;
        onTap = () => _rush(away.first);
      } else if (spawn != null && _sendOpen) {
        line = '저쪽에 한 마리 더 있어! 멀리 있으니까 내가 대신 다녀올게.';
        final card = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.42),
            width: math.min(320, size.width - 40),
            height: 210);
        extra = Positioned.fromRect(rect: card, child: _SendCard(spawn: spawn));
        hole = Rect.fromLTWH(card.left + 24, card.bottom - 70, card.width - 48, 54);
        round = false;
        onTap = () => _send(spawn);
        label = '보내기';
      } else if (spawn != null) {
        line = '저쪽에 한 마리 더 있어! 멀리 있으니까 내가 대신 다녀올게.';
        hole = _monsterHole(size);
        onTap = () => setState(() => _sendOpen = true);
        extra = _slimeAt(hole);
      } else {
        line = '잠깐만, 다음 몬스터를 찾고 있어…';
      }
    } else {
      line = '잠깐, 네가 어디 있는지 찾고 있어…';
    }

    // 메뉴 칸·원정 띠 자리는 그려진 뒤에 알 수 있다: 아직이면 다음 화면에서 다시
    if (hole == null && onTap != null && _retries < 30) {
      _retries++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else if (hole != null) {
      _retries = 0;
    }

    // 위치를 못 받으면: 위치를 켜 달라고 하고, 그래도 가운데 슬라임으로 진행
    final askLocation = _noLocation &&
        !_locating &&
        (step == TutorialStep.hunt || step == TutorialStep.expedition) &&
        widget.tab == TutorialLayer.tMap;

    return Stack(fit: StackFit.expand, children: [
      Spotlight(
          hole: hole, onTap: onTap, round: round, label: label, dim: dim),
      if (extra != null) extra,
      // 정령 말풍선: 아래쪽, 몬스터를 가리지 않게
      Positioned(
        left: 14,
        right: 14,
        bottom: bottomPad + 96,
        child: IgnorePointer(
          ignoring: !askLocation,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BulssiBubble(
                key: const Key('tutorialLine'), line: line, size: 52),
            if (askLocation) ...[
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Flexible(
                  child: Text('위치를 켜 주세요. 그동안은 여기서 해 볼게!',
                      style: TextStyle(color: AppColors.text, fontSize: 14)),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: const Key('tutorialRetryLocation'),
                  onPressed: () {
                    _waitSince = null;
                    c.retryLocation();
                  },
                  child: const Text('다시 시도'),
                ),
              ]),
            ],
          ]),
        ),
      ),
      // 막히면 언제든 빠져나올 수 있게
      Positioned(
        right: 10,
        top: MediaQuery.paddingOf(context).top + 56,
        child: TextButton(
          key: const Key('tutorialSkip'),
          onPressed: c.skipTutorial,
          child: const Text('건너뛰기',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      ),
    ]);
  }

  /// 밝게 비춘 자리에 하늘 슬라임 (지도 표시보다 또렷하게)
  Widget _slimeAt(Rect hole) => Positioned.fromRect(
        rect: hole.deflate(10),
        child: const IgnorePointer(
          child: MonsterPicture(monster: MonsterId.slime, size: 80),
        ),
      );
}

/// 둘째 몬스터에게 정령 보내기 (튜토리얼): 보내기 버튼만
class _SendCard extends StatelessWidget {
  const _SendCard({required this.spawn});

  final FieldSpawn spawn;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      key: const Key('tutorialSendCard'),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          MonsterPicture(monster: spawn.monster, size: 56),
          const SizedBox(width: 10),
          Expanded(
            child: Text(Monsters.info(spawn.monster).name,
                style: AppText.title(19)),
          ),
        ]),
        const SizedBox(height: 10),
        GoldButton(
          key: const Key('tutorialSend'),
          label: '보내기',
          height: 50,
          onPressed: () {},
        ),
      ]),
    );
  }
}

/// 각성 직후 연출 (묶음 16 #140, 묶음 18 #150): 빛이 가운데서 퍼지며 이세계 색으로
/// 물들고, 정령이 두 마디 한 뒤 저절로 첫 전투로 넘어간다. 버튼 없음.
class IsekaiIntro extends StatefulWidget {
  const IsekaiIntro({super.key, required this.onDone});

  final Future<void> Function() onDone;

  static const lines = [
    '여기가 네가 사는 동네야. 그런데 봐, 세상이 조금 다르게 빛나지?',
    '어? 바로 옆에 뭔가 있어!',
  ];

  @override
  State<IsekaiIntro> createState() => _IsekaiIntroState();
}

class _IsekaiIntroState extends State<IsekaiIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..forward();
  int _line = 0;
  final List<Timer> _timers = [];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // 빛이 퍼진 뒤 첫 마디 → 2.6초 뒤 둘째 마디 → 2초 뒤 첫 전투로
    _timers.add(Timer(const Duration(milliseconds: 4800), () {
      if (mounted) setState(() => _line = 1);
    }));
    _timers.add(Timer(const Duration(milliseconds: 6800), _finish));
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onDone();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) _a.value = 1;
    // 연출 중에는 아래 지도가 눌리지 않는다 (#150)
    return AbsorbPointer(
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_a.value);
          final textIn = ((_a.value - 0.55) / 0.45).clamp(0.0, 1.0);
          return Stack(fit: StackFit.expand, children: [
            CustomPaint(painter: _IntroGlowPainter(t)),
            Positioned(
              left: 14,
              right: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 96,
              child: Opacity(
                opacity: textIn,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: BulssiBubble(
                    key: ValueKey(_line),
                    line: IsekaiIntro.lines[_line],
                    size: 52,
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _IntroGlowPainter extends CustomPainter {
  _IntroGlowPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.longestSide * (0.15 + 0.9 * t);
    // 바깥은 밤빛 보라로 덮고, 가운데 빛 고리가 퍼진다
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = Color.lerp(const Color(0xEE0B0D26),
              const Color(0x553A1E6E), t)!);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFE9A8).withValues(alpha: 0.55 * (1 - t * 0.6)),
            const Color(0xFFB98330).withValues(alpha: 0.25 * (1 - t * 0.5)),
            const Color(0x00000000),
          ], stops: const [0, 0.55, 1])
              .createShader(Rect.fromCircle(center: c, radius: r)));
    // 반짝이 몇 개
    final rnd = math.Random(7);
    for (var i = 0; i < 24; i++) {
      final a = rnd.nextDouble() * math.pi * 2;
      final d = r * (0.3 + rnd.nextDouble() * 0.7);
      final p = c + Offset(math.cos(a) * d, math.sin(a) * d);
      canvas.drawCircle(
          p,
          1.2 + rnd.nextDouble() * 1.8,
          Paint()
            ..color = const Color(0xFFFFF3C4)
                .withValues(alpha: (0.8 * t) * (1 - (d / r) * 0.5)));
    }
  }

  @override
  bool shouldRepaint(_IntroGlowPainter old) => old.t != t;
}
