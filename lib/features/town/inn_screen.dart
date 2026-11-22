import '../village/npc_header.dart';
import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../jobs/job_skill_bar.dart' show kJobMpColor;
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_mood.dart';
import '../../theme/top_notice.dart';

/// 여관 (앱 안 시설): 체크인해 있는 동안 HP · MP · 기력이 조금씩 찬다 (묶음 80 #367 · 81 #373).
/// 시간당 최대치의 20%(숨은 값), 상한 없음 · 「일어나기」 까지. 원정 나간 펫이 있으면 멈춤.
class InnScreen extends StatelessWidget {
  const InnScreen({super.key, required this.controller});

  final AppController controller;

  /// 마르타 상황 안내 (가득 · 쉬는 중 · 오늘 이미 쉼). 없으면 null
  static String? innSituation(
      {required bool resting, required bool restedToday, bool full = false}) {
    if (resting && full) return VillageRules.innFull;
    if (resting) return VillageRules.innResting;
    if (restedToday) return VillageRules.innRested;
    return null;
  }

  /// 판 설명 한 줄 (각성 전엔 MP 없음)
  static String fillLine({required bool job}) => job
      ? '여관에 있는 동안 HP · MP · 기력이 조금씩 차요'
      : '여관에 있는 동안 HP · 기력이 조금씩 차요';

  /// 원정 중이라 멈춤
  static const String pausedLine = '원정 중이라 회복이 멈췄어요 · 펫이 돌아오면 다시 차요';

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        header: true,
        interior: 'inn', // 묶음 67 #272
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final c = controller;
            final today = c.player.today;
            final resting = c.resting;
            final job = c.jobsOpen;
            final full = c.innFull;
            final paused = resting && c.innPaused;

            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                  title: '여관',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 6),
                // 묶음 38 #213: 정령 띠 대신 마을 사람이 안내
                NpcHeader(
                  controller: c,
                  npc: Npc.marta,
                  guide: VillageRules.innGuide,
                  situation: innSituation(
                      resting: resting, restedToday: today?.rested ?? false, full: full),
                ),
                const SizedBox(height: 4),
                // 묶음 26 #175: 그림을 줄이고 체크인·쉬는 중 버튼을 바로 아래에
                // (작은 iPhone에서도 들어오자마자 보이게)
                Center(
                  child: Image.asset('assets/images/map_inn.webp',
                      height: 80,
                      errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                const SizedBox(height: 8),
                if (resting) ...[
                  GoldButton(
                    key: const Key('innResting'),
                    // 묶음 82 #391: 띠는 「쉬는 중」만 (차오름은 아래 막대로)
                    label: '쉬는 중',
                    onPressed: null,
                  ),
                  // 묶음 81 #373: 광고 보고 바로 회복 (1시간치, 한 번 체크인에 두 번까지)
                  if (c.canInnAd) ...[
                    const SizedBox(height: 8),
                    AdButton(
                      key: const Key('innAd'),
                      label: '광고 보고 바로 회복',
                      onPressed: () async {
                        final ok = await c.innAd();
                        if (!ok && context.mounted) {
                          showTopNotice(context, '광고를 불러오지 못했어요.');
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  // 묶음 15 #107: 일어나도 그때까지 찬 HP·기력은 그대로
                  TextButton(
                    key: const Key('innWake'),
                    onPressed: () => c.stopResting(),
                    child: const KText('일어나기',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ] else
                  GoldButton(
                    key: const Key('innCheckIn'),
                    label: '체크인하고 쉬기',
                    onPressed: () async {
                      final ok = await c.restAtInn();
                      if (ok && context.mounted) {
                        showTopNotice(context, '체크인했어요. 있는 동안 조금씩 차요!');
                      }
                    },
                  ),
                const SizedBox(height: 12),
                // 묶음 80 #367: 쉬는 동안 차는 것 (HP · MP(각성 뒤) · 기력)
                OrnatePanel(
                  key: const Key('innFillPanel'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('쉬는 동안 차는 것', style: AppText.title(18)),
                        const SizedBox(height: 8),
                        _Fill(
                            key: const Key('innFill_hp'),
                            icon: 'vitality',
                            label: 'HP',
                            color: const Color(0xFFE86A6A),
                            value: c.hp,
                            max: c.maxHp),
                        if (job)
                          _Fill(
                              key: const Key('innFill_jobMp'),
                              icon: 'job_mp',
                              label: 'MP',
                              color: kJobMpColor,
                              value: c.jobMp,
                              max: c.jobMpMax),
                        _Fill(
                            key: const Key('innFill_mp'),
                            icon: 'mp',
                            label: mpLabel(context),
                            color: AppColors.mana,
                            value: c.mp,
                            max: c.mpMax),
                        if (paused) ...[
                          const SizedBox(height: 4),
                          const KText(pausedLine,
                              key: Key('innPaused'),
                              style: TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 6),
                        Row(children: [
                          const GameIcon('moon', size: 22),
                          const SizedBox(width: 6),
                          Expanded(
                            child: KText(fillLine(job: job),
                                key: const Key('innFillLine'),
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 12.5, height: 1.35)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 차는 것 한 줄: 아이콘 · 이름 · 막대 · 「지금 / 최대」
class _Fill extends StatelessWidget {
  const _Fill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.value,
    required this.max,
  });

  final String icon;
  final String label;
  final Color color;
  final int value;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        GameIcon(icon, size: 22),
        const SizedBox(width: 6),
        SizedBox(
          width: 34,
          child: Text(label,
              maxLines: 1,
              style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: ratio),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                backgroundColor: color.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 큰 숫자(1,117 / 2,175)도 잘리지 않게: 자리를 넓히고 넘치면 살짝 줄임
        SizedBox(
          width: 96,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text('${comma(value)} / ${comma(max)}',
                textAlign: TextAlign.right,
                maxLines: 1,
                style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}
