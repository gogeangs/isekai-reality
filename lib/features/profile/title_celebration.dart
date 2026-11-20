import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../data/sound/sfx.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 칭호를 얻었을 때 화면 가운데 축하 연출 (11-11 #85 → 묶음 77 #351).
/// 약 2초: ① 어두워지며 섬광 ② 배지가 위에서 떨어져 튀었다 제자리 ③ 금빛 고리 · 빛살 · 금가루
/// ④ 빛줄기 · 이름 리본 · 등급 칩 ⑤ 얻은 까닭 · 버튼(1.8초). 그 전에 누르면 끝 화면으로.
/// 등급(보통 · 희귀 · 전설)마다 빛살 색 · 고리 수 · 효과음 · 진동이 다르다
Future<void> showTitleCelebration(
    BuildContext context, AppController c, TitleId t) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '닫기',
    barrierColor: const Color(0xE605060F),
    transitionDuration: const Duration(milliseconds: 200),
    // 묶음 20 #160: 글자 밑줄이 생기지 않게 Material 바탕 위에
    pageBuilder: (d, _, __) => Material(
        type: MaterialType.transparency,
        child: TitleCelebration(controller: c, title: t)),
    transitionBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  );
}

class TitleCelebration extends StatefulWidget {
  const TitleCelebration({super.key, required this.controller, required this.title, this.start});

  final AppController controller;
  final TitleId title;

  /// 시험 · 캡처용: 이 진행(0~1)에서 멈춰 보여 줌
  final double? start;

  @override
  State<TitleCelebration> createState() => _TitleCelebrationState();
}

class _TitleCelebrationState extends State<TitleCelebration> with TickerProviderStateMixin {
  static const total = Duration(milliseconds: 2000);
  late final AnimationController _a = AnimationController(vsync: this, duration: total);
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 14));

  TitleGrade get grade => TitleRules.gradeOf(widget.title);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (widget.start != null) {
        _a.value = widget.start!;
      } else if (still) {
        _a.value = 1; // 줄인 움직임: 연출 없이 끝 화면
      } else {
        _a.forward();
        _spin.repeat();
        _feel();
      }
    });
  }

  void _feel() {
    final c = widget.controller;
    if (c.sound) Sfx.play(grade == TitleGrade.common ? SfxKind.perfect : SfxKind.superEffective);
    if (c.vibrate && grade != TitleGrade.common) HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _a.dispose();
    _spin.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final info = TitleRules.info(widget.title);
    final c = widget.controller;
    final already = c.equippedTitle == widget.title;
    final g = grade;
    final size = MediaQuery.sizeOf(context);
    final badge = math.min(size.width * 0.5, 240.0);
    return GestureDetector(
      key: const Key('titleCelebration'),
      behavior: HitTestBehavior.opaque,
      // 끝나기 전에 누르면 끝 화면으로 건너뜀
      onTap: () {
        if (_a.value < 1) _a.value = 1;
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_a, _spin]),
        builder: (context, _) {
          final t = _a.value * total.inMilliseconds / 1000; // 초
          final flash = t < 0.3 ? math.sin(_seg(t, 0, 0.3) * math.pi) : 0.0;
          // 배지: 0.3~0.8초 위에서 떨어져 1.2배로 튀었다 제자리
          final drop = _seg(t, 0.3, 0.6);
          final bounce = _seg(t, 0.6, 0.85);
          final scale = t < 0.3
              ? 0.0
              : drop < 1
                  ? 0.4 + 0.8 * Curves.easeIn.transform(drop)
                  : 1.2 - 0.2 * Curves.easeOut.transform(bounce);
          final dy = (1 - Curves.easeIn.transform(drop)) * -size.height * 0.35;
          final land = _seg(t, 0.75, 1.6); // 고리 · 금가루
          final beam = t >= 1.0 && t < 1.5 ? math.sin(_seg(t, 1.0, 1.5) * math.pi) : 0.0;
          final ribbon = Curves.easeOutBack.transform(_seg(t, 1.05, 1.45));
          final tail = _seg(t, 1.6, 1.95);
          return Stack(alignment: Alignment.center, children: [
            // ① 가운데 섬광
            if (flash > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        Colors.white.withValues(alpha: 0.85 * flash),
                        Colors.white.withValues(alpha: 0),
                      ], radius: 0.5),
                    ),
                  ),
                ),
              ),
            // ③ 빛살 (계속 천천히 돎) · 고리 · 금가루
            if (t >= 0.75)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    key: Key('titleRays_${g.name}'),
                    painter: _RaysPainter(
                      grade: g,
                      spin: _spin.value,
                      ring: land,
                      rings: g == TitleGrade.common ? 1 : 2,
                      badge: badge,
                      dy: -size.height * 0.08,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(height: size.height * 0.04),
                // ② 배지 (카드 틀 없이)
                Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: badge,
                      height: badge,
                      child: Stack(alignment: Alignment.center, children: [
                        Image.asset('assets/images/${TitleRules.asset(widget.title)}.webp',
                            key: const Key('titleBadge'),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const GoldTitleBadge(key: Key('titleBadgeCommon'))),
                        // ④ 빛줄기 한 번
                        if (beam > 0)
                          IgnorePointer(
                            child: Container(
                              width: badge * 0.28,
                              height: badge * 1.4,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.7 * beam),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // ④ 이름 리본 · 등급 칩
                Opacity(
                  opacity: ribbon.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scaleX: ribbon.clamp(0.0, 1.2),
                    child: Container(
                      key: const Key('titleRibbon'),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF8A5A12), Color(0xFFF4C95D), Color(0xFF8A5A12)]),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: 18)],
                      ),
                      child: Text(info.name,
                          textAlign: TextAlign.center,
                          style: AppText.title(24, color: AppColors.goldInk)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: _seg(t, 1.3, 1.5),
                  child: Container(
                    key: Key('titleGrade_${g.name}'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    decoration: BoxDecoration(
                      color: _gradeColor(g).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _gradeColor(g)),
                    ),
                    child: Text('새 칭호 · ${TitleRules.gradeLabel(g)}',
                        style: TextStyle(color: _gradeColor(g), fontSize: 13, fontWeight: FontWeight.w800)),
                  ),
                ),
                // ⑤ 얻은 까닭 · 버튼
                Opacity(
                  opacity: tail,
                  child: IgnorePointer(
                    ignoring: tail < 1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (g == TitleGrade.legend) ...[
                            Text('「대단해! 이건 정말 드문 거야!」',
                                key: const Key('titleLegendLine'),
                                style: AppText.title(15, color: AppColors.goldBright)),
                            const SizedBox(height: 4),
                          ],
                          KText(TitleRules.earnedLine(widget.title),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.4)),
                          const SizedBox(height: 14),
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
            ),
          ]);
        },
      ),
    );
  }
}

