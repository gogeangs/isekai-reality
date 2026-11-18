import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../act4/act4_screens.dart' show showAct4Pending;
import '../battle/battle_view.dart';
import '../battle/hero_rig.dart' show weaponKindOf;
import '../party/party_flag.dart';

/// 에르바르드로 (길드 회관 · 지도): 볼 장면부터
Future<void> openErbard(BuildContext context, AppController c) async {
  await showAct4Pending(context, c);
  if (!context.mounted || !c.act5Open || !c.act5.has('e1b')) return;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ErbardScreen(controller: c)));
}

String _when(DateTime t) {
  final k = t.toUtc().add(const Duration(hours: 9));
  const days = ['월', '화', '수', '목', '금', '토', '일'];
  return '${k.month}월 ${k.day}일(${days[k.weekday - 1]})';
}

/// 지금 공성전 한 줄 (숫자 · 시각만, 숨은 값 없음)
String siegeLine(ErbardView v, DateTime now) {
  if (v.active && v.end != null) {
    final left = v.end!.difference(now);
    final h = left.inHours;
    return '제${v.siegeNo + 1}회 깃발 공성전 중 · ${h >= 1 ? '$h시간' : '${left.inMinutes.clamp(1, 59)}분'} 남았어요';
  }
  return v.start == null ? '' : '다음 깃발 공성전 ${_when(v.start!)} 0시부터 이틀';
}

/// 5막 대륙 지도 「에르바르드」 (묶음 60 #247): 영지 30 + 왕성 · 깃발 · 공성권 · 공성전 · 수비대 · 연맹
class ErbardScreen extends StatefulWidget {
  const ErbardScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ErbardScreen> createState() => _ErbardScreenState();
}

