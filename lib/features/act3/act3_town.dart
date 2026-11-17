import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../smithy/equipment_view.dart';
import '../town/shop_screen.dart' show ShopItemIcon, ShopScreen;
import 'act3_screen.dart';
import 'region_screens.dart';

/// 대사 한 줄의 말하는 이 (얼굴 · 이름)
({String name, String? face}) speakerOf(AppController c, String who) => switch (who) {
      'volk' || 'hanna' || 'pipi' || 'orum' => (
          name: BaldrinRules.resident(Resident.values.byName(who)).name,
          face: BaldrinRules.resident(Resident.values.byName(who)).face,
        ),
      'garen' => (name: '가렌', face: 'assets/images/npc_garen.webp'),
      'lian' => (name: '리안', face: 'assets/images/npc_lian.webp'),
      'marta' => (name: '마르타', face: 'assets/images/npc_marta.webp'),
      // 묶음 57: 지역 2~5 사람 · 이야기 동료
      'nia' => (name: '니아', face: 'assets/images/npc_nia.webp'),
      'barkan' => (name: '바르칸', face: 'assets/images/npc_barkan.webp'),
      'popo' => (name: '포포', face: 'assets/images/npc_popo.webp'),
      'sera' => (name: '세라', face: 'assets/images/npc_sera.webp'),
      'teo' => (name: '테오', face: 'assets/images/npc_teo.webp'),
      'kaspar' => (name: '카스파르', face: 'assets/images/npc_kaspar.webp'),
      'orben' => (name: '오르벤', face: 'assets/images/npc_orben.webp'),
      _ => _regionSpeaker(c, who),
    };

({String name, String? face}) _regionSpeaker(AppController c, String who) {
  for (final r in RegionRules.all) {
    for (final p in r.residents) {
      if (p.id == who) return (name: p.name, face: p.faceAsset);
    }
  }
  return (name: c.firstPet?.name ?? '펫', face: null);
}

/// 지금 지역의 마을 화면 (발드린은 피난민 야영지)
Widget townFor(AppController c) => switch (c.regionNow) {
      final r? => RegionTownScreen(controller: c, region: r),
      null => TownScreen(controller: c),
    };

Widget _face(String? asset, {double size = 44}) => ClipOval(
      child: Container(
        width: size,
        height: size,
        color: const Color(0x33E8C77A),
        child: asset == null
            ? const Icon(Icons.pets_rounded, color: AppColors.goldBright)
            : Image.asset(asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person_rounded, color: AppColors.goldBright)),
      ),
    );

/// 몇 줄짜리 대화 (얼굴 + 이름 + 말). 「다음」으로 넘김
Future<void> showTalk(BuildContext context, AppController c, List<(String, String)> lines,
    {Key? key}) async {
  var i = 0;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (d) => StatefulBuilder(
      builder: (d, set) {
        final (who, line) = lines[i];
        final sp = speakerOf(c, who);
        final last = i == lines.length - 1;
        return GameAlert(
          key: key ?? const Key('talkDialog'),
          title: Row(children: [
            _face(sp.face),
            const SizedBox(width: 10),
            Text(sp.name, style: AppText.title(18)),
          ]),
          content: KText(line,
              key: Key('talkLine_$i'),
              style: const TextStyle(color: AppColors.text, fontSize: 15, height: 1.5)),
          actions: [
            TextButton(
              key: const Key('talkNext'),
              onPressed: () => last ? Navigator.pop(d) : set(() => i++),
              child: Text(last ? '좋아요' : '다음'),
            ),
          ],
        );
      },
    ),
  );
}

