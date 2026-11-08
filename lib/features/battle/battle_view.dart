import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 자동 전투 화면 (목업 구도): 동굴 배경 위 각성자 vs 몬스터,
/// 아래에 체력 막대, 정화 수, 둥근 스킬 버튼 '불씨의 일격'.
///
/// [tickInterval] 마다 [Battle.tick] 을 부르고, 끝나면 [onFinished] 를 한 번 부른다.
class BattleView extends StatefulWidget {
  const BattleView({
    super.key,
    required this.battle,
    required this.onFinished,
    this.tickInterval = const Duration(milliseconds: 900),
    this.playerName = '각성자',
    this.look = HeroLook.male,
  });

  final Battle battle;
  final VoidCallback onFinished;
  final Duration tickInterval;
  final String playerName;
  final HeroLook look;

  @override
  State<BattleView> createState() => _BattleViewState();
}

class _BattleViewState extends State<BattleView> {
  Timer? _timer;
  bool _reported = false;

  Battle get _b => widget.battle;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.tickInterval, (_) => _step());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _step() {
    if (!mounted) return;
    setState(_b.tick);
    _checkEnd();
  }

  void _skill() {
    setState(() => _b.useSkill());
    _checkEnd();
  }

  void _checkEnd() {
    if (!_b.isOver || _reported) return;
    _reported = true;
    _timer?.cancel();
    // 마지막 타격을 잠깐 보여 주고 결과로 넘어간다
    Timer(widget.tickInterval, () {
      if (mounted) widget.onFinished();
    });
  }

  String get _floorLabel {
    if (_b.floors.length == 1) return '필드 전투';
    return _b.foe.isBoss
        ? 'BOSS'
        : '${_b.floor + 1}층 / ${_b.floors.length - 1}층';
  }

  @override
  Widget build(BuildContext context) {
    final foe = _b.foe;
    final cleared = _b.phase == BattlePhase.floorCleared ||
        _b.phase == BattlePhase.cleared;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Scene(
          foe: foe,
          cleared: cleared,
          floorLabel: _floorLabel,
          dealt: _b.lastDealt,
          skill: _b.lastWasSkill,
          look: widget.look,
        ),
        const SizedBox(height: 10),
        OrnatePanel(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          child: Row(children: [
            _Avatar(look: widget.look),
            const SizedBox(width: 8),
            Expanded(
              child: _HpColumn(
                name: widget.playerName,
                hp: _b.playerHp,
                maxHp: _b.playerMaxHp,
                colors: BarColors.hp,
                note: _b.lastTaken > 0 ? '-${comma(_b.lastTaken)}' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HpColumn(
                name: cleared ? foe.info.purifiedName : foe.info.name,
                hp: _b.foeHp,
                maxHp: foe.maxHp,
                colors: BarColors.foe,
                alignEnd: true,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: OrnatePanel(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.diamond_rounded,
                      color: Color(0xFFB08CF0), size: 34),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('정화',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      Text('${_b.purified.length} / ${_b.floors.length}',
                          style: AppText.title(26, color: AppColors.text)),
                    ],
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 16),
            _SkillOrb(
              ratio: _b.skillRatio,
              ready: _b.skillReady,
              onPressed: _skill,
            ),
            const SizedBox(width: 6),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────────────────────────── 전투 장면

class _Scene extends StatelessWidget {
  const _Scene({
    required this.foe,
    required this.cleared,
    required this.floorLabel,
    required this.dealt,
    required this.skill,
    required this.look,
  });

  final Foe foe;
  final bool cleared;
  final String floorLabel;
  final int dealt;
  final bool skill;
  final HeroLook look;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 360,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/bg_battle.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF1B1840))),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xAA0B0D26)],
                  stops: [0.45, 1],
                ),
              ),
            ),
            // 바닥의 마법진 빛
            Positioned(
              left: 20,
              bottom: 18,
              child: Container(
                width: 150,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(75, 13)),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.7), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        blurRadius: 16),
                  ],
                ),
              ),
            ),
            // 각성자
            Positioned(
              left: 30,
              bottom: 26,
              height: 210,
              child: HeroSprite(
                  look: look, pose: cleared ? HeroPose.victory : HeroPose.attack),
            ),
            // 몬스터
            Positioned(
              right: 14,
              top: 70,
              width: 170,
              height: 170,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: MonsterPicture(
                  key: ValueKey('${foe.monster.name}_$cleared'),
                  monster: foe.monster,
                  size: 170,
                  purified: cleared,
                ),
              ),
            ),
            // 일격의 빛
            if (skill && !cleared)
              Positioned(
                right: 60,
                top: 110,
                child: Icon(Icons.auto_awesome_rounded,
                    size: 90,
                    color: AppColors.goldBright.withValues(alpha: 0.9),
                    shadows: const [
                      Shadow(color: AppColors.gold, blurRadius: 30),
                    ]),
              ),
            // 준 피해
            Positioned(
              right: 26,
              top: 46,
              child: Text(
                cleared
                    ? '정화!'
                    : dealt > 0
                        ? '-${comma(dealt)}'
                        : '',
                style: AppText.title(skill ? 34 : 26,
                    color: cleared ? AppColors.goldBright : Colors.white),
              ),
            ),
            // 층 표시
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xCC14173E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: foe.isBoss
                            ? AppColors.gauge
                            : AppColors.gold.withValues(alpha: 0.8)),
                  ),
                  child: Text(floorLabel,
                      style: AppText.title(17,
                          color: foe.isBoss
                              ? AppColors.gauge
                              : AppColors.goldBright)),
                ),
              ),
            ),
            // 불씨의 응원
            Positioned(
              left: 8,
              bottom: 6,
              child: Row(children: [
                Image.asset('assets/images/bulssi.png',
                    width: 54,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_fire_department_rounded,
                        color: AppColors.gold)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBF5E6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(cleared ? '정화했어!' : '할 수 있어!',
                      style: const TextStyle(
                          color: AppColors.night,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.look, this.size = 46});

  final HeroLook look;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldBright, width: 1.6),
      ),
      child: ClipOval(
        child: Image.asset(
          look == HeroLook.female
              ? 'assets/images/portrait_female.jpg'
              : 'assets/images/portrait_male.jpg',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person_rounded, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _HpColumn extends StatelessWidget {
  const _HpColumn({
    required this.name,
    required this.hp,
    required this.maxHp,
    required this.colors,
    this.note,
    this.alignEnd = false,
  });

  final String name;
  final int hp;
  final int maxHp;
  final List<Color> colors;
  final String? note;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
            if (note != null) ...[
              const SizedBox(width: 6),
              Text(note!,
                  style:
                      const TextStyle(color: Color(0xFFE57373), fontSize: 12)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        GlowBar(
            ratio: maxHp == 0 ? 0 : hp / maxHp, colors: colors, height: 11),
        const SizedBox(height: 3),
        Text('HP ${comma(hp)} / ${comma(maxHp)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      ],
    );
  }
}

/// 둥근 스킬 버튼: 바깥 고리가 충전 정도
class _SkillOrb extends StatelessWidget {
  const _SkillOrb({
    required this.ratio,
    required this.ready,
    required this.onPressed,
  });

  final double ratio;
  final bool ready;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: ready ? onPressed : null,
          child: SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 6,
                    color: AppColors.goldBright,
                    backgroundColor: AppColors.track,
                  ),
                ),
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: ready
                          ? const [Color(0xFFFFF4C8), Color(0xFFE8B04A),
                              Color(0xFF8A5A1C)]
                          : const [Color(0xFF4A4F86), Color(0xFF262A5A),
                              Color(0xFF181B45)],
                    ),
                    border: Border.all(
                        color: AppColors.goldBright, width: ready ? 2 : 1),
                    boxShadow: ready
                        ? [
                            BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.8),
                                blurRadius: 26,
                                spreadRadius: 2),
                          ]
                        : null,
                  ),
                  child: Icon(Icons.flare_rounded,
                      size: 46,
                      color: ready
                          ? const Color(0xFF5A3410)
                          : AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: ready ? onPressed : null,
          child: Text(ready ? '불씨의 일격!' : '충전 중',
              style: AppText.title(15,
                  color: ready ? AppColors.goldBright : AppColors.textMuted)),
        ),
      ],
    );
  }
}

