import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../awakening/awakening_screen.dart' show IllustratedScene, SceneWho;
import '../battle/battle_view.dart';
import '../battle/dungeon_screen.dart' show confirmStopResting;
import '../battle/hero_rig.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart' show SpiritMood;
import '../smithy/equipment_view.dart';
import '../village/tavern_screen.dart';
import 'act3_town.dart';
import 'region_screens.dart';

/// 3막에 들어간다 (마을의 다리 · 지도 「여정」): 처음이면 다리 장면부터
Future<void> openJourney(BuildContext context, AppController c) async {
  if (c.bridgeScenePending) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => BridgeSceneScreen(controller: c)));
    if (!context.mounted || !c.act3Open) return;
  }
  if (!c.act3Open) {
    showTopNotice(
        context,
        c.act2.kingDone
            ? 'Lv.${Act3Rules.openLevel}에 다리를 건널 수 있어요'
            : '아직 다리가 놓이지 않았어요',
        icon: Icons.lock_rounded);
    return;
  }
  await Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => Act3Screen(controller: c)));
}

/// 처음 다리를 건너는 장면 (묶음 52 #243): 리안 · 가렌 · 첫 펫. 끝나면 3막이 열림
class BridgeSceneScreen extends StatefulWidget {
  const BridgeSceneScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<BridgeSceneScreen> createState() => _BridgeSceneScreenState();
}

class _BridgeSceneScreenState extends State<BridgeSceneScreen> {
  AppController get c => widget.controller;
  int _line = 0;
  bool _done = false;

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

  Future<void> _next() async {
    if (_line < Act3Rules.bridgeScene.length - 1) {
      setState(() => _line++);
      return;
    }
    if (_done) return;
    _done = true;
    await c.openAct3();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final (who, line) = Act3Rules.bridgeScene[_line];
    final speaker = switch (who) {
      'lian' => '리안',
      'garen' => '가렌',
      _ => c.firstPet?.name ?? c.voicePet?.name ?? '펫',
    };
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: const Key('bridgeScene'),
        backgroundColor: AppColors.deepNight,
        body: IllustratedScene(
          key: ValueKey('bridge$_line'),
          image: Act3Rules.bridgeImage,
          speaker: speaker,
          who: switch (who) {
            'lian' => const SceneWho.face('assets/images/npc_lian.webp'),
            'garen' => const SceneWho.face('assets/images/npc_garen.webp'),
            _ => SceneWho.petOr(c.firstPet ?? c.voicePet),
          },
          line: line,
          lineKey: 'bridge-$_line',
          onNext: _next,
        ),
      ),
    );
  }
}

/// 3막 화면 (묶음 52 #243): 위 여정 기력 · 데려가는 동료 / 지도 · 일지 · 세계 / 아래 다음 지역 길
class Act3Screen extends StatefulWidget {
  const Act3Screen({super.key, required this.controller, this.tab = 0});

  final AppController controller;
  final int tab;

  @override
  State<Act3Screen> createState() => _Act3ScreenState();
}

