import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 칭호를 얻었을 때 화면 가운데 축하 연출 (11-11 #85).
/// 배경을 어둡게 하고 빛 입자 위에 금빛 칭호 패. 아무 곳이나 누르면 닫힌다.
Future<void> showTitleCelebration(
    BuildContext context, AppController c, TitleId t) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '닫기',
    barrierColor: const Color(0xCC05060F),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (d, _, __) => _TitleCelebration(controller: c, title: t),
    transitionBuilder: (_, a, __, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 0.86, end: 1.0)
            .animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

class _TitleCelebration extends StatefulWidget {
  const _TitleCelebration({required this.controller, required this.title});

  final AppController controller;
  final TitleId title;

  @override
  State<_TitleCelebration> createState() => _TitleCelebrationState();
}

class _TitleCelebrationState extends State<_TitleCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(seconds: 4))
    ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = TitleRules.info(widget.title);
    final c = widget.controller;
    final already = c.equippedTitle == widget.title;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Stack(children: [
        // 빛 입자
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _a,
              builder: (_, __) =>
                  CustomPaint(painter: _Sparkles(_a.value)),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GestureDetector(
              onTap: () {}, // 패 안을 눌러도 닫히지 않게
              child: Container(
                key: const Key('titleCelebration'),
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF2B2459), Color(0xFF141638)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.goldBright, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.55),
                        blurRadius: 40,
                        spreadRadius: 2),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.military_tech_rounded,
                      size: 64, color: AppColors.goldBright),
                  const SizedBox(height: 4),
                  Text('새 칭호',
                      style: AppText.title(15, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  KText('「${info.name}」',
                      textAlign: TextAlign.center,
                      style: AppText.title(26, color: AppColors.goldBright)),
                  const SizedBox(height: 8),
                  KText(TitleRules.earnedLine(widget.title),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 14.5, height: 1.4)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        key: const Key('titleClose'),
                        style: gameButtonStyle(gold: false),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        key: const Key('titleEquip'),
                        style: gameButtonStyle(gold: true),
                        onPressed: already
                            ? null
                            : () async {
                                await c.setEquippedTitle(widget.title);
                                if (context.mounted) Navigator.of(context).pop();
                              },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(already ? '대표 칭호예요' : '대표 칭호로 걸기'),
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Sparkles extends CustomPainter {
  _Sparkles(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final p = Paint();
    for (var i = 0; i < 46; i++) {
      final x = rng.nextDouble() * size.width;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble();
      final y = size.height * (1 - ((t * speed + phase) % 1.0));
      final r = 1.2 + rng.nextDouble() * 2.6;
      final a = (math.sin((t + phase) * math.pi * 2) * 0.5 + 0.5) * 0.85;
      p.color = (i.isEven ? AppColors.goldBright : Colors.white)
          .withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _Sparkles old) => old.t != t;
}
