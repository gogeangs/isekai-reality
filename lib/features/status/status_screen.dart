import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models/armory.dart';
import '../../core/models/player_state.dart';
import '../../core/rules/rules.dart';
import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/bulssi_lines.dart';
import '../bulssi/spirit_art.dart';
import '../smithy/equipment_view.dart';
import '../bulssi/bulssi_mood.dart';

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
    this.maxHp,
    this.mpMax = RuleConstants.mpMax,
    this.stats,
    this.unspentPoints = 0,
    this.onOpenStats,
    this.lifeLine,
    this.armory,
    this.onSlot,
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

  /// 장비를 입은 최대 HP (없으면 레벨·스탯으로)
  final int? maxHp;

  /// 최대 MP (지능으로 늘어난다)
  final int mpMax;

  /// 보여 줄 스탯 합계 (없으면 생활 스탯), 나눌 포인트, 분배 화면 열기
  final Stats? stats;
  final int unspentPoints;
  final VoidCallback? onOpenStats;

  /// 생활 보너스가 올랐을 때 정령이 할 한 줄 (있으면 평소 대사 대신)
  final String? lifeLine;

  /// 장비 6칸 (없으면 칸을 그리지 않는다), 칸을 눌렀을 때
  final Armory? armory;
  final ValueChanged<EquipSlot>? onSlot;

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
    final topHp = maxHp ?? player.maxHp;
    final curHp = hp ?? topHp;
    final curMp = mp ?? mpMax;
    final full = curHp >= topHp && curMp >= mpMax;
    final line = lifeLine ?? BulssiLines.forStatus(
      today: today,
      gauge: player.gauge,
      now: DateTime.now(),
      hpRatio: curHp / topHp,
      mpRatio: curMp / mpMax,
      resting: restLeft != null,
      spiritAway: spiritAway != null,
    );
    // 11-10 정령 표정: 쉬는 중 졸림, HP가 낮으면 걱정, 퀘스트를 다 하면 축하
    final mood = restLeft != null
        ? SpiritMood.sleepy
        : curHp < topHp * 0.3
            ? SpiritMood.worried
            : QuestRules.allDone(today)
                ? SpiritMood.cheer
                : SpiritMood.normal;

    // 11-11 #66: 한 화면에 고정 (당겨도 끌려 내려가지 않게). 작은 기기에서만
    // 끝에서 튕기지 않는 스크롤. 무대 그림은 상태 표시줄 뒤까지 깐다.
    return NightBackground(
      statusScrim: false,
      child: LayoutBuilder(builder: (context, box) {
        // 아래 정보(레벨·HP·MP·스탯)가 차지하는 높이 (대략)
        final below = 300.0 + (restLeft != null ? 48 : 0);
        final heroH = (box.maxHeight - below).clamp(320.0, 470.0 + top);
        return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─────────── 각성자 그림 + 그 오른쪽 빈자리의 정령 (11-10 A3)
          // 날씨 칩은 게임에 영향이 없어 평소에는 숨긴다 (C6),
          // 눈 문장은 누를 기능이 없어 뺐다 (A4).
          SizedBox(
            height: heroH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // HP 0이면 지친 각성자 그림
                _HeroArt(look: look, top: top, tired: curHp <= 0),
                // 장비 칸 (11-11 #44): 왼쪽 무기·장갑·장신구, 오른쪽 머리·몸·신발.
                // 말풍선(오른쪽 위) 아래에서 시작하고, 각성자·마법진은 가리지 않게 작게
                if (armory != null) ...[
                  Positioned(
                    left: 10,
                    top: top + 168,
                    child: _SlotColumn(
                      slots: const [
                        EquipSlot.weapon,
                        EquipSlot.hands,
                        EquipSlot.accessory,
                      ],
                      armory: armory!,
                      onTap: onSlot,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: top + 168,
                    child: _SlotColumn(
                      slots: const [
                        EquipSlot.head,
                        EquipSlot.body,
                        EquipSlot.feet,
                      ],
                      armory: armory!,
                      onTap: onSlot,
                    ),
                  ),
                ],
                // 정령은 오른쪽 위 빈자리: 각성자 얼굴·손·지도를 가리지 않게
                Positioned(
                  top: top + 58, // 위쪽 설정 버튼 아래
                  right: 8,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.5),
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
                // 11-10 #25: 여관에서 쉬는 중일 때만 한 줄 (일일 퀘스트는 의뢰 게시판으로)
                if (restLeft != null) ...[
                  const SizedBox(height: 10),
                  _RestLine(
                    text: full
                        ? '여관에서 쉬는 중 · 회복 완료, 보너스까지 ${_left(restLeft!)}'
                        : '여관에서 쉬는 중 · ${_left(restLeft!)} 남음',
                    onTap: onOpenInn,
                  ),
                ],
                const SizedBox(height: 12),
                _StatusPanel(
                  player: player,
                  maxHp: topHp,
                  mpMax: mpMax,
                  hp: curHp,
                  mp: curMp,
                  spiritAway: spiritAway,
                ),
                const SizedBox(height: 12),
                _StatsSection(
                    stats: stats ?? player.stats,
                    unspent: unspentPoints,
                    onOpen: onOpenStats),
              ],
            ),
          ),
        ],
      ),
      );
      }),
    );
  }
}

