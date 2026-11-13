import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 튜토리얼 누를 곳 안내 (묶음 18 #148): 화면을 어둡게 덮고 [hole] 만 동그랗게 밝게.
/// 밝은 곳을 누르면 [onTap], 나머지는 눌리지 않는다. 손가락이 톡톡 + 「눌러 보세요」.
class Spotlight extends StatelessWidget {
  const Spotlight({
    super.key,
    required this.hole,
    required this.onTap,
    this.label = '눌러 보세요',
    this.round = true,
    this.dim = 0.7,
    this.showFinger = true,
  });

  final bool showFinger;

  /// 어둡기 (0~1)
  final double dim;

  /// 밝게 비출 곳 (화면 좌표). null 이면 어둡게만
  final Rect? hole;
  final VoidCallback? onTap;
  final String label;

  /// true 면 동그랗게, false 면 둥근 네모로
  final bool round;

  @override
  Widget build(BuildContext context) {
    final h = hole;
    return Stack(fit: StackFit.expand, children: [
      // 어두운 막: 모든 터치를 막는다
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: CustomPaint(painter: _DimPainter(h, round, dim)),
      ),
      if (h != null) ...[
        Positioned.fromRect(
          rect: h,
          child: GestureDetector(
            key: const Key('spotlightHole'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: const SizedBox.expand(),
          ),
        ),
        if (showFinger)
        Positioned(
          left: _fingerX(context, h),
          top: h.bottom - 6,
          child: IgnorePointer(child: FingerHint(label: label)),
        ),
      ],
    ]);
  }

  double _fingerX(BuildContext context, Rect h) {
    final w = MediaQuery.sizeOf(context).width;
    return (h.center.dx - 10).clamp(8.0, w - 150);
  }
}

class _DimPainter extends CustomPainter {
  _DimPainter(this.hole, this.round, this.dim);

  final Rect? hole;
  final bool round;
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final shade = Paint()..color = Color.fromRGBO(0, 0, 0, dim);
    final all = Path()..addRect(Offset.zero & size);
    final h = hole;
    if (h == null) {
      canvas.drawPath(all, shade);
      return;
    }
    final cut = Path();
    if (round) {
      cut.addOval(Rect.fromCircle(
          center: h.center, radius: math.max(h.width, h.height) / 2));
    } else {
      cut.addRRect(RRect.fromRectAndRadius(h, const Radius.circular(16)));
    }
    canvas.drawPath(Path.combine(PathOperation.difference, all, cut), shade);
    // 밝은 곳 둘레 금빛 테
    canvas.drawPath(
        cut,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = AppColors.goldBright
          ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3));
  }

  @override
  bool shouldRepaint(_DimPainter old) =>
      old.hole != hole || old.round != round || old.dim != dim;
}

/// 톡톡 누르는 손가락 + 짧은 글
class FingerHint extends StatefulWidget {
  const FingerHint({super.key, this.label = '눌러 보세요'});

  final String label;

  @override
  State<FingerHint> createState() => _FingerHintState();
}

class _FingerHintState extends State<FingerHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true, count: 14);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedBuilder(
      key: const Key('fingerHint'),
      animation: _a,
      builder: (context, _) {
        final t = still ? 0.0 : Curves.easeInOut.transform(_a.value);
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Transform.translate(
            offset: Offset(0, -10 * t),
            child: const Icon(Icons.touch_app_rounded,
                size: 44, color: Colors.white,
                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 8)]),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.abyss,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.goldBright),
            ),
            child: Text(widget.label,
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
        ]);
      },
    );
  }
}