class _Act3ScreenState extends State<Act3Screen> {
  AppController get c => widget.controller;
  late int _tab = widget.tab;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pending());
  }

  /// 묶음 57: 지역에 처음 온 장면 · 미뤄 둔 큰 고르기 · 3막 끝 장면
  Future<void> _pending() async {
    final r = c.regionNow;
    if (!mounted) return;
    if (r != null && c.regionArrivePending(r)) await showRegionArrive(context, c, r);
    if (!mounted) return;
    if (r != null && c.regionChoicePending(r) && r.choice.afterLamp) {
      await afterRegionLamp(context, c, r);
    } else if (c.act3EndPending) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true, builder: (_) => Act3EndScreen(controller: c)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('act3Screen'),
      backgroundColor: AppColors.deepNight,
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => NightBackground(
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, pad.top + 6, 12, pad.bottom + 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OrnateTopBar(
                    title: c.currentRegion.name,
                    onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 6),
                _topBar(),
                const SizedBox(height: 8),
                Row(children: [
                  for (final (i, t) in const ['지도', '일지', '세계'].indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: ChoiceChip(
                        key: Key('act3Tab_$i'),
                        label: SizedBox(
                            width: double.infinity,
                            child: Text(t, textAlign: TextAlign.center)),
                        selected: _tab == i,
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 8),
                Expanded(
                  child: switch (_tab) {
                    0 => _RegionMap(controller: c),
                    1 => _Journal(controller: c, onGo: (id) {
                        setState(() => _tab = 0);
                        showPlaceSheet(context, c, id);
                      }),
                    _ => _WorldMap(controller: c),
                  },
                ),
                const SizedBox(height: 6),
                _roadBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final e = c.journeyEnergy;
    return Row(children: [
      Image.asset(Act3Rules.energyImage,
          width: 30,
          height: 30,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.local_fire_department_rounded, color: AppColors.goldBright)),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('여정 기력 $e / ${Act3Rules.energyMax}',
                key: const Key('act3Energy'),
                style: const TextStyle(
                    color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            GlowBar(
                ratio: e / Act3Rules.energyMax,
                colors: const [Color(0xFF7FD6FF), Color(0xFF3B8DD6)],
                height: 8),
          ],
        ),
      ),
      if (c.lunchCount > 0) ...[
        const SizedBox(width: 6),
        GestureDetector(
          key: const Key('eatLunch'),
          onTap: () async {
            final ok = await c.eatLunch();
            if (!mounted) return;
            showTopNotice(
                context,
                ok
                    ? '마르타의 도시락을 먹었어요 · 여정 기력 +${BaldrinRules.lunchEnergy}'
                    : '여정 기력이 가득해요');
          },
          child: Stack(clipBehavior: Clip.none, children: [
            Image.asset(BaldrinRules.lunchImage,
                width: 34,
                height: 34,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.lunch_dining_rounded, color: AppColors.goldBright)),
            Positioned(
              right: -4,
              bottom: -4,
              child: Text('${c.lunchCount}',
                  style: const TextStyle(
                      color: AppColors.goldBright, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      ],
      const SizedBox(width: 10),
      // 데려가는 동료 (누르면 「아르카 마을 주점에서 바꿀 수 있어요」)
      for (final a in c.partyAllies)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: GestureDetector(
            key: Key('act3Ally_${a.id}'),
            onTap: () => _partyDialog(),
            child: AllyFace(look: c.allyLook(a), size: 38),
          ),
        ),
    ]);
  }

  Future<void> _partyDialog() => showDialog<void>(
        context: context,
        builder: (d) => GameAlert(
          key: const Key('act3PartyDialog'),
          title: Text('데려가는 동료', style: AppText.title(18)),
          content: const KText('동료는 아르카 마을 주점에서 바꿀 수 있어요.',
              style: TextStyle(color: AppColors.text, height: 1.45)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('닫기')),
            TextButton(
              key: const Key('act3GoTavern'),
              onPressed: () {
                Navigator.pop(d);
                Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => TavernScreen(controller: c, allyTab: true)));
              },
              child: const Text('주점으로 가기'),
            ),
          ],
        ),
      );

  Widget _roadBar() {
    final r = c.road;
    final next = r.next;
    if (next == null || c.regionReached(next.id)) {
      return OrnatePanel(
        key: const Key('act3Road'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: KText(
            c.act3Done
                ? '다섯 등불이 모두 켜졌어요. 「세계」에서 지역을 골라 오갈 수 있어요.'
                : next == null
                    ? '마지막 지역이에요. 성소의 등불을 켜면 3막이 끝나요.'
                    : '「세계」에서 이미 가 본 지역이에요.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      );
    }
    return OrnatePanel(
      key: const Key('act3Road'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.directions_walk_rounded, color: AppColors.goldBright, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                  '「${next.name}」 가는 길',
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
            Text('${comma(r.steps.clamp(0, r.need))} / ${comma(r.need)}보',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          GlowBar(ratio: r.steps / r.need, colors: BarColors.exp, height: 6),
          if (c.canEnterNext) ...[
            const SizedBox(height: 6),
            GoldButton(
              key: const Key('enterRegion'),
              label: '「${next.name}」으로 들어가기',
              height: 42,
              fontSize: 16,
              onPressed: () async {
                final reg = await c.enterNextRegion();
                if (reg == null || !mounted) return;
                setState(() => _tab = 0);
                await showRegionArrive(context, c, reg);
              },
            ),
          ] else if (r.steps >= r.need) ...[
            const SizedBox(height: 4),
            KText(
                !c.regionLit(c.currentRegion.id)
                    ? '길이 뚫렸어요. 이 지역 등불을 켜면 들어갈 수 있어요.'
                    : '길이 뚫렸어요. Lv.${next.level}이 되면 들어갈 수 있어요.',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

/// 동료 얼굴 (이야기 동료는 얼굴 그림, 이름 없는 동료는 직업 색 동그라미)
class AllyFace extends StatelessWidget {
  const AllyFace({super.key, required this.look, this.size = 40});

  final ({String? art, String? face, int color}) look;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(look.color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.3),
        border: Border.all(color: AppColors.goldBright, width: 1.4),
      ),
      child: ClipOval(
        child: look.face == null
            ? Icon(Icons.person_rounded, color: color, size: size * 0.7)
            : Image.asset(look.face!,
                fit: BoxFit.cover,
                // 직업 그림(전신)은 얼굴 쪽만
                alignment: look.face!.contains('ally_job_')
                    ? const Alignment(0, -0.8)
                    : Alignment.center,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.person_rounded, color: color, size: size * 0.7)),
      ),
    );
  }
}

/// 지역 지도: 그림 위에 장소 아이콘 (눌러서 이동)
class _RegionMap extends StatelessWidget {
  const _RegionMap({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final r = c.currentRegion;
    return LayoutBuilder(builder: (context, box) {
      const ratio = 1024 / 1536;
      var w = box.maxWidth, h = w / ratio;
      if (h > box.maxHeight) {
        h = box.maxHeight;
        w = h * ratio;
      }
      return Center(
        child: SizedBox(
          key: const Key('regionMap'),
          width: w,
          height: h,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(children: [
              Positioned.fill(
                child: Image.asset(r.map,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xFF2A2C4A))),
              ),
              for (final p in r.places)
                Positioned(
                  left: p.x * w - 44,
                  top: p.y * h - 26,
                  width: 88,
                  child: _PlaceMark(
                      place: p,
                      name: placeName(c, p),
                      alert: placeAlert(c, p.id),
                      onTap: () => showPlaceSheet(context, c, p.id)),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

/// 장소 아이콘 위 「!」 (할 이야기 · 보고할 퀘스트가 있는 곳)
bool placeAlert(AppController c, String id) => switch (id) {
      'baldrin_town' => c.volkTalkPending ||
          [for (final q in SideQuest.values) c.sideReady(q)].any((x) => x) ||
          Resident.values.any((r) => c.residentOffer(r) != null),
      'baldrin_ashplain' => c.mainStep == 0,
      'baldrin_wallroad' => c.wallPending,
      'baldrin_wolfhill' => c.nestPending,
      'baldrin_fort' => c.dungeonOpen && !c.baldrinLit,
      'baldrin_windden' => c.denOpen && !c.denCleared,
      _ => _regionAlert(c, id),
    };

bool _regionAlert(AppController c, String id) {
  final r = RegionRules.byPlace(id);
  if (r == null) return false;
  final p = Act3Rules.place(id);
  final step = c.regionStep(r);
  return switch (p?.kind) {
    SpotKind.town => c.regionTalkPending(r) ||
        r.quests.any((q) => c.questReady(q)) ||
        r.residents.any((x) => c.regionOffer(r, x) != null) ||
        c.regionAllyOffers(r).isNotEmpty,
    SpotKind.dungeon => c.regionDungeonOpen(r) && !c.regionLit(r.region),
    SpotKind.hidden => c.regionHiddenOpen(r) && !c.regionHiddenCleared(r),
    _ => (step == 0 && id == r.mains.first.place) ||
        (id == r.eventPlace && (c.regionEventPending(r) || (c.regionChoicePending(r) && !r.choice.afterLamp))),
  };
}

class _PlaceMark extends StatelessWidget {
  const _PlaceMark(
      {required this.place, required this.name, required this.onTap, this.alert = false});

  final PlaceInfo place;
  final String name;
  final bool alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (place.kind) {
      SpotKind.town => Icons.holiday_village_rounded,
      SpotKind.field => Icons.landscape_rounded,
      SpotKind.dungeon => Icons.fort_rounded,
      SpotKind.hidden => Icons.help_outline_rounded,
    };
    return GestureDetector(
      key: Key('place_${place.id}'),
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xE6141638),
            border: Border.all(color: AppColors.goldBright, width: 1.4),
            boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 6)],
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Center(child: Icon(icon, size: 19, color: AppColors.goldBright)),
            if (alert)
              Positioned(
                right: -4,
                top: -6,
                child: Container(
                  key: Key('placeAlert_${place.id}'),
                  width: 16,
                  height: 16,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: Color(0xFFE0533F), shape: BoxShape.circle),
                  child: const Text('!',
                      style: TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xD9101024),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.text, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// 3막 싸움 하나를 한다 (끝나면 결과). 지면 야영지로
Future<Act3FightResult?> runEncounter(BuildContext context, AppController c, A3Enc e,
    {Duration tick = const Duration(milliseconds: 900)}) async {
  final r = await Navigator.of(context).push<Act3FightResult>(MaterialPageRoute(
      builder: (_) => Act3BattleScreen(controller: c, encounter: e, tickInterval: tick)));
  if (r != null && !r.won && context.mounted && e.kind != A3Kind.floor &&
      e.kind != A3Kind.mid && e.kind != A3Kind.lamp) {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => townFor(c)));
  }
  return r;
}

/// 장소 이름 (바람의 굴은 열리기 전엔 ???)
String placeName(AppController c, PlaceInfo p) {
  if (p.kind != SpotKind.hidden) return p.name;
  if (RegionRules.byPlace(p.id) case final r?) {
    return c.regionHiddenOpen(r) ? r.hidden.name : p.name;
  }
  return c.denOpen ? '바람의 굴' : p.name;
}

/// 장소를 눌렀을 때: 마을 · 요새는 그 화면으로, 필드는 싸우기 + 이야기 · 퀘스트, 숨은 장소는 ???
Future<void> showPlaceSheet(BuildContext context, AppController c, String id) async {
  final p = Act3Rules.place(id);
  if (p == null) return;
  final reg = RegionRules.byPlace(id);
  if (p.kind == SpotKind.town) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => townFor(c)));
    return;
  }
  if (p.kind == SpotKind.dungeon && (reg == null ? c.dungeonOpen : c.regionDungeonOpen(reg))) {
    await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => FortScreen(controller: c, region: reg)));
    return;
  }
  if (!context.mounted) return;
  final go = await showModalBottomSheet<A3Enc>(
    context: context,
    backgroundColor: AppColors.night,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        key: Key('placeSheet_$id'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _placeBody(sheet, c, p),
        ),
      ),
    ),
  );
  if (go == null || !context.mounted) return;
  final r = await runEncounter(context, c, go);
  if (!context.mounted || r == null || !r.won) return;
  if (go.kind == A3Kind.wall && c.choicePending) {
    await openLetterChoice(context, c);
  }
  if (!context.mounted) return;
  if (go.kind == A3Kind.event && reg != null && c.regionChoicePending(reg)) {
    await openRegionChoice(context, c, reg);
  }
}

String _energyLabel(AppController c, int cost, String what) => c.journeyEnergy < cost
    ? '여정 기력이 모자라요 · 걸으면 차요'
    : c.hp <= 0
        ? 'HP가 없어요 · 천막 여관에서 쉬어요'
        : '$what · 여정 기력 $cost';

List<Widget> _placeBody(BuildContext sheet, AppController c, PlaceInfo p) {
  Widget fight(Key key, String label, A3Enc e) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: GoldButton(
          key: key,
          height: 50,
          fontSize: 18,
          label: _energyLabel(c, e.energy, label),
          onPressed: c.journeyEnergy >= e.energy && c.hp > 0
              ? () => Navigator.of(sheet).pop(e)
              : null,
        ),
      );
  final out = <Widget>[
    Text(placeName(c, p), style: AppText.title(19)),
    const SizedBox(height: 8),
  ];
  final reg = RegionRules.byPlace(p.id);
  if (reg != null) return out..addAll(_regionPlaceBody(sheet, c, p, reg, fight));
  if (p.monster case final m?) {
    out.addAll([
      Row(children: [
        MonsterPicture(monster: m, size: 76),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Monsters.info(m).name,
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
              KText(Monsters.info(m).description,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ],
          ),
        ),
      ]),
      const SizedBox(height: 4),
      GoldButton(
        key: const Key('placeFight'),
        height: 50,
        fontSize: 18,
        label: _energyLabel(c, Act3Rules.energyField, '싸우기'),
        onPressed: c.canFieldFight(p.id)
            ? () => Navigator.of(sheet).pop(A3Enc(
                  kind: A3Kind.field,
                  place: p.id,
                  foes: [m, if (m == MonsterId.goblinRaider) m],
                  energy: Act3Rules.energyField,
                  background: p.background,
                ))
            : null,
      ),
    ]);
    // 메인 ③ 성벽길 · 한나 퀘스트 하피 둥지
    if (p.id == 'baldrin_wallroad' && c.wallPending && !c.choicePending) {
      out.add(fight(const Key('wallSearch'), '성벽길 안쪽 살피기', c.wallFight));
    }
    if (p.id == 'baldrin_wallroad' && c.choicePending) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: FrameButton(
          key: const Key('letterAgain'),
          label: '테오의 편지',
          onPressed: () {
            Navigator.of(sheet).pop();
            openLetterChoice(sheet, c);
          },
        ),
      ));
    }
    if (p.id == 'baldrin_wolfhill' && c.nestPending) {
      out.add(fight(const Key('nestFight'), '하피 둥지로', c.nestFight));
    }
    if (p.id == 'baldrin_wolfhill' && !c.hasSilverFur && !c.denOpen) {
      out.add(const Padding(
        padding: EdgeInsets.only(top: 8),
        child: KText('언덕 어딘가에 은빛 털이 반짝인다는 소문이 있어요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      ));
    }
  } else if (p.kind == SpotKind.hidden) {
    if (c.denOpen) {
      out.addAll([
        for (final l in BaldrinRules.denLines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: KText(l, style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.45)),
          ),
        if (c.hasWindPet)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: KText(BaldrinRules.denWolfLine,
                key: Key('denWolfLine'),
                style: TextStyle(color: AppColors.goldBright, fontSize: 14, height: 1.45)),
          ),
        fight(const Key('denFight'), c.denCleared ? '다시 싸우기' : '잿빛 늑대 우두머리와 싸우기', c.denFight),
      ]);
    } else {
      out.add(KText(
          c.hasSilverFur
              ? '은빛 털에서 바람 냄새가 나요. 아르카 마을 펫 쉼터의 루미에게 보여 주면 길을 알지도 몰라요.'
              : '아직 길을 찾지 못한 곳이에요.',
          style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.45)));
    }
  } else {
    out.add(const KText('잿빛이 기어 나오는 요새예요. 성벽길에서 테오의 흔적을 찾은 뒤에 들어갈 수 있어요.',
        style: TextStyle(color: AppColors.text, fontSize: 14, height: 1.45)));
  }
  return out;
}

/// 묶음 57: 지역 2~5 장소 (필드 · 숨은 장소 · 던전)
List<Widget> _regionPlaceBody(BuildContext sheet, AppController c, PlaceInfo p, RegionContent r,
    Widget Function(Key, String, A3Enc) fight) {
  const style = TextStyle(color: AppColors.text, fontSize: 14, height: 1.45);
  final out = <Widget>[];
  if (p.monster case final m?) {
    out.addAll([
      Row(children: [
        MonsterPicture(monster: m, size: 76),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Monsters.info(m).name,
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
              KText(Monsters.info(m).description,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ],
          ),
        ),
      ]),
      fight(
          const Key('placeFight'),
          '싸우기',
          A3Enc(
              kind: A3Kind.field,
              place: p.id,
              foes: [m],
              energy: Act3Rules.energyField,
              background: p.background)),
    ]);
    if (p.id == r.eventPlace && c.regionEventPending(r)) {
      out.add(fight(const Key('eventFight'), r.eventLabel, c.regionEventFight(r)));
    }
    if (p.id == r.eventPlace && c.regionChoicePending(r) && !r.choice.afterLamp) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: FrameButton(
          key: const Key('regionChoiceAgain'),
          label: r.choice.title,
          onPressed: () {
            Navigator.of(sheet).pop();
            openRegionChoice(sheet, c, r);
          },
        ),
      ));
    }
    for (final q in r.quests) {
      if (q.place == p.id && q.kind == RQKind.hunt && c.questState(q) == 1 && !c.questReady(q)) {
        out.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: KText('「${q.title}」 ${questProgText(c, q)} · 여기서 이기면 나아가요',
              style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5)),
        ));
      }
    }
  } else if (p.kind == SpotKind.hidden) {
    if (c.regionHiddenOpen(r)) {
      out.addAll([
        for (final l in r.hidden.lines)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: KText(l, style: style)),
        if (c.regionHasPet(r) && r.hidden.petLine != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: KText(r.hidden.petLine!,
                key: const Key('hiddenPetLine'),
                style: const TextStyle(color: AppColors.goldBright, fontSize: 14, height: 1.45)),
          ),
        fight(
            const Key('hiddenFight'),
            c.regionHiddenCleared(r)
                ? '다시 싸우기'
                : '${Monsters.info(r.hidden.boss).name}와(과) 싸우기',
            c.regionHiddenFight(r)),
      ]);
    } else {
      out.add(KText(r.hidden.locked, style: style));
    }
  } else {
    out.add(KText(
        r.choice.afterLamp
            ? '「${r.eventLabel}」을 끝낸 뒤에 들어갈 수 있어요.'
            : '「${r.choice.title}」을 고른 뒤에 들어갈 수 있어요.',
        style: style));
  }
  return out;
}

