import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../data/storage/record_store.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart';
import 'bag_sheet.dart';

/// 잡화상 (앱 안 시설): 몬스터를 정화하고 모은 정화 결정으로 편의 물건을 산다.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.controller});

  final AppController controller;

  static String reason(PurchaseCheck check, ShopItemInfo info, int crystals) =>
      switch (check) {
        PurchaseCheck.ok => '',
        PurchaseCheck.limitReached => info.limit == ShopLimit.perDay
            ? '오늘 샀어요'
            : '이번 주 샀어요',
        PurchaseCheck.notEnoughCrystals =>
          '결정 ${info.price - crystals}개 부족',
        PurchaseCheck.needsLocation => '위치를 켜 주세요',
        PurchaseCheck.levelTooLow => 'Lv.${info.minLevel}부터',
        PurchaseCheck.bagFull => '가방에 ${TownRules.bagMax}개 있어요',
      };

  static String boughtLine(ShopItem item) => switch (item) {
        ShopItem.spareKey => '여분의 열쇠를 샀어요. 던전 열쇠가 하나 늘었어요!',
        ShopItem.bulssiPotion => '정령 물약을 가방에 넣었어요. 던전 가기 전에 마셔요!',
        ShopItem.magicLens => '마법 돋보기로 주변 안개를 걷었어요. 지도를 확인해 보세요!',
        ShopItem.healSmall ||
        ShopItem.heal ||
        ShopItem.manaSmall ||
        ShopItem.mana =>
          '가방에 넣었어요. 필요할 때 가방에서 마셔요!',
      };

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final history = controller.history;
            final crystals = controller.player.crystals;
            final hasLocation = controller.lastFix != null;
            final level = controller.player.level.level;

            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                  title: '잡화상',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Image.asset('assets/images/map_store.png',
                      height: 110,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                const SizedBox(height: 8),
                OrnatePanel(
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GameIcon('crystal', size: 34),
                        const SizedBox(width: 8),
                        Text('정화 결정 $crystals개',
                            style: AppText.title(22,
                                color: AppColors.goldBright)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'HP ${comma(controller.hp)} / ${comma(controller.maxHp)} · '
                      '정령 MP ${controller.mp} / ${RuleConstants.mpMax}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '던전 정화 3개 · 던전 실패 1개 · 필드 몬스터 1개',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                FrameButton(
                  onPressed: () => showBagSheet(context, controller),
                  icon: Icons.backpack_rounded,
                  height: 44,
                  label: '가방 열기',
                ),
                const SizedBox(height: 12),
                for (final info in TownRules.items) ...[
                  _ItemCard(
                    info: info,
                    check: TownRules.canBuy(history, info.item,
                        hasLocation: hasLocation,
                        level: level),
                    crystals: crystals,
                    spiritKind: controller.profile.spiritKind,
                    onBuy: () async {
                      final result = await controller.buy(info.item);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result == PurchaseCheck.ok
                            ? boughtLine(info.item)
                            : reason(result, info, controller.player.crystals)),
                      ));
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                const BulssiBubble(
                    line: '몬스터를 정화하면 결정이 남아. 모아서 필요한 걸 사자!'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.info,
    required this.check,
    required this.crystals,
    required this.onBuy,
    this.spiritKind = SpiritKind.fire,
  });

  final ShopItemInfo info;
  final PurchaseCheck check;
  final int crystals;
  final VoidCallback onBuy;
  final SpiritKind spiritKind;

  @override
  Widget build(BuildContext context) {
    final ok = check == PurchaseCheck.ok;
    return OrnatePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
              info.item == ShopItem.bulssiPotion
                  ? spiritPotionAsset(spiritKind)
                  : 'assets/images/${info.icon}.png',
              width: 48,
              height: 48,
              errorBuilder: (_, __, ___) => const GameIcon('crystal', size: 48)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(18, color: AppColors.text)),
                const SizedBox(height: 3),
                Text(info.description,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 13, height: 1.35)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.6)),
                    ),
                    child: Text(info.limitLabel,
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 10)),
                  ),
                  if (!ok) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(ShopScreen.reason(check, info, crystals),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 106,
            child: GoldButton(
              label: '${info.price}개',
              height: 46,
              fontSize: 16,
              onPressed: ok ? onBuy : null,
            ),
          ),
        ],
      ),
    );
  }
}
