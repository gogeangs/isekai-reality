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
    // 묶음 20 #160: 글자 밑줄이 생기지 않게 Material 바탕 위에
    pageBuilder: (d, _, __) => Material(
        type: MaterialType.transparency,
        child: _TitleCelebration(controller: c, title: t)),
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
      vsync: this, duration: const Duration(seconds: 3))
    ..forward();

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
                  // 그 칭호의 배지 그림, 없으면 공통 금빛 배지
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: Image.asset(
                        'assets/images/title_${widget.title.name}.webp',
                        key: const Key('titleBadge'),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const GoldTitleBadge(key: Key('titleBadgeCommon'))),
                  ),
                  const SizedBox(height: 4),
                  Text('새 칭호',
                      style: AppText.title(14, color: AppColors.textMuted)),
                  const SizedBox(height: 6),
                  KText('「${info.name}」',
                      textAlign: TextAlign.center,
                      style: AppText.title(26, color: AppColors.goldBright)),
                  const SizedBox(height: 8),
                  KText(TitleRules.earnedLine(widget.title),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 16),
                  // #136 규칙: 기본 행동은 금빛 한 줄, 닫기는 작게. 이미 대표면 닫기 하나만 금빛
                  if (!already) ...[
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        key: const Key('titleEquip'),
                        style: gameButtonStyle(gold: true),
                        onPressed: () async {
                          await c.setEquippedTitle(widget.title);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('대표로 하기', maxLines: 1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      key: const Key('titleClose'),
                      style: smallButtonStyle(),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('닫기'),
                    ),
                  ] else
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        key: const Key('titleClose'),
                        style: gameButtonStyle(gold: true),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('닫기', maxLines: 1),
                      ),
                    ),
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
      p.color = (i.isEven ? AppColors.goldBright : AppColors.gold)
          .withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _Sparkles old) => old.t != t;
}

/// 그림이 없는 칭호의 공통 금빛 배지 (묶음 20 #160): 리본 위 둥근 금메달과 별
class GoldTitleBadge extends StatelessWidget {
  const GoldTitleBadge({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _BadgePainter(), size: Size.infinite);
}

class _BadgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);
    final c = Offset(size.width / 2, size.height * 0.42);
    final r = s * 0.32;
    // 리본 두 갈래
    final ribbon = Paint()..color = const Color(0xFF7A3FB8);
    for (final dir in [-1.0, 1.0]) {
      final path = Path()
        ..moveTo(c.dx + dir * r * 0.25, c.dy + r * 0.6)
        ..lineTo(c.dx + dir * r * 0.85, c.dy + r * 1.75)
        ..lineTo(c.dx + dir * r * 0.5, c.dy + r * 1.55)
        ..lineTo(c.dx + dir * r * 0.3, c.dy + r * 1.85)
        ..lineTo(c.dx - dir * r * 0.15, c.dy + r * 0.7)
        ..close();
      canvas.drawPath(path, ribbon);
    }
    // 금메달
    canvas.drawCircle(
        c,
        r * 1.08,
        Paint()
          ..color = const Color(0x88FFD86B)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
                  colors: [Color(0xFFFFF0B3), Color(0xFFE8B04A), Color(0xFFA9781F)],
                  stops: [0, 0.6, 1])
              .createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.025
          ..color = const Color(0xFF6B4A12));
    canvas.drawCircle(
        c,
        r * 0.78,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.012
          ..color = const Color(0xAA6B4A12));
    // 가운데 별
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r * 0.55 : r * 0.24;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFF7D6));
    canvas.drawPath(
        star,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.012
          ..color = const Color(0xFF8A6418));
  }

  @override
  bool shouldRepaint(_BadgePainter old) => false;
}
