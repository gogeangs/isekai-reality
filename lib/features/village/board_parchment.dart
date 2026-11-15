import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/ornaments.dart';

/// 판타지 의뢰 게시판 (묶음 26 #180): 나무 게시판 위에 핀으로 꽂은 양피지 쪽지.
///
/// 그림(board_bg·board_note·board_pin·board_seal·board_done)이 들어오면 그것을 쓰고,
/// 없으면 코드로 그린 임시 그림을 쓴다.

/// 게시판 그림 자리. 그림이 아직 없으면 코드로 그린 임시 그림이 보인다
/// (그림 경로 점검 시험이 빠진 그림을 오류로 보지 않게 이름만 적는다)
String boardArt(String name) => 'assets/images/$name.webp';

/// 쪽지 글씨 (진한 갈색)
const Color kInk = Color(0xFF3A2614);

/// 쪽지 작은 글씨
const Color kInkSoft = Color(0xFF6E4C2C);

const Color _paperTop = Color(0xFFF4E4BE);
const Color _paperBottom = Color(0xFFE6CC98);
const Color _sealRed = Color(0xFFA3231C);
const Color _stampRed = Color(0xFFB0352B);

/// 쪽지 제목 글씨
TextStyle noteTitle([double size = 16]) =>
    AppText.title(size, color: kInk).copyWith(height: 1.3);

/// 나무 게시판: 판자 + 테두리 나무틀. 안쪽에 쪽지들을 놓는다.
/// 묶음 28: board_bg 그림은 위(문장·등불)·아래(나무틀 끝)를 그대로 두고
/// 가운데 판자만 세로로 이어 붙인다 (세로 9-slice). 그림이 없으면 코드로 그린 판자.
class WoodBoard extends StatefulWidget {
  const WoodBoard(
      {super.key, required this.child, this.topInset = 0, this.minHeight = 0});

  final Widget child;

  /// 묶음 39 #217 전체 화면: 위쪽에 얹은 버튼·마을 사람 아래부터 내용 (최소 위 여백)
  final double topInset;

  /// 게시판이 화면 끝까지 이어지게 하는 최소 높이
  final double minHeight;

  /// 그림에서 늘리지 않는 위·아래 높이 (그림 픽셀)
  static const double artTop = 220, artBottom = 120, artWidth = 1024;

  @override
  State<WoodBoard> createState() => _WoodBoardState();
}

class _WoodBoardState extends State<WoodBoard> {
  ui.Image? _art;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      if (mounted) setState(() => _art = info.image);
    },
    onError: (_, __) {},
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AssetImage(boardArt('board_bg'))
        .resolve(createLocalImageConfiguration(context));
    if (s.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = s..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = _art;
    if (art == null) return _fallback();
    return LayoutBuilder(builder: (context, box) {
      final s = box.maxWidth / art.width;
      return Container(
        key: const Key('woodBoard'),
        constraints: BoxConstraints(minHeight: widget.minHeight),
        child: CustomPaint(
          painter: _BoardArtPainter(art),
          child: Padding(
            // 위 문장·등불 아래부터(위에 얹은 것이 있으면 그 아래), 양옆 나무틀 안쪽에
            padding: EdgeInsets.fromLTRB(
                62 * s,
                math.max(WoodBoard.artTop * s, widget.topInset),
                62 * s,
                WoodBoard.artBottom * s + 6),
            child: widget.child,
          ),
        ),
      );
    });
  }

  Widget _fallback() => Container(
        key: const Key('woodBoard'),
        constraints: BoxConstraints(minHeight: widget.minHeight),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3B2410), width: 7),
          boxShadow: const [
            BoxShadow(
                color: Color(0x99000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(children: [
            const Positioned.fill(child: CustomPaint(painter: _WoodPainter())),
            Padding(
              padding: EdgeInsets.fromLTRB(12, math.max(14, widget.topInset), 12, 16),
              child: widget.child,
            ),
          ]),
        ),
      );
}

