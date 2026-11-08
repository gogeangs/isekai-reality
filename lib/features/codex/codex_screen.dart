import 'package:flutter/material.dart';

import '../../core/models/player_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../bulssi/bulssi_bubble.dart';

/// 도감 (목업 '칭호' 구도): 칭호 8종 카드, 직업, 몬스터 6종
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

  static IconData titleIcon(TitleId id) => switch (id) {
        TitleId.firstSteps => Icons.hiking_rounded,
        TitleId.persistentTraveler => Icons.flag_rounded,
        TitleId.morningSpiritFriend => Icons.wb_twilight_rounded,
        TitleId.bookwormSage => Icons.menu_book_rounded,
        TitleId.forcedMarchKnight => Icons.shield_rounded,
        TitleId.nightWalker => Icons.nightlight_round,
        TitleId.awakened => Icons.auto_awesome_rounded,
        TitleId.lanternKeeper => Icons.emoji_objects_rounded,
      };

  /// 상태창과 같은 규칙의 대표 칭호
  TitleId? get _equipped {
    if (player.titles.contains(TitleId.persistentTraveler)) {
      return TitleId.persistentTraveler;
    }
    for (final t in TitleRules.all.reversed) {
      if (player.titles.contains(t.id)) return t.id;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final days = player.history.length;
    final daysLeft = RuleConstants.jobAwakeningDay - days;
    final job = player.job;
    final scores = JobRules.scores(
        player.history.take(RuleConstants.jobAwakeningDay).toList());
    final top = MediaQuery.paddingOf(context).top;
    final equipped = _equipped;

    return NightBackground(
      child: ListView(
        padding: EdgeInsets.fromLTRB(14, top + 6, 14, 24),
        children: [
          const OrnateTopBar(title: '도감'),
          const SizedBox(height: 8),
          Center(
            child: Text('칭호 ${player.titles.length} / ${TitleRules.all.length}',
                style: AppText.title(18, color: AppColors.text)),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.0,
            children: [
              for (final t in TitleRules.all)
                _TitleCard(
                  info: t,
                  icon: titleIcon(t.id),
                  earned: player.titles.contains(t.id),
                  equipped: t.id == equipped,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const BulssiBubble(line: '숨은 칭호를 같이 찾아보자!'),
          const SizedBox(height: 16),

          // ─────────────── 직업
          OrnatePanel(
            ornament: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('직업', style: AppText.title(18)),
                const SizedBox(height: 6),
                if (job != null) ...[
                  Text(job.koreanName,
                      style: AppText.title(26, color: AppColors.text)),
                  const SizedBox(height: 4),
                  Text(jobDescription(job),
                      style: const TextStyle(color: AppColors.text)),
                ] else ...[
                  Text('$daysLeft일 뒤 직업 각성 · 첫 7일의 생활로 정해져요',
                      style: const TextStyle(color: AppColors.text)),
                  const SizedBox(height: 8),
                  for (final j in Job.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(
                          width: 64,
                          child: Text(j.koreanName,
                              style:
                                  const TextStyle(color: AppColors.textMuted)),
                        ),
                        Expanded(
                          child: GlowBar(
                              ratio: scores[j] ?? 0,
                              colors: BarColors.exp,
                              height: 8),
                        ),
                      ]),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ─────────────── 몬스터
          OrnatePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    '몬스터 도감 ${purifiedMonsters.length} / ${Monsters.all.length}',
                    style: AppText.title(18)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                  children: [
                    for (final m in Monsters.all)
                      _MonsterTile(
                          info: m, purified: purifiedMonsters.contains(m.id)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TitleCard extends StatelessWidget {
  const _TitleCard({
    required this.info,
    required this.icon,
    required this.earned,
    required this.equipped,
  });

  final TitleInfo info;
  final IconData icon;
  final bool earned;
  final bool equipped;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      highlight: equipped,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (equipped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                gradient: kGoldGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('장착',
                  style: TextStyle(
                      color: Color(0xFF3A2208),
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Stack(alignment: Alignment.center, children: [
                // 얻지 못한 칭호는 어둡게, 자물쇠를 얹는다
                ColorFiltered(
                  colorFilter: earned
                      ? const ColorFilter.mode(
                          Colors.transparent, BlendMode.dst)
                      : const ColorFilter.matrix([
                          0.12, 0.12, 0.12, 0, 0,
                          0.12, 0.12, 0.14, 0, 0,
                          0.16, 0.16, 0.22, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                  child: Image.asset(
                    'assets/images/title_${info.id.name}.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(icon,
                        size: 40,
                        color: earned
                            ? AppColors.goldBright
                            : AppColors.textMuted),
                  ),
                ),
                if (!earned)
                  const Icon(Icons.lock_rounded,
                      size: 30, color: AppColors.goldBright),
              ]),
            ),
          ),
          Text(earned ? info.name : '???',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.title(15,
                  color: earned ? AppColors.goldBright : AppColors.textMuted)),
          Text(info.hint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
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
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: purified
                ? const [Color(0xFF3A2E6E), Color(0xFF1B1E4C)]
                : const [Color(0xFF1E2152), Color(0xFF14173E)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: purified
                  ? AppColors.goldBright
                  : AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Expanded(
              child: purified
                  ? MonsterPicture(monster: info.id, size: 88, purified: true)
                  : ColorFiltered(
                      // 아직 정화하지 않은 몬스터는 그림자로만 보인다
                      colorFilter: const ColorFilter.mode(
                          Color(0xFF0B0D26), BlendMode.srcATop),
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