enum HeroPose { attack, victory }

/// 각성자 SD 그림 (공격·승리 자세). 그림이 없으면 서 있는 그림이나 초상화로 대신한다.
/// 파일 이름: hero_attack_male.png, hero_victory_female.png ...
class HeroSprite extends StatelessWidget {
  const HeroSprite({super.key, required this.look, required this.pose});

  final HeroLook look;
  final HeroPose pose;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/hero_${pose.name}_${look.name}.png',
      fit: BoxFit.contain,
      semanticLabel: '각성자',
      errorBuilder: (_, __, ___) => look == HeroLook.male
          ? Image.asset('assets/images/hero_chibi_male.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                  size: 140, color: AppColors.textMuted))
          : const Padding(
              padding: EdgeInsets.only(top: 60),
              child: _Avatar(look: HeroLook.female, size: 120),
            ),
    );
  }
}

/// 몬스터 그림. 그림 파일이 없으면 아이콘으로 대신한다.
class MonsterPicture extends StatelessWidget {
  const MonsterPicture({
    super.key,
    required this.monster,
    this.size = 64,
    this.purified = false,
  });

  final MonsterId monster;
  final double size;

  /// true 면 정화된 모습
  final bool purified;

  static IconData iconOf(MonsterId id) => switch (id) {
        MonsterId.ashSlime => Icons.water_drop_rounded,
        MonsterId.labyrinthBat => Icons.nights_stay_rounded,
        MonsterId.roughWaterSpirit => Icons.waves_rounded,
        MonsterId.shadowButterfly => Icons.flutter_dash_rounded,
        MonsterId.lostStoneSpirit => Icons.landscape_rounded,
        MonsterId.labyrinthWarden => Icons.shield_moon_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final info = Monsters.info(monster);
    final label = purified ? info.purifiedName : info.name;
    return Image.asset(
      purified ? info.purifiedAsset : info.asset,
      width: size,
      height: size,
      semanticLabel: label,
      errorBuilder: (_, __, ___) => Icon(
        iconOf(monster),
        size: size * 0.7,
        color: purified ? AppColors.goldBright : const Color(0xFFB8B2C8),
        semanticLabel: label,
      ),
    );
  }
}
