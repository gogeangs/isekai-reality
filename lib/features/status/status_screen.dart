import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/player_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/bulssi_lines.dart';

/// 메인 상태창 (목업 확정본 기준).
///
/// [player] 의 마지막 기록이 '오늘'이다. 공부 기록은 [onLogStudy] 로 알린다.
class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.player,
    required this.onLogStudy,
    this.onOpenDungeon,
    this.heroAsset = 'assets/images/hero_male.png',
    this.weatherLabel = '맑음',
    this.weatherIcon = Icons.wb_sunny_rounded,
  });

  /// 위쪽 날씨 표시 (예: '맑음 12°')
  final String weatherLabel;
  final IconData weatherIcon;

  final PlayerState player;
  final ValueChanged<int> onLogStudy;

  /// '던전 열기' 버튼 (없으면 버튼을 그리지 않음)
  final VoidCallback? onOpenDungeon;
  final String heroAsset;

  Future<void> _openStudySheet(BuildContext context) async {
    final minutes = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _StudySheet(),
    );
    if (minutes != null) onLogStudy(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final today = player.today!;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.duskPink, AppColors.dusk, AppColors.night],
          stops: [0, 0.35, 0.8],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _TopBar(weatherLabel: weatherLabel, weatherIcon: weatherIcon),
            const SizedBox(height: 8),
            _Hero(asset: heroAsset),
            _LevelBadge(
              level: player.level.level,
              title: _equippedTitle(player.titles),
            ),
            const SizedBox(height: 12),
            _StatusPanel(player: player, onOpenDungeon: onOpenDungeon),
            const SizedBox(height: 16),
            _QuestPanel(
              quests: QuestRules.forDay(today),
              onLogStudy: () => _openStudySheet(context),
            ),
            const SizedBox(height: 16),
            BulssiBubble(
              line: BulssiLines.forStatus(
                today: today,
                gauge: player.gauge,
                now: DateTime.now(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 대표 칭호: '끈기의 여행자'를 우선, 없으면 가장 마지막에 얻을 수 있는 칭호
  String _equippedTitle(Set<TitleId> titles) {
    if (titles.contains(TitleId.persistentTraveler)) {
      return TitleRules.info(TitleId.persistentTraveler).name;
    }
    for (final t in TitleRules.all.reversed) {
      if (titles.contains(t.id)) return t.name;
    }
    return '새내기 각성자';
  }
}

// ───────────────────────────────────────────────────────────── 위쪽 바

class _TopBar extends StatelessWidget {
  const _TopBar({required this.weatherLabel, required this.weatherIcon});

  final String weatherLabel;
  final IconData weatherIcon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold, width: 1.5),
          ),
          child: const Icon(Icons.remove_red_eye_outlined,
              color: AppColors.gold, size: 24, semanticLabel: '탑의 문장'),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.panelBorder.withValues(alpha: 0.6)),
          ),
          child: Row(children: [
            Icon(weatherIcon, color: AppColors.gold, size: 18),
            const SizedBox(width: 6),
            Text(weatherLabel,
                style: const TextStyle(color: AppColors.text, fontSize: 14)),
          ]),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────── 캐릭터

