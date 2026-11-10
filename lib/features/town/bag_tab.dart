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
import '../lens/lens_screen.dart' show openLens;
import '../pets/farewell_screen.dart';
import '../pets/pet_art.dart';
import 'bag_sheet.dart';
import 'material_view.dart';

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
  const BagTab({super.key, required this.controller});

  final AppController controller;

  @override
  State<BagTab> createState() => _BagTabState();
}

class _BagTabState extends State<BagTab> {
  BagFilter _filter = BagFilter.all;

  AppController get c => widget.controller;

  Future<void> _expand() async {
    final cost = c.bagExpandCost;
    if (cost == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('가방 늘리기'),
        content: KText('금화 ${comma(cost)}으로 가방을 '
            '${BagRules.slotsPerExpansion}칸 늘릴까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('그만둘래요')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('늘리기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await c.expandBag();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(done
          ? '가방이 ${c.bagCapacity}칸이 됐어요!'
          : '금화가 ${comma(cost - c.player.gold)} 모자라요.'),
    ));
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
        return ListView(
          padding: EdgeInsets.fromLTRB(14, top + 6, 14, 24),
          children: [
            const OrnateTopBar(title: '가방'),
            const SizedBox(height: 10),
            OrnatePanel(
              child: WalletRow(manaStones: p.manaStones, gold: p.gold),
            ),
            const SizedBox(height: 12),
            OrnatePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const GameIcon('bag', size: 28),
                    const SizedBox(width: 6),
                    Text('가방', style: AppText.title(20)),
                    const SizedBox(width: 8),
                    Text('$used / $cap칸',
                        style: TextStyle(
                            color: used >= cap
                                ? const Color(0xFFE57373)
                                : AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ]),
                  if (cost != null) ...[
                    const SizedBox(height: 8),
                    FrameButton(
                      label: '가방 ${BagRules.slotsPerExpansion}칸 늘리기 · 금화 ${comma(cost)}',
                      gameIcon: 'gold',
                      height: 40,
                      onPressed: _expand,
                    ),
                  ],
                  const SizedBox(height: 6),
                  FrameButton(
                    label: '전투에서 자동으로 마시기',
                    icon: Icons.auto_mode_rounded,
                    height: 38,
                    onPressed: () => showAutoUseSheet(context, c),
                  ),
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
                            backgroundColor: const Color(0xFF1E2250),
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
                      crossAxisCount: 5,
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
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 가방 한 칸
class BagSlot extends StatelessWidget {
  const BagSlot({super.key, this.entry, this.controller, this.onTap});

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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161A44),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: e is EquipEntry ? 2 : 1),
        ),
        child: Stack(children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: switch (e) {
                null => const SizedBox(),
                MaterialEntry(:final id) => MaterialIcon(id, size: 40),
                ItemEntry(:final item) => Image.asset(
                    bagIconAsset(controller!, item),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const GameIcon('bag', size: 36)),
                EquipEntry(:final item) =>
                  EquipIcon(base: item.base, grade: item.grade, size: 40),
                PotionEntry(:final key) => PotionIcon(
                    potion: AlchemyRules.byName(key.replaceAll('*', '')),
                    suspicious: key.startsWith('?:'),
                    size: 40),
                PouchEntry() => Image.asset('assets/images/item_pouch.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.shopping_bag_rounded,
                        size: 34,
                        color: AppColors.goldBright)),
                EggEntry(:final egg) => EggArt(
                    size: 40,
                    glowing: controller != null && controller!.eggReady(egg)),
              },
            ),
          ),
          if (count > 1)
            Positioned(
              right: 4,
              bottom: 2,
              child: Text('$count',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 3)])),
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
                      fontSize: 11,
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
      builder: (d) => AlertDialog(
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
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(gatherLine(r))));
          },
        );
      case PotionEntry(:final key):
        action = GoldButton(
          label: '마시기',
          height: 44,
          onPressed: () async {
            final why = await c.drinkPotion(key);
            if (!context.mounted) return;
            if (why != null) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(why)));
            } else {
              Navigator.of(context).pop();
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
                          style: AppText.title(18, color: AppColors.text)),
                    },
                    if (e is! EquipEntry)
                      Text('$count개',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 12),
            if (desc.isNotEmpty)
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
                    style: AppText.title(20, color: AppColors.goldBright)),
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

