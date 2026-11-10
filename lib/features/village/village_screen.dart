import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../town/inn_screen.dart';
import '../town/shop_screen.dart';
import 'board_screen.dart';

/// 마을 시설
enum Facility { inn, shop, board, smithy, alchemy, market }

class FacilityInfo {
  const FacilityInfo(this.facility, this.name, this.icon, this.subtitle,
      {this.open = true});

  final Facility facility;
  final String name;

  /// assets/images/<icon>.png
  final String icon;
  final String subtitle;

  /// false 면 '곧 열려요'
  final bool open;
}

/// 하단 메뉴 '마을' 탭 (11-10 #26): 어디서든 들어갈 수 있는 게임 속 마을 하나.
/// 위에는 마을 그림(건물을 누르면 들어감), 아래에는 같은 시설 카드 목록.
/// 마을 그림(village.png)이 오기 전에는 하늘 그림 위에 건물 아이콘을 놓는다.
class VillageScreen extends StatelessWidget {
  const VillageScreen({super.key, required this.controller});

  final AppController controller;

  static const facilities = [
    FacilityInfo(Facility.inn, '여관', 'map_inn', '쉬면 HP·MP가 가득'),
    FacilityInfo(Facility.shop, '잡화상', 'map_store', '물약과 물건'),
    FacilityInfo(Facility.board, '의뢰 게시판', 'icon_quest', '일일 의뢰'),
    FacilityInfo(Facility.smithy, '대장간', 'icon_smithy', '장비 제작·강화',
        open: false),
    FacilityInfo(Facility.alchemy, '연금술 공방', 'icon_lock', '나중에 열려요',
        open: false),
    FacilityInfo(Facility.market, '거래소', 'icon_lock', '나중에 열려요',
        open: false),
  ];

  void _enter(BuildContext context, FacilityInfo f) {
    if (!f.open) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${f.name}은(는) 곧 열려요')));
      return;
    }
    final Widget page = switch (f.facility) {
      Facility.inn => InnScreen(controller: controller),
      Facility.shop => ShopScreen(controller: controller),
      _ => BoardScreen(controller: controller),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.fromLTRB(14, top + 6, 14, 24),
      children: [
        const OrnateTopBar(title: '마을'),
        const SizedBox(height: 6),
        const BulssiLine(line: '어서 와! 마을에서 쉬고, 사고, 의뢰를 받을 수 있어.'),
        const SizedBox(height: 10),
        _VillageArt(onTap: (f) => _enter(context, f)),
        const SizedBox(height: 12),
        for (final f in facilities)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FacilityCard(info: f, onTap: () => _enter(context, f)),
          ),
      ],
    );
  }
}

/// 마을 그림: 건물을 누르면 시설로. 그림이 없으면 하늘 띠 + 건물 아이콘
class _VillageArt extends StatelessWidget {
  const _VillageArt({required this.onTap});

  final ValueChanged<FacilityInfo> onTap;

  // 건물 자리 (그림 안 비율 좌표, village.png 를 그릴 때 이 자리에 맞춘다)
  static const spots = {
    Facility.inn: Alignment(-0.62, 0.15),
    Facility.shop: Alignment(0.0, 0.35),
    Facility.board: Alignment(0.62, 0.15),
    Facility.smithy: Alignment(-0.3, -0.45),
    Facility.alchemy: Alignment(0.32, -0.5),
    Facility.market: Alignment(0.85, -0.55),
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/images/village.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset(
                  'assets/images/bg_header.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF1A1D4A)))),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x000B0D26), Color(0x990B0D26)],
              ),
            ),
          ),
          for (final f in VillageScreen.facilities)
            Align(
              alignment: spots[f.facility]!,
              child: GestureDetector(
                onTap: () => onTap(f),
                child: Opacity(
                  opacity: f.open ? 1 : 0.55,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _BuildingIcon(icon: f.icon, size: f.open ? 58 : 40),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0B0D26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(f.name,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _BuildingIcon extends StatelessWidget {
  const _BuildingIcon({required this.icon, required this.size});

  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/$icon.png',
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(
          icon == 'icon_smithy'
              ? Icons.hardware_rounded
              : Icons.lock_outline_rounded,
          size: size * 0.6,
          color: AppColors.goldBright,
        ),
      );
}

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({required this.info, required this.onTap});

  final FacilityInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: info.open ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xCC12153A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: info.open ? 0.7 : 0.3)),
          ),
          child: Row(children: [
            _BuildingIcon(icon: info.icon, size: 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.name, style: AppText.title(17, color: AppColors.text)),
                  Text(info.open ? info.subtitle : '곧 열려요',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(
                info.open
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: AppColors.gold),
          ]),
        ),
      ),
    );
  }
}
