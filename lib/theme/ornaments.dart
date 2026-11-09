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

/// 9조각 그림 (모서리는 그대로, 가운데만 늘림). [scale] 은 그림 픽셀 ÷ 화면 크기.
class _NineSlice extends StatelessWidget {
  const _NineSlice({
    required this.asset,
    required this.slice,
    required this.scale,
    required this.child,
  });

  final String asset;
  final Rect slice;
  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 그림을 원래 픽셀 크기(화면 크기 × scale)로 9조각 그린 뒤 화면 크기로 줄인다.
    // (DecorationImage 의 scale 을 쓰면 소수 계산 오차로 디버그 검사에 걸린다)
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(builder: (context, c) {
            if (!c.maxWidth.isFinite || !c.maxHeight.isFinite) {
              return const SizedBox();
            }
            return FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: c.maxWidth * scale,
                height: c.maxHeight * scale,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(asset),
                      centerSlice: slice,
                      fit: BoxFit.fill,
                      onError: (_, __) {},
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        child,
      ],
    );
  }
}

/// 금테 패널. 목업의 모든 상자 모양.
///
/// 폭이 120 이상이면 그림 테두리(ui_panel_wide / ui_panel)를,
/// 그보다 작으면 코드로 그린 테두리를 쓴다.
/// 불씨 말풍선 그림 (ui_bubble.png, 477×234, 왼쪽 아래 꼬리)
class SpeechBubbleArt extends StatelessWidget {
  const SpeechBubbleArt({super.key, required this.child});

  final Widget child;

  static const double _scale = 2.8;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 50, minWidth: 80),
      child: _NineSlice(
        asset: 'assets/images/ui_bubble.png',
        slice: const Rect.fromLTRB(110, 55, 400, 175),
        scale: _scale,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 13, 20, 19),
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: child,
          ),
        ),
      ),
    );
  }
}

class OrnatePanel extends StatelessWidget {
  const OrnatePanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    this.highlight = false,
    this.ornament = false,
    this.art = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  /// 고른 상태처럼 더 밝게 빛난다
  final bool highlight;

  /// (코드 테두리일 때) 위쪽 가운데 작은 마름모 장식
  final bool ornament;

  /// false 면 항상 코드 테두리 (작은 막대 등)
  final bool art;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      if (!art || !w.isFinite || w < 120) return _codePanel();
      final wide = w >= 260;
      final imgW = wide ? 947.0 : 422.0;
      final s = imgW / w;
      final slice = wide
          ? const Rect.fromLTRB(70, 72, 947 - 70, 394 - 64)
          : const Rect.fromLTRB(60, 66, 422 - 60, 410 - 58);
      final framed = _NineSlice(
        asset: wide
            ? 'assets/images/ui_panel_wide.png'
            : 'assets/images/ui_panel.png',
        slice: slice,
        scale: s,
        child: Padding(
          // 테두리 두께와 모서리 장식만큼 안쪽으로
          // (11-10: 글자가 모서리 장식에 겹쳐서 여백을 늘림)
          padding: EdgeInsets.fromLTRB(
            46 / s + padding.left * 0.6,
            (wide ? 74 : 62) / s + padding.top * 0.4,
            46 / s + padding.right * 0.6,
            (wide ? 58 : 52) / s + padding.bottom * 0.4,
          ),
          child: child,
        ),
      );
      if (!highlight) return framed;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.45), blurRadius: 18),
          ],
        ),
        child: framed,
      );
    });
  }

  Widget _codePanel() {
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

/// 게임 아이콘 그림 (assets/images/icon_<name>.png). 없으면 [fallback] 아이콘.
class GameIcon extends StatelessWidget {
  const GameIcon(this.name,
      {super.key, this.size = 22, this.fallback = Icons.circle_outlined});

  final String name;
  final double size;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/icon_$name.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(fallback, size: size, color: AppColors.goldBright),
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

/// ─◆ 제목 ◆─ 모양의 리본 제목 (ui_divider 그림의 왼쪽·오른쪽 반)
class RibbonHeading extends StatelessWidget {
  const RibbonHeading(this.text, {super.key, this.size = 22});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget half(bool left) => Expanded(
          child: SizedBox(
            height: size * 0.75,
            child: Image.asset(
              left
                  ? 'assets/images/ui_divider_left.png'
                  : 'assets/images/ui_divider_right.png',
              fit: BoxFit.fitHeight,
              alignment: left ? Alignment.centerRight : Alignment.centerLeft,
              errorBuilder: (_, __, ___) => Center(
                child: Container(height: 1.2, color: AppColors.gold),
              ),
            ),
          ),
        );
    return Row(
      children: [
        half(true),
        const SizedBox(width: 8),
        Flexible(
          flex: 8,
          child: Text(text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title(size)),
        ),
        const SizedBox(width: 8),
        half(false),
      ],
    );
  }
}

/// 빛나는 금색 버튼 (ui_button_gold 그림)
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
    return _ArtButton(
      asset: enabled
          ? 'assets/images/ui_button_gold.png'
          : 'assets/images/ui_button_dark.png',
      imgH: enabled ? 159 : 160,
      slice: enabled
          ? const Rect.fromLTRB(110, 48, 668 - 110, 159 - 48)
          : const Rect.fromLTRB(90, 48, 662 - 90, 160 - 48),
      height: height,
      onPressed: onPressed,
      glow: enabled,
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Title',
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          color: enabled ? const Color(0xFF3A2208) : AppColors.textMuted,
        ),
      ),
    );
  }
}