/// 전투 자동 마시기 설정 (11-11 #57): 회복·상태이상. 원정에도 같이 쓴다.
Future<void> showAutoUseSheet(BuildContext context, AppController c) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      builder: (sheet) => ListenableBuilder(
        listenable: c,
        builder: (sheet, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('전투에서 자동으로 마시기', style: AppText.title(19)),
                const SizedBox(height: 4),
                const KText('던전·필드·펫 원정 모두에 써요. 전투 한 번에 3개까지.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 10),
                const Text('HP가 이만큼 아래면 회복 물약',
                    style: TextStyle(color: AppColors.text)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  for (final v in const [0, 30, 50])
                    ChoiceChip(
                      label: Text(v == 0 ? '안 마심' : '$v%'),
                      selected: c.alchemy.autoHp == v,
                      onSelected: (_) => c.setAutoUse(hpPercent: v),
                    ),
                ]),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: c.alchemy.autoCure,
                  onChanged: (v) => c.setAutoUse(cure: v),
                  title: const Text('중독·화상·눈부심이면 해독제·연고·맑은 눈 물약',
                      style: TextStyle(color: AppColors.text, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

/// 주머니·길가에서 나온 것 한 줄
String gatherLine(({Map<MaterialId, int> mats, int gold, bool note}) r) => [
      for (final e in r.mats.entries) '${Materials.info(e.key).name} +${e.value}',
      if (r.gold > 0) '금화 +${r.gold}',
      if (r.note) '레시피 쪽지 +1',
    ].join(' · ');

/// 떠돌이 상인 (11-11 #59): 잠깐 동안 귀한 재료를 금화로
Future<void> showMerchantSheet(BuildContext context, AppController c) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      builder: (sheet) => ListenableBuilder(
        listenable: c,
        builder: (sheet, _) {
          final g = c.gather;
          final left = c.merchantHere
              ? g.merchantUntil!.difference(c.now).inMinutes + 1
              : 0;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Image.asset('assets/images/merchant.png',
                        width: 56,
                        height: 56,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.storefront_rounded,
                            size: 44,
                            color: AppColors.goldBright)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('떠돌이 상인', style: AppText.title(19)),
                          Text(
                              c.merchantHere ? '$left분 뒤 떠나요 · 금화 ${c.player.gold}' : '상인이 떠났어요',
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  for (final e in g.offers.entries)
                    if (Materials.byName(e.key) case final m?)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: MaterialIcon(m, size: 36),
                        title: Text(Materials.info(m).name,
                            style: const TextStyle(color: AppColors.text)),
                        trailing: TextButton(
                          onPressed: c.merchantHere && c.player.gold >= e.value
                              ? () => c.buyFromMerchant(m)
                              : null,
                          child: Text('금화 ${e.value}'),
                        ),
                      ),
                  if (g.noteOffer)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.description_rounded,
                          color: AppColors.goldBright, size: 32),
                      title: const Text('레시피 쪽지',
                          style: TextStyle(color: AppColors.text)),
                      trailing: TextButton(
                        onPressed: c.merchantHere &&
                                c.player.gold >= GatherRules.notePrice
                            ? () => c.buyFromMerchant(null)
                            : null,
                        child: const Text('금화 ${GatherRules.notePrice}'),
                      ),
                    ),
                  if (g.offers.isEmpty && !g.noteOffer)
                    const KText('다 팔렸어요. 또 만나요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          );
        },
      ),
    );
