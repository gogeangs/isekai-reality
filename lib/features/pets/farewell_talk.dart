import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../core/rules/rules.dart';
import '../../data/sound/sfx.dart';
import '../../data/storage/record_store.dart';
import '../../theme/ornaments.dart';
import '../battle/element_view.dart';
import '../bulssi/spirit_art.dart';

/// 묶음 69 #284: 정령 이별 장면에서 「정령이 말하는」 대사창
/// - 왼쪽에 정령 얼굴(줄마다 표정) · 테두리 · 이름표를 정령 색으로 · 이름 옆 속성 아이콘
/// - 꼬리는 그림 속 정령을 가리킴(장면마다 자리), 정령이 안 보이면 얼굴 쪽
/// - 한 글자씩(빠르게, 누르면 바로 다) · 정령마다 글자 소리 · 글자가 나오는 동안 얼굴이 살짝 위아래
/// - 「내 빛을 조금 남겨 둘게」: 정령 자리에 빛이 2~3번 맥박 · 빛 알갱이가 손 쪽으로 · 진동 한 번
class FarewellTalkScene extends StatefulWidget {
  const FarewellTalkScene({
    super.key,
    required this.image,
    required this.name,
    required this.kind,
    required this.line,
    required this.index,
    required this.onNext,
    this.sound = true,
    this.vibrate = true,
  });

  final String image;
  final String name;
  final SpiritKind kind;
  final String line;

  /// 이별 장면의 몇 번째 줄 (표정 · 빛 효과)
  final int index;
  final VoidCallback onNext;
  final bool sound, vibrate;

  /// 장면마다 그림 속 정령 자리 (그림 비율). 없으면 정령이 안 보이는 장면
  static const Map<String, Offset> spiritAt = {
    'farewell_02_lookup': Offset(0.36, 0.60),
    'farewell_03_smile': Offset(0.53, 0.50),
    'farewell_04_light': Offset(0.44, 0.48),
  };

  /// 「내 빛을 조금 남겨 둘게」 장면의 손 자리 (빛 알갱이가 흘러가는 곳)
  static const Offset handAt = Offset(0.72, 0.80);

  /// 줄마다 표정: 0 기본 · 1 걱정 · 3 웃음 · 4 눈물 맺힌 미소(없으면 웃음)
  static SpiritMood moodOf(int index) => switch (index) {
        1 => SpiritMood.worried,
        3 || 4 => SpiritMood.cheer,
        _ => SpiritMood.normal,
      };

  /// 정령 색 (풀 연두 · 불 금빛 · 물 하늘빛)
  static Color colorOf(SpiritKind k) => spiritColor(k);

  static Element elementOf(SpiritKind k) => switch (k) {
        SpiritKind.fire => Element.fire,
        SpiritKind.water => Element.water,
        SpiritKind.plant => Element.earth,
      };

  static SfxKind soundOf(SpiritKind k) => switch (k) {
        SpiritKind.fire => SfxKind.talkFire,
        SpiritKind.water => SfxKind.talkWater,
        SpiritKind.plant => SfxKind.talkLeaf,
      };

  @override
  State<FarewellTalkScene> createState() => _FarewellTalkSceneState();
}

class _FarewellTalkSceneState extends State<FarewellTalkScene> with TickerProviderStateMixin {
  late final int _len = widget.line.characters.length;
  late final AnimationController _type =
      AnimationController(vsync: this, duration: Duration(milliseconds: 26 * _len))..forward();
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  int _shown = 0;

  bool get _light => widget.index == 4;

  @override
  void initState() {
    super.initState();
    _type.addListener(_onType);
    if (_light) {
      _glow.forward();
      if (widget.vibrate) HapticFeedback.mediumImpact();
    }
  }

  void _onType() {
    final n = (_type.value * _len).floor();
    if (n == _shown) return;
    // 글자 소리: 두 글자에 한 번, 짧고 작게 (빈칸은 건너뜀)
    if (widget.sound && n.isOdd && n < _len && widget.line.characters.elementAt(n).trim().isNotEmpty) {
      Sfx.play(FarewellTalkScene.soundOf(widget.kind), volume: 0.35);
    }
    setState(() => _shown = n);
  }

