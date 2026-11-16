import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../smithy/equipment_view.dart';
import 'bag_tab.dart';
import 'shop_screen.dart' show ShopChip;
import '../../theme/top_notice.dart';

/// 하나의 판매 값
int sellPrice(BagEntry e) => switch (e) {
      MaterialEntry(:final id) => BagRules.materialPrice(id),
      ItemEntry(:final item) => BagRules.itemPrice(item),
      EquipEntry(:final item) => BagRules.equipPrice(item),
      EggEntry() || PotionEntry() || PouchEntry() => 0,
    };

/// 팔기 탭 묶음
enum SellGroup { material, item, equip }

extension SellGroupLabel on SellGroup {
  String get label => switch (this) {
        SellGroup.material => '재료',
        SellGroup.item => '물건',
        SellGroup.equip => '장비',
      };
}

/// 팔 수 있는 한 줄 (재료·물건은 가진 수를 모두 합침, 장비는 하나씩)
class _Row {
  const _Row(this.key, this.entry, this.count, {this.worn = false});

  final String key;
  final BagEntry entry;
  final int count;
  final bool worn;
}

/// 잡화상 「팔기」 탭 (11-11 #48 · 묶음 41 #227): 맨 위 마석 팔기, 그 아래
/// 재료·물건·장비 목록에서 여러 개를 골라 한꺼번에 판다. 입은 장비는 팔 수 없다.
class ShopSellTab extends StatefulWidget {
  const ShopSellTab({super.key, required this.controller});

  final AppController controller;

  @override
  State<ShopSellTab> createState() => _ShopSellTabState();
}

class _ShopSellTabState extends State<ShopSellTab> {
  AppController get c => widget.controller;

  SellGroup _group = SellGroup.material;

  /// 고른 줄 → 팔 개수
  final _picked = <String, int>{};

  List<_Row> _rows(SellGroup g) => switch (g) {
        SellGroup.material => [
            for (final m in MaterialId.values)
              if (c.player.materialCount(m) > 0)
                _Row('m:${m.name}', MaterialEntry(m, c.player.materialCount(m)),
                    c.player.materialCount(m)),
          ],
        SellGroup.item => [
            for (final i in TownRules.bagItems)
              if (c.bagCount(i) > 0)
                _Row('i:${i.name}', ItemEntry(i, c.bagCount(i)), c.bagCount(i)),
          ],
        SellGroup.equip => [
            for (final s in EquipSlot.values)
              if (c.armory.wornIn(s) case final w?)
                _Row('e:${w.uid}', EquipEntry(w), 1, worn: true),
            for (final e in c.armory.items)
              if (!c.armory.isWorn(e)) _Row('e:${e.uid}', EquipEntry(e), 1),
          ],
      };

  List<_Row> get _all => [for (final g in SellGroup.values) ..._rows(g)];

  /// 없어진 줄·넘친 개수는 고른 것에서 뺀다 (판 뒤·다른 화면에서 쓴 뒤)
  void _prune() {
    final rows = {for (final r in _all) r.key: r};
    _picked.removeWhere((k, n) => rows[k] == null || rows[k]!.worn);
    for (final k in _picked.keys.toList()) {
      final max = rows[k]!.count;
      if (_picked[k]! > max) _picked[k] = max;
    }
  }

  Future<void> _sellStones(int n) async {
    final ok = await c.sellManaStones(n);
    if (!mounted) return;
    showTopNotice(
        context,
        ok
            ? '마석 $n개를 팔았어요. 금화 +${comma(n * RuleConstants.goldPerManaStone)}'
            : '마석이 모자라요.');
  }

