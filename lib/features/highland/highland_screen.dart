import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../map/trip_sheet.dart';
import '../act2/ash_battle_screen.dart' show AshExpPanel;
import '../awakening/awakening_screen.dart' show IllustratedScene, SceneWho;
import '../battle/battle_view.dart';
import '../battle/dungeon_screen.dart' show confirmStopResting;
import '../battle/element_view.dart';
import '../battle/hero_rig.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart' show SpiritMood;
import '../town/material_view.dart';
import 'sky_turn_view.dart';
import 'sky_walk_view.dart';

enum _Stage { entry, walk, soldier, guardian, result }

/// 하이랜드 (묶음 50 #146 · 묶음 83 #389): 하늘에 뜬 섬 하나.
/// 오르기(하늘 깃털 1) → 쿼터뷰 구름 걷기 3층(석상 병사 · 유물 조각 · 계단) →
/// 꼭대기 제단에서 수호자 턴제 → 결과. 오르는 중에 나가면 그대로 이어서 (앱을 다시 켜도).
class HighlandScreen extends StatefulWidget {
  const HighlandScreen({
    super.key,
    required this.controller,
    this.tickInterval = const Duration(milliseconds: 900),
    this.turnStep = const Duration(milliseconds: 520),
  });

  final AppController controller;
  final Duration tickInterval;
  final Duration turnStep;

  @override
  State<HighlandScreen> createState() => _HighlandScreenState();
}

class _HighlandScreenState extends State<HighlandScreen> {
  _Stage _stage = _Stage.entry;
  Battle? _battle;
  SkyTurn? _turn;

  /// 결과 창: 구름 걷기가 끝남 (까닭 · 합계) 또는 수호자 결과
  SkyEnd? _end;
  SkyClimbSummary? _summary;
  SkyResult? _result;

  String? _line;
  String? _walkNews;
  int _walkNo = 0;
  Timer? _watch;

  /// 들어올 때 섬 (그사이 섬이 사라져도 그림·이름은 그대로)
  late final IsleInfo? _info = widget.controller.skyIsland?.info;

  AppController get _c => widget.controller;
  SkyIsland? get _island => _c.skyIsland;

