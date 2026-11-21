part of '../battle_view.dart';

/// 발밑 타원 그림자
class _Shadow extends StatelessWidget {
  const _Shadow({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 0.16,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(
            Radius.elliptical(width / 2, width * 0.08)),
        color: const Color(0x66000000),
      ),
    );
  }
}

/// 테두리가 있는 큰 숫자 (어느 배경에서도 읽히게)
class _Outlined extends StatelessWidget {
  const _Outlined(this.text, {required this.size, required this.color});

  final String text;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final base = AppText.title(size, color: color);
    return Stack(children: [
      Text(text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = const Color(0xFF1B1030),
          )),
      Text(text, style: base),
    ]);
  }
}

/// 타격 지점에서 사방으로 튀는 금빛 불꽃 조각
class _SparkPainter extends CustomPainter {
  _SparkPainter({
    required this.origin,
    required this.progress,
    required this.seed,
    required this.count,
    required this.reach,
  });

  final Offset origin;
  final double progress;
  final int seed;
  final int count;
  final double reach;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final rng = math.Random(seed);
    final ease = Curves.easeOut.transform(progress);
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final dist = reach * (0.4 + rng.nextDouble() * 0.6) * ease;
      final fall = 30 * progress * progress; // 살짝 떨어진다
      final p = origin +
          Offset(math.cos(angle) * dist, math.sin(angle) * dist + fall);
      final r = (2 + rng.nextDouble() * 3) * (1 - progress);
      final paint = Paint()
        ..color = Color.lerp(const Color(0xFFFFF3C8), const Color(0xFFF0A93B),
                rng.nextDouble())!
            .withValues(alpha: 1 - progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawCircle(p, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.progress != progress || old.seed != seed;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.look});

  final HeroLook look;
  double get size => 46;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2B2F6B),
        border: Border.all(color: AppColors.goldBright, width: 1.6),
      ),
      child: ClipOval(
        child: PortraitFace(
            look: look,
            fallback: const Icon(Icons.person_rounded, color: AppColors.textMuted)),
      ),
    );
  }
}

/// 묶음 75 #324: 연습 허수아비 — 가득 찬 금빛 줄 「끝없는 허수아비 ∞」 (맞을 때 살짝 번쩍)
class _EndlessDummy extends StatelessWidget {
  const _EndlessDummy({required this.beat, this.element});

  final int beat;
  final Element? element;

  @override
  Widget build(BuildContext context) => Column(
        key: const Key('endlessDummy'),
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (element != null) ...[
              ElementIcon(element, size: 16),
              const SizedBox(width: 4),
            ],
            const Flexible(
              child: Text('끝없는 허수아비 ∞',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.goldBright, fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            key: ValueKey(beat),
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 380),
            builder: (context, v, _) => ColorFiltered(
              colorFilter: ColorFilter.mode(Colors.white.withValues(alpha: v * 0.55), BlendMode.srcATop),
              child: const GlowBar(ratio: 1, colors: BarColors.exp, height: 11),
            ),
          ),
        ],
      );
}

class _HpColumn extends StatelessWidget {
  const _HpColumn({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.colors,
    this.note,
    this.alignEnd = false,
    this.nameColor = AppColors.text,
    this.element,
    this.showElement = false,
    this.hideNumbers = false,
  });

  final bool hideNumbers;

  /// 몬스터 속성 아이콘 (11-11 #63)
  final Element? element;
  final bool showElement;

  final String name;
  final Color nameColor;
  final int hp;
  final int maxHp;
  final List<Color> colors;
  final String? note;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (showElement) ...[
              ElementIcon(element, size: 16),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: nameColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            if (note != null) ...[
              const SizedBox(width: 6),
              Text(note!,
                  style:
                      const TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        GlowBar(
            ratio: maxHp == 0 ? 0 : hp / maxHp, colors: colors, height: 11),
        if (!hideNumbers) ...[
          const SizedBox(height: 3),
          // 묶음 76 #338: 큰 숫자도 한 줄에 (넘치면 글자를 줄임)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('HP ${comma(hp)} / ${comma(maxHp)}',
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        ],
      ],
    );
  }
}

SpiritKind _kind(BuildContext context) =>
    BulssiScope.maybeOf(context)?.kind ?? SpiritKind.fire;

/// 색을 살짝 입힌다 (상태 이상·속성 타격 색)
Widget _tinted(Color? c, Widget child, {double alpha = 0.32}) => c == null
    ? child
    : ColorFiltered(
        colorFilter: ColorFilter.mode(c.withValues(alpha: alpha), BlendMode.srcATop),
        child: child);