class _Hero extends StatelessWidget {
  const _Hero({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 발밑의 마법진
          Container(
            width: 240,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: const BorderRadius.all(Radius.elliptical(120, 28)),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            child: Image.asset(
              asset,
              height: 270,
              semanticLabel: '기본 각성자',
              errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                size: 200,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── 레벨·칭호

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.title});

  final int level;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.night,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold, width: 1.5),
          ),
          child: Text(
            'Lv.$level',
            style: const TextStyle(
              color: AppColors.goldBright,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD9B865), AppColors.goldBright, Color(0xFFD9B865)],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.night,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────────────────────── 상태 패널

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.player, this.onOpenDungeon});

  final PlayerState player;
  final VoidCallback? onOpenDungeon;

  @override
  Widget build(BuildContext context) {
    final today = player.today!;
    final gauge = player.gauge;
    final sleep = today.sleepMinutes ?? 0;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Bar(
            label: 'EXP',
            ratio: player.level.ratio,
            color: AppColors.gold,
            value: '${comma(player.level.expIntoLevel)} / '
                '${comma(player.level.expToNext)}',
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Bar(
                  icon: Icons.vpn_key_rounded,
                  label: '던전 게이지 · 열쇠 ${gauge.keysAvailable}',
                  ratio: gauge.ratio,
                  color: AppColors.gauge,
                  value: gauge.dailyKeyLimitReached
                      ? '오늘은 다 모았어요'
                      : '${comma(gauge.stepsIntoNextKey)} / '
                          '${comma(gauge.stepsPerKey)}보',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Bar(
                  icon: Icons.nightlight_round,
                  label: 'MP · 수면',
                  ratio: (sleep / RuleConstants.sleepGoodMinutes)
                      .clamp(0, 1)
                      .toDouble(),
                  color: AppColors.mana,
                  value: today.sleepMinutes == null
                      ? '기록 없음'
                      : '${hoursMinutes(sleep)} / 7시간',
                ),
              ),
            ],
          ),
          if (onOpenDungeon != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onOpenDungeon,
              icon: const Icon(Icons.door_front_door_rounded),
              label: Text(gauge.keysAvailable > 0
                  ? '던전 열기 (열쇠 ${gauge.keysAvailable})'
                  : '던전 (열쇠 없음)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gauge,
                side: BorderSide(
                    color: gauge.keysAvailable > 0
                        ? AppColors.gauge
                        : AppColors.track),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _StatCard(icon: Icons.favorite_rounded, name: '체력', value: player.stats.vitality),
              _StatCard(icon: Icons.air_rounded, name: '민첩', value: player.stats.agility),
              _StatCard(icon: Icons.menu_book_rounded, name: '지력', value: player.stats.wisdom),
              _StatCard(icon: Icons.auto_awesome_rounded, name: '정신', value: player.stats.spirit),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.ratio,
    required this.color,
    required this.value,
    this.icon,
  });

  final String label;
  final double ratio;
  final Color color;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 10,
            color: AppColors.track,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: ratio.clamp(0, 1).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.name, required this.value});

  final IconData icon;
  final String name;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.night.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.panelBorder.withValues(alpha: 0.7)),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text('$value',
              style: const TextStyle(
                  color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── 일일 퀘스트

class _QuestPanel extends StatelessWidget {
  const _QuestPanel({required this.quests, required this.onLogStudy});

  final List<QuestProgress> quests;
  final VoidCallback onLogStudy;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.gold),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('일일 퀘스트',
                  style: TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
            FilledButton.icon(
              onPressed: onLogStudy,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.night,
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.menu_book_rounded, size: 18),
              label: const Text('공부 기록'),
            ),
          ]),
          const SizedBox(height: 10),
          for (final q in quests) _QuestRow(quest: q),
        ],
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.quest});

  final QuestProgress quest;

  @override
  Widget build(BuildContext context) {
    final current =
        quest.unit == '보' ? comma(quest.current) : '${quest.current}';
    final target = quest.unit == '보' ? comma(quest.target) : '${quest.target}';
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.night.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.panelBorder.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(
          quest.completed
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          color: AppColors.gold,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(quest.title,
              style: const TextStyle(color: AppColors.text, fontSize: 15)),
        ),
        if (quest.completed)
          const Text('완료',
              style: TextStyle(
                  color: AppColors.goldBright, fontWeight: FontWeight.w700))
        else
          Text('$current / $target${quest.unit}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ]),
    );
  }
}

// ───────────────────────────────────────────────────────────── 공부 기록 시트

class _StudySheet extends StatelessWidget {
  const _StudySheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('얼마나 공부·독서했나요?',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final m in const [10, 30, 60])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, m),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.goldBright,
                          side: const BorderSide(color: AppColors.gold),
                          minimumSize: const Size(44, 52),
                        ),
                        child: Text('+$m분'),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── 공통 패널

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.panelBorder.withValues(alpha: 0.8)),
      ),
      child: child,
    );
  }
}
