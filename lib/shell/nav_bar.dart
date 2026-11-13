part of '../app.dart';

/// 상태창에 보여 줄 원정 한 줄 (원정 중이 아니면 null)
String? _spiritAway(AppController c) {
  final ex = c.expedition;
  if (ex == null || ex.finished) return null;
  final left = ex.returnAt.difference(c.now);
  final m = left.inMinutes < 1 ? 1 : left.inMinutes;
  return '${c.companionName} 원정 중 · $m분 뒤 돌아와요';
}

/// 하단 메뉴: 금테 막대, 고른 메뉴는 금색 상자 (목업 구도)
class OrnateNavBar extends StatelessWidget {
  const OrnateNavBar(
      {super.key,
      required this.index,
      required this.onTap,
      this.dots = const {},
      this.dimmed = const {}});

  final int index;
  final ValueChanged<int> onTap;

  /// 빨간 점을 찍을 메뉴 (묶음 16 #130)
  final Set<int> dots;

  /// 튜토리얼 동안 흐리게 막아 둔 메뉴 (묶음 16 #125)
  final Set<int> dimmed;

  /// 가운데 지도 메뉴 자리
  static const mapIndex = 2;

  /// (그림, 이름). 마을·가방 전용 메뉴 그림(nav_village, nav_bag)이 오기 전에는
  /// 여관·가방 아이콘으로 대신한다.
  static const items = [
    ('nav_status', '상태'),
    ('nav_bag', '가방'),
    ('nav_map', '지도'),
    ('nav_village', '마을'),
    ('nav_codex', '도감'),
  ];

  static const _fallback = {
    'nav_village': 'map_inn',
    'nav_bag': 'icon_bag',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.deepNight,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: OrnatePanel(
            art: false,
            padding: const EdgeInsets.all(4),
            radius: 18,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    // 가운데 지도는 조금 넓고 그림도 조금 크게
                    flex: i == mapIndex ? 6 : 5,
                    child: KeyedSubtree(
                     key: tutorialNavKeys[i],
                     child: Semantics(
                      selected: i == index,
                      button: true,
                      child: Opacity(
                       opacity: dimmed.contains(i) ? 0.3 : 1,
                       child: InkWell(
                        key: Key('nav_$i'),
                        onTap: dimmed.contains(i) ? null : () => onTap(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: i == mapIndex ? 58 : 54,
                          decoration: i == index
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFB98330),
                                      Color(0xFF6E4B1A)
                                    ],
                                  ),
                                  border: Border.all(
                                      color: AppColors.goldBright, width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.45),
                                        blurRadius: 10),
                                  ],
                                )
                              : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(clipBehavior: Clip.none, children: [
                                Opacity(
                                  opacity: i == index || i == mapIndex ? 1 : 0.7,
                                  child: Image.asset(
                                      'assets/images/${items[i].$1}.webp',
                                      width: i == mapIndex ? 36 : 30,
                                      height: i == mapIndex ? 36 : 30,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                          'assets/images/${_fallback[items[i].$1] ?? 'icon_quest'}.webp',
                                          width: 30,
                                          height: 30,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.circle_outlined,
                                                  color: AppColors.text))),
                                ),
                                if (dots.contains(i))
                                  Positioned(
                                    key: Key('navDot_$i'),
                                    right: -3,
                                    top: -2,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE53935),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 1.2),
                                      ),
                                    ),
                                  ),
                              ]),
                              const SizedBox(height: 2),
                              Text(items[i].$2,
                                  style: TextStyle(
                                    color: i == index
                                        ? AppColors.goldBright
                                        : AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: i == index
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                       ),
                      ),
                     ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

