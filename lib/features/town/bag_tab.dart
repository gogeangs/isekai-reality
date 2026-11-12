import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/armory.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../smithy/equipment_view.dart';
import '../../core/models/pet_state.dart';
import '../alchemy/alchemy_screen.dart' show PotionIcon;
import '../battle/auto_use_window.dart';
import '../lens/lens_screen.dart' show openLens;
import '../pets/farewell_screen.dart';
import '../pets/pet_art.dart';
import 'bag_sheet.dart';
import 'material_view.dart';
import '../../theme/top_notice.dart';

/// 가방 칸 거르기
enum BagFilter {
  all('전체'),
  equip('장비'),
  material('재료'),
  consumable('소비'),
  other('기타');

  const BagFilter(this.label);
  final String label;
}

/// 가방 한 칸에 든 것
sealed class BagEntry {
  const BagEntry();
  BagFilter get kind;
}

class MaterialEntry extends BagEntry {
  const MaterialEntry(this.id, this.count);
  final MaterialId id;
  final int count;
  @override
  BagFilter get kind => BagFilter.material;
}

class ItemEntry extends BagEntry {
  const ItemEntry(this.item, this.count);
  final ShopItem item;
  final int count;

  /// 물약은 소비, 나침반·향은 기타
  @override
  BagFilter get kind => switch (item) {
        ShopItem.expeditionCompass ||
        ShopItem.purifyIncense ||
        ShopItem.raceLens =>
          BagFilter.other,
        _ => BagFilter.consumable,
      };
}

/// 공방 물약 ('healBig', 'healBig*', '?:…' 수상한 물약)
class PotionEntry extends BagEntry {
  const PotionEntry(this.key, this.count);
  final String key;
  final int count;
  @override
  BagFilter get kind =>
      key.startsWith('?:') ? BagFilter.other : BagFilter.consumable;
}

/// 걸음 주머니 (열어 보기 전엔 내용물을 모른다)
class PouchEntry extends BagEntry {
  const PouchEntry(this.count);
  final int count;
  @override
  BagFilter get kind => BagFilter.other;
}

/// 펫 알 (정령이 떠나기 전에는 「신비한 알」)
class EggEntry extends BagEntry {
  const EggEntry(this.egg);
  final PetEgg egg;
  @override
  BagFilter get kind => BagFilter.other;
}

class EquipEntry extends BagEntry {
  const EquipEntry(this.item);
  final EquipItem item;
  @override
  BagFilter get kind => BagFilter.equip;
}

/// 가방에 든 것을 칸으로 나눈다 (99개마다 한 칸, 장비는 하나씩)
List<BagEntry> bagEntries(AppController c) {
  List<int> split(int n) => [
        for (var left = n; left > 0; left -= BagRules.stackMax)
          left > BagRules.stackMax ? BagRules.stackMax : left,
      ];
  return [
    for (final e in c.armory.items)
      if (!c.armory.isWorn(e)) EquipEntry(e),
    for (final e in c.pets.eggs) EggEntry(e),
    for (final n in split(c.gather.pouches)) PouchEntry(n),
    for (final e in c.alchemy.potions.entries)
      for (final n in split(e.value)) PotionEntry(e.key, n),
    for (final i in TownRules.bagItems)
      for (final n in split(c.bagCount(i))) ItemEntry(i, n),
    for (final m in MaterialId.values)
      for (final n in split(c.player.materialCount(m))) MaterialEntry(m, n),
  ];
}

/// 하단 메뉴 '가방' 탭 (11-11 #48).
/// 칸 20개에서 시작, 금화로 5칸씩 늘린다. 마석·금화는 칸을 차지하지 않는다.
class BagTab extends StatefulWidget {
  const BagTab(
      {super.key,
      required this.controller,
      this.initialFilter = BagFilter.all,
      this.onBack});

  final AppController controller;

  /// 처음 고른 필터 (던전 입구에서는 「소비」, 11-11 #99)
  final BagFilter initialFilter;

  /// 따로 연 가방 화면이면 뒤로 가기
  final VoidCallback? onBack;

  @override
  State<BagTab> createState() => _BagTabState();
}

class _BagTabState extends State<BagTab> {
  late BagFilter _filter = widget.initialFilter;