Color _gradeColor(TitleGrade g) => switch (g) {
      TitleGrade.common => AppColors.goldBright,
      TitleGrade.rare => const Color(0xFF8FD3FF),
      TitleGrade.legend => const Color(0xFFFF9AF5),
    };

/// 빛살 · 금빛 고리 · 금가루
class _RaysPainter extends CustomPainter {
  _RaysPainter({
    required this.grade,
    required this.spin,
    required this.ring,
    required this.rings,
    required this.badge,
    required this.dy,
  });

  final TitleGrade grade;
  final double spin;
  final double ring;
  final int rings;
  final double badge;
  final double dy;

  static const _rainbow = [
    Color(0xFFFF6B6B), Color(0xFFFFC75F), Color(0xFFF9F871), Color(0xFF7BE495),
    Color(0xFF5EC8FF), Color(0xFF9D8CFF), Color(0xFFFF8CE6),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + dy - badge * 0.12);
    final reach = math.max(size.width, size.height) * 0.75;
    // 빛살
    const n = 16;
    for (var i = 0; i < n; i++) {
      final a = spin * math.pi * 2 + i * math.pi * 2 / n;
      final color = switch (grade) {
        TitleGrade.common => AppColors.goldBright,
        TitleGrade.rare => const Color(0xFF8FD3FF),
        TitleGrade.legend => _rainbow[i % _rainbow.length],
      };
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(a - 0.07) * reach, center.dy + math.sin(a - 0.07) * reach)
        ..lineTo(center.dx + math.cos(a + 0.07) * reach, center.dy + math.sin(a + 0.07) * reach)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = RadialGradient(colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: center, radius: reach)));
    }
    // 금빛 고리 퍼짐
    for (var k = 0; k < rings; k++) {
      final p = ((ring - k * 0.25) / 0.75).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      canvas.drawCircle(
          center,
          badge * (0.45 + 1.2 * p),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4 * (1 - p) + 1
            ..color = AppColors.goldBright.withValues(alpha: 0.8 * (1 - p)));
    }
    // 금가루 (가운데서 사방으로)
    if (ring > 0 && ring < 1) {
      final rng = math.Random(11);
      for (var i = 0; i < 40; i++) {
        final a = rng.nextDouble() * math.pi * 2;
        final d = badge * (0.3 + ring * (0.8 + rng.nextDouble() * 1.4));
        canvas.drawCircle(
            center + Offset(math.cos(a) * d, math.sin(a) * d),
            1.2 + rng.nextDouble() * 2.4,
            Paint()..color = (i.isEven ? AppColors.goldBright : AppColors.gold).withValues(alpha: 1 - ring));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => true;
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
          ..shader = const RadialGradient(colors: [
            Color(0xFFFFF0B3),
            Color(0xFFE8B04A),
            Color(0xFFA9781F)
          ], stops: [
            0,
            0.6,
            1
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
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