/// 일지 (메인 · 서브 · 끝낸 것)
class _Journal extends StatelessWidget {
  const _Journal({required this.controller, required this.onGo});

  final AppController controller;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c.regionNow case final r?) return _RegionJournal(controller: c, region: r, onGo: onGo);
    final main = c.journalMain;
    final open = [for (final q in main) if (!q.done) q];
    final done = [for (final q in main) if (q.done) q];
    final sides = c.journalSides;
    Widget card({
      required Key key,
      required String title,
      required String text,
      required bool done,
      String? place,
      String? extra,
      String? reward,
    }) =>
        OrnatePanel(
          key: key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(done ? Icons.check_circle_rounded : Icons.flag_rounded,
                    size: 18, color: AppColors.goldBright),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: AppText.title(16))),
                Text(c.currentRegion.name,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ]),
              const SizedBox(height: 4),
              KText(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              if (extra != null)
                Text(extra, style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5)),
              if (reward != null)
                Text('보상 · $reward',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              if (!done && place != null) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: Key('questGo_$title'),
                    onPressed: () => onGo(place),
                    child: const Text('그 장소로 가기'),
                  ),
                ),
              ],
            ],
          ),
        );
    const sideReward = '모집권 ${BaldrinRules.sideTickets} · 금화 ${BaldrinRules.sideGold}';
    return ListView(children: [
      Text('메인', style: AppText.title(15, color: AppColors.goldBright)),
      const SizedBox(height: 6),
      for (final q in open) ...[
        card(key: Key('quest_${q.title}'), title: q.title, text: q.text, done: false, place: q.place),
        const SizedBox(height: 8),
      ],
      if (open.isEmpty)
        const KText('관문의 등불이 켜졌어요. 다음 이야기는 셀레니아 대장터에서 이어져요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      const SizedBox(height: 14),
      Text('서브', style: AppText.title(15, color: AppColors.goldBright)),
      const SizedBox(height: 6),
      for (final s in sides.where((x) => !x.done)) ...[
        card(
          key: Key('side_${s.q.id.name}'),
          title: s.q.title,
          text: s.q.task,
          done: false,
          place: s.q.place,
          extra: s.ready
              ? '다 했어요 · ${s.q.garen ? '초소장의 의뢰판에서' : '${BaldrinRules.resident(s.q.giver!).name}에게'} 알려 주세요'
              : s.q.id == SideQuest.stall
                  ? null
                  : '${s.prog} / ${s.q.target}',
          reward: s.q.garen ? '가렌 스킬 ④ · $sideReward' : sideReward,
        ),
        const SizedBox(height: 8),
      ],
      if (sides.where((x) => !x.done).isEmpty)
        const KText('피난민 야영지 사람들이 부탁할 일이 있을지도 몰라요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      if (done.isNotEmpty || sides.any((x) => x.done) || c.act3.choice != null) ...[
        const SizedBox(height: 14),
        Text('끝낸 것', style: AppText.title(15, color: AppColors.goldBright)),
        const SizedBox(height: 6),
        if (c.act3.choice case final ch?) ...[
          card(
            key: const Key('doneChoice'),
            title: BaldrinRules.choiceTitle,
            text: ch == 'marta' ? BaldrinRules.choiceMarta.title : BaldrinRules.choiceGaren.title,
            done: true,
          ),
          const SizedBox(height: 8),
        ],
        for (final q in done) ...[
          card(key: Key('quest_${q.title}'), title: q.title, text: q.text, done: true),
          const SizedBox(height: 8),
        ],
        for (final s in sides.where((x) => x.done)) ...[
          card(key: Key('side_${s.q.id.name}'), title: s.q.title, text: s.q.task, done: true),
          const SizedBox(height: 8),
        ],
      ],
    ]);
  }
}

