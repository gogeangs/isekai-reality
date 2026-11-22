import '../pets/egg_news.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/armory.dart' show EquipItem;
import '../../core/rules/rules.dart';
import '../../data/storage/record_store.dart' show HeroLook;
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../map/trip_sheet.dart';
import '../awakening/awakening_screen.dart' show IllustratedScene, SceneWho;
import '../battle/battle_view.dart';
import '../battle/dungeon_screen.dart' show confirmStopResting;
import '../battle/element_view.dart';
import '../battle/hero_rig.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart' show SpiritMood;
import '../smithy/equipment_view.dart';
import 'ash_turn_view.dart';
import '../smithy/equip_now_button.dart';

enum _Stage { entry, battle, result }

/// 2막 (묶음 34): 잿빛 틈의 분신 한 판 · 던전 끝 「문 앞」의 잿빛 군주.
/// 입장 → 전투(층 없이 보스만, 본체는 감정 단계 다섯) → 결과.
class AshBattleScreen extends StatefulWidget {
  const AshBattleScreen({
    super.key,
    required this.controller,
    this.king = false,
    this.tickInterval = const Duration(milliseconds: 900),
  });

  final AppController controller;

  /// true 면 본체 (잿빛 군주)
  final bool king;
  final Duration tickInterval;

  @override
  State<AshBattleScreen> createState() => _AshBattleScreenState();
}

class _AshBattleScreenState extends State<AshBattleScreen> {
  _Stage _stage = _Stage.entry;
  Battle? _battle;

  /// 묶음 82 #394: 분신은 턴제 (본체는 자동 전투 그대로)
  AshTurn? _turn;
  AshResult? _result;

  /// 이번 판에 본 기억으로 왕의 기억을 다 봤는지 (끝 장면 「○○이 잠잠해졌어」)
  bool _calm = false;

  /// 묶음 75 #327: 이 싸움에서 얻은 알 등급
  EggGrade? _egg;
  late final AshAvatar? _avatar = widget.controller.nextAvatar;

  AppController get _c => widget.controller;
  bool get _king => widget.king;

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

  Future<void> _start() async {
    if (_c.resting) {
      final ok = await confirmStopResting(context);
      if (!ok || !mounted) return;
    }
    if (!_king) {
      final t = _c.startAshTurn();
      if (t == null) return;
      setState(() {
        _turn = t;
        _stage = _Stage.battle;
      });
      return;
    }
    final b = _c.startKingBattle();
    if (b == null) return;
    setState(() {
      _battle = b;
      _stage = _Stage.battle;
    });
  }

