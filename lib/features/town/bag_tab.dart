import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'bag_sheet.dart';

/// 하단 메뉴 '가방' 탭 (11-10 #25).
/// 물약·물건을 보고 쓰는 곳. 마석·금화·재료와 장비 6칸은 다음 묶음에서 여기에 더한다.
class BagTab extends StatelessWidget {
  const BagTab({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.fromLTRB(14, top + 6, 14, 24),
      children: [
        const OrnateTopBar(title: '가방'),
        const SizedBox(height: 10),
        OrnatePanel(child: BagContents(controller: controller)),
        const SizedBox(height: 12),
        const OrnatePanel(
          child: Row(children: [
            Icon(Icons.shield_outlined, color: AppColors.textMuted),
            SizedBox(width: 10),
            Expanded(
              child: Text('장비 6칸은 대장간이 열리면 여기서 입고 벗어요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ),
          ]),
        ),
      ],
    );
  }
}