/// 금테 두른 어두운 버튼 (ui_button_dark 그림)
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
    final color =
        onPressed == null ? AppColors.textMuted : AppColors.goldBright;
    return _ArtButton(
      asset: 'assets/images/ui_button_dark.png',
      imgH: 160,
      slice: const Rect.fromLTRB(90, 48, 662 - 90, 160 - 48),
      height: height,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: color),
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
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtButton extends StatelessWidget {
  const _ArtButton({
    required this.asset,
    required this.imgH,
    required this.slice,
    required this.height,
    required this.onPressed,
    required this.child,
    this.glow = false,
  });

  final String asset;
  final double imgH;
  final Rect slice;
  final double height;
  final VoidCallback? onPressed;
  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: glow
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(height / 2),
              boxShadow: [
                BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    blurRadius: 16),
              ],
            )
          : null,
      child: _NineSlice(
        asset: asset,
        slice: slice,
        scale: imgH / height,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: height * 0.7),
              child: Center(child: child),
            ),
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

/// 레벨 배지: 월계관 판(ui_level_plaque) + 'Lv.12' + 아래 칭호 리본(ui_ribbon)
class LaurelBadge extends StatelessWidget {
  const LaurelBadge({super.key, required this.level, required this.title});

  final int level;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      height: 172,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: SizedBox(
              width: 250,
              height: 116,
              child: Stack(alignment: Alignment.center, children: [
                Image.asset('assets/images/ui_level_plaque.png',
                    width: 250, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text('Lv.$level', style: AppText.title(36)),
                ),
              ]),
            ),
          ),
          Positioned(
            top: 104,
            child: SizedBox(
              width: 190,
              height: 68,
              child: Stack(alignment: Alignment.center, children: [
                Image.asset('assets/images/ui_ribbon.png',
                    width: 190, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(title,
                      style: const TextStyle(
                        fontFamily: 'Title',
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF3A2208),
                      )),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// 글자를 얹는 그림 배너 (레벨업·던전 클리어·입구 보너스)
class ArtBanner extends StatelessWidget {
  const ArtBanner({
    super.key,
    required this.asset,
    required this.width,
    required this.aspect,
    required this.text,
    this.textOffset = 0,
    this.fontSize = 26,
  });

  final String asset;
  final double width;

  /// 그림의 가로 ÷ 세로
  final double aspect;
  final String text;

  /// 글자를 세로로 옮기는 정도 (-1 위 ~ 1 아래)
  final double textOffset;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width / aspect,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset(asset,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox()),
        Align(
          alignment: Alignment(0, textOffset),
          child: Text(text,
              style: AppText.title(fontSize, color: const Color(0xFFFFF3C8))),
        ),
      ]),
    );
  }
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
            // 밝은 하늘 그림 위에서도 보이게 어두운 동그라미를 깐다
            DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0x990B0D26),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: AppColors.goldBright),
                tooltip: '뒤로',
              ),
            )
          else
            const EyeEmblem(size: 40),
          const SizedBox(width: 6),
          // 제목 뒤에 어두운 띠 (하늘 그림에 글자가 묻히지 않게)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const RadialGradient(
                  radius: 2.2,
                  colors: [Color(0xCC0B0D26), Color(0x000B0D26)],
                  stops: [0.35, 1],
                ),
              ),
              child: RibbonHeading(title, size: 21),
            ),
          ),
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
  const NightBackground({super.key, required this.child, this.header = false});

  final Widget child;

  /// 위쪽에 노을 속 탑 그림 띠(bg_header)를 깐다
  final bool header;

  @override
  Widget build(BuildContext context) {
    final base = _base(header
        ? Stack(children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 230,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, 0.45, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: Opacity(
                  opacity: 0.85,
                  child: Image.asset('assets/images/bg_header.jpg',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.4, -0.2),
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            ),
            Positioned.fill(child: child),
          ])
        : child);
    return base;
  }

  Widget _base(Widget child) {
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
