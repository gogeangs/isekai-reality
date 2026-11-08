import 'package:flutter/material.dart';

import '../../core/models/player_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../battle/battle_view.dart';

/// 도감: 직업 · 칭호 8종 · 몬스터 6종
class CodexScreen extends StatelessWidget {
  const CodexScreen({
    super.key,
    required this.player,
    required this.purifiedMonsters,
  });

  final PlayerState player;
  final Set<MonsterId> purifiedMonsters;

  static String jobDescription(Job job) => switch (job) {
        Job.explorer => '목표보다 꾸준히 더 걸은 각성자. 새 장소를 찾는 눈이 밝다.',
        Job.knight => '목표의 두 배를 걸은 날이 많은 각성자. 던전에서 든든하다.',
        Job.sage => '매일 공부·독서를 쌓은 각성자. 지혜로 길을 연다.',
        Job.cleric => '푹 잔 날이 많은 각성자. 맑은 정신으로 동료를 돕는다.',
      };

  @override
  Widget build(BuildContext context) {
    final days = player.history.length;
    final daysLeft = RuleConstants.jobAwakeningDay - days;
    final job = player.job;
    final scores = JobRules.scores(
        player.history.take(RuleConstants.jobAwakeningDay).toList());

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text('도감',
              style: TextStyle(
                  color: AppColors.goldBright,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          // ─────────────── 직업
          _Section(
            title: '직업',
            child: job != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.koreanName,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(jobDescription(job),
                          style: const TextStyle(color: AppColors.text)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '$daysLeft일 뒤 직업 각성 · 첫 7일의 생활로 정해져요',
                        style: const TextStyle(color: AppColors.text),
                      ),
                      const SizedBox(height: 10),
                      for (final j in Job.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(children: [
                            SizedBox(
                              width: 64,
                              child: Text(j.koreanName,
                                  style: const TextStyle(
                                      color: AppColors.textMuted)),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: scores[j],
                                  minHeight: 8,
                                  color: AppColors.gold,
                                  backgroundColor: AppColors.track,
                                ),
                              ),
                            ),
                          ]),
                        ),
                    ],
                  ),
          ),

          // ─────────────── 칭호
          _Section(
            title: '칭호 ${player.titles.length} / ${TitleRules.all.length}',
            child: Column(
              children: [
                for (final t in TitleRules.all)
                  _TitleRow(info: t, earned: player.titles.contains(t.id)),
              ],
            ),
          ),

          // ─────────────── 몬스터
          _Section(
            title: '몬스터 도감 ${purifiedMonsters.length} / ${Monsters.all.length}',
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.72,
              children: [
                for (final m in Monsters.all)
                  _MonsterTile(
                      info: m, purified: purifiedMonsters.contains(m.id)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.info, required this.earned});

  final TitleInfo info;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(
          earned ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
          color: earned ? AppColors.gold : AppColors.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(earned ? info.name : '???',
                  style: TextStyle(
                      color: earned ? AppColors.goldBright : AppColors.textMuted,
                      fontWeight: FontWeight.w700)),
              Text(info.hint,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _MonsterTile extends StatelessWidget {
  const _MonsterTile({required this.info, required this.purified});

  final MonsterInfo info;
  final bool purified;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: purified ? '${info.name} → ${info.purifiedName}' : info.habitat,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.track.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: purified ? AppColors.gold : AppColors.track),
        ),
        child: Column(
          children: [
            Expanded(
              child: purified
                  ? MonsterPicture(monster: info.id, size: 88, purified: true)
                  : ColorFiltered(
                      // 아직 정화하지 않은 몬스터는 그림자로만 보인다
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF0E1330), BlendMode.srcIn),
                      child: MonsterPicture(monster: info.id, size: 88),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              purified ? info.purifiedName : '???',
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: purified ? AppColors.text : AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.panelBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.goldBright,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
