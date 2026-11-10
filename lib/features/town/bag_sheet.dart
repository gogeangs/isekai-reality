import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/spirit_art.dart';

/// 가방 안 물건 그림
String bagIconAsset(AppController c, ShopItem item) =>
    item == ShopItem.bulssiPotion
        ? spiritPotionAsset(c.profile.spiritKind)
        : 'assets/images/${TownRules.info(item).icon}.png';

String useReason(UseCheck c) => switch (c) {
      UseCheck.ok => '',
      UseCheck.none => '가방에 없어요',
      UseCheck.alreadyFull => '이미 가득해요',
      UseCheck.alreadyActive => '이미 효과가 있어요',
    };

/// 가방 버튼 글자: 물약은 마시기, 나침반은 쓰기, 향은 피우기
String useLabel(ShopItem item) => switch (item) {
      ShopItem.expeditionCompass => '쓰기',
      ShopItem.purifyIncense => '피우기',
      _ => '마시기',
    };

/// 가방 열기 (상태창·던전 입구·잡화상)
Future<void> showBagSheet(BuildContext context, AppController c) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.night,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BagSheet(controller: c),
  );
}

class BagSheet extends StatelessWidget {
  const BagSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
        child: BagContents(controller: controller),
      ),
    );
  }
}

/// 가방 안 물건 목록 (가방 창과 가방 탭이 같이 쓴다)
class BagContents extends StatelessWidget {
  const BagContents({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final owned = [
          for (final i in TownRules.bagItems)
            if (c.bagCount(i) > 0) i,
        ];
        return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  const GameIcon('bag', size: 30),
                  const SizedBox(width: 6),
                  Text('가방', style: AppText.title(20)),
                ]),
                const SizedBox(height: 4),
                Text(
                  'HP ${comma(c.hp)} / ${comma(c.maxHp)} · '
                  '정령 MP ${c.mp} / ${RuleConstants.mpMax}',
                  style: const TextStyle(color: AppColors.text, fontSize: 13),
                ),
                const SizedBox(height: 10),
                if (owned.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Text('가방이 비어 있어요. 잡화상에서 물약과 물건을 살 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                for (final item in owned) _BagRow(controller: c, item: item),
              ],
            );
      },
    );
  }
}

class _BagRow extends StatelessWidget {
  const _BagRow({required this.controller, required this.item});

  final AppController controller;
  final ShopItem item;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = TownRules.info(item);
    final check = c.canUse(item);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Image.asset(bagIconAsset(c, item),
            width: 44,
            height: 44,
            errorBuilder: (_, __, ___) => const GameIcon('crystal', size: 44)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${info.name} × ${c.bagCount(item)}',
                  style: AppText.title(16, color: AppColors.text)),
              if (check != UseCheck.ok)
                Text(useReason(check),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(
          width: 118,
          child: GoldButton(
            label: useLabel(item),
            height: 40,
            fontSize: 15,
            onPressed: check == UseCheck.ok
                ? () async {
                    await c.useItem(item);
                  }
                : null,
          ),
        ),
      ]),
    );
  }
}
