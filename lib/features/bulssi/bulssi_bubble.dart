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
      // 묶음 69 #288: 캐릭터를 먼저 놓고 말풍선 꼬리는 캐릭터 얼굴 높이
      crossAxisAlignment: CrossAxisAlignment.start,
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
            // 꼬리는 정령 얼굴 높이 (말풍선 위쪽에서 정령 높이의 절반쯤)
            at: size * 0.5,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '$name\n',
                  style: const TextStyle(
                    color: kBubbleName,
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
              side: BubbleSide.right,
              at: -size * 0.2,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '$name\n',
                    style: const TextStyle(
                        color: kBubbleName,
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
/// 묶음 77 #352: 안내(튜토리얼)가 떠 있는 동안 화면의 정령 얼굴 · 말풍선을 숨긴다 (펫이 하나만 보이게)
final ValueNotifier<int> tourShowing = ValueNotifier<int>(0);

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
    this.actionLabel,
    this.onAction,
    this.more = const [],
    this.urgent = false,
    this.visible,
  });

  /// 보이는지 (말풍선을 맨 위 겹에 그리는 SpiritBadgeRow 가 자기 자리로 알려 줌). null 이면 TickerMode
  final bool? visible;

  /// 묶음 75 #320: 꼭 알릴 말(지금 상황 · 새 소식)이면 들어올 때 이 대사부터
  final bool urgent;

  /// 묶음 69 #289: 열 때마다 차례로 보여 줄 다른 대사
  final List<String> more;

  /// 묶음 25 #166: 배지를 눌렀을 때 대사 끝에 붙는 한마디 (예: 「서두를까?」).
  /// 누르면 [onAction]
  final String? actionLabel;
  final VoidCallback? onAction;

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
  bool _open = false;
  bool _withAction = false;
  String _now = '';

  /// 묶음 75 #320: 말풍선을 눌러 닫았으면 이 화면에 있는 동안 저절로 다시 안 뜸
  bool _dismissed = false;
  bool _shown = false;
  Timer? _close;

  List<String> get _lines => [widget.line, ...(widget.more.isEmpty ? idleTalk : widget.more).where((x) => x != widget.line)];

  /// 화면에 들어올 때마다 대사 하나가 저절로 열렸다가 5초 뒤 닫힘 (꼭 알릴 말이 먼저, 아니면 다음 대사)
  void _enter() {
    _dismissed = false;
    final urgent = widget.urgent || (widget.actionLabel != null && widget.onAction != null);
    _say(urgent ? widget.line : TalkTurns.next('spirit', _lines));
  }

  void _say(String line) {
    _now = line;
    _open = true;
    _withAction = widget.actionLabel != null && widget.onAction != null;
    _hop
      ..reset()
      ..repeat(reverse: true, count: 2);
    _close?.cancel();
    _close = Timer(TalkTurns.autoClose, () {
      if (mounted) setState(() => _open = false);
    });
    if (mounted) setState(() {});
  }

  /// 얼굴을 누르면 언제든 다음 대사
  void _tapFace() => _say(TalkTurns.next('spirit', _lines));

  /// 보이는 칸인지 (아래 메뉴의 숨은 칸은 TickerMode 가 꺼짐)
  bool get _visible => widget.visible ?? TickerMode.valuesOf(context).enabled;

  /// 보이는 칸이 됐을 때(처음 · 아래 메뉴로 돌아옴) 한 번
  void _sync() {
    final on = _visible;
    if (on && !_shown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _visible) _enter();
      });
    }
    if (!on && _open) {
      _close?.cancel();
      _open = false;
    }
    _shown = on;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SpiritTalkBadge old) {
    super.didUpdateWidget(old);
    if (old.visible != widget.visible) _sync();
    // 꼭 알릴 말이 새로 생기면 (눌러서 닫지 않았으면) 바로
    if (widget.urgent && widget.line != old.line && !_dismissed && _visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _say(widget.line);
      });
    }
  }

  @override
  void dispose() {
    _close?.cancel();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: tourShowing,
        builder: (context, n, child) => Visibility(
          visible: n == 0,
          maintainSize: true,
          maintainState: true,
          maintainAnimation: true,
          child: child!,
        ),
        child: Builder(builder: _build),
      );

  Widget _build(BuildContext context) {
    final action = _withAction && widget.onAction != null
        ? widget.actionLabel
        : null;
    final s = widget.size;
    final scope = BulssiScope.maybeOf(context);
    final kind = scope?.kind ?? SpiritKind.fire;
    final name = scope?.spiritName ?? kind.defaultName;
    final badge = GestureDetector(
      key: const Key('spiritBadge'),
      onTap: _tapFace,
      child: AnimatedBuilder(
        animation: _hop,
        builder: (context, child) => Transform.translate(
            offset: Offset(0, -3 * Curves.easeOut.transform(_hop.value)),
            child: child),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
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
        ]),
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
                  onTap: () => setState(() {
                    _open = false;
                    _dismissed = true;
                    _close?.cancel();
                  }),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(maxWidth: widget.maxBubbleWidth),
                      child: CodeBubble(
                        side: BubbleSide.left,
                        at: s / 2,
                        stroke: CodeBubblePainter.thin,
                        padding: const EdgeInsets.fromLTRB(10, 7, 12, 8),
                        minWidth: 60,
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: '$name\n',
                              style: const TextStyle(
                                color: kBubbleName,
                                fontSize: 11,
                                height: 1.4,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(text: keepAll(_now)),
                            if (action != null) ...[
                              const TextSpan(text: ' '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: GestureDetector(
                                  key: const Key('spiritAction'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() {
                                      _open = false;
                                      _withAction = false;
                                    });
                                    widget.onAction?.call();
                                  },
                                  child: Text(action,
                                      style: const TextStyle(
                                        color: kBubbleName,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        decoration: TextDecoration.underline,
                                      )),
                                ),
                              ),
                            ],
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
      ],
    );
  }
}

