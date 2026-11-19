import 'dart:math' as math;

import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import 'app_colors.dart';
import 'glyphs.dart';
export 'glyphs.dart';

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

  /// 레벨 숫자 ('Lv.3'): 다른 UI와 같은 기본 글꼴, 굵게 (11-10 #29.
  /// 제목 글꼴은 영문이 세리프라 'Lv.' 만 튀었다)
  static TextStyle level(double size, {Color color = AppColors.goldBright}) =>
      TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: size,
        color: color,
        height: 1.15,
        shadows: [
          Shadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 8),
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
/// 묶음 69 #287 #288: 큰 안내 말풍선을 그림(ui_bubble) 대신 코드로.
/// 크림색 바탕(아래로 살짝 진하게) · 굵은 금갈색 테 한 줄 · 둥근 모서리 · 아래 그림자.
/// 꼬리는 길이가 늘 같고(약 18) 말하는 캐릭터 쪽 변([side])의 [at] 자리에서 캐릭터를 향한다.
/// [mirrored] 는 예전 이름 그대로 (꼬리가 오른쪽 아래)
class SpeechBubbleArt extends StatelessWidget {
  const SpeechBubbleArt({super.key, required this.child, this.mirrored = false, this.side, this.at, this.border});

  final Widget child;
  final bool mirrored;
  final BubbleSide? side;

  /// 꼬리 자리: 왼쪽 · 오른쪽 변이면 위에서부터, 위 · 아래 변이면 왼쪽에서부터 (null = 가운데, 음수 = 끝에서부터)
  final double? at;

  /// 테 색 (정령 이별처럼 말하는 이의 색으로 은은하게)
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final sd = side ?? (mirrored ? BubbleSide.right : BubbleSide.left);
    return CodeBubble(side: sd, at: at, border: border, child: child);
  }
}

/// 꼬리가 나오는 변
enum BubbleSide { left, right, up, down }

/// 코드로 그린 말풍선 (#287 #288)
class CodeBubble extends StatelessWidget {
  const CodeBubble({
    super.key,
    required this.child,
    this.side = BubbleSide.left,
    this.at,
    this.border,
    this.padding = const EdgeInsets.fromLTRB(16, 11, 16, 12),
    this.minWidth = 80,
  });

  final Widget child;
  final BubbleSide side;
  final double? at;
  final Color? border;
  final EdgeInsets padding;
  final double minWidth;

  static const double tail = 18;
  static const Color edge = Color(0xFF8A5A2B);

