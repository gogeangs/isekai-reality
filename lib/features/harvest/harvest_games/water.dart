part of '../harvest_games.dart';

class _WaterGame extends StatefulWidget {
  const _WaterGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_WaterGame> createState() => _WaterGameState();
}

class _WaterGameState extends State<_WaterGame> {
  final _rng = math.Random();
  Timer? _t;

  /// 시작할 때 정함: 큰 그림자 = 귀한 재료 (놓치면 없음)
  late final bool _big = widget.ctl.debugRare ??
      _rng.nextDouble() < HarvestRules.waterRareChance(widget.ctl.ease);

  /// 0 기다림, 1 찌가 가라앉음, 2 줄 잡기
  int phase = 0;
  int ticks = 0, age = 0;
  double tension = 0.5;
  bool holding = false;
  int inZone = 0; // 0.1초 단위
  bool _over = false;
  late int _dipAt = 15 + _rng.nextInt(20);

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _finish(HarvestGrade g) {
    if (_over) return;
    _over = true;
    _t?.cancel();
    setState(() {});
    widget.ctl.onDone(HarvestPlay(g, rare: _big && g != HarvestGrade.fail));
  }

  void _tick() {
    if (!mounted || _over || widget.ctl.paused.value) return;
    setState(() {
      ticks++;
      age++;
      if (phase == 0 && ticks >= _dipAt) {
        phase = 1;
        ticks = 0;
        widget.ctl.feel.sfx(SfxKind.drop);
      } else if (phase == 1 && ticks > 9) {
        _finish(HarvestGrade.fail); // 놓쳤다
      } else if (phase == 2) {
        tension += holding ? 0.06 : -0.05;
        tension += (_rng.nextDouble() - 0.5) * 0.04;
        tension = tension.clamp(0.0, 1.0);
        if (tension > 0.35 && tension < 0.75) inZone++;
        if (tension >= 1) {
          _finish(inZone >= 12 ? HarvestGrade.good : HarvestGrade.fail);
        } else if (ticks >= 40) {
          _finish(inZone >= 25
              ? HarvestGrade.perfect
              : inZone >= 12
                  ? HarvestGrade.good
                  : HarvestGrade.fail);
        }
      }
    });
  }

  void _down() {
    if (_over) return;
    widget.ctl.feel.tap();
    if (phase == 0) {
      // 너무 일찍 누르면 다시 기다린다
      setState(() {
        ticks = 0;
        _dipAt = 15 + _rng.nextInt(20);
      });
    } else if (phase == 1) {
      setState(() {
        phase = 2;
        ticks = 0;
      });
    }
    holding = true;
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(
            switch (phase) {
              0 => '찌를 지켜봐요…',
              1 => '퐁당! 지금 당기기!',
              _ => '줄이 끊기지 않게 눌러 잡아요',
            },
            key: const Key('waterLine'),
            style: AppText.title(19,
                color: phase == 1 ? AppColors.goldBright : AppColors.text)),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth, h = box.maxHeight;
            final bob = math.sin(age / 4) * 4;
            final fishX = 0.5 + math.sin(age / 13) * 0.25;
            final fishW = w * (_big ? 0.46 : 0.22);
            return Stack(clipBehavior: Clip.none, children: [
              // 물 아래 물고기 그림자
              Positioned(
                left: w * fishX - fishW / 2,
                top: h * 0.58,
                width: fishW,
                height: fishW * 0.45,
                child: Opacity(
                  opacity: 0.55,
                  child: _img('harvest_water_fish',
                      key: Key(_big ? 'fishBig' : 'fishSmall'),
                      fallback: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A1A2A),
                          borderRadius: BorderRadius.circular(fishW),
                        ),
                      )),
                ),
              ),
              // 물결
              Positioned(
                left: 0,
                right: 0,
                top: h * 0.42,
                height: 3,
                child: const ColoredBox(color: Color(0x667FD8FF)),
              ),
              // 찌 (가라앉으면 아래로)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                left: w * 0.5 - h * 0.11,
                top: h * (phase == 1 ? 0.36 : 0.26) + bob,
                width: h * 0.22,
                height: h * 0.22,
                child: _img('harvest_water_bobber',
                    key: const Key('waterBobber'),
                    fallback: const FittedBox(
                        child: Icon(Icons.radio_button_checked_rounded,
                            color: Color(0xFFE85C5C)))),
              ),
              if (phase == 1)
                Positioned(
                  left: w * 0.5 - h * 0.2,
                  top: h * 0.3,
                  width: h * 0.4,
                  height: h * 0.25,
                  child: const IgnorePointer(
                    child: _Burst(
                        key: ValueKey('splash'),
                        colors: [Color(0xFFBFE6FF), Color(0xFF7FD8FF)],
                        label: '퐁당!'),
                  ),
                ),
            ]);
          }),
        ),
        if (phase == 2)
          SizedBox(
            height: 26,
            child: CustomPaint(
              key: const Key('waterTension'),
              painter: _BarPainter(tension, 0.35, 0.75),
              size: Size.infinite,
            ),
          )
        else
          const SizedBox(height: 26),
        const SizedBox(height: 10),
        _FillBar(value: phase == 2 ? inZone / 25 : 0, label: '줄 힘'),
        const SizedBox(height: 12),
        _HoldButton(
            keyName: 'gameFish',
            label: phase < 2 ? '당기기!' : '눌러 잡기',
            tool: widget.ctl.tool,
            onDown: _down,
            onUp: () => holding = false),
      ]);
}
