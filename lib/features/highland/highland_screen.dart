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

enum _Stage { entry, path, battle, result }

/// 섬 안 칸: 입구 → 첫 갈림길 → 둘째 갈림길 → 수호자 앞
const List<String> _steps = ['입구', '첫 갈림길', '둘째 갈림길', '수호자 앞'];

/// 하이랜드 (묶음 50 #146): 하늘에 뜬 섬 하나.
/// 오르기(하늘 깃털) → 갈림길 둘(석상의 길 · 폐허의 길) → 수호자 → 결과.
/// 지면 입구로 돌아가 섬이 떠 있는 동안 몇 번이든 다시 (깃털은 처음 한 번만).
class HighlandScreen extends StatefulWidget {
  const HighlandScreen({
    super.key,
    required this.controller,
    this.tickInterval = const Duration(milliseconds: 900),
  });

  final AppController controller;
  final Duration tickInterval;

  @override
  State<HighlandScreen> createState() => _HighlandScreenState();
}

class _HighlandScreenState extends State<HighlandScreen> {
  _Stage _stage = _Stage.entry;

  /// 지금 칸 (1 첫 갈림길 · 2 둘째 갈림길 · 3 수호자 앞)
  int _step = 1;
  Battle? _battle;
  bool _guardianFight = false;

  /// 갈림길에서 방금 일어난 일 (다음 칸으로 넘어가기 전 한 줄)
  String? _forkLine;
  Map<MaterialId, int> _forkMats = const {};
  int _forkGold = 0;

  SkyResult? _result;
  String? _line;
  /// 들어올 때 섬 (그사이 섬이 사라져도 그림·이름은 그대로)
  late final IsleInfo? _info = widget.controller.skyIsland?.info;

  AppController get _c => widget.controller;
  SkyIsland? get _island => _c.skyIsland;

  @override
  void initState() {
    super.initState();
    _c.holdNoticesWhile(true);
  }