  AppController get c => widget.controller;

  /// 묶음 15 #106: 한 칸씩 열기. 첫째·둘째 칸은 금화 또는 광고 중 고르는 창
  Future<void> _expand() async {
    final cost = c.bagExpandCost;
    if (cost == null) return;
    final short = cost - c.player.gold;
    final byAd = c.bagSlotByAd && c.adsReady;
    // 묶음 16 #136: 세로 버튼. 금화 크게 · 광고 둘째 · 닫기 작게
    final choice = await showDialog<String>(
      context: context,
      builder: (d) => GameAlert(
        key: const Key('bagExpandAlert'),
        title: const Text('가방 한 칸 열기'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          GoldButton(
            key: const Key('bagExpandOk'),
            label: '${josa(comma(cost), '으로/로')} 열기',
            height: 54,
            fontSize: 19,
            leading: const GameIcon('gold', size: 22),
            onPressed: short > 0 ? null : () => Navigator.pop(d, 'gold'),
          ),
          if (short > 0) ...[
            const SizedBox(height: 4),
            const Text('금화가 모자라요',
                key: Key('bagGoldShort'),
                style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
          if (byAd) ...[
            const SizedBox(height: 8),
            AdButton(
                key: const Key('bagExpandAd'),
                label: '광고 보고 열기',
                onPressed: () => Navigator.pop(d, 'ad')),
          ],
          const SizedBox(height: 4),
          TextButton(
              key: const Key('bagExpandClose'),
              onPressed: () => Navigator.pop(d),
              child: const Text('닫기', style: TextStyle(fontSize: 14))),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    final done = await c.expandBag(byAd: choice == 'ad');
    if (!mounted) return;
    if (done) showTopNotice(context, '가방이 ${c.bagCapacity}칸이 됐어요!');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final p = c.player;
        final all = bagEntries(c);
        final shown = _filter == BagFilter.all
            ? all
            : [for (final e in all) if (e.kind == _filter) e];
        final cap = c.bagCapacity;
        final used = c.bagUsed;
        final cost = c.bagExpandCost;
        // 전체 보기에서는 빈칸도 그린다
        final empty = _filter == BagFilter.all && cap > all.length
            ? cap - all.length
            : 0;
        // 11-11 #70: 한 줄 4칸. 마지막 줄이 모자라면 「늘릴 수 있는 칸」으로 채운다
        final cells = (_filter == BagFilter.all ? all.length + empty : 0);
        // 11-11 #93: 맨 끝에는 언제나 「🔒 +5칸 · 금화 200」 칸 하나
        final locks = _filter == BagFilter.all && cost != null
            ? (cells % 4 == 0 ? 1 : 4 - cells % 4)
            : 0;
        // 11-11 #93: 위쪽 버튼 줄·마석·금화 칸은 고정하고 아래만 스크롤한다
        // (스크롤한 내용이 상태 표시줄 뒤로 비쳐 보이지 않게)
        return Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, top + 6, 14, 0),
            child: Column(children: [
              OrnateTopBar(title: '가방', onBack: widget.onBack),
              const SizedBox(height: 10),
              OrnatePanel(
                child: WalletRow(manaStones: p.manaStones, gold: p.gold),
              ),
            ]),
          ),
          Expanded(
            child: ClipRect(
              child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
          children: [
            // 지금 걸린 물약 (11-11 #74): 전투 · 속성 · 탐험 하나씩
            if (c.activeBuffs.isNotEmpty) ...[
              const SizedBox(height: 8),
              OrnatePanel(
                key: const Key('activePotions'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('지금 걸린 물약', style: AppText.title(14)),
                    const SizedBox(height: 4),
                    for (final b in c.activeBuffs)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: [
                          PotionIcon(
                              potion: AlchemyRules.byName(b.key),
                              suspicious: b.key.startsWith('?:'),
                              size: 24),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(c.buffName(b),
                                style: const TextStyle(
                                    color: AppColors.text, fontSize: 14)),
                          ),
                          Text(c.buffLeftLabel(b),
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                        ]),
                      ),
                  ],
                ),
              ),
            ],
            // 채집 도구 (11-11 #56): 가방 칸을 쓰지 않는다
            if (c.harvest.granted) ...[
              const SizedBox(height: 8),
              OrnatePanel(
                child: Wrap(spacing: 12, runSpacing: 4, children: [
                  for (final t in HarvestTool.values)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      // 도구 등급 그림 (묶음 14 E: 가방에도). 없으면 글자만
                      Image.asset(
                          'assets/images/tool_${t.name}_${c.toolTier(t).name}.webp',
                          key: Key('bagTool_${t.name}'),
                          width: 22,
                          height: 22,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                      const SizedBox(width: 3),
                      Text(
                          '${c.toolTier(t).label} ${HarvestRules.toolName(t)} ${c.toolDurability(t)}/${c.toolMaxOf(t)}',
                          style: TextStyle(
                              color: c.toolDurability(t) > 0
                                  ? AppColors.text
                                  : AppColors.danger,
                              fontSize: 12)),
                    ]),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            OrnatePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const GameIcon('bag', size: 28),
                    const SizedBox(width: 6),
                    Text('가방', style: AppText.title(19)),
                    const SizedBox(width: 8),
                    Text('$used / $cap칸',
                        style: TextStyle(
                            color: used >= cap
                                ? AppColors.danger
                                : AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    // 전투 자동 마시기 (11-11 #93): 작은 물약 아이콘
                    IconButton(
                      key: const Key('bagAutoUse'),
                      tooltip: '전투에서 자동으로 마시기',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => showAutoUseSheet(context, c),
                      icon: Icon(Icons.local_drink_rounded,
                          size: 22,
                          color: c.alchemy.autoHp > 0 || c.alchemy.autoCure
                              ? AppColors.goldBright
                              : AppColors.textMuted),
                    ),
                  ]),
                  if (used > cap)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: KText('칸보다 많이 들어 있어요. 새로 얻는 것은 금화로 바뀌어요.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final f in BagFilter.values)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(f.label),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                            selectedColor: AppColors.gold,
                            backgroundColor: AppColors.chipBg,
                            labelStyle: TextStyle(
                                color: _filter == f
                                    ? AppColors.night
                                    : AppColors.text,
                                fontWeight: FontWeight.w700),
                            showCheckmark: false,
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  if (shown.isEmpty && empty == 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: KText('여기에 든 것이 없어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted)),
                    )
                  else
                    GridView.count(
                      crossAxisCount: 4,
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: [
                        for (final e in shown)
                          BagSlot(
                            entry: e,
                            controller: c,
                            onTap: () => showBagEntry(context, c, e),
                          ),
                        for (var i = 0; i < empty; i++) const BagSlot(),
                        for (var i = 0; i < locks; i++)
                          BagSlot(
                              key: i == 0
                                  ? const Key('bagExpandSlot')
                                  : null,
                              locked: true,
                              // 묶음 16 #118: 자물쇠만. 바로 다음 칸은 조금 밝게,
                              // 어느 칸을 눌러도 다음 한 칸 열기 창
                              nextLock: i == 0,
                              onTap: _expand),
                      ],
                    ),
                ],
              ),
            ),
          ],
              ),
            ),
          ),
        ]);
      },
    );
  }
}