  @override
  Widget build(BuildContext context) {
    final t = tail;
    final inset = switch (side) {
      BubbleSide.left => EdgeInsets.only(left: t),
      BubbleSide.right => EdgeInsets.only(right: t),
      BubbleSide.up => EdgeInsets.only(top: t),
      BubbleSide.down => EdgeInsets.only(bottom: t),
    };
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth + t, minHeight: 44),
      child: CustomPaint(
        painter: CodeBubblePainter(side: side, at: at, border: border ?? edge),
        child: Padding(
          padding: inset + padding,
          child: Align(alignment: Alignment.centerLeft, widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}

class CodeBubblePainter extends CustomPainter {
  CodeBubblePainter({required this.side, this.at, this.border = CodeBubble.edge});

  final BubbleSide side;
  final double? at;
  final Color border;

  static const double radius = 20;
  static const double stroke = 4.5;

  Path shape(Size size) {
    const t = CodeBubble.tail;
    final body = switch (side) {
      BubbleSide.left => Rect.fromLTWH(t, 0, size.width - t, size.height),
      BubbleSide.right => Rect.fromLTWH(0, 0, size.width - t, size.height),
      BubbleSide.up => Rect.fromLTWH(0, t, size.width, size.height - t),
      BubbleSide.down => Rect.fromLTWH(0, 0, size.width, size.height - t),
    }.deflate(stroke / 2);
    final rr = RRect.fromRectAndRadius(body, const Radius.circular(radius));
    // 꼬리: 변에서 [t] 만큼 나와 끝이 살짝 둥근 삼각형 (밑변 22)
    const half = 11.0;
    final vertical = side == BubbleSide.left || side == BubbleSide.right;
    final len = vertical ? body.height : body.width;
    // [at] 이 음수면 끝(아래 · 오른쪽)에서부터
    final a = at;
    final from = a == null
        ? (vertical ? body.center.dy : body.center.dx)
        : a < 0
            ? (vertical ? body.bottom : body.right) + a
            : a;
    final start = vertical ? body.top : body.left;
    var lo = start + radius + half - 6, hi = start + len - radius - half + 6;
    if (lo > hi) lo = hi = start + len / 2;
    final pos = from.clamp(lo, hi);
    final tip = Path();
    switch (side) {
      case BubbleSide.left:
        tip
          ..moveTo(body.left + 2, pos - half)
          ..quadraticBezierTo(body.left - t * 0.55, pos - 3, body.left - t + 3, pos - 1)
          ..quadraticBezierTo(body.left - t, pos, body.left - t + 3, pos + 1.5)
          ..quadraticBezierTo(body.left - t * 0.45, pos + 4, body.left + 2, pos + half)
          ..close();
      case BubbleSide.right:
        tip
          ..moveTo(body.right - 2, pos - half)
          ..quadraticBezierTo(body.right + t * 0.55, pos - 3, body.right + t - 3, pos - 1)
          ..quadraticBezierTo(body.right + t, pos, body.right + t - 3, pos + 1.5)
          ..quadraticBezierTo(body.right + t * 0.45, pos + 4, body.right - 2, pos + half)
          ..close();
      case BubbleSide.up:
        tip
          ..moveTo(pos - half, body.top + 2)
          ..quadraticBezierTo(pos - 3, body.top - t * 0.55, pos - 1, body.top - t + 3)
          ..quadraticBezierTo(pos, body.top - t, pos + 1.5, body.top - t + 3)
          ..quadraticBezierTo(pos + 4, body.top - t * 0.45, pos + half, body.top + 2)
          ..close();
      case BubbleSide.down:
        tip
          ..moveTo(pos - half, body.bottom - 2)
          ..quadraticBezierTo(pos - 3, body.bottom + t * 0.55, pos - 1, body.bottom + t - 3)
          ..quadraticBezierTo(pos, body.bottom + t, pos + 1.5, body.bottom + t - 3)
          ..quadraticBezierTo(pos + 4, body.bottom + t * 0.45, pos + half, body.bottom - 2)
          ..close();
    }
    return Path.combine(PathOperation.union, Path()..addRRect(rr), tip);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = shape(size);
    canvas.drawShadow(p.shift(const Offset(0, 2)), const Color(0x99000000), 4, false);
    canvas.drawPath(
        p,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF7E6), Color(0xFFF3E2C0)],
          ).createShader(Offset.zero & size));
    canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round
          ..color = border);
  }

  @override
  bool shouldRepaint(CodeBubblePainter old) => old.side != side || old.at != at || old.border != border;
}

/// 말풍선 위 이름 줄 색 (금갈색)
const Color kBubbleName = Color(0xFF9A6324);

