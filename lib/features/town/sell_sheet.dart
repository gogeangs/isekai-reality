import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../smithy/equipment_view.dart';
import 'bag_tab.dart';

/// 잡화상에서 가방 물건 팔기 (11-11 #48). 입은 장비는 팔 수 없다.
Future<void> showSellSheet(BuildContext context, AppController c) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SellSheet(controller: c),
    );

/// 하나의 판매 값
int sellPrice(BagEntry e) => switch (e) {
      MaterialEntry(:final id) => BagRules.materialPrice(id),
      ItemEntry(:final item) => BagRules.itemPrice(item),
      EquipEntry(:final item) => BagRules.equipPrice(item),
      EggEntry() || PotionEntry() => 0,
    };

class SellSheet extends StatelessWidget {
  const SellSheet({super.key, required this.controller});

  final AppController controller;

  Future<void> _sell(BuildContext context, BagEntry e, int n) async {
    final c = controller;
    final ok = switch (e) {
      MaterialEntry(:final id) => await c.sellMaterial(id, n),
      ItemEntry(:final item) => await c.sellItem(item, n),
      EquipEntry(:final item) => await c.sellEquip(item.uid),
      EggEntry() || PotionEntry() => false,
    };
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '${bagEntryName(e)} $n개를 팔았어요. 금화 +${comma(n * sellPrice(e))}'
          : '팔지 못했어요.'),
    ));
  }

  Future<void> _confirmEquip(BuildContext context, EquipEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('장비 팔기'),
        content: KText('${josa(e.item.name, '을/를')} 금화 '
            '${comma(BagRules.equipPrice(e.item))}에 팔까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('그만둘래요')),
          TextButton(
              onPressed: () => Navigator.pop(d, true), child: const Text('팔기')),
        ],
      ),
    );
    if (ok == true && context.mounted) await _sell(context, e, 1);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final entries = [
          for (final e in bagEntries(controller))
            if (e is! EggEntry && e is! PotionEntry) e,
        ];
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('가방 물건 팔기', style: AppText.title(20)),
                  const SizedBox(height: 2),
                  const KText('입고 있는 장비는 팔 수 없어요.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  if (entries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: KText('팔 물건이 없어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(children: [
                              SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: BagSlot(
                                      entry: e, controller: controller)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    switch (e) {
                                      EquipEntry(:final item) => EquipName(item),
                                      _ => Text(bagEntryName(e, controller),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.title(15,
                                              color: AppColors.text)),
                                    },
                                    Text(
                                        '1개 금화 ${comma(sellPrice(e))}',
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              ...switch (e) {
                                EquipEntry() => [
                                    SizedBox(
                                      width: 92,
                                      child: GoldButton(
                                        label: '팔기',
                                        height: 36,
                                        fontSize: 14,
                                        onPressed: () =>
                                            _confirmEquip(context, e),
                                      ),
                                    ),
                                  ],
                                MaterialEntry(:final count) ||
                                ItemEntry(:final count) =>
                                  [
                                    SizedBox(
                                      width: 84,
                                      child: GoldButton(
                                        label: '1개',
                                        height: 36,
                                        fontSize: 14,
                                        onPressed: () => _sell(context, e, 1),
                                      ),
                                    ),
                                    if (count > 1) ...[
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        width: 92,
                                        child: GoldButton(
                                          label: '$count개',
                                          height: 36,
                                          fontSize: 14,
                                          onPressed: () =>
                                              _sell(context, e, count),
                                        ),
                                      ),
                                    ],
                                  ],
                                EggEntry() || PotionEntry() => const <Widget>[],
                              },
                            ]),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