  @override
  void dispose() {
    _type.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _tap() {
    if (_type.isAnimating) {
      _type.value = 1; // 누르면 바로 다 보임
      return;
    }
    widget.onNext();
  }

  String get _key {
    final f = widget.image.split('/').last.replaceAll('.webp', '');
    for (final k in FarewellTalkScene.spiritAt.keys) {
      if (f.startsWith(k)) return k;
    }
    return f;
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final at = FarewellTalkScene.spiritAt[_key];
    final tint = FarewellTalkScene.colorOf(widget.kind);
    return GestureDetector(
      key: const Key('farewellTalk'),
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: Stack(fit: StackFit.expand, children: [
        ClipRect(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(widget.image),
            tween: Tween(begin: 1.0, end: 1.06),
            duration: const Duration(seconds: 8),
            curve: Curves.easeOut,
            builder: (context, s, child) => Transform.scale(scale: s, child: child),
            child: Image.asset(widget.image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1B1840))),
          ),
        ),
        // 「내 빛을 조금 남겨 둘게」: 빛 맥박 + 손 쪽으로 흘러내리는 빛 알갱이
        if (_light && at != null)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _glow,
                builder: (context, _) => CustomPaint(
                  key: const Key('farewellGlow'),
                  painter: _LightPainter(
                      t: _glow.value,
                      from: Offset(at.dx * size.width, at.dy * size.height),
                      to: Offset(FarewellTalkScene.handAt.dx * size.width, FarewellTalkScene.handAt.dy * size.height),
                      color: tint),
                ),
              ),
            ),
          ),
        Positioned(
          left: 14,
          right: 14,
          bottom: pad.bottom + 18,
          child: LayoutBuilder(builder: (context, box) {
            const face = 72.0, gap = 8.0;
            final bubbleLeft = 14 + face + gap;
            final bubbleW = box.maxWidth - face - gap;
            // 꼬리: 그림 속 정령을 향해 위로 (안 보이면 얼굴 쪽)
            final side = at == null ? BubbleSide.left : BubbleSide.up;
            final tailAt = at == null ? 30.0 : (at.dx * size.width - bubbleLeft).clamp(30.0, bubbleW - 30);
            final shown = widget.line.characters.take(_shown).toString();
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: EdgeInsets.only(top: at == null ? 0 : CodeBubble.tail),
                child: AnimatedBuilder(
                  animation: _type,
                  builder: (context, child) => Transform.translate(
                    // 글자가 나오는 동안 얼굴이 살짝 위아래
                    offset: Offset(0, _type.isAnimating ? math.sin(_type.value * _len * 0.9) * 2.5 : 0),
                    child: child,
                  ),
                  child: _Face(kind: widget.kind, index: widget.index, tint: tint, size: face),
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: CodeBubble(
                  key: Key('farewellBubble_${widget.index}'),
                  side: side,
                  at: tailAt,
                  border: Color.lerp(CodeBubble.edge, tint, 0.45),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        key: const Key('farewellName'),
                        padding: const EdgeInsets.fromLTRB(8, 1, 8, 2),
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.28),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color.lerp(CodeBubble.edge, tint, 0.45)!.withValues(alpha: 0.8)),
                        ),
                        child: Text(widget.name,
                            style: const TextStyle(color: kBubbleName, fontSize: 13, fontWeight: FontWeight.w900)),
                      ),
                      const SizedBox(width: 5),
                      ElementIcon(FarewellTalkScene.elementOf(widget.kind), size: 16),
                    ]),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: double.infinity,
                      child: Text(shown,
                          key: Key('farewellLine_${widget.index}'),
                          style: const TextStyle(
                              color: Color(0xFF2E2010), fontSize: 16.5, height: 1.45, fontWeight: FontWeight.w600)),
                    ),
                    if (!_type.isAnimating)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.arrow_drop_down_rounded, color: kBubbleName, size: 22),
                      ),
                  ]),
                ),
              ),
            ]);
          }),
        ),
      ]),
    );
  }
}

/// 정령 얼굴 (줄마다 표정, 둘레에 정령 색 빛)
class _Face extends StatelessWidget {
  const _Face({required this.kind, required this.index, required this.tint, required this.size});
  final SpiritKind kind;
  final int index;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mood = FarewellTalkScene.moodOf(index);
    final fallback = SpiritArt(kind: kind, size: size * 0.86, mood: mood);
    // 마지막 인사는 눈물 맺힌 미소 (그림이 없으면 웃음)
    final art = index == 4
        ? Image.asset('assets/images/spirit_${kind.name}_${'farewell'}.webp',
            width: size * 0.86, height: size * 0.95, fit: BoxFit.contain, errorBuilder: (_, __, ___) => fallback)
        : fallback;
    return Container(
      key: Key('farewellFace_${mood.name}'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xEE141638),
        border: Border.all(color: tint, width: 2.5),
        boxShadow: [BoxShadow(color: tint.withValues(alpha: 0.55), blurRadius: 14)],
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: art,
    );
  }
}

/// 빛 맥박(2~3번) + 손 쪽으로 흘러내리는 빛 알갱이
class _LightPainter extends CustomPainter {
  _LightPainter({required this.t, required this.from, required this.to, required this.color});
  final double t;
  final Offset from, to;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 맥박: 세 번 밝아졌다 잦아듦
    final pulse = math.pow(math.sin(t * math.pi * 3).abs(), 1.4).toDouble() * (1 - t * 0.4);
    final r = 46 + 26 * pulse;
    canvas.drawCircle(
        from,
        r * 1.8,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: 0.55 * pulse),
            color.withValues(alpha: 0.45 * pulse),
            color.withValues(alpha: 0),
          ], stops: const [0, 0.35, 1])
              .createShader(Rect.fromCircle(center: from, radius: r * 1.8)));
    // 빛 알갱이: 정령 자리에서 손 쪽으로 (조금씩 흩어지며)
    final rng = math.Random(7);
    for (var i = 0; i < 26; i++) {
      final delay = rng.nextDouble() * 0.5;
      final p = ((t - delay) / 0.55).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final wob = math.sin((p * 3 + i) * math.pi) * 18 * (1 - p);
      final pos = Offset.lerp(from, to, Curves.easeIn.transform(p))! + Offset(wob, rng.nextDouble() * 10 - 5);
      final a = (1 - p) * 0.9;
      canvas.drawCircle(pos, 2 + rng.nextDouble() * 2.5, Paint()..color = Colors.white.withValues(alpha: a));
      canvas.drawCircle(pos, 5 + rng.nextDouble() * 3, Paint()..color = color.withValues(alpha: a * 0.35));
    }
  }

  @override
  bool shouldRepaint(_LightPainter old) => old.t != t;
}