/// 금테 박스 안쪽 여백 (테두리 두께 밖으로 더하는 값)
const double kPanelGapH = 14;
const double kPanelGapV = 10;

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
            ? 'assets/images/ui_panel_wide.webp'
            : 'assets/images/ui_panel.webp',
        slice: slice,
        scale: s,
        child: Padding(
          // 모든 금테 박스의 안쪽 여백 기준 (11-10 A1):
          // 그림 테두리 두께 + 좌우 14, 위아래 10.
          // 안쪽 모서리 장식 조각은 그림에서 지웠다.
          padding: EdgeInsets.fromLTRB(
            (wide ? 24 : 26) / s + kPanelGapH,
            (wide ? 60 : 56) / s + kPanelGapV,
            (wide ? 24 : 26) / s + kPanelGapH,
            (wide ? 50 : 48) / s + kPanelGapV,
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
      'assets/images/icon_$name.webp',
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
                  ? 'assets/images/ui_divider_left.webp'
                  : 'assets/images/ui_divider_right.webp',
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
              // 밝은 그림 위에서도 읽히게 짙은 그림자 (11-10 A5)
              style: AppText.title(size).copyWith(shadows: const [
                Shadow(color: Color(0xE6000000), blurRadius: 6),
                // 은은한 테두리 (사방 1px 그림자)
                Shadow(color: Color(0xCC0B0D26), offset: Offset(1, 0)),
                Shadow(color: Color(0xCC0B0D26), offset: Offset(-1, 0)),
                Shadow(color: Color(0xCC0B0D26), offset: Offset(0, 1)),
                Shadow(color: Color(0xCC0B0D26), offset: Offset(0, -1)),
                Shadow(
                    color: Color(0xCC0B0D26),
                    blurRadius: 2,
                    offset: Offset(0, 1.5)),
              ])),
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
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final double fontSize;

  /// 글자 앞 아이콘 (금화·광고 등)
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        fontFamily: 'Title',
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
        letterSpacing: 0,
        color: enabled ? AppColors.goldInk : AppColors.textMuted,
      ),
    );
    return _ArtButton(
      asset: enabled
          ? 'assets/images/ui_button_gold.webp'
          : 'assets/images/ui_button_dark.webp',
      imgH: enabled ? 159 : 160,
      slice: enabled
          ? const Rect.fromLTRB(110, 48, 668 - 110, 159 - 48)
          : const Rect.fromLTRB(90, 48, 662 - 90, 160 - 48),
      height: height,
      onPressed: onPressed,
      glow: enabled,
      // 버튼 글자는 말줄임·줄바꿈 없이 다 보이게 (11-11 #87): 좁으면 글자만 줄인다
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: leading == null
            ? text
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Opacity(opacity: enabled ? 1 : 0.5, child: leading),
                SizedBox(width: fontSize * 0.3),
                text,
              ]),
      ),
    );
  }
}

/// 광고 보상 버튼 (묶음 16 #119): 금색 버튼과 같은 모양, 한 단계 작게
class AdButton extends StatelessWidget {
  const AdButton(
      {super.key, required this.label, required this.onPressed, this.height = 46});

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) => GoldButton(
        label: label,
        onPressed: onPressed,
        height: height,
        fontSize: 16,
        leading: GameGlyph(Glyph.ad, size: 18, dim: onPressed == null),
      );
}

/// 금테 두른 어두운 버튼 (ui_button_dark 그림)
class FrameButton extends StatelessWidget {
  const FrameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gameIcon,
    this.height = 50,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// 그림 아이콘 이름 (icon_<이름>.png). [icon] 보다 먼저 쓴다
  final String? gameIcon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color =
        onPressed == null ? AppColors.textMuted : AppColors.goldBright;
    return _ArtButton(
      asset: 'assets/images/ui_button_dark.webp',
      imgH: 160,
      slice: const Rect.fromLTRB(90, 48, 662 - 90, 160 - 48),
      height: height,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (gameIcon != null) ...[
            GameIcon(gameIcon!, size: 24),
            const SizedBox(width: 5),
          ] else if (icon != null) ...[
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'Title',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: color,
                ),
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
    this.glow = false,
  });

  final double ratio;
  final List<Color> colors;
  final double height;

  /// 차오르는 중: 조금 더 밝게 빛난다
  final bool glow;

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
                    color: colors.last.withValues(alpha: glow ? 0.95 : 0.6),
                    blurRadius: glow ? 14 : 8,
                    spreadRadius: glow ? 1 : 0),
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
                Image.asset('assets/images/ui_level_plaque.webp',
                    width: 250, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text('Lv.$level', style: AppText.level(34)),
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
                Image.asset('assets/images/ui_ribbon.webp',
                    width: 190, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox()),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(title,
                      style: const TextStyle(
                        fontFamily: 'Title',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.goldInk,
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
            // 눈 문장은 누를 기능이 없어 뺐다 (11-10 A4). 제목이 가운데 오게 빈칸
            const SizedBox(width: 40),
          const SizedBox(width: 6),
          // 11-11 #71: 제목 뒤 어두운 띠를 없애고 글자 그림자·테두리로 읽히게
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
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
            style: const TextStyle(color: AppColors.text, fontSize: 14)),
      ]),
    );
  }
}

