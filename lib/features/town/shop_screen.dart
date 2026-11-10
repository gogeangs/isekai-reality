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
import 'material_view.dart';
import 'sell_sheet.dart';

/// 잡화상 (앱 안 시설): 몬스터가 떨어뜨린 마석을 금화로 팔고, 금화로 물건을 산다.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.controller});

  final AppController controller;

  static String reason(PurchaseCheck check, ShopItemInfo info, int gold) =>
      switch (check) {
        PurchaseCheck.ok => '',
        PurchaseCheck.limitReached => info.limit == ShopLimit.perDay
            ? '오늘 샀어요'
            : '이번 주 샀어요',
        PurchaseCheck.notEnoughCrystals => '금화 ${info.price - gold} 부족',
        PurchaseCheck.needsLocation => '위치를 켜 주세요',
        PurchaseCheck.levelTooLow => 'Lv.${info.minLevel}부터',
        PurchaseCheck.bagFull => '가방이 가득 찼어요',
      };

  static String boughtLine(ShopItem item) => switch (item) {
        ShopItem.spareKey => '여분의 열쇠를 샀어요. 던전 열쇠가 하나 늘었어요!',
        ShopItem.bulssiPotion => '정령 물약을 가방에 넣었어요. 던전 가기 전에 마셔요!',
        ShopItem.magicLens => '마법 돋보기는 더 이상 팔지 않아요.',
        ShopItem.expeditionCompass =>
          '원정 나침반을 가방에 넣었어요. 정령을 보내기 전에 써요!',
        ShopItem.purifyIncense =>
          '성장의 향을 가방에 넣었어요. 몬스터를 잡으러 가는 날 피워요!',
        ShopItem.ironShard ||
        ShopItem.twig ||
        ShopItem.herb =>
          '${josa(TownRules.info(item).name, '을/를')} 재료 주머니에 넣었어요.',
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
            final player = controller.player;
            final gold = player.gold;
            final hasLocation = controller.lastFix != null;

            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                  title: '잡화상',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 6),
                const BulssiLine(
                    line: '몬스터를 잡으면 마석이 나와. 팔아서 금화로 필요한 걸 사자!'),
                const SizedBox(height: 4),
                Center(
                  child: Image.asset('assets/images/map_store.png',
                      height: 110,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                const SizedBox(height: 8),
                OrnatePanel(
                  child: Column(children: [
                    WalletRow(manaStones: player.manaStones, gold: gold),
                    const SizedBox(height: 4),
                    Text(
                      'HP ${comma(controller.hp)} / ${comma(controller.maxHp)} · '
                      '정령 MP ${controller.mp} / ${controller.mpMax}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 13),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                _SellPanel(controller: controller, manaStones: player.manaStones),
                const SizedBox(height: 10),
                FrameButton(
                  onPressed: () => showBagSheet(context, controller),
                  gameIcon: 'bag',
                  height: 44,
                  label: '가방 열기',
                ),
                const SizedBox(height: 8),
                FrameButton(
                  onPressed: () => showSellSheet(context, controller),
                  gameIcon: 'gold',
                  height: 44,
                  label: '재료·물건·장비 팔기',
                ),
                const SizedBox(height: 12),
                for (final info in TownRules.items) ...[
                  _ItemCard(
                    info: info,
                    check: controller.canBuy(info.item,
                        hasLocation: hasLocation),
                    gold: gold,
                    spiritKind: controller.profile.spiritKind,
                    onBuy: () async {
                      final result = await controller.buy(info.item);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(result == PurchaseCheck.ok
                            ? boughtLine(info.item)
                            : reason(result, info, controller.player.gold)),
                      ));
                    },
                  ),
                  const SizedBox(height: 10),
                ],
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
    required this.gold,
    required this.onBuy,
    this.spiritKind = SpiritKind.fire,
  });

  final ShopItemInfo info;
  final PurchaseCheck check;
  final int gold;
  final VoidCallback onBuy;
  final SpiritKind spiritKind;

  @override
  Widget build(BuildContext context) {
    final ok = check == PurchaseCheck.ok;
    return OrnatePanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (info.material case final mat?)
            MaterialIcon(mat, size: 48)
          else
            Image.asset(
                info.item == ShopItem.bulssiPotion
                    ? spiritPotionAsset(spiritKind)
                    : 'assets/images/${info.icon}.png',
                width: 48,
                height: 48,
                errorBuilder: (_, __, ___) => const GameIcon('gold', size: 48)),
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
                      child: Text(ShopScreen.reason(check, info, gold),
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
          const SizedBox(width: 6),
          Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 96,
              child: GoldButton(
                label: '${info.price}',
                height: 44,
                fontSize: 17,
                onPressed: ok ? onBuy : null,
              ),
            ),
            const SizedBox(height: 2),
            const Row(mainAxisSize: MainAxisSize.min, children: [
              GameIcon('gold', size: 14, fallback: Icons.monetization_on_rounded),
              SizedBox(width: 2),
              Text('금화',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ]),
          ]),
        ],
      ),
    );
  }
}

/// 마석 팔기 (1개 = 금화 10)
class _SellPanel extends StatelessWidget {
  const _SellPanel({required this.controller, required this.manaStones});

  final AppController controller;
  final int manaStones;

  Future<void> _sell(BuildContext context, int n) async {
    final ok = await controller.sellManaStones(n);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '마석 $n개를 팔았어요. 금화 +${n * RuleConstants.goldPerManaStone}'
          : '마석이 모자라요.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const GameIcon('mana_stone',
                size: 36, fallback: Icons.diamond_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('마석 팔기',
                      style: AppText.title(17, color: AppColors.text)),
                  const KText(
                      '1개에 금화 ${RuleConstants.goldPerManaStone}. '
                      '대장간에서도 쓰니 조금 남겨 두세요.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: GoldButton(
                label: '1개 팔기',
                height: 40,
                fontSize: 14,
                onPressed: manaStones >= 1 ? () => _sell(context, 1) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GoldButton(
                label: '5개 팔기',
                height: 40,
                fontSize: 14,
                onPressed: manaStones >= 5 ? () => _sell(context, 5) : null,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