/// 게시판 그림: 위·아래는 그대로, 가운데 판자는 세로로 이어 붙인다
class _BoardArtPainter extends CustomPainter {
  _BoardArtPainter(this.art);

  final ui.Image art;

  @override
  void paint(Canvas canvas, Size size) {
    final w = art.width.toDouble(), h = art.height.toDouble();
    final s = size.width / w;
    const top = WoodBoard.artTop, bottom = WoodBoard.artBottom;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    final topDst = Rect.fromLTWH(0, 0, size.width, top * s);
    final bottomDst =
        Rect.fromLTWH(0, size.height - bottom * s, size.width, bottom * s);
    // 가운데 판자 (그림 높이만큼씩 이어 붙임)
    final midSrcH = h - top - bottom;
    final midDstH = midSrcH * s;
    var y = topDst.bottom;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, topDst.bottom, size.width, bottomDst.top));
    while (y < bottomDst.top) {
      canvas.drawImageRect(art, Rect.fromLTWH(0, top, w, midSrcH),
          Rect.fromLTWH(0, y, size.width, midDstH), paint);
      y += midDstH;
    }
    canvas.restore();
    canvas.drawImageRect(art, Rect.fromLTWH(0, 0, w, top), topDst, paint);
    canvas.drawImageRect(
        art, Rect.fromLTWH(0, h - bottom, w, bottom), bottomDst, paint);
  }

  @override
  bool shouldRepaint(_BoardArtPainter old) => old.art != art;
}

/// 가로 판자와 나뭇결 (임시 그림)
class _WoodPainter extends CustomPainter {
  const _WoodPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const plank = 58.0;
    final n = (size.height / plank).ceil();
    for (var i = 0; i < n; i++) {
      final top = i * plank;
      final rect = Rect.fromLTWH(0, top, size.width, plank);
      final shade = i.isEven ? 0.0 : 0.05;
      canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(const Color(0xFF7A4E28), Colors.black, shade)!,
                Color.lerp(const Color(0xFF61391A), Colors.black, shade)!,
              ],
            ).createShader(rect));
      // 나뭇결
      final rng = math.Random(i * 7919 + 13);
      final grain = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x22000000);
      for (var g = 0; g < 4; g++) {
        final y = top + 8 + rng.nextDouble() * (plank - 16);
        final path = Path()..moveTo(0, y);
        for (var x = 0.0; x <= size.width; x += 24) {
          path.lineTo(x, y + math.sin(x / 40 + g + i) * 2.2);
        }
        canvas.drawPath(path, grain);
      }
      // 판자 사이 틈
      canvas.drawLine(Offset(0, top), Offset(size.width, top),
          Paint()
            ..color = const Color(0xFF2E1A0B)
            ..strokeWidth = 2);
      // 못
      for (final x in [10.0, size.width - 10]) {
        canvas.drawCircle(Offset(x, top + plank / 2), 2.4,
            Paint()..color = const Color(0xFF2A1A0E));
      }
    }
  }

  @override
  bool shouldRepaint(_WoodPainter old) => false;
}

/// 나무 이름판 (오늘의 의뢰 · 길드 의뢰 …)
class BoardPlaque extends StatelessWidget {
  const BoardPlaque(this.title, {super.key, this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4E3018), Color(0xFF34200E)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF9A6C3E), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x88000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: AppText.title(17, color: const Color(0xFFF3DFB0))),
          ),
          if (note != null)
            Text(note!,
                style: const TextStyle(
                    color: Color(0xFFD8C096),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
        ]),
      );
}

/// 양피지 쪽지 한 장: 위에 핀, 살짝 기울어짐(±2° 안).
/// [faded] 면 다 한 쪽지처럼 흐리게 (단, [action] 버튼은 그대로 또렷하게).
class ParchmentNote extends StatelessWidget {
  const ParchmentNote({
    super.key,
    required this.child,
    this.seed = 0,
    this.faded = false,
    this.action,
    this.stamp,
    this.ribbon = false,
    this.edge,
    this.small = false,
  });

