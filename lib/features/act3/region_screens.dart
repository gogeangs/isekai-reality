import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../awakening/awakening_screen.dart' show IllustratedScene;
import '../town/shop_screen.dart' show ShopItemIcon, ShopScreen;
import '../smithy/equipment_view.dart';
import 'act3_town.dart';

/// 「니아: …」 처럼 앞에 붙은 이름을 뗀다
String _strip(String s) => s.replaceFirst(RegExp(r'^[^:：]{1,6}: '), '');

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

const _sideReward = '모집권 ${RegionRules.sideTickets} · 금화 ${RegionRules.sideGold}';

/// 지역 2~5 마을 (묶음 57 #243): 주민 4 · 여관 · 가게 · (셀레니아 경매장) · 의뢰판
class RegionTownScreen extends StatelessWidget {
  const RegionTownScreen({super.key, required this.controller, required this.region});

  final AppController controller;
  final RegionContent region;

  Future<void> _talk(BuildContext context, RResident p) async {
    final c = controller;
    final r = region;
    // 메인 ② 마을 이야기 (첫 주민)
    if (p == r.residents.first && c.regionTalkPending(r)) {
      await showTalk(context, c, r.talk, key: const Key('regionTalk'));
      await c.markRegionTalk(r);
      if (context.mounted) showTopNotice(context, '일지 · 「${r.mains[2].title}」이 열렸어요');
      return;
    }
    for (final q in r.quests) {
      if (q.giver == p.id && c.questReady(q)) {
        final ok = await c.reportQuest(r, q);
        if (!context.mounted || !ok) return;
        await showTalk(context, c, [(p.id, q.done)]);
        if (context.mounted) {
          showTopNotice(
              context,
              r.hidden.unlockBy == q.id
                  ? '「${q.title}」 끝 · $_sideReward · 새 장소 「${r.hidden.name}」'
                  : '「${q.title}」 끝 · $_sideReward');
        }
        return;
      }
    }
    final offer = c.regionOffer(r, p);
    if (offer != null) {
      final take = await _offerDialog(context, p.faceAsset, offer);
      if (take == true) await c.acceptQuest(offer);
      return;
    }
    await showTalk(context, c, [(p.id, c.regionResidentLine(r, p))]);
  }

