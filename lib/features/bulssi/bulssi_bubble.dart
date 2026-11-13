import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../data/storage/record_store.dart';
import 'bulssi_mood.dart';
import 'spirit_art.dart';

/// 정령 그림 + 말풍선 (팝업처럼 따로 뜨는 곳에서만).
/// 화면에서는 [BulssiLine](제목 아래 한 줄) 이나 [ArtSpirit](그림 안) 을 쓴다.
/// 정령 종류·이름·빛 색(속성 + 날씨·시간)은 [BulssiScope] 에서 받는다.
class BulssiBubble extends StatelessWidget {
  const BulssiBubble(
      {super.key,
      required this.line,
      this.size = 64,
      this.mood = SpiritMood.normal});

  final String line;
  final double size;
  final SpiritMood mood;

  @override
  Widget build(BuildContext context) {
    final scope = BulssiScope.maybeOf(context);
    final kind = scope?.kind ?? SpiritKind.fire;
    final glow = scope?.glow ?? spiritColor(kind);
    final name = scope?.spiritName ?? kind.defaultName;

    // 정령 몸 전체가 배경 위에 떠 있고, 둘레에 은은한 빛이 번진다.
    // 말풍선 첫 줄에 플레이어가 지어 준 이름을 작게 쓴다.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size * 1.1,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                left: -size * 0.25,
                right: -size * 0.25,
                top: -size * 0.2,
                bottom: -size * 0.2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          glow.withValues(alpha: 0.38),
                          glow.withValues(alpha: 0.12),
                          glow.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
              CompanionArt(size: size, mood: mood),
            ],
          ),
        ),
        const SizedBox(width: 2),
        Flexible(
          child: SpeechBubbleArt(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '$name\n',
                  style: const TextStyle(
                    color: Color(0xFFB27C1C),
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: keepAll(line)),
              ]),
              style: const TextStyle(
                color: AppColors.night,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 정령 둘레의 은은한 빛
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.child, this.spread = 0.3});

  final Color color;
  final Widget child;
  final double spread;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Transform.scale(
              scale: 1 + spread * 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      color.withValues(alpha: 0.38),
                      color.withValues(alpha: 0.1),
                      color.withValues(alpha: 0),
                    ], stops: const [0, 0.45, 1]),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      );
}

/// 그림이 없는 화면: 제목 바로 아래 고정 자리의 정령 아이콘 + 한 줄 대사 (11-10 A3)
class BulssiLine extends StatelessWidget {
  const BulssiLine(
      {super.key, required this.line, this.mood = SpiritMood.normal});

  final String line;
  final SpiritMood mood;

  @override
  Widget build(BuildContext context) {
    final scope = BulssiScope.maybeOf(context);
    final kind = scope?.kind ?? SpiritKind.fire;
    final glow = scope?.glow ?? spiritColor(kind);
    final name = scope?.spiritName ?? kind.defaultName;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(children: [
        _Glow(
            color: glow,
            child: CompanionArt(size: 38, mood: mood)),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '$name  ',
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
              ),
              TextSpan(text: keepAll(line)),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

/// 위쪽 그림이 있는 화면: 그림 속 각성자 오른쪽 빈자리에 떠 있는 작은 정령과
/// 각성자 쪽(왼쪽 아래)을 향한 말풍선 (11-10 A3)
class ArtSpirit extends StatelessWidget {
  const ArtSpirit(
      {super.key,
      required this.line,
      this.size = 50,
      this.mood = SpiritMood.normal});

  final String line;
  final double size;
  final SpiritMood mood;

  @override
  Widget build(BuildContext context) {
    final scope = BulssiScope.maybeOf(context);
    final kind = scope?.kind ?? SpiritKind.fire;
    final glow = scope?.glow ?? spiritColor(kind);
    final name = scope?.spiritName ?? kind.defaultName;
    // 11-10 #28: 말풍선은 정령 바로 옆(왼쪽)에 붙이고 꼬리(오른쪽 아래)가 정령을 향한다.
    // 각성자 얼굴·손을 가리지 않게 화면 오른쪽 위에 작게. 긴 대사는 글자를 줄인다.
    final long = line.length > 30;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.35),
            child: SpeechBubbleArt(
              mirrored: true,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$name\n',
                    style: const TextStyle(
                        color: Color(0xFFB27C1C),
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: keepAll(line)),
                ]),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.night,
                    fontSize: long ? 11.5 : 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        _Glow(
            color: glow,
            spread: 0.4,
            child: CompanionArt(size: size, mood: mood)),
      ],
    );
  }
}

/// 정령 배지 + 말풍선 (묶음 20 #158·#159): 프로필 바로 아래 같은 크기의 금테 원형
/// 배지(진한 남색 바탕) 안에 정령(이별 뒤엔 함께하는 펫). 말풍선은 배지 오른쪽,
/// 배지와 같은 높이에서 시작하고 꼬리는 배지 쪽(왼쪽). 말이 바뀌면 배지가 살짝
/// 톡톡 튀며 말풍선이 열리고, 잠시 뒤 접힌다. 배지를 누르면 다시 말한다.
class SpiritTalkBadge extends StatefulWidget {
  const SpiritTalkBadge({
    super.key,
    required this.line,
    required this.maxBubbleWidth,
    this.mood = SpiritMood.normal,
    this.size = 44,
    this.hideAfter = const Duration(seconds: 8),
    this.bubbleKey = const Key('spiritBubble'),
    this.retalk,
  });

