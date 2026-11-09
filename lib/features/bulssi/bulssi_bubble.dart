import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../data/storage/record_store.dart';
import 'bulssi_mood.dart';
import 'spirit_art.dart';

/// 정령 그림 + 말풍선. 모든 화면에서 같은 모양으로 쓴다.
/// 정령 종류·이름·빛 색(속성 + 날씨·시간)은 [BulssiScope] 에서 받는다.
class BulssiBubble extends StatelessWidget {
  const BulssiBubble({super.key, required this.line, this.size = 96});

  final String line;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scope = BulssiScope.maybeOf(context);
    final kind = scope?.kind ?? SpiritKind.fire;
    final glow = scope?.glow ?? spiritColor(kind);
    final name = scope?.spiritName ?? kind.defaultName;

    // 정령 몸 전체가 배경 위에 떠 있고, 둘레에 은은한 빛이 번진다.
    // 말풍선 첫 줄에 플레이어가 지어 준 이름을 작게 쓴다.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size * 1.1,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                left: -size * 0.25,
                right: -size * 0.25,
                top: -size * 0.2,
                bottom: -size * 0.2,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          glow.withValues(alpha: 0.38),
                          glow.withValues(alpha: 0.12),
                          glow.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
              SpiritArt(kind: kind, size: size, name: name),
            ],
          ),
        ),
        const SizedBox(width: 2),
        Flexible(
          child: SpeechBubbleArt(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '$name\n',
                  style: const TextStyle(
                    color: Color(0xFF8A5A12),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: line),
              ]),
              style: const TextStyle(
                color: AppColors.night,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
