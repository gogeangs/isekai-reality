import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
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

  void _start() {
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
        StatRules.combatPower(level: player.level.level, stats: player.stats);
    final reward = atGate
        ? (RuleConstants.dungeonClearExp * RuleConstants.gateBonusMultiplier)
            .round()
        : RuleConstants.dungeonClearExp;

    final String line;
    if (!canFight) {
      line = '움직이는 중엔 위험해! 멈춰 서서 던전을 열자.';
    } else if (keys == 0) {
      line = '열쇠가 없어. ${comma(RuleConstants.stepsPerKey)}보를 걸으면 하나 생겨!';
    } else if (atGate) {
      line = '미궁 입구야! 여기서 열면 보상이 1.5배야.';
    } else if (!_c.dungeonExpLeftToday) {
      line = '오늘 경험치는 다 받았어. 열쇠는 내일을 위해 아껴 둘까?';
    } else {
      line = '문이 열려 있어. 준비됐어?';
    }

    return [
      // 미궁 문 그림
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 210,
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
              for (var i = 0; i < RuleConstants.maxKeysEarnedPerDay; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: GameIcon(i < keys ? 'key' : 'key_empty', size: 30),
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
      const SizedBox(height: 14),
      BulssiBubble(line: line),
      const SizedBox(height: 18),
      GoldButton(
        label: '던전 열기',
        onPressed: keys > 0 && canFight ? _start : null,
      ),
    ];
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
            ? Monsters.info(MonsterId.labyrinthWarden).purifiedLine
            : '던전을 정화했어!')
        : '괜찮아, 잃은 건 없어. 조금 더 강해져서 다시 오자!';

    return [
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
                  text: cleared ? '던전 정화 완료!' : '이번엔 물러났어요',
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
                  pose: cleared ? HeroPose.victory : HeroPose.attack),
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
                  style: AppText.title(16, color: AppColors.text)),
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
            Text('정화 ${battle.purified.length} / ${battle.floors.length}',
                style: AppText.title(16, color: const Color(0xFFCDB8F5))),
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
                    : '정화한 몬스터',
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
      BulssiBubble(line: line),
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
        MonsterPicture(monster: info.id, size: 70, purified: true),
        Text(info.purifiedName,
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
