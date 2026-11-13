import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../core/format.dart';
import '../../theme/top_notice.dart';
import '../bulssi/bulssi_bubble.dart';
import '../town/inn_screen.dart';
import '../town/shop_screen.dart';
import '../smithy/smithy_screen.dart';
import '../alchemy/alchemy_screen.dart';
import 'board_screen.dart';

/// 마을 시설
enum Facility { inn, shop, board, smithy, alchemy, market }

class FacilityInfo {
  const FacilityInfo(this.facility, this.name, this.icon,
      {this.open = true, this.inArt = true});

  /// 마을 그림에 건물이 그려져 있는지 (없으면 그림 위에 아이콘을 놓는다)
  final bool inArt;

  final Facility facility;
  final String name;

  /// assets/images/<icon>.png
  final String icon;

  /// false 면 '곧 열려요'
  final bool open;
}

/// 하단 메뉴 '마을' 탭 (11-10 #26): 어디서든 들어갈 수 있는 게임 속 마을 하나.
/// 위에는 마을 그림(건물을 누르면 들어감), 아래에는 같은 시설 카드 목록.
/// 마을 그림(village.jpg)이 없으면 하늘 그림 위에 건물 아이콘을 놓는다.
class VillageScreen extends StatelessWidget {
  const VillageScreen({super.key, required this.controller});

  final AppController controller;

  static const facilities = [
    FacilityInfo(Facility.inn, '여관', 'map_inn'),
    FacilityInfo(Facility.shop, '잡화상', 'map_store'),
    FacilityInfo(Facility.board, '의뢰 게시판', 'icon_board'),
    FacilityInfo(Facility.smithy, '대장간', 'icon_smithy'),
    FacilityInfo(Facility.alchemy, '연금술 공방', 'icon_alchemy'),
    // 묶음 15 #113: 우체국은 빼고 우편은 위쪽 우편함 아이콘으로만
    FacilityInfo(Facility.market, '거래소', 'icon_lock', open: false),
  ];

  /// 레벨이 모자라 잠긴 시설이면 그 레벨 (묶음 16 #141 #142)
  int? _lockLevel(Facility f) => switch (f) {
        Facility.smithy when !controller.featureOpen(Feature.smithy) =>
          AppController.featureLevel[Feature.smithy],
        Facility.board when !controller.featureOpen(Feature.board) =>
          AppController.featureLevel[Feature.board],
        _ => null,
      };

  /// 지금 보여 줄 시설. 묶음 20 #157: 새로 시작한 사람은 아직 못 쓰는 곳(레벨로
  /// 잠긴 곳·준비 중인 거래소)을 아예 숨긴다. 그림 속 건물은 배경으로만.
  /// 기존 사용자는 예전처럼 자물쇠로 보인다.
  List<FacilityInfo> get _shown => [
        for (final f in facilities)
          if (!controller.newGates)
            _lockLevel(f.facility) == null
                ? f
                : FacilityInfo(f.facility, f.name, f.icon,
                    open: false, inArt: f.inArt)
          else if (_lockLevel(f.facility) == null && f.open)
            f,
      ];

  /// 정령 인사: 열린 시설만 말한다
  String get _greeting {
    if (!controller.featureOpen(Feature.board)) {
      return '어서 와! 마을에서 쉬고, 물건을 살 수 있어.';
    }
    return '어서 와! 마을에서 쉬고, 사고, 의뢰를 받을 수 있어.';
  }