  Future<void> _finish() async {
    final t = _turn;
    final AshResult r;
    if (t != null) {
      r = await _c.finishAshTurn(t);
      _calm = r.won && t.allMemories;
    } else {
      final b = _battle!;
      r = _king ? await _c.finishKingBattle(b) : await _c.finishAshBattle(b);
    }
    if (!mounted) return;
    if (_king && r.won) {
      // 결말 「문을 다리로」: 본체를 쓰러뜨린 직후, 건너뛰기 없이 한 번
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => EndingScreen(controller: _c, reward: r)));
      return;
    }
    setState(() {
      _result = r;
      _stage = _Stage.result;
      _egg = r.egg ? (_c.takeBattleEgg() ?? EggGrade.common) : null;
    });
    // 묶음 82: 턴제는 마주하기로 본 기억이 사연 (따로 창을 띄우지 않음)
    if (t == null && r.won && r.story != null) {
      final i = Act2Rules.avatars.indexWhere((a) => a.story == r.story);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && i >= 0) showKingStory(context, i, seen: _c.act2.memoriesOf(i));
      });
    }
  }

  String get _bg => _king
      ? 'assets/images/bg_boss_gate.webp'
      : switch (_avatar) {
          AshAvatar.rage => 'assets/images/bg_boss_flame.webp',
          AshAvatar.sorrow => 'assets/images/bg_boss_frost.webp',
          AshAvatar.greed => 'assets/images/bg_boss_warden.webp',
          AshAvatar.fear => 'assets/images/bg_boss_night.webp',
          _ => 'assets/images/bg_boss_storm.webp',
        };

  String get _title => _king
      ? '문 앞'
      : _avatar == null
          ? '잿빛 틈'
          : Act2Rules.info(_avatar).name;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('ashBattleScreen'),
      backgroundColor: AppColors.deepNight,
      bottomNavigationBar: switch (_stage) {
        _Stage.entry => _bottom(_entryButton()),
        _Stage.result => _bottom(FrameButton(
            key: const Key('ashBack'),
            label: '돌아가기',
            onPressed: () => Navigator.of(context).pop())),
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
                    OrnateTopBar(title: _title, onBack: null),
                    const SizedBox(height: 10),
                    Expanded(
                        child: _turn != null
                            ? AshTurnView(
                                key: const Key('ashTurnView'),
                                controller: _c,
                                turn: _turn!,
                                background: _bg,
                                fast: _c.fastBattle,
                                onFinished: _finish,
                              )
                            : _battleView()),
                  ],
                ),
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 28),
                children: [
                  OrnateTopBar(
                      title: _title,
                      onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 10),
                  ...(_stage == _Stage.entry ? _entry() : _resultView()),
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

  // ───────────── 입장

  String get _entryLine {
    if (_c.hp <= 0) return '많이 지쳤어. 여관에서 쉬거나 물약을 마시고 오자.';
    if (!_c.canFightNow) return '움직이는 중엔 위험해! 멈춰 서서 들어가자.';
    if (_king) {
      return _c.act2.kingPhase > 0
          ? '안개가 조금 걷혀 있어. 지난번에 걷어 낸 데서부터야.'
          : '문 너머에서 왕이 기다리고 있어. 같이 가자.';
    }
    if (_c.riftClosedToday) return '오늘은 틈이 닫혔어. ${Act2Rules.closedLine}.';
    return '왕의 기운이 느껴져. 준비됐어?';
  }

  List<Widget> _entry() {
    final a = _avatar;
    final phase = _c.act2.kingPhase;
    final monster = _king ? MonsterId.ashKing : a == null ? null : Act2Rules.info(a).monster;
    final element = _king
        ? Act2Rules.avatars[phase.clamp(0, 4)].element
        : a == null
            ? null
            : Act2Rules.info(a).element;
    return [
      BulssiLine(
          line: _entryLine,
          mood: _c.hp <= 0 ? SpiritMood.worried : SpiritMood.normal),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB9B2C9)),
          ),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset(_bg,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF1B1840))),
            if (monster != null)
              Center(
                child: MonsterPicture(
                    key: const Key('ashEntryArt'),
                    monster: monster,
                    size: 210,
                    reveal: _king ? phase / 4 : null),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      OrnatePanel(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (element != null) ...[
              ElementIcon(element, size: 22),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(_king ? Act2Rules.kingName : _title,
                  style: AppText.title(21, color: AppColors.text)),
            ),
          ]),
          const SizedBox(height: 6),
          if (_king)
            KText(
                phase > 0
                    ? '감정 ${5 - phase}개가 남았어요 · 걷어 낸 곳부터 이어서'
                    : '분노 · 슬픔 · 탐욕 · 두려움 · 외로움을 차례로 걷어 내요',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13))
          else if (a != null)
            KText('특별한 공격 「${Act2Rules.info(a).moveName}」',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          if (!_king) ...[
            const SizedBox(height: 4),
            Text(
                _c.riftClosedToday
                    ? Act2Rules.closedLine
                    : '오늘 남은 도전 ${_c.riftTriesLeft}번',
                key: const Key('ashTries'),
                style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
          ],
        ]),
      ),
    ];
  }

  Widget _entryButton() {
    final ok = _c.hp > 0 &&
        _c.canFightNow &&
        (_king ? _c.kingOpen : _avatar != null && !_c.riftClosedToday);
    return GoldButton(
      key: const Key('ashEnter'),
      label: _c.hp <= 0
          ? 'HP가 없어요 · 쉬고 오세요'
          : !_king && _c.riftClosedToday
              ? Act2Rules.closedLine
              : _king
                  ? '문을 열기'
                  : '잿빛 틈에 들어가기',
      onPressed: ok ? _start : null,
    );
  }

  // ───────────── 결과

  List<Widget> _resultView() {
    final r = _result!;
    final a = _avatar;
    final info = a == null ? null : Act2Rules.info(a);
    final String line;
    if (r.won) {
      line = info == null
          ? '해냈어!'
          : Monsters.info(info.monster).huntLine;
    } else if (_king) {
      line = r.phasesCleared > 0
          ? '안개가 조금 걷혔어. 쉬고 와서 이어서 하자.'
          : '이번엔 물러났어. 쉬고 다시 오자.';
    } else {
      line = _c.riftClosedToday
          ? '오늘은 틈이 닫혔어. ${Act2Rules.closedLine}.'
          : '이번엔 물러났어. 쉬고 다시 오자.';
    }
    return [
      BulssiLine(
          line: line, mood: r.won ? SpiritMood.cheer : SpiritMood.worried),
      const SizedBox(height: 10),
      Center(
        child: ArtBanner(
          asset: 'assets/images/banner_clear.webp',
          width: 280,
          aspect: 760 / 302,
          text: !r.won
              ? '이번엔 물러났어요'
              : _calm && a != null
                  ? '${josa(AshTurnRules.info(a).emotion, '이/가')} 잠잠해졌어'
                  : '잠재웠어요!',
          textOffset: -0.12,
          fontSize: 22,
        ),
      ),
      const SizedBox(height: 8),
      if (info != null)
        Center(
          child: r.won
              ? PurifiedMonster(monster: info.monster, size: 150)
              : MonsterPicture(monster: info.monster, size: 150),
        ),
      // 묶음 82 #394: 왕의 기억을 다 보고 이기면 왕의 마지막 한마디, 덜 봤으면 몇 조각 봤는지
      if (r.won && _turn != null && a != null) ...[
        const SizedBox(height: 8),
        OrnatePanel(
          child: _calm
              ? KText(AshTurnRules.info(a).lastWord,
                  key: const Key('ashLastWord'),
                  textAlign: TextAlign.center,
                  style: AppText.title(16, color: AppColors.text).copyWith(height: 1.6))
              : KText(
                  '왕의 기억 ${_c.act2.memoriesOf(a.index)} / 3 · 못 본 기억은 「왕의 사연 다시 보기」에서 빈칸으로 남아요',
                  key: const Key('ashMemoryCount'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
      ],
      if (r.exp > 0) ...[
        const SizedBox(height: 10),
        AshExpPanel(controller: _c, exp: r.exp),
      ],
      if (r.won && r.firstKill) ...[
        const SizedBox(height: 10),
        OrnatePanel(
          ornament: true,
          child: Column(children: [
            // 묶음 75 #327: 알은 보상 칸 맨 앞에 크게
            if (_egg case final g?) ...[
              EggGotBanner(grade: g, farewell: _c.farewellDone),
              const SizedBox(height: 8),
            ],
            if (r.item case final item?) ...[
              Text('유품 장비', style: AppText.title(14, color: AppColors.goldBright)),
              const SizedBox(height: 6),
              Row(children: [
                EquipIcon(base: item.base, grade: item.grade, size: 56),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EquipName(item, size: 16),
                      ItemStats(item, fontSize: 13),
                    ],
                  ),
                ),
                EquipNowButton(
                  key: const Key('ashEquip'),
                  controller: _c,
                  item: item,
                  onEquipped: () => setState(() {}),
                ),
              ]),
            ],
            if (r.title case final t?) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.goldBright),
                const SizedBox(width: 8),
                Text('칭호 「${TitleRules.info(t).name}」',
                    style: AppText.title(15, color: AppColors.text)),
              ]),
            ],

            if (r.story != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                key: const Key('ashStoryAgain'),
                onPressed: () {
                  final i =
                      Act2Rules.avatars.indexWhere((x) => x.story == r.story);
                  if (i >= 0) showKingStory(context, i, seen: _c.act2.memoriesOf(i));
                },
                icon: const Icon(Icons.menu_book_rounded,
                    color: AppColors.goldBright),
                label: const Text('왕의 사연 다시 보기'),
              ),
            ],
          ]),
        ),
      ],
      if (!r.won && !_king && !_c.riftClosedToday) ...[
        const SizedBox(height: 10),
        Center(
          child: Text('오늘 남은 도전 ${_c.riftTriesLeft}번',
              style: const TextStyle(color: AppColors.goldBright, fontSize: 14)),
        ),
      ],
    ];
  }
}

