import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'codex_screen.dart';

/// 묶음 85 #419: 도감은 아래 탭에서 빠지고, 프로필 「도감」 버튼 · 발견 알림에서 여는 화면 (뒤로 가기)
class CodexPage extends StatelessWidget {
  const CodexPage({super.key, required this.controller});

  final AppController controller;

  static Future<void> open(BuildContext context, AppController c) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CodexPage(controller: c)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('codexPage'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => CodexScreen(
            onBack: () => Navigator.of(context).maybePop(),
            // 더 나오지 않는 정령계 몬스터는 도감에서 숨긴다 (하늘 슬라임은 보임, #168)
            // 묶음 70 #293: 발견한 것만 (갈래가 있는 몬스터)
            purifiedMonsters: {
              for (final m in controller.purifiedEver)
                if (Monsters.codexGroup(m) != null) m,
            },
            fresh: controller.codexFresh,
            onSeen: controller.markCodexSeen,
            highlandOpen: controller.highlandOpen,
            huntCounts: controller.huntTotals,
            monGearFound: {
              for (final b in MonGearRules.byMonster.values)
                if (controller.monGearFound(b)) b,
            },
            petsSeen: controller.pets.seen,
            petsOpen: controller.petCodexOpen,
            petsNew: controller.petCodexNew,
            onPetsTab: controller.markPetCodexSeen,
          ),
        ),
      ),
    );
  }
}