/// 가방을 따로 연다 (던전 입구 등, 11-11 #99): 탭의 20칸 가방과 같은 화면
Future<void> openBag(BuildContext context, AppController c,
        {BagFilter filter = BagFilter.all}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (route) => Scaffold(
        backgroundColor: AppColors.night,
        body: NightBackground(
          header: true,
          child: BagTab(
            controller: c,
            initialFilter: filter,
            onBack: () => Navigator.of(route).maybePop(),
          ),
        ),
      ),
    ));

/// 가방 한 칸
class BagSlot extends StatelessWidget {
  const BagSlot(
      {super.key,
      this.entry,
      this.controller,
      this.onTap,
      this.locked = false,
      this.nextLock = false});

  /// 금화로 늘릴 수 있는 칸 (자물쇠)
  final bool locked;

  /// 바로 다음에 열 칸 (자물쇠를 조금 밝게)
  final bool nextLock;

  final BagEntry? entry;
  final AppController? controller;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final border = switch (e) {
      EquipEntry(:final item) => equipGradeColor(item.grade),
      MaterialEntry(:final id) when Materials.info(id).rare =>
        AppColors.goldBright,
      null => AppColors.gold.withValues(alpha: 0.18),
      _ => AppColors.gold.withValues(alpha: 0.5),
    };
    final count = switch (e) {
      MaterialEntry(:final count) ||
      ItemEntry(:final count) ||
      PotionEntry(:final count) ||
      PouchEntry(:final count) =>
        count,
      _ => 0,
    };
    if (locked) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF10132F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: AppColors.gold
                    .withValues(alpha: nextLock ? 0.35 : 0.12)),
          ),
          child: Center(
            child: GameGlyph(Glyph.lock, size: 22, dim: !nextLock),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slotBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: e is EquipEntry ? 2 : 1),
        ),
        child: Stack(children: [
          // 11-11 #70: 그림이 칸의 85% 쯤
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
              width: 64,
              height: 64,
              child: switch (e) {
                null => const SizedBox(),
                MaterialEntry(:final id) => MaterialIcon(id, size: 64),
                ItemEntry(:final item) => Image.asset(
                    bagIconAsset(controller!, item),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const GameIcon('bag', size: 56)),
                EquipEntry(:final item) =>
                  EquipIcon(base: item.base, grade: item.grade, size: 64),
                PotionEntry(:final key) => PotionIcon(
                    potion: AlchemyRules.parseKey(key)?.id,
                    suspicious: key.startsWith('?:'),
                    size: 64),
                PouchEntry() => Image.asset('assets/images/item_pouch.webp',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_rounded,
                        size: 54,
                        color: AppColors.goldBright)),
                EggEntry(:final egg) => EggArt(
                    size: 64,
                    glowing: controller != null && controller!.eggReady(egg)),
              },
              ),
              ),
            ),
          ),
          // 개수는 오른쪽 아래 작은 뱃지 (그림을 가리지 않게)
          if (count > 1)
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                decoration: BoxDecoration(
                  color: const Color(0xE60B0D26),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 0.8),
                ),
                child: Text('$count',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          // 물약 품질 (11-11 #74): 좋음·최상만 왼쪽 위에 작게
          if (e case PotionEntry(:final key)
              when (AlchemyRules.parseKey(key)?.quality ?? PotionQuality.normal) !=
                  PotionQuality.normal)
            Positioned(
              left: 3,
              top: 2,
              child: Container(
                key: const Key('potionQuality'),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: kGoldGradient,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(AlchemyRules.parseKey(key)!.quality.label,
                    style: const TextStyle(
                        color: AppColors.goldInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          if (e case EggEntry(:final egg) when egg.incubatedAt != null)
            const Positioned(
              right: 3,
              bottom: 2,
              child: Icon(Icons.hourglass_bottom_rounded,
                  size: 14, color: AppColors.goldBright),
            ),
          if (e case EquipEntry(:final item) when item.enhance > 0)
            Positioned(
              left: 4,
              top: 2,
              child: Text('+${item.enhance}',
                  style: const TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 3)])),
            ),
        ]),
      ),
    );
  }
}