class _ErbardScreenState extends State<ErbardScreen> {
  AppController get c => widget.controller;
  final _tc = TransformationController();
  bool _placed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await c.refreshErbard();
    if (!mounted) return;
    if (c.siegeResultPending) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true, builder: (_) => SiegeResultScreen(controller: c)));
    }
    if (mounted) await showAct4Pending(context, c);
  }

  void _say(String t, {bool ok = true}) =>
      showTopNotice(context, t, icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('erbard'),
      backgroundColor: AppColors.deepNight,
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final v = c.erbard;
          return Stack(children: [
            Positioned.fill(child: LayoutBuilder(builder: (context, box) => _map(v, box))),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(12, pad.top + 4, 12, 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xF00B0D26), Color(0xC00B0D26), Color(0x000B0D26)],
                    stops: [0, 0.75, 1],
                  ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  OrnateTopBar(
                    title: '에르바르드',
                    onBack: () => Navigator.of(context).pop(),
                    trailing: _tickets(),
                  ),
                  _story(v),
                ]),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: pad.bottom + 10,
              child: Row(children: [
                if (c.erbardGuild && c.garrisonOpen) ...[
                  Expanded(
                    child: FrameButton(
                        key: const Key('erbardGarrison'),
                        label: '수비대',
                        height: 44,
                        onPressed: () => _garrisonPick(v)),
                  ),
                  const SizedBox(width: 6),
                ],
                if (c.erbardGuild) ...[
                  Expanded(
                    child: FrameButton(
                        key: const Key('erbardAlliance'),
                        label: '연맹',
                        height: 44,
                        onPressed: () => showAllianceSheet(context, c)),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: FrameButton(
                    key: const Key('erbardResult'),
                    label: '공성전 결과',
                    height: 44,
                    onPressed: v.lastNo == null
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute<void>(
                            fullscreenDialog: true, builder: (_) => SiegeResultScreen(controller: c))),
                  ),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Widget _tickets() => Row(key: const Key('siegeTickets'), mainAxisSize: MainAxisSize.min, children: [
        Image.asset(ErbardRules.ticketImage,
            width: 26, errorBuilder: (_, __, ___) => const Icon(Icons.confirmation_number_rounded, color: AppColors.goldBright)),
        const SizedBox(width: 3),
        Text('${c.siegeTickets}',
            style: const TextStyle(color: AppColors.goldBright, fontSize: 16, fontWeight: FontWeight.w900)),
      ]);

  Widget _story(ErbardView v) {
    final pending = c.pendingAct5Scene;
    return Container(
      key: const Key('act5Story'),
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xD0141838),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66E8C46A)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(
                c.act5Done ? '5막 「흑등 연맹의 귀환」 · 끝' : '5막 ${c.act5Chapter}장 · ${ErbardRules.chapterTitle(c.act5Chapter)}',
                style: AppText.title(14.5)),
          ),
          if (pending != null)
            TextButton(
              key: const Key('act5Watch'),
              style: TextButton.styleFrom(minimumSize: const Size(0, 28), padding: const EdgeInsets.symmetric(horizontal: 8)),
              onPressed: () => showAct4Pending(context, c),
              child: const Text('이야기 보기', style: TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.w800)),
            ),
        ]),
        KText(c.act5Goal, key: const Key('act5Goal'), style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
        if (c.act5Chapter == 2 && !c.act5Done) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
                value: c.act5Progress, minHeight: 5, backgroundColor: const Color(0x33FFFFFF), color: AppColors.goldBright),
          ),
        ],
        const SizedBox(height: 3),
        Text(siegeLine(v, c.now),
            key: const Key('siegeLine'),
            style: TextStyle(
                color: v.active ? const Color(0xFFFF8A65) : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _map(ErbardView v, BoxConstraints box) {
    final w = [760.0, box.maxHeight * 1.05, box.maxWidth * 1.25].reduce((a, b) => a > b ? a : b);
    final s = w / ErbardRules.mapW;
    final h = ErbardRules.mapH * s;
    if (!_placed) {
      _placed = true;
      final royal = ErbardRules.estate('royal')!;
      final dx = -(w - box.maxWidth) / 2;
      final dy = -(royal.y * s - box.maxHeight * 0.55).clamp(0.0, (h - box.maxHeight).clamp(0.0, double.infinity));
      _tc.value = Matrix4.identity()..translate(dx, dy);
    }
    final icon = 64 * s * 3.2;
    return InteractiveViewer(
      transformationController: _tc,
      constrained: false,
      minScale: 0.6,
      maxScale: 2.2,
      boundaryMargin: const EdgeInsets.all(40),
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(
            child: Image.asset(ErbardRules.mapImage,
                fit: BoxFit.fill, errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.night)),
          ),
          for (final e in ErbardRules.estates) _marker(v, e, s, e.royal ? icon * 1.45 : icon),
        ]),
      ),
    );
  }

  Widget _marker(ErbardView v, EstateInfo e, double s, double size) {
    final o = v.owners[e.id];
    final mine = o?.kind == 'mine';
    final prog = o == null ? v.wild[e.id] ?? const [] : v.run[e.id] ?? const [];
    return Positioned(
      left: e.x * s - size / 2,
      top: e.y * s - size * 0.85,
      width: size,
      height: size + 34,
      child: GestureDetector(
        key: Key('estate_${e.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _estate(e),
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          if (mine)
            Positioned(
              top: size * 0.45,
              child: Container(
                width: size * 0.95,
                height: size * 0.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  boxShadow: const [BoxShadow(color: Color(0xAAFFD54F), blurRadius: 14, spreadRadius: 2)],
                ),
              ),
            ),
          Positioned(
            top: 0,
            child: Image.asset(ErbardRules.estateIcon(e),
                width: size, height: size, errorBuilder: (_, __, ___) => Icon(Icons.castle_rounded, size: size * 0.8, color: AppColors.gold)),
          ),
          if (o != null)
            Positioned(
              top: -size * 0.32,
              left: size * 0.5,
              child: PartyFlag(
                  emblem: o.emblem, color: o.color, size: size * 0.55, npc: o.kind == 'npc', crown: o.crown),
            ),
          Positioned(
            top: size * 0.92,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: mine ? const Color(0xE0574012) : const Color(0xC00B0D26),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(e.name,
                  maxLines: 1,
                  style: TextStyle(
                      color: mine ? AppColors.goldBright : AppColors.text,
                      fontSize: e.royal ? 11.5 : 9.5,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          if (prog.isNotEmpty)
            Positioned(
              top: size * 0.92 + 17,
              child: _Dots(broken: prog),
            ),
        ]),
      ),
    );
  }

  Future<void> _estate(EstateInfo e) async {
    final act = await showEstateSheet(context, c, e);
    if (!mounted || act == null) return;
    switch (act) {
      case 'fight':
        final b = await c.startErbardFight(e);
        if (!mounted) return;
        if (b == null) return _say(ErbardRules.errorText(c.erbardError ?? ''), ok: false);
        await Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true, builder: (_) => ErbardBattleScreen(controller: c, battle: b, estate: e)));
        if (mounted) await showAct4Pending(context, c);
      case 'hunt':
        final b = c.startErbardHunt(e);
        if (b == null) return _say('여정 기력이 모자라요', ok: false);
        await Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true, builder: (_) => ErbardBattleScreen(controller: c, battle: b, estate: e, hunt: true)));
      case 'garrison':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GarrisonScreen(controller: c, estate: e)));
    }
  }

  Future<void> _garrisonPick(ErbardView v) async {
    if (v.myEstates.isEmpty) return _say('우리 길드 영지가 생기면 수비대를 세울 수 있어요', ok: false);
    final e = ErbardRules.estate(v.placed ?? v.myEstates.first)!;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GarrisonScreen(controller: c, estate: e)));
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.broken});
  final List<int> broken;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xC00B0D26), borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var k = 0; k < ErbardRules.slots; k++)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: broken.contains(k) ? const Color(0xFFFF8A65) : const Color(0x55FFFFFF),
              ),
            ),
        ]),
      );
}

