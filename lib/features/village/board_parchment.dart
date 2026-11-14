import 'dart:math' as math;

import 'package:flutter/material.dart';

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

/// 나무 게시판: 판자 + 테두리 나무틀. 안쪽에 쪽지들을 놓는다
class WoodBoard extends StatelessWidget {
  const WoodBoard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('woodBoard'),
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
            Positioned.fill(
              child: Image.asset(boardArt('board_bg'),
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  repeat: ImageRepeat.repeatY,
                  errorBuilder: (_, __, ___) => const SizedBox()),
            ),
            // 나무틀 안쪽 그림자
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: const Color(0x55000000), width: 2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
              child: child,
            ),
          ]),
        ),
      );
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
  });

  final Widget child;

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

  /// 이 쪽지의 기울기 (도)
  static double tiltOf(int seed) => ((seed * 37 + 11) % 9 - 4) * 0.45;

  @override
  Widget build(BuildContext context) {
    final tilt = tiltOf(seed) * math.pi / 180;
    final paper = Container(
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
      child: Stack(children: [
        Positioned.fill(
          child: Image.asset(boardArt('board_note'),
              centerSlice: const Rect.fromLTRB(90, 90, 710, 310),
              fit: BoxFit.fill,
              errorBuilder: (_, __, ___) => const SizedBox()),
        ),
        if (ribbon)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 7,
              decoration: const BoxDecoration(gradient: kGoldGradient),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(14, ribbon ? 18 : 14, 14, 10),
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
        child: Stack(clipBehavior: Clip.none, children: [
          paper,
          // 핀
          const Positioned(
            top: -9,
            left: 0,
            right: 0,
            child: Center(child: BoardPin()),
          ),
        ]),
      ),
    );
  }
}

/// 쪽지를 꽂은 핀
class BoardPin extends StatelessWidget {
  const BoardPin({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        height: 24,
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
    final w = small ? 64.0 : 84.0;
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