/// 지역 2~5 일지
class _RegionJournal extends StatelessWidget {
  const _RegionJournal({required this.controller, required this.region, required this.onGo});

  final AppController controller;
  final RegionContent region;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final r = region;
    final main = c.regionJournal(r);
    final open = [for (final q in main) if (!q.done) q];
    final done = [for (final q in main) if (q.done) q];
    final sides = [for (final q in r.quests) if (c.questState(q) > 0) q];
    final choice = c.regionChoice(r);
    Widget card(Key key, String title, String text, bool isDone,
            {String? place, String? extra, String? reward}) =>
        OrnatePanel(
          key: key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(isDone ? Icons.check_circle_rounded : Icons.flag_rounded,
                    size: 18, color: AppColors.goldBright),
                const SizedBox(width: 6),
                Expanded(child: Text(title, style: AppText.title(16))),
                Text(c.currentRegion.name,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ]),
              const SizedBox(height: 4),
              KText(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              if (extra != null)
                Text(extra, style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5)),
              if (reward != null)
                Text('보상 · $reward', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              if (!isDone && place != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: Key('questGo_$title'),
                    onPressed: () => onGo(place),
                    child: const Text('그 장소로 가기'),
                  ),
                ),
            ],
          ),
        );
    const reward = '모집권 ${RegionRules.sideTickets} · 금화 ${RegionRules.sideGold}';
    String who(RQuest q) => q.ally != null
        ? '의뢰판에서 ${Act3Rules.story(q.ally!).name}에게'
        : '${r.resident(q.giver!).name}에게';
    return ListView(children: [
      Text('메인', style: AppText.title(15, color: AppColors.goldBright)),
      const SizedBox(height: 6),
      for (final q in open) ...[
        card(Key('quest_${q.title}'), q.title, q.text, false, place: q.place),
        const SizedBox(height: 8),
      ],
      if (open.isEmpty)
        KText(
            r.region == Region.aurel
                ? '다섯 등불이 모두 켜졌어요.'
                : '${Act3Rules.region(r.region).name}의 등불이 켜졌어요. 다음 지역 길을 걸어요.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      const SizedBox(height: 14),
      Text('서브', style: AppText.title(15, color: AppColors.goldBright)),
      const SizedBox(height: 6),
      for (final q in sides.where((x) => c.questState(x) == 1)) ...[
        card(Key('side_${q.id}'), q.title, q.task, false,
            place: q.place,
            extra: c.questReady(q) ? '다 했어요 · ${who(q)} 알려 주세요' : questProgText(c, q),
            reward: q.ally != null ? '${Act3Rules.story(q.ally!).name} 스킬 ④ · $reward' : reward),
        const SizedBox(height: 8),
      ],
      if (sides.where((x) => c.questState(x) == 1).isEmpty)
        KText('${r.townName} 사람들이 부탁할 일이 있을지도 몰라요.',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      if (done.isNotEmpty || sides.any((x) => c.questState(x) == 2) || choice != null) ...[
        const SizedBox(height: 14),
        Text('끝낸 것', style: AppText.title(15, color: AppColors.goldBright)),
        const SizedBox(height: 6),
        if (choice != null) ...[
          card(const Key('doneChoice'), r.choice.title,
              choice == r.choice.a.key ? r.choice.a.title : r.choice.b.title, true),
          const SizedBox(height: 8),
        ],
        for (final q in done) ...[
          card(Key('quest_${q.title}'), q.title, q.text, true),
          const SizedBox(height: 8),
        ],
        for (final q in sides.where((x) => c.questState(x) == 2)) ...[
          card(Key('side_${q.id}'), q.title, q.task, true),
          const SizedBox(height: 8),
        ],
      ],
    ]);
  }
}

