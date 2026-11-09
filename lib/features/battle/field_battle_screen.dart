import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
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
    final cleared = battle?.phase == BattlePhase.cleared;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
          children: [
            OrnateTopBar(
              title: info.name,
              onBack: battle == null || _done
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            const SizedBox(height: 10),
            if (battle == null)
              BulssiBubble(
                  line: widget.controller.hp <= 0
                      ? '많이 지쳤어. 여관에서 쉬거나 물약을 마시고 오자.'
                      : '움직이는 중엔 위험해! 멈춰 선 다음에 정화하자.')
            else if (!_done)
              BattleView(
                battle: battle,
                onFinished: _finish,
                tickInterval: widget.tickInterval,
                playerName: widget.controller.profile.name,
                look: widget.controller.profile.look,
              )
            else ...[
              const SizedBox(height: 8),
              Text(cleared ? '정화 완료!' : '이번엔 물러났어요',
                  textAlign: TextAlign.center, style: AppText.title(30)),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.gold.withValues(alpha: cleared ? 0.4 : 0.1),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                  MonsterPicture(monster: info.id, size: 190, purified: cleared),
                ]),
              ),
              if (cleared)
                OrnatePanel(
                  ornament: true,
                  child: Column(children: [
                    Text(info.purifiedName, style: AppText.title(20)),
                    const SizedBox(height: 6),
                    Text('경험치 +$_exp · 주변 안개가 걷혔어요',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14)),
                  ]),
                ),
              const SizedBox(height: 14),
              BulssiBubble(
                line: cleared
                    ? info.purifiedLine
                    : '괜찮아, 잃은 건 없어. 조금 더 강해져서 다시 오자!',
              ),
            ],
            if (battle == null || _done) ...[
              const SizedBox(height: 20),
              FrameButton(
                label: '돌아가기',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
