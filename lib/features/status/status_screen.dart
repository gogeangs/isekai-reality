import 'dart:ui' show ImageFilter;

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
/// 위: 각성자 그림 + 월계관 레벨 배지 / 가운데: 경험치·던전 게이지·HP·정령 MP·스탯 /
/// 아래: 일일 퀘스트와 불씨.
class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.player,
    this.hp,
    this.mp,
    this.restLeft,
    this.spiritAway,
    this.onOpenDungeon,
    this.onOpenInn,
    this.onOpenShop,
    this.equippedTitle,
    this.look = HeroLook.male,
    this.weatherLabel = '맑음',
    this.weatherIcon = Icons.wb_sunny_rounded,
  });

  final PlayerState player;

  /// 지금 HP (없으면 가득)
  final int? hp;

  /// 정령 MP (없으면 가득)
  final int? mp;

  /// 여관에서 쉬는 중이면 남은 시간
  final Duration? restLeft;

  /// 정령이 원정 중이면 한 줄 안내 (예: '원정 중 · 12분 뒤 돌아와요')
  final String? spiritAway;

  /// '던전 열기' 버튼 (없으면 버튼을 그리지 않음)
  final VoidCallback? onOpenDungeon;

  /// 앱 안 시설 (없으면 마을 줄을 그리지 않음)
  final VoidCallback? onOpenInn;
  final VoidCallback? onOpenShop;

  /// 대표 칭호 (없으면 '새내기 각성자')
  final TitleId? equippedTitle;
  final HeroLook look;

  /// 위쪽 날씨 표시 (예: '맑음 12°')
  final String weatherLabel;
  final IconData weatherIcon;

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
            height: 360 + top,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _HeroArt(look: look, top: top),
                const Align(
                    alignment: Alignment.bottomCenter,
                    child: FadeToNight(height: 80)),
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
                title: equippedTitle == null
                    ? '새내기 각성자'
                    : TitleRules.info(equippedTitle!).name,
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
                  // 불씨: 각성자 그림 바로 아래에서 오늘의 한마디
                  BulssiBubble(
                    line: BulssiLines.forStatus(
                      today: today,
                      gauge: player.gauge,
                      now: DateTime.now(),
                      hpRatio: (hp ?? player.maxHp) / player.maxHp,
                      resting: restLeft != null,
                      spiritAway: spiritAway != null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StatusPanel(
                    player: player,
                    hp: hp ?? player.maxHp,
                    mp: mp ?? RuleConstants.mpMax,
                    spiritAway: spiritAway,
                    onOpenDungeon: onOpenDungeon,
                  ),
                  const SizedBox(height: 14),
                  _QuestPanel(quests: QuestRules.forDay(today)),
                  if (onOpenInn != null || onOpenShop != null) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: _TownTile(
                          asset: 'map_inn',
                          title: '여관',
                          subtitle: restLeft != null
                              ? '쉬는 중 · ${_left(restLeft!)}'
                              : '하루 마무리',
                          onTap: onOpenInn,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _TownTile(
                          asset: 'map_store',
                          title: '잡화상',
                          subtitle: '결정 ${player.crystals}개',
                          onTap: onOpenShop,
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── 각성자 그림

/// 마을 시설 입구 (여관 · 잡화상)
class _TownTile extends StatelessWidget {
  const _TownTile({
    required this.asset,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String asset;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: OrnatePanel(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: Row(children: [
          Image.asset('assets/images/$asset.png',
              width: 46,
              height: 46,
              errorBuilder: (_, __, ___) => const SizedBox(width: 46)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.title(18, color: AppColors.text)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// 각성자 그림. 머리가 휴대폰 상태 표시줄(시계·배터리)에, 발이 레벨 배지에
/// 가리지 않도록 그림 전체를 상태 표시줄 아래 ~ 배지 위 사이에 넣는다.
/// 그 바깥(상태 표시줄 뒤, 배지 뒤)은 같은 그림을 흐리게 깔아 이어 보이게 한다.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.look, required this.top});

  final HeroLook look;

  /// 상태 표시줄 높이
  final double top;

  /// 아래 레벨 배지가 겹치는 높이
  static const double badgeOverlap = 64;

  @override
  Widget build(BuildContext context) {
    final asset = look == HeroLook.female
        ? 'assets/images/bg_status_female.jpg'
        : 'assets/images/bg_status_male.jpg';
    final cutout = look == HeroLook.female
        ? 'assets/images/hero_status_female.png'
        : 'assets/images/hero_status_male.png';
    final alignment = look == HeroLook.female
        ? const Alignment(-0.45, 0)
        : const Alignment(-0.42, 0);
    return Stack(fit: StackFit.expand, children: [
      // 바탕: 같은 그림을 흐리게
      ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Image.asset(asset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => const SizedBox()),
      ),
      // 각성자 전신
      Positioned(
        top: top,
        left: 0,
        right: 0,
        bottom: badgeOverlap,
        child: ShaderMask(
          // 위아래 가장자리를 바탕에 녹인다
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00FFFFFF),
            ],
            stops: [0, 0.04, 0.9, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: Stack(fit: StackFit.expand, children: [
            // 배경: 살짝 흐리고 어둡게 눌러서 뒤로 물린다
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                    Color(0x990B0D26), BlendMode.srcATop),
                child: Image.asset(asset,
                    fit: BoxFit.cover,
                    alignment: alignment,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ),
            // 각성자 둘레의 금빛 후광
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                    AppColors.goldBright.withValues(alpha: 0.75),
                    BlendMode.srcIn),
                child: Image.asset(cutout,
                    fit: BoxFit.cover,
                    alignment: alignment,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ),
            // 각성자 (배경과 분리된 그림, 원래 자리 그대로)
            Image.asset(cutout,
                fit: BoxFit.cover,
                alignment: alignment,
                semanticLabel: '기본 각성자',
                errorBuilder: (_, __, ___) => const SizedBox()),
          ]),
        ),
      ),
    ]);
  }
}

// ───────────────────────────────────────────────────────────── 상태 패널

/// '2시간 10분' / '12분'
String _left(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return m > 0 ? '$h시간 $m분' : '$h시간';
  return '${d.inMinutes < 1 ? 1 : d.inMinutes}분';
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.player,
    required this.hp,
    required this.mp,
    this.spiritAway,
    this.onOpenDungeon,
  });

  final PlayerState player;
  final int hp;
  final int mp;
  final String? spiritAway;
  final VoidCallback? onOpenDungeon;

  @override
  Widget build(BuildContext context) {
    final gauge = player.gauge;
    final maxHp = player.maxHp;

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
                  icon: 'key',
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
                  icon: 'vitality',
                  label: hp <= 0 ? 'HP · 쉬어야 해요' : 'HP',
                  ratio: maxHp == 0 ? 0 : hp / maxHp,
                  colors: BarColors.hp,
                  value: '${comma(hp)} / ${comma(maxHp)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Gauge(
            icon: 'mp',
            label: spiritAway ?? '정령 MP',
            ratio: mp / RuleConstants.mpMax,
            colors: BarColors.mana,
            value: '$mp / ${RuleConstants.mpMax}',
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
                  icon: 'vitality',
                  name: '체력',
                  value: player.stats.vitality),
              _StatTile(
                  icon: 'agility',
                  name: '민첩',
                  value: player.stats.agility),
              _StatTile(
                  icon: 'wisdom',
                  name: '지력',
                  value: player.stats.wisdom),
              _StatTile(
                  icon: 'spirit',
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
  final String icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          GameIcon(icon, size: 20),
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

  final String icon;
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
          GameIcon(icon, size: 26),
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
  const _QuestPanel({required this.quests});

  final List<QuestProgress> quests;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const GameIcon('quest', size: 28),
            const SizedBox(width: 8),
            Text('일일 퀘스트', style: AppText.title(19)),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.gold.withValues(alpha: 0.4),
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
          Row(mainAxisSize: MainAxisSize.min, children: [
            const GameIcon('check', size: 24),
            const SizedBox(width: 2),
            Text('완료', style: AppText.title(15)),
          ])
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
