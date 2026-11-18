import 'package:flutter/material.dart';

import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';

/// 파티 깃발 (묶음 56): 흰 깃발 그림(flag_party)에 파티 색을 입히고 가운데 문양.
/// 그림이 오기 전에는 색 깃발을 그려서 대신한다.
class PartyFlag extends StatelessWidget {
  const PartyFlag({super.key, required this.emblem, required this.color, this.size = 56, this.npc = false, this.crown = false});

  final int emblem;
  final int color;
  final double size;

  /// 묶음 60: 흑등 연맹 깃발 (검은 천 · 검은 등불 문양)
  final bool npc;

  /// 묶음 60: 왕성을 가진 길드 깃발 위 왕관 (다음 공성전까지)
  final bool crown;

  @override
  Widget build(BuildContext context) {
    final col = npc ? const Color(0xFF2A2A36) : Color(PartyRules.colors[color.clamp(0, PartyRules.colors.length - 1)]);
    return SizedBox(
      key: const Key('partyFlag'),
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(
          child: Image.asset(PartyRules.flagAsset,
              color: col,
              colorBlendMode: BlendMode.modulate,
              errorBuilder: (_, __, ___) => CustomPaint(painter: _FlagPainter(col))),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: size * 0.08, left: size * 0.06),
          child: npc
              ? Image.asset(ErbardRules.npcEmblem,
                  width: size * 0.42,
                  height: size * 0.42,
                  color: const Color(0xFF0E0E14),
                  colorBlendMode: BlendMode.srcATop,
                  errorBuilder: (_, __, ___) => Icon(Icons.light_rounded, size: size * 0.38, color: Colors.black))
              : EmblemIcon(index: emblem, size: size * 0.42, light: true),
        ),
        if (crown)
          Positioned(
            top: 0,
            right: size * 0.08,
            child: Image.asset(ErbardRules.crownMark,
                width: size * 0.4,
                height: size * 0.4,
                errorBuilder: (_, __, ___) => Icon(Icons.workspace_premium_rounded, size: size * 0.38, color: const Color(0xFFFFD54F))),
          ),
      ]),
    );
  }
}

/// 깃발 문양 그림 (없으면 아이콘)
class EmblemIcon extends StatelessWidget {
  const EmblemIcon({super.key, required this.index, this.size = 28, this.light = false});

  final int index;
  final double size;
  final bool light;

  static const _icons = [
    Icons.shield_rounded,
    Icons.pets_rounded,
    Icons.light_rounded,
    Icons.castle_rounded,
    Icons.eco_rounded,
    Icons.star_rounded,
    Icons.dark_mode_rounded,
    Icons.air_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final i = index.clamp(0, PartyRules.emblems.length - 1);
    return Image.asset(PartyRules.emblemAsset(i),
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(_icons[i],
            size: size * 0.9, color: light ? const Color(0xFFFFF6DC) : AppColors.goldBright));
  }
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final pole = Paint()..color = const Color(0xFF8A6A3A);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(s.width * 0.1, s.height * 0.05, s.width * 0.06, s.height * 0.92),
            const Radius.circular(2)),
        pole);
    final path = Path()
      ..moveTo(s.width * 0.16, s.height * 0.1)
      ..lineTo(s.width * 0.95, s.height * 0.1)
      ..lineTo(s.width * 0.82, s.height * 0.42)
      ..lineTo(s.width * 0.95, s.height * 0.74)
      ..lineTo(s.width * 0.16, s.height * 0.74)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFE8C46A));
  }

  @override
  bool shouldRepaint(_FlagPainter old) => old.color != color;
}
