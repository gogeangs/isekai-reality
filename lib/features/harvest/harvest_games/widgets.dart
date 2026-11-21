part of '../harvest_games.dart';

class _QuitButton extends StatelessWidget {
  const _QuitButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('harvestQuit'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(
            color: const Color(0xCC0B0D26),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.close_rounded, size: 16, color: AppColors.goldBright),
            SizedBox(width: 3),
            Text('그만두기',
                style: TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}

/// 「도구 → 받을 재료」 한 줄 (귀한 재료는 검은 실루엣 + 금빛 테두리)
class _ToolLine extends StatelessWidget {
  const _ToolLine({required this.tool, required this.toolName, required this.base});

  final String? tool;
  final String toolName;
  final MaterialId base;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w700);
    return FittedBox(
      key: const Key('harvestToolLine'),
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
        decoration: BoxDecoration(
          color: const Color(0xAA0B0D26),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (tool != null)
            _img(tool!,
                width: 22,
                height: 22,
                fallback: const Icon(Icons.handyman_rounded,
                    size: 18, color: AppColors.goldBright)),
          const SizedBox(width: 4),
          Text(toolName, style: style),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward_rounded,
                size: 15, color: AppColors.goldBright),
          ),
          MaterialIcon(base, size: 22),
          const SizedBox(width: 3),
          Text(Materials.info(base).name, style: style),
          const Text(' · ', style: style),
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF07070C),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBright, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: AppColors.goldBright.withValues(alpha: 0.4),
                    blurRadius: 6),
              ],
            ),
            child: const Text('?',
                style: TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 3),
          const Text('귀한 재료?', style: style),
        ]),
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
          decoration: BoxDecoration(
            color: const Color(0x99070818),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(text,
            key: const Key('harvestHint'),
            maxLines: 1,
            style: const TextStyle(
                color: Color(0xFFE6DCC4),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
        ),
      );
}

/// 처음 할 때만: 큰 말풍선 설명 + 「시작!」
class _FirstBubble extends StatelessWidget {
  const _FirstBubble({required this.text, required this.tool, required this.onStart});

  final String text;
  final String? tool;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              key: const Key('harvestFirstBubble'),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E7CC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFB08A4A), width: 2),
                boxShadow: const [
                  BoxShadow(color: Color(0x88000000), blurRadius: 14),
                ],
              ),
              child: Row(children: [
                if (tool != null) ...[
                  _img(tool!, width: 48, height: 48),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: KText(text,
                      style: const TextStyle(
                          color: Color(0xFF3A2614),
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            const SizedBox(height: 18),
            GoldButton(
                key: const Key('gameStart'), label: '시작!', onPressed: onStart),
          ]),
        ),
      );
}

/// 맞출 때마다 금빛으로 차는 칸 (3번 하는 게임)
class _Cells extends StatelessWidget {
  const _Cells({required this.results});

  /// 칸마다: null 아직 · true 맞춤 · false 놓침
  final List<bool?> results;

  @override
  Widget build(BuildContext context) => Row(
        key: const Key('harvestCells'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final r in results)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 46,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: r == true
                    ? const LinearGradient(
                        colors: [Color(0xFFFFE7A3), Color(0xFFE0A93A)])
                    : null,
                color: r == true
                    ? null
                    : r == false
                        ? const Color(0xFF3A2A2A)
                        : const Color(0xFF1C1F3A),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color: r == true
                        ? const Color(0xFF8A5A14)
                        : AppColors.gold.withValues(alpha: 0.5)),
                boxShadow: r == true
                    ? [
                        BoxShadow(
                            color: AppColors.goldBright.withValues(alpha: 0.6),
                            blurRadius: 8),
                      ]
                    : null,
              ),
            ),
        ],
      );
}

/// 금빛으로 차는 막대 (드러난 정도 · 남은 시간)
class _FillBar extends StatelessWidget {
  const _FillBar({super.key, required this.value, this.gold = true, this.label});

  final double value;
  final bool gold;
  final String? label;

  @override
  Widget build(BuildContext context) => Row(children: [
        if (label != null) ...[
          Text(label!,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1F3A),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: gold
                          ? const [Color(0xFFFFE7A3), Color(0xFFE0A93A)]
                          : const [Color(0xFFB9C3E8), Color(0xFF7884B8)]),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
      ]);
}

/// 연속 완벽 불꽃 (숫자 없이, 다섯 개까지)
class _Flames extends StatelessWidget {
  const _Flames(this.n);

  final int n;

  @override
  Widget build(BuildContext context) => Row(
        key: const Key('harvestFlames'),
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < math.min(n, 5); i++)
            const Padding(
              padding: EdgeInsets.only(left: 1),
              child: Icon(Icons.local_fire_department_rounded,
                  size: 18,
                  color: Color(0xFFFFB347),
                  shadows: [Shadow(color: Color(0xFFFF7A00), blurRadius: 6)]),
            ),
        ],
      );
}

/// 큰 버튼 (도구 그림 + 「뽑기!」)
class _ActButton extends StatelessWidget {
  const _ActButton(
      {required this.keyName, required this.label, required this.tool, this.onTap});

  final String keyName;
  final String label;
  final String? tool;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GoldButton(
        key: Key(keyName),
        label: label,
        height: 60,
        leading: tool == null
            ? null
            : _img(tool!, width: 34, height: 34),
        onPressed: onTap,
      );
}

/// 버튼 없이 화면을 누르는 게임: 버튼 자리에 할 일 한 줄
class _TaskLine extends StatelessWidget {
  const _TaskLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        key: const Key('harvestTask'),
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xCC12142E),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(text, style: AppText.title(17)),
          ),
        ),
      );
}

/// 누르고 있는 동안 (나무 톱질 · 물가 줄 잡기)
class _HoldButton extends StatelessWidget {
  const _HoldButton(
      {required this.keyName,
      required this.label,
      required this.tool,
      required this.onDown,
      required this.onUp});

  final String keyName;
  final String label;
  final String? tool;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: Key(keyName),
        onTapDown: (_) => onDown(),
        onTapUp: (_) => onUp(),
        onTapCancel: onUp,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF3A2E6E), Color(0xFF241B4C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.goldBright, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (tool != null) ...[
              _img(tool!, width: 32, height: 32),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppText.title(19)),
          ]),
        ),
      );
}

/// 위쪽 남은 시간 막대 (0.1초 단위 타이머, 멈춤 중엔 안 줄어듦)
mixin _Clock<T extends StatefulWidget> on State<T> {
  late int timeMax;
  late int timeLeft;
  Timer? _clock;
  bool get over;

  void startClock(int ticks, ValueNotifier<bool> paused, VoidCallback onEnd,
      {VoidCallback? onTick}) {
    timeMax = ticks;
    timeLeft = ticks;
    _clock = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || over || paused.value) return;
      setState(() {
        timeLeft--;
        onTick?.call();
      });
      if (timeLeft <= 0) {
        _clock?.cancel();
        onEnd();
      }
    });
  }

  void stopClock() => _clock?.cancel();

  Widget timeBar() => _FillBar(
      key: const Key('harvestTime'),
      value: timeLeft / timeMax,
      gold: false,
      label: '남은 시간');
}