  @override
  void initState() {
    super.initState();
    _c.holdNoticesWhile(true);
    if (_c.skyGuardianAbandoned) {
      // 수호자를 깨운 채 나갔으면 진 것으로
      WidgetsBinding.instance.addPostFrameCallback((_) => _guardianDone());
    } else if (_c.skyClimb case final cl?) {
      if (cl.soldier != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _soldier());
      } else {
        _stage = _Stage.walk;
      }
    }
    _watch = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _stage != _Stage.walk) return;
      if (_c.skyIsland == null) _endClimb(SkyEnd.islandGone);
    });
  }

  @override
  void dispose() {
    _watch?.cancel();
    _c.holdNoticesWhile(false);
    super.dispose();
  }

  // ───────────── 오르기

  Future<void> _climb() async {
    if (_c.resting) {
      final ok = await confirmStopResting(context);
      if (!ok || !mounted) return;
    }
    final ok = await _c.climbIsland();
    if (!ok || !mounted) return;
    setState(() {
      _stage = _Stage.walk;
      _walkNews = _c.takeFirstClimbLine();
      _walkNo++;
    });
  }

  // ───────────── 석상 병사 (밝히면 바로)

  void _soldier() {
    final b = _c.startSoldierBattle();
    if (b == null) {
      setState(() => _stage = _Stage.walk);
      return;
    }
    setState(() {
      _battle = b;
      _stage = _Stage.soldier;
    });
  }

  Future<void> _soldierDone() async {
    final r = await _c.finishSoldierBattle(_battle!);
    if (!mounted) return;
    if (!r.won) {
      setState(() {
        _end = SkyEnd.hpZero;
        _summary = r.climb;
        _result = null;
        _battle = null;
        _stage = _Stage.result;
      });
      return;
    }
    if (_c.hp <= 0) {
      await _endClimb(SkyEnd.hpZero);
      return;
    }
    final n = r.mats[MaterialId.skyStone] ?? 0;
    setState(() {
      _battle = null;
      _stage = _Stage.walk;
      _walkNews = '석상 병사가 길을 비켜 줬어요 · 하늘 돌 조각 $n';
      _walkNo++;
    });
    if (_c.skyStuck) await _endClimb(SkyEnd.noWind);
  }

  // ───────────── 끝

  Future<void> _endClimb(SkyEnd why) async {
    if (_stage == _Stage.result) return;
    final sum = await _c.endSkyClimb();
    if (!mounted) return;
    setState(() {
      _end = why;
      _summary = sum;
      _result = null;
      _stage = _Stage.result;
    });
  }

  // ───────────── 수호자 (턴제)

  Future<void> _wake() async {
    final t = await _c.startGuardianTurn();
    if (t == null || !mounted) return;
    setState(() {
      _turn = t;
      _stage = _Stage.guardian;
    });
  }

  Future<void> _guardianDone() async {
    final t = _turn;
    final r = await _c.finishGuardianTurn(t != null && t.isOver ? t : null);
    if (!mounted) return;
    setState(() {
      _result = r;
      _summary = r.climb;
      _end = null;
      _stage = _Stage.result;
    });
    if (r.inscription case final i?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSkyInscription(context, i);
      });
    }
  }

  // ───────────── 화면

  String get _bg => _info?.background ?? 'assets/images/bg_highland_wind.webp';

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final title = _info?.place ?? '하이랜드';
    final fight = _stage == _Stage.soldier || _stage == _Stage.guardian;
    return PopScope(
      // 수호자와 싸우다 나가면 진 것으로
      canPop: _stage != _Stage.guardian,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _stage == _Stage.guardian) _guardianDone();
      },
      child: Scaffold(
        key: const Key('highlandScreen'),
        backgroundColor: AppColors.deepNight,
        bottomNavigationBar: switch (_stage) {
          _Stage.entry => _bottom(_entryButton()),
          _Stage.result => _bottom(FrameButton(
              key: const Key('skyBack'),
              label: '내려가기',
              onPressed: () => Navigator.of(context).pop())),
          _ => null,
        },
        body: NightBackground(
          child: _stage == _Stage.entry || _stage == _Stage.result
              ? ListView(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 28),
                  children: [
                    OrnateTopBar(title: title, onBack: () => Navigator.of(context).maybePop()),
                    const SizedBox(height: 10),
                    ...(_stage == _Stage.entry ? _entry() : _resultView()),
                  ],
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OrnateTopBar(
                          title: title,
                          onBack: fight ? null : () => Navigator.of(context).maybePop()),
                      const SizedBox(height: 8),
                      Expanded(
                        child: switch (_stage) {
                          _Stage.soldier => _battleView(),
                          _Stage.guardian => SkyTurnView(
                              key: const Key('skyTurnView'),
                              controller: _c,
                              turn: _turn!,
                              fast: _c.fastBattle,
                              stepDelay: widget.turnStep,
                              onFinished: _guardianDone,
                            ),
                          _ => SkyWalkView(
                              key: ValueKey('skyWalk$_walkNo'),
                              controller: _c,
                              firstLine: _walkNews,
                              onSoldier: _soldier,
                              onWake: _wake,
                              onEnd: _endClimb,
                            ),
                        },
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _bottom(Widget child) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x000F1233), AppColors.deepNight],
            stops: [0, 0.35],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: SafeArea(top: false, child: child),
      );

  Widget _battleView() => BattleView(
        battle: _battle!,
        fit: true,
        jobSkills: _c.battleBarJobSlots,
        bar: _c.battleBar,
        emptySlots: _c.skillPageOpen,
        jobMp: () => _c.jobMp,
        onJobSkill: _c.payBattleSkill,
        onMasterySkill: _c.payMasterySkill,
        background: _bg,
        onFinished: _soldierDone,
        tickInterval: widget.tickInterval,
        playerName: _c.profile.name,
        look: _c.profile.look,
        heroJob: _c.heroJobArt, // 묶음 76 #307
        vibrate: _c.vibrate,
        sound: _c.sound,
        hour: _c.now.hour,
        season: SeasonRules.of(_c.now),
        weapon: weaponKindOf(_c.armory.wornIn(EquipSlot.weapon)?.base),
        fast: _c.fastBattle,
        onFastChanged: _c.setFastBattle,
        onAutoChanged: (hp, cure) => _c.setAutoUse(hpPercent: hp, cure: cure),
        poisonTip: !_c.poisonTipSeen,
        onPoisonTipShown: _c.markPoisonTipSeen,
        aura: switch (_c.gear.sets.look) {
          final set? => Color(BossGearRules.info(set).aura),
          null => null,
        },
      );

  Widget _picture({double height = 240, Widget? child}) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFBFD8EA)),
          ),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(_bg,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF1B2A40))),
            if (child != null) Center(child: child),
          ]),
        ),
      );

  // ───────────── 입구

  String get _entryLine {
    final s = _island;
    if (_line != null) return _line!;
    if (s == null) return '섬이 구름 속으로 사라졌어. 다음에 또 떠오를 거야.';
    if (s.cleared) return '수호자가 우리를 인정해 줬어. 이 섬은 문을 닫았어.';
    if (_c.hp <= 0) return '많이 지쳤어. 여관에서 쉬거나 물약을 마시고 오자.';
    if (!_c.canFightNow) return '움직이는 중엔 위험해! 멈춰 서서 오르자.';
    if (_c.skyFeathers < 1) return '하늘 깃털이 없어. 걷다 보면 바람에 실려 올 거야.';
    return '구름 위 세 층을 지나면 꼭대기 제단에 수호자가 있어. 가 볼까?';
  }

  List<Widget> _entry() {
    final i = _info;
    return [
      BulssiLine(
          line: _entryLine,
          mood: _c.hp <= 0 ? SpiritMood.worried : SpiritMood.normal),
      const SizedBox(height: 10),
      _picture(
        child: i == null
            ? null
            : MonsterPicture(
                key: const Key('skyEntryArt'), monster: i.guardian, size: 200),
      ),
      const SizedBox(height: 12),
      if (i != null)
        OrnatePanel(
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElementIcon(i.element, size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(Monsters.info(i.guardian).name,
                    style: AppText.title(20, color: AppColors.text)),
              ),
            ]),
            const SizedBox(height: 6),
            KText('수호자의 특별한 공격 「${i.moveName}」',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const MaterialIcon(MaterialId.skyFeather, size: 26),
              const SizedBox(width: 6),
              Text('하늘 깃털 ${_c.skyFeathers}개',
                  key: const Key('skyFeathers'),
                  style: const TextStyle(color: AppColors.goldBright, fontSize: 14)),
              const SizedBox(width: 10),
              Text('· ${_c.skyMinutesLeft}분 남음',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ]),
          ]),
        ),
    ];
  }

  Widget _entryButton() {
    final s = _island;
    final ok = s != null &&
        !s.cleared &&
        _c.hp > 0 &&
        _c.canFightNow &&
        _c.canClimb;
    return GoldButton(
      key: const Key('skyClimb'),
      label: s == null
          ? '섬이 사라졌어요'
          : s.cleared
              ? '수호자가 인정해 줬어요'
              : _c.hp <= 0
                  ? 'HP가 없어요 · 쉬고 오세요'
                  : '하늘 깃털 1개로 오르기',
      onPressed: ok ? _climb : null,
    );
  }

  // ───────────── 결과

  Widget _sumPanel(SkyClimbSummary s) {
    final i = _info;
    Widget item(Widget icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          icon,
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: AppColors.text, fontSize: 14)),
        ]);
    return OrnatePanel(
      key: const Key('skyClimbSum'),
      child: Column(children: [
        Text('${s.floor}층까지 올랐어요', style: AppText.title(16, color: AppColors.goldBright)),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 14, runSpacing: 6, children: [
          item(MaterialIcon(i?.crystal ?? MaterialId.cloudCrystal, size: 28), '하늘 결정 ${s.crystals}'),
          item(const MaterialIcon(MaterialId.skyStone, size: 28), '하늘 돌 ${s.stones}'),
          item(Image.asset(SkyWalkRules.shardArt, width: 26, height: 26, errorBuilder: (_, __, ___) => const SizedBox()),
              '유물 조각 ${s.shards}'),
        ]),
      ]),
    );
  }

  List<Widget> _resultView() {
    final r = _result;
    final i = _info;
    final sum = _summary;
    if (r == null || !r.won) {
      final line = r != null
          ? '수호자에게 밀려났어. 쉬고 다시 오르자. 얻은 것은 그대로야.'
          : switch (_end) {
              SkyEnd.noWind => '바람이 다했어. 오늘은 여기까지 걸었어.',
              SkyEnd.hpZero => '힘이 다했어. 쉬고 다시 오르자. 얻은 것은 그대로야.',
              SkyEnd.islandGone => '섬이 구름 속으로 떠나. 얼른 내려가자!',
              _ => '구름 아래로 내려왔어. 얻은 것은 그대로야.',
            };
      return [
        BulssiLine(
            key: Key('skyEnd_${r != null ? 'guardian' : _end?.name}'),
            line: line,
            mood: r != null || _end == SkyEnd.hpZero ? SpiritMood.worried : SpiritMood.normal),
        const SizedBox(height: 10),
        _picture(height: 180),
        const SizedBox(height: 10),
        if (sum != null) _sumPanel(sum),
      ];
    }
    return [
      BulssiLine(
          line: i == null ? '해냈어!' : Monsters.info(i.guardian).huntLine,
          mood: SpiritMood.cheer),
      const SizedBox(height: 10),
      const Center(
        child: ArtBanner(
          asset: 'assets/images/banner_clear.webp',
          width: 280,
          aspect: 760 / 302,
          text: '수호자의 인정!',
          textOffset: -0.12,
          fontSize: 22,
        ),
      ),
      const SizedBox(height: 8),
      if (i != null) Center(child: PurifiedMonster(monster: i.guardian, size: 150)),
      if (r.exp > 0) ...[
        const SizedBox(height: 10),
        AshExpPanel(controller: _c, exp: r.exp),
      ],
      const SizedBox(height: 10),
      OrnatePanel(
        key: const Key('skyReward'),
        ornament: true,
        child: Column(children: [
          Text('수호자가 나눠 준 것',
              style: AppText.title(14, color: AppColors.goldBright)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [
              for (final e in r.mats.entries)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  MaterialIcon(e.key, size: 30),
                  const SizedBox(width: 4),
                  Text('${Materials.info(e.key).name} ${e.value}',
                      style: const TextStyle(color: AppColors.text, fontSize: 14)),
                ]),
            ],
          ),
          for (final t in r.titles) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.goldBright),
              const SizedBox(width: 8),
              Text('칭호 「${TitleRules.info(t).name}」',
                  style: AppText.title(15, color: AppColors.text)),
            ]),
          ],
          if (r.inscription case final k?) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('skyStoneAgain'),
              onPressed: () => showSkyInscription(context, k),
              icon: const Icon(Icons.menu_book_rounded,
                  color: AppColors.goldBright),
              label: const Text('비문 다시 보기'),
            ),
          ],
        ]),
      ),
      if (sum != null) ...[
        const SizedBox(height: 10),
        _sumPanel(sum),
      ],
    ];
  }
}

