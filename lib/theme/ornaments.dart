import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 목업의 장식 요소: 금테 패널, 리본 제목, 금색 버튼, 빛나는 막대, 월계관 배지.
/// 그림 파일 없이 코드로 그린다.

class AppText {
  AppText._();

  /// 제목·숫자 (고운바탕 Bold, 금색, 은은한 빛)
  static TextStyle title(double size, {Color color = AppColors.goldBright}) =>
      TextStyle(
        fontFamily: 'Title',
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color,
        height: 1.15,
        shadows: [
          Shadow(color: AppColors.gold.withValues(alpha: 0.45), blurRadius: 10),
        ],
      );
}

/// 금색 그라데이션 (테두리·버튼)
const LinearGradient kGoldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFBE7A6), Color(0xFFE8BE5C), Color(0xFFB98330)],
);

const LinearGradient _frameGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFF5DC94),
    Color(0xFF9C7334),
    Color(0xFFE8C66A),
    Color(0xFF8A6428),
  ],
  stops: [0, 0.35, 0.65, 1],
);

/// 금테 패널. 목업의 모든 상자 모양.
class OrnatePanel extends StatelessWidget {
  const OrnatePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    this.highlight = false,
    this.ornament = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// 고른 상태처럼 더 밝게 빛난다
  final bool highlight;

  /// 위쪽 가운데 작은 마름모 장식
  final bool ornament;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: EdgeInsets.all(highlight ? 2 : 1.3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: _frameGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: highlight ? 0.5 : 0.18),
            blurRadius: highlight ? 18 : 10,
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 1),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF2282C66), Color(0xF5181B48)],
          ),
        ),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius - 3),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.22), width: 0.8),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
    if (!ornament) return panel;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        panel,
        const Positioned(
          top: -5,
          left: 0,
          right: 0,
          child: Center(child: Diamond(size: 10)),
        ),
      ],
    );
  }
}

/// 작은 금색 마름모
class Diamond extends StatelessWidget {
  const Diamond({super.key, this.size = 8, this.color = AppColors.goldBright});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

/// ─◆ 제목 ◆─ 모양의 리본 제목
class RibbonHeading extends StatelessWidget {
  const RibbonHeading(this.text, {super.key, this.size = 22});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget line(bool left) => Expanded(
          child: Container(
            height: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: left
                    ? [Colors.transparent, AppColors.gold]
                    : [AppColors.gold, Colors.transparent],
              ),
            ),
          ),
        );
    return Row(
      children: [
        line(true),
        const SizedBox(width: 6),
        const Diamond(size: 7),
        const SizedBox(width: 10),
        Flexible(
          flex: 8,
          child: Text(text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title(size)),
        ),
        const SizedBox(width: 10),
        const Diamond(size: 7),
        const SizedBox(width: 6),
        line(false),
      ],
    );
  }
}

