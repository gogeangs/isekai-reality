part of '../harvest_games.dart';

class _ResultFx extends StatelessWidget {
  const _ResultFx({required this.grade, required this.mats, required this.onTap});

  final HarvestGrade grade;
  final Map<MaterialId, int>? mats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fail = grade == HarvestGrade.fail;
    final perfect = grade == HarvestGrade.perfect;
    final glow = perfect
        ? const Color(0xFFFFD36A)
        : fail
            ? const Color(0xFF9A8466)
            : const Color(0xFFDDE4F5);
    return GestureDetector(
      key: const Key('harvestFx'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: HarvestRules.resultFx,
        builder: (context, k, _) {
          final burst = Curves.easeOut.transform(math.min(1, k * 1.8));
          return LayoutBuilder(builder: (context, box) {
            final c = Offset(box.maxWidth / 2, box.maxHeight * 0.42);
            // 가방 쪽(오른쪽 위)으로 날아감
            final fly = Curves.easeInCubic.transform(((k - 0.45) / 0.55).clamp(0.0, 1.0));
            final target = Offset(box.maxWidth - 40, 40);
            final list = (mats ?? const {}).entries.toList();
            return Stack(children: [
              Positioned.fill(
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.6 * burst)),
              ),
              // 금빛·은빛 터짐 (실패는 부드럽게 흩어짐)
              Positioned.fill(
                child: CustomPaint(
                  painter: _FxPainter(
                      k: k, center: c, color: glow, fail: fail, burst: burst),
                ),
              ),
              // 가운데: 결과 + 받은 재료 줄
              Positioned(
                left: 20,
                right: 20,
                top: c.dy - 80,
                child: Opacity(
                  opacity: burst,
                  child: Transform.scale(
                    scale: 0.85 + 0.15 * burst,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(gradeLabel(grade),
                          key: const Key('harvestFxLabel'),
                          textAlign: TextAlign.center,
                          style: AppText.title(34,
                                  color: fail ? const Color(0xFFD8CBB4) : glow)
                              .copyWith(shadows: [
                            const Shadow(color: Colors.black, blurRadius: 6),
                            Shadow(color: glow.withValues(alpha: 0.9), blurRadius: 18),
                          ])),
                      if (list.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          key: const Key('harvestFxMats'),
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xDD0B0D26),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: glow.withValues(alpha: 0.8)),
                          ),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              for (final e in list)
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  MaterialIcon(e.key, size: 30),
                                  const SizedBox(width: 4),
                                  Text('${Materials.info(e.key).name} +${e.value}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800)),
                                ]),
                            ],
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
              // 받은 재료 아이콘이 튀어나와 가방 쪽(오른쪽 위)으로 날아감
              if (!fail || list.isNotEmpty)
                for (final (i, e) in list.indexed)
                  if (fly > 0)
                    Positioned(
                      left: Offset.lerp(
                                  c + Offset((i - (list.length - 1) / 2) * 56, 40),
                                  target,
                                  fly)!
                              .dx -
                          22,
                      top: Offset.lerp(
                                  c + Offset((i - (list.length - 1) / 2) * 56, 40),
                                  target,
                                  fly)!
                              .dy -
                          22,
                      child: Opacity(
                        opacity: (1 - fly * 0.4).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: 1 - fly * 0.4,
                          child: MaterialIcon(e.key, size: 44),
                        ),
                      ),
                    ),
            ]);
          });
        },
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter(
      {required this.k,
      required this.center,
      required this.color,
      required this.fail,
      required this.burst});

  final double k, burst;
  final Offset center;
  final Color color;
  final bool fail;

  @override
  void paint(Canvas canvas, Size size) {
    final fade = (1 - k).clamp(0.0, 1.0);
    if (!fail) {
      canvas.drawCircle(
          center,
          size.width * 0.45 * burst,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withValues(alpha: 0.75 * fade),
              color.withValues(alpha: 0),
            ]).createShader(Rect.fromCircle(center: center, radius: size.width * 0.45 * burst + 1)));
    }
    final rng = math.Random(5);
    for (var i = 0; i < (fail ? 14 : 22); i++) {
      final a = rng.nextDouble() * math.pi * 2;
      if (fail) {
        // 잎·돌가루가 흩어지며 천천히 떨어짐
        final pos = center +
            Offset(math.cos(a) * size.width * 0.25 * burst,
                -20 + k * size.height * 0.18 + rng.nextDouble() * 40 * k);
        canvas.drawCircle(
            pos,
            2.5 + rng.nextDouble() * 2.5,
            Paint()
              ..color = (i.isEven ? const Color(0xFF8FA36A) : const Color(0xFFA08C70))
                  .withValues(alpha: 0.8 * fade));
      } else {
        final d = size.width * (0.15 + rng.nextDouble() * 0.35) * burst;
        final pos = center + Offset(math.cos(a), math.sin(a)) * d;
        canvas.drawCircle(pos, 2 + rng.nextDouble() * 3,
            Paint()..color = color.withValues(alpha: fade));
      }
    }
  }

  @override
  bool shouldRepaint(_FxPainter o) => o.k != k;
}

/// 묶음 48: 유물 구덩이 모양 (조금 울퉁불퉁한 둥근 구덩이)
class _PitClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final c = size.center(Offset.zero);
    final rx = size.width * 0.45, ry = size.height * 0.45;
    final path = Path();
    const n = 48;
    for (var i = 0; i <= n; i++) {
      final t = i / n * math.pi * 2;
      // 가장자리를 살짝 들쭉날쭉하게 (늘 같은 모양)
      final k = 1 + 0.035 * math.sin(t * 5) + 0.02 * math.sin(t * 11 + 1);
      final p = Offset(c.dx + math.cos(t) * rx * k, c.dy + math.sin(t) * ry * k);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