/// 묶음 75 #320: 정령 · 마을 사람마다 다음 대사 차례 (앱이 저장 · 불러옴)
class TalkTurns {
  TalkTurns._();

  static final Map<String, int> _turns = {};

  /// 바뀔 때마다 저장 (앱이 정함)
  static void Function(Map<String, int>)? onSave;

  /// 저절로 열린 말풍선이 닫히기까지
  static const Duration autoClose = Duration(seconds: 5);

  static void load(Map<String, int> m) => _turns
    ..clear()
    ..addAll(m);

  /// [who] 의 다음 대사 (차례를 하나 넘김)
  static String next(String who, List<String> lines) {
    if (lines.isEmpty) return '';
    final n = _turns[who] ?? 0;
    _turns[who] = n + 1;
    onSave?.call(Map.of(_turns));
    return lines[n % lines.length];
  }
}

/// 묶음 69 #289: 얼굴을 누를 때마다 차례로 나오는 평소 대사 (그 화면 대사 다음)
const List<String> idleTalk = [
  '오늘도 같이 걸어서 좋아!',
  '조금 쉬었다 가도 괜찮아. 천천히 가자.',
  '걷다 보면 새로운 게 꼭 보이더라.',
  '물 한 모금 마시고 갈까?',
  '네 발소리가 들리면 힘이 나.',
];

/// 말풍선 꼬리가 나오는 쪽 (묶음 25 #164)
enum TailSide { left, right, down }

/// 꼬리가 말하는 쪽(왼쪽·오른쪽·아래)을 가리키는 말풍선 바탕.
/// [at] 은 꼬리 자리: 왼쪽·오른쪽이면 위에서부터, 아래면 왼쪽에서부터 (논리 픽셀)
class TailBubblePainter extends CustomPainter {
  TailBubblePainter({required this.side, required this.at});

  final TailSide side;
  final double at;
  static const double tail = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
        switch (side) {
          TailSide.left =>
            Rect.fromLTWH(tail, 0, size.width - tail, size.height),
          TailSide.right => Rect.fromLTWH(0, 0, size.width - tail, size.height),
          TailSide.down => Rect.fromLTWH(0, 0, size.width, size.height - tail),
        },
        const Radius.circular(12));
    final Path tip;
    switch (side) {
      case TailSide.left:
        final ty = at.clamp(12.0, size.height - 12);
        tip = Path()
          ..moveTo(tail + 1, ty - 7)
          ..lineTo(0, ty)
          ..lineTo(tail + 1, ty + 7)
          ..close();
      case TailSide.right:
        final ty = at.clamp(12.0, size.height - 12);
        final x = size.width - tail;
        tip = Path()
          ..moveTo(x - 1, ty - 7)
          ..lineTo(size.width, ty)
          ..lineTo(x - 1, ty + 7)
          ..close();
      case TailSide.down:
        final tx = at.clamp(14.0, size.width - 14);
        final y = size.height - tail;
        tip = Path()
          ..moveTo(tx - 7, y - 1)
          ..lineTo(tx, size.height)
          ..lineTo(tx + 7, y - 1)
          ..close();
    }
    final shape =
        Path.combine(PathOperation.union, Path()..addRRect(body), tip);
    canvas.drawShadow(shape, const Color(0xAA000000), 3, false);
    canvas.drawPath(shape, Paint()..color = const Color(0xFFFFF6E0));
    canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFC9A24A));
  }

  @override
  bool shouldRepaint(TailBubblePainter old) =>
      old.side != side || old.at != at;
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
          // 묶음 75 #320: 이 줄이 보이는 칸에 있을 때만 말함 (말풍선은 맨 위 겹이라 자리로 알려 줌)
          final visible = TickerMode.valuesOf(context).enabled;
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
                    visible: visible,
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