  @override
  void dispose() {
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
      _stage = _Stage.path;
      _step = 1;
      _forkLine = null;
      _line = _c.takeFirstClimbLine();
    });
  }

  // ───────────── 갈림길

  Future<void> _ruins() async {
    final r = await _c.searchRuins();
    if (r == null || !mounted) return;
    setState(() {
      _line = null;
      _forkMats = r.mats;
      _forkGold = r.gold;
      _forkLine = switch (r.find) {
        RuinsFind.chest => '무너진 기둥 사이에서 낡은 상자를 찾았어!',
        RuinsFind.feather => '바람에 실려 온 하늘 깃털이 걸려 있었어!',
        RuinsFind.empty => '조용한 폐허야. 이번엔 아무것도 없었어.',
      };
    });
  }

  void _fight({required bool guardian}) {
    final b = guardian ? _c.startGuardianBattle() : _c.startSoldierBattle();
    if (b == null) return;
    setState(() {
      _battle = b;
      _guardianFight = guardian;
      _stage = _Stage.battle;
    });
  }

  Future<void> _finish() async {
    final b = _battle!;
    final r = _guardianFight
        ? await _c.finishGuardianBattle(b)
        : await _c.finishSoldierBattle(b);
    if (!mounted) return;
    if (!r.won) {
      // 지면 입구로 (섬이 떠 있는 동안 깃털 없이 다시)
      setState(() {
        _stage = _Stage.entry;
        _line = '이번엔 물러났어. 쉬고 다시 오르자. 갈림길도 다시 고를 수 있어.';
      });
      return;
    }
    if (!_guardianFight) {
      setState(() {
        _stage = _Stage.path;
        _line = null;
        _forkMats = r.mats;
        _forkGold = 0;
        _forkLine = '석상 병사가 길을 비켜 줬어!';
      });
      return;
    }
    setState(() {
      _result = r;
      _stage = _Stage.result;
    });
    if (r.inscription case final i?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSkyInscription(context, i);
      });
    }
  }

  void _next() => setState(() {
        _step++;
        _forkLine = null;
        _forkMats = const {};
        _forkGold = 0;
      });

  // ───────────── 화면

  String get _bg => _info?.background ?? 'assets/images/bg_highland_wind.webp';

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final title = _info?.place ?? '하이랜드';
    return Scaffold(
      key: const Key('highlandScreen'),
      backgroundColor: AppColors.deepNight,
      bottomNavigationBar: switch (_stage) {
        _Stage.entry => _bottom(_entryButton()),
        _Stage.result => _bottom(FrameButton(
            key: const Key('skyBack'),
            label: '내려가기',
            onPressed: () => Navigator.of(context).pop())),
        _Stage.path => _forkLine != null || _step >= 3
            ? _bottom(_pathButton())
            : null,
        _Stage.battle => null,
      },
      body: NightBackground(
        child: _stage == _Stage.battle
            ? Padding(
                padding:
                    EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OrnateTopBar(title: title, onBack: null),
                    const SizedBox(height: 10),
                    Expanded(child: _battleView()),
                  ],
                ),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 28),
                children: [
                  OrnateTopBar(
                      title: title,
                      onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 10),
                  ...switch (_stage) {
                    _Stage.entry => _entry(),
                    _Stage.path => _path(),
                    _ => _resultView(),
                  },
                ],
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
        jobSkills: _c.battleJobSlots,
        emptySlots: _c.skillPageOpen,
        jobMp: () => _c.jobMp,
        onJobSkill: _c.payBattleSkill,
        onMasterySkill: _c.payMasterySkill,
        background: _bg,
        onFinished: _finish,
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
    if (s.climbed) return '아직 섬이 떠 있어. 다시 올라가 보자!';
    if (_c.skyFeathers < 1) return '하늘 깃털이 없어. 걷다 보면 바람에 실려 올 거야.';
    return '하늘 깃털이 있으면 올라갈 수 있어. 가 볼까?';
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
                  : s.climbed
                      ? '다시 오르기'
                      : '하늘 깃털 1개로 오르기',
      onPressed: ok ? _climb : null,
    );
  }

  // ───────────── 길

  Widget _progress() => Row(children: [
        for (var k = 0; k < _steps.length; k++) ...[
          if (k > 0)
            Expanded(
              child: Container(
                height: 2,
                color: k <= _step
                    ? AppColors.goldBright
                    : AppColors.textMuted.withValues(alpha: 0.4),
              ),
            ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              key: Key('skyStep_$k'),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: k < _step
                    ? AppColors.goldBright
                    : k == _step
                        ? Color(_info?.color ?? 0xFFFFFFFF)
                        : AppColors.abyss,
                border: Border.all(color: AppColors.goldBright),
              ),
            ),
            const SizedBox(height: 4),
            Text(_steps[k],
                style: TextStyle(
                    color: k == _step ? AppColors.text : AppColors.textMuted,
                    fontSize: 11)),
          ]),
        ],
      ]);

  List<Widget> _path() {
    final i = _info;
    final atGuardian = _step >= 3;
    return [
      BulssiLine(
          line: _line ??
              (atGuardian
                  ? '수호자가 기다리고 있어. 우리를 시험하려는 거야.'
                  : _forkLine ?? '길이 둘로 갈라져. 어느 쪽으로 갈까?'),
          mood: SpiritMood.normal),
      const SizedBox(height: 10),
      OrnatePanel(child: _progress()),
      const SizedBox(height: 10),
      if (atGuardian)
        _picture(
          child: i == null
              ? null
              : MonsterPicture(
                  key: const Key('skyGuardianArt'),
                  monster: i.guardian,
                  size: 200),
        )
      else if (_forkLine != null)
        OrnatePanel(
          key: const Key('skyForkResult'),
          child: Column(children: [
            KText(_forkLine!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text, fontSize: 15)),
            if (_forkGold > 0 || _forkMats.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (_forkGold > 0)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const GameIcon('gold', size: 22),
                      const SizedBox(width: 4),
                      Text('금화 $_forkGold',
                          style: const TextStyle(color: AppColors.goldBright)),
                    ]),
                  for (final e in _forkMats.entries)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      MaterialIcon(e.key, size: 26),
                      const SizedBox(width: 4),
                      Text('${Materials.info(e.key).name} ${e.value}',
                          style: const TextStyle(color: AppColors.text)),
                    ]),
                ],
              ),
            ],
          ]),
        )
      else ...[
        _forkCard(
          key: const Key('skyForkStone'),
          title: '석상의 길',
          line: '작은 석상 병사가 길을 지켜요. 이기면 하늘 재료를 조금 얻어요.',
          art: MonsterPicture(
              monster: MonsterId.stoneSoldier, size: 72, tint: i?.color),
          onTap: _c.hp > 0 && _c.canFightNow
              ? () => _fight(guardian: false)
              : null,
        ),
        const SizedBox(height: 10),
        _forkCard(
          key: const Key('skyForkRuins'),
          title: '폐허의 길',
          line: '싸움 없이 폐허를 살펴요. 운이 좋으면 무언가 남아 있어요.',
          art: const Icon(Icons.account_balance_rounded,
              size: 52, color: Color(0xFFDDE7F0)),
          onTap: _ruins,
        ),
      ],
    ];
  }

  Widget _forkCard({
    required Key key,
    required String title,
    required String line,
    required Widget art,
    required VoidCallback? onTap,
  }) =>
      Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: GestureDetector(
          key: key,
          onTap: onTap,
          child: OrnatePanel(
            child: Row(children: [
              SizedBox(width: 76, height: 76, child: Center(child: art)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.title(17, color: AppColors.text)),
                    const SizedBox(height: 4),
                    KText(line,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.goldBright),
            ]),
          ),
        ),
      );

  Widget _pathButton() {
    if (_step >= 3) {
      final ok = _c.hp > 0 && _c.canFightNow;
      return GoldButton(
        key: const Key('skyGuardian'),
        label: _c.hp <= 0 ? 'HP가 없어요 · 쉬고 오세요' : '수호자에게 도전하기',
        onPressed: ok ? () => _fight(guardian: true) : null,
      );
    }
    return GoldButton(
      key: const Key('skyNext'),
      label: _step == 2 ? '수호자 앞으로' : '다음 갈림길로',
      onPressed: () {
        _line = null;
        _next();
      },
    );
  }

  // ───────────── 결과

  List<Widget> _resultView() {
    final r = _result!;
    final i = _info;
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
