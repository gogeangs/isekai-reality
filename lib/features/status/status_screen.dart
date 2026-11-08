import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/player_state.dart';
import '../../core/rules/rules.dart';
import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/bulssi_lines.dart';

/// 메인 상태창 (목업 확정본 구도).
///
/// 위: 각성자 그림 + 월계관 레벨 배지 / 가운데: 경험치·던전 게이지·MP·스탯 /
/// 아래: 일일 퀘스트와 불씨.
class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.player,
    required this.onLogStudy,
    this.onOpenDungeon,
    this.look = HeroLook.male,
    this.weatherLabel = '맑음',
    this.weatherIcon = Icons.wb_sunny_rounded,
  });

  final PlayerState player;
  final ValueChanged<int> onLogStudy;

  /// '던전 열기' 버튼 (없으면 버튼을 그리지 않음)
  final VoidCallback? onOpenDungeon;
  final HeroLook look;

  /// 위쪽 날씨 표시 (예: '맑음 12°')
  final String weatherLabel;
  final IconData weatherIcon;

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
    final top = MediaQuery.paddingOf(context).top;

    return NightBackground(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ─────────── 각성자 그림
          SizedBox(
            height: 300 + top,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _HeroArt(look: look),
                const Align(
                    alignment: Alignment.bottomCenter,
                    child: FadeToNight(height: 110)),
                Positioned(
                  top: top + 8,
                  left: 14,
                  right: 14,
                  child: Row(children: [
                    const EyeEmblem(size: 42),
                    const Spacer(),
                    ChipBadge(text: weatherLabel, icon: weatherIcon),
                  ]),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -70),
            child: Center(
              child: LaurelBadge(
                level: player.level.level,
                title: _equippedTitle(player.titles),
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StatusPanel(player: player, onOpenDungeon: onOpenDungeon),
                  const SizedBox(height: 14),
                  _QuestPanel(
                    quests: QuestRules.forDay(today),
                    onLogStudy: () => _openStudySheet(context),
                  ),
                  const SizedBox(height: 14),
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
          ),
        ],
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

// ───────────────────────────────────────────────────────────── 각성자 그림

class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.look});

  final HeroLook look;

  @override
  Widget build(BuildContext context) {
    const male = 'assets/images/bg_status_male.jpg';
    if (look == HeroLook.male) {
      return Image.asset(male,
          fit: BoxFit.cover,
          alignment: const Alignment(-0.3, -0.5),
          semanticLabel: '기본 각성자',
          errorBuilder: (_, __, ___) => const SizedBox());
    }
    // 여성 전신 그림이 생기기 전까지: 흐린 배경 + 초상화
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Image.asset(male,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox()),
        ),
        Center(
          child: Container(
            width: 190,
            height: 190,
            margin: const EdgeInsets.only(bottom: 30),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.goldBright, width: 3),
              boxShadow: [
                BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.6),
                    blurRadius: 30),
              ],
            ),
            child: ClipOval(
              child: Image.asset('assets/images/portrait_female.jpg',
                  fit: BoxFit.cover,
                  semanticLabel: '기본 각성자',
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      size: 120,
                      color: AppColors.textMuted)),
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

    return OrnatePanel(
      ornament: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('EXP', style: AppText.title(16)),
            const SizedBox(width: 10),
            Expanded(
                child: GlowBar(
                    ratio: player.level.ratio, colors: BarColors.exp)),
            const SizedBox(width: 10),
            Text(
              '${comma(player.level.expIntoLevel)} / '
              '${comma(player.level.expToNext)}',
              style: const TextStyle(color: AppColors.text, fontSize: 13),
            ),
          ]),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Gauge(
                  icon: Icons.vpn_key_rounded,
                  label: '던전 게이지 · 열쇠 ${gauge.keysAvailable}',
                  ratio: gauge.ratio,
                  colors: BarColors.gauge,
                  value: gauge.dailyKeyLimitReached
                      ? '오늘은 다 모았어요'
                      : '${comma(gauge.stepsIntoNextKey)} / '
                          '${comma(gauge.stepsPerKey)}보',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Gauge(
                  icon: Icons.nightlight_round,
                  label: 'MP · 수면',
                  ratio: (sleep / RuleConstants.sleepGoodMinutes)
                      .clamp(0, 1)
                      .toDouble(),
                  colors: BarColors.mana,
                  value: today.sleepMinutes == null
                      ? '기록 없음'
                      : '${hoursMinutes(sleep)} / 7시간',
                ),
              ),
            ],
          ),
          if (onOpenDungeon != null) ...[
            const SizedBox(height: 12),
            FrameButton(
              onPressed: onOpenDungeon,
              icon: Icons.door_front_door_rounded,
              height: 46,
              label: gauge.keysAvailable > 0
                  ? '던전 열기 (열쇠 ${gauge.keysAvailable})'
                  : '던전 (열쇠 없음)',
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              _StatTile(
                  icon: Icons.favorite_rounded,
                  name: '체력',
                  value: player.stats.vitality),
              _StatTile(
                  icon: Icons.air_rounded,
                  name: '민첩',
                  value: player.stats.agility),
              _StatTile(
                  icon: Icons.menu_book_rounded,
                  name: '지력',
                  value: player.stats.wisdom),
              _StatTile(
                  icon: Icons.auto_awesome_rounded,
                  name: '정신',
                  value: player.stats.spirit),
            ],
          ),
        ],
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({
    required this.label,
    required this.ratio,
    required this.colors,
    required this.value,
    required this.icon,
  });

  final String label;
  final double ratio;
  final List<Color> colors;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: colors.last),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 6),
        GlowBar(ratio: ratio, colors: colors),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.name, required this.value});

  final IconData icon;
  final String name;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2B2F6B), Color(0xFF1B1E4C)],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.75)),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.goldBright, size: 20),
          const SizedBox(height: 2),
          Text(name,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text('$value', style: AppText.title(20, color: AppColors.text)),
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
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.receipt_long_rounded, color: AppColors.goldBright),
            const SizedBox(width: 8),
            Text('일일 퀘스트', style: AppText.title(19)),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.gold.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onLogStudy,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    gradient: kGoldGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.menu_book_rounded,
                        size: 16, color: Color(0xFF3A2208)),
                    SizedBox(width: 4),
                    Text('공부 기록',
                        style: TextStyle(
                            color: Color(0xFF3A2208),
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x66101333),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            gradient: quest.completed ? kGoldGradient : null,
            border: Border.all(color: AppColors.gold, width: 1.4),
          ),
          child: quest.completed
              ? const Icon(Icons.check_rounded,
                  size: 18, color: Color(0xFF3A2208))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: Text(quest.title,
              style: const TextStyle(color: AppColors.text, fontSize: 15)),
        ),
        if (quest.completed)
          Text('완료', style: AppText.title(15))
        else ...[
          Expanded(
            flex: 3,
            child: GlowBar(
              ratio: quest.target == 0 ? 0 : quest.current / quest.target,
              colors: BarColors.exp,
              height: 7,
            ),
          ),
          const SizedBox(width: 8),
          Text('$current / $target${quest.unit}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
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
            Text('얼마나 공부·독서했나요?', style: AppText.title(19)),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final m in const [10, 30, 60])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FrameButton(
                        onPressed: () => Navigator.pop(context, m),
                        label: '+$m분',
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
