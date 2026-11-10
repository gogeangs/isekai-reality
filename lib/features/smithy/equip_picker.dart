import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/armory.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'equipment_view.dart';

/// 상태 화면 장비 칸을 눌렀을 때: 그 부위 장비 목록에서 바로 입고 벗는다 (11-11 #44)
Future<void> showEquipPicker(
    BuildContext context, AppController c, EquipSlot slot) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.night,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final a = c.armory;
          final worn = a.wornIn(slot);
          final items = [
            for (final i in a.items)
              if (i.slot == slot) i,
          ];
          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(slotIcon(slot), color: AppColors.goldBright),
                  const SizedBox(width: 6),
                  Text(EquipmentRules.slotLabel(slot), style: AppText.title(20)),
                ]),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: KText('이 부위 장비가 없어요. 마을 대장간에서 만들 수 있어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.5),
                  child: ListView(shrinkWrap: true, children: [
                    for (final item in items)
                      _PickRow(
                        item: item,
                        worn: worn?.uid == item.uid,
                        onPressed: () => worn?.uid == item.uid
                            ? c.unequip(slot)
                            : c.equip(item.uid),
                      ),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _PickRow extends StatelessWidget {
  const _PickRow(
      {required this.item, required this.worn, required this.onPressed});

  final EquipItem item;
  final bool worn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          EquipIcon(base: item.base, grade: item.grade, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: EquipName(item)),
                  if (worn) ...[
                    const SizedBox(width: 6),
                    const Text('입는 중',
                        style: TextStyle(
                            color: AppColors.goldBright, fontSize: 11)),
                  ],
                ]),
                KText(EquipmentRules.itemStatLabel(item),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5)),
                DurabilityBar(value: item.durability),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 84,
            child: worn
                ? FrameButton(label: '벗기', height: 38, onPressed: onPressed)
                : GoldButton(
                    label: '입기', height: 38, fontSize: 14, onPressed: onPressed),
          ),
        ]),
      );
}
