import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../awakening/awakening_screen.dart' show IllustratedScene;
import '../battle/battle_view.dart';
import '../battle/dungeon_screen.dart' show confirmStopResting;
import '../battle/hero_rig.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart' show SpiritMood;
import '../smithy/equipment_view.dart';
import '../village/tavern_screen.dart';

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
          tailX: switch (who) { 'lian' => 0.3, 'garen' => 0.7, _ => 0.5 },
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
                  next == null ? '다음 지역 길' : '「${next.name}」 가는 길',
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
            Text('${comma(r.steps.clamp(0, r.need))} / ${comma(r.need)}보',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          GlowBar(ratio: r.steps / r.need, colors: BarColors.exp, height: 6),
          if (r.steps >= r.need && next != null) ...[
            const SizedBox(height: 4),
            KText(
                r.levelOk
                    ? '길이 뚫렸어요. 다음 이야기에서 이어져요.'
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
                  child: _PlaceMark(place: p, onTap: () => showPlaceSheet(context, c, p.id)),
                ),
            ]),
          ),
        ),
      );
    });
  }
}

class _PlaceMark extends StatelessWidget {
  const _PlaceMark({required this.place, required this.onTap});

  final PlaceInfo place;
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
          child: Icon(icon, size: 19, color: AppColors.goldBright),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: const Color(0xD9101024),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(place.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.text, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// 장소를 눌렀을 때: 필드는 싸우기, 마을·던전은 다음 이야기, 숨은 장소는 ???
Future<void> showPlaceSheet(BuildContext context, AppController c, String id) {
  final p = Act3Rules.place(id);
  if (p == null) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.night,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: Padding(
        key: Key('placeSheet_$id'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(p.name, style: AppText.title(19)),
            const SizedBox(height: 8),
            if (p.monster case final m?) ...[
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
              const SizedBox(height: 10),
              GoldButton(
                key: const Key('placeFight'),
                label: c.journeyEnergy < Act3Rules.energyField
                    ? '여정 기력이 모자라요 · 걸으면 차요'
                    : c.hp <= 0
                        ? 'HP가 없어요 · 쉬고 오세요'
                        : '싸우기 · 여정 기력 ${Act3Rules.energyField}',
                onPressed: c.canFieldFight(id)
                    ? () {
                        Navigator.of(sheet).pop();
                        Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => Act3BattleScreen(controller: c, placeId: id)));
                      }
                    : null,
              ),
            ] else
              KText(
                  switch (p.kind) {
                    SpotKind.hidden => '아직 길을 찾지 못한 곳이에요.',
                    SpotKind.town => '피난민들이 천막을 치고 사는 야영지예요. 곧 문을 열어 줄 거예요.',
                    _ => '잿빛이 기어 나오는 요새예요. 곧 들어갈 수 있어요.',
                  },
                  style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.45)),
          ],
        ),
      ),
    ),
  );
}

/// 일지 (메인 · 서브 · 끝낸 것)
class _Journal extends StatelessWidget {
  const _Journal({required this.controller, required this.onGo});

  final AppController controller;
  final ValueChanged<String> onGo;

  @override
  Widget build(BuildContext context) {
    final main = controller.journalMain;
    final open = [for (final q in main) if (!q.done) q];
    final done = [for (final q in main) if (q.done) q];
    Widget row(({String title, String text, bool done}) q) => OrnatePanel(
          key: Key('quest_${q.title}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(q.done ? Icons.check_circle_rounded : Icons.flag_rounded,
                    size: 18, color: AppColors.goldBright),
                const SizedBox(width: 6),
                Expanded(child: Text(q.title, style: AppText.title(16))),
                Text(controller.currentRegion.name,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ]),
              const SizedBox(height: 4),
              KText(q.text,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
              if (!q.done) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const Key('questGo'),
                    onPressed: () => onGo('baldrin_ashplain'),
                    child: const Text('그 장소로 가기'),
                  ),
                ),
              ],
            ],
          ),
        );
    return ListView(children: [
      Text('메인', style: AppText.title(15, color: AppColors.goldBright)),
      const SizedBox(height: 6),
      for (final q in open) ...[row(q), const SizedBox(height: 8)],
      const KText('이야기는 곧 이어져요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      const SizedBox(height: 14),
      Text('서브', style: AppText.title(15, color: AppColors.goldBright)),
      const SizedBox(height: 6),
      const KText('야영지 사람들이 부탁할 일이 생길 거예요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      if (done.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('끝낸 것', style: AppText.title(15, color: AppColors.goldBright)),
        const SizedBox(height: 6),
        for (final q in done) ...[row(q), const SizedBox(height: 8)],
      ],
    ]);
  }
}

/// 세계 지도: 지역 다섯 (지금 지역 밝게 · 앞으로 갈 곳은 안개 + 필요 레벨)
class _WorldMap extends StatelessWidget {
  const _WorldMap({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final cur = controller.act3.region;
    return ListView(children: [
      for (final (i, r) in Act3Rules.regions.indexed) ...[
        Opacity(
          opacity: i <= cur ? 1 : 0.5,
          child: OrnatePanel(
            key: Key('region_${r.id.name}'),
            highlight: i == cur,
            child: Row(children: [
              Icon(i <= cur ? Icons.local_fire_department_rounded : Icons.cloud_rounded,
                  color: i <= cur ? AppColors.goldBright : AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i <= cur ? r.name : '안개 너머',
                        style: AppText.title(16, color: AppColors.text)),
                    Text(i <= cur ? r.blurb : 'Lv.${r.level}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              if (i == cur)
                const Text('지금 여기',
                    style: TextStyle(color: AppColors.goldBright, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
      ],
      const KText('파티 · 준비 중 — 같은 지역을 걷는 각성자는 서버가 열리면 보여요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ]);
  }
}

/// 3막 필드 싸움 (동료 둘과 함께)
class Act3BattleScreen extends StatefulWidget {
  const Act3BattleScreen({
    super.key,
    required this.controller,
    required this.placeId,
    this.tickInterval = const Duration(milliseconds: 900),
  });

  final AppController controller;
  final String placeId;
  final Duration tickInterval;

  @override
  State<Act3BattleScreen> createState() => _Act3BattleScreenState();
}

class _Act3BattleScreenState extends State<Act3BattleScreen> {
  AppController get c => widget.controller;
  Battle? _battle;
  Act3FightResult? _result;
  late final PlaceInfo _place = Act3Rules.place(widget.placeId)!;
  late final List<({String? art, String? face, int color})> _looks = [
    for (final a in c.partyAllies) c.allyLook(a),
  ];

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
    final b = c.startAct3Fight(widget.placeId);
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
                  label: _result!.won ? '지도로' : '피난민 야영지로',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
      body: NightBackground(
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrnateTopBar(title: _place.name, onBack: null),
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
                            jobSkills: c.battleJobSlots,
                            emptySlots: c.skillPageOpen,
                            jobMp: () => c.jobMp,
                            onJobSkill: c.payBattleSkill,
                            onMasterySkill: c.payMasterySkill,
                            background: _place.background ?? Act3Rules.fallbackBackground,
                            aura: switch (c.gear.sets.look) {
                              final set? => Color(BossGearRules.info(set).aura),
                              null => null,
                            },
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

  Widget _resultView(Act3FightResult r) => ListView(children: [
        BulssiLine(
            line: r.won
                ? (r.firstFight
                    ? '저쪽 세계에서의 첫 싸움, 해냈어! 리안이랑 가렌도 같이였어.'
                    : Monsters.info(_place.monster!).huntLine)
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
