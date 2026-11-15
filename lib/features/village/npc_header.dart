import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 시설 맨 위 마을 사람 (묶음 35): 금테 얼굴 + 이름·역할 + 한마디 말풍선.
/// 처음 만날 때 한 줄(한 번), 그 뒤엔 그 막의 평소 대사 두 줄을 번갈아.
/// 한마디는 화면을 열 때 한 번 정한다 (다시 그려도 바뀌지 않음).
class NpcHeader extends StatefulWidget {
  const NpcHeader({super.key, required this.controller, required this.npc});

  final AppController controller;
  final Npc npc;

  @override
  State<NpcHeader> createState() => _NpcHeaderState();
}

class _NpcHeaderState extends State<NpcHeader> {
  late final String _line = widget.controller.takeNpcLine(widget.npc);

  @override
  Widget build(BuildContext context) {
    final info = VillageRules.npc(widget.npc);
    return Row(
      key: Key('npc_${widget.npc.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NpcFace(npc: widget.npc, size: 58),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(info.name, style: AppText.title(16, color: AppColors.goldBright)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(info.role,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 4),
              // 말풍선 (꼬리는 얼굴 쪽)
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E7CC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB08A4A)),
                  ),
                  child: KText(_line,
                      key: Key('npcLine_${widget.npc.name}'),
                      style: const TextStyle(
                          color: Color(0xFF3A2614),
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600)),
                ),
                Positioned(
                  left: -6,
                  top: 10,
                  child: CustomPaint(
                      size: const Size(8, 12), painter: _TailPainter()),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// 마을 사람 얼굴 (금테 원)
class NpcFace extends StatelessWidget {
  const NpcFace({super.key, required this.npc, this.size = 58});

  final Npc npc;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.abyss,
          border: Border.all(color: AppColors.goldBright, width: 2),
          boxShadow: [
            BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 8),
          ],
        ),
        child: ClipOval(
          child: Image.asset(VillageRules.npc(npc).asset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                  color: AppColors.goldBright)),
        ),
      );
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFF3E7CC));
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height / 2),
        Paint()..color = const Color(0xFFB08A4A));
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height),
        Paint()..color = const Color(0xFFB08A4A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