  final Widget child;

  /// 두 칸 쪽지 (묶음 37 #206): 세로 쪽지 그림 board_note_small, 높이는 내용만큼,
  /// 칸 높이가 정해지면(같은 줄의 높은 쪽) 그만큼 채운다
  final bool small;

  /// 기울기를 정하는 수 (쪽지마다 다르게)
  final int seed;
  final bool faded;
  final Widget? action;

  /// 오른쪽 아래에 찍는 도장·인장
  final Widget? stamp;

  /// 금색 리본 (모두 완료 보너스 쪽지)
  final bool ribbon;

  /// 테두리 색 (긴급 의뢰는 빨강)
  final Color? edge;

  /// 두 칸 쪽지 안 글·진행 줄의 좌우 여백 (보이는 종이 기준, 묶음 38 #215)
  static const double smallSide = 22;

  /// 핀이 쪽지 위로 튀어나온 높이 (줄 사이는 이보다 넉넉히)
  static const double pinRise = 17;

  /// 이 쪽지의 기울기 (도)
  static double tiltOf(int seed) => ((seed * 37 + 11) % 9 - 4) * 0.45;

  @override
  Widget build(BuildContext context) {
    final tilt = tiltOf(seed) * (small ? 0.5 : 1) * math.pi / 180;
    // 그림이 없을 때 쓰는 종이 (코드로 그림)
    final drawn = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: faded
              ? [const Color(0xFFE9DDC3), const Color(0xFFD9C8A4)]
              : const [_paperTop, _paperBottom],
        ),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
            color: edge ?? const Color(0x66A07840), width: edge == null ? 1 : 2),
        boxShadow: const [
          BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(2, 4)),
        ],
      ),
    );
    final paper = ConstrainedBox(
      // 늘린 쪽지의 귀퉁이 장식이 겹치지 않을 만큼은 높게
      constraints: BoxConstraints(minHeight: small ? 56 : 78),
      child: Stack(children: [
        // 묶음 28: 양피지 그림 (9-slice, 귀퉁이 장식은 늘리지 않음)
        Positioned.fill(
          child: Opacity(
            opacity: faded ? 0.82 : 1,
            // 묶음 39 #218·#219: 엔진의 9조각 그리기(centerSlice)는 실제 기기(Impeller)에서
            // 귀퉁이가 다르게 그려져 종이가 비뚤어지거나 잘려 보임 → 9조각을 직접 그린다
            child: small
                ? NineSliceArt(
                    asset: boardArt('board_note_small'),
                    slice: const Rect.fromLTRB(72, 72, 312, 408),
                    scale: 3.2,
                    fallback: drawn)
                : NineSliceArt(
                    asset: boardArt('board_note'),
                    slice: const Rect.fromLTRB(110, 92, 690, 308),
                    scale: 2.4,
                    fallback: drawn),
          ),
        ),
        if (edge != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: edge!, width: 2),
                ),
              ),
            ),
          ),
        if (ribbon)
          Positioned(
            top: 6,
            left: 10,
            right: 10,
            child: Container(
              height: 7,
              decoration: const BoxDecoration(gradient: kGoldGradient),
            ),
          ),
        Padding(
          // 묶음 38 #215: 둘레 투명 여백·찢긴 가장자리 안쪽 「보이는 종이」 기준으로
          padding: small
              ? const EdgeInsets.fromLTRB(
                  ParchmentNote.smallSide, 17, ParchmentNote.smallSide, 13)
              : EdgeInsets.fromLTRB(18, ribbon ? 22 : 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(opacity: faded ? 0.72 : 1, child: child),
              if (action != null) ...[const SizedBox(height: 8), action!],
            ],
          ),
        ),
        if (stamp != null)
          Positioned(
              right: 10, bottom: 8, child: IgnorePointer(child: stamp!)),
        if (ribbon)
          const Positioned(top: -2, left: 10, child: _RibbonTail()),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Transform.rotate(
        angle: tilt,
        // passthrough: 칸 높이가 정해져 있으면 쪽지가 그만큼 채운다
        child: Stack(
            clipBehavior: Clip.none, fit: StackFit.passthrough, children: [
          paper,
          // 핀
          // 옆에서 본 핀: 머리는 쪽지 위 가장자리, 바늘 끝은 쪽지 안쪽으로 살짝
          const Positioned(
            top: -17,
            left: 0,
            right: 0,
            child: Center(child: BoardPin()),
          ),
        ]),
      ),
    );
  }
}