// ───────────────────────────────────────────────────────────── 각성자 그림

/// 무대형 배경 (11-11 #39): 남·여 공통 무대 그림, 가운데 마법진 위에 각성자.
/// 은은한 테두리 빛과 발밑 그림자로 배경과 나눈다. 오른쪽 위 하늘은 정령 말풍선 자리.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.look, required this.top, this.tired = false});

  final HeroLook look;

  /// HP 0: 지친 모습
  final bool tired;

  /// 상태 표시줄 높이
  final double top;

  @override
  Widget build(BuildContext context) {
    final hero = 'assets/images/hero_stand_${tired ? 'tired_' : ''}'
        '${look == HeroLook.female ? 'female' : 'male'}.png';
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      // 마법진 가운데 (무대 그림의 아래쪽 1/4쯤)
      final floorY = h * 0.86;
      final heroH = (floorY - top - 8).clamp(120.0, 520.0);
      return Stack(fit: StackFit.expand, children: [
        // 무대: 아래쪽은 밤하늘 배경에 경계 없이 녹인다
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.86, 1],
          ).createShader(r),
          blendMode: BlendMode.dstIn,
          child: Image.asset('assets/images/bg_status_stage.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.55),
              errorBuilder: (_, __, ___) => Image.asset(
                  look == HeroLook.female
                      ? 'assets/images/bg_status_female.jpg'
                      : 'assets/images/bg_status_male.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox())),
        ),
        // 발밑 그림자
        Positioned(
          left: box.maxWidth / 2 - heroH * 0.22,
          width: heroH * 0.44,
          top: floorY - heroH * 0.035,
          height: heroH * 0.07,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.all(Radius.elliptical(heroH, heroH * 0.1)),
              gradient: const RadialGradient(colors: [
                Color(0xAA05060F),
                Color(0x0005060F),
              ]),
            ),
          ),
        ),
        // 각성자 + 테두리 빛
        Positioned(
          left: 0,
          right: 0,
          top: floorY - heroH,
          height: heroH,
          child: Stack(alignment: Alignment.bottomCenter, children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                    Color(0xCCFFF1C9), BlendMode.srcIn),
                child: Image.asset(hero,
                    height: heroH,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ),
            Image.asset(hero,
                height: heroH,
                fit: BoxFit.contain,
                semanticLabel: '기본 각성자',
                errorBuilder: (_, __, ___) => const SizedBox()),
          ]),
        ),
      ]);
    });
  }
}

