import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart';

/// 여관 (앱 안 시설): 하루를 정리하고 쉰다.
/// 언제든 체크인하고 4시간이 지나면 HP·정령 MP가 가득 차고,
/// 그날 처음 쉬었으면 휴식 보너스, 며칠 이어서 쉬면 연속 휴식 보너스.
class InnScreen extends StatelessWidget {
  const InnScreen({super.key, required this.controller});

  final AppController controller;

  static String bulssiLine(
      {required bool resting, required bool restedToday, bool full = false}) {
    // 11-10 C4: 이미 가득하면 회복이 아니라 휴식 보너스를 말한다
    if (resting && full) {
      return '기운은 벌써 가득해. 푹 쉬면 휴식 보너스를 받을 수 있어.';
    }
    if (resting) return '푹 쉬는 중이야. 다른 일 하다가 와도 돼. 다 쉬면 알려 줄게!';
    if (restedToday) return '오늘은 이미 푹 쉬었어. 지치면 언제든 또 쉬어도 돼.';
    return '오늘 하루 고생 많았어. 여기서 쉬면 HP와 MP가 가득 찰 거야.';
  }

  static String left(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return m > 0 ? '$h시간 $m분' : '$h시간';
    return '${d.inMinutes < 1 ? 1 : d.inMinutes}분';
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
            final resting = controller.resting;
            final full = controller.hp >= controller.maxHp &&
                controller.mp >= RuleConstants.mpMax;
            final streak = p.restStreak;
            final next = TownRules.nextRestReward(streak);
            final cleared = today.dungeonRuns.where((r) => r.cleared).length;

            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                  title: '여관',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 6),
                BulssiLine(
                  mood: resting ? SpiritMood.sleepy : SpiritMood.normal,
                  line: bulssiLine(
                      resting: resting,
                      restedToday: today.rested,
                      full: full),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Image.asset('assets/images/map_inn.png',
                      height: 110,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                const SizedBox(height: 8),
                OrnatePanel(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
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
                                : '${today.dungeonRuns.length}번 · 돌파 $cleared번'),
                        _Row(
                            icon: 'crystal',
                            label: '필드 몬스터',
                            value: '${today.fieldMonstersPurified}마리 사냥'),
                        _Row(
                            icon: 'vitality',
                            label: 'HP',
                            value: '${comma(controller.hp)} / '
                                '${comma(controller.maxHp)}'),
                        _Row(
                            icon: 'mp',
                            label: '정령 MP',
                            value:
                                '${controller.mp} / ${RuleConstants.mpMax}'),
                        const Divider(color: Color(0x33E9C46A), height: 18),
                        _Row(
                            icon: 'exp',
                            label: '오늘 경험치',
                            value: '+${exp?.total ?? 0}',
                            strong: true),
                        _Row(
                            icon: 'mana_stone',
                            label: '오늘 마석',
                            value: '+${TownRules.manaStonesEarnedOn(today)}개',
                            strong: true),
                        if ((exp?.rest ?? 0) > 0)
                          _Row(
                              icon: 'moon',
                              label: '휴식 보너스',
                              value: '+${exp!.rest + exp.restStreak}',
                              strong: true),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OrnatePanel(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const GameIcon('streak', size: 32),
                          const SizedBox(width: 8),
                          KText('연속 휴식 $streak일',
                              style: AppText.title(18,
                                  color: AppColors.goldBright)),
                        ]),
                        const SizedBox(height: 8),
                        _StreakDots(streak: streak),
                        const SizedBox(height: 8),
                        if (next.daysLeft > 0)
                          KText(
                            '${next.daysLeft}일 더 쉬면 경험치 +${next.exp}'
                            '${next.crystals > 0 ? ', 마석 +${next.crystals}' : ''}',
                            style: const TextStyle(
                                color: AppColors.text, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const OrnatePanel(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Row(children: [
                      GameIcon('moon', size: 34),
                      SizedBox(width: 10),
                      Expanded(
                        child: KText(
                          '언제든 체크인하고 4시간 쉬면 HP와 정령 MP가 가득 차요.\n'
                          '하루 첫 휴식은 경험치 +${RuleConstants.restBonusExp}, '
                          '며칠 이어서 쉬면 보너스가 커져요.',
                          style: TextStyle(
                              color: AppColors.text, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                if (resting) ...[
                  GoldButton(
                    label: full
                        ? '회복 완료 · 보너스까지 ${left(controller.restLeft)}'
                        : '쉬는 중 · ${left(controller.restLeft)} 남음',
                    onPressed: null,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => controller.stopResting(),
                    child: const KText('그만 쉬기 (보상 없음)',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ] else
                  GoldButton(
                    label: '체크인하고 쉬기',
                    onPressed: () async {
                      final ok = await controller.restAtInn();
                      if (ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: KText('체크인했어요. 4시간 뒤에 다 쉬어요!')),
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

/// 다음 14일 단계까지의 연속 휴식 점
class _StreakDots extends StatelessWidget {
  const _StreakDots({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    const marks = {3, 7, 14};
    final shown = streak <= 14 ? 14 : streak + (7 - (streak - 14) % 7);
    final start = shown - 14;
    return Row(children: [
      for (var i = start + 1; i <= shown; i++)
        Expanded(
          child: Container(
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: i <= streak
                  ? AppColors.goldBright
                  : AppColors.gold.withValues(alpha: 0.18),
              border: marks.contains(i) || (i > 14 && (i - 14) % 7 == 0)
                  ? Border.all(color: AppColors.goldBright, width: 1.4)
                  : null,
            ),
          ),
        ),
    ]);
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