/// 세계 지도: 지역 다섯 (지금 지역 밝게 · 앞으로 갈 곳은 안개 + 필요 레벨) · 이름 있는 장비 모음
class _WorldMap extends StatelessWidget {
  const _WorldMap({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final cur = c.act3.region;
    return ListView(children: [
      for (final (i, r) in Act3Rules.regions.indexed) ...[
        Opacity(
          opacity: c.regionReached(r.id) ? 1 : 0.5,
          child: OrnatePanel(
            key: Key('region_${r.id.name}'),
            highlight: i == cur,
            child: InkWell(
              onTap: c.canTravelTo(r.id)
                  ? () async {
                      if (await c.travelTo(r.id) && context.mounted) {
                        showTopNotice(context, '「${r.name}」으로 왔어요');
                      }
                    }
                  : null,
              child: Row(children: [
                Icon(c.regionReached(r.id) ? Icons.local_fire_department_rounded : Icons.cloud_rounded,
                    color: c.regionLit(r.id)
                        ? AppColors.goldBright
                        : c.regionReached(r.id)
                            ? AppColors.text
                            : AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.regionReached(r.id) ? r.name : '안개 너머',
                          style: AppText.title(16, color: AppColors.text)),
                      Text(
                          c.regionReached(r.id)
                              ? (c.regionLit(r.id) ? '등불을 켰어요 · ${r.blurb}' : r.blurb)
                              : 'Lv.${r.level}',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                if (i == cur)
                  const Text('지금 여기',
                      style: TextStyle(color: AppColors.goldBright, fontSize: 12))
                else if (c.canTravelTo(r.id))
                  Text('가기', key: Key('travel_${r.id.name}'),
                      style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      FrameButton(
        key: const Key('uniqueBook'),
        label: '이름 있는 장비 모음',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => UniqueBookScreen(controller: controller))),
      ),
      const SizedBox(height: 10),
      const KText('파티 · 준비 중 — 같은 지역을 걷는 각성자는 서버가 열리면 보여요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ]);
  }
}

/// 3막 싸움 (동료 둘과 함께). 끝나면 결과를 돌려줌
class Act3BattleScreen extends StatefulWidget {
  const Act3BattleScreen({
    super.key,
    required this.controller,
    this.placeId,
    this.encounter,
    this.tickInterval = const Duration(milliseconds: 900),
  });

  final AppController controller;

  /// 지역 지도 필드 사냥 (encounter 가 없을 때)
  final String? placeId;
  final A3Enc? encounter;
  final Duration tickInterval;

  @override
  State<Act3BattleScreen> createState() => _Act3BattleScreenState();
}

class _Act3BattleScreenState extends State<Act3BattleScreen> {
  AppController get c => widget.controller;
  Battle? _battle;
  Act3FightResult? _result;
  late final A3Enc? _enc = widget.encounter;
  late final PlaceInfo? _place = Act3Rules.place(_enc?.place ?? widget.placeId ?? '');
  late final List<({String? art, String? face, int color})> _looks = [
    for (final a in c.partyAllies) c.allyLook(a),
  ];

  late final RegionContent? _reg = RegionRules.byPlace(_enc?.place ?? '');
  int get _floorNo => _reg == null ? c.floorNow : c.regionFloorNow(_reg);

  String get _title => switch (_enc?.kind) {
        A3Kind.floor || A3Kind.mid || A3Kind.lamp => '${_reg?.dungeonName ?? '문지기 지하 요새'} $_floorNo층',
        A3Kind.den when _reg != null => _reg.hidden.name,
        A3Kind.den => '바람의 굴',
        A3Kind.nest => '하피 둥지',
        _ => _place == null ? '다리 너머' : placeName(c, _place),
      };

  @override
  void initState() {
    super.initState();
    c.holdNoticesWhile(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    c.holdNoticesWhile(false);
    super.dispose();
  }

  Future<void> _start() async {
    if (c.resting) {
      final ok = await confirmStopResting(context);
      if (!ok || !mounted) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }
    final e = _enc;
    final b = e != null ? c.startEncounter(e) : c.startAct3Fight(widget.placeId ?? '');
    if (!mounted) return;
    if (b == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _battle = b);
  }

  Future<void> _finish() async {
    final r = await c.finishAct3Fight(_battle!);
    if (mounted) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final b = _battle;
    final inFort = switch (_enc?.kind) {
      A3Kind.floor || A3Kind.mid || A3Kind.lamp => true,
      _ => false,
    };
    return Scaffold(
      key: const Key('act3Battle'),
      backgroundColor: AppColors.deepNight,
      bottomNavigationBar: _result == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FrameButton(
                  key: const Key('act3Back'),
                  label: _result!.won
                      ? (inFort ? '계속' : '지도로')
                      : (_reg == null ? '피난민 야영지로' : '${_reg.townName}(으)로'),
                  onPressed: () => Navigator.of(context).pop(_result),
                ),
              ),
            ),
      body: NightBackground(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrnateTopBar(title: _title, onBack: null),
              const SizedBox(height: 10),
              Expanded(
                child: b == null
                    ? const SizedBox()
                    : _result != null
                        ? _resultView(_result!)
                        : BattleView(
                            battle: b,
                            fit: true,
                            allyArts: _looks,
                            jobSkills: c.battleBarJobSlots,
                            bar: c.battleBar,
                            emptySlots: c.skillPageOpen,
                            jobMp: () => c.jobMp,
                            onJobSkill: c.payBattleSkill,
                            onMasterySkill: c.payMasterySkill,
                            background: _enc?.background ??
                                _place?.background ??
                                Act3Rules.fallbackBackground,
                            aura: switch (c.gear.sets.look) {
                              final set? => Color(BossGearRules.info(set).aura),
                              null => null,
                            },
                            onFinished: _finish,
                            // 묶음 53: 위 띠 (요새 층 · 보스)
                            floorLabelOf: (b) => switch (_enc?.kind) {
                              A3Kind.mid || A3Kind.lamp || A3Kind.den => 'BOSS',
                              A3Kind.floor => '$_floorNo층',
                              _ => b.floors.length == 1
                                  ? '필드 전투'
                                  : '${b.floor + 1} / ${b.floors.length}마리',
                            },
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
                            onAutoChanged: (hp, cure) =>
                                c.setAutoUse(hpPercent: hp, cure: cure),
                            poisonTip: !c.poisonTipSeen,
                            onPoisonTipShown: c.markPoisonTipSeen,
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultView(Act3FightResult r) {
    final foe = _battle!.floors.first.monster;
    return ListView(children: [
      BulssiLine(
          line: r.won
              ? (r.firstFight
                  ? '저쪽 세계에서의 첫 싸움, 해냈어! 리안이랑 가렌도 같이였어.'
                  : Monsters.info(foe).huntLine)
              : '이번엔 물러났어. 야영지에서 숨 좀 돌리자. 얻은 건 그대로야.',
          mood: r.won ? SpiritMood.cheer : SpiritMood.worried),
      const SizedBox(height: 10),
      if (r.won)
        OrnatePanel(
          key: const Key('act3Reward'),
          ornament: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('경험치 +${r.exp} · 금화 +${r.gold}',
                  textAlign: TextAlign.center, style: AppText.title(17)),
              if (r.tickets > 0)
                Text('모집권 +${r.tickets}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.goldBright, fontSize: 14)),
              for (final it in r.items) ...[
                const SizedBox(height: 8),
                Row(children: [
                  EquipIcon(base: it.base, grade: it.grade, size: 52),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [EquipName(it, size: 15), ItemStats(it, fontSize: 12)],
                    ),
                  ),
                ]),
              ],
              for (final e in r.allyLevels.entries) ...[
                const SizedBox(height: 6),
                Text('${e.key} Lv.${e.value}!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.goldBright, fontSize: 14)),
              ],
              for (final l in r.lines) ...[
                const SizedBox(height: 8),
                KText(l,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.4)),
              ],
              if (r.firstFight) ...[
                const SizedBox(height: 8),
                const Text('일지 · 「잿빛 들판에서 첫 싸움」을 끝냈어요',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.text, fontSize: 13)),
              ],
            ],
          ),
        ),
    ]);
  }
}
