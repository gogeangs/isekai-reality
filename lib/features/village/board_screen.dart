import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import 'daily_quests.dart';

/// 마을 의뢰 게시판 (11-10 #26). 이번에는 일일 의뢰만,
/// 주간·수시·긴급 의뢰는 수치를 확정한 뒤 더한다.
class BoardScreen extends StatelessWidget {
  const BoardScreen({super.key, required this.controller});

  final AppController controller;

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
            final p = controller.player;
            final today = p.today!;
            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                  title: '의뢰 게시판',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 6),
                const BulssiLine(line: '오늘의 의뢰야. 다 끝내면 보너스가 있어!'),
                const SizedBox(height: 12),
                DailyQuestPanel(
                  quests: QuestRules.forDay(today),
                  allDone: QuestRules.allDone(today),
                  streak: QuestRules.allDoneStreak(p.history),
                ),
                const SizedBox(height: 12),
                const OrnatePanel(
                  child: Text('주간·수시·긴급 의뢰는 곧 올라와요.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