/// 상태 이상 (11-11 #81). 그림이 오기 전에는 아이콘.
enum _Status { poison, burn, frozen, dazzle, bound, stance }

extension on _Status {
  String get label => switch (this) {
        _Status.poison => '중독',
        _Status.burn => '화상',
        _Status.frozen => '빙결',
        _Status.dazzle => '눈부심',
        _Status.bound => '묶임',
        _Status.stance => '방어 태세',
      };

  IconData get icon => switch (this) {
        _Status.poison => Icons.bubble_chart_rounded,
        _Status.burn => Icons.local_fire_department_rounded,
        _Status.frozen => Icons.ac_unit_rounded,
        _Status.dazzle => Icons.flare_rounded,
        _Status.bound => Icons.link_rounded,
        _Status.stance => Icons.shield_rounded,
      };

  Color get color => switch (this) {
        _Status.poison => const Color(0xFF7BD86A),
        _Status.burn => const Color(0xFFFF8A4C),
        _Status.frozen => const Color(0xFF8FD3FF),
        _Status.dazzle => const Color(0xFFFFF1A0),
        _Status.bound => const Color(0xFFE0B3FF),
        _Status.stance => const Color(0xFF6FB8FF),
      };

  String get asset => 'assets/images/status_$name.webp';
}

class _StatusIcons extends StatelessWidget {
  const _StatusIcons(this.list);

  final List<_Status> list;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 4, children: [
        for (final s in list)
          Tooltip(
            message: s.label,
            child: Container(
              key: Key('status_${s.name}'),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF14173E),
                shape: BoxShape.circle,
                border: Border.all(color: s.color, width: 1.4),
              ),
              child: Image.asset(s.asset,
                  errorBuilder: (_, __, ___) =>
                      Icon(s.icon, size: 14, color: s.color)),
            ),
          ),
      ]);
}

/// 배경 위 시간 색감·속성 입자·밤 반딧불 (11-11 #81, 그림 없이 코드로)
class _AmbientPainter extends CustomPainter {
  _AmbientPainter({required this.t, this.element, this.hour});

