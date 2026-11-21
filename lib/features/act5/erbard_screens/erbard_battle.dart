part of '../erbard_screens.dart';

/// 공성권 한 판 · 에르바르드 사냥
class ErbardBattleScreen extends StatefulWidget {
  const ErbardBattleScreen({
    super.key,
    required this.controller,
    required this.battle,
    required this.estate,
    this.hunt = false,
    this.tickInterval = const Duration(milliseconds: 900),
  });

  final AppController controller;
  final Battle battle;
  final EstateInfo estate;
  final bool hunt;
  final Duration tickInterval;

  @override
  State<ErbardBattleScreen> createState() => _ErbardBattleScreenState();
}

class _ErbardBattleScreenState extends State<ErbardBattleScreen> {
  AppController get c => widget.controller;
  bool _done = false;
  ErbardFightResult? _r;
  Act3FightResult? _h;

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
    if (widget.hunt) {
      final h = await c.finishErbardHunt(widget.battle);
      if (mounted) setState(() => _h = h);
    } else {
      final r = await c.finishErbardFight(widget.battle);
      if (mounted) setState(() => _r = r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final b = widget.battle;
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: const Key('erbardBattle'),
        backgroundColor: AppColors.deepNight,
        bottomNavigationBar: _done
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: FrameButton(key: const Key('erbardBack'), label: '지도로', onPressed: () => Navigator.of(context).pop()),
                ),
              )
            : null,
        body: NightBackground(
          child: _done
              ? ListView(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 28),
                  children: [OrnateTopBar(title: widget.estate.name), const SizedBox(height: 10), _result(b)],
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    OrnateTopBar(title: widget.hunt ? '사냥 · ${widget.estate.name}' : widget.estate.name, onBack: null),
                    const SizedBox(height: 10),
                    Expanded(
                      child: BattleView(
                        battle: b,
                        fit: true,
                        jobSkills: c.battleJobSlots,
                        emptySlots: c.skillPageOpen,
                        jobMp: () => c.jobMp,
                        onJobSkill: c.payBattleSkill,
                        onMasterySkill: c.payMasterySkill,
                        background: widget.hunt ? 'assets/images/bg_field_village.webp' : ErbardRules.siegeBg,
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
                      ),
                    ),
                  ]),
                ),
        ),
      ),
    );
  }

  Widget _result(Battle b) {
    final r = _r, h = _h;
    final won = r?.won ?? h?.won ?? false;
    return OrnatePanel(
      key: const Key('erbardResult_panel'),
      ornament: true,
      child: Column(children: [
        MonsterPicture(monster: b.foe.monster, size: 100, defeated: won),
        const SizedBox(height: 6),
        if (r == null && h == null)
          const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppColors.goldBright))
        else if (r?.error != null)
          KText(ErbardRules.errorText(r!.error!), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text))
        else ...[
          Text(
              won
                  ? (r?.captured ?? false)
                      ? '다섯 자리를 모두 깼어요! 우리 길드 깃발을 꽂았어요'
                      : (r?.full ?? false)
                          ? '다섯 자리를 모두 깼어요!'
                          : widget.hunt
                              ? '사냥에 이겼어요'
                              : '한 자리를 깼어요'
                  : '이번엔 물러났어요',
              textAlign: TextAlign.center,
              style: AppText.title(18, color: AppColors.goldBright)),
          const SizedBox(height: 6),
          for (final l in [...?r?.lines, ...?h?.lines, if (h != null && h.won) '경험치 ${comma(h.exp)} · 금화 ${comma(h.gold)}'])
            KText(l, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.text, fontSize: 13.5)),
          if (!widget.hunt) ...[
            const SizedBox(height: 6),
            Text('남은 공성권 ${c.siegeTickets}장', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ],
      ]),
    );
  }
}