/// 빛나는 금색 버튼 (✦ 글자 ✦)
class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.height = 58,
    this.fontSize = 21,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final textColor = enabled ? const Color(0xFF3A2208) : AppColors.textMuted;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: enabled
              ? kGoldGradient
              : const LinearGradient(
                  colors: [Color(0xFF3A3F70), Color(0xFF2A2E58)]),
          border: Border.all(
              color: enabled ? const Color(0xFFFFF1C4) : AppColors.track,
              width: 1.5),
          boxShadow: enabled
              ? [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.55),
                      blurRadius: 18,
                      spreadRadius: 1),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✦', style: TextStyle(color: textColor, fontSize: 13)),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Title',
                      fontWeight: FontWeight.w700,
                      fontSize: fontSize,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('✦', style: TextStyle(color: textColor, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 금테 두른 어두운 버튼 (보조)
class FrameButton extends StatelessWidget {
  const FrameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(1.3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: _frameGradient,
      ),
      child: Material(
        color: const Color(0xFF1C1F4C),
        borderRadius: BorderRadius.circular(height / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 20,
                    color: onPressed == null
                        ? AppColors.textMuted
                        : AppColors.goldBright),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Title',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: onPressed == null
                        ? AppColors.textMuted
                        : AppColors.goldBright,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 빛나는 막대 (경험치·체력·MP)
class GlowBar extends StatelessWidget {
  const GlowBar({
    super.key,
    required this.ratio,
    required this.colors,
    this.height = 10,
  });

  final double ratio;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final r = ratio.isNaN ? 0.0 : ratio.clamp(0.0, 1.0);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF0E1130),
        borderRadius: BorderRadius.circular(height),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth * r;
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: w < 2 && r > 0 ? 2 : w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(height),
              gradient: LinearGradient(colors: colors),
              boxShadow: [
                BoxShadow(
                    color: colors.last.withValues(alpha: 0.6), blurRadius: 8),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// 막대 색 묶음
class BarColors {
  BarColors._();
  static const exp = [Color(0xFFE3A93B), Color(0xFFFBE38F)];
  static const gauge = [Color(0xFFD94A3A), Color(0xFFF08A4B)];
  static const mana = [Color(0xFF2F6FE0), Color(0xFF7FD0FF)];
  static const hp = [Color(0xFF2E9D57), Color(0xFF7BE08F)];
  static const foe = [Color(0xFFA8323C), Color(0xFFE86A6A)];
}

/// 레벨 배지: 월계관 + 'Lv.12' + 아래 칭호 리본
class LaurelBadge extends StatelessWidget {
  const LaurelBadge({super.key, required this.level, required this.title});

  final int level;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 112,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _LaurelPainter()),
          ),
          Positioned(
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1D4A),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.goldBright, width: 1.6),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.5),
                      blurRadius: 16),
                ],
              ),
              child: Text('Lv.$level', style: AppText.title(38)),
            ),
          ),
          Positioned(
            top: 64,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: BoxDecoration(
                gradient: kGoldGradient,
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: Color(0x88000000), blurRadius: 6),
                ],
              ),
              child: Text(title,
                  style: const TextStyle(
                    fontFamily: 'Title',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF3A2208),
                  )),
            ),
          ),
        ],
      ),
    );
  }
}

class _LaurelPainter extends CustomPainter {
  const _LaurelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final leaf = Paint()..color = const Color(0xFFE2B85A);
    final stem = Paint()
      ..color = const Color(0xFFC99A3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(size.width / 2, size.height * 0.62);
      canvas.scale(side, 1);
      final path = Path();
      const r = 70.0;
      for (var i = 0; i <= 20; i++) {
        final a = math.pi * (0.55 + i * 0.022);
        final p = Offset(math.cos(a) * r * 1.35, -math.sin(a) * r * 0.75);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, stem);
      for (var i = 1; i <= 7; i++) {
        final a = math.pi * (0.58 + i * 0.055);
        final p = Offset(math.cos(a) * r * 1.35, -math.sin(a) * r * 0.75);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(-a + math.pi / 2 + 0.6);
        canvas.drawOval(
            const Rect.fromLTWH(-4, -13, 8, 16), leaf); // 위쪽 잎
        canvas.restore();
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 탑의 눈 문장 (동그란 금테 안의 눈)
class EyeEmblem extends StatelessWidget {
  const EyeEmblem({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1A1D4A),
        border: Border.all(color: AppColors.goldBright, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.45), blurRadius: 12),
        ],
      ),
      child: Icon(Icons.remove_red_eye_rounded,
          color: AppColors.goldBright,
          size: size * 0.55,
          semanticLabel: '탑의 문장'),
    );
  }
}

/// 화면 위쪽 막대: 문장(또는 뒤로) · 제목 · 오른쪽 칩
class OrnateTopBar extends StatelessWidget {
  const OrnateTopBar({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.goldBright),
              tooltip: '뒤로',
            )
          else
            const EyeEmblem(size: 40),
          const SizedBox(width: 6),
          Expanded(child: RibbonHeading(title, size: 21)),
          const SizedBox(width: 6),
          trailing ?? const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// 둥근 칩 (날씨, AUTO 등)
class ChipBadge extends StatelessWidget {
  const ChipBadge({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xCC1A1D4A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.goldBright),
          const SizedBox(width: 5),
        ],
        Text(text,
            style: const TextStyle(color: AppColors.text, fontSize: 13)),
      ]),
    );
  }
}

/// 화면 전체 배경 (남색 + 보랏빛)
class NightBackground extends StatelessWidget {
  const NightBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.3,
          colors: [Color(0xFF2E2A6A), Color(0xFF181B45), Color(0xFF0F1233)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

/// 그림 위에 얹는 아래쪽 어둠 (그림과 화면이 자연스럽게 이어지게)
class FadeToNight extends StatelessWidget {
  const FadeToNight({super.key, this.height = 120});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00181B45), Color(0xFF181B45)],
          ),
        ),
      ),
    );
  }
}