  Future<void> _pickCount(_Row r) async {
    if (r.worn) return;
    var n = _picked[r.key] ?? r.count;
    final got = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: StatefulBuilder(
          builder: (sheet, set) => Padding(
            key: const Key('sellCountSheet'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${bagEntryName(r.entry, c)} 몇 개 팔까요?',
                    style: AppText.title(17, color: AppColors.text)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                    key: const Key('sellMinus'),
                    onPressed: n > 1 ? () => set(() => n--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded,
                        color: AppColors.goldBright, size: 34),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text('$n',
                        key: const Key('sellCount'),
                        textAlign: TextAlign.center,
                        style: AppText.title(24, color: AppColors.text)),
                  ),
                  IconButton(
                    key: const Key('sellPlus'),
                    onPressed: n < r.count ? () => set(() => n++) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        color: AppColors.goldBright, size: 34),
                  ),
                  TextButton(
                    key: const Key('sellMax'),
                    onPressed: n < r.count ? () => set(() => n = r.count) : null,
                    child: Text('최대 ${r.count}',
                        style: const TextStyle(
                            color: AppColors.goldBright,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text('금화 ${comma(n * sellPrice(r.entry))}',
                    textAlign: TextAlign.center,
                    style: AppText.title(15, color: AppColors.goldBright)),
                const SizedBox(height: 12),
                GoldButton(
                  key: const Key('sellCountOk'),
                  label: '$n개 고르기',
                  height: 46,
                  fontSize: 16,
                  onPressed: () => Navigator.of(sheet).pop(n),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (got != null && mounted) setState(() => _picked[r.key] = got);
  }

  Future<void> _sellPicked() async {
    final rows = {for (final r in _all) r.key: r};
    final picks = [
      for (final e in _picked.entries)
        if (rows[e.key] case final r? when !r.worn && e.value > 0) (r, e.value),
    ];
    if (picks.isEmpty) return;
    final kinds = picks.length;
    final total = picks.fold<int>(0, (s, p) => s + p.$2 * sellPrice(p.$1.entry));
    // 장비·귀한 재료가 섞였을 때만 한 번 더 묻는다
    final careful = picks.any((p) => switch (p.$1.entry) {
          EquipEntry() => true,
          MaterialEntry(:final id) => Materials.info(id).rare,
          _ => false,
        });
    if (careful) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => GameAlert(
          title: const Text('팔기'),
          content: KText(
              '${[
                for (final p in picks.take(3))
                  '${bagEntryName(p.$1.entry, c)}${p.$1.entry is EquipEntry ? '' : ' ${p.$2}개'}',
              ].join(', ')}${kinds > 3 ? ' 외 ${kinds - 3}가지' : ''}를 '
              '금화 ${comma(total)}에 팔까요?\n판 장비는 되돌릴 수 없어요.'),
          actions: [
            TextButton(
                key: const Key('sellConfirmNo'),
                onPressed: () => Navigator.pop(d, false),
                child: const Text('그만둘래요')),
            TextButton(
                key: const Key('sellConfirmYes'),
                onPressed: () => Navigator.pop(d, true),
                child: const Text('팔기')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final before = c.player.gold;
    var sold = 0;
    for (final (r, n) in picks) {
      final ok = switch (r.entry) {
        MaterialEntry(:final id) => await c.sellMaterial(id, n),
        ItemEntry(:final item) => await c.sellItem(item, n),
        EquipEntry(:final item) => await c.sellEquip(item.uid),
        _ => false,
      };
      if (ok) sold += n;
    }
    if (!mounted) return;
    setState(_picked.clear);
    showTopNotice(
        context,
        sold > 0
            ? '$kinds가지 $sold개를 팔았어요. 금화 +${comma(c.player.gold - before)}'
            : '팔지 못했어요.');
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        _prune();
        final stones = c.player.manaStones;
        final rows = _rows(_group);
        final all = {for (final r in _all) r.key: r};
        final picks = [
          for (final e in _picked.entries)
            if (all[e.key] case final r?) (r, e.value),
        ];
        final count = picks.fold<int>(0, (s, p) => s + p.$2);
        final total =
            picks.fold<int>(0, (s, p) => s + p.$2 * sellPrice(p.$1.entry));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                key: const Key('sellList'),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                children: [
                  // 맨 위 마석 팔기
                  OrnatePanel(
                    key: const Key('stoneSellPanel'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const GameIcon('mana_stone',
                              size: 34, fallback: Icons.diamond_rounded),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('마석 팔기 · 가진 것 ${comma(stones)}',
                                    style: AppText.title(15.5,
                                        color: AppColors.text)),
                                KText(
                                    '1개에 금화 ${RuleConstants.goldPerManaStone} · 대장간에서도 써요',
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          for (final (i, (label, n, on)) in [
                            ('1개', 1, stones >= 1),
                            ('5개', 5, stones >= 5),
                            ('5개 남기고 모두', stones - 5, stones > 5),
                          ].indexed) ...[
                            Expanded(
                              flex: i == 2 ? 5 : 3,
                              child: GoldButton(
                                key: Key('stoneSell_$i'),
                                label: label,
                                height: 40,
                                fontSize: 13.5,
                                onPressed: on ? () => _sellStones(n) : null,
                              ),
                            ),
                            if (i < 2) const SizedBox(width: 6),
                          ],
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    for (final g in SellGroup.values) ...[
                      ShopChip(
                        key: Key('sellChip_${g.name}'),
                        label: g.label,
                        selected: _group == g,
                        onTap: () => setState(() => _group = g),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  const KText('눌러서 고르고, 길게 누르면 몇 개 팔지 정해요.',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  if (rows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: KText('팔 것이 없어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted)),
                    ),
                  for (final r in rows)
                    _SellLine(
                      key: Key('sellRow_${r.key}'),
                      row: r,
                      controller: c,
                      picked: _picked[r.key],
                      onTap: r.worn
                          ? null
                          : () => setState(() => _picked.containsKey(r.key)
                              ? _picked.remove(r.key)
                              : _picked[r.key] = r.count),
                      onLong: r.worn || r.count <= 1 ? null : () => _pickCount(r),
                    ),
                ],
              ),
            ),
            // 아래 고정 버튼
            Container(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + pad.bottom),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00080A1F), Color(0xEE080A1F)],
                  stops: [0, 0.35],
                ),
              ),
              child: GoldButton(
                key: const Key('sellPicked'),
                label: picks.isEmpty
                    ? '팔 것을 골라 주세요'
                    : '${picks.length}가지 $count개 팔기 · 금화 ${comma(total)}',
                height: 48,
                fontSize: 15.5,
                onPressed: picks.isEmpty ? null : _sellPicked,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SellLine extends StatelessWidget {
  const _SellLine({
    super.key,
    required this.row,
    required this.controller,
    required this.picked,
    required this.onTap,
    required this.onLong,
  });

  final _Row row;
  final AppController controller;
  final int? picked;
  final VoidCallback? onTap;
  final VoidCallback? onLong;

  @override
  Widget build(BuildContext context) {
    final e = row.entry;
    final on = picked != null;
    final line = Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
      decoration: BoxDecoration(
        color: on ? const Color(0x33F2C14E) : const Color(0x5512153A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: on
                ? AppColors.goldBright
                : AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(
            row.worn
                ? Icons.block_rounded
                : on
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
            key: Key('sellCheck_${row.key}'),
            color: on ? AppColors.goldBright : AppColors.textMuted,
            size: 24),
        const SizedBox(width: 6),
        SizedBox(
            width: 44,
            height: 44,
            child: BagSlot(entry: e, controller: controller)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              switch (e) {
                EquipEntry(:final item) => EquipName(item),
                _ => Text(bagEntryName(e, controller),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(14, color: AppColors.text)),
              },
              Text(
                  row.worn
                      ? '입는 중이라 못 팔아요'
                      : on && picked! < row.count
                          ? '$picked개 고름 · 1개 금화 ${comma(sellPrice(e))}'
                          : '1개 금화 ${comma(sellPrice(e))}',
                  style: TextStyle(
                      color: on ? AppColors.goldBright : AppColors.textMuted,
                      fontSize: 12)),
            ],
          ),
        ),
        if (e is! EquipEntry)
          Text('×${comma(row.count)}',
              style: AppText.title(15, color: AppColors.text)),
      ]),
    );
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLong,
      behavior: HitTestBehavior.opaque,
      child: row.worn ? Opacity(opacity: 0.45, child: line) : line,
    );
  }
}
