part of '../battle_view.dart';

class _Scene extends StatefulWidget {
  const _Scene({
    this.height = 380,
    required this.foe,
    required this.cleared,
    required this.floorLabel,
    required this.dealt,
    required this.taken,
    required this.skill,
    required this.look,
    this.heroJob,
    required this.beat,
    required this.beatDuration,
    this.petDash = false,
    this.warning,
    this.guarded = false,
    this.guardButton = false,
    this.guard,
    this.guardBroken = false,
    this.enraged = false,
    this.stance = false,
    this.aura,
    this.crit = false,
    this.superHit = false,
    this.heals = 0,
    this.healed = 0,
    this.defeated = false,
    this.bossBeat = 0,
    this.hitElement,
    this.heroTint,
    this.foeTint,
    this.hour,
    this.season,
    this.background,
    this.weapon,
    this.allies = const [],
    this.resisted = false,
    this.elementHints = false,
  });

  /// 묶음 75 #324: 잘 안 들었는지 · 숫자 위 「효과 좋음 / 잘 안 들어요」를 보일지
  final bool resisted;
  final bool elementHints;

  /// 묶음 52: 각성자 뒤에 서는 3막 동료 (그림 · 색 · 쓰러짐)
  /// 묶음 73 #306: [swing] 이 바뀌면 공격 칸 그림을 한 번 (now: 스킬이라 바로), [dealt] 는 4칸에 뜨는 피해
  final List<({String? art, int color, bool down, int swing, int dealt, bool now})> allies;

  /// 장면 높이 (null 이면 주어진 자리만큼)
  final double? height;

  final WeaponKind? weapon;
  final Color? aura;
  final bool crit;
  final bool superHit;

  /// 회복할 때마다 늘어난다 (초록 숫자)
  final int heals;
  final int healed;
  final bool defeated;
  final int bossBeat;
  final Element? hitElement;
  final Color? heroTint;
  final Color? foeTint;
  final int? hour;
  final Season? season;
  final String? background;

  /// 정령(펫) 스킬: 펫이 몬스터 쪽으로 달려든다
  final bool petDash;

  /// 강한 공격 예고 문구 (막기 시간)
  final String? warning;

  /// 예고에 이미 막기를 눌렀다
  final bool guarded;

  /// 묶음 76 #338: 아래에 「막기!」 버튼이 있음 (안내 글만 바뀜)
  final bool guardButton;

  /// 방금 막은 결과
  final GuardResult? guard;

  /// 묶음 65: 강한 공격을 막지 못함
  final bool guardBroken;

  /// 보스 분노 (붉은 빛)
  final bool enraged;

  /// 방어 태세 중
  final bool stance;

