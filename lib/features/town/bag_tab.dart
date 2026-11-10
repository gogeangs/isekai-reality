import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'bag_sheet.dart';
import 'material_view.dart';

/// 하단 메뉴 '가방' 탭 (11-10 #25).
/// 마석·금화, 물약·물건(마시고 쓰기), 재료. 장비 6칸은 대장간 묶음에서 여기에 더한다.
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
