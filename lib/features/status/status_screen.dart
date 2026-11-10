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
import '../bulssi/spirit_art.dart';

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
    this.onOpenBag,
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

  /// 가방 열기 (없으면 버튼을 그리지 않음)
  final VoidCallback? onOpenBag;

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
    final curHp = hp ?? player.maxHp;
    final curMp = mp ?? RuleConstants.mpMax;
    final full = curHp >= player.maxHp && curMp >= RuleConstants.mpMax;
    final line = BulssiLines.forStatus(
      today: today,
      gauge: player.gauge,
      now: DateTime.now(),
      hpRatio: curHp / player.maxHp,
      mpRatio: curMp / RuleConstants.mpMax,
      resting: restLeft != null,
      spiritAway: spiritAway != null,
    );
    // 11-10 정령 표정: 쉬는 중 졸림, HP가 낮으면 걱정, 퀘스트를 다 하면 축하
    final mood = restLeft != null
        ? SpiritMood.sleepy
        : curHp < player.maxHp * 0.3
            ? SpiritMood.worried
            : QuestRules.allDone(today)
                ? SpiritMood.cheer
                : SpiritMood.normal;

    return NightBackground(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ─────────── 각성자 그림 + 그 오른쪽 빈자리의 정령 (11-10 A3)
          // 날씨 칩은 게임에 영향이 없어 평소에는 숨긴다 (C6),
          // 눈 문장은 누를 기능이 없어 뺐다 (A4).
          SizedBox(
            height: 340 + top,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // HP 0이면 지친 각성자 그림
                _HeroArt(look: look, top: top, tired: curHp <= 0),
                // 정령은 오른쪽 위 빈자리: 각성자 얼굴·손·지도를 가리지 않게
                Positioned(
                  top: top + 6,
                  right: 8,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.46),
                    child: ArtSpirit(line: line, mood: mood, size: 44),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 레벨 · 칭호 · 경험치 한 줄 (C1). 큰 배지는 레벨업 연출에서만.
                _LevelLine(
                  player: player,
                  title: equippedTitle == null
                      ? '새내기 각성자'
                      : TitleRules.info(equippedTitle!).name,
                ),
                const SizedBox(height: 12),
                _QuestPanel(
                  quests: QuestRules.forDay(today),
                  allDone: QuestRules.allDone(today),
                  streak: QuestRules.allDoneStreak(player.history),
                ),
                const SizedBox(height: 12),
                _StatusPanel(
                  player: player,
                  hp: curHp,
                  mp: curMp,
                  spiritAway: spiritAway,
                  onOpenBag: onOpenBag,
                  onOpenDungeon: onOpenDungeon,
                ),
                if (onOpenInn != null || onOpenShop != null) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: _TownTile(
                        asset: 'map_inn',
                        title: '여관',
                        // C5: 상태와 남은 시간을 두 줄로 (말줄임 없이)
                        subtitle: restLeft == null
                            ? '하루 마무리'
                            : full
                                ? '회복 완료'
                                : '쉬는 중',
                        detail: restLeft == null
                            ? null
                            : full
                                ? '보너스까지 ${_left(restLeft!)}'
                                : '${_left(restLeft!)} 남음',
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
                const SizedBox(height: 12),
                _StatsSection(player: player),
              ],
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
    this.detail,
    this.onTap,
  });

  final String asset;
  final String title;
  final String subtitle;

  /// 둘째 줄 (예: '3시간 10분 남음')
  final String? detail;
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
                if (detail != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(detail!,
                        maxLines: 1,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 12)),
                  ),
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
  const _HeroArt({required this.look, required this.top, this.tired = false});

  final HeroLook look;

  /// HP 0: 지친 모습
  final bool tired;

  /// 상태 표시줄 높이
  final double top;

  /// 아래 레벨 배지가 겹치는 높이
  static const double badgeOverlap = 12;

  @override
  Widget build(BuildContext context) {
    final asset = look == HeroLook.female
        ? 'assets/images/bg_status_female.jpg'
        : 'assets/images/bg_status_male.jpg';
    final cutout = 'assets/images/hero_status_${tired ? 'tired_' : ''}'
        '${look == HeroLook.female ? 'female' : 'male'}.png';
    final alignment = look == HeroLook.female
        ? const Alignment(-0.45, 0)
        : const Alignment(-0.42, 0);
    return Stack(fit: StackFit.expand, children: [
      // 바탕: 같은 그림을 흐리게. 아래쪽은 밤하늘 배경에 경계 없이 녹인다.
      // 흐림이 상자 밖으로 번지면 배지 뒤에 띠가 생겨서 잘라 둔다.
      ClipRect(
        child: ShaderMask(
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          stops: [0, 0.62, 1],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
              sigmaX: 10, sigmaY: 10, tileMode: TileMode.decal),
          child: ColorFiltered(
            // 살짝 어둡게 눌러 각성자가 앞으로 나오게
            colorFilter:
                const ColorFilter.mode(Color(0x660B0D26), BlendMode.srcATop),
            child: Image.asset(asset,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        ),
      ),
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
            stops: [0, 0.02, 0.92, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: Stack(fit: StackFit.expand, children: [
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

/// 오늘 정보: HP | 정령 MP 나란히, 던전 게이지·열쇠는 던전 버튼 바로 위 (11-10 C3)
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.player,
    required this.hp,
    required this.mp,
    this.spiritAway,
    this.onOpenBag,
    this.onOpenDungeon,
  });

  final PlayerState player;
  final int hp;
  final int mp;
  final String? spiritAway;
  final VoidCallback? onOpenBag;
  final VoidCallback? onOpenDungeon;

  @override
  Widget build(BuildContext context) {
    final gauge = player.gauge;
    final maxHp = player.maxHp;

    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Gauge(
                  icon: 'vitality',
                  label: hp <= 0 ? 'HP · 쉬어야 해요' : 'HP',
                  ratio: maxHp == 0 ? 0 : hp / maxHp,
                  colors: BarColors.hp,
                  value: '${comma(hp)} / ${comma(maxHp)}',
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Gauge(
                  icon: 'mp',
                  label: spiritAway == null ? '정령 MP' : '정령 MP · 원정 중',
                  ratio: mp / RuleConstants.mpMax,
                  colors: BarColors.mana,
                  value: '$mp / ${RuleConstants.mpMax}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.gold.withValues(alpha: 0.25)),
          const SizedBox(height: 10),
          _Gauge(
            icon: 'key',
            label: '던전 게이지 · 열쇠 ${gauge.keysAvailable}',
            ratio: gauge.ratio,
            colors: BarColors.gauge,
            value: gauge.dailyKeyLimitReached
                ? '오늘은 다 모았어요'
                : '${comma(gauge.stepsIntoNextKey)} / '
                    '${comma(gauge.stepsPerKey)}보',
          ),
          if (onOpenDungeon != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: FrameButton(
                  onPressed: onOpenDungeon,
                  icon: Icons.door_front_door_rounded,
                  height: 46,
                  // 열쇠 개수는 바로 위 게이지에 있어 짧게
                  label: gauge.keysAvailable > 0 ? '던전 열기' : '열쇠 없음',
                ),
              ),
              if (onOpenBag != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 128,
                  child: FrameButton(
                    onPressed: onOpenBag,
                    gameIcon: 'bag',
                    height: 46,
                    label: '가방',
                  ),
                ),
              ],
            ]),
          ],
        ],
      ),
    );
  }
}