  void _enter(BuildContext context, FacilityInfo f) {
    final lv = _lockLevel(f.facility);
    if (lv != null) {
      showTopNotice(context, '${josa(f.name, '은/는')} Lv.$lv에 열려요',
          icon: Icons.lock_outline_rounded);
      return;
    }
    if (!f.open) {
      // 묶음 16 #137: 잠긴 곳을 누르면 위쪽 띠로 「곧 열려요」
      showTopNotice(context, '${josa(f.name, '은/는')} 곧 열려요',
          icon: Icons.lock_outline_rounded);
      return;
    }
    final Widget page = switch (f.facility) {
      Facility.inn => InnScreen(controller: controller),
      Facility.shop => ShopScreen(controller: controller),
      Facility.smithy => SmithyScreen(controller: controller),
      Facility.alchemy => AlchemyScreen(controller: controller),
      _ => BoardScreen(controller: controller),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    // 묶음 15 #115: 위쪽(제목·대사)은 고정하고 아래만 스크롤 → 마을 그림이
    // 위쪽 우편함·설정 버튼 밑으로 올라가 이름표가 가려지지 않게
    return Padding(
      padding: EdgeInsets.fromLTRB(14, top + 6, 14, 0),
      child: Column(children: [
        const OrnateTopBar(title: '마을'),
        const SizedBox(height: 6),
        BulssiLine(key: const Key('villageGreeting'), line: _greeting),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _VillageArt(list: _shown, onTap: (f) => _enter(context, f)),
              const SizedBox(height: 12),
              for (final f in _shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FacilityCard(
                      key: Key('facility_${f.facility.name}'),
                      info: f, onTap: () => _enter(context, f)),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

/// 마을 그림(village.jpg): 건물을 누르면 시설로. 그림이 없으면 하늘 띠 위에
/// 건물 아이콘을 같은 자리에 놓는다.
class _VillageArt extends StatelessWidget {
  const _VillageArt({required this.list, required this.onTap});

  final List<FacilityInfo> list;
  final ValueChanged<FacilityInfo> onTap;

  // 건물이 차지하는 칸 (그림 안 비율: 왼쪽, 위, 너비, 높이). village.jpg 기준
  static const areas = {
    Facility.smithy: Rect.fromLTWH(0.10, 0.08, 0.30, 0.30),
    Facility.inn: Rect.fromLTWH(0.00, 0.36, 0.30, 0.33),
    Facility.shop: Rect.fromLTWH(0.35, 0.45, 0.36, 0.44),
    Facility.board: Rect.fromLTWH(0.75, 0.47, 0.22, 0.24),
    Facility.alchemy: Rect.fromLTWH(0.44, 0.22, 0.23, 0.18),
    Facility.market: Rect.fromLTWH(0.70, 0.24, 0.24, 0.19),
  };

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          Rect at(Facility f) {
            final r = areas[f]!;
            return Rect.fromLTWH(r.left * w, r.top * h, r.width * w, r.height * h);
          }

          return Stack(fit: StackFit.expand, children: [
            Image.asset('assets/images/village.webp',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Stack(fit: StackFit.expand, children: [
                      Image.asset('assets/images/bg_header.webp',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const ColoredBox(color: Color(0xFF1A1D4A))),
                      for (final f in list)
                        Positioned.fromRect(
                          rect: at(f.facility),
                          child: Center(
                            child: Opacity(
                              opacity: f.open ? 1 : 0.55,
                              child: _BuildingIcon(
                                  icon: f.icon, size: f.open ? 50 : 36),
                            ),
                          ),
                        ),
                    ])),
            // 아래쪽 이름표가 잘 보이게 살짝 어둡게
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x000B0D26), Color(0x550B0D26)],
                  ),
                ),
              ),
            ),
            for (final f in list)
              Positioned.fromRect(
                rect: at(f.facility),
                child: Semantics(
                  button: true,
                  label: f.name,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(f),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _NameTag(name: f.name, open: f.open),
                      ),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

class _NameTag extends StatelessWidget {
  const _NameTag({required this.name, required this.open});

  final String name;
  final bool open;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xD90B0D26),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: AppColors.gold.withValues(alpha: open ? 0.8 : 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!open) ...[
            const Icon(Icons.lock_outline_rounded,
                size: 11, color: AppColors.textMuted),
            const SizedBox(width: 2),
          ],
          Text(name,
              style: TextStyle(
                  color: open ? AppColors.text : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _BuildingIcon extends StatelessWidget {
  const _BuildingIcon({required this.icon, required this.size});

  final String icon;
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/$icon.webp',
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(
          switch (icon) {
            'icon_smithy' => Icons.hardware_rounded,
            'icon_board' => Icons.assignment_rounded,
            'icon_alchemy' => Icons.science_rounded,
            'icon_post' => Icons.markunread_mailbox_rounded,
            _ => Icons.lock_outline_rounded,
          },
          size: size * 0.6,
          color: AppColors.goldBright,
        ),
      );
}

class _FacilityCard extends StatelessWidget {
  const _FacilityCard({super.key, required this.info, required this.onTap});

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
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: info.open ? 0.7 : 0.3)),
          ),
          child: Row(children: [
            _BuildingIcon(icon: info.icon, size: 42),
            const SizedBox(width: 10),
            // 묶음 15 #112: 아이콘 · 이름 · > 만 (설명글 없음)
            Expanded(
              child: Text(info.name,
                  style: AppText.title(16, color: AppColors.text)),
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
