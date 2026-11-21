import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../chat/chat_screens.dart';
import '../../app_controller.dart';
import '../../data/sound/sfx.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../act4/act4_screens.dart' show showAct4Pending;
import '../battle/battle_view.dart';
import '../battle/hero_rig.dart' show weaponKindOf;
import '../party/party_flag.dart';
import 'estate_manage_screen.dart';

part 'erbard_screens/estate_sheet.dart';
part 'erbard_screens/erbard_battle.dart';
part 'erbard_screens/garrison.dart';
part 'erbard_screens/siege.dart';

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
  if (!v.open) return ErbardRules.closedLine;
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
      // 묶음 65: 결과 장면 (깃발이 바뀜) → 결과 화면
      await Navigator.of(context).push(PageRouteBuilder<void>(
          opaque: true,
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => SiegeResultScene(controller: c),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child)));
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => SiegeResultScreen(controller: c)));
    }
    if (!mounted) return;
    _siegeNotices();
    await showAct4Pending(context, c);
  }

  /// 묶음 65: 「○○ 영지에 집결해요」 · 「마지막 6시간」(공성전마다 한 번, 북소리)
  void _siegeNotices() {
    final v = c.erbard;
    final r = v.rally;
    if (r != null && c.takeRallyNotice(v.siegeNo, r.estate)) {
      final e = ErbardRules.estate(r.estate);
      if (e != null) showTopNoticeQueued(context, '${e.name}에 집결해요', image: ErbardRules.rallyIcon);
    }
    if (c.siegeFinal && c.takeFinalNotice(v.siegeNo)) {
      Sfx.play(SfxKind.siegeDrum, volume: 0.9);
      showTopNoticeQueued(context, '마지막 6시간이에요! 붉은 하늘 아래 마지막 힘을 모아요', icon: Icons.local_fire_department_rounded);
    }
  }

  void _say(String t, {bool ok = true}) => showTopNotice(context, t, icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);

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
            // 묶음 65: 마지막 6시간 — 붉은 하늘
            if (c.siegeFinal)
              Positioned.fill(
                key: const Key('siegeFinalSky'),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.55,
                    child: ShaderMask(
                      shaderCallback: (r) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Colors.transparent],
                        stops: [0.0, 0.55],
                      ).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(ErbardRules.finalSky,
                          fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0x66B3261E))),
                    ),
                  ),
                ),
              ),
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
                    trailing: c.siegeOpen ? _tickets() : null,
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
                if (c.erbardGuild && c.garrisonOpen && c.siegeOpen) ...[
                  Expanded(
                    child: FrameButton(key: const Key('erbardGarrison'), label: '수비대', height: 44, onPressed: () => _garrisonPick(v)),
                  ),
                  const SizedBox(width: 6),
                ],
                if (c.erbardGuild && v.active) ...[
                  Expanded(
                    child:
                        FrameButton(key: const Key('erbardWarBoard'), label: '전황', height: 44, onPressed: () => showWarBoard(context, c)),
                  ),
                  const SizedBox(width: 6),
                ],
                if (c.erbardGuild) ...[
                  Expanded(
                    child: FrameButton(
                        key: const Key('erbardAlliance'), label: '연맹', height: 44, onPressed: () => showAllianceSheet(context, c)),
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
                        : () => Navigator.of(context)
                            .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => SiegeResultScreen(controller: c))),
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
        Text('${c.siegeTickets}', style: const TextStyle(color: AppColors.goldBright, fontSize: 16, fontWeight: FontWeight.w900)),
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
            child: Text(c.act5Done ? '5막 「흑등 연맹의 귀환」 · 끝' : '5막 ${c.act5Chapter}장 · ${ErbardRules.chapterTitle(c.act5Chapter)}',
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
        if (v.active && v.gauge != null) ...[
          const SizedBox(height: 5),
          SiegeGaugeRow(gauge: v.gauge!, mine: v.myEstates.length),
        ],
        const SizedBox(height: 3),
        Text(siegeLine(v, c.now),
            key: const Key('siegeLine'),
            style: TextStyle(color: v.active ? const Color(0xFFFF8A65) : AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
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
            child:
                Image.asset(ErbardRules.mapImage, fit: BoxFit.fill, errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.night)),
          ),
          // 묶음 65 #255: 번영 단계가 오르면 영지 아이콘이 커짐
          for (final e in ErbardRules.estates)
            _marker(v, e, s, (e.royal ? icon * 1.45 : icon) * EstateDevRules.iconScale(v.stages[e.id] ?? 0)),
        ]),
      ),
    );
  }

  Widget _marker(ErbardView v, EstateInfo e, double s, double size) {
    final o = v.owners[e.id];
    final mine = o?.kind == 'mine';
    // 우리 영지는 공성전 동안 깨진 자리 수(가장 많이 깬 길드 기준)
    final prog = mine && v.active
        ? [for (var k = 0; k < (v.defense[e.id] ?? 0); k++) k]
        : o == null
            ? v.wild[e.id] ?? const <int>[]
            : v.run[e.id] ?? const <int>[];
    final rally = v.active && v.rally?.estate == e.id;
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
          // 고을 · 도시: 불빛 (따뜻한 빛) · 도시엔 작은 집
          if ((v.stages[e.id] ?? 0) >= 1)
            Positioned(
              key: Key('estateStage_${e.id}'),
              top: size * 0.3,
              child: Container(
                width: size * 0.7,
                height: size * 0.45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  boxShadow: const [BoxShadow(color: Color(0x99FFB74D), blurRadius: 16, spreadRadius: 3)],
                ),
              ),
            ),
          Positioned(
            top: 0,
            child: Image.asset(ErbardRules.estateIcon(e),
                width: size,
                height: size,
                errorBuilder: (_, __, ___) => Icon(Icons.castle_rounded, size: size * 0.8, color: AppColors.gold)),
          ),
          if (o != null)
            Positioned(
              top: -size * 0.32,
              left: size * 0.5,
              child: PartyFlag(emblem: o.emblem, color: o.color, size: size * 0.55, npc: o.kind == 'npc', crown: o.crown),
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
                      color: mine ? AppColors.goldBright : AppColors.text, fontSize: e.royal ? 11.5 : 9.5, fontWeight: FontWeight.w800)),
            ),
          ),
          if (prog.isNotEmpty)
            Positioned(
              top: size * 0.92 + 17,
              child: _Dots(broken: prog, defend: mine),
            ),
          if ((v.stages[e.id] ?? 0) >= 2)
            Positioned(
              top: size * 0.45,
              right: -size * 0.12,
              child: Image.asset('assets/images/fac_market.webp',
                  width: size * 0.42, height: size * 0.42, errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          if (rally)
            Positioned(
              key: Key('rally_${e.id}'),
              top: -size * 0.38,
              left: -size * 0.05,
              child: Image.asset(ErbardRules.rallyIcon,
                  width: size * 0.55,
                  height: size * 0.55,
                  errorBuilder: (_, __, ___) => Icon(Icons.flag_rounded, size: size * 0.5, color: const Color(0xFFFF8A65))),
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
        await Navigator.of(context)
            .push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => ErbardBattleScreen(controller: c, battle: b, estate: e)));
        if (mounted) await showAct4Pending(context, c);
      case 'hunt':
        final b = c.startErbardHunt(e);
        if (b == null) return _say('여정 기력이 모자라요', ok: false);
        await Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true, builder: (_) => ErbardBattleScreen(controller: c, battle: b, estate: e, hunt: true)));
      case 'garrison':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GarrisonScreen(controller: c, estate: e)));
      case 'manage':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EstateManageScreen(controller: c, estate: e)));
      case 'rally':
        final ok = await c.setRally(e.id);
        if (!mounted) return;
        if (ok) {
          showTopNotice(context, '${e.name}에 집결 깃발을 꽂았어요', icon: Icons.flag_rounded);
          c.takeRallyNotice(c.erbard.siegeNo, e.id);
        } else {
          _say(ErbardRules.errorText(c.erbardError ?? ''), ok: false);
        }
    }
  }

  Future<void> _garrisonPick(ErbardView v) async {
    if (v.myEstates.isEmpty) return _say('우리 길드 영지가 생기면 수비대를 세울 수 있어요', ok: false);
    final e = ErbardRules.estate(v.placed ?? v.myEstates.first)!;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GarrisonScreen(controller: c, estate: e)));
  }
}

// ───────────── 묶음 65 #251: 게이지 · 전황판 · 결과 장면
