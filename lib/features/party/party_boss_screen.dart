import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../battle/hero_rig.dart' show weaponKindOf;

/// 파티 보스 한 판 (묶음 56 #236): 정해진 턴 동안 싸우고, 준 피해를 파티에 보탠다
class PartyBossScreen extends StatefulWidget {
  const PartyBossScreen({
    super.key,
    required this.controller,
    required this.battle,
    this.tickInterval = const Duration(milliseconds: 900),
  });

  final AppController controller;
  final Battle battle;
  final Duration tickInterval;

  @override
  State<PartyBossScreen> createState() => _PartyBossScreenState();
}

class _PartyBossScreenState extends State<PartyBossScreen> {
  AppController get c => widget.controller;
  bool _done = false;
  PartyBossResult? _result;

  @override
  void initState() {
    super.initState();
    c.holdNoticesWhile(true);
  }

  @override
  void dispose() {
    c.holdNoticesWhile(false);
    super.dispose();
  }

  Future<void> _finish() async {
    if (_done) return;
    _done = true;
    final r = await c.finishPartyBoss(widget.battle);
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final b = widget.battle;
    final boss = Monsters.info(b.foe.monster);
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: const Key('partyBossBattle'),
        backgroundColor: AppColors.deepNight,
        bottomNavigationBar: _done
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: FrameButton(
                      key: const Key('partyBossBack'),
                      label: '돌아가기',
                      onPressed: () => Navigator.of(context).pop()),
                ),
              )
            : null,
        body: NightBackground(
          child: _done
              ? ListView(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 28),
                  children: [OrnateTopBar(title: boss.name), const SizedBox(height: 10), _resultView(b)],
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    OrnateTopBar(title: '파티 보스 · ${boss.name}', onBack: null),
                    const SizedBox(height: 10),
                    Expanded(
                      child: BattleView(
                        battle: b,
                        fit: true,
                        jobSkills: c.battleBarJobSlots,
                        bar: c.battleBar,
                        emptySlots: c.skillPageOpen,
                        jobMp: () => c.jobMp,
                        onJobSkill: c.payBattleSkill,
                        onMasterySkill: c.payMasterySkill,
                        background: 'assets/images/bg_field_village.webp',
                        onFinished: _finish,
                        tickInterval: widget.tickInterval,
                        playerName: c.profile.name,
                        look: c.profile.look,
                        heroJob: c.heroJobArt, // 묶음 76 #307
                        vibrate: c.vibrate,
                        sound: c.sound,
                        hour: c.now.hour,
                        season: SeasonRules.of(c.now),
                        weapon: weaponKindOf(c.armory.wornIn(EquipSlot.weapon)?.base),
                        fast: c.fastBattle,
                        onFastChanged: c.setFastBattle,
                        onAutoChanged: (hp, cure) => c.setAutoUse(hpPercent: hp, cure: cure),
                        floorLabelOf: (x) =>
                            '남은 턴 ${(PartyRules.fightTicks - x.ticks).clamp(0, PartyRules.fightTicks)}',
                        counterOf: (x) => '피해 ${comma(x.dealtToFoe)}',
                      ),
                    ),
                  ]),
                ),
        ),
      ),
    );
  }

  Widget _resultView(Battle b) {
    final r = _result;
    final v = c.party?.boss;
    return OrnatePanel(
      key: const Key('partyBossResult'),
      ornament: true,
      child: Column(children: [
        MonsterPicture(monster: b.foe.monster, size: 110),
        const SizedBox(height: 6),
        if (r == null)
          const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(color: AppColors.goldBright))
        else if (r.error != null)
          KText(PartyRules.errorText(r.error!),
              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text))
        else ...[
          Text(r.defeatedNow ? '다 함께 쓰러뜨렸어요!' : '파티에 피해를 보탰어요',
              style: AppText.title(18, color: AppColors.goldBright)),
          const SizedBox(height: 6),
          Text('이번 판 ${comma(r.damage)}',
              key: const Key('partyBossDealt'), style: AppText.title(26, color: AppColors.text)),
          if (v != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: v.left,
                minHeight: 10,
                backgroundColor: const Color(0x33FFFFFF),
                color: const Color(0xFFE25D5D),
              ),
            ),
            const SizedBox(height: 4),
            Text(v.defeated ? '주점 파티 탭에서 보상을 받으세요' : '남은 도전권 ${v.tickets}장',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ],
      ]),
    );
  }
}