/// 영지 한 곳 (주인 · 다섯 자리 · 할 수 있는 일) → 'fight' · 'hunt' · 'garrison'
Future<String?> showEstateSheet(BuildContext context, AppController c, EstateInfo e) => showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) {
        final v = c.erbard;
        final o = v.owners[e.id];
        final p = e.province == null ? null : ErbardRules.province(e.province!);
        final kind = c.erbardFightKind(e);
        final broken = o == null ? v.wild[e.id] ?? const <int>[] : v.run[e.id] ?? const <int>[];
        final mine = o?.kind == 'mine';
        final monster = p == null ? MonsterId.blackCaptain : (e.inner ? p.inner : p.outer);
        return SafeArea(
          child: Padding(
            key: Key('estateSheet_${e.id}'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Image.asset(ErbardRules.estateIcon(e), width: 56, height: 56, errorBuilder: (_, __, ___) => const SizedBox(width: 56)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.name, style: AppText.title(19)),
                    Text(
                        e.royal
                            ? '에르바르드 가운데 · 영지 두 곳을 가진 길드만 공성'
                            : '${p!.name} · ${p.element} · ${e.inner ? '안쪽(강함)' : '바깥(보통)'}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                if (o != null) PartyFlag(emblem: o.emblem, color: o.color, size: 36, npc: o.kind == 'npc', crown: o.crown),
                if (o != null) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      o == null
                          ? '빈 영지 · 야생 수비대가 지켜요'
                          : switch (o.kind) {
                              'mine' => '우리 길드 영지',
                              'ally' => '연맹 길드 「${o.name}」의 영지',
                              'npc' => '흑등 연맹이 쥐고 있어요',
                              _ => '「${o.name}」 길드의 영지',
                            },
                      style: TextStyle(color: mine ? AppColors.goldBright : AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 8),
              if (!mine)
                Row(children: [
                  MonsterPicture(
                      monster: o == null ? monster : (o.kind == 'npc' ? ErbardRules.blackOf(e, 0) : MonsterId.cloneWarrior), size: 44),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(o == null ? '야생 수비대 다섯 자리' : '수비대 다섯 자리',
                          style: const TextStyle(color: AppColors.text, fontSize: 13)),
                      const SizedBox(height: 3),
                      _Dots(broken: broken),
                    ]),
                  ),
                ]),
              const SizedBox(height: 6),
              KText(
                  o == null
                      ? (c.erbardGuild
                          ? '공성권 한 장으로 한 자리와 싸워요. 길드원이 나눠서 다섯 자리를 모두 깨면 우리 길드가 차지해요.'
                          : '공성권 한 장으로 한 자리와 싸워요. 다섯 자리를 모두 깨면 개척 보상을 받아요. 영지는 길드만 가질 수 있어 빈 채로 남아요.')
                      : mine
                          ? '길드원이 자기 분신을 세워 지켜요. 두 주 동안 함께 걸을수록 수비대가 튼튼해져요.'
                          : '깃발 공성전 기간에 공성권으로 한 자리씩 깨요. 깬 자리는 공성전 동안 되살아나지 않아요.',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 10),
              if (kind != null)
                GoldButton(
                  key: const Key('estateFight'),
                  label: kind == 'wild' ? '야생 수비대와 싸우기' : '공성하기',
                  leading: Image.asset(ErbardRules.ticketImage, width: 24, errorBuilder: (_, __, ___) => const SizedBox()),
                  height: 46,
                  fontSize: 17,
                  onPressed: c.siegeTickets > 0 && !c.erbardBusy ? () => Navigator.pop(sheet, 'fight') : null,
                )
              else if (!mine)
                Text(
                    e.royal && o?.kind == 'npc' && !v.active
                        ? '왕성은 깃발 공성전 기간에만 공성할 수 있어요'
                        : o?.kind == 'ally'
                            ? '연맹 길드의 영지는 공성하지 않아요'
                            : c.erbardGuild
                                ? '깃발 공성전 기간에 공성할 수 있어요 · ${siegeLine(v, c.now)}'
                                : '주인 있는 영지는 길드끼리 공성전으로 다퉈요',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              if (mine && c.garrisonOpen) ...[
                const SizedBox(height: 6),
                FrameButton(key: const Key('estateGarrison'), label: '수비대 보기 · 세우기', height: 44, onPressed: () => Navigator.pop(sheet, 'garrison')),
              ],
              if (!e.royal) ...[
                const SizedBox(height: 6),
                FrameButton(
                  key: const Key('estateHunt'),
                  label: '이 영지에서 사냥하기 (여정 기력)',
                  height: 42,
                  onPressed: c.canErbardHunt(e) ? () => Navigator.pop(sheet, 'hunt') : null,
                ),
              ],
            ]),
          ),
        );
      },
    );

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