/// 화면 전체 배경 (남색 + 보랏빛)
/// 묶음 67 #272: 건물 안 바탕 — 위쪽 기준으로 화면을 덮고(그림 위 40%에 그 건물다운 벽 · 물건),
/// 위는 옅게 · 아래로 갈수록 밤빛에 가까운 그라데이션을 한 겹. 그림이 없으면 아무것도 그리지 않음
class InteriorArt extends StatelessWidget {
  const InteriorArt({super.key, required this.name});
  final String name;

  static String asset(String name) => 'assets/images/bg_in_$name.webp';

  @override
  Widget build(BuildContext context) => Image.asset(
        asset(name),
        key: Key('interior_$name'),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        frameBuilder: (context, child, frame, sync) => Stack(fit: StackFit.expand, children: [
          child,
          if (frame != null || sync)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.3, 0.6, 1],
                  colors: [Color(0x660B0D26), Color(0x990B0D26), Color(0xDD0B0D26), Color(0xF50B0D26)],
                ),
              ),
            ),
        ]),
      );
}

class NightBackground extends StatelessWidget {
  const NightBackground({
    super.key,
    required this.child,
    this.header = false,
    this.statusScrim = true,
    this.interior,
  });

  final Widget child;

  /// 묶음 67 #272: 건물 안 바탕 그림 (bg_in_<이름>). 그림이 없으면 지금처럼 밤하늘
  final String? interior;

  /// 휴대폰 상태 표시줄(시계·배터리) 뒤에 어두운 띠를 깐다.
  /// 스크롤하는 내용이 표시줄 글자와 겹치지 않게 (11-10 A2).
  final bool statusScrim;

  /// 위쪽에 노을 속 탑 그림 띠(bg_header)를 깐다
  final bool header;

  @override
  Widget build(BuildContext context) {
    if (interior != null) {
      final base = _base(Stack(children: [
        Positioned.fill(child: InteriorArt(name: interior!)),
        Positioned.fill(child: child),
      ]));
      if (!statusScrim) return base;
      return Stack(children: [
        Positioned.fill(child: base),
        const Positioned(top: 0, left: 0, right: 0, child: StatusBarScrim()),
      ]);
    }
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
                  child: Image.asset('assets/images/bg_header.webp',
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.4, -0.2),
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            ),
            Positioned.fill(child: child),
          ])
        : child);
    if (!statusScrim) return base;
    return Stack(children: [
      Positioned.fill(child: base),
      const Positioned(top: 0, left: 0, right: 0, child: StatusBarScrim()),
    ]);
  }

  Widget _base(Widget child) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.6),
          radius: 1.3,
          colors: [Color(0xFF2E2A6A), Color(0xFF181B45), AppColors.deepNight],
          stops: [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}

/// 상태 표시줄 높이만큼의 어두운 띠 (아래로 살짝 번진다)
class StatusBarScrim extends StatelessWidget {
  const StatusBarScrim({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    if (top <= 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        height: top + 10,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xF50B0D26), Color(0xF50B0D26), Color(0x000B0D26)],
            stops: [0, 0.8, 1],
          ),
        ),
      ),
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


/// 한글 단어 단위로 줄을 바꾸는 글자 (11-11 #47). Text 와 같이 쓰되
/// '시 / 작해요'처럼 단어 가운데서 끊기지 않는다.
class KText extends StatelessWidget {
  const KText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text(keepAll(data),
      style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
}


/// 키보드 닫기 (11-11 #73): 입력칸 포커스를 풀고 키보드를 내린다.
void hideKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
}

/// 입력칸 바깥을 누르면 키보드를 닫는다 (11-11 #73, 앱 전체).
/// 입력칸·복사/붙여넣기 메뉴를 누를 때는 그대로 둔다.
class TapOutsideToHideKeyboard extends StatelessWidget {
  const TapOutsideToHideKeyboard({super.key, required this.child});