String bagEntryName(BagEntry e, [AppController? c]) => switch (e) {
      MaterialEntry(:final id) => Materials.info(id).name,
      ItemEntry(:final item) =>
        c == null ? TownRules.info(item).name : c.itemName(item),
      EquipEntry(:final item) => item.name,
      EggEntry() => c != null && c.farewellDone ? '펫 알' : '신비한 알',
      PotionEntry(:final key) => c == null ? key : c.potionName(key),
      PouchEntry() => '걸음 주머니',
    };

/// 칸을 누르면: 설명, 쓰기·입기, 버리기
Future<void> showBagEntry(BuildContext context, AppController c, BagEntry e) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => e is EggEntry
          ? EggSheet(controller: c, egg: e.egg)
          : _EntrySheet(controller: c, entry: e),
    );

class _EntrySheet extends StatelessWidget {
  const _EntrySheet({required this.controller, required this.entry});

  final AppController controller;
  final BagEntry entry;

  Future<void> _discard(BuildContext context, int n) async {
    final name = bagEntryName(entry, controller);
    final what = entry is EquipEntry ? name : '$name $n개';
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: const Text('버리기'),
        content: KText('${josa(what, '을/를')} 버릴까요? 버리면 되찾을 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('그만둘래요')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('버리기')),
        ],
      ),
    );
    if (ok != true) return;
    final c = controller;
    switch (entry) {
      case MaterialEntry(:final id):
        await c.discardMaterial(id, n);
      case ItemEntry(:final item):
        await c.discardItem(item, n);
      case EquipEntry(:final item):
        await c.discardEquip(item.uid);
      case EggEntry():
        break;
      case PotionEntry(:final key):
        await c.discardPotion(key, n);
      case PouchEntry():
        break;
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final e = entry;
    final count = switch (e) {
      MaterialEntry(:final count) ||
      ItemEntry(:final count) ||
      PotionEntry(:final count) ||
      PouchEntry(:final count) =>
        count,
      EquipEntry() || EggEntry() => 1,
    };
    final (String desc, String sell) = switch (e) {
      MaterialEntry(:final id) => (
          Materials.info(id).description,
          '잡화상에서 1개 금화 ${BagRules.materialPrice(id)}'
        ),
      EggEntry() => ('', ''),
      PotionEntry(:final key) => (c.potionDescription(key), '잡화상에서는 팔지 않아요'),
      PouchEntry() => (
          '걷다가 길에서 주운 것들이 든 주머니. 열어 보기 전엔 무엇이 들었는지 몰라요.',
          '${GatherRules.pouchSteps}보마다 하나, 하루 ${GatherRules.pouchesPerDay}개까지'
        ),
      ItemEntry(:final item) => (
          c.itemDescription(item),
          '잡화상에서 1개 금화 ${BagRules.itemPrice(item)}'
        ),
      EquipEntry(:final item) => (
          EquipmentRules.itemStatLabel(item),
          '잡화상에서 금화 ${BagRules.equipPrice(item)}'
        ),
    };
    Widget? action;
    switch (e) {
      case ItemEntry(:final item):
        final check = c.canUse(item);
        action = GoldButton(
          label: check == UseCheck.ok
              ? useLabel(item, petSnack: c.farewellDone)
              : useReason(check),
          height: 44,
          onPressed: check == UseCheck.ok
              ? () async {
                  if (item == ShopItem.raceLens) {
                    final nav = Navigator.of(context)..pop();
                    await openLens(nav, c);
                    return;
                  }
                  await c.useItem(item);
                  if (context.mounted) Navigator.of(context).pop();
                }
              : null,
        );
      case EquipEntry(:final item):
        action = GoldButton(
          label: '입기',
          height: 44,
          onPressed: () async {
            await c.equip(item.uid);
            if (context.mounted) Navigator.of(context).pop();
          },
        );
      case MaterialEntry() || EggEntry():
        action = null;
      case PouchEntry():
        action = GoldButton(
          label: '열어 보기',
          height: 44,
          onPressed: () async {
            final r = await c.openPouch();
            if (r == null || !context.mounted) return;
            Navigator.of(context).pop();
            showTopNotice(context, gatherLine(r));
          },
        );
      case PotionEntry(:final key):
        action = GoldButton(
          label: '마시기',
          height: 44,
          onPressed: () async {
            final name = c.potionName(key);
            final why = await c.drinkPotion(key);
            if (!context.mounted) return;
            if (why != null) {
              showTopNotice(context, why);
            } else {
              Navigator.of(context).pop();
              showTopNotice(context, c.drinkNote ?? '${josa(name, '을/를')} 마셨어요.');
            }
          },
        );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              SizedBox(
                  width: 64,
                  height: 64,
                  child: BagSlot(entry: e, controller: c)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    switch (e) {
                      EquipEntry(:final item) => EquipName(item),
                      _ => Text(bagEntryName(e, c),
                          style: AppText.title(19, color: AppColors.text)),
                    },
                    if (e is! EquipEntry)
                      Text('$count개',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (e is EquipEntry)
              // 묶음 13 A4: 스탯은 메달 + 숫자, 지금 입은 것과 비교
              ItemStats(e.item,
                  compare: c.armory.wornIn(e.item.slot), fontSize: 14)
            else if (desc.isNotEmpty)
              KText(desc,
                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
            const SizedBox(height: 6),
            KText(sell,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 14),
            if (action != null) ...[action, const SizedBox(height: 8)],
            Row(children: [
              if (count > 1)
                Expanded(
                  child: TextButton(
                    onPressed: () => _discard(context, 1),
                    child: const Text('1개 버리기',
                        style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
              Expanded(
                child: TextButton(
                  onPressed: () => _discard(context, count),
                  child: Text(count > 1 ? '모두 버리기' : '버리기',
                      style: const TextStyle(color: AppColors.textMuted)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 알 칸을 누르면: 정령이 떠나기 전에는 설명만, 떠난 뒤에는 품기·바로 부화·깨우기
class EggSheet extends StatelessWidget {
  const EggSheet({super.key, required this.controller, required this.egg});

  final AppController controller;
  final PetEgg egg;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        // 최신 상태의 알 (품기·부화 뒤)
        PetEgg? cur;
        for (final e in c.pets.eggs) {
          if (e.id == egg.id) cur = e;
        }
        final e = cur;
        final children = <Widget>[];
        if (e == null) {
          children.add(const KText('알이 깨어났어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text)));
        } else if (!c.farewellDone) {
          children.add(const KText(
              '따뜻한 기운이 느껴지는 알이에요. 정령이 무언가 알고 있는 것 같아요.',
              style: TextStyle(color: AppColors.text, fontSize: 14)));
        } else if (e.incubatedAt == null) {
          final busy = c.pets.eggs.any((x) => x.incubatedAt != null);
          children.addAll([
            KText(
                '품으면 ${PetRules.hatchTime.inHours}시간 뒤 깨어나요. 알은 한 번에 하나씩 품을 수 있어요.',
                style: const TextStyle(color: AppColors.text, fontSize: 14)),
            const SizedBox(height: 12),
            GoldButton(
              label: busy ? '다른 알을 품는 중이에요' : '품기',
              height: 46,
              onPressed: busy ? null : () => c.incubateEgg(e.id),
            ),
          ]);
        } else if (c.eggReady(e)) {
          children.addAll([
            const KText('알이 깨어나려 해요!',
                style: TextStyle(color: AppColors.text, fontSize: 14)),
            const SizedBox(height: 12),
            GoldButton(
              label: '깨우기',
              height: 46,
              onPressed: () async {
                Navigator.of(context).pop();
                await showHatchSheet(context, c, e);
              },
            ),
          ]);
        } else {
          final left = e.incubatedAt!
              .add(PetRules.hatchTime)
              .difference(c.now);
          final mana = c.hatchManaCost(e), gold = c.hatchGoldCost(e);
          children.addAll([
            KText(
                '깨어나기까지 ${left.inHours}시간 ${left.inMinutes % 60}분 남았어요.',
                style: const TextStyle(color: AppColors.text, fontSize: 14)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FrameButton(
                  label: '마석 $mana로 바로',
                  gameIcon: 'mana_stone',
                  height: 44,
                  onPressed: c.player.manaStones >= mana
                      ? () => c.hatchNow(e.id, useMana: true)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FrameButton(
                  label: '금화 $gold로 바로',
                  gameIcon: 'gold',
                  height: 44,
                  onPressed: c.player.gold >= gold
                      ? () => c.hatchNow(e.id, useMana: false)
                      : null,
                ),
              ),
            ]),
          ]);
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                    child: EggArt(
                        size: 96, glowing: e != null && c.eggReady(e))),
                const SizedBox(height: 6),
                Text(c.farewellDone ? '펫 알' : '신비한 알',
                    textAlign: TextAlign.center,
                    style: AppText.title(19, color: AppColors.goldBright)),
                const SizedBox(height: 10),
                ...children,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 전투 자동 마시기 설정 (11-11 #57, #93): 전투·설정·가방이 같은 창을 쓴다
Future<void> showAutoUseSheet(BuildContext context, AppController c) =>
    showAutoUseWindow(context,
        hp: c.alchemy.autoHp,
        cure: c.alchemy.autoCure,
        onChanged: (hp, cure) => c.setAutoUse(hpPercent: hp, cure: cure));

/// 주머니·길가에서 나온 것 한 줄
String gatherLine(({Map<MaterialId, int> mats, int gold, bool note}) r) => [
      for (final e in r.mats.entries) '${Materials.info(e.key).name} +${e.value}',
      if (r.gold > 0) '금화 +${r.gold}',
      if (r.note) '레시피 쪽지 +1',
    ].join(' · ');

/// 떠돌이 상인 (11-11 #59, #84): 금테 공용 팝업. 상품마다 그림·이름·한 줄 설명·가격.
/// 금화가 모자라면 「금화 N 부족」, 산 것은 「팔렸어요」. 상인이 떠나면 안내와 함께 닫힌다.
Future<void> showMerchantSheet(BuildContext context, AppController c) =>
    showDialog<void>(
      context: context,
      builder: (d) => _MerchantDialog(controller: c),
    );

class _MerchantDialog extends StatefulWidget {
  const _MerchantDialog({required this.controller});

  final AppController controller;

  @override
  State<_MerchantDialog> createState() => _MerchantDialogState();
}

class _MerchantDialogState extends State<_MerchantDialog> {
  Timer? _tick;
  bool _left = false;

  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _check() {
    if (!mounted || _left) return;
    if (!c.merchantHere) {
      _left = true;
      final nav = Navigator.of(context);
      showTopNotice(context, '상인이 떠났어요. 또 만나요!',
          icon: Icons.storefront_rounded);
      nav.pop();
    } else {
      setState(() {});
    }
  }

  Widget _row({
    required Widget icon,
    required String name,
    required String line,
    required int price,
    required bool sold,
    required VoidCallback onBuy,
    required Key key,
  }) {
    final gold = c.player.gold;
    final short = price - gold;
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Opacity(opacity: sold ? 0.45 : 1, child: icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              KText(line,
                  maxLines: 2,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: sold
              ? const Center(
                  child: Text('팔렸어요',
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700)))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                    style: gameButtonStyle(gold: short <= 0).copyWith(
                      minimumSize: const WidgetStatePropertyAll(Size(88, 38)),
                      padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                    ),
                    onPressed: short <= 0 && c.merchantHere ? onBuy : null,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('금화 ${comma(price)}'),
                    ),
                  ),
                  if (short > 0)
                    Text('금화 ${comma(short)} 부족',
                        style: const TextStyle(
                            color: Color(0xFFE88B8B), fontSize: 12)),
                ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final g = c.gather;
        Future<void> buy(MaterialId? m, String name) async {
          final ok = await c.buyFromMerchant(m);
          if (ok && context.mounted) {
            showTopNotice(context, '${josa(name, '을/를')} 샀어요.',
                icon: Icons.storefront_rounded);
          }
        }

        return GameAlert(
          title: Row(children: [
            Image.asset('assets/images/merchant.webp',
                width: 60,
                height: 60,
                errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded,
                    size: 46, color: AppColors.goldBright)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('떠돌이 상인', style: AppText.title(19)),
                  Text(
                      c.merchantHere
                          ? '${c.merchantMinutesLeft}분 뒤 떠나요'
                          : '상인이 떠났어요',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const GameIcon('gold', size: 20, fallback: Icons.paid_rounded),
            const SizedBox(width: 3),
            Text(comma(c.player.gold),
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in g.offers.entries)
                if (Materials.byName(e.key) case final m?)
                  _row(
                    key: Key('merchant_${m.name}'),
                    icon: MaterialIcon(m, size: 40),
                    name: Materials.info(m).name,
                    line: Materials.info(m).description,
                    price: e.value,
                    sold: c.merchantSold(m),
                    onBuy: () => buy(m, Materials.info(m).name),
                  ),
              if (g.noteOffer || c.merchantSold(null))
                _row(
                  key: const Key('merchant_note'),
                  icon: Image.asset('assets/images/item_recipe_note.webp',
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.description_rounded,
                          size: 34,
                          color: AppColors.goldBright)),
                  name: '레시피 쪽지',
                  line: '공방에서 읽으면 아직 모르는 물약의 재료를 알 수 있어요.',
                  price: GatherRules.notePrice,
                  sold: c.merchantSold(null),
                  onBuy: () => buy(null, '레시피 쪽지'),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('닫기')),
          ],
        );
      },
    );
  }
}
