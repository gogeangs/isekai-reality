import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';

/// 여관 (앱 안 시설): 오늘 하루를 정리하고 체크인한다.
/// 저녁 6시 ~ 11시에 체크인하고 7시간 이상 자면 다음 날 경험치 +10.
class InnScreen extends StatelessWidget {
  const InnScreen({super.key, required this.controller});

  final AppController controller;

  static String bulssiLine({
    required bool rested,
    required bool open,
    required DateTime now,
  }) {
    if (rested) return '오늘도 수고했어. 푹 자고 내일 아침에 보자!';
    if (open) return '오늘 하루 고생 많았어. 여기서 쉬고 푹 자면 내일 보너스를 줄게.';
    if (now.hour < RuleConstants.innOpenHour) {
      return '여관 문은 저녁 6시에 열려. 그때 와서 하루를 마무리하자.';
    }
    return '벌써 늦었어! 오늘은 그냥 바로 자자.';
  }

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
            final exp = p.dailyExp.isEmpty ? null : p.dailyExp.last;
            final open = controller.innOpen;
            final rested = today.restedAtInn;
            final cleared = today.dungeonRuns.where((r) => r.cleared).length;

            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                  title: '여관',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Image.asset('assets/images/map_inn.png',
                      height: 110,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                const SizedBox(height: 8),
                OrnatePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('오늘 하루', style: AppText.title(18)),
                      const SizedBox(height: 10),
                      _Row(
                          icon: 'steps',
                          label: '걸음',
                          value: '${comma(today.steps)} / '
                              '${comma(today.stepGoal)}보',
                          done: today.stepGoalAchieved),
                      _Row(
                          icon: 'key',
                          label: '던전',
                          value: today.dungeonRuns.isEmpty
                              ? '아직 안 열었어요'
                              : '${today.dungeonRuns.length}번 · 정화 $cleared번'),
                      _Row(
                          icon: 'crystal',
                          label: '필드 몬스터',
                          value: '${today.fieldMonstersPurified}마리 정화'),
                      _Row(
                          icon: 'study',
                          label: '공부·독서',
                          value: '${today.studyMinutes}분'),
                      const Divider(color: Color(0x33E9C46A), height: 18),
                      _Row(
                          icon: 'exp',
                          label: '오늘 경험치',
                          value: '+${exp?.total ?? 0}',
                          strong: true),
                      _Row(
                          icon: 'crystal',
                          label: '오늘 정화 결정',
                          value: '+${TownRules.crystalsEarnedOn(today)}개',
                          strong: true),
                      if ((exp?.innRest ?? 0) > 0)
                        _Row(
                            icon: 'moon',
                            label: '어젯밤 휴식 보너스',
                            value: '+${exp!.innRest}',
                            strong: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                BulssiBubble(
                  line: bulssiLine(
                      rested: rested, open: open, now: controller.now),
                ),
                const SizedBox(height: 12),
                const OrnatePanel(
                  child: Row(children: [
                    GameIcon('moon', size: 34),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '저녁 6시 ~ 11시에 체크인하고 7시간 이상 자면\n'
                        '내일 경험치 +${RuleConstants.innRestExp}',
                        style: TextStyle(
                            color: AppColors.text, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                GoldButton(
                  label: rested
                      ? '체크인 완료'
                      : open
                          ? '체크인하고 쉬기'
                          : '저녁 6시 ~ 11시에 열려요',
                  onPressed: rested || !open
                      ? null
                      : () async {
                          final ok = await controller.restAtInn();
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('체크인했어요. 좋은 꿈 꾸세요!')),
                            );
                          }
                        },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.done = false,
    this.strong = false,
  });

  final String icon;
  final String label;
  final String value;
  final bool done;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        GameIcon(icon, size: 22),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        const Spacer(),
        if (done) ...[
          const GameIcon('check', size: 18),
          const SizedBox(width: 4),
        ],
        Text(value,
            style: strong
                ? AppText.title(17, color: AppColors.goldBright)
                : const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