  final Widget child;

  static void _onDown(PointerDownEvent e) {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return;
    final typing = ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
    if (!typing) return;
    final hit = HitTestResult();
    WidgetsBinding.instance.hitTestInView(hit, e.position, e.viewId);
    for (final h in hit.path) {
      final t = h.target;
      if (t is RenderTapRegion && t.groupId == EditableText) return;
    }
    hideKeyboard();
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        child: child,
      );
}

/// 화면을 옮기거나 창이 닫힐 때마다 키보드를 닫는다 (11-11 #73)
class KeyboardCloser extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      hideKeyboard();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      hideKeyboard();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      hideKeyboard();
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      hideKeyboard();
}

/// 버튼 모양 (금색 = 주된 버튼, 어두운 = 그만두기 등)
ButtonStyle gameButtonStyle({required bool gold}) => ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(88, 44)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
      shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      textStyle: const WidgetStatePropertyAll(TextStyle(
          fontFamily: 'Title', fontWeight: FontWeight.w700, fontSize: 16)),
      backgroundColor: WidgetStateProperty.resolveWith((s) {
        final off = s.contains(WidgetState.disabled);
        if (gold) {
          return off ? const Color(0xFF4A4330) : const Color(0xFFE2B856);
        }
        return off ? const Color(0xFF1A1E3E) : const Color(0xFF232A5C);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((s) {
        final off = s.contains(WidgetState.disabled);
        if (gold) return off ? const Color(0xFF8C8370) : AppColors.goldInk;
        return off ? AppColors.textMuted : AppColors.goldBright;
      }),
      side: WidgetStateProperty.resolveWith((s) {
        final off = s.contains(WidgetState.disabled);
        return BorderSide(
            color: gold
                ? (off ? const Color(0xFF6E6248) : const Color(0xFFFBE7A6))
                : AppColors.gold.withValues(alpha: off ? 0.25 : 0.6),
            width: 1.2);
      }),
      overlayColor: WidgetStatePropertyAll(
          (gold ? Colors.white : AppColors.gold).withValues(alpha: 0.12)),
    );

/// 되돌릴 수 없는 행동 (버리기·분해·팔기): 어두운 바탕 + 붉은 테두리
ButtonStyle dangerButtonStyle() => gameButtonStyle(gold: false).copyWith(
      foregroundColor: const WidgetStatePropertyAll(Color(0xFFFFB0A4)),
      side: const WidgetStatePropertyAll(
          BorderSide(color: Color(0xFFE5484D), width: 1.6)),
    );

/// 취소: 작은 글자 버튼
ButtonStyle smallButtonStyle() => ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 36)),
      // 묶음 71: 금빛 버튼과 같은 제목 글꼴 (글꼴을 비워 두면 버튼마다 다른 글꼴로 나옴)
      textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: 'Title', fontSize: 14, fontWeight: FontWeight.w700)),
      foregroundColor: const WidgetStatePropertyAll(AppColors.textMuted),
    );