/// 섬 띄우기 (지도에서 누를 때): 걸어서 닿았으면 들어가고, 아니면 「걸어서 가기 · 원정 보내기」 창 (묶음 81 #375)
Future<void> openSkyIsland(BuildContext context, AppController c) async {
  final s = c.skyIsland;
  if (s == null) return;
  Future<void> enter() => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => HighlandScreen(controller: c)));
  if (c.atSkyIsland && !s.cleared) {
    await enter();
    return;
  }
  await showTripSheet(
    context,
    c,
    kind: 'sky',
    title: s.info.place,
    about: s.cleared
        ? '수호자가 우리를 인정해 줬어요. 이 섬은 문을 닫았어요.'
        : '하늘에 섬이 떠 있어요. 걸어서 섬 아래까지 가거나 펫을 보내면 오를 수 있어요 · '
            '${c.skyMinutesLeft}분 뒤 사라져요',
    distanceM: s.cleared ? null : c.skyDistance,
    onEnter: () async {
      if (context.mounted) await enter();
    },
  );
}

/// 비문 한 조각 (묶음 50): 돌판이 떠오르고 → 글귀 → 「기록에 남겨 두기」
Future<void> showSkyInscription(BuildContext context, int index) =>
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC05060F),
      builder: (d) => _InscriptionView(index: index),
    );