  final Foe foe;
  final bool cleared;
  final String floorLabel;
  final int dealt;
  final int taken;
  final bool skill;
  final HeroLook look;
  final String? heroJob;

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
class _SceneState extends State<_Scene> with TickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.beatDuration);

  /// 보스 등장 띠
  late final AnimationController _boss = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didUpdateWidget(covariant _Scene old) {
    super.didUpdateWidget(old);
    if (widget.beat != old.beat) {
      // 스킬은 조금 느리게 (슬로모션)
      _c.duration = widget.skill ? widget.beatDuration * 1.6 : widget.beatDuration;
      _c.forward(from: 0);
    }
    if (widget.bossBeat != old.bossBeat) _boss.forward(from: 0);
    // 묶음 73 #306: 동료 공격 (2→6칸 뒤 1칸). 보통 공격은 각성자가 친 뒤 차례로, 스킬은 바로
    for (var i = 0; i < widget.allies.length; i++) {
      final a = widget.allies[i];
      final before = i < old.allies.length ? old.allies[i].swing : 0;
      if (a.swing == before || AllyAttackSheet.sheetOf(a.art) == null) continue;
      final scale = allyScale;
      final delay = a.now
          ? 0
          : (widget.beatDuration.inMilliseconds * 0.45 + i * 120 * scale).round();
      final total = delay + (AllyAttackSheet.totalMs * scale).round();
      _allyDelay[i] = delay;
      final c = _allyC[i] ??= AnimationController(vsync: this);
      c.duration = Duration(milliseconds: total);
      c.forward(from: 0);
    }
  }

  /// 동료 공격 칸 컨트롤러 · 그 앞에 기다리는 시간(ms)
  final Map<int, AnimationController> _allyC = {};
  final Map<int, int> _allyDelay = {};

  /// 빠르게 보기면 같은 비율로 짧게 (1배 한 틱 765ms 기준)
  double get allyScale =>
      (widget.beatDuration.inMilliseconds / 765).clamp(0.35, 1.0);

  /// 동료 i 의 지금 칸 (0~5)과, 4칸(맞히는 순간)에서 흐른 비율 (그 칸이 아니면 null)
  (int, double?) _allyFrame(int i) {
    final c = _allyC[i];
    if (c == null || !c.isAnimating) return (0, null);
    final ms = c.value * c.duration!.inMilliseconds - (_allyDelay[i] ?? 0);
    return AllyAttackSheet.frameAt(ms / allyScale);
  }

  @override
  void dispose() {
    for (final c in _allyC.values) {
      c.dispose();
    }
    _boss.dispose();
    _c.dispose();
    super.dispose();
  }

  /// 동료 그림 한 칸: 이야기 동료는 공격 칸 그림(640×640), 이름 없는 동료는 통 그림
  Widget _allyArt(int i, ({String? art, int color, bool down, int swing, int dealt, bool now}) a,
      int frame, double s, double h) {
    Widget icon() => Icon(Icons.person_rounded, size: h * 0.3, color: Color(a.color));
    final sheet = AllyAttackSheet.sheetOf(a.art);
    if (sheet != null) {
      return SheetFrame(
          key: Key('allyFrame_${i}_$frame'),
          asset: sheet,
          frames: AllyAttackSheet.frames,
          frame: frame,
          fallback: a.art == null ? icon() : Image.asset(a.art!, fit: BoxFit.contain));
    }
    if (a.art == null) return Align(alignment: Alignment.bottomCenter, child: icon());
    // 통 그림(768×1024)은 몸이 칸의 약 95% → 공격 칸 그림(약 80%)과 같은 키로
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: s * 0.84,
        child: Image.asset(a.art!,
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => icon()),
      ),
    );
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
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          final h = box.maxHeight;
          return AnimatedBuilder(
            animation: Listenable.merge([_c, ..._allyC.values]),
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

              // 묶음 73 #261: 통 그림 (공격은 여섯 칸)
              final heroPose = cleared
                  ? HeroPose.victory
                  : widget.defeated
                      ? HeroPose.tired
                      : swinging
                          ? HeroPose.attack
                          : HeroPose.idle;
              final attackT = swinging ? _seg(t, 0, 0.5) : 0.0;
              // 묶음 76 #307: 직업 그림 — 대기 = 1칸 + 숨쉬기, 공격 = 2→6칸 (4칸이 0.22 타격 순간)
              var jobFrame = 0;
              if (widget.heroJob != null && !idle && widget.dealt > 0 && !cleared && !widget.defeated) {
                final dur = _c.duration!.inMilliseconds;
                final start = 0.22 * dur -
                    (AllyAttackSheet.durations[0] + AllyAttackSheet.durations[1]) * allyScale;
                jobFrame = AllyAttackSheet.frameAt((t * dur - start) / allyScale).$1;
              }
              // 묶음 73 #260 다듬기: 혼자면 무대 높이의 약 절반(머리가 가운데보다 조금 아래),
              // 동료와 함께면 조금 작게. 그림 칸은 768×1024 (몸은 왼쪽 17%부터)
              final party = widget.allies.isNotEmpty;
              final heroH = h * (party ? 0.5 : 0.58);
              final heroW = math.min(w * 0.5, heroH * 0.75);
              // 뒷줄 동료: 640×640 칸, 주인공보다 왼쪽 · 조금 위, 서로 몸 반 넘게 떨어지게
              final allyS = h * 0.36;
              final allyBottom = h * 0.1;
              final allyLeft0 = -allyS * 0.12;
              final allyStep = allyS * 0.5;
              // 각성자 몸이 시작하는 자리: 혼자면 정령 말풍선 오른쪽, 함께면 뒷줄 동료 얼굴을 가리지 않게
              final bodyStart = party
                  ? allyLeft0 + allyStep * (widget.allies.length - 1) + allyS * 0.74
                  : 128.0;
              final heroLeft = math.max(w * 0.02, bodyStart - heroW * 0.17);
              // (아래 효과 자리들은 「front + w * …」로 각성자를 따라간다)
              final front = heroLeft - w * 0.02;
              // 동료 공격 칸 · 4칸(맞히는 순간)
              final allyFrames = [
                for (var i = 0; i < widget.allies.length; i++)
                  widget.allies[i].down ? (0, null) : _allyFrame(i)
              ];
              var allyShake = 0.0;
              for (final (f, p) in allyFrames) {
                if (f == 3 && p != null) allyShake += math.sin(p * math.pi * 6) * (1 - p) * 4;
              }
              final monSize = w * (party ? 0.34 : 0.38);
              final monLeft = w - monSize - w * 0.02 + shake + allyShake - counter * w * 0.07;
              final monTop = h * 0.24;
              final hitX = monLeft + monSize * 0.45;
              final hitY = monTop + monSize * 0.45;
              // 묶음 76 #315: 방패 자리 — 주인공 그림의 실제 머리 · 발 위치로 (768×1024 칸, 발 바닥 1004)
              final heroLeftNow = front + w * 0.02 + lunge * w * 0.08;
              final heroBottomNow = 8 + lunge * 6;
              final spriteH = heroW * 1024 / 768;
              // 서기 · 공격 그림 모두 몸은 칸 가운데, 키는 칸 높이의 약 68% (640×800 칸이 768×1024 칸 바닥에)
              final feetY = heroBottomNow + spriteH * 22 / 1024; // 무대 아래에서 발까지
              final bodyH = spriteH * 0.68; // 발 → 머리 끝
              final shieldD = bodyH * 0.55;
              final shieldCx = heroLeftNow + heroW * 0.72; // 몸 앞쪽 (몬스터 쪽)
              final shieldCy = feetY + bodyH * 0.62; // 가슴 높이 (아래에서)
              final heroHeadY = feetY + bodyH; // 머리 끝 (아래에서)
              Widget shieldAt(Key key, Widget child, {double scale = 1}) => Positioned(
                    key: key,
                    left: shieldCx - shieldD * scale / 2,
                    bottom: shieldCy - shieldD * scale / 2,
                    width: shieldD * scale,
                    height: shieldD * scale,
                    child: IgnorePointer(child: child),
                  );

              // 치명타·스킬: 살짝 확대 (11-11 #81)
              final punch = !idle && (widget.crit || widget.skill)
                  ? math.sin(_seg(t, 0.15, 0.7) * math.pi) *
                      (widget.skill ? 0.08 : 0.05)
                  : 0.0;
              final critShake = widget.crit && hitting
                  ? math.sin(hit * math.pi * 10) * (1 - hit) * 4
                  : 0.0;
              return Transform.translate(
                offset: Offset(camera + critShake, camera * 0.4),
                child: Transform.scale(
                 scale: 1 + punch,
                 child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                          widget.background ?? 'assets/images/bg_battle.webp',
                          fit: BoxFit.cover,
                          // 그림이 아직 없으면 비슷한 배경 → 기본 배경 → 색
                          errorBuilder: (_, __, ___) => Image.asset(
                              backgroundFallback(widget.background),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Color(0xFF1B1840)))),
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
                    // 시간 색감 · 몬스터 속성 입자 · 비·눈 (11-11 #81)
                    // 공격이 오갈 때마다 조금씩 흐른다 (끝없이 도는 애니메이션은 쓰지 않는다)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          key: const Key('battleAmbient'),
                          foregroundPainter: widget.season == null
                              ? null
                              : SeasonPainter(
                                  season: widget.season!,
                                  t: ((widget.beat + t) * 0.06) % 1.0,
                                  few: MediaQuery.maybeDisableAnimationsOf(
                                          context) ??
                                      false),
                          painter: _AmbientPainter(
                            t: ((widget.beat + t) * 0.11) % 1.0,
                            element: foe.info.element,
                            hour: widget.hour,
                          ),
                        ),
                      ),
                    ),
                    // 발밑 그림자
                    Positioned(
                      left: front + w * 0.06 + lunge * w * 0.08,
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
                          key: ValueKey('${foe.monster.name}_${foe.reveal}_$cleared'),
                          colorFilter: ColorFilter.mode(
                              Colors.white.withValues(alpha: flash * 0.75),
                              BlendMode.srcATop),
                          child: Transform.scale(
                            scale: (1 - flash * 0.06 + counter * 0.06) *
                                (widget.enraged ? 1.08 : 1),
                            child: widget.enraged && !cleared
                                ? DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: const Color(0xFFFF3B3B)
                                                .withValues(alpha: 0.55),
                                            blurRadius: 40,
                                            spreadRadius: 6),
                                      ],
                                    ),
                                    child: ColorFiltered(
                                      key: const Key('bossRage'),
                                      colorFilter: ColorFilter.mode(
                                          const Color(0xFFFF2E2E)
                                              .withValues(alpha: 0.35),
                                          BlendMode.srcATop),
                                      child: MonsterPicture(
                                        monster: foe.monster,
                                        size: monSize,
                                        reveal: foe.reveal,
                                      ),
                                    ),
                                  )
                                : cleared
                                    // 묶음 18 #149: 정화된 몬스터는 또렷하게
                                    ? PurifiedMonster(
                                        monster: foe.monster,
                                        size: monSize * 0.66)
                                    : _tinted(
                                        widget.foeTint,
                                        MonsterPicture(
                                          monster: foe.monster,
                                          size: monSize,
                                          reveal: foe.reveal,
                                          crystal: foe.monster ==
                                                  MonsterId.dummyElement
                                              ? elementColor(foe.element)
                                              : null,
                                          tint: foe.tint,
                                        )),
                          ),
                        ),
                      ),
                    ),
                    // 보스 장비 6개 세트: 각성자 둘레 세트 빛 (11-11 #82)
                    if (widget.aura != null)
                      Positioned(
                        key: const Key('battleAura'),
                        left: front + w * 0.02 + lunge * w * 0.08 - heroW * 0.1,
                        bottom: 10,
                        width: heroW * 1.2,
                        height: h * 0.62,
                        child: IgnorePointer(
                          child: Stack(fit: StackFit.expand, children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(colors: [
                                  widget.aura!.withValues(
                                      alpha: 0.45 + 0.15 * math.sin(t * math.pi)),
                                  widget.aura!.withValues(alpha: 0),
                                ]),
                              ),
                            ),
                            // 묶음 19 6-3: 세트마다 다른 무늬·반짝임
                            if (SetAuraPattern.ofAura(widget.aura)
                                case final set?)
                              SetAuraPattern(set: set),
                          ]),
                        ),
                      ),
                    // 묶음 52 #243 · 묶음 73 #260/#306: 뒷줄 동료 (이야기 동료는 오른쪽을 본 1칸 + 숨쉬기, 공격하면 2→6칸)
                    for (var i = widget.allies.length - 1; i >= 0; i--)
                      Positioned(
                        key: Key('sceneAlly_$i'),
                        left: allyLeft0 + i * allyStep,
                        bottom: allyBottom,
                        width: allyS,
                        height: allyS,
                        child: Opacity(
                          opacity: widget.allies[i].down ? 0.35 : 0.97,
                          child: Transform.scale(
                            alignment: Alignment.bottomCenter,
                            scaleY: allyFrames[i].$1 != 0 || widget.allies[i].down
                                ? 1
                                : 1 + math.sin((t + i * 0.37) * math.pi * 2) * 0.015,
                            child: _allyArt(i, widget.allies[i], allyFrames[i].$1, allyS, h),
                          ),
                        ),
                      ),
                    // 각성자 (달려들고, 맞으면 붉게 번쩍)
                    Positioned(
                      key: const Key('sceneHero'),
                      left: front + w * 0.02 + lunge * w * 0.08,
                      bottom: 8 + lunge * 6,
                      width: heroW,
                      height: heroH,
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
                              scaleY: swinging || cleared || jobFrame > 0
                                  ? 1
                                  : 1 + math.sin(t * math.pi * 2) * 0.015,
                              alignment: Alignment.bottomCenter,
                              child: _tinted(
                                  widget.heroTint,
                                  HeroSprite(
                                      look: widget.look,
                                      pose: widget.heroJob == null ||
                                              heroPose == HeroPose.victory ||
                                              heroPose == HeroPose.tired
                                          ? heroPose
                                          : jobFrame > 0
                                              ? HeroPose.attack
                                              : HeroPose.idle,
                                      t: attackT,
                                      job: widget.heroJob,
                                      frame: jobFrame)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 묶음 57: 활로 쏘면 화살이 날아감
                    // 묶음 76 #307: 궁수 그림은 4칸에 화살이 이미 있어 코드 화살은 뺀다
                    if (widget.weapon == WeaponKind.bow && swinging && !cleared &&
                        widget.heroJob != JobId.archer.name)
                      Positioned(
                        left: front + w * 0.12 + (hitX - front - w * 0.12) * _seg(t, 0.05, 0.3) - 64,
                        top: hitY - 16,
                        width: 128,
                        height: 32,
                        child: IgnorePointer(
                          child: Opacity(
                            key: const Key('fxArrow'),
                            opacity: 1 - _seg(t, 0.3, 0.38),
                            child: Image.asset('assets/images/fx_arrow.webp',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox()),
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
                          child: Image.asset('assets/images/fx_purify.webp',
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
                              child: Image.asset('assets/images/fx_slash.webp',
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
                            // 속성 타격 그림이 있으면 그것, 없으면 기본 타격에 속성 색
                            child: widget.hitElement == null
                                ? Image.asset('assets/images/fx_hit.webp',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox())
                                : Image.asset(
                                    'assets/images/fx_hit_${widget.hitElement!.name}.webp',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _tinted(
                                        elementColor(widget.hitElement),
                                        Image.asset('assets/images/fx_hit.webp',
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox()),
                                        alpha: 0.55)),
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
                          opacity: cleared
                              ? (widget.guard != null && !idle ? _seg(t, 0.42, 0.55) : 1)
                              : 1 - _seg(t, 0.6, 0.9),
                          child: Center(
                            child: Transform.scale(
                              scale: cleared
                                  ? 1
                                  : 0.7 +
                                      Curves.elasticOut
                                              .transform(_seg(t, 0.22, 0.45)) *
                                          0.4,
                              // 피해 숫자 (11-11 #81): 보통 흰색, 치명타 크고 노랑, 약점 빨강
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                // 묶음 75 #324: 속성 허수아비 — 숫자 위 작은 글 (배율은 숨김)
                                if (widget.elementHints && !cleared && (widget.superHit || widget.resisted))
                                  Text(widget.superHit ? '효과 좋음' : '잘 안 들어요',
                                      key: Key(widget.superHit ? 'hintGood' : 'hintBad'),
                                      style: TextStyle(
                                          color: widget.superHit ? AppColors.goldBright : const Color(0xFFB8B8C8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          shadows: const [Shadow(blurRadius: 3)])),
                                _Outlined(
                                  cleared ? '사냥!' : '-${comma(widget.dealt)}',
                                  size: widget.crit || widget.skill ? 38 : 28,
                                  color: cleared
                                      ? AppColors.goldBright
                                      : widget.crit || widget.skill
                                          ? const Color(0xFFFFE14D)
                                          : widget.superHit
                                              ? const Color(0xFFFF5A5A)
                                              : Colors.white,
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    // 받은 피해: 각성자 머리 위
                    if (hurt > 0)
                      Positioned(
                        left: front + w * 0.08,
                        width: heroW * 0.6,
                        bottom: 8 + heroH * 0.85 + _seg(t, 0.6, 0.95) * 30,
                        child: Opacity(
                          opacity: 1 - _seg(t, 0.8, 0.98),
                          child: Center(
                            // 막으면 파랑, 아니면 흰색
                            child: _Outlined('-${comma(widget.taken)}',
                                size: 22,
                                color: widget.guard != null
                                    ? const Color(0xFF6FB8FF)
                                    : Colors.white),
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
                    // 방어 태세: 주인공 앞 원형 방패 (fx_guard, 은은히 숨쉬기) — 묶음 76 #315
                    if (widget.stance && !cleared && !(widget.guarded && widget.warning != null && widget.guard == null))
                      shieldAt(
                          const Key('fxStance'),
                          Opacity(
                            opacity: 0.7 + 0.15 * math.sin(t * math.pi * 2).abs(),
                            child: Image.asset('assets/images/fx_guard.webp',
                                errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                          scale: 1 + 0.03 * math.sin(t * math.pi * 2)),
                    // 묶음 65 #256: 막기 준비 (캐릭터 앞 방어막, 은은히 숨 쉬듯)
                    if (widget.guarded && widget.warning != null && widget.guard == null)
                      shieldAt(
                          const Key('fxGuard'),
                          Opacity(
                            opacity: 0.75 + 0.25 * math.sin(t * math.pi * 2).abs(),
                            child: Image.asset('assets/images/fx_guard.webp',
                                errorBuilder: (_, __, ___) => DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.mana.withValues(alpha: 0.7), width: 3),
                                      ),
                                    )),
                          )),
                    // 막기 결과: 막은 순간 방어막이 번쩍 + 「막았다!」(안내 글은 그 뒤에)
                    // 묶음 76 #315: 그 공격으로 몬스터가 쓰러지면 번쩍임은 0.4초 안에 끝내고 승리 자세로,
                    // 글은 「완벽한 막기!」(주인공 위) → 「사냥!」(무대 가운데 위) 차례로
                    if (widget.guard != null && !idle) ...[
                      shieldAt(
                          const Key('fxGuardHit'),
                          Opacity(
                            opacity: cleared ? 1 - _seg(t, 0.15, 0.45) : 1 - _seg(t, 0.55, 0.95),
                            child: Transform.scale(
                              scale: 0.95 + 0.15 * _seg(t, 0.0, 0.2),
                              child: Image.asset('assets/images/fx_guardHit.webp',
                                  errorBuilder: (_, __, ___) => Icon(Icons.shield_rounded,
                                      size: 56,
                                      color: widget.guard == GuardResult.perfect ? AppColors.goldBright : AppColors.mana)),
                            ),
                          ),
                          scale: 1.15),
                      Positioned(
                        key: const Key('guardText'),
                        left: heroLeftNow,
                        width: heroW,
                        // 승리 자세(통 그림)는 키가 더 커서 그 머리 위로
                        bottom: (cleared ? feetY + spriteH * 0.86 : heroHeadY) + 6 + _seg(t, 0.1, 0.6) * 16,
                        child: Opacity(
                          opacity: cleared ? 1 - _seg(t, 0.3, 0.45) : 1 - _seg(t, 0.75, 0.98),
                          child: Center(
                            child: _Outlined(
                                widget.guard == GuardResult.perfect ? '완벽한 막기!' : '막았다!',
                                size: 22,
                                color: widget.guard == GuardResult.perfect ? AppColors.goldBright : Colors.white),
                          ),
                        ),
                      ),
                    ],
                    // 막지 못함: 방어막이 깨짐
                    if (widget.guardBroken && widget.guard == null && !idle)
                      shieldAt(
                          const Key('fxGuardBreak'),
                          Opacity(
                            opacity: 1 - _seg(t, 0.55, 0.95),
                            child: Image.asset('assets/images/fx_guardBreak.webp', errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                          scale: 1.15),
                    // 강한 공격 예고: 화면을 누르면 막기
                    if (widget.warning != null)
                      Positioned(
                        key: const Key('guardWarning'),
                        left: 0,
                        right: 0,
                        // 묶음 65: 위 「BOSS」 · 층 표 아래로 (겹치지 않게)
                        top: math.max(monTop - 46, 50.0),
                        child: IgnorePointer(
                          child: Column(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xDDB3261E),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white70),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const GameGlyph(Glyph.warn, size: 16),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(widget.warning!,
                                          style: AppText.title(16,
                                              color: Colors.white)),
                                    ),
                                  ]),
                            ),
                          ]),
                        ),
                      ),
                    // 묶음 76 #338: 무대 아래쪽 가운데 작게 (머리 · 몬스터 · 경고 띠와 안 겹치게)
                    if (widget.warning != null && !(widget.guard != null && !idle))
                      Positioned(
                        key: const Key('guardHint'),
                        left: 0,
                        right: 0,
                        bottom: 6,
                        child: IgnorePointer(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xB30B0D26),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                  widget.guarded
                                      ? '막기 준비!'
                                      : widget.guardButton
                                          ? '아래 「막기!」를 눌러요'
                                          : '화면을 눌러 막기!',
                                  style: TextStyle(
                                      color: widget.guarded ? AppColors.mana : AppColors.goldBright,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                      ),
                    // 회복: 초록 숫자
                    if (widget.healed > 0)
                      Positioned(
                        left: front + w * 0.06,
                        width: heroW * 0.7,
                        bottom: h * 0.5,
                        child: IgnorePointer(
                          child: TweenAnimationBuilder<double>(
                            key: ValueKey('heal_${widget.heals}'),
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 900),
                            builder: (_, v, __) => Opacity(
                              opacity: (1 - v).clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, -24 * v),
                                child: Center(
                                  child: _Outlined('+${comma(widget.healed)}',
                                      size: 22,
                                      color: const Color(0xFF6BE38A)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // 승리: 빛 조각으로 흩어지고 마석·재료가 튀어나온다
                    if (cleared && !idle) ...[
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SparkPainter(
                              origin: Offset(monLeft + monSize / 2,
                                  monTop + monSize / 2),
                              progress: _seg(t, 0, 0.9),
                              seed: widget.beat + 7,
                              count: 28,
                              reach: 140,
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < 3; i++)
                        Positioned(
                          // 묶음 76 #315: 보상 아이콘은 무대 안쪽에 (오른쪽 끝에서 잘리지 않게)
                          left: (monLeft +
                                  monSize / 2 -
                                  14 +
                                  (i - 1) * 30 * _seg(t, 0, 0.5) +
                                  _seg(t, 0.5, 1) * w * 0.25)
                              .clamp(4.0, w - 36),
                          top: monTop +
                              monSize / 2 -
                              math.sin(_seg(t, 0, 0.5) * math.pi) * 60 +
                              _seg(t, 0.5, 1) * h * 0.35,
                          child: Opacity(
                            opacity: 1 - _seg(t, 0.8, 1),
                            child: i == 1
                                ? const GameIcon('mana_stone',
                                    size: 28, fallback: Icons.diamond_rounded)
                                : const Icon(Icons.inventory_2_rounded,
                                    size: 24, color: AppColors.goldBright),
                          ),
                        ),
                    ],
                    // 패배: 화면이 어두워진다
                    if (widget.defeated)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 0.62),
                            duration: const Duration(milliseconds: 700),
                            builder: (_, v, __) => ColoredBox(
                                key: const Key('battleDefeatDim'),
                                color: Colors.black.withValues(alpha: v)),
                          ),
                        ),
                      ),
                    // 보스 등장: 이름 띠
                    AnimatedBuilder(
                      animation: _boss,
                      builder: (_, __) {
                        final b = _boss.value;
                        if (b <= 0 || b >= 1 || !foe.isBoss) {
                          return const SizedBox.shrink();
                        }
                        final a = b < 0.15
                            ? b / 0.15
                            : b > 0.8
                                ? (1 - b) / 0.2
                                : 1.0;
                        return Positioned(
                          left: 0,
                          right: 0,
                          top: h * 0.42,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: a,
                              child: Container(
                                key: const Key('bossIntro'),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                color: const Color(0xCC1A0B0B),
                                child: Column(children: [
                                  Text('BOSS',
                                      style: AppText.title(14,
                                          color: const Color(0xFFFF8A65))),
                                  Text(foe.name,
                                      style: AppText.title(22,
                                          color: AppColors.goldBright)),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
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
                              style: AppText.title(16,
                                  color: foe.isBoss
                                      ? AppColors.gauge
                                      : AppColors.goldBright)),
                        ),
                      ),
                    ),
                    // 묶음 73 #306: 동료 피해 숫자 (4칸, 맞히는 순간)
                    for (var i = 0; i < widget.allies.length; i++)
                      if (allyFrames[i].$2 case final p? when widget.allies[i].dealt > 0)
                        Positioned(
                          key: Key('allyDealt_$i'),
                          left: monLeft + monSize * (0.05 + i * 0.22),
                          top: monTop - 8 - p * 26,
                          child: IgnorePointer(
                            child: Opacity(
                              opacity: (1 - p * 0.7).clamp(0.0, 1.0),
                              child: _Outlined('-${comma(widget.allies[i].dealt)}',
                                  size: 20, color: const Color(0xFFE8F0FF)),
                            ),
                          ),
                        ),
                    // 정령의 응원 (묶음 73 #260: 무대 왼쪽 아래 구석, 말풍선은 정령 오른쪽 위 — 누구 발도 덮지 않게)
                    // 펫이면 주인공 발 앞쪽 아래에 서고, 말풍선만 구석에
                    Builder(builder: (context) {
                      final pet = BulssiScope.maybeOf(context)?.petSpecies != null;
                      final petS = h * 0.17;
                      final dash = widget.petDash && !idle
                          ? math.sin(_seg(t, 0, 0.5) * math.pi) * w * 0.3
                          : 0.0;
                      return Positioned(
                        left: pet ? heroLeft + heroW * 0.55 + dash : 4 + dash,
                        bottom: pet ? 0 : 4,
                        child: Transform.translate(
                          offset: Offset(0, -math.sin(t * math.pi) * 6),
                          child: BattleCompanion(
                              key: const Key('battleCompanion'), size: pet ? petS : 44),
                        ),
                      );
                    }),
                    Builder(builder: (context) {
                      final pet = BulssiScope.maybeOf(context)?.petSpecies != null;
                      return Positioned(
                        key: const Key('companionLine'),
                        left: pet ? 6 : 40,
                        bottom: pet ? 6 : 38,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: math.max(80, heroLeft + heroW * 0.17 - (pet ? 14 : 46))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBF5E6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                                cleared
                                    ? '잡았어!'
                                    : widget.defeated
                                        ? '괜찮아? 오늘은 좀 쉬자.'
                                        : widget.warning != null
                                            ? '조심해!'
                                            : widget.enraged
                                                ? '화났어, 조심!'
                                                : widget.skill && hitting
                                                    ? skillLabel(context)
                                                    : '할 수 있어!',
                                style: const TextStyle(
                                    color: AppColors.night,
                                    fontSize: 11.5,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      );
                    }),
                  ],
                 ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
