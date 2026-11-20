import '../pets/egg_news.dart';
import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../core/story/dungeon_clues.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart';
import '../town/bag_tab.dart' show openBag, BagFilter;
import '../town/material_view.dart';
import '../pets/pet_art.dart';
import '../../data/storage/record_store.dart' show HeroLook;
import 'battle_view.dart';
import '../act2/ash_battle_screen.dart' show AshBattleScreen;
import 'hero_rig.dart';

enum _Stage { entry, battle, result }

/// 던전: 입장 → 자동 전투(3층 + 보스) → 결과 (목업 구도)
class DungeonScreen extends StatefulWidget {
  const DungeonScreen({
    super.key,
    required this.controller,
    this.tickInterval = const Duration(milliseconds: 900),
  });

  final AppController controller;
  final Duration tickInterval;

  @override
  State<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends State<DungeonScreen> {
  int _clueFloor = 0;
  _Stage _stage = _Stage.entry;
  Battle? _battle;
  bool _atGate = false;
  int _exp = 0;
  Set<MonsterId> _knownBefore = {};

  AppController get _c => widget.controller;

  // 전투·결과 화면이 열려 있는 동안 칭호 축하는 미룬다 (11-11 #85)
  @override
  void initState() {
    super.initState();
    widget.controller.holdNoticesWhile(true);
  }

  @override
  void dispose() {
    widget.controller.holdNoticesWhile(false);
    super.dispose();
  }

  Future<void> _start() async {
    if (_c.resting) {
      final ok = await confirmStopResting(context);
      if (!ok || !mounted) return;
    }
    final atGate = _c.atGate;
    final battle = _c.startDungeon();
    if (battle == null) return;
    setState(() {
      _atGate = atGate;
      _battle = battle;
      _clueFloor = 0;
      _knownBefore = _c.purifiedEver;
      _stage = _Stage.battle;
    });
  }

  Future<void> _finish() async {
    final exp = await _c.finishDungeon(_battle!, atGate: _atGate);
    if (!mounted) return;
    setState(() {
      _exp = exp;
      _stage = _Stage.result;
      // 묶음 75 #327: 이 던전에서 얻은 알 (결과 창 보상 맨 앞)
      _egg = _c.takeBattleEgg();
    });
  }

  EggGrade? _egg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepNight,
      // 입장 화면의 '던전 열기'는 스크롤과 상관없이 화면 아래에 늘 보이게 고정한다
      bottomNavigationBar: _stage == _Stage.entry
          ? _entryButton()
          : _stage == _Stage.result
              ? _resultButtons()
              : null,
      body: NightBackground(
        child: _page([
            OrnateTopBar(
              title: switch (_stage) {
                _Stage.entry => _c.atGate ? '미궁 입구' : '잿빛 던전',
                _Stage.battle => '잿빛 던전',
                _Stage.result => '던전 결과',
              },
              // 전투 중에는 나가지 않게 한다 (중간에 나가면 열쇠를 쓰지 않음)
              onBack: _stage == _Stage.battle
                  ? null
                  : () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 10),
            ...switch (_stage) {
              _Stage.entry => _entry(),
              _Stage.battle => [
                  // 묶음 19 #7: 층마다 정령의 이야기 단서 한 마디 (이별 전까지)
                  if (DungeonClues.lineFor(
                          level: _c.player.level.level,
                          floor: _clueFloor,
                          floors: _battle!.floors.length,
                          farewellDone: _c.farewellDone)
                      case final clue?) ...[
                    BulssiLine(key: const Key('dungeonClue'), line: clue),
                    const SizedBox(height: 6),
                  ],
                  BattleView(
                    battle: _battle!,
                    fit: true,
                    // 묶음 31 #198: 전투 칸 2개
                    jobSkills: _c.battleJobSlots,
                    emptySlots: _c.skillPageOpen,
                    jobMp: () => _c.jobMp,
                    onJobSkill: _c.payBattleSkill,
                    onMasterySkill: _c.payMasterySkill,
                    onFloor: (f) {
                      if (mounted && f != _clueFloor) {
                        setState(() => _clueFloor = f);
                      }
                    },
                    backgroundOf: dungeonBackground,
                    onFinished: _finish,
                    tickInterval: widget.tickInterval,
                    playerName: _c.profile.name,
                    look: _c.profile.look,
                    heroJob: _c.heroJobArt, // 묶음 76 #307
                    vibrate: _c.vibrate,
                    sound: _c.sound,
                    hour: _c.now.hour,
                season: SeasonRules.of(_c.now),
                weapon: weaponKindOf(
                    _c.armory.wornIn(EquipSlot.weapon)?.base),
                    fast: _c.fastBattle,
                    onFastChanged: _c.setFastBattle,
                    onAutoChanged: (hp, cure) =>
                        _c.setAutoUse(hpPercent: hp, cure: cure),
                    poisonTip: !_c.poisonTipSeen,
                    onPoisonTipShown: _c.markPoisonTipSeen,
                    aura: switch (_c.gear.sets.look) {
                      final set? => Color(BossGearRules.info(set).aura),
                      null => null,
                    },
                  ),
                ],
              _Stage.result => _result(),
            },
          ]),
      ),
    );
  }

  /// 묶음 33 #202: 싸우는 동안은 스크롤 없이 한 화면 (전투 장면이 남은 높이에 맞춰 줄어듦)
  Widget _page(List<Widget> children) {
    final pad = MediaQuery.paddingOf(context);
    if (_stage != _Stage.battle) {
      return ListView(
        padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 28),
        children: children,
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in children) c is BattleView ? Expanded(child: c) : c,
        ],
      ),
    );
  }

  // ───────────────────────────────────────────── 입장

  List<Widget> _entry() {
    final player = _c.player;
    final gauge = player.gauge;
    final keys = gauge.keysAvailable;
    final atGate = _c.atGate;
    final canFight = _c.canFightNow;
    final power =
        StatRules.combatPower(level: player.level.level, stats: _c.combatStats);
    final reward = atGate
        ? (RuleConstants.dungeonClearExp * RuleConstants.gateBonusMultiplier)
            .round()
        : RuleConstants.dungeonClearExp;

    final hp = _c.hp;
    final maxHp = _c.maxHp;
    final String line;
    if (hp <= 0) {
      line = '많이 지쳤어. 여관에서 쉬거나 물약을 마시고 오자.';
    } else if (!canFight) {
      line = '움직이는 중엔 위험해! 멈춰 서서 던전을 열자.';
    } else if (keys == 0) {
      line = '열쇠가 없어. ${comma(RuleConstants.stepsPerKey)}보를 걸으면 하나 생겨!';
    } else if (atGate) {
      line = '미궁 입구야! 여기서 열면 보상이 1.5배야.';
    } else if (hp < maxHp * 0.3) {
      line = 'HP가 얼마 안 남았어. 들어가면 쓰러질 수도 있어!';
    } else {
      line = '문이 열려 있어. 준비됐어?';
    }

    return [
      // 11-10 A3: 정령 한 줄은 제목 바로 아래 고정 자리
      BulssiLine(
          line: line,
          mood: hp < maxHp * 0.3 ? SpiritMood.worried : SpiritMood.normal),
      const SizedBox(height: 10),
      // 묶음 34: 분신 다섯을 모두 쓰러뜨리면 던전 끝 「문 앞」이 다시 열린다 (열쇠 없이)
      if (_c.kingOpen) ...[
        _KingGate(controller: _c),
        const SizedBox(height: 10),
      ],
      // HP 0: 지쳐 주저앉은 각성자
      if (hp <= 0) ...[
        SizedBox(
          height: 200,
          child: HeroSprite(look: _c.profile.look, pose: HeroPose.tired),
        ),
        const SizedBox(height: 10),
      ],
      // 미궁 문 그림
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/bg_gate.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF1B1840))),
              if (atGate)
                const Positioned(top: 10, right: 10, child: _GateBonusBadge()),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      // 열쇠
      OrnatePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const GameIcon('key', size: 28),
              const SizedBox(width: 6),
              Text('열쇠 $keys개', style: AppText.title(19, color: AppColors.text)),
              const Spacer(),
              for (var i = 0;
                  i <
                      RuleConstants.maxKeysEarnedPerDay +
                          RuleConstants.goalBonusKeys;
                  i++)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: GameIcon(i < keys ? 'key' : 'key_empty', size: 26),
                ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              const GameIcon('steps', size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  gauge.dailyKeyLimitReached
                      ? '오늘 열쇠는 다 모았어요'
                      : '다음 열쇠 ${comma(gauge.stepsIntoNextKey)} / '
                          '${comma(gauge.stepsPerKey)}보',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                ),
              ),
              Text('전투력 ${comma(power)}',
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            GlowBar(ratio: gauge.ratio, colors: BarColors.exp, height: 8),
            const SizedBox(height: 8),
            Row(children: [
              const GameIcon('vitality', size: 18),
              const SizedBox(width: 6),
              Text('HP ${comma(hp)} / ${comma(maxHp)}',
                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: GlowBar(
                    ratio: maxHp == 0 ? 0 : hp / maxHp,
                    colors: BarColors.hp,
                    height: 8),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                key: const Key('dungeonBag'),
                onPressed: () =>
                    openBag(context, _c, filter: BagFilter.consumable),
                icon: const GameIcon('bag', size: 22),
                label: const Text('가방',
                    style: TextStyle(color: AppColors.goldBright)),
              ),
            ]),
            if (gauge.goalBonusKey || gauge.stepsToGoal != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                GameIcon(gauge.goalBonusKey ? 'check' : 'quest', size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    gauge.goalBonusKey
                        ? '오늘 걸음 목표 달성! 보너스 열쇠 +1'
                        : '걸음 목표까지 ${comma(gauge.stepsToGoal!)}보 · '
                            '채우면 보너스 열쇠 +1',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: gauge.goalBonusKey
                            ? AppColors.goldBright
                            : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      // 층 구성과 보스
      OrnatePanel(
        child: Column(
          children: [
            const _FloorTrack(),
            const SizedBox(height: 8),
            // 오늘의 보스 그림자 (요일마다 바뀐다, 11-11 #75. 일요일은 무작위라 문지기 그림자)
            SizedBox(
              height: 110,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                    Color(0xFF55557A), BlendMode.modulate),
                child: Opacity(
                  opacity: 0.85,
                  child: MonsterPicture(
                      monster: _c.now.weekday == DateTime.sunday
                          ? MonsterId.labyrinthWarden
                          : BattleRules.bossOf(_c.now, atGate: _c.atGate),
                      size: 110),
                ),
              ),
            ),
            Text('???', style: AppText.title(22, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(
              '보상: 클리어 $reward · 실패 ${RuleConstants.dungeonFailExp} 경험치',
              style: const TextStyle(color: AppColors.goldBright, fontSize: 14),
            ),
            // 묶음 70 #296: 하루 상한 없음 — 열쇠 수만
            Text(
              '열쇠 ${player.gauge.keysAvailable}개',
              key: const Key('dungeonKeys'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _entryButton() {
    final keys = _c.player.gauge.keysAvailable;
    final canFight = _c.canFightNow;
    final tired = _c.hp <= 0;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x000F1233), AppColors.deepNight],
          stops: [0, 0.35],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: SafeArea(
        top: false,
        child: GoldButton(
          label: tired
              ? 'HP가 없어요 · 쉬고 오세요'
              : keys > 0
                  ? '던전 열기 · 열쇠 1개'
                  : '열쇠가 없어요',
          onPressed: keys > 0 && canFight && !tired ? _start : null,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────── 결과

  List<Widget> _result() {
    final battle = _battle!;
    final cleared = battle.phase == BattlePhase.cleared;
    final purified = battle.purified.toSet().map(Monsters.info).toList();
    final player = _c.player;
    final line = cleared
        ? (purified.any((m) => m.isBoss)
            ? purified.firstWhere((m) => m.isBoss).huntLine
            : '던전을 돌파했어!')
        : AppController.tiredLine;

    return [
      // 11-10 A3: 정령 한 줄은 제목 바로 아래 고정 자리
      BulssiLine(
          line: line,
          mood: cleared ? SpiritMood.cheer : SpiritMood.worried),
      const SizedBox(height: 8),
      // 묶음 33 #203·#204: 낮은 축하 그림 — 배경 위에 각성자(성별)와 지금 동행(정령·펫)을 겹쳐 그림
      SizedBox(
        height: 190,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, 0.7, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(victoryBackground,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.2),
                      color: cleared ? null : const Color(0x88000000),
                      colorBlendMode: cleared ? null : BlendMode.darken,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            ),
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.gold.withValues(alpha: cleared ? 0.45 : 0.15),
                  Colors.transparent,
                ]),
              ),
            ),
            // 각성자 상반신 정도 (그림 아래쪽은 잘라 냄)
            Positioned(
              key: const Key('victoryHero'),
              bottom: 0,
              height: 150,
              width: 170,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: 230,
                  child: Image.asset(
                      cleared
                          ? victoryHeroAsset(_c.profile.look)
                          : 'assets/images/hero_idle_${_c.profile.look == HeroLook.female ? 'female' : 'male'}.webp',
                      height: 230,
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      errorBuilder: (_, __, ___) => HeroSprite(
                          look: _c.profile.look,
                          pose: cleared ? HeroPose.victory : HeroPose.idle)),
                ),
              ),
            ),
            Positioned(
              key: const Key('victoryBuddy'),
              right: 26,
              bottom: 26,
              child: _victoryBuddy(cleared),
            ),
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Center(
                child: ArtBanner(
                  asset: 'assets/images/banner_clear.webp',
                  width: 280,
                  aspect: 760 / 302,
                  text: cleared ? '던전 돌파!' : '이번엔 물러났어요',
                  textOffset: -0.12,
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      OrnatePanel(
        ornament: true,
        child: Column(
          children: [
            if (_egg case final g?) ...[
              EggGotBanner(grade: g, farewell: _c.farewellDone),
              const SizedBox(height: 6),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GameIcon('exp', size: 28),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _exp > 0 ? '경험치 +$_exp' : '오늘 던전 경험치는 다 받았어요',
                    style: AppText.title(_exp > 0 ? 24 : 16),
                  ),
                ),
                if (_atGate && _exp > 0) ...[
                  const SizedBox(width: 10),
                  const _GateBonusBadge(small: true),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('Lv.${player.level.level}',
                  style: AppText.level(15, color: AppColors.text)),
              const SizedBox(width: 8),
              Expanded(
                  child: GlowBar(
                      ratio: player.level.ratio, colors: BarColors.exp)),
              const SizedBox(width: 8),
              Text(
                  '${comma(player.level.expIntoLevel)} / '
                  '${comma(player.level.expToNext)}',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Text('사냥 ${battle.purified.length} / ${battle.floors.length}',
                  style: AppText.title(14, color: const Color(0xFFCDB8F5))),
              const SizedBox(width: 10),
              // 얻은 것 한 줄 (넘치면 옆으로 넘김, 누르면 이름)
              Expanded(child: RewardStrip(reward: _c.lastReward)),
            ]),
          ],
        ),
      ),
      if (purified.isNotEmpty) ...[
        const SizedBox(height: 8),
        // 도감 새로 등록은 작은 칩 한 줄
        SingleChildScrollView(
          key: const Key('codexChips'),
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Text(
                purified.any((m) => !_knownBefore.contains(m.id))
                    ? '도감에 새로 등록'
                    : '사냥한 몬스터',
                style: AppText.title(13, color: AppColors.goldBright)),
            const SizedBox(width: 8),
            for (final m in purified) ...[
              _MonsterChip(info: m, isNew: !_knownBefore.contains(m.id)),
              const SizedBox(width: 6),
            ],
          ]),
        ),
      ],
    ];
  }

  /// 결과 화면 아래 고정: 남은 열쇠 + 다시 열기 · 돌아가기
  Widget _resultButtons() {
    final keys = _c.player.gauge.keysAvailable;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x000F1233), AppColors.deepNight],
          stops: [0, 0.3],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const GameIcon('key', size: 22),
            const SizedBox(width: 6),
            Text('남은 열쇠 $keys개',
                style: AppText.title(15, color: AppColors.text)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            if (keys > 0 && _c.canFightNow) ...[
              Expanded(
                child: GoldButton(
                  label: '다시 열기 · 열쇠 1개',
                  fontSize: 15,
                  onPressed: () {
                    setState(() => _stage = _Stage.entry);
                    _start();
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FrameButton(
                label: '돌아가기',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  /// 축하 그림 속 동행: 정령(고른 종류의 기뻐하는 그림), 이별 뒤엔 동행 펫
  Widget _victoryBuddy(bool cleared) {
    final pet = _c.companionPet;
    if (_c.farewellDone && pet != null) {
      return PetArt(species: pet.species, adult: pet.adult, size: 70);
    }
    if (_c.farewellDone) return const SizedBox.shrink();
    final kind = _c.profile.spiritKind;
    return Image.asset(
        cleared ? 'assets/images/spirit_${kind.name}_cheer.webp' : spiritAsset(kind),
        width: 70,
        errorBuilder: (_, __, ___) => Image.asset(spiritAsset(kind), width: 70));
  }
}

/// 축하 배경 (묶음 34 확인 답: 사람 없는 새 그림)
const String victoryBackground = 'assets/images/bg_victory.webp';

/// 각성자 성별 축하 그림
String victoryHeroAsset(HeroLook look) =>
    'assets/images/hero_victory_${look == HeroLook.female ? 'female' : 'male'}.webp';

/// 도감 칩 (작게 한 줄)
class _MonsterChip extends StatelessWidget {
  const _MonsterChip({required this.info, required this.isNew});

  final MonsterInfo info;
  final bool isNew;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 10, 3),
        decoration: BoxDecoration(
          color: AppColors.slotBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isNew
                  ? AppColors.goldBright
                  : AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          MonsterPicture(monster: info.id, size: 26),
          const SizedBox(width: 4),
          Text(isNew ? '${info.name} · 새로' : info.name,
              style: TextStyle(
                  color: isNew ? AppColors.goldBright : AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _FloorTrack extends StatelessWidget {
  const _FloorTrack();

  @override
  Widget build(BuildContext context) {
    Widget node(String label, String asset) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/$asset.webp',
                width: 62,
                height: 62,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.door_back_door_rounded,
                    color: AppColors.goldBright)),
            const SizedBox(height: 2),
            Text(label, style: AppText.title(14, color: AppColors.text)),
          ],
        );
    Widget link() => Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.only(bottom: 4),
            color: AppColors.gold.withValues(alpha: 0.6),
          ),
        );
    return Row(
      children: [
        node('1층', 'floor_1'),
        link(),
        node('2층', 'floor_2'),
        link(),
        node('3층', 'floor_3'),
        link(),
        node('보스', 'floor_boss'),
      ],
    );
  }
}

class _GateBonusBadge extends StatelessWidget {
  const _GateBonusBadge({this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    return ArtBanner(
      asset: 'assets/images/badge_gate.webp',
      width: small ? 56 : 92,
      aspect: 240 / 225,
      text: '×1.5',
      textOffset: -0.1,
      fontSize: small ? 15 : 22,
    );
  }
}

/// 여관에서 쉬는 중에 싸우려 할 때 먼저 묻는다
Future<bool> confirmStopResting(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => GameAlert(
      title: Text('휴식을 멈출까요?', style: AppText.title(19)),
      content: const Text(
        '여관에서 쉬는 중이에요. 지금 일어나면 그때까지 찬 HP·기력은 그대로 가지고 가고, '
        '휴식 보너스는 받지 못해요.',
        style: TextStyle(color: AppColors.text, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('계속 쉬기'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('싸우러 가기'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 던전 전투 배경: 일반 1~3층은 입구 돌복도·수정 동굴·깊은 어둠, 보스는 보스마다 방
String dungeonBackground(int floor, Foe foe) {
  if (foe.isBoss) {
    for (final s in BossGearRules.sets) {
      if (s.boss == foe.monster) return 'assets/images/bg_boss_${s.id.name}.webp';
    }
    return 'assets/images/bg_boss_warden.webp';
  }
  return 'assets/images/bg_dungeon_${(floor % 3) + 1}.webp';
}


/// 던전 끝 「문 앞」 (묶음 34): 잿빛 군주에게 가는 길
class _KingGate extends StatelessWidget {
  const _KingGate({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final phase = controller.act2.kingPhase;
    return GestureDetector(
      key: const Key('kingGate'),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              AshBattleScreen(controller: controller, king: true))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFB9B2C9), width: 1.5),
          ),
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/images/bg_boss_gate.webp',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.2),
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF1B1840))),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xCC0B0D26), Color(0x000B0D26)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('문 앞', style: AppText.title(21, color: AppColors.text)),
                      const SizedBox(height: 4),
                      KText(
                          phase > 0
                              ? '잿빛 군주 · 걷어 낸 곳부터 이어서'
                              : '잿빛 군주가 기다리고 있어요',
                          style: const TextStyle(
                              color: Color(0xFFD9D3E2), fontSize: 13)),
                    ],
                  ),
                ),
                MonsterPicture(
                    monster: MonsterId.ashKing, size: 92, reveal: phase / 4),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
