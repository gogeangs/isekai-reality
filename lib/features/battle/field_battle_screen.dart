import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart';
import '../town/material_view.dart';
import 'battle_view.dart';
import 'hero_rig.dart';
import 'modifier_view.dart';

/// 지도에서 만난 필드 몬스터를 정화하는 짧은 전투 (한 마리)
class FieldBattleScreen extends StatefulWidget {
  const FieldBattleScreen({
    super.key,
    required this.controller,
    required this.spawn,
    this.tickInterval = const Duration(milliseconds: 700),
  });

  final AppController controller;
  final FieldSpawn spawn;
  final Duration tickInterval;

  @override
  State<FieldBattleScreen> createState() => _FieldBattleScreenState();
}

class _FieldBattleScreenState extends State<FieldBattleScreen> {
  Battle? _battle;
  bool _done = false;
  int _exp = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.holdNoticesWhile(true); // 칭호 축하는 결과를 닫은 뒤 (#85)
    _battle = widget.controller.startFieldBattle(widget.spawn);
  }

  @override
  void dispose() {
    widget.controller.holdNoticesWhile(false);
    super.dispose();
  }

  Future<void> _finish() async {
    final exp =
        await widget.controller.finishFieldBattle(widget.spawn, _battle!);
    if (!mounted) return;
    setState(() {
      _exp = exp;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    final info = widget.spawn.info;
    final cleared = battle?.phase == BattlePhase.cleared;
    final escaped = battle?.phase == BattlePhase.escaped;
    final spawn = widget.spawn;
    final nameColor = modGradeColor(spawn.grade);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
          children: [
            OrnateTopBar(
              title: info.name,
              onBack: battle == null || _done
                  ? () => Navigator.of(context).maybePop()
                  : null,
            ),
            const SizedBox(height: 10),
            // 11-10 A3: 정령 한 줄은 제목 바로 아래 고정 자리
            if (battle == null) ...[
              BulssiLine(
                  mood: widget.controller.hp <= 0
                      ? SpiritMood.worried
                      : SpiritMood.normal,
                  line: widget.controller.hp <= 0
                      ? '많이 지쳤어. 여관에서 쉬거나 물약을 마시고 오자.'
                      : '움직이는 중엔 위험해! 멈춰 선 다음에 사냥하자.'),
              // HP 0: 지쳐 주저앉은 각성자
              if (widget.controller.hp <= 0)
                SizedBox(
                  height: 240,
                  child: HeroSprite(
                      look: widget.controller.profile.look,
                      pose: HeroPose.tired),
                ),
            ] else if (_done) ...[
              BulssiLine(
                mood: cleared ? SpiritMood.cheer : SpiritMood.worried,
                line: cleared
                    ? (widget.controller.tiredHuntLine ?? info.huntLine)
                    : escaped
                        ? '앗, 도망쳤어! 황금빛 몬스터는 빨라. 다음엔 꼭 잡자!'
                        : '괜찮아, 잃은 건 없어. 조금 더 강해져서 다시 오자!',
              ),
              const SizedBox(height: 4),
            ],
            // 수식어 몬스터: 색 이름과 행동 설명 (11-10 #21)
            if (battle != null && !_done && spawn.modifiers.isNotEmpty) ...[
              Text(spawn.name,
                  textAlign: TextAlign.center,
                  style: AppText.title(19, color: nameColor)),
              const SizedBox(height: 6),
              ModifierPanel(
                  mods: spawn.modifiers, foeCount: battle.floors.length),
              const SizedBox(height: 10),
            ],
            if (battle != null && !_done)
              BattleView(
                battle: battle,
                onFinished: _finish,
                tickInterval: widget.tickInterval,
                playerName: widget.controller.profile.name,
                look: widget.controller.profile.look,
                vibrate: widget.controller.vibrate,
                sound: widget.controller.sound,
                hour: widget.controller.now.hour,
                season: SeasonRules.of(widget.controller.now),
                weapon: weaponKindOf(
                    widget.controller.armory.wornIn(EquipSlot.weapon)?.base),
                background: fieldBackground(
                    widget.controller.landAt(widget.spawn.point)),
                fast: widget.controller.fastBattle,
                onFastChanged: widget.controller.setFastBattle,
                onAutoChanged: (hp, cure) =>
                    widget.controller.setAutoUse(hpPercent: hp, cure: cure),
                poisonTip: !widget.controller.poisonTipSeen,
                onPoisonTipShown: widget.controller.markPoisonTipSeen,
                aura: switch (widget.controller.gear.sets.look) {
                  final set? => Color(BossGearRules.info(set).aura),
                  null => null,
                },
              )
            else if (_done) ...[
              const SizedBox(height: 8),
              Text(
                  cleared
                      ? '사냥 성공!'
                      : escaped
                          ? '도망쳤어요'
                          : '이번엔 물러났어요',
                  textAlign: TextAlign.center, style: AppText.title(30)),
              const SizedBox(height: 12),
              // 묶음 18 #149: 잡은 몬스터는 흐리지 않고 또렷하게, 정화 빛과 함께
              if (cleared)
                Center(child: PurifiedMonster(monster: info.id, size: 130))
              else
                SizedBox(
                  height: 180,
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          AppColors.gold.withValues(alpha: 0.1),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                    MonsterPicture(monster: info.id, size: 150),
                  ]),
                ),
              if (!cleared && !escaped)
                const Padding(
                  key: Key('tiredLine'),
                  padding: EdgeInsets.only(top: 4),
                  child: Text('「${AppController.tiredLine}」',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.text, fontSize: 14)),
                ),
              if (cleared)
                OrnatePanel(
                  ornament: true,
                  child: Column(children: [
                    Text(spawn.name,
                        textAlign: TextAlign.center,
                        style: AppText.title(19, color: nameColor)),
                    if (battle!.floors.length > 1)
                      Text('${battle.floors.length}마리',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 14)),
                    const SizedBox(height: 6),
                    Text(_exp > 0 ? '경험치 +$_exp' : '오늘 보상은 다 받았어요',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14)),
                    if (!widget.controller.lastReward.isEmpty) ...[
                      const SizedBox(height: 8),
                      RewardItems(reward: widget.controller.lastReward),
                    ],
                  ]),
                ),
            ],
            if (battle == null || _done) ...[
              const SizedBox(height: 20),
              FrameButton(
                label: '돌아가기',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 필드 전투 배경 (묶음 13 C7): 몬스터 자리의 장소 종류에 맞춰. 모르면 마을.
String fieldBackground(LandKind? land) => switch (land) {
      LandKind.park || LandKind.forest => 'assets/images/bg_field_forest.webp',
      LandKind.water => 'assets/images/bg_field_water.webp',
      // 바다 그림이 오기 전에는 물가 그림 (backgroundFallback)
      LandKind.sea => 'assets/images/bg_field_sea.webp',
      LandKind.city => 'assets/images/bg_field_city.webp',
      LandKind.mountain => 'assets/images/bg_field_mountain.webp',
      LandKind.village || null => 'assets/images/bg_field_village.webp',
    };