/// 9조각 그림 (귀퉁이·가장자리는 늘리지 않고 가운데만 늘림). [slice] 는 그림 픽셀,
/// 귀퉁이는 그림 픽셀 ÷ [scale] 크기로. 칸이 귀퉁이보다 작으면 귀퉁이를 함께 줄인다.
/// 그림을 못 읽으면 [fallback]
class NineSliceArt extends StatefulWidget {
  const NineSliceArt({
    super.key,
    required this.asset,
    required this.slice,
    required this.scale,
    this.fallback = const SizedBox.shrink(),
  });

  final String asset;
  final Rect slice;
  final double scale;
  final Widget fallback;

  @override
  State<NineSliceArt> createState() => _NineSliceArtState();
}

class _NineSliceArtState extends State<NineSliceArt> {
  ui.Image? _art;
  bool _failed = false;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      if (mounted) setState(() => _art = info.image);
    },
    onError: (_, __) {
      if (mounted) setState(() => _failed = true);
    },
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AssetImage(widget.asset)
        .resolve(createLocalImageConfiguration(context));
    if (s.key != _stream?.key) {
      _stream?.removeListener(_listener);
      _stream = s..addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = _art;
    if (art == null) return _failed ? widget.fallback : const SizedBox.expand();
    return CustomPaint(
      size: Size.infinite,
      painter: _NineSlicePainter(art, widget.slice, widget.scale),
    );
  }
}

class _NineSlicePainter extends CustomPainter {
  _NineSlicePainter(this.art, this.slice, this.scale);

  final ui.Image art;
  final Rect slice;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final w = art.width.toDouble(), h = art.height.toDouble();
    // 그림 픽셀 기준 네 귀퉁이 크기
    final l = slice.left, t = slice.top, r = w - slice.right, b = h - slice.bottom;
    // 화면 크기 (칸이 작으면 귀퉁이를 같은 비율로 줄임)
    var dl = l / scale, dr = r / scale, dt = t / scale, db = b / scale;
    final kx = math.min(1.0, size.width / (dl + dr));
    final ky = math.min(1.0, size.height / (dt + db));
    dl *= kx;
    dr *= kx;
    dt *= ky;
    db *= ky;
    final sx = [0.0, l, w - r, w];
    final sy = [0.0, t, h - b, h];
    final dx = [0.0, dl, size.width - dr, size.width];
    final dy = [0.0, dt, size.height - db, size.height];
    final paint = Paint()..filterQuality = FilterQuality.medium;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final src = Rect.fromLTRB(sx[i], sy[j], sx[i + 1], sy[j + 1]);
        final dst = Rect.fromLTRB(dx[i], dy[j], dx[i + 1], dy[j + 1]);
        if (src.isEmpty || dst.isEmpty) continue;
        canvas.drawImageRect(art, src, dst, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_NineSlicePainter old) =>
      old.art != art || old.slice != slice || old.scale != scale;
}

/// 같은 줄 칸들을 같은 폭으로 놓고, 가장 높은 칸의 높이에 모두 맞춘다 (묶음 39 #218).
/// 칸마다 실제로 그려 본 높이로 정하므로(미리 재는 값이 아님) 어떤 칸도 줄 밖으로 넘치지 않는다
class EqualHeightRow extends MultiChildRenderObjectWidget {
  const EqualHeightRow({super.key, required super.children, this.gap = 0});

  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualRow(gap);