class _InscriptionView extends StatefulWidget {
  const _InscriptionView({required this.index});

  final int index;

  @override
  State<_InscriptionView> createState() => _InscriptionViewState();
}

class _InscriptionViewState extends State<_InscriptionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = HighlandRules.isles[widget.index].inscription;
    final w = math.min(340.0, MediaQuery.sizeOf(context).width - 32);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            final rise = Curves.easeOutCubic
                .transform((_a.value / 0.4).clamp(0.0, 1.0));
            final textIn = ((_a.value - 0.4) / 0.45).clamp(0.0, 1.0);
            final done = _a.value >= 1;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Text('하이랜드의 비문 ${widget.index + 1}',
                  key: const Key('skyStoneTitle'),
                  style: AppText.title(15, color: const Color(0xFFDDF3FF))),
              const SizedBox(height: 8),
              Opacity(
                opacity: rise,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - rise)),
                  child: Container(
                    width: w,
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFE6EDF2), Color(0xFFC9D4DD)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD4B26A), width: 2),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66BFE3FF), blurRadius: 24),
                      ],
                    ),
                    child: Opacity(
                      opacity: textIn,
                      child: Text(text,
                          key: const Key('skyStoneText'),
                          textAlign: TextAlign.center,
                          style: AppText.title(17, color: const Color(0xFF22303D))
                              .copyWith(height: 1.6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: done ? 1 : 0.3,
                child: TextButton(
                  key: const Key('skyStoneClose'),
                  onPressed: done ? () => Navigator.pop(context) : null,
                  child: const Text('기록에 남겨 두기'),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// 처음 하늘에 섬이 뜰 때 짧은 장면 (묶음 50 #146). 주인공 한마디 → 첫 펫 두 마디.
/// 끝나면 첫 펫이 주운 하늘 깃털 하나.
class HighlandSceneScreen extends StatefulWidget {
  const HighlandSceneScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HighlandSceneScreen> createState() => _HighlandSceneScreenState();
}

class _HighlandSceneScreenState extends State<HighlandSceneScreen> {
  AppController get c => widget.controller;
  int _line = 0;
  bool _done = false;

  late final List<({String? speaker, bool hero, String line})> _lines = [
    (speaker: c.profile.name, hero: true, line: HighlandRules.sceneHero),
    for (final l in HighlandRules.scenePet)
      (speaker: c.firstPet?.name ?? c.voicePet?.name ?? '펫', hero: false, line: l),
  ];

  @override
  void initState() {
    super.initState();
    c.holdNoticesWhile(true);
  }

  @override
  void dispose() {
    c.holdNoticesWhile(false);
    super.dispose();
  }

  Future<void> _next() async {
    if (_line < _lines.length - 1) {
      setState(() => _line++);
      return;
    }
    if (_done) return;
    _done = true;
    await c.markHighlandScene();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = _lines[_line];
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: const Key('highlandScene'),
        backgroundColor: AppColors.deepNight,
        body: IllustratedScene(
          key: ValueKey('skyScene$_line'),
          image: HighlandRules.scene,
          speaker: l.speaker,
          // 묶음 81 #376: 주인공은 오른쪽 얼굴, 펫은 왼쪽 얼굴 (꼬리 없음)
          who: l.hero ? SceneWho.hero(c.profile.look) : SceneWho.petOr(c.firstPet ?? c.voicePet),
          line: l.line,
          lineKey: 'skyScene-$_line',
          onNext: _next,
        ),
      ),
    );
  }
}