/// 레벨 · 칭호 · 경험치 막대 한 줄 (11-10 C1)
class _LevelLine extends StatelessWidget {
  const _LevelLine({required this.player, required this.title});

  final PlayerState player;
  final String title;

  @override
  Widget build(BuildContext context) {
    final level = player.level;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      decoration: BoxDecoration(
        color: const Color(0xE6161A44),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        Text('Lv.${level.level}', style: AppText.level(17)),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GlowBar(ratio: level.ratio, colors: BarColors.exp, height: 7),
        ),
        const SizedBox(width: 8),
        Text(
          '${comma(level.expIntoLevel)}/${comma(level.expToNext)}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ]),
    );
  }
}

/// 스탯 4종 (접어 두고 눌러서 펼친다, 11-10 C2)
class _StatsSection extends StatefulWidget {
  const _StatsSection({required this.player});

  final PlayerState player;

  @override
  State<_StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<_StatsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final st = widget.player.stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(children: [
              const GameIcon('spirit', size: 20),
              const SizedBox(width: 6),
              const Text('스탯',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '체력 ${st.vitality} · 민첩 ${st.agility} · '
                  '지력 ${st.wisdom} · 정신 ${st.spirit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.goldBright),
            ]),
          ),
        ),
        if (_open)
          Row(children: [
            _StatTile(icon: 'vitality', name: '체력', value: st.vitality),
            _StatTile(icon: 'agility', name: '민첩', value: st.agility),
            _StatTile(icon: 'wisdom', name: '지력', value: st.wisdom),
            _StatTile(icon: 'spirit', name: '정신', value: st.spirit),
          ]),
      ],
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
  const _QuestPanel({
    required this.quests,
    required this.allDone,
    required this.streak,
  });

  final List<QuestProgress> quests;
  final bool allDone;

  /// 3개를 모두 마친 날이 이어진 일수 (표시만)
  final int streak;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const GameIcon('quest', size: 26),
            const SizedBox(width: 8),
            Text('일일 퀘스트', style: AppText.title(18)),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                height: 1,
                color: AppColors.gold.withValues(alpha: 0.4),
              ),
            ),
          ]),
          const SizedBox(height: 2),
          for (final q in quests) _QuestRow(quest: q),
          const SizedBox(height: 8),
          _AllDoneRow(done: allDone, streak: streak),
        ],
      ),
    );
  }
}