/// 피난민 야영지 (묶음 53): 주민 4 · 천막 여관 · 피피의 노점 · 초소장의 의뢰판
class TownScreen extends StatelessWidget {
  const TownScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _talk(BuildContext context, Resident r) async {
    final c = controller;
    // 메인 ② 볼크 이야기
    if (r == Resident.volk && c.volkTalkPending) {
      await showTalk(context, c, BaldrinRules.volkTalk, key: const Key('volkTalk'));
      await c.markVolkTalk();
      if (context.mounted) showTopNotice(context, '일지 · 「성벽길의 흔적」이 열렸어요');
      return;
    }
    // 끝낸 퀘스트 보고
    for (final q in BaldrinRules.sides) {
      if (q.giver == r && c.sideReady(q.id)) {
        final ok = await c.reportSide(q.id);
        if (!context.mounted || !ok) return;
        await showTalk(context, c, [(r.name, q.done)]);
        if (context.mounted) {
          showTopNotice(context,
              '「${q.title}」 끝 · 모집권 +${BaldrinRules.sideTickets} · 금화 +${BaldrinRules.sideGold}');
        }
        return;
      }
    }
    // 맡길 퀘스트
    final offer = c.residentOffer(r);
    if (offer != null) {
      final take = await showDialog<bool>(
        context: context,
        builder: (d) => GameAlert(
          key: const Key('questOffer'),
          title: Row(children: [
            _face(BaldrinRules.resident(r).face),
            const SizedBox(width: 10),
            Expanded(child: Text(offer.title, style: AppText.title(17))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            KText(offer.ask,
                style: const TextStyle(color: AppColors.text, fontSize: 14.5, height: 1.5)),
            const SizedBox(height: 8),
            KText('할 일 · ${offer.task}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            Text('보상 · 모집권 ${BaldrinRules.sideTickets} · 금화 ${BaldrinRules.sideGold}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('나중에')),
            TextButton(
                key: const Key('questTake'),
                onPressed: () => Navigator.pop(d, true),
                child: const Text('맡을게요')),
          ],
        ),
      );
      if (take == true) await c.acceptSide(offer.id);
      return;
    }
    await showTalk(context, c, [(r.name, c.residentLine(r))]);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('townScreen'),
      backgroundColor: AppColors.deepNight,
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24),
          children: [
            OrnateTopBar(title: '피난민 야영지', onBack: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: ColorFiltered(
                  colorFilter: c.baldrinLit
                      ? const ColorFilter.mode(Color(0x00000000), BlendMode.dst)
                      : const ColorFilter.mode(Color(0x55101024), BlendMode.srcATop),
                  child: Image.asset(BaldrinRules.town,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2C4A))),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text('사람들', style: AppText.title(16)),
            const SizedBox(height: 6),
            Row(children: [
              for (final r in Resident.values)
                Expanded(
                  child: GestureDetector(
                    key: Key('resident_${r.name}'),
                    onTap: () => _talk(context, r),
                    child: Column(children: [
                      Stack(clipBehavior: Clip.none, children: [
                        _face(BaldrinRules.resident(r).face, size: 58),
                        if ((r == Resident.volk && c.volkTalkPending) ||
                            c.residentOffer(r) != null ||
                            BaldrinRules.sides.any((q) => q.giver == r && c.sideReady(q.id)))
                          const Positioned(
                            right: -2,
                            top: -4,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: Color(0xFFE0533F),
                              child: Text('!',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Text(BaldrinRules.resident(r).name,
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(BaldrinRules.resident(r).role,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            _inn(context),
            const SizedBox(height: 10),
            _stall(context),
            const SizedBox(height: 10),
            _board(context),
          ],
        ),
      ),
    );
  }

  Widget _inn(BuildContext context) {
    final c = controller;
    return OrnatePanel(
      key: const Key('townInn'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.bedroom_parent_rounded, color: AppColors.goldBright),
            const SizedBox(width: 6),
            Text('천막 여관', style: AppText.title(17)),
            const Spacer(),
            Text('HP ${c.hp} / ${c.maxHp}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          KText(
              c.innEnergyToday
                  ? '한나의 천막에서 쉬면 HP와 MP가 가득 차요. 오늘은 여정 기력도 조금 채워 줘요.'
                  : '한나의 천막에서 쉬면 HP와 MP가 가득 차요. 여정 기력은 내일 또 채워 줘요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 8),
          GoldButton(
            key: const Key('innRest'),
            label: '쉬기',
            height: 44,
            fontSize: 18,
            onPressed: () async {
              final got = await c.restAtTent();
              if (!context.mounted) return;
              showTopNotice(context,
                  got > 0 ? '푹 쉬었어요 · HP·MP 가득 · 여정 기력 +$got' : '푹 쉬었어요 · HP·MP 가득');
            },
          ),
        ],
      ),
    );
  }

  Widget _stall(BuildContext context) {
    final c = controller;
    return OrnatePanel(
      key: const Key('townStall'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.storefront_rounded, color: AppColors.goldBright),
            const SizedBox(width: 6),
            Text('피피의 노점', style: AppText.title(17)),
            const Spacer(),
            Text('금화 ${c.player.gold}',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
          ]),
          const SizedBox(height: 2),
          const KText('아르카 잡화상과 같은 값 · 하루 개수도 함께 세요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          for (final item in c.stallItems)
            Builder(builder: (context) {
              final info = TownRules.info(item);
              final check = c.canBuy(item);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  SizedBox(width: 44, height: 44, child: ShopItemIcon(c: c, info: info)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.name,
                            style: const TextStyle(
                                color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                        KText(info.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  TextButton(
                    key: Key('stall_${item.name}'),
                    style: gameButtonStyle(gold: check == PurchaseCheck.ok),
                    onPressed: () async {
                      if (check != PurchaseCheck.ok) {
                        showTopNotice(context, ShopScreen.reason(check, info, c.player.gold));
                        return;
                      }
                      final r = await c.buy(item);
                      if (!context.mounted) return;
                      showTopNotice(
                          context,
                          r == PurchaseCheck.ok
                              ? '${info.name}을(를) 샀어요'
                              : ShopScreen.reason(r, info, c.player.gold));
                    },
                    child: Text('금화 ${info.price}'),
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }

  Widget _board(BuildContext context) {
    final c = controller;
    final garen = c.garenOffer;
    final rosterReady = c.sideReady(SideQuest.roster);
    return OrnatePanel(
      key: const Key('townBoard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.assignment_rounded, color: AppColors.goldBright),
            const SizedBox(width: 6),
            Text('초소장의 의뢰판', style: AppText.title(17)),
          ]),
          const SizedBox(height: 4),
          const KText('야영지 사람들의 부탁이에요. 사람을 눌러 맡고, 다 하면 그 사람에게 알려요. '
              '되풀이 의뢰는 아르카 마을 의뢰 게시판에 붙어요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          for (final q in BaldrinRules.sides)
            if (c.sideState(q.id) == 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(c.sideReady(q.id) ? Icons.check_circle_rounded : Icons.flag_rounded,
                      size: 16, color: AppColors.goldBright),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(q.title,
                        style: const TextStyle(color: AppColors.text, fontSize: 13.5)),
                  ),
                  Text(
                      c.sideReady(q.id)
                          ? '다 했어요'
                          : q.id == SideQuest.stall
                              ? '재료 3종'
                              : '${c.sideProg(q.id)} / ${q.target}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ]),
              ),
          if (garen != null) ...[
            const SizedBox(height: 8),
            FrameButton(
              key: const Key('garenQuest'),
              label: '가렌의 부탁 · ${garen.title}',
              onPressed: () async {
                await showTalk(context, c, [('garen', garen.ask.replaceFirst('가렌: ', ''))]);
                await c.acceptSide(SideQuest.roster);
              },
            ),
          ],
          if (rosterReady) ...[
            const SizedBox(height: 8),
            GoldButton(
              key: const Key('garenReport'),
              label: '가렌에게 이름표 건네기',
              height: 44,
              fontSize: 17,
              onPressed: () async {
                final ok = await c.reportSide(SideQuest.roster);
                if (!ok || !context.mounted) return;
                await showTalk(context, c, [
                  ('garen', BaldrinRules.side(SideQuest.roster).done.replaceFirst('가렌: ', '')),
                ]);
                if (context.mounted) showTopNotice(context, '가렌 스킬 ④ 「신병 다섯의 함성」을 열 수 있어요');
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 문지기 지하 요새 (5층). 층마다 싸움 1~2번 → 갈림길 하나 → 다음 층
class FortScreen extends StatefulWidget {
  const FortScreen(
      {super.key, required this.controller, this.region, this.tick = const Duration(milliseconds: 900)});

  final AppController controller;

  /// 묶음 57: 지역 2~5 던전 (null 이면 발드린 지하 요새)
  final RegionContent? region;
  final Duration tick;

  @override
  State<FortScreen> createState() => _FortScreenState();
}

class _FortScreenState extends State<FortScreen> {
  AppController get c => widget.controller;
  RegionContent? get r => widget.region;
  int get _now => r == null ? c.floorNow : c.regionFloorNow(r!);
  int get _best => r == null ? c.floorBest : c.regionFloorBest(r!);
  List<FloorInfo> get _floors => r?.floors ?? BaldrinRules.floors;
  FloorInfo get _floor => r == null ? BaldrinRules.floors[c.floorNow - 1] : c.regionFloor(r!, _now);

  /// 층 싸움을 다 이겨 갈림길을 고를 차례
  bool _branching = false;
  String? _branchText;

  Future<void> _enter() async {
    final fights = r == null ? c.enterFloor() : c.regionEnterFloor(r!);
    if (fights == null) {
      showTopNotice(context, c.hp <= 0 ? 'HP가 없어요 · 천막 여관에서 쉬어요' : '여정 기력이 모자라요');
      return;
    }
    for (final e in fights) {
      if (!mounted) return;
      final r = await runEncounter(context, c, e, tick: widget.tick);
      if (!mounted) return;
      if (r == null || !r.won) {
        // 졌을 때: 야영지로 (도달한 층은 그대로)
        await Navigator.of(context)
            .pushReplacement(MaterialPageRoute<void>(builder: (_) => townFor(c)));
        return;
      }
      if (r.lamp && mounted) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true, builder: (_) => LampScreen(controller: c, region: widget.region)));
        if (widget.region case final reg? when mounted) await afterRegionLamp(context, c, reg);
      }
    }
    if (mounted) setState(() => _branching = true);
  }

  Future<void> _branch(Branch b) async {
    final reg = widget.region;
    final r = reg == null ? await c.takeBranch(b) : await c.regionTakeBranch(reg, b);
    if (!mounted) return;
    if (r.fight case final f?) {
      final res = await runEncounter(context, c, f, tick: widget.tick);
      if (!mounted) return;
      if (res == null || !res.won) {
        await Navigator.of(context)
            .pushReplacement(MaterialPageRoute<void>(builder: (_) => townFor(c)));
        return;
      }
    }
    String? more;
    if (reg == null) {
      await c.clearFloor();
    } else {
      more = await c.regionClearFloor(reg);
    }
    if (!mounted) return;
    setState(() {
      _branching = false;
      _branchText = [
        r.text,
        if (more != null) more,
        if (r.gold > 0) '금화 +${r.gold}',
        for (final it in r.items) EquipmentRules.info(it.base).name,
        if (r.hpLost > 0) 'HP -${r.hpLost}',
        if (r.exp > 0) '경험치 +${r.exp}',
      ].where((x) => x.isNotEmpty).join(' · ');
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('fortScreen'),
      backgroundColor: AppColors.deepNight,
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final f = _floor;
          final deep = f.n > _floors.length;
          final bossName = Monsters.info(f.foes.first).name;
          return ListView(
            padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24),
            children: [
              OrnateTopBar(
                  title: r?.dungeonName ?? '문지기 지하 요새',
                  onBack: _branching ? null : () => Navigator.of(context).maybePop()),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.asset(r?.dungeonBg ?? BaldrinRules.dungeonBg,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2C4A))),
                ),
              ),
              const SizedBox(height: 10),
              // 층 표시 (끝낸 층 금빛)
              if (deep)
                Row(children: [
                  const Icon(Icons.stairs_rounded, color: AppColors.goldBright),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('심층 ${f.n}층 · 가장 깊이 ${c.regionDeepBest(r!)}층',
                        key: const Key('deepFloor'),
                        style: const TextStyle(color: AppColors.goldBright, fontSize: 14)),
                  ),
                  if (!_branching)
                    TextButton(
                      key: const Key('leaveDeep'),
                      onPressed: () => c.leaveDeep(r!),
                      child: const Text('1층으로'),
                    ),
                ])
              else
              Row(children: [
                for (final fl in _floors)
                  Expanded(
                    child: Container(
                      key: Key('floor_${fl.n}'),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: fl.n <= _best ? const Color(0x55E8C77A) : const Color(0x22FFFFFF),
                        border: Border.all(
                            color: fl.n == _now ? AppColors.goldBright : Colors.transparent,
                            width: 1.4),
                      ),
                      child: Column(children: [
                        Text('${fl.n}층',
                            style: const TextStyle(
                                color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
                        if (fl.boss)
                          Icon(fl.lamp ? Icons.local_fire_department_rounded : Icons.warning_rounded,
                              size: 14, color: AppColors.goldBright),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 10),
              if (_branchText != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KText(_branchText!,
                      key: const Key('branchText'),
                      style: const TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.45)),
                ),
              if (_branching) ...[
                Text('갈림길', style: AppText.title(17)),
                const SizedBox(height: 6),
                for (final (b, title, text) in const [
                  (Branch.fight, '싸움의 길', '몬스터가 더 있지만 전리품도 더 있어요'),
                  (Branch.chest, '보물 상자 방', '보물이 있을지, 함정이 있을지'),
                  (Branch.story, '조용한 복도', '문지기들이 남긴 흔적을 살펴요'),
                ]) ...[
                  OrnatePanel(
                    key: Key('branch_${b.name}'),
                    child: InkWell(
                      onTap: () => _branch(b),
                      child: Row(children: [
                        Icon(switch (b) {
                          Branch.fight => Icons.sports_martial_arts_rounded,
                          Branch.chest => Icons.inventory_2_rounded,
                          Branch.story => Icons.menu_book_rounded,
                        }, color: AppColors.goldBright),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, style: AppText.title(16)),
                              KText(text,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                              // 묶음 57 #244: 셰이드(나이트메어)가 함정을 미리 알려 줌
                              if (b == Branch.chest && c.chestHint != null)
                                KText(c.chestHint!,
                                    key: const Key('chestHint'),
                                    style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ] else ...[
                Text('${f.n}층 · ${f.name}', style: AppText.title(17)),
                const SizedBox(height: 4),
                KText(
                    r != null
                        ? (f.lamp
                            ? (c.regionLit(r!.region)
                                ? '등불의 방. 잿빛이 다시 $bossName의 꼴로 뭉치고 있어요.'
                                : '등불의 방. 꺼진 등불 앞에 $bossName이(가) 버티고 있어요.')
                            : f.boss
                                ? '$bossName이(가) 길을 막고 있어요.'
                                : deep
                                    ? '심층. 내려갈수록 몬스터가 세져요. 5층마다 보스가 있어요.'
                                    : '층마다 싸움을 이기면 갈림길이 나와요. 중간에 나가도 이 층부터 다시 해요.')
                    : f.lamp
                        ? (c.baldrinLit
                            ? '등불의 방. 잿빛 찌꺼기가 다시 갑옷 꼴로 뭉치고 있어요.'
                            : '등불의 방. 거대한 빈 갑주가 꺼진 등불을 끌어안고 있어요.')
                        : f.boss
                            ? '사냥개 우리. 잿빛에 물든 사냥개 무리가 으르렁거려요.'
                            : '층마다 싸움을 이기면 갈림길이 나와요. 중간에 나가도 이 층부터 다시 해요.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 10),
                GoldButton(
                  key: const Key('enterFloor'),
                  label: c.journeyEnergy < Act3Rules.energyFloor
                      ? '여정 기력이 모자라요'
                      : '${f.n}층으로 · 여정 기력 ${Act3Rules.energyFloor}',
                  height: 50,
                  fontSize: 18,
                  onPressed: c.journeyEnergy >= Act3Rules.energyFloor && c.hp > 0 ? _enter : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 큰 고르기 「테오의 편지」
Future<void> openLetterChoice(BuildContext context, AppController c) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => LetterChoiceScreen(controller: c)));

class LetterChoiceScreen extends StatelessWidget {
  const LetterChoiceScreen({super.key, required this.controller});

  final AppController controller;

  Future<void> _pick(BuildContext context, bool marta) async {
    final c = controller;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text(marta ? BaldrinRules.choiceMarta.title : BaldrinRules.choiceGaren.title),
        content: const Text(BaldrinRules.choiceNote, style: TextStyle(color: AppColors.text)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('그만두기')),
          TextButton(
              key: const Key('choiceSure'),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('이걸로 할게요')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final nav = Navigator.of(context);
    final spear = await c.chooseLetter(marta: marta);
    if (!context.mounted) return;
    await showTalk(context, c, marta ? BaldrinRules.martaScene : BaldrinRules.garenScene,
        key: Key(marta ? 'martaScene' : 'garenScene'));
    if (!context.mounted) return;
    showTopNotice(
        context,
        marta
            ? '마르타의 도시락 ${BaldrinRules.lunchCount}개를 받았어요 · 일지 「문지기 지하 요새」'
            : '${spear == null ? '' : '${EquipmentRules.info(spear.base).name}을 얻었어요 · '}일지 「문지기 지하 요새」');
    nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    Widget card(Key key, ({String title, String text}) o, IconData icon, bool marta) => OrnatePanel(
          key: key,
          ornament: true,
          child: InkWell(
            onTap: () => _pick(context, marta),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(icon, color: AppColors.goldBright, size: 34),
                const SizedBox(height: 6),
                Text(o.title, textAlign: TextAlign.center, style: AppText.title(19)),
                const SizedBox(height: 6),
                KText(o.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.45)),
              ],
            ),
          ),
        );
    return Scaffold(
      key: const Key('letterChoice'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, pad.top + 8, 16, pad.bottom + 24),
          children: [
            OrnateTopBar(title: BaldrinRules.choiceTitle, onBack: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 10),
            const KText(BaldrinRules.letterLine,
                style: TextStyle(color: AppColors.text, fontSize: 15, height: 1.5)),
            const SizedBox(height: 4),
            const Text(BaldrinRules.choiceNote,
                style: TextStyle(color: AppColors.goldBright, fontSize: 13)),
            const SizedBox(height: 14),
            card(const Key('choiceMarta'), BaldrinRules.choiceMarta, Icons.mail_rounded, true),
            const SizedBox(height: 12),
            card(const Key('choiceGaren'), BaldrinRules.choiceGaren, Icons.shield_rounded, false),
          ],
        ),
      ),
    );
  }
}

/// 등불을 켬: 지역 지도가 밝아지는 연출 + 열리는 것
class LampScreen extends StatefulWidget {
  const LampScreen({super.key, required this.controller, this.region});

  final AppController controller;

  /// 묶음 57: 지역 2~5 (null 이면 발드린)
  final RegionContent? region;

  @override
  State<LampScreen> createState() => _LampScreenState();
}

class _LampScreenState extends State<LampScreen> {
  int _shown = 0;

  @override
  void initState() {
    super.initState();
    _step();
  }

  Future<void> _step() async {
    final r = widget.region;
    final total = (r?.lampLines ?? BaldrinRules.lampLines).length +
        (r?.lampUnlocks ?? BaldrinRules.lampUnlocks).length;
    while (mounted && _shown < total) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _shown++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final r = widget.region;
    final lines = r?.lampLines ?? BaldrinRules.lampLines;
    final unlocks = r?.lampUnlocks ?? BaldrinRules.lampUnlocks;
    return Scaffold(
      key: const Key('lampScreen'),
      backgroundColor: AppColors.deepNight,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FrameButton(
            key: const Key('lampClose'),
            label: r == null ? '관문으로' : '${r.townName}(으)로',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, pad.top + 10, 16, 16),
        children: [
          Text(r == null ? '관문의 등불이 켜졌어요' : '${Act3Rules.region(r.region).name}의 등불이 켜졌어요',
              textAlign: TextAlign.center, style: AppText.title(22)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 2200),
              builder: (context, k, child) => ColorFiltered(
                colorFilter: ColorFilter.matrix(_bright(k)),
                child: child,
              ),
              child: AspectRatio(
                aspectRatio: 1024 / 1100,
                child: Image.asset(
                    r == null ? widget.controller.currentRegion.map : Act3Rules.region(r.region).map,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2C4A))),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final (i, l) in lines.indexed)
            AnimatedOpacity(
              opacity: i < _shown ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: KText(l, style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.45)),
              ),
            ),
          const SizedBox(height: 6),
          for (final (i, u) in unlocks.indexed)
            AnimatedOpacity(
              opacity: lines.length + i < _shown ? 1 : 0,
              duration: const Duration(milliseconds: 400),
              child: Padding(
                key: Key('lampUnlock_$i'),
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.goldBright),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(u,
                        style: const TextStyle(color: AppColors.goldBright, fontSize: 14)),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  /// 어두운 지도(채도·밝기 낮음) → 밝은 지도
  static List<double> _bright(double k) {
    final b = 0.55 + 0.5 * k; // 밝기
    final s = 0.35 + 0.75 * k; // 채도
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
    return [
      (sr + s) * b, sg * b, sb * b, 0, 0,
      sr * b, (sg + s) * b, sb * b, 0, 0,
      sr * b, sg * b, (sb + s) * b, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}

/// 이름 있는 장비 모음 (지역마다 3개, 얻은 것만 보임)
class UniqueBookScreen extends StatelessWidget {
  const UniqueBookScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('uniqueBookScreen'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24),
          children: [
            OrnateTopBar(title: '이름 있는 장비', onBack: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 4),
            const KText('보스 · 숨은 보스 · 보물 상자에서 아주 드물게 나와요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            for (final book in c.uniqueBook) ...[
              const SizedBox(height: 10),
              Text('${book.name} ${book.items.where(c.uniqueFound).length} / ${book.items.length}',
                  style: AppText.title(16)),
              const SizedBox(height: 6),
              for (final b in book.items) ...[
                OrnatePanel(
                  key: Key('unique_${b.name}'),
                  child: c.uniqueFound(b)
                      ? Row(children: [
                          EquipIcon(base: b, grade: EquipGrade.orange, size: 56),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(EquipmentRules.info(b).name, style: AppText.title(16)),
                                KText(book.stories[b] ?? '',
                                    style: const TextStyle(color: AppColors.text, fontSize: 12.5, height: 1.4)),
                                Text(book.effects[b] ?? '',
                                    style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
                              ],
                            ),
                          ),
                        ])
                      : const Row(children: [
                          Icon(Icons.help_outline_rounded, color: AppColors.textMuted, size: 40),
                          SizedBox(width: 10),
                          Text('???', style: TextStyle(color: AppColors.textMuted, fontSize: 16)),
                        ]),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