/// 수비대: 우리 영지 다섯 자리 · 내 분신(+ 동료 둘) 세우기
class GarrisonScreen extends StatefulWidget {
  const GarrisonScreen({super.key, required this.controller, required this.estate});

  final AppController controller;
  final EstateInfo estate;

  @override
  State<GarrisonScreen> createState() => _GarrisonScreenState();
}

class _GarrisonScreenState extends State<GarrisonScreen> {
  AppController get c => widget.controller;
  late EstateInfo _e = widget.estate;
  final Set<String> _allies = {};

  void _say(String t, {bool ok = true}) =>
      showTopNotice(context, t, icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('garrison'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final v = c.erbard;
            final slots = v.garrisons[_e.id] ?? List.filled(ErbardRules.slots, null);
            return ListView(
              padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24),
              children: [
                OrnateTopBar(title: '수비대', onBack: () => Navigator.of(context).pop()),
                if (v.myEstates.length > 1)
                  Wrap(spacing: 6, children: [
                    for (final id in v.myEstates)
                      ChoiceChip(
                        key: Key('garrisonEstate_$id'),
                        label: Text(ErbardRules.estate(id)!.name),
                        selected: id == _e.id,
                        onSelected: (_) => setState(() => _e = ErbardRules.estate(id)!),
                      ),
                  ]),
                const SizedBox(height: 8),
                OrnatePanel(
                  ornament: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Image.asset(ErbardRules.estateIcon(_e), width: 48, height: 48, errorBuilder: (_, __, ___) => const SizedBox(width: 48)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_e.name, style: AppText.title(18))),
                    ]),
                    const SizedBox(height: 4),
                    KText(
                        v.active
                            ? '공성전 중에는 수비대를 바꿀 수 없어요.'
                            : '길드원마다 한 자리에 자기 분신을 세워요. 동료는 둘까지 함께 서요. 두 주 동안 길드원이 함께 걸을수록 튼튼해져요.',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
                    const SizedBox(height: 8),
                    for (var k = 0; k < ErbardRules.slots; k++) _slot(v, k, k < slots.length ? slots[k] : null),
                  ]),
                ),
                const SizedBox(height: 10),
                _boost(v),
                const SizedBox(height: 10),
                OrnatePanel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('함께 서는 동료 (둘까지)', style: AppText.title(15)),
                    const SizedBox(height: 6),
                    if (c.allies.isEmpty)
                      const Text('3막에서 만난 동료가 없어요', style: TextStyle(color: AppColors.textMuted))
                    else
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final a in c.allies)
                          FilterChip(
                            key: Key('garrisonAlly_${a.id}'),
                            label: Text('${a.name} Lv.${a.level}'),
                            selected: _allies.contains(a.id),
                            onSelected: (on) => setState(() {
                              if (on && _allies.length < ErbardRules.garrisonAllies) {
                                _allies.add(a.id);
                              } else {
                                _allies.remove(a.id);
                              }
                            }),
                          ),
                      ]),
                    if (v.placed != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        key: const Key('garrisonRemove'),
                        onPressed: v.active || c.erbardBusy
                            ? null
                            : () async {
                                final ok = await c.removeGarrison();
                                if (mounted) ok ? _say('내 분신을 내렸어요') : _say(ErbardRules.errorText(c.erbardError ?? ''), ok: false);
                              },
                        child: const Text('내 분신 내리기', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ],
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 묶음 61: 길드 금고로 수비대 강화 (그 영지 · 다음 공성전 끝까지, 세기는 숨김)
  Widget _boost(ErbardView v) {
    final cur = v.boosts[_e.id] ?? 0;
    return OrnatePanel(
      key: const Key('garrisonBoost'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('수비대 강화 · 길드 금고', style: AppText.title(15)),
          const Spacer(),
          for (var i = 1; i <= ErbardRules.boostCost.length; i++)
            Icon(i <= cur ? Icons.shield_rounded : Icons.shield_outlined, size: 18, color: AppColors.goldBright),
        ]),
        const SizedBox(height: 4),
        KText(
            cur > 0
                ? '금고 금화로 단단해진 수비대예요. 다음 공성전이 끝날 때까지 이어져요.'
                : '길드장 · 부길드장이 금고 금화로 이 영지 수비대를 더 단단하게 해요. 다음 공성전이 끝날 때까지 이어져요.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
        Text('길드 금고 · 금화 ${comma(v.treasury)}',
            key: const Key('garrisonTreasury'), style: const TextStyle(color: AppColors.text, fontSize: 13)),
        if (v.staff) ...[
          const SizedBox(height: 6),
          Row(children: [
            for (var i = 1; i <= ErbardRules.boostCost.length; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Expanded(
                child: FrameButton(
                  key: Key('garrisonBoost_$i'),
                  label: '$i단계 · ${comma(ErbardRules.boostCost[i - 1] - (cur > 0 && cur < i ? ErbardRules.boostCost[cur - 1] : 0))}',
                  height: 40,
                  onPressed: v.active || c.guildBusy || i <= cur
                      ? null
                      : () async {
                          final ok = await c.boostGarrison(_e.id, i);
                          if (mounted) ok ? _say('수비대를 강화했어요') : _say(GuildRules.errorText(c.guildError ?? ''), ok: false);
                        },
                ),
              ),
            ],
          ]),
          if (v.active)
            const Text('공성전 중에는 강화할 수 없어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ]),
    );
  }

  Widget _slot(ErbardView v, int k, ({String name, int level, List<String> allies, bool me})? g) => Container(
        key: Key('garrisonSlot_$k'),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        decoration: BoxDecoration(
          color: g?.me ?? false ? const Color(0x33E8C46A) : const Color(0x22000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x44E8C46A)),
        ),
        child: Row(children: [
          Text('${k + 1}', style: AppText.title(15, color: AppColors.goldBright)),
          const SizedBox(width: 6),
          if (g != null) ...[
            MonsterPicture(monster: ErbardRules.cloneOf((v.guards[_e.id] ?? const [])
                .elementAtOrNull(k)), size: 36),
            const SizedBox(width: 6),
          ],
          const SizedBox(width: 4),
          Expanded(
            child: g == null
                ? const Text('빈 자리 · 비어 있으면 그 지방 수비병이 지켜요', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${g.name}${g.me ? ' (나)' : ''} · Lv.${g.level}',
                        style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
                    if (g.allies.isNotEmpty)
                      Text('함께: ${g.allies.join(' · ')}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ]),
          ),
          if (!v.active && (g == null || g.me))
            FilledButton(
              key: Key('garrisonPlace_$k'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold, minimumSize: const Size(0, 32)),
              onPressed: c.erbardBusy
                  ? null
                  : () async {
                      final ok = await c.placeGarrison(_e.id, k, _allies.toList());
                      if (!mounted) return;
                      ok ? _say('${_e.name} ${k + 1}번 자리에 섰어요') : _say(ErbardRules.errorText(c.erbardError ?? ''), ok: false);
                    },
              child: Text(g == null ? '여기 서기' : '다시 서기', style: const TextStyle(color: AppColors.goldInk)),
            ),
        ]),
      );
}

/// 연맹: 만들기 · 코드로 들어가기 · 나가기 (길드장)
Future<void> showAllianceSheet(BuildContext context, AppController c) {
  final name = TextEditingController();
  final code = TextEditingController();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.night,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final v = c.erbard;
        final a = v.alliance;
        void err() => showTopNotice(context, ErbardRules.errorText(c.erbardError ?? ''), icon: Icons.info_outline_rounded);
        return SafeArea(
          child: Padding(
            key: const Key('allianceSheet'),
            padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('연맹', style: AppText.title(18)),
              const Text('길드 세 곳까지 함께해요. 연맹 길드끼리는 서로 공성하지 않고, 영지 몫 보상을 나눠요. 연맹은 공성전 네 번마다 다시 고를 수 있어요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
              const SizedBox(height: 10),
              if (a != null) ...[
                Text(a.name, style: AppText.title(17, color: AppColors.goldBright)),
                Text(a.guilds.join(' · '), style: const TextStyle(color: AppColors.text)),
                Row(children: [
                  Text('연맹 코드 ${a.code}', style: const TextStyle(color: AppColors.textMuted)),
                  IconButton(
                    onPressed: () => Clipboard.setData(ClipboardData(text: a.code)),
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textMuted),
                  ),
                ]),
                if (v.owner)
                  TextButton(
                    key: const Key('allianceLeave'),
                    onPressed: a.locked
                        ? null
                        : () async {
                            if (!await c.allianceAction('leave')) err();
                          },
                    child: Text(a.locked ? '공성전 네 번이 지나면 다시 고를 수 있어요' : '연맹에서 나가기',
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
              ] else if (!v.owner)
                const Text('연맹은 길드장이 만들거나 들어가요', style: TextStyle(color: AppColors.textMuted))
              else ...[
                TextField(
                  key: const Key('allianceName'),
                  controller: name,
                  maxLength: 12,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(hintText: '연맹 이름', counterText: '', isDense: true),
                ),
                const SizedBox(height: 6),
                GoldButton(
                  key: const Key('allianceCreate'),
                  label: '연맹 만들기',
                  height: 44,
                  fontSize: 17,
                  onPressed: () async {
                    if (name.text.trim().length < 2) return;
                    if (!await c.allianceAction('create', name: name.text.trim())) err();
                  },
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      key: const Key('allianceCode'),
                      controller: code,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(color: AppColors.text, letterSpacing: 3),
                      decoration: const InputDecoration(hintText: '연맹 코드', counterText: '', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('allianceJoin'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold),
                    onPressed: () async {
                      if (code.text.trim().length < 6) return;
                      if (!await c.allianceAction('join', code: code.text.trim().toUpperCase())) err();
                    },
                    child: const Text('들어가기', style: TextStyle(color: AppColors.goldInk)),
                  ),
                ]),
              ],
            ]),
          ),
        );
      },
    ),
  );
}