/// 잿빛 틈 띄우기 (지도에서 누를 때): 걸어서 닿았으면 들어가고, 아니면 「걸어서 가기 · 원정 보내기」 창 (묶음 81 #375)
Future<void> openRift(BuildContext context, AppController c) async {
  Future<void> enter() => Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AshBattleScreen(controller: c)));
  if (c.atRift) {
    await enter();
    return;
  }
  final a = c.nextAvatar;
  if (a == null) return;
  final waiting = c.tripWaiting('rift');
  await showTripSheet(
    context,
    c,
    kind: 'rift',
    title: '잿빛 틈',
    about: c.riftClosedToday && !waiting
        ? '${Act2Rules.info(a).name}의 기운이 잦아들었어요. ${Act2Rules.closedLine}.'
        : '${Act2Rules.info(a).name}의 기운이 새어 나와요. 걸어서 가까이 가거나 펫을 보내면 들어갈 수 있어요.',
    distanceM: c.riftDistance,
    onEnter: () async {
      if (context.mounted) await enter();
    },
  );
}

/// 왕의 사연 한 조각 (묶음 34): 양피지가 펼쳐지고 → 글귀 → 「기록에 남겨 두기」
/// 묶음 82 #394: 사연은 왕의 기억 세 조각 — 못 본 조각은 빈칸 「아직 보지 못한 기억」
Future<void> showKingStory(BuildContext context, int index, {int seen = 3}) => showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC05060F),
      builder: (d) => _KingStoryView(index: index, seen: seen),
    );

