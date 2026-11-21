part of '../harvest_games.dart';

class _FlowerGame extends StatefulWidget {
  const _FlowerGame({required this.ctl});
  final _GameCtl ctl;
  @override
  State<_FlowerGame> createState() => _FlowerGameState();
}

class _FlowerGameState extends State<_FlowerGame> with SingleTickerProviderStateMixin {
  final _rng = math.Random();
  late int _wind = _rng.nextInt(HarvestRules.flowerWindMs.length);
  late final AnimationController _a = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: HarvestRules.flowerWindMs[_wind]))
    ..repeat(reverse: true);
  final _res = <bool>[];
  bool get _over => _res.length >= 3;

  /// 가운데에서 이만큼 안이면 성공 (-1~1 기준)
  double get _tol => 0.16 + 0.04 * widget.ctl.ease;
  double get _sway => (_a.value * 2 - 1);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _tap() {
    if (_over) return;
    final hit = _sway.abs() <= _tol;
    widget.ctl.feel.tap();
    if (hit) widget.ctl.feel.sfx(SfxKind.pluck);
    setState(() => _res.add(hit));
    if (_over) {
      _a.stop();
      final hits = _res.where((x) => x).length;
      widget.ctl.onDone(HarvestPlay(_grade(hits, perfect: 3, good: 2)));
      return;
    }
    // 다음 판은 바람이 바뀜
    _wind = _rng.nextInt(HarvestRules.flowerWindMs.length);
    _a.duration = Duration(milliseconds: HarvestRules.flowerWindMs[_wind]);
    _a.repeat(reverse: true);
  }

  String get _windLabel => switch (_wind) {
        0 => '바람 세게',
        1 => '바람 보통',
        _ => '바람 약하게',
      };

  @override
  Widget build(BuildContext context) => Column(children: [
        // 바람 줄기 표시
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 3 - _wind; i++)
            const Icon(Icons.air_rounded, size: 20, color: Color(0xFFBFE6FF)),
          const SizedBox(width: 6),
          Text(_windLabel,
              key: const Key('flowerWind'),
              style: const TextStyle(
                  color: Color(0xFFBFE6FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            final h = box.maxHeight;
            final band = math.min(box.maxWidth, h) * _tol * 1.2;
            return AnimatedBuilder(
              animation: _a,
              builder: (_, __) =>
                  Stack(alignment: Alignment.bottomCenter, children: [
                // 가운데 금빛 표시
                Positioned(
                  bottom: 0,
                  top: h * 0.05,
                  child: Container(
                    width: band,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.goldBright.withValues(alpha: 0),
                        AppColors.goldBright.withValues(alpha: 0.28),
                        AppColors.goldBright.withValues(alpha: 0),
                      ]),
                    ),
                    alignment: Alignment.center,
                    child: Container(
                        width: 2,
                        color: AppColors.goldBright.withValues(alpha: 0.8)),
                  ),
                ),
                Transform.rotate(
                  angle: _sway * 0.6,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: h * 0.92,
                    width: h * 0.5,
                    child: _img('harvest_flower_stem',
                        key: const Key('flowerStem'),
                        fallback: const Column(children: [
                          Expanded(
                              flex: 2,
                              child: FittedBox(
                                  child: Icon(Icons.local_florist_rounded,
                                      color: Color(0xFFF7A8C8)))),
                          Expanded(
                              flex: 3,
                              child: SizedBox(
                                  width: 6,
                                  child: ColoredBox(color: Color(0xFF6FBF73)))),
                        ])),
                  ),
                ),
              ]),
            );
          }),
        ),
        const SizedBox(height: 10),
        _Cells(results: [for (var i = 0; i < 3; i++) i < _res.length ? _res[i] : null]),
        const SizedBox(height: 12),
        _ActButton(
            keyName: 'gameTap', label: '따기!', tool: widget.ctl.tool, onTap: _over ? null : _tap),
      ]);
}
