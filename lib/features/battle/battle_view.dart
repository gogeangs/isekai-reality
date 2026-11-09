import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_mood.dart';
import '../bulssi/spirit_art.dart';

/// 자동 전투 화면 (목업 구도): 동굴 배경 위 각성자 vs 몬스터,
/// 아래에 체력 막대, 정화 수, 둥근 스킬 버튼 '정령의 일격'.
///
/// [tickInterval] 마다 [Battle.tick] 을 부르고, 끝나면 [onFinished] 를 한 번 부른다.
class BattleView extends StatefulWidget {
  const BattleView({
    super.key,
    required this.battle,
    required this.onFinished,
    this.tickInterval = const Duration(milliseconds: 900),
    this.playerName = '각성자',
    this.look = HeroLook.male,
  });

  final Battle battle;
  final VoidCallback onFinished;
  final Duration tickInterval;
  final String playerName;
  final HeroLook look;

  @override
  State<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<BattleView> {
  Timer? _timer;
  bool _reported = false;

  /// 공격이 한 번 오갈 때마다 1씩 늘어난다 (전투 장면 연출의 신호)
  int _beat = 0;

  Battle get _b => widget.battle;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tickInterval, (_) => _step());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _step() {
    if (!mounted) return;
    setState(() {
      final before = _b.ticks;
      _b.tick();
      if (_b.ticks != before) _beat++; // 층이 바뀌는 틱은 연출하지 않는다
    });
    _checkEnd();
  }

  void _skill() {
    setState(() {
      if (_b.useSkill()) _beat++;
    });
    _checkEnd();
  }

  void _checkEnd() {
    if (!_b.isOver || _reported) return;
    _reported = true;
    _timer?.cancel();
    // 마지막 타격을 잠깐 보여 주고 결과로 넘어간다
    Timer(widget.tickInterval, () {
      if (mounted) widget.onFinished();
    });
  }

  String get _floorLabel {
    if (_b.floors.length == 1) return '필드 전투';
    return _b.foe.isBoss
        ? 'BOSS'
        : '${_b.floor + 1}층 / ${_b.floors.length - 1}층';
  }