  final double t;
  final Element? element;
  final int? hour;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // 시간 색감: 낮은 그대로, 노을(16~19시)은 주황, 밤(19~6시)은 남색
    final hr = hour;
    if (hr != null) {
      Color? tint;
      if (hr >= 16 && hr < 19) tint = const Color(0x38FF8A3D);
      if (hr >= 19 || hr < 6) tint = const Color(0x5A0B1240);
      if (tint != null) canvas.drawRect(Offset.zero & size, Paint()..color = tint);
    }
    final rng = math.Random(11);
    final p = Paint();
    // 몬스터 속성 입자
    final e = element;
    if (e != null) {
      final c = elementColor(e);
      for (var i = 0; i < 22; i++) {
        final x0 = rng.nextDouble() * w;
        final ph = rng.nextDouble();
        final sp = 0.5 + rng.nextDouble();
        final v = (t * sp + ph) % 1.0;
        final a = math.sin(v * math.pi) * 0.75;
        p.color = c.withValues(alpha: a);
        switch (e) {
          case Element.fire:
            // 불똥이 위로
            canvas.drawCircle(
                Offset(x0 + math.sin(v * 6 + i) * 8, h * (1 - v)), 2.2, p);
          case Element.ice:
            // 눈송이가 아래로
            _flake(canvas, Offset(x0 + math.sin(v * 4 + i) * 10, h * v), 4, p);
          case Element.water || Element.poison:
            // 물방울·기포가 위로
            p
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4;
            canvas.drawCircle(Offset(x0, h * (1 - v)), 3 + (i % 3).toDouble(), p);
            p.style = PaintingStyle.fill;
          case Element.thunder:
            // 번쩍이는 작은 번개
            if (a > 0.55) {
              p.strokeWidth = 2;
              final o = Offset(x0, h * ((ph + i * 0.13) % 1.0));
              canvas.drawLine(o, o + const Offset(5, 8), p);
              canvas.drawLine(o + const Offset(5, 8), o + const Offset(1, 12), p);
            }
          case Element.wind:
            // 옆으로 흐르는 바람 줄
            p.strokeWidth = 1.6;
            final y = h * ((ph + i * 0.07) % 1.0);
            final x = w * v * 1.2 - 40;
            canvas.drawLine(Offset(x, y), Offset(x + 30, y - 2), p);
          case Element.earth || Element.metal:
            // 흙먼지·금속 반짝임이 천천히
            canvas.drawCircle(Offset(x0, h * (0.6 + 0.4 * ((ph + v * 0.2) % 1.0))),
                e == Element.metal ? 1.6 : 2.4, p);
          case Element.light || Element.dark:
            // 빛 알갱이·어둠 안개
            canvas.drawCircle(Offset(x0, h * ((ph - v * 0.3) % 1.0)),
                e == Element.light ? 2.0 : 6.0,
                p..color = c.withValues(alpha: e == Element.dark ? a * 0.35 : a));
        }
      }
    }
    // 밤에는 반딧불 (기기 시간, 날씨는 쓰지 않는다)
    if (hr != null && (hr >= 19 || hr < 6)) {
      for (var i = 0; i < 14; i++) {
        final x0 = rng.nextDouble() * w;
        final y0 = h * (0.25 + rng.nextDouble() * 0.6);
        final ph = rng.nextDouble();
        final v = (t * (0.4 + rng.nextDouble() * 0.4) + ph) % 1.0;
        final a = (math.sin(v * math.pi * 2) * 0.5 + 0.5) * 0.85;
        final o = Offset(x0 + math.sin(v * 6.28 + i) * 10,
            y0 + math.cos(v * 6.28 + i * 0.7) * 8);
        canvas.drawCircle(
            o, 5, p..color = Color.fromRGBO(220, 255, 140, a * 0.25));
        canvas.drawCircle(
            o, 1.8, p..color = Color.fromRGBO(240, 255, 170, a));
      }
    }
  }

  void _flake(Canvas c, Offset o, double r, Paint p) {
    p.strokeWidth = 1.2;
    for (var k = 0; k < 3; k++) {
      final a = k * math.pi / 3;
      final d = Offset(math.cos(a) * r, math.sin(a) * r);
      c.drawLine(o - d, o + d, p);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.t != t ||
      old.element != element ||
      old.hour != hour;
}

/// 충전 중·잠긴 버튼 그림은 어둡게 (묶음 35)
Widget _dimmed(bool dim, Widget child) => dim
    ? ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.25, 0.25, 0.25, 0, 0, //
          0.25, 0.25, 0.25, 0, 0, //
          0.30, 0.30, 0.30, 0, 0, //
          0, 0, 0, 0.85, 0,
        ]),
        child: child)
    : child;

/// 묶음 52 #243: 전투 화면 동료 칸 — 얼굴 · 이름 · HP 막대 · 끼운 스킬 버튼(게이지가 차면 누름)
class _AllyCard extends StatelessWidget {
  const _AllyCard({super.key, required this.ally, this.look, this.onSkill});

  final BattleAlly ally;
  final ({String? art, String? face, int color})? look;
  final VoidCallback? onSkill;

  @override
  Widget build(BuildContext context) {
    final a = ally;
    final color = Color(look?.color ?? 0xFF9AA6D8);
    final face = look?.face;
    return Opacity(
      opacity: a.down ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
        decoration: BoxDecoration(
          color: const Color(0xCC14163A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          ClipOval(
            child: Container(
              width: 30,
              height: 30,
              color: color.withValues(alpha: 0.35),
              child: face == null
                  ? Icon(Icons.person_rounded, size: 22, color: color)
                  : Image.asset(face,
                      fit: BoxFit.cover,
                      alignment: face.contains('ally_job_')
                          ? const Alignment(0, -0.8)
                          : Alignment.center,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.person_rounded, size: 22, color: color)),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 11.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                GlowBar(
                    key: Key('allyHp_${a.id}'),
                    ratio: a.maxHp == 0 ? 0 : a.hp / a.maxHp,
                    colors: BarColors.hp,
                    height: 7),
              ],
            ),
          ),
          if (a.skill case final s?) ...[
            const SizedBox(width: 5),
            GestureDetector(
              key: Key('allySkill_${a.id}'),
              onTap: a.ready ? onSkill : null,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                    value: a.ratio,
                    strokeWidth: 3,
                    color: a.ready ? AppColors.goldBright : color,
                    backgroundColor: const Color(0x33FFFFFF),
                  ),
                  Icon(Icons.auto_awesome_rounded,
                      size: 18,
                      color: a.ready ? AppColors.goldBright : AppColors.textMuted),
                ]),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(s.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: a.ready ? AppColors.goldBright : AppColors.textMuted,
                      fontSize: 9.5,
                      height: 1.1,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ]),
      ),
    );
  }
}
