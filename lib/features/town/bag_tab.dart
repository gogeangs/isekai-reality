import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/armory.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../smithy/equipment_view.dart';
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
        ShopItem.expeditionCompass || ShopItem.purifyIncense => BagFilter.other,
        _ => BagFilter.consumable,
      };
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
                    const Spacer(),
                    if (cost != null)
                      SizedBox(
                        width: 128,
                        child: FrameButton(
                          label: '늘리기 ${comma(cost)}',
                          gameIcon: 'gold',
                          height: 36,
                          onPressed: _expand,
                        ),
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
      MaterialEntry(:final count) || ItemEntry(:final count) => count,
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

String bagEntryName(BagEntry e) => switch (e) {
      MaterialEntry(:final id) => Materials.info(id).name,
      ItemEntry(:final item) => TownRules.info(item).name,
      EquipEntry(:final item) => item.name,
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
      builder: (sheet) => _EntrySheet(controller: c, entry: e),
    );

class _EntrySheet extends StatelessWidget {
  const _EntrySheet({required this.controller, required this.entry});

  final AppController controller;
  final BagEntry entry;

  Future<void> _discard(BuildContext context, int n) async {
    final name = bagEntryName(entry);
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
    }
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final e = entry;
    final count = switch (e) {
      MaterialEntry(:final count) || ItemEntry(:final count) => count,
      EquipEntry() => 1,
    };
    final (String desc, String sell) = switch (e) {
      MaterialEntry(:final id) => (
          Materials.info(id).description,
          '잡화상에서 1개 금화 ${BagRules.materialPrice(id)}'
        ),
      ItemEntry(:final item) => (
          TownRules.info(item).description,
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
          label: check == UseCheck.ok ? useLabel(item) : useReason(check),
          height: 44,
          onPressed: check == UseCheck.ok
              ? () async {
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
      case MaterialEntry():
        action = null;
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
                      _ => Text(bagEntryName(e),
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
