import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'bulssi_mood.dart';

/// 불씨 그림 + 말풍선. 모든 화면에서 같은 모양으로 쓴다.
/// 빛 색(날씨·시간)과 이름은 [BulssiScope] 에서 받는다.
class BulssiBubble extends StatelessWidget {
  const BulssiBubble({super.key, required this.line, this.size = 96});

  final String line;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scope = BulssiScope.maybeOf(context);
    final glow = (scope?.mood ?? BulssiMood.gold).color;
    final name = scope?.spiritName ?? '불씨';

    // 목업처럼 불씨 몸 전체가 배경 위에 떠 있고, 둘레에 은은한 빛만 번진다.
    // (이름 표시 없이 말풍선 꼬리가 불씨를 가리킨다)
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
              Image.asset(
                'assets/images/bulssi.png',
                width: size,
                height: size * 1.1,
                fit: BoxFit.contain,
                semanticLabel: '정령 $name',
                errorBuilder: (_, __, ___) => Icon(
                  Icons.local_fire_department_rounded,
                  color: glow,
                  size: size * 0.78,
                  semanticLabel: '정령 $name',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 2),
        Flexible(
          child: SpeechBubbleArt(
            child: Text(
              line,
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
