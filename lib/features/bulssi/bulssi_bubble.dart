import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../data/storage/record_store.dart';
import 'bulssi_mood.dart';
import 'spirit_art.dart';

/// 정령 그림 + 말풍선 (팝업처럼 따로 뜨는 곳에서만).
/// 화면에서는 [BulssiLine](제목 아래 한 줄) 이나 [ArtSpirit](그림 안) 을 쓴다.
/// 정령 종류·이름·빛 색(속성 + 날씨·시간)은 [BulssiScope] 에서 받는다.
class BulssiBubble extends StatelessWidget {
  const BulssiBubble({super.key, required this.line, this.size = 64});

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
                TextSpan(text: keepAll(line)),
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

/// 정령 둘레의 은은한 빛
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.child, this.spread = 0.3});

  final Color color;
  final Widget child;
  final double spread;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Transform.scale(
              scale: 1 + spread * 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      color.withValues(alpha: 0.38),
                      color.withValues(alpha: 0.1),
                      color.withValues(alpha: 0),
                    ], stops: const [0, 0.45, 1]),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      );
}

/// 그림이 없는 화면: 제목 바로 아래 고정 자리의 정령 아이콘 + 한 줄 대사 (11-10 A3)
class BulssiLine extends StatelessWidget {
  const BulssiLine({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) {
    final scope = BulssiScope.maybeOf(context);
    final kind = scope?.kind ?? SpiritKind.fire;
    final glow = scope?.glow ?? spiritColor(kind);
    final name = scope?.spiritName ?? kind.defaultName;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
      decoration: BoxDecoration(
        color: const Color(0xCC12153A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
      ),
      child: Row(children: [
        _Glow(color: glow, child: SpiritArt(kind: kind, size: 38, name: name)),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '$name  ',
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 12,
                    fontWeight: FontWeight.w800),
              ),
              TextSpan(text: keepAll(line)),
            ]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

/// 위쪽 그림이 있는 화면: 그림 속 각성자 오른쪽 빈자리에 떠 있는 작은 정령과
/// 각성자 쪽(왼쪽 아래)을 향한 말풍선 (11-10 A3)
class ArtSpirit extends StatelessWidget {
  const ArtSpirit({super.key, required this.line, this.size = 50});

  final String line;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scope = BulssiScope.maybeOf(context);
    final kind = scope?.kind ?? SpiritKind.fire;
    final glow = scope?.glow ?? spiritColor(kind);
    final name = scope?.spiritName ?? kind.defaultName;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SpeechBubbleArt(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '$name\n',
                style: const TextStyle(
                    color: Color(0xFF8A5A12),
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              ),
              TextSpan(text: keepAll(line)),
            ]),
            style: const TextStyle(
                color: AppColors.night,
                fontSize: 13.5,
                height: 1.3,
                fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: _Glow(
              color: glow,
              spread: 0.4,
              child: SpiritArt(kind: kind, size: size, name: name)),
        ),
      ],
    );
  }
}