/// 장비 칸 3개 세로 줄
class _SlotColumn extends StatelessWidget {
  const _SlotColumn(
      {required this.slots, required this.armory, required this.onTap});

  final List<EquipSlot> slots;
  final Armory armory;
  final ValueChanged<EquipSlot>? onTap;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final slot in slots)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GearSlot(
              slot: slot,
              item: armory.wornIn(slot),
              onTap: onTap == null ? null : () => onTap!(slot),
            ),
          ),
      ]);
}

class _GearSlot extends StatelessWidget {
  const _GearSlot({required this.slot, this.item, this.onTap});

  final EquipSlot slot;
  final EquipItem? item;
  final VoidCallback? onTap;

  static const double size = 50;

  @override
  Widget build(BuildContext context) {
    final it = item;
    final color = it == null ? AppColors.gold : equipGradeColor(it.grade);
    return Semantics(
      button: true,
      label: '${EquipmentRules.slotLabel(slot)} 칸${it == null ? ', 비어 있음' : ', ${it.name}'}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xCC12153A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: color.withValues(alpha: it == null ? 0.45 : 0.95),
                width: it == null ? 1 : 2),
            boxShadow: it != null && it.grade.index >= EquipGrade.blue.index
                ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                : null,
          ),
          child: Stack(children: [
            Center(
              child: it == null
                  ? Icon(slotIcon(slot),
                      color: AppColors.textMuted.withValues(alpha: 0.7),
                      size: 22)
                  : Image.asset('assets/images/${it.info.asset}.png',
                      width: size - 10,
                      height: size - 10,
                      errorBuilder: (_, __, ___) =>
                          Icon(slotIcon(slot), color: color, size: 24)),
            ),
            if (it != null && it.enhance > 0)
              Positioned(
                right: 3,
                bottom: 1,
                child: Text('+${it.enhance}',
                    style: const TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Colors.black, blurRadius: 3)])),
              ),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── 상태 패널

/// 여관에서 쉬는 중 한 줄 (누르면 여관)
class _RestLine extends StatelessWidget {
  const _RestLine({required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xCC12153A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          const GameIcon('moon', size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

/// '2시간 10분' / '12분'
String _left(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return m > 0 ? '$h시간 $m분' : '$h시간';
  return '${d.inMinutes < 1 ? 1 : d.inMinutes}분';
}

/// 오늘 정보: HP | 정령 MP 나란히 (11-11 #68: 던전 게이지·던전 열기는 지도로 옮겼다)
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.player,
    required this.maxHp,
    required this.mpMax,
    required this.hp,
    required this.mp,
    this.spiritAway,
  });

  final PlayerState player;
  final int maxHp;
  final int hp;
  final int mp;
  final int mpMax;
  final String? spiritAway;

  @override
  Widget build(BuildContext context) {
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
                  label: spiritAway == null
                      ? mpLabel(context)
                      : '${mpLabel(context)} · 원정 중',
                  ratio: mp / mpMax,
                  colors: BarColors.mana,
                  value: '$mp / $mpMax',
                ),
              ),
            ],
          ),
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

/// 스탯 5종 한 줄 (11-11 #50). 누르면 포인트 분배 화면.
/// 나눌 포인트가 있으면 알림 점. 숫자는 합계만 보여 준다.
class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats, this.unspent = 0, this.onOpen});

  final Stats stats;
  final int unspent;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            const GameIcon('spirit', size: 20),
            if (unspent > 0)
              const Positioned(
                right: -3,
                top: -3,
                child: _Dot(),
              ),
          ]),
          const SizedBox(width: 6),
          const Text('스탯',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              [
                for (final k in StatKind.values) '${k.label} ${stats.of(k)}',
              ].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          if (unspent > 0)
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFE5484D),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('+$unspent',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.goldBright),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: const Color(0xFFE5484D),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.2),
        ),
      );
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

