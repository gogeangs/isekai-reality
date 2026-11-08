import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'bulssi_mood.dart';

/// 불씨 그림 + 말풍선. 모든 화면에서 같은 모양으로 쓴다.
/// 빛 색(날씨·시간)과 이름은 [BulssiScope] 에서 받는다.
class BulssiBubble extends StatelessWidget {
  const BulssiBubble({super.key, required this.line, this.size = 72});

  final String line;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scope = BulssiScope.maybeOf(context);
    final glow = (scope?.mood ?? BulssiMood.gold).color;
    final name = scope?.spiritName ?? '불씨';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: glow.withValues(alpha: 0.55),
                blurRadius: size * 0.45,
                spreadRadius: size * 0.02,
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/bulssi.png',
            width: size,
            height: size,
            semanticLabel: '정령 $name',
            errorBuilder: (_, __, ___) => Icon(
              Icons.local_fire_department_rounded,
              color: glow,
              size: size * 0.78,
              semanticLabel: '정령 $name',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text(name,
                    style: TextStyle(
                        color: glow,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBF5E6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  line,
                  style: const TextStyle(
                    color: AppColors.night,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
