import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../bulssi/bulssi_bubble.dart';
import 'battle_view.dart';

/// 지도에서 만난 필드 몬스터를 정화하는 짧은 전투 (한 마리)
class FieldBattleScreen extends StatefulWidget {
  const FieldBattleScreen({
    super.key,
    required this.controller,
    required this.spawn,
    this.tickInterval = const Duration(milliseconds: 700),
  });

  final AppController controller;
  final FieldSpawn spawn;
  final Duration tickInterval;

  @override
  State<FieldBattleScreen> createState() => _FieldBattleScreenState();
}

class _FieldBattleScreenState extends State<FieldBattleScreen> {
  Battle? _battle;
  bool _done = false;
  int _exp = 0;

  @override
  void initState() {
    super.initState();
    _battle = widget.controller.startFieldBattle(widget.spawn);
  }

  Future<void> _finish() async {
    final exp =
        await widget.controller.finishFieldBattle(widget.spawn, _battle!);
    if (!mounted) return;
    setState(() {
      _exp = exp;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    final info = widget.spawn.info;
    return Scaffold(
      backgroundColor: AppColors.night,
      appBar: AppBar(
        backgroundColor: AppColors.night,
        foregroundColor: AppColors.goldBright,
        title: Text(info.name),
        automaticallyImplyLeading: battle == null || _done,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (battle == null)
              const BulssiBubble(line: '움직이는 중엔 위험해! 멈춰 선 다음에 정화하자.')
            else if (!_done)
              BattleView(
                battle: battle,
                onFinished: _finish,
                tickInterval: widget.tickInterval,
                playerName: widget.controller.profile.name,
              )
            else ...[
              const SizedBox(height: 12),
              Text(
                battle.phase == BattlePhase.cleared ? '정화 완료!' : '이번엔 물러났어요',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 28,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              if (battle.phase == BattlePhase.cleared)
                Text(
                  '${info.purifiedName} · 경험치 +$_exp · 주변 안개가 걷혔어요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.gold, fontSize: 16),
                ),
              const SizedBox(height: 20),
              Center(child: MonsterPicture(monster: info.id, size: 120)),
              const SizedBox(height: 16),
              BulssiBubble(
                line: battle.phase == BattlePhase.cleared
                    ? info.purifiedLine
                    : '괜찮아, 잃은 건 없어. 조금 더 강해져서 다시 오자!',
              ),
            ],
            if (battle == null || _done) ...[
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
            ],
          ],
        ),
      ),
    );
  }
}