  /// 바뀔 때마다 다시 말한다 (아래 메뉴 칸에 들어올 때, 묶음 22)
  final Listenable? retalk;

  final String line;
  final double maxBubbleWidth;
  final SpiritMood mood;
  final double size;
  final Duration hideAfter;
  final Key bubbleKey;

  @override
  State<SpiritTalkBadge> createState() => _SpiritTalkBadgeState();
}

class _SpiritTalkBadgeState extends State<SpiritTalkBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 180));
  String? _said;
  bool _open = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.retalk?.addListener(_again);
  }

  void _again() {
    if (mounted) setState(_talk);
  }

  void _talk() {
    _open = true;
    _hop
      ..reset()
      ..repeat(reverse: true, count: 2);
    _hide?.cancel();
    _hide = Timer(widget.hideAfter, () {
      if (mounted) setState(() => _open = false);
    });
  }

  @override
  void dispose() {
    widget.retalk?.removeListener(_again);
    _hide?.cancel();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.line != _said) {
      _said = widget.line;
      _talk();
    }
    final s = widget.size;
    final scope = BulssiScope.maybeOf(context);
    final kind = scope?.kind ?? SpiritKind.fire;
    final name = scope?.spiritName ?? kind.defaultName;
    final badge = GestureDetector(
      key: const Key('spiritBadge'),
      onTap: () => setState(_talk),
      child: AnimatedBuilder(
        animation: _hop,
        builder: (context, child) => Transform.translate(
            offset: Offset(0, -3 * Curves.easeOut.transform(_hop.value)),
            child: child),
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF141638),
            border: Border.all(color: AppColors.goldBright, width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 8),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: CompanionArt(size: s * 0.82, mood: widget.mood),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        badge,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: !_open
              ? const SizedBox.shrink()
              : GestureDetector(
                  key: widget.bubbleKey,
                  onTap: () => setState(() => _open = false),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: widget.maxBubbleWidth),
                      child: CustomPaint(
                        painter: _LeftTailBubble(tailY: s / 2),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 7, 10, 8),
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: '$name\n',
                                style: const TextStyle(
                                  color: Color(0xFFB27C1C),
                                  fontSize: 11,
                                  height: 1.4,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(text: keepAll(widget.line)),
                            ]),
                            style: const TextStyle(
                              color: AppColors.night,
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 꼬리가 왼쪽(배지 쪽)을 가리키는 말풍선 바탕
class _LeftTailBubble extends CustomPainter {
  _LeftTailBubble({required this.tailY});

  final double tailY;
  static const double _tail = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(_tail, 0, size.width - _tail, size.height),
        const Radius.circular(12));
    final ty = tailY.clamp(12.0, size.height - 12);
    final path = Path()
      ..addRRect(body)
      ..moveTo(_tail + 1, ty - 7)
      ..lineTo(0, ty)
      ..lineTo(_tail + 1, ty + 7)
      ..close();
    final shape = Path.combine(PathOperation.union, Path()..addRRect(body),
        Path()..moveTo(_tail + 1, ty - 7)..lineTo(0, ty)..lineTo(_tail + 1, ty + 7)..close());
    canvas.drawShadow(path, const Color(0xAA000000), 3, false);
    canvas.drawPath(shape, Paint()..color = const Color(0xFFFFF6E0));
    canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFC9A24A));
  }

  @override
  bool shouldRepaint(_LeftTailBubble old) => old.tailY != tailY;
}

/// 아래 메뉴 칸에 들어올 때마다 늘어나는 수 (마을·가방·도감 정령이 다시 말한다)
final ValueNotifier<int> spiritTabVisits = ValueNotifier<int>(0);

/// 마을·가방·도감 위쪽 정령 (묶음 22, #159 확장): 지도·상태 화면과 같은 금테 배지 +
/// 오른쪽 말풍선. 칸에 들어올 때 한 번 말하고 접힌다. 말풍선은 아래 내용 위로 겹쳐
/// 열리고(내용이 밀리지 않게), 접히면 배지 한 줄만 남는다.
class SpiritBadgeRow extends StatefulWidget {
  const SpiritBadgeRow(
      {super.key, required this.line, this.mood = SpiritMood.normal});

  final String line;
  final SpiritMood mood;

  @override
  State<SpiritBadgeRow> createState() => _SpiritBadgeRowState();
}

class _SpiritBadgeRowState extends State<SpiritBadgeRow> {
  // 말풍선이 아래 내용(마을 그림 등)에 가리지 않게 화면 맨 위 겹(Overlay)에 그린다.
  // 자리는 이 줄을 따라가고, 칸이 숨거나 다른 화면이 덮으면 함께 숨는다.
  final _link = LayerLink();
  final _portal = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _portal.show();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final maxW = (box.maxWidth - 46 - 8).clamp(140.0, 420.0);
          return CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _portal,
              overlayChildBuilder: (_) => CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SpiritTalkBadge(
                    line: widget.line,
                    mood: widget.mood,
                    retalk: spiritTabVisits,
                    maxBubbleWidth: maxW,
                  ),
                ),
              ),
              child: const SizedBox(height: 44, width: double.infinity),
            ),
          );
        },
      );
}
