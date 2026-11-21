part of '../battle_view.dart';

/// 내 스킬 작은 버튼 (강타 · 방어 태세, 11-11 #75)
class _MiniSkill extends StatelessWidget {
  const _MiniSkill({
    super.key,
    required this.label,
    required this.icon,
    required this.ratio,
    required this.ready,
    required this.onPressed,
    this.active = false,
    this.sub,
    this.ringColor,
    this.art,
    this.artFrame,
  });

  /// 묶음 35: 버튼 그림 (btn_○○). 있으면 아이콘 대신 둥근 그림
  final String? art;

  /// 묶음 35: 스킬 그림 (종류 테두리 안 70%). [art] 보다 먼저
  final Widget? artFrame;

  final String label;
  final IconData icon;
  final double ratio;
  final bool ready;
  final bool active;
  final VoidCallback onPressed;

  /// 이름 아래 작은 글 (직업 스킬 MP)
  final String? sub;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final lit = ready || active;
    return GestureDetector(
      onTap: ready ? onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 4,
                    color: active
                        ? AppColors.mana
                        : ringColor ?? AppColors.goldBright,
                    backgroundColor: AppColors.track,
                  ),
                ),
                if (artFrame != null)
                  // 충전 중·잠김은 어둡게 (게이지는 둘레 고리)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: ready
                          ? [
                              BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.7),
                                  blurRadius: 14),
                            ]
                          : null,
                    ),
                    child: artFrame,
                  )
                else if (art != null)
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: ready
                          ? [
                              BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.7),
                                  blurRadius: 14),
                            ]
                          : null,
                    ),
                    child: _dimmed(
                        !lit,
                        Image.asset('assets/images/$art.webp',
                            width: 46,
                            height: 46,
                            errorBuilder: (_, __, ___) => Icon(icon,
                                size: 24,
                                color: lit
                                    ? AppColors.goldBright
                                    : AppColors.textMuted))),
                  )
                else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: lit ? const Color(0xFF6A4A1C) : const Color(0xFF262A5A),
                    border: Border.all(
                        color: AppColors.goldBright, width: ready ? 2 : 1),
                    boxShadow: ready
                        ? [
                            BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.7),
                                blurRadius: 14),
                          ]
                        : null,
                  ),
                  child: Icon(icon,
                      size: 24,
                      color: lit ? AppColors.goldBright : AppColors.textMuted),
                ),
              ]),
            ),
            const SizedBox(height: 2),
            Text(keepAll(label),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: lit ? AppColors.goldBright : AppColors.textMuted,
                    fontSize: 11.5,
                    height: 1.15,
                    fontWeight: FontWeight.w700)),
            if (sub != null)
              Text(sub!,
                  maxLines: 1,
                  style: TextStyle(
                      color: ringColor ?? AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// 묶음 76 #338: 강한 공격 예고 동안 「방어 태세」 자리의 「막기!」 버튼.
/// 1.15배 · 금빛으로 숨쉬고, 둘레 고리가 예고 시간만큼 차오른다 (끝 완벽한 막기 구간은 금색).
/// 판정은 전투 화면 전체 Listener([_BattleViewState._onPointer])가 한다 — 이 버튼은 누르는 자리일 뿐
class _GuardButton extends StatefulWidget {
  const _GuardButton(
      {super.key, required this.clock, required this.window, required this.perfect, this.done = false});

  final Stopwatch clock;
  final Duration window;

  /// 끝에서 이만큼이 완벽한 막기
  final Duration perfect;

  /// 이미 눌렀음
  final bool done;

  @override
  State<_GuardButton> createState() => _GuardButtonState();
}

class _GuardButtonState extends State<_GuardButton> with SingleTickerProviderStateMixin {
  late final AnimationController _t =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '막기',
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final w = widget.window.inMilliseconds;
            final p = w <= 0 ? 1.0 : (widget.clock.elapsedMilliseconds / w).clamp(0.0, 1.0);
            final perfectFrom = w <= 0 ? 1.0 : 1 - widget.perfect.inMilliseconds / w;
            final glow = widget.done ? 0.3 : 0.45 + 0.4 * _t.value;
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Transform.scale(
                scale: 1.15,
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: CustomPaint(
                    painter: _GuardRingPainter(progress: p, perfectFrom: perfectFrom),
                    child: Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: AppColors.goldBright.withValues(alpha: glow), blurRadius: 16, spreadRadius: 1),
                          ],
                        ),
                        child: Image.asset('assets/images/btn_guard.webp',
                            width: 46,
                            height: 46,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.shield_rounded, size: 26, color: AppColors.goldBright)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(widget.done ? '막는 중' : '막기!',
                  style: const TextStyle(
                      color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ]);
          },
        ),
      );
}

class _GuardRingPainter extends CustomPainter {
  _GuardRingPainter({required this.progress, required this.perfectFrom});

  final double progress;
  final double perfectFrom;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    const start = -math.pi / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0x55FFFFFF);
    canvas.drawArc(r, 0, math.pi * 2, false, track);
    // 완벽한 막기 구간 (옅은 금색)
    canvas.drawArc(r, start + perfectFrom * math.pi * 2, (1 - perfectFrom) * math.pi * 2, false,
        track..color = AppColors.gold.withValues(alpha: 0.45));
    // 지금까지 찬 만큼 (완벽 구간에 들어가면 금색)
    canvas.drawArc(
        r,
        start,
        progress * math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..color = progress >= perfectFrom ? AppColors.goldBright : Colors.white);
  }

  @override
  bool shouldRepaint(_GuardRingPainter old) => old.progress != progress || old.perfectFrom != perfectFrom;
}

/// 둥근 스킬 버튼: 바깥 고리가 충전 정도
class _SkillOrb extends StatelessWidget {
  const _SkillOrb({
    required this.ratio,
    required this.ready,
    required this.onPressed,
    this.away = false,
    this.size = 104,
    this.compact = false,
  });

  final double size;

  /// 버튼 줄 안 (이름이 잘리지 않게 작은 글씨)
  final bool compact;
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
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 6,
                    color: AppColors.goldBright,
                    backgroundColor: AppColors.track,
                  ),
                ),
                Container(
                  width: size * 0.79,
                  height: size * 0.79,
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
                  // 묶음 35: 펫 버튼 그림 (충전 중엔 어둡게)
                  child: ClipOval(
                    child: _dimmed(
                        !ready,
                        Image.asset('assets/images/btn_pet.webp',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                                Icons.flare_rounded,
                                size: size * 0.44,
                                color: ready
                                    ? const Color(0xFF5A3410)
                                    : AppColors.textMuted))),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          key: const Key('skillButton'),
          onTap: ready ? onPressed : null,
          child: Text(
              away
                  ? '원정 중'
                  : ready
                      ? skillLabel(context)
                      : '충전 중',
              maxLines: compact ? 2 : 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: compact
                  ? TextStyle(
                      color: ready ? AppColors.goldBright : AppColors.textMuted,
                      fontSize: 11.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700)
                  : AppText.title(14,
                      color: ready ? AppColors.goldBright : AppColors.textMuted)),
        ),
      ],
    );
  }
}