class _KingStoryView extends StatefulWidget {
  const _KingStoryView({required this.index, this.seen = 3});

  final int index;
  final int seen;

  @override
  State<_KingStoryView> createState() => _KingStoryViewState();
}

class _KingStoryViewState extends State<_KingStoryView>
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
    final mem = AshTurnRules.info(AshAvatar.values[widget.index.clamp(0, 4)]).memories;
    final w = math.min(340.0, MediaQuery.sizeOf(context).width - 32);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _a,
          builder: (context, _) {
            final open = Curves.easeOutCubic
                .transform((_a.value / 0.4).clamp(0.0, 1.0));
            final textIn = ((_a.value - 0.4) / 0.45).clamp(0.0, 1.0);
            final done = _a.value >= 1;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Text('왕의 사연 ${widget.index + 1}',
                  key: const Key('kingStoryTitle'),
                  style: AppText.title(15, color: AppColors.goldBright)),
              const SizedBox(height: 8),
              ClipRect(
                child: Align(
                  widthFactor: 0.15 + 0.85 * open,
                  child: ParchmentSheet(
                    width: w,
                    tint: const Color(0xFFB9B2C9), fallback: const Color(0xFFD9D3E2),
                    child: Opacity(
                      opacity: textIn,
                      child: Column(key: const Key('kingStoryText'), mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 0; i < mem.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          i < widget.seen
                              ? Text(mem[i],
                                  key: Key('kingMemory_$i'),
                                  textAlign: TextAlign.center,
                                  style: AppText.title(16, color: const Color(0xFF2A2433)).copyWith(height: 1.55))
                              : Text('아직 보지 못한 기억',
                                  key: Key('kingMemoryBlank_$i'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0x992A2433), fontSize: 13, fontStyle: FontStyle.italic)),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: done ? 1 : 0.3,
                child: TextButton(
                  key: const Key('kingStoryClose'),
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

/// 결말 「문을 다리로」 (묶음 34): 본체를 쓰러뜨린 직후 한 번, 건너뛰기 없음.
/// 대사창 꼬리·이름표는 이별 컷신과 같은 방식. 끝나면 본체 보상.
class EndingScreen extends StatefulWidget {
  const EndingScreen({super.key, required this.controller, this.reward});

  final AppController controller;

  /// 방금 받은 보상 (도중에 껐다가 다시 볼 때는 null)
  final AshResult? reward;

  @override
  State<EndingScreen> createState() => _EndingScreenState();
}

class _EndingScreenState extends State<EndingScreen> {
  AppController get c => widget.controller;
  int _line = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // 결말 동안 칭호 축하 같은 창은 미룬다 (끝난 뒤 차례로)
    c.holdNoticesWhile(true);
  }

  @override
  void dispose() {
    c.holdNoticesWhile(false);
    super.dispose();
  }

  late final _lines = Act2Rules.ending(
    hero: c.profile.name,
    spirit: c.firstSpiritName,
    pet: c.firstPet?.name ?? c.voicePet?.name ?? '펫',
    female: c.profile.look == HeroLook.female,
  );

  Future<void> _next() async {
    if (_line < _lines.length - 1) {
      setState(() => _line++);
      return;
    }
    await c.markEndingSeen();
    if (c.bridgePending) await c.markBridgeShown();
    if (mounted) setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: const Key('endingScreen'),
        backgroundColor: AppColors.deepNight,
        body: _done ? _rewardView() : _scene(),
      ),
    );
  }

  Widget _scene() {
    final l = _lines[_line];
    return IllustratedScene(
      key: ValueKey('ending$_line'),
      image: l.image,
      speaker: l.speaker,
      // 묶음 81 #376: 주인공 · 펫 얼굴, 왕은 이름 칩만
      who: l.hero
          ? SceneWho.hero(c.profile.look)
          : l.pet
              ? SceneWho.petOr(c.firstPet ?? c.voicePet)
              : const SceneWho.name(),
      dialogTop: l.top,
      line: l.line,
      lineKey: 'ending-$_line',
      onNext: _next,
    );
  }

  Widget _rewardView() {
    final crown = c.armory.items
        .where((i) => i.base == Act2Rules.kingGear)
        .fold<EquipItem?>(null, (a, b) => b);
    final lv = c.player.level.level;
    return NightBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
           child: Padding(
            padding: const EdgeInsets.all(20),
            child: OrnatePanel(
              key: const Key('endingReward'),
              ornament: true,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('문을 다리로', style: AppText.title(22)),
                const SizedBox(height: 12),
                if (crown != null) ...[
                  EquipIcon(base: crown.base, grade: crown.grade, size: 88),
                  const SizedBox(height: 6),
                  EquipName(crown, size: 17),
                  ItemStats(crown, fontSize: 13),
                  const SizedBox(height: 10),
                ],
                AshExpPanel(controller: c, exp: Act2Rules.kingExp),
                const SizedBox(height: 10),
                Text('칭호 「${TitleRules.info(Act2Rules.kingTitle).name}」',
                    style: AppText.title(16, color: AppColors.goldBright)),
                if (lv >= Act2Rules.bridgeLevel) ...[
                  const SizedBox(height: 12),
                  const KText(Act2Rules.bridgeLine,
                      key: Key('bridgeLine'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.text, fontSize: 15)),
                ],
                const SizedBox(height: 16),
                GoldButton(
                  key: const Key('endingClose'),
                  label: '돌아가기',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
            ),
           ),
          ),
        ),
      ),
    );
  }
}


/// 처음 쓰러뜨릴 때 받은 경험치 · 레벨 막대 (던전 결과와 같은 방식, 묶음 34 확인 답)
class AshExpPanel extends StatelessWidget {
  const AshExpPanel({super.key, required this.controller, required this.exp});

  final AppController controller;
  final int exp;

  @override
  Widget build(BuildContext context) {
    final p = controller.player;
    return OrnatePanel(
      key: const Key('ashExp'),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const GameIcon('exp', size: 28),
          const SizedBox(width: 8),
          Text('경험치 +$exp', style: AppText.title(22)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('Lv.${p.level.level}',
              style: AppText.level(15, color: AppColors.text)),
          const SizedBox(width: 8),
          Expanded(
              child: GlowBar(ratio: p.level.ratio, colors: BarColors.exp)),
          const SizedBox(width: 8),
          Text('${comma(p.level.expIntoLevel)} / ${comma(p.level.expToNext)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ]),
    );
  }
}