/// 보상 표시 (아이콘 + 수량)
class _Reward extends StatelessWidget {
  const _Reward({required this.text, this.done = false});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
      decoration: BoxDecoration(
        color: done ? const Color(0x3346E0A0) : const Color(0x33E8B04A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: done
                ? const Color(0xAA6FE3B0)
                : AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        done
            ? const Icon(Icons.check_rounded, size: 15, color: Color(0xFF8FF0C4))
            : const GameIcon('exp', size: 16),
        const SizedBox(width: 3),
        Text(text,
            style: TextStyle(
                color: done ? const Color(0xFF8FF0C4) : AppColors.goldBright,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      ]),
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
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
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
        // 이름은 넓게, 진행 막대는 이름 아래 짧게 (C2)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(keepAll(quest.title),
                  style: const TextStyle(color: AppColors.text, fontSize: 15)),
              const SizedBox(height: 4),
              if (quest.completed)
                Text('완료', style: AppText.title(13))
              else
                Row(children: [
                  SizedBox(
                    width: 70,
                    child: GlowBar(
                      ratio: quest.target == 0
                          ? 0
                          : quest.current / quest.target,
                      colors: BarColors.exp,
                      height: 6,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('$current / $target${quest.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ),
                ]),
            ],
          ),
        ),
        const SizedBox(width: 6),
        _Reward(
            text: 'EXP ${QuestRules.rewardExp}', done: quest.completed),
      ]),
    );
  }
}

/// 3개 모두 완료 보너스 + 연속 달성 일수 (11-10 C2)
class _AllDoneRow extends StatelessWidget {
  const _AllDoneRow({required this.done, required this.streak});

  final bool done;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(colors: [
          AppColors.gold.withValues(alpha: done ? 0.28 : 0.14),
          AppColors.gold.withValues(alpha: 0.04),
        ]),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(children: [
        const GameIcon('medal', size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(done ? '모두 완료!' : '3개 모두 완료하면 보너스',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              Text(
                streak > 0 ? '연속 달성 $streak일째' : '연속 달성을 시작해 보세요',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
        _Reward(text: 'EXP +${QuestRules.allDoneBonusExp}', done: done),
      ]),
    );
  }
}