  @override
  void updateRenderObject(BuildContext context, _RenderEqualRow r) =>
      r.gap = gap;
}

class _EqualRowData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EqualRowData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EqualRowData> {
  _RenderEqualRow(this._gap);

  double _gap;
  set gap(double v) {
    if (v == _gap) return;
    _gap = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EqualRowData) child.parentData = _EqualRowData();
  }

  double _cell(double width) =>
      childCount == 0 ? 0 : (width - _gap * (childCount - 1)) / childCount;

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    final cw = _cell(w);
    var maxH = 0.0;
    var child = firstChild;
    while (child != null) {
      child.layout(BoxConstraints(minWidth: cw, maxWidth: cw),
          parentUsesSize: true);
      maxH = math.max(maxH, child.size.height);
      child = childAfter(child);
    }
    var x = 0.0;
    child = firstChild;
    while (child != null) {
      // 높이를 꼭 맞춘 제약(tight)이면 칸이 혼자서 다시 그려질 때 이 줄을 다시 재지 않아
      // 내용이 줄 밖으로 넘칠 수 있다 → 「최소 maxH」로만 준다
      child.layout(
          BoxConstraints(minWidth: cw, maxWidth: cw, minHeight: maxH),
          parentUsesSize: true);
      maxH = math.max(maxH, child.size.height);
      (child.parentData! as _EqualRowData).offset = Offset(x, 0);
      x += cw + _gap;
      child = childAfter(child);
    }
    size = constraints.constrain(Size(w, maxH));
  }

  double _maxChild(double Function(RenderBox) f) {
    var m = 0.0;
    var child = firstChild;
    while (child != null) {
      m = math.max(m, f(child));
      child = childAfter(child);
    }
    return m;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      _maxChild((c) => c.getMinIntrinsicHeight(_cell(width)));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _maxChild((c) => c.getMaxIntrinsicHeight(_cell(width)));

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// 쪽지를 꽂은 핀
class BoardPin extends StatelessWidget {
  const BoardPin({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 30,
        height: 30,
        child: Image.asset(boardArt('board_pin'),
            errorBuilder: (_, __, ___) =>
                const CustomPaint(painter: _PinPainter())),
      );
}

class _PinPainter extends CustomPainter {
  const _PinPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(c + const Offset(1.5, 2.5), 7,
        Paint()..color = const Color(0x66000000));
    canvas.drawCircle(
        c,
        7,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.4, -0.4),
            colors: [Color(0xFFE8746A), Color(0xFF8E1F18)],
          ).createShader(Rect.fromCircle(center: c, radius: 7)));
    canvas.drawCircle(c + const Offset(-2.2, -2.2), 1.8,
        Paint()..color = const Color(0xCCFFFFFF));
  }

  @override
  bool shouldRepaint(_PinPainter old) => false;
}

class _RibbonTail extends StatelessWidget {
  const _RibbonTail();

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (final a in [-0.35, 0.35])
          Transform.rotate(
            angle: a,
            child: Container(
              width: 9,
              height: 22,
              decoration: const BoxDecoration(gradient: kGoldGradient),
            ),
          ),
      ]);
}

/// 쪽지 아래 보상 띠
class NoteRewards extends StatelessWidget {
  const NoteRewards({super.key, required this.items, this.done = false});

  /// (아이콘, 글)
  final List<(Widget, String)> items;
  final bool done;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        decoration: BoxDecoration(
          color: const Color(0x22704A20),
          borderRadius: BorderRadius.circular(3),
          border: const Border(
              top: BorderSide(color: Color(0x55704A20), width: 1)),
        ),
        child: Wrap(spacing: 10, runSpacing: 2, children: [
          for (final (icon, text) in items)
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(width: 15, height: 15, child: icon),
              const SizedBox(width: 3),
              Text(text,
                  style: TextStyle(
                      color: done ? kInkSoft : kInk,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: kInkSoft)),
            ]),
        ]),
      );
}

