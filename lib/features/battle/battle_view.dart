import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';

/// 자동 전투 화면 조각. [tickInterval] 마다 [Battle.tick] 을 부르고,
/// 끝나면 [onFinished] 를 한 번 부른다. 스킬 버튼 하나.
class BattleView extends StatefulWidget {
  const BattleView({
    super.key,
    required this.battle,
    required this.onFinished,
    this.tickInterval = const Duration(milliseconds: 900),
    this.playerName = '각성자',
  });

  final Battle battle;
  final VoidCallback onFinished;
  final Duration tickInterval;
  final String playerName;

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
    return _b.foe.isBoss ? 'BOSS' : '${_b.floor + 1}층 / ${_b.floors.length - 1}층';
  }

  @override
  Widget build(BuildContext context) {
    final foe = _b.foe;
    final cleared = _b.phase == BattlePhase.floorCleared ||
        _b.phase == BattlePhase.cleared;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(_floorLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: foe.isBoss ? AppColors.gauge : AppColors.goldBright,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const SizedBox(height: 12),
        _FoeCard(foe: foe, hp: _b.foeHp, cleared: cleared),
        const SizedBox(height: 8),
        SizedBox(
          height: 28,
          child: Center(
            child: Text(
              cleared
                  ? '${foe.info.purifiedName}(으)로 정화!'
                  : _b.lastDealt > 0
                      ? '${_b.lastWasSkill ? '불씨의 일격! ' : ''}-${comma(_b.lastDealt)}'
                      : '',
              style: TextStyle(
                color: cleared ? AppColors.goldBright : AppColors.gauge,
                fontSize: _b.lastWasSkill ? 20 : 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _HpBar(
          label: widget.playerName,
          hp: _b.playerHp,
          maxHp: _b.playerMaxHp,
          color: const Color(0xFF6FD08C),
          note: _b.lastTaken > 0 ? '-${comma(_b.lastTaken)}' : null,
        ),
        const SizedBox(height: 16),
        _SkillButton(
          ratio: _b.skillRatio,
          ready: _b.skillReady,
          onPressed: _skill,
        ),
      ],
    );
  }
}

class _FoeCard extends StatelessWidget {
  const _FoeCard({required this.foe, required this.hp, required this.cleared});

  final Foe foe;
  final int hp;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    final info = foe.info;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: cleared ? AppColors.goldBright : AppColors.panelBorder,
            width: cleared ? 2 : 1),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: AnimatedOpacity(
              opacity: cleared ? 0.55 : 1,
              duration: const Duration(milliseconds: 300),
              child: MonsterPicture(monster: foe.monster, size: 140),
            ),
          ),
          const SizedBox(height: 8),
          Text(cleared ? info.purifiedName : info.name,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _HpBar(
            hp: hp,
            maxHp: foe.maxHp,
            color: const Color(0xFF9C93B8), // 잿빛
          ),
        ],
      ),
    );
  }
}

/// 몬스터 그림. 그림 파일이 없으면 아이콘으로 대신한다.
class MonsterPicture extends StatelessWidget {
  const MonsterPicture({super.key, required this.monster, this.size = 64});

  final MonsterId monster;
  final double size;

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
    return Image.asset(
      info.asset,
      width: size,
      height: size,
      semanticLabel: info.name,
      errorBuilder: (_, __, ___) => Icon(
        iconOf(monster),
        size: size * 0.7,
        color: const Color(0xFFB8B2C8),
        semanticLabel: info.name,
      ),
    );
  }
}

class _HpBar extends StatelessWidget {
  const _HpBar({
    required this.hp,
    required this.maxHp,
    required this.color,
    this.label,
    this.note,
  });

  final int hp;
  final int maxHp;
  final Color color;
  final String? label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp == 0 ? 0.0 : (hp / maxHp).clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          if (label != null)
            Text(label!,
                style: const TextStyle(
                    color: AppColors.text, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (note != null)
            Text('$note  ',
                style: const TextStyle(color: Color(0xFFE57373), fontSize: 13)),
          Text('HP ${comma(hp)} / ${comma(maxHp)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            color: color,
            backgroundColor: AppColors.track,
          ),
        ),
      ],
    );
  }
}

class _SkillButton extends StatelessWidget {
  const _SkillButton({
    required this.ratio,
    required this.ready,
    required this.onPressed,
  });

  final double ratio;
  final bool ready;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: LinearProgressIndicator(
              value: ratio,
              color: AppColors.gauge.withValues(alpha: 0.45),
              backgroundColor: AppColors.track,
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: BorderSide(
                  color: ready ? AppColors.goldBright : AppColors.panelBorder,
                  width: ready ? 2.5 : 1),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: ready ? onPressed : null,
              child: Center(
                child: Text(
                  ready ? '불씨의 일격!' : '불씨의 일격 충전 중',
                  style: TextStyle(
                    color: ready ? AppColors.goldBright : AppColors.textMuted,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