/// 지난 공성전 결과 (일요일 밤 정리 뒤 한 번 · 지도에서 다시 보기)
class SiegeResultScreen extends StatefulWidget {
  const SiegeResultScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SiegeResultScreen> createState() => _SiegeResultScreenState();
}

class _SiegeResultScreenState extends State<SiegeResultScreen> {
  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.markSiegeResultSeen();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final v = c.erbard;
    final no = v.lastNo ?? 0;
    return Scaffold(
      key: const Key('siegeResult'),
      backgroundColor: AppColors.deepNight,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FrameButton(key: const Key('siegeResultClose'), label: '확인', onPressed: () => Navigator.of(context).pop()),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.only(bottom: pad.bottom + 16),
        children: [
          SizedBox(
            height: 220 + pad.top,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(ErbardRules.siegeBg, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.night)),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x330B0D26), Color(0xFF0B0D26)]),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('제${no + 1}회 깃발 공성전', style: AppText.title(24, color: AppColors.goldBright)),
                  Text(
                      v.lastRoyalNpc
                          ? '왕성은 아직 흑등 연맹이 쥐고 있어요'
                          : '에르바르드 왕성은 「${v.lastRoyal}」 길드가 지켜요',
                      style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: OrnatePanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('주인이 바뀐 영지', style: AppText.title(15)),
                const SizedBox(height: 6),
                if (v.lastChanges.isEmpty)
                  const Text('이번엔 주인이 바뀐 영지가 없어요', style: TextStyle(color: AppColors.textMuted)),
                for (final ch in v.lastChanges)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Expanded(
                        child: Text(ErbardRules.estate(ch.estate)?.name ?? ch.estate,
                            style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800)),
                      ),
                      Text('${ch.fromName.isEmpty ? '빈 영지' : ch.fromName} → ${ch.toName}',
                          style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
                    ]),
                  ),
                const SizedBox(height: 8),
                if (c.erbardGuild)
                  Text(
                      v.myEstates.isEmpty
                          ? '우리 길드 영지 없음 · 다음 공성전에 다시 도전해요'
                          : '우리 길드 영지 ${v.myEstates.length}곳 · ${v.myEstates.map((x) => ErbardRules.estate(x)?.name ?? x).join(' · ')}',
                      style: const TextStyle(color: AppColors.text)),
                const SizedBox(height: 4),
                const Text('공성전 보상은 세라 이름으로 우편에 왔어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
