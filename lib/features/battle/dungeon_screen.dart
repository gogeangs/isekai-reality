import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart';
import '../town/bag_sheet.dart';
import '../town/material_view.dart';
import 'battle_view.dart';

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
  _Stage _stage = _Stage.entry;
  Battle? _battle;
  bool _atGate = false;
  int _exp = 0;
  Set<MonsterId> _knownBefore = {};

  AppController get _c => widget.controller;

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      // 입장 화면의 '던전 열기'는 스크롤과 상관없이 화면 아래에 늘 보이게 고정한다
      bottomNavigationBar: _stage == _Stage.entry ? _entryButton() : null,
      body: NightBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
          children: [
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
                  BattleView(
                    battle: _battle!,
                    onFinished: _finish,
                    tickInterval: widget.tickInterval,
                    playerName: _c.profile.name,
                    look: _c.profile.look,
                  ),
                ],
              _Stage.result => _result(),
            },
          ],
        ),
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
    } else if (!_c.dungeonExpLeftToday) {
      line = '오늘 경험치는 다 받았어. 열쇠는 내일을 위해 아껴 둘까?';
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
              Image.asset('assets/images/bg_gate.jpg',
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
                  style: const TextStyle(color: AppColors.text, fontSize: 13),
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
                  style: const TextStyle(color: AppColors.text, fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: GlowBar(
                    ratio: maxHp == 0 ? 0 : hp / maxHp,
                    colors: BarColors.hp,
                    height: 8),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: () => showBagSheet(context, _c),
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
            const SizedBox(
              height: 110,
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                    Color(0xFF55557A), BlendMode.modulate),
                child: Opacity(
                  opacity: 0.85,
                  child: MonsterPicture(
                      monster: MonsterId.labyrinthWarden, size: 110),
                ),
              ),
            ),
            Text('???', style: AppText.title(22, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(
              '보상: 클리어 $reward · 실패 ${RuleConstants.dungeonFailExp} 경험치',
              style: const TextStyle(color: AppColors.goldBright, fontSize: 13),
            ),
            Text(
              '오늘 연 던전 ${player.today?.dungeonRuns.length ?? 0} / '
              '${RuleConstants.maxDungeonRunsPerDay}회 (경험치 인정)',
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
          colors: [Color(0x000F1233), Color(0xFF0F1233)],
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
    final keys = player.gauge.keysAvailable;
    final line = cleared
        ? (purified.any((m) => m.isBoss)
            ? Monsters.info(MonsterId.labyrinthWarden).huntLine
            : '던전을 돌파했어!')
        : '쓰러졌지만 괜찮아. 여관에서 쉬거나 걸으면 HP가 다시 차!';

    return [
      // 11-10 A3: 정령 한 줄은 제목 바로 아래 고정 자리
      BulssiLine(
          line: line,
          mood: cleared ? SpiritMood.cheer : SpiritMood.worried),
      const SizedBox(height: 10),
      // 배너
      SizedBox(
        height: 300,
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
                  child: Image.asset(
                      cleared
                          ? 'assets/images/bg_victory.jpg'
                          : 'assets/images/bg_battle.jpg',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, 0.2),
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 0,
              right: 0,
              child: Center(
                child: ArtBanner(
                  asset: 'assets/images/banner_clear.png',
                  width: 330,
                  aspect: 760 / 302,
                  text: cleared ? '던전 돌파!' : '이번엔 물러났어요',
                  textOffset: -0.12,
                  fontSize: 25,
                ),
              ),
            ),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.gold.withValues(alpha: cleared ? 0.45 : 0.15),
                  Colors.transparent,
                ]),
              ),
            ),
            Positioned(
              bottom: 6,
              height: 170,
              child: HeroSprite(
                  look: _c.profile.look,
                  pose: cleared ? HeroPose.victory : HeroPose.idle),
            ),
            Positioned(
              right: 36,
              bottom: 60,
              child: Image.asset('assets/images/bulssi.png',
                  width: 76, errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      OrnatePanel(
        ornament: true,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const GameIcon('exp', size: 34),
                const SizedBox(width: 8),
                Text(
                  _exp > 0 ? '경험치 +$_exp' : '오늘 던전 경험치는 다 받았어요',
                  style: AppText.title(_exp > 0 ? 28 : 17),
                ),
                if (_atGate && _exp > 0) ...[
                  const SizedBox(width: 10),
                  const _GateBonusBadge(small: true),
                ],
              ],
            ),
            const SizedBox(height: 10),
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
            Text('사냥 ${battle.purified.length} / ${battle.floors.length}',
                style: AppText.title(16, color: const Color(0xFFCDB8F5))),
            const SizedBox(height: 8),
            RewardItems(reward: _c.lastReward),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (purified.isNotEmpty)
        OrnatePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                purified.any((m) => !_knownBefore.contains(m.id))
                    ? '도감에 새로 등록'
                    : '사냥한 몬스터',
                textAlign: TextAlign.center,
                style: AppText.title(17),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final m in purified)
                    Expanded(
                      child: _MonsterCard(
                          info: m, isNew: !_knownBefore.contains(m.id)),
                    ),
                ],
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const GameIcon('key', size: 26),
          const SizedBox(width: 6),
          Text('남은 열쇠 $keys개', style: AppText.title(16, color: AppColors.text)),
        ]),
      ),
      const SizedBox(height: 14),
      if (keys > 0 && _c.canFightNow) ...[
        GoldButton(
          label: '다시 열기 · 열쇠 1개',
          onPressed: () {
            setState(() => _stage = _Stage.entry);
            _start();
          },
        ),
        const SizedBox(height: 10),
      ],
      FrameButton(
        label: '돌아가기',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }
}

class _FloorTrack extends StatelessWidget {
  const _FloorTrack();

  @override
  Widget build(BuildContext context) {
    Widget node(String label, String asset) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/$asset.png',
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
      asset: 'assets/images/badge_gate.png',
      width: small ? 56 : 92,
      aspect: 240 / 225,
      text: '×1.5',
      textOffset: -0.1,
      fontSize: small ? 15 : 22,
    );
  }
}

class _MonsterCard extends StatelessWidget {
  const _MonsterCard({required this.info, required this.isNew});

  final MonsterInfo info;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A2E6E), Color(0xFF1B1E4C)],
        ),
        border: Border.all(color: AppColors.goldBright, width: 1.2),
      ),
      child: Column(children: [
        if (isNew)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            decoration: BoxDecoration(
              gradient: kGoldGradient,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('NEW',
                style: TextStyle(
                    color: Color(0xFF3A2208),
                    fontSize: 10,
                    fontWeight: FontWeight.w900)),
          )
        else
          const SizedBox(height: 15),
        MonsterPicture(monster: info.id, size: 70),
        Text(info.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

/// 여관에서 쉬는 중에 싸우려 할 때 먼저 묻는다
Future<bool> confirmStopResting(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.night,
      title: Text('휴식을 멈출까요?', style: AppText.title(19)),
      content: const Text(
        '여관에서 쉬는 중이에요. 지금 싸우면 휴식이 끝나고, '
        '휴식 보상(HP·MP 가득, 보너스)은 받지 못해요.',
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