/// 금테 공용 팝업 (11-11 #72). AlertDialog 와 같은 모양으로 쓴다.
/// 마지막 버튼은 금색, 나머지는 어두운 버튼. 닫히면 키보드도 닫는다 (#73).
class GameAlert extends StatelessWidget {
  const GameAlert({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.alignment,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;

  /// 창 자리. 입력 창은 아래(키보드 바로 위)에 붙인다.
  final AlignmentGeometry? alignment;

  /// 묶음 19 6-1: 확인 창 버튼 규칙. 기본 행동은 금빛(크게), 되돌릴 수 없는
  /// 행동(버리기·분해·팔기·지우기)은 붉은 테두리, 취소는 아래에 작은 글자.
  /// 버튼 글자는 언제나 한 줄.
  static const _cancelWords = {
    '그만둘래요', '그만두기', '취소', '닫기', '나중에', '아니요', '허용 안 함',
    '다시 고를래요', '계속 쉬기', '기다릴게',
  };
  static const _dangerWords = ['버리기', '분해', '팔기', '판매', '지우기', '삭제', '포기'];

  static String? labelOf(Widget w) {
    Widget? child = w;
    if (w is ButtonStyleButton) child = w.child;
    if (child is Text) return child.data ?? child.textSpan?.toPlainText();
    if (child is FittedBox) return labelOf(child.child ?? const SizedBox());
    return null;
  }

  static List<Widget> _actionColumn(List<Widget> acts) {
    final kinds = [
      for (final a in acts)
        switch (labelOf(a)) {
          final t? when _cancelWords.contains(t.trim()) => 0,
          final t? when _dangerWords.any(t.contains) => 2,
          _ => 1,
        },
    ];
    final main = [
      for (var i = 0; i < acts.length; i++)
        if (kinds[i] != 0) i,
    ];
    // 금빛은 기본 행동 중 마지막 하나 (나머지는 어두운 버튼)
    final gold = main.lastWhere((i) => kinds[i] == 1, orElse: () => -1);
    return [
      for (final i in main) ...[
        if (i != main.first) const SizedBox(height: 8),
        TextButtonTheme(
          data: TextButtonThemeData(
              style: kinds[i] == 2
                  ? dangerButtonStyle()
                  : gameButtonStyle(gold: i == gold)),
          child: _oneLine(acts[i]),
        ),
      ],
      for (var i = 0; i < acts.length; i++)
        if (kinds[i] == 0) ...[
          SizedBox(height: main.isEmpty ? 0 : 4),
          TextButtonTheme(
            data: TextButtonThemeData(style: smallButtonStyle()),
            child: Center(child: _oneLine(acts[i])),
          ),
        ],
    ];
  }

  /// 버튼 글자가 줄바꿈되지 않게
  static Widget _oneLine(Widget w) => w;

  @override
  Widget build(BuildContext context) {
    final acts = actions ?? const <Widget>[];
    return PopScope(
      onPopInvokedWithResult: (_, __) => hideKeyboard(),
      child: Dialog(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        alignment: alignment,
        insetPadding: alignment == Alignment.bottomCenter
            ? const EdgeInsets.fromLTRB(16, 24, 16, 10)
            : const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: OrnatePanel(
            art: false,
            ornament: true,
            radius: 18,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  DefaultTextStyle.merge(
                    style: AppText.title(19),
                    textAlign: TextAlign.center,
                    child: Center(child: title!),
                  ),
                if (title != null && content != null)
                  const SizedBox(height: 12),
                if (content != null)
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14, height: 1.4),
                        child: content!,
                      ),
                    ),
                  ),
                if (acts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ..._actionColumn(acts),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 묶음 65 #253: 양피지 쪽지 (board_note 800×400) — 그림 비율 2:1 그대로, 네 모서리 장식 · 위아래 찢긴 테두리가 다 보이게.
/// 글은 안쪽 테두리 안 가운데 (넘치면 작게 줄임)
class ParchmentSheet extends StatelessWidget {
  const ParchmentSheet({super.key, required this.width, required this.child, this.tint, this.fallback = const Color(0xFFF1E0B8)});

  final double width;
  final Widget child;

  /// 물들이기 (잿빛 사연은 보랏빛)
  final Color? tint;
  final Color fallback;

  static const double ratio = 2.0;

  @override
  Widget build(BuildContext context) {
    final h = width / ratio;
    return SizedBox(
      width: width,
      height: h,
      child: Stack(children: [
        Positioned.fill(
          child: Image.asset('assets/images/board_note.webp',
              fit: BoxFit.fill,
              color: tint,
              colorBlendMode: tint == null ? null : BlendMode.modulate,
              errorBuilder: (_, __, ___) => DecoratedBox(
                    decoration: BoxDecoration(color: fallback, borderRadius: BorderRadius.circular(4)),
                  )),
        ),
        // 안쪽 테두리(그림 기준 가로 60~740 · 세로 55~345) 안
        Positioned(
          left: width * 0.085,
          right: width * 0.085,
          top: h * 0.15,
          bottom: h * 0.15,
          child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: width * 0.83, child: child))),
        ),
      ]),
    );
  }
}