  @override
  Widget build(BuildContext context) {
    final foe = _b.foe;
    final cleared = _b.phase == BattlePhase.floorCleared ||
        _b.phase == BattlePhase.cleared;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Scene(
          foe: foe,
          cleared: cleared,
          floorLabel: _floorLabel,
          dealt: _b.lastDealt,
          taken: _b.lastTaken,
          skill: _b.lastWasSkill,
          look: widget.look,
          beat: _beat,
          beatDuration: widget.tickInterval * 0.85,
        ),
        const SizedBox(height: 10),
        OrnatePanel(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          child: Row(children: [
            _Avatar(look: widget.look),
            const SizedBox(width: 8),
            Expanded(
              child: _HpColumn(
                name: widget.playerName,
                hp: _b.playerHp,
                maxHp: _b.playerMaxHp,
                colors: BarColors.hp,
                note: _b.lastTaken > 0 ? '-${comma(_b.lastTaken)}' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HpColumn(
                name: cleared ? foe.info.purifiedName : foe.info.name,
                hp: _b.foeHp,
                maxHp: foe.maxHp,
                colors: BarColors.foe,
                alignEnd: true,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: OrnatePanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(children: [
                  const GameIcon('crystal', size: 40),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('정화',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      Text('${_b.purified.length} / ${_b.floors.length}',
                          style: AppText.title(26, color: AppColors.text)),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            _SkillOrb(
              ratio: _b.skillRatio,
              ready: _b.skillReady,
              away: _b.skillDisabled,
              onPressed: _skill,
            ),
            const SizedBox(width: 6),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────── 전투 장면

class _Scene extends StatefulWidget {
  const _Scene({
    required this.foe,
    required this.cleared,
    required this.floorLabel,
    required this.dealt,
    required this.taken,
    required this.skill,
    required this.look,
    required this.beat,
    required this.beatDuration,
  });

  final Foe foe;
  final bool cleared;
  final String floorLabel;
  final int dealt;
  final int taken;
  final bool skill;
  final HeroLook look;

  /// 바뀔 때마다 한 번의 공격 연출을 처음부터 재생한다
  final int beat;
  final Duration beatDuration;

  @override
  State<_Scene> createState() => _SceneState();
}

/// 한 번의 공격 연출 (0 → 1):
/// 0.00~0.22 각성자가 달려든다 → 0.22 타격 (몬스터 흔들림·번쩍임, 불꽃, 피해 숫자)
/// → 0.22~0.50 제자리로 → 0.50~0.70 몬스터 반격 (각성자 붉게 번쩍, 받은 피해 숫자)
/// 일격은 화면이 흔들리고 금빛 베기가 가로지른다.
class _SceneState extends State<_Scene> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.beatDuration);

  @override
  void didUpdateWidget(covariant _Scene old) {
    super.didUpdateWidget(old);
    if (widget.beat != old.beat) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // t 구간 [a, b] 안에서 0 → 1
  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final foe = widget.foe;
    final cleared = widget.cleared;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              final idle = !_c.isAnimating;
              // 각성자 달려들기: 0→0.22 앞으로, 0.22→0.5 돌아오기
              final lunge = t < 0.22
                  ? Curves.easeIn.transform(_seg(t, 0, 0.22))
                  : 1 - Curves.easeOut.transform(_seg(t, 0.22, 0.5));
              // 달려들어 휘두르는 동안만 공격 자세, 나머지는 대기 자세
              final swinging = !idle && widget.dealt > 0 && t < 0.5;
              // 타격 순간부터
              final hit = _seg(t, 0.22, 0.6);
              final hitting = !idle && t >= 0.22 && widget.dealt > 0;
              // 몬스터 흔들림 (줄어드는 진동)
              final shake = hitting
                  ? math.sin(hit * math.pi * 6) * (1 - hit) * (widget.skill ? 14 : 8)
                  : 0.0;
              final flash = hitting ? (1 - _seg(t, 0.22, 0.42)) : 0.0;
              // 몬스터 반격 (0.5~0.7)
              final counter = widget.taken > 0 && !idle
                  ? math.sin(_seg(t, 0.5, 0.7) * math.pi)
                  : 0.0;
              final hurt = widget.taken > 0 && !idle
                  ? (1 - _seg(t, 0.6, 0.85)) * (t >= 0.6 ? 1 : 0)
                  : 0.0;
              // 일격: 화면 흔들림
              final camera = widget.skill && hitting
                  ? math.sin(hit * math.pi * 8) * (1 - hit) * 6
                  : 0.0;

              final heroW = w * 0.5;
              final monSize = w * 0.38;
              final monLeft = w - monSize - w * 0.05 + shake - counter * w * 0.07;
              final monTop = h * 0.24;
              final hitX = monLeft + monSize * 0.45;
              final hitY = monTop + monSize * 0.45;

              return Transform.translate(
                offset: Offset(camera, camera * 0.4),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset('assets/images/bg_battle.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFF1B1840))),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0xAA0B0D26)],
                            stops: [0.45, 1],
                          ),
                        ),
                      ),
                    ),
                    // 발밑 그림자
                    Positioned(
                      left: w * 0.06 + lunge * w * 0.08,
                      bottom: 20,
                      child: _Shadow(width: heroW * 0.6),
                    ),
                    Positioned(
                      left: monLeft + monSize * 0.15,
                      top: monTop + monSize * 0.88,
                      child: _Shadow(width: monSize * 0.7),
                    ),
                    // 몬스터 (맞으면 흔들리고 하얗게 번쩍, 반격할 때 앞으로)
                    Positioned(
                      left: monLeft,
                      top: monTop - (cleared ? 6 : 0),
                      width: monSize,
                      height: monSize,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        child: ColorFiltered(
                          key: ValueKey('${foe.monster.name}_$cleared'),
                          colorFilter: ColorFilter.mode(
                              Colors.white.withValues(alpha: flash * 0.75),
                              BlendMode.srcATop),
                          child: Transform.scale(
                            scale: 1 - flash * 0.06 + counter * 0.06,
                            child: MonsterPicture(
                              monster: foe.monster,
                              size: monSize,
                              purified: cleared,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 각성자 (달려들고, 맞으면 붉게 번쩍)
                    Positioned(
                      left: w * 0.02 + lunge * w * 0.08,
                      bottom: 26 + lunge * 6,
                      width: heroW,
                      height: h * 0.52,
                      child: Transform.rotate(
                        angle: lunge * 0.06 - hurt * 0.05,
                        alignment: Alignment.bottomCenter,
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(
                              const Color(0xFFFF4D4D)
                                  .withValues(alpha: hurt * 0.45),
                              BlendMode.srcATop),
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            // 쉬는 동안 살짝 숨 쉬듯 늘었다 줄었다 한다
                            child: Transform.scale(
                              scaleY: swinging || cleared
                                  ? 1
                                  : 1 + math.sin(t * math.pi * 2) * 0.015,
                              alignment: Alignment.bottomCenter,
                              child: HeroSprite(
                                  look: widget.look,
                                  pose: cleared
                                      ? HeroPose.victory
                                      : swinging
                                          ? HeroPose.attack
                                          : HeroPose.idle),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 타격 효과
                    if (cleared)
                      Positioned(
                        left: monLeft - 10,
                        top: monTop - 60 - _seg(t, 0, 1) * 20,
                        width: monSize + 20,
                        height: monSize + 80,
                        child: Opacity(
                          opacity: idle ? 1 : _seg(t, 0, 0.3),
                          child: Image.asset('assets/images/fx_purify.png',
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox()),
                        ),
                      )
                    else if (hitting && widget.skill)
                      Positioned(
                        left: hitX - w * 0.35 + hit * w * 0.12,
                        top: hitY - w * 0.2,
                        width: w * 0.6,
                        height: w * 0.45,
                        child: Opacity(
                          opacity: 1 - _seg(t, 0.4, 0.7),
                          child: Transform.rotate(
                            angle: -0.3 + hit * 0.5,
                            child: ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                  _kind(context) == SpiritKind.fire
                                      ? Colors.white
                                      : spiritColor(_kind(context)),
                                  BlendMode.modulate),
                              child: Image.asset('assets/images/fx_slash.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox()),
                            ),
                          ),
                        ),
                      )
                    else if (hitting)
                      Positioned(
                        left: hitX - 45,
                        top: hitY - 40,
                        width: 90,
                        height: 80,
                        child: Opacity(
                          opacity: 1 - _seg(t, 0.32, 0.55),
                          child: Transform.scale(
                            scale: 0.5 + _seg(t, 0.22, 0.32) * 0.8,
                            child: Image.asset('assets/images/fx_hit.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                        ),
                      ),
                    // 금빛 불꽃 조각
                    if (hitting)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SparkPainter(
                              origin: Offset(hitX, hitY),
                              progress: _seg(t, 0.22, 0.75),
                              seed: widget.beat,
                              count: widget.skill ? 22 : 12,
                              reach: widget.skill ? 120 : 70,
                            ),
                          ),
                        ),
                      ),
                    // 준 피해: 몬스터 머리 위로 떠오르며 사라진다
                    if (hitting || cleared)
                      Positioned(
                        left: monLeft,
                        width: monSize,
                        top: monTop - 10 - (cleared ? 0 : _seg(t, 0.22, 0.8) * 40),
                        child: Opacity(
                          opacity: cleared ? 1 : 1 - _seg(t, 0.6, 0.9),
                          child: Center(
                            child: Transform.scale(
                              scale: cleared
                                  ? 1
                                  : 0.7 +
                                      Curves.elasticOut
                                              .transform(_seg(t, 0.22, 0.45)) *
                                          0.4,
                              child: _Outlined(
                                cleared ? '정화!' : '-${comma(widget.dealt)}',
                                size: widget.skill ? 36 : 28,
                                color: cleared
                                    ? AppColors.goldBright
                                    : widget.skill
                                        ? const Color(0xFFFFE58A)
                                        : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 받은 피해: 각성자 머리 위
                    if (hurt > 0)
                      Positioned(
                        left: w * 0.08,
                        width: heroW * 0.6,
                        bottom: 26 + h * 0.52 - 10 + _seg(t, 0.6, 0.95) * 30,
                        child: Opacity(
                          opacity: 1 - _seg(t, 0.8, 0.98),
                          child: Center(
                            child: _Outlined('-${comma(widget.taken)}',
                                size: 22, color: const Color(0xFFFF6B6B)),
                          ),
                        ),
                      ),
                    // 일격: 화면 전체가 금빛으로 번쩍
                    if (hitting && widget.skill)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: const Color(0xFFFFF3C8).withValues(
                                alpha: (1 - _seg(t, 0.22, 0.4)) * 0.45),
                          ),
                        ),
                      ),
                    // 층 표시
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xCC14173E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: foe.isBoss
                                    ? AppColors.gauge
                                    : AppColors.gold.withValues(alpha: 0.8)),
                          ),
                          child: Text(widget.floorLabel,
                              style: AppText.title(17,
                                  color: foe.isBoss
                                      ? AppColors.gauge
                                      : AppColors.goldBright)),
                        ),
                      ),
                    ),
                    // 정령의 응원
                    Positioned(
                      left: 8,
                      bottom: 6,
                      child: Row(children: [
                        Transform.translate(
                          offset: Offset(0, -math.sin(t * math.pi) * 6),
                          child: SpiritArt(kind: _kind(context), size: 54),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFBF5E6),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                              cleared
                                  ? '정화했어!'
                                  : widget.skill && hitting
                                      ? '정령의 일격!'
                                      : '할 수 있어!',
                              style: const TextStyle(
                                  color: AppColors.night,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

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
  const _Avatar({required this.look, this.size = 46});

  final HeroLook look;
  final double size;

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
        child: Image.asset(
          look == HeroLook.female
              ? 'assets/images/portrait_female.png'
              : 'assets/images/portrait_male.png',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.6),
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person_rounded, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _HpColumn extends StatelessWidget {
  const _HpColumn({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.colors,
    this.note,
    this.alignEnd = false,
  });

  final String name;
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
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            if (note != null) ...[
              const SizedBox(width: 6),
              Text(note!,
                  style:
                      const TextStyle(color: Color(0xFFE57373), fontSize: 12)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        GlowBar(
            ratio: maxHp == 0 ? 0 : hp / maxHp, colors: colors, height: 11),
        const SizedBox(height: 3),
        Text('HP ${comma(hp)} / ${comma(maxHp)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

/// 둥근 스킬 버튼: 바깥 고리가 충전 정도
class _SkillOrb extends StatelessWidget {
  const _SkillOrb({
    required this.ratio,
    required this.ready,
    required this.onPressed,
    this.away = false,
  });

  final double ratio;
  final bool ready;
  final VoidCallback onPressed;

  /// 정령이 원정 중이라 쓸 수 없다
  final bool away;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: ready ? onPressed : null,
          child: SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 6,
                    color: AppColors.goldBright,
                    backgroundColor: AppColors.track,
                  ),
                ),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: ready
                          ? const [Color(0xFFFFF4C8), Color(0xFFE8B04A),
                              Color(0xFF8A5A1C)]
                          : const [Color(0xFF4A4F86), Color(0xFF262A5A),
                              Color(0xFF181B45)],
                    ),
                    border: Border.all(
                        color: AppColors.goldBright, width: ready ? 2 : 1),
                    boxShadow: ready
                        ? [
                            BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.8),
                                blurRadius: 26,
                                spreadRadius: 2),
                          ]
                        : null,
                  ),
                  child: Icon(Icons.flare_rounded,
                      size: 46,
                      color: ready
                          ? const Color(0xFF5A3410)
                          : AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: ready ? onPressed : null,
          child: Text(
              away
                  ? '정령 원정 중'
                  : ready
                      ? '정령의 일격!'
                      : '충전 중',
              style: AppText.title(15,
                  color: ready ? AppColors.goldBright : AppColors.textMuted)),
        ),
      ],
    );
  }
}

enum HeroPose { idle, attack, victory }

/// 각성자 SD 그림 (공격·승리 자세). 그림이 없으면 서 있는 그림이나 초상화로 대신한다.
/// 파일 이름: hero_attack_male.png, hero_victory_female.png ...
class HeroSprite extends StatelessWidget {
  const HeroSprite({super.key, required this.look, required this.pose});

  final HeroLook look;
  final HeroPose pose;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/hero_${pose.name}_${look.name}.png',
      fit: BoxFit.contain,
      semanticLabel: '각성자',
      errorBuilder: (_, __, ___) => look == HeroLook.male
          ? Image.asset('assets/images/hero_chibi_male.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                  size: 140, color: AppColors.textMuted))
          : const Padding(
              padding: EdgeInsets.only(top: 60),
              child: _Avatar(look: HeroLook.female, size: 120),
            ),
    );
  }
}

/// 몬스터 그림. 그림 파일이 없으면 아이콘으로 대신한다.
class MonsterPicture extends StatelessWidget {
  const MonsterPicture({
    super.key,
    required this.monster,
    this.size = 64,
    this.purified = false,
  });

  final MonsterId monster;
  final double size;

  /// true 면 정화된 모습
  final bool purified;

  static IconData iconOf(MonsterId id) => switch (id) {
        MonsterId.ashSlime => Icons.water_drop_rounded,
        MonsterId.labyrinthBat => Icons.nights_stay_rounded,
        MonsterId.roughWaterSpirit => Icons.waves_rounded,
        MonsterId.shadowButterfly => Icons.flutter_dash_rounded,
        MonsterId.lostStoneSpirit => Icons.landscape_rounded,
        MonsterId.labyrinthWarden => Icons.shield_moon_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final info = Monsters.info(monster);
    final label = purified ? info.purifiedName : info.name;
    return Image.asset(
      purified ? info.purifiedAsset : info.asset,
      width: size,
      height: size,
      semanticLabel: label,
      errorBuilder: (_, __, ___) => Icon(
        iconOf(monster),
        size: size * 0.7,
        color: purified ? AppColors.goldBright : const Color(0xFFB8B2C8),
        semanticLabel: label,
      ),
    );
  }
}

SpiritKind _kind(BuildContext context) =>
    BulssiScope.maybeOf(context)?.kind ?? SpiritKind.fire;