  Future<bool?> _offerDialog(BuildContext context, String? face, RQuest q) => showDialog<bool>(
        context: context,
        builder: (d) => GameAlert(
          key: const Key('questOffer'),
          title: Row(children: [
            _face(face),
            const SizedBox(width: 10),
            Expanded(child: Text(q.title, style: AppText.title(17))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            KText(_strip(q.ask),
                style: const TextStyle(color: AppColors.text, fontSize: 14.5, height: 1.5)),
            const SizedBox(height: 8),
            KText('할 일 · ${q.task}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            Text(
                q.ally != null
                    ? '보상 · ${Act3Rules.story(q.ally!).name} 스킬 ④ · $_sideReward'
                    : '보상 · $_sideReward',
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

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final r = region;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('regionTown'),
      backgroundColor: AppColors.deepNight,
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final lit = c.regionLit(r.region);
          return ListView(
            padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24),
            children: [
              OrnateTopBar(title: r.townName, onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: ColorFiltered(
                    colorFilter: lit
                        ? const ColorFilter.mode(Color(0x00000000), BlendMode.dst)
                        : const ColorFilter.mode(Color(0x55101024), BlendMode.srcATop),
                    child: Image.asset(r.town,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF2A2C4A))),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text('사람들', style: AppText.title(16)),
              const SizedBox(height: 6),
              Row(children: [
                for (final p in r.residents)
                  Expanded(
                    child: GestureDetector(
                      key: Key('resident_${p.id}'),
                      onTap: () => _talk(context, p),
                      child: Column(children: [
                        Stack(clipBehavior: Clip.none, children: [
                          _face(p.faceAsset, size: 58),
                          if ((p == r.residents.first && c.regionTalkPending(r)) ||
                              c.regionOffer(r, p) != null ||
                              r.quests.any((q) => q.giver == p.id && c.questReady(q)))
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
                        Text(p.name,
                            style: const TextStyle(
                                color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
                        Text(p.role,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              _inn(context),
              const SizedBox(height: 10),
              _shop(context),
              if (r.region == Region.selenia && lit) ...[
                const SizedBox(height: 10),
                _auction(context),
              ],
              const SizedBox(height: 10),
              _board(context),
            ],
          );
        },
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
            Text('여관', style: AppText.title(17)),
            const Spacer(),
            Text('HP ${c.hp} / ${c.maxHp}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 4),
          KText(
              c.innEnergyToday
                  ? '쉬면 HP와 MP가 가득 차요. 오늘은 여정 기력도 조금 채워 줘요.'
                  : '쉬면 HP와 MP가 가득 차요. 여정 기력은 내일 또 채워 줘요.',
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

  Widget _shop(BuildContext context) {
    final c = controller;
    final r = region;
    final dark = c.regionShopDark(r);
    return OrnatePanel(
      key: const Key('townStall'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.storefront_rounded, color: AppColors.goldBright),
            const SizedBox(width: 6),
            Text(dark ? '흑등 상회 빛 가게' : '마을 가게', style: AppText.title(17)),
            const Spacer(),
            Text('금화 ${c.player.gold}',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
          ]),
          const SizedBox(height: 2),
          KText(
              dark
                  ? '장터의 가게는 모두 문을 닫았어요. 흑등 상회만 빛을 팔아요 · 값이 아주 비싸요.'
                  : '아르카 잡화상과 같은 값 · 하루 개수도 함께 세요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          for (final item in c.regionShopItems(r))
            Builder(builder: (context) {
              final info = TownRules.info(item);
              final price = c.regionPrice(r, item);
              final check = c.player.gold < price ? PurchaseCheck.notEnoughCrystals : c.canBuy(item);
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
                      final res = await c.regionBuy(r, item);
                      if (!context.mounted) return;
                      showTopNotice(
                          context,
                          res == PurchaseCheck.ok
                              ? '${info.name}을(를) 샀어요'
                              : ShopScreen.reason(res, info, c.player.gold));
                    },
                    child: Text('금화 $price'),
                  ),
                ]),
              );
            }),
        ],
      ),
    );
  }

  Widget _auction(BuildContext context) {
    final c = controller;
    final lot = c.auctionLot;
    return OrnatePanel(
      key: const Key('townAuction'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.gavel_rounded, color: AppColors.goldBright),
            const SizedBox(width: 6),
            Text('장터 경매장', style: AppText.title(17)),
          ]),
          const SizedBox(height: 4),
          if (lot == null)
            const KText('오늘 경매는 끝났어요. 내일 새 물건이 올라와요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
          else
            Row(children: [
              EquipIcon(base: lot, grade: EquipGrade.purple, size: 48),
              const SizedBox(width: 8),
              Expanded(
                child: KText('오늘의 물건 · ${EquipmentRules.info(lot).name}\n등급은 낙찰받아야 알 수 있어요.',
                    style: const TextStyle(color: AppColors.text, fontSize: 12.5, height: 1.4)),
              ),
              TextButton(
                key: const Key('auctionBuy'),
                style: gameButtonStyle(gold: c.player.gold >= RegionRules.auctionGold),
                onPressed: () async {
                  final it = await c.buyAuction();
                  if (!context.mounted) return;
                  showTopNotice(
                      context,
                      it == null
                          ? '금화가 모자라요'
                          : '${EquipmentRules.info(it.base).name}을(를) 낙찰받았어요');
                },
                child: const Text('금화 ${RegionRules.auctionGold}'),
              ),
            ]),
        ],
      ),
    );
  }

  Widget _board(BuildContext context) {
    final c = controller;
    final r = region;
    final offers = c.regionAllyOffers(r);
    final allyReady = [
      for (final q in r.quests)
        if (q.ally != null && c.questReady(q)) q,
    ];
    return OrnatePanel(
      key: const Key('townBoard'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.assignment_rounded, color: AppColors.goldBright),
            const SizedBox(width: 6),
            Text('의뢰판', style: AppText.title(17)),
          ]),
          const SizedBox(height: 4),
          const KText('마을 사람들의 부탁이에요. 사람을 눌러 맡고, 다 하면 그 사람에게 알려요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          for (final q in r.quests)
            if (c.questState(q) == 1)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(c.questReady(q) ? Icons.check_circle_rounded : Icons.flag_rounded,
                      size: 16, color: AppColors.goldBright),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(q.title,
                        style: const TextStyle(color: AppColors.text, fontSize: 13.5)),
                  ),
                  Text(questProgText(c, q),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ]),
              ),
          for (final q in offers) ...[
            const SizedBox(height: 8),
            FrameButton(
              key: Key('allyQuest_${q.id}'),
              label: '${Act3Rules.story(q.ally!).name}의 부탁 · ${q.title}',
              onPressed: () async {
                await showTalk(context, c, [(q.ally!.name, _strip(q.ask))]);
                await c.acceptQuest(q);
              },
            ),
          ],
          for (final q in allyReady) ...[
            const SizedBox(height: 8),
            GoldButton(
              key: Key('allyReport_${q.id}'),
              label: '${Act3Rules.story(q.ally!).name}에게 알리기',
              height: 44,
              fontSize: 17,
              onPressed: () async {
                final ok = await c.reportQuest(r, q);
                if (!ok || !context.mounted) return;
                await showTalk(context, c, [(q.ally!.name, _strip(q.done))]);
                if (context.mounted) {
                  showTopNotice(context,
                      '${Act3Rules.story(q.ally!).name} 스킬 ④ 「${Act3Rules.story(q.ally!).skills[3].name}」을 열 수 있어요');
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 퀘스트 진행 글 (걸음은 보 · 층은 「n층까지」)
String questProgText(AppController c, RQuest q) {
  if (c.questReady(q)) return '다 했어요';
  if (q.embers) {
    return '불씨 ${c.embersFound}/${RegionRules.embersNeed} · 걸음 ${comma(c.questProg(q))}/${comma(q.target)}';
  }
  return switch (q.kind) {
    RQKind.walk => '${comma(c.questProg(q))} / ${comma(q.target)}보',
    RQKind.floor => '${q.target}층까지',
    RQKind.boss => '보스',
    _ => '${c.questProg(q)} / ${q.target}',
  };
}

/// 지역에 처음 들어갈 때 장면 (동료 합류)
Future<void> showRegionArrive(BuildContext context, AppController c, RegionContent r) async {
  await showTalk(context, c, r.arrive, key: const Key('regionArrive'));
  await c.markRegionArrive(r);
  if (!context.mounted) return;
  final joined = [
    for (final e in r.joins.entries)
      if (e.value == 'arrive') Act3Rules.story(e.key).name,
  ];
  if (joined.isNotEmpty) {
    showTopNotice(context, '${joined.join(' · ')}이(가) 동료가 됐어요 · 주점에서 데려갈 수 있어요');
  }
}

/// 등불을 켠 뒤: (아우렐) 큰 고르기 → 3막 끝 장면
Future<void> afterRegionLamp(BuildContext context, AppController c, RegionContent r) async {
  if (c.regionChoicePending(r)) await openRegionChoice(context, c, r);
  if (!context.mounted) return;
  if (c.act3EndPending) {
    await Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => Act3EndScreen(controller: c)));
  }
}

Future<void> openRegionChoice(BuildContext context, AppController c, RegionContent r) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => RegionChoiceScreen(controller: c, region: r)));

/// 지역의 큰 고르기 (한 번 고르면 바꿀 수 없음)
class RegionChoiceScreen extends StatelessWidget {
  const RegionChoiceScreen({super.key, required this.controller, required this.region});

  final AppController controller;
  final RegionContent region;

  Future<void> _pick(BuildContext context, ROption o) async {
    final c = controller;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text(o.title),
        content: const Text('한 번 고르면 바꿀 수 없어요.', style: TextStyle(color: AppColors.text)),
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
    final item = await c.chooseRegion(region, o);
    if (!context.mounted) return;
    await showTalk(context, c, o.result, key: Key('choiceScene_${o.key}'));
    if (!context.mounted) return;
    final got = [
      if (item != null) '${EquipmentRules.info(item.base).name}을 얻었어요',
      if (o.tickets > 0) '모집권 +${o.tickets}',
      if (o.gold > 0) '금화 +${o.gold}',
      if (!region.choice.afterLamp) '일지 「${region.mains[3].title}」',
    ];
    showTopNotice(context, got.join(' · '));
    nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final r = region;
    final pad = MediaQuery.paddingOf(context);
    Widget card(ROption o, IconData icon) => OrnatePanel(
          key: Key('choice_${o.key}'),
          ornament: true,
          child: InkWell(
            onTap: () => _pick(context, o),
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
      key: const Key('regionChoice'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, pad.top + 8, 16, pad.bottom + 24),
          children: [
            OrnateTopBar(title: r.choice.title, onBack: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 10),
            KText(r.choice.afterLamp ? r.lampLines.first : r.eventLines.last,
                style: const TextStyle(color: AppColors.text, fontSize: 15, height: 1.5)),
            const SizedBox(height: 4),
            const Text('한 번 고르면 바꿀 수 없어요.',
                style: TextStyle(color: AppColors.goldBright, fontSize: 13)),
            const SizedBox(height: 14),
            card(r.choice.a, Icons.balance_rounded),
            const SizedBox(height: 12),
            card(r.choice.b, Icons.favorite_rounded),
          ],
        ),
      ),
    );
  }
}

/// 3막 끝 (묶음 57): 다섯 등불 → 카스파르가 빛 병을 들고 사라짐 → 테오와 마르타
class Act3EndScreen extends StatefulWidget {
  const Act3EndScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<Act3EndScreen> createState() => _Act3EndScreenState();
}

class _Act3EndScreenState extends State<Act3EndScreen> {
  AppController get c => widget.controller;
  int _i = 0;
  bool _done = false;

  static final List<(String, String, String)> _lines = [
    for (final (w, l) in RegionRules.endScene) (RegionRules.fiveLampsScene, w, l),
    for (final (w, l) in RegionRules.teoScene) (RegionRules.teoMartaScene, w, l),
  ];

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
    if (_i < _lines.length - 1) {
      setState(() => _i++);
      return;
    }
    if (_done) return;
    _done = true;
    await c.finishAct3Story();
    if (!mounted) return;
    showTopNotice(context, '칭호 「다섯 등불의 수호자」 · 지역을 자유롭게 오가요 · 던전 「심층」이 열렸어요');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final (img, who, line) = _lines[_i];
    final sp = speakerOf(c, who);
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: const Key('act3End'),
        backgroundColor: AppColors.deepNight,
        body: IllustratedScene(
          key: ValueKey('act3End$_i'),
          image: img,
          speaker: sp.name,
          tailX: 0.5,
          line: line,
          lineKey: 'act3End-$_i',
          onNext: _next,
        ),
      ),
    );
  }
}


/// 심층 주간 순위 (묶음 58): 이번 주 심층 지역 · 순위 50 · 내 순위
class DeepRankScreen extends StatefulWidget {
  const DeepRankScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DeepRankScreen> createState() => _DeepRankScreenState();
}

class _DeepRankScreenState extends State<DeepRankScreen> {
  AppController get c => widget.controller;
  DeepBoard? _b;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = c.cloud.signedIn ? await c.deepBoard() : null;
    if (mounted) setState(() {
      _b = b;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final region = _b?.region ?? c.deepRegion;
    final r = RegionRules.of(region);
    return Scaffold(
      key: const Key('deepRank'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24),
          children: [
            OrnateTopBar(title: '심층 순위', onBack: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 8),
            OrnatePanel(
              ornament: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('이번 주 심층 · ${Act3Rules.region(region).name}',
                    textAlign: TextAlign.center, style: AppText.title(18)),
                if (r != null)
                  Text(r.dungeonName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                const SizedBox(height: 4),
                const KText('그 지역 던전 5층을 지나 심층으로 내려가면 가장 깊은 층이 순위에 올라요. 주가 끝나면 순위에 따라 하르트가 우편으로 상을 보내요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                if (r != null)
                  Text('내 기록 · 가장 깊이 ${c.regionDeepBest(r)}층',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 10),
            if (!c.cloud.signedIn)
              const KText('순위는 로그인한 각성자만 올라요. 설정에서 로그인할 수 있어요.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted))
            else if (!_loaded)
              const Center(child: CircularProgressIndicator(color: AppColors.goldBright))
            else if (_b == null)
              KText(MarketOps.marketErrorText(c.marketError),
                  textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted))
            else ...[
              if (_b!.myRank != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('내 순위 ${_b!.myRank}위 · ${_b!.myFloor}층 (${_b!.total}명 중)',
                      key: const Key('deepMyRank'),
                      textAlign: TextAlign.center,
                      style: AppText.title(16, color: AppColors.goldBright)),
                ),
              if (_b!.top.isEmpty)
                const KText('이번 주엔 아직 아무도 심층에 내려가지 않았어요.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
              for (final t in _b!.top)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: t.me ? const Color(0x33E8C77A) : const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    SizedBox(
                        width: 40,
                        child: Text('${t.rank}', style: AppText.title(16, color: AppColors.goldBright))),
                    Expanded(child: Text(t.name, style: const TextStyle(color: AppColors.text, fontSize: 14))),
                    Text('${t.floor}층', style: const TextStyle(color: AppColors.goldBright, fontSize: 14)),
                  ]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