/// 잉크 선 진행 막대
class InkBar extends StatelessWidget {
  const InkBar({super.key, required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 6,
        child: Stack(alignment: Alignment.centerLeft, children: [
          Container(height: 1.4, color: const Color(0x553A2614)),
          FractionallySizedBox(
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: kInk,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ]),
      );
}

/// 수락하면 찍히는 빨간 밀랍 도장. [stampIn] 이면 「쿵」 찍히며 나타난다
class WaxSeal extends StatefulWidget {
  const WaxSeal({super.key, this.stampIn = false, this.size = 50});

  final bool stampIn;
  final double size;

  @override
  State<WaxSeal> createState() => _WaxSealState();
}

class _WaxSealState extends State<WaxSeal> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void initState() {
    super.initState();
    if (widget.stampIn) {
      _a.forward();
    } else {
      _a.value = 1;
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, child) {
        final t = Curves.easeIn.transform(_a.value);
        // 크게 떠 있다가 내려앉으며 쿵 (마지막에 살짝 눌림)
        final scale = _a.value < 0.85
            ? 1.9 - 0.95 * (t / Curves.easeIn.transform(0.85))
            : 0.95 + (_a.value - 0.85) / 0.15 * 0.05;
        return Opacity(
          opacity: (_a.value * 2.5).clamp(0.0, 1.0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: SizedBox(
        key: const Key('waxSeal'),
        width: s,
        height: s,
        child: Image.asset(boardArt('board_seal'),
            errorBuilder: (_, __, ___) =>
                const CustomPaint(painter: _SealPainter())),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  const _SealPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.86;
    // 울퉁불퉁한 밀랍 가장자리
    final blob = Path();
    for (var i = 0; i <= 48; i++) {
      final a = i / 48 * 2 * math.pi;
      final rr = r * (1 + 0.06 * math.sin(a * 7) + 0.03 * math.cos(a * 11));
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? blob.moveTo(p.dx, p.dy) : blob.lineTo(p.dx, p.dy);
    }
    blob.close();
    canvas.drawShadow(blob, const Color(0xAA000000), 3, false);
    canvas.drawPath(
        blob,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.35),
            colors: [Color(0xFFD0483C), _sealRed, Color(0xFF6E130E)],
            stops: [0, 0.6, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r)));
    // 안쪽 고리
    canvas.drawCircle(
        c,
        r * 0.62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0x88FFD2C4));
    // 가운데 별 무늬
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r * 0.42 : r * 0.18;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xAAFFD9CB));
  }

  @override
  bool shouldRepaint(_SealPainter old) => false;
}

/// 「완료」 인장 (비스듬히, 글자는 코드로)
class DoneStamp extends StatelessWidget {
  const DoneStamp({super.key, this.small = false});

  final bool small;

  @override
  Widget build(BuildContext context) {
    // 인장 그림(512×256) 비율에 맞춰
    final w = small ? 72.0 : 96.0;
    final h = small ? 30.0 : 40.0;
    return Transform.rotate(
      angle: -0.24,
      child: SizedBox(
        key: const Key('doneStamp'),
        width: w,
        height: h,
        child: Stack(alignment: Alignment.center, children: [
          Positioned.fill(
            child: Image.asset(boardArt('board_done'),
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: _stampRed.withValues(alpha: 0.85),
                            width: 2.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: _stampRed.withValues(alpha: 0.7),
                              width: 1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
          ),
          Text('완료',
              style: AppText.title(small ? 14 : 19,
                      color: _stampRed.withValues(alpha: 0.9))
                  .copyWith(letterSpacing: small ? 3 : 5)),
        ]),
      ),
    );
  }
}
