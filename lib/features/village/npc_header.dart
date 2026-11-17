import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'building_upgrade.dart';
import 'npc_request.dart';

/// 시설 맨 위 마을 사람 (묶음 35): 금테 얼굴 + 이름·역할 + 한마디 말풍선.
/// 처음 만날 때 한 줄(한 번), 그 뒤엔 그 막의 평소 대사 두 줄을 번갈아.
/// 한마디는 화면을 열 때 한 번 정한다 (다시 그려도 바뀌지 않음).
/// 묶음 38 #213: 시설 안 정령 띠 대신 마을 사람이 안내한다 — 처음 만날 때 첫 줄 →
/// 상황 안내([situation]) → 그 밖엔 막 대사와 기본 안내([guide])를 번갈아.
/// 탭을 바꾸면 그 탭 안내([tabLine])로 바뀐다
class NpcHeader extends StatefulWidget {
  const NpcHeader({
    super.key,
    required this.controller,
    required this.npc,
    this.guide,
    this.situation,
    this.tabLine,
  });

  final AppController controller;
  final Npc npc;
  final String? guide;
  final String? situation;
  final String? tabLine;

  @override
  State<NpcHeader> createState() => _NpcHeaderState();
}

class _NpcHeaderState extends State<NpcHeader> {
  late String _line = widget.controller.takeNpcLine(widget.npc,
      guide: widget.guide, situation: widget.situation);

  @override
  void didUpdateWidget(NpcHeader old) {
    super.didUpdateWidget(old);
    // 화면에 있는 동안 상황이 바뀌면 (예: 체크인해서 쉬는 중) 그 안내로
    final s = widget.situation;
    if (s != null && s != old.situation) _line = s;
    if (s == null && old.situation != null && widget.guide != null) {
      _line = widget.guide!;
    }
  }

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
              // 묶음 38 #214: 뒤 배경 그림 위에서도 또렷하게 어두운 반투명 띠
              Container(
                key: Key('npcName_${widget.npc.name}'),
                padding: const EdgeInsets.fromLTRB(8, 2, 10, 3),
                decoration: BoxDecoration(
                  color: const Color(0xCC0B0D26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(info.name,
                      style: AppText.title(16, color: AppColors.goldBright)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(info.role,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFFE6DCC4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
              ),
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
                  child: KText(widget.tabLine ?? _line,
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
              // 묶음 42 #226: 부탁 듣기 · 진행 · 다 했어요
              NpcRequestBar(controller: widget.controller, npc: widget.npc),
              // 묶음 54: 건물 레벨업 (결말 뒤)
              BuildingUpgradeBar(controller: widget.controller, npc: widget.npc),
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
