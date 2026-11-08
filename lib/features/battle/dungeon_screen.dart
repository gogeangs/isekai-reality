import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../bulssi/bulssi_bubble.dart';
import 'battle_view.dart';

enum _Stage { entry, battle, result }

/// 던전: 입장 → 자동 전투(3층 + 보스) → 결과
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

  AppController get _c => widget.controller;

  void _start() {
    final atGate = _c.atGate;
    final battle = _c.startDungeon();
    if (battle == null) return;
    setState(() {
      _atGate = atGate;
      _battle = battle;
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
    return Scaffold(
      backgroundColor: AppColors.night,
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: AppColors.goldBright,
        title: const Text('잿빛 던전'),
        // 전투 중에는 나가지 않게 한다 (중간에 나가면 열쇠를 쓰지 않음)
        automaticallyImplyLeading: _stage != _Stage.battle,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: switch (_stage) {
            _Stage.entry => _entry(),
            _Stage.battle => [
                BattleView(
                  battle: _battle!,
                  onFinished: _finish,
                  tickInterval: widget.tickInterval,
                  playerName: _c.profile.name,
                ),
              ],
            _Stage.result => _result(),
          },
        ),
      ),
    );
  }

  List<Widget> _entry() {
    final player = _c.player;
    final keys = player.gauge.keysAvailable;
    final atGate = _c.atGate;
    final canFight = _c.canFightNow;
    final power =
        StatRules.combatPower(level: player.level.level, stats: player.stats);

    final String line;
    if (!canFight) {
      line = '움직이는 중엔 위험해! 멈춰 서서 던전을 열자.';
    } else if (keys == 0) {
      line = '열쇠가 없어. ${comma(RuleConstants.stepsPerKey)}보를 걸으면 하나 생겨!';
    } else if (atGate) {
      line = '미궁 입구야! 여기서 열면 보상이 1.5배야. 박쥐들이 기다리고 있어.';
    } else if (!_c.dungeonExpLeftToday) {
      line = '오늘 경험치는 다 받았어. 열쇠는 내일을 위해 아껴 둘까?';
    } else {
      line = '잿빛 던전 3층과 문지기가 기다려. 준비됐어?';
    }

    return [
      _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.vpn_key_rounded, color: AppColors.gold),
              const SizedBox(width: 8),
              Text('열쇠 $keys개',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('전투력 ${comma(power)}',
                  style: const TextStyle(color: AppColors.goldBright)),
            ]),
            const SizedBox(height: 12),
            const Text('구성: 자동 전투 3층 + 보스 · 열쇠 1개 사용',
                style: TextStyle(color: AppColors.textMuted)),
            Text(
                '보상: 클리어 ${RuleConstants.dungeonClearExp} · '
                '실패 ${RuleConstants.dungeonFailExp} 경험치'
                '${atGate ? ' (미궁 입구 1.5배)' : ''}',
                style: const TextStyle(color: AppColors.textMuted)),
            Text(
                '오늘 연 던전 ${player.today?.dungeonRuns.length ?? 0} / '
                '${RuleConstants.maxDungeonRunsPerDay}회 (경험치 인정)',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 8),
            const Text('충전되면 \'불씨의 일격\'을 눌러 큰 피해를 줄 수 있어요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
      if (atGate) ...[
        const SizedBox(height: 12),
        const _GateBanner(),
      ],
      const SizedBox(height: 16),
      BulssiBubble(line: line),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: keys > 0 && canFight ? _start : null,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.night,
          minimumSize: const Size.fromHeight(56),
          textStyle:
              const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        child: const Text('던전 열기'),
      ),
    ];
  }

  List<Widget> _result() {
    final battle = _battle!;
    final cleared = battle.phase == BattlePhase.cleared;
    final purified = battle.purified.toSet().map(Monsters.info).toList();
    final line = cleared
        ? (purified.any((m) => m.isBoss)
            ? Monsters.info(MonsterId.labyrinthWarden).purifiedLine
            : '던전을 정화했어!')
        : '괜찮아, 잃은 건 없어. 조금 더 강해져서 다시 오자!';

    return [
      const SizedBox(height: 12),
      Text(cleared ? '던전 정화 완료!' : '이번엔 물러났어요',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: cleared ? AppColors.goldBright : AppColors.text,
              fontSize: 28,
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(_exp > 0 ? '경험치 +$_exp' : '오늘 받을 수 있는 던전 경험치는 다 받았어요',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.gold, fontSize: 20)),
      const SizedBox(height: 20),
      if (purified.isNotEmpty)
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('정화한 몬스터',
                  style: TextStyle(
                      color: AppColors.goldBright,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final m in purified)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    MonsterPicture(monster: m.id, size: 36),
                    const SizedBox(width: 10),
                    Text('${m.name} → ${m.purifiedName}',
                        style: const TextStyle(color: AppColors.text)),
                  ]),
                ),
            ],
          ),
        ),
      const SizedBox(height: 16),
      BulssiBubble(line: line),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.night,
          minimumSize: const Size.fromHeight(56),
        ),
        child: const Text('돌아가기'),
      ),
    ];
  }
}

class _GateBanner extends StatelessWidget {
  const _GateBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gauge.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gauge),
      ),
      child: const Row(children: [
        Icon(Icons.stars_rounded, color: AppColors.gauge),
        SizedBox(width: 8),
        Expanded(
          child: Text('미궁 입구 보너스: 보상 1.5배, 미궁 박쥐 출현',
              style: TextStyle(color: AppColors.text)),
        ),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.panelBorder.withValues(alpha: 0.8)),
      ),
      child: child,
    );
  }
}
