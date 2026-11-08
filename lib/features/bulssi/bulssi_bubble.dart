import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 불씨 그림 + 말풍선. 모든 화면에서 같은 모양으로 쓴다.
class BulssiBubble extends StatelessWidget {
  const BulssiBubble({super.key, required this.line, this.size = 72});

  final String line;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          'assets/images/bulssi.png',
          width: size,
          height: size,
          semanticLabel: '정령 불씨',
          errorBuilder: (_, __, ___) => Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.gold,
            size: size * 0.78,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        ),
      ],
    );
  }
}
