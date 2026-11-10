import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../core/models/armory.dart';
import '../smithy/equipment_view.dart';
import 'bag_sheet.dart';
import 'material_view.dart';

/// 하단 메뉴 '가방' 탭 (11-10 #25).
/// 마석·금화, 장비 6칸(입고 벗기), 물약·물건(마시고 쓰기), 재료.
class BagTab extends StatelessWidget {
  const BagTab({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final p = controller.player;
        return ListView(
          padding: EdgeInsets.fromLTRB(14, top + 6, 14, 24),
          children: [
            const OrnateTopBar(title: '가방'),
            const SizedBox(height: 10),
            OrnatePanel(
              child: WalletRow(manaStones: p.manaStones, gold: p.gold),
            ),
            const SizedBox(height: 12),
            _GearPanel(controller: controller),
            const SizedBox(height: 12),
            OrnatePanel(child: BagContents(controller: controller)),
            const SizedBox(height: 12),
            OrnatePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.inventory_2_rounded,
                        color: AppColors.goldBright, size: 24),
                    const SizedBox(width: 6),
                    Text('재료', style: AppText.title(20)),
                  ]),
                  const SizedBox(height: 8),
                  MaterialGrid(materials: p.materials),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 장비: 입은 6칸 + 가진 장비 (입기·벗기)
class _GearPanel extends StatelessWidget {
  const _GearPanel({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final a = c.armory;
    final spare = [for (final i in a.items) if (!a.isWorn(i)) i];
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.shield_rounded, color: AppColors.goldBright, size: 24),
            const SizedBox(width: 6),
            Text('장비', style: AppText.title(20)),
          ]),
          const SizedBox(height: 2),
          Text(gearSummary(c.gear),
              style: const TextStyle(color: AppColors.text, fontSize: 13)),
          const SizedBox(height: 8),
          EquipGrid(
            armory: a,
            onTap: (slot, item) async {
              if (item == null) return;
              await c.unequip(slot);
            },
          ),
          if (a.worn.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('칸을 누르면 벗어요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          const SizedBox(height: 8),
          if (a.items.isEmpty)
            const KText('마을 대장간에서 몬스터 재료로 장비를 만들 수 있어요.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          for (final item in spare) _SpareRow(controller: c, item: item),
        ],
      ),
    );
  }
}

class _SpareRow extends StatelessWidget {
  const _SpareRow({required this.controller, required this.item});

  final AppController controller;
  final EquipItem item;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          EquipIcon(base: item.base, grade: item.grade, size: 40),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EquipName(item),
                Text(EquipmentRules.itemStatLabel(item),
                    maxLines: 2,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
          SizedBox(
            width: 80,
            child: GoldButton(
              label: '입기',
              height: 36,
              fontSize: 14,
              onPressed: () => controller.equip(item.uid),
            ),
          ),
        ]),
      );
}
