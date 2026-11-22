import 'dart:async';

import 'package:flutter/material.dart';

import '../village/shelter_screen.dart';
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
import 'bag_hold_sheet.dart';
import 'bag_sheet.dart';
import 'sell_sheet.dart' show SellGroup;
import 'shop_screen.dart' show ShopScreen;
import 'material_view.dart';
import '../../theme/top_notice.dart';
import '../bulssi/bulssi_bubble.dart';

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

/// 알 (등급 이름, 정령이 떠나기 전에는 「신비한 알」)
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
    // 묶음 69 #282: 품는 중인 알은 가방이 아니라 펫 쉼터 「알 부화장」에
    for (final e in c.pets.eggs)
      if (e.incubatedAt == null) EggEntry(e),
    for (final n in split(c.gather.pouches)) PouchEntry(n),
    for (final e in c.alchemy.potions.entries)
      for (final n in split(e.value)) PotionEntry(e.key, n),
    for (final i in TownRules.bagItems)
      for (final n in split(c.bagCount(i))) ItemEntry(i, n),
    for (final m in Materials.displayOrder)
      for (final n in split(c.player.materialExact(m))) MaterialEntry(m, n),
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

  /// 묶음 81 #378: 위쪽 띠 펼침 ('tool' · 'treasure' · null)
  String? _open;

  /// 「골라서 버리기」 중 · 고른 칸
  bool _picking = false;
  final Set<int> _picked = {};

  Future<void> _discardPicked(List<BagEntry> shown) async {
    final chosen = [for (final i in _picked) if (i < shown.length) shown[i]];
    if (chosen.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        key: const Key('bagPickConfirm'),
        title: const Text('골라서 버리기'),
        content: KText('${chosen.length}칸을 버릴까요? 버리면 되찾을 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('그만둘래요')),
          TextButton(key: const Key('bagPickYes'), onPressed: () => Navigator.pop(d, true), child: const Text('버리기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    var n = 0;
    for (final e in chosen) {
      final done = switch (e) {
        MaterialEntry(:final id, :final count) => await c.discardMaterial(id, count),
        ItemEntry(:final item, :final count) => await c.discardItem(item, count),
        EquipEntry(:final item) => await c.discardEquip(item.uid),
        PotionEntry(:final key, :final count) => await c.discardPotion(key, count),
        _ => false,
      };
      if (done) n++;
    }
    if (!mounted) return;
    setState(() {
      _picking = false;
      _picked.clear();
    });
    showTopNotice(context, '$n칸을 비웠어요');
  }

  /// 골라서 버릴 수 있는 칸 (알 · 걸음 주머니는 못 버림)
  static bool _pickable(BagEntry e) => e is! EggEntry && e is! PouchEntry;

  /// 등급 (정렬 · 테 색)
  static int _gradeOf(BagEntry e, AppController c) => switch (e) {
        EquipEntry(:final item) => item.grade.index,
        MaterialEntry(:final id) => Materials.info(id).rare ? 2 : 0,
        EggEntry(:final egg) => c.farewellDone ? egg.grade.index : 0,
        PotionEntry(:final key) => AlchemyRules.parseKey(key)?.quality.index ?? 0,
        _ => 0,
      };

  static int _kindOrder(BagEntry e) => switch (e.kind) {
        BagFilter.equip => 0,
        BagFilter.consumable => 1,
        BagFilter.material => 2,
        BagFilter.other => 3,
        BagFilter.all => 4,
      };

  List<BagEntry> _sorted(List<BagEntry> list) {
    final idx = {for (final (i, e) in list.indexed) e: i};
    final out = [...list];
    switch (c.bagSort) {
      case BagSort.recent:
        out.sort((a, b) {
          final d = c.bagOrderOf(bagKey(b)) - c.bagOrderOf(bagKey(a));
          return d != 0 ? d : idx[a]! - idx[b]!;
        });
      case BagSort.grade:
        out.sort((a, b) {
          final d = _gradeOf(b, c) - _gradeOf(a, c);
          return d != 0 ? d : idx[a]! - idx[b]!;
        });
      case BagSort.kind:
        out.sort((a, b) {
          final d = _kindOrder(a) - _kindOrder(b);
          return d != 0 ? d : idx[a]! - idx[b]!;
        });
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final p = c.player;
        final all = bagEntries(c);
        // 묶음 81 #378: 새로 얻은 것 · 최근 차례
        c.noteBagContents(bagCounts(all));
        final shown = _sorted(_filter == BagFilter.all
            ? all
            : [for (final e in all) if (e.kind == _filter) e]);
        final cap = c.bagCapacity;
        final used = c.bagUsed;
        final cost = c.bagExpandCost;
        // 전체 보기에서는 남은 칸을 점선 빈 칸으로
        final empty = _filter == BagFilter.all && cap > all.length ? cap - all.length : 0;
        const cols = 5;
        final cells = (_filter == BagFilter.all ? all.length + empty : 0);
        final locks = _filter == BagFilter.all && cost != null
            ? (cells % cols == 0 ? 1 : cols - cells % cols)
            : 0;
        final ratio = cap <= 0 ? 1.0 : (used / cap).clamp(0.0, 1.0);
        final capColor = used >= cap
            ? AppColors.danger
            : ratio > 0.8
                ? const Color(0xFFF2C94C)
                : const Color(0xFF6BD97A);
        final tools = c.harvest.granted ? HarvestTool.values : const <HarvestTool>[];
        final relics = c.ownedRelics;
        return Column(children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, top + 6, 14, 0),
            child: Column(children: [
              // ① 마석 · 금화는 머리 줄 오른쪽 작은 칩 둘
              TutorialGlow(
                on: c.tutorialStep == TutorialStep.bag,
                child: OrnateTopBar(
                  title: '가방',
                  onBack: widget.onBack,
                  trailing: _WalletChips(manaStones: p.manaStones, gold: p.gold),
                ),
              ),
              if (widget.onBack == null && !c.inTutorial) ...[
                const SizedBox(height: 4),
                SpiritBadgeRow(
                    key: const Key('bagSpirit'),
                    line: c.bagFree <= 0
                        ? '가방이 가득 찼어! 안 쓰는 건 팔거나 정리하자.'
                        : '얻은 건 다 여기 있어. 물약은 눌러서 바로 쓸 수 있어.'),
              ],
              const SizedBox(height: 6),
            ]),
          ),
          Expanded(
            child: ClipRect(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                children: [
                  // ③ 도구 · 보물 — 한 줄 띠 두 칸 (누르면 아래 펼침)
                  if (tools.isNotEmpty || relics.isNotEmpty)
                    Row(children: [
                      if (tools.isNotEmpty)
                        Expanded(
                          child: _StripButton(
                            key: const Key('bagStrip_tool'),
                            on: _open == 'tool',
                            icon: 'assets/images/tool_${HarvestTool.values.first.name}_${c.toolTier(HarvestTool.values.first).name}.webp',
                            title: '도구 ${tools.length}',
                            dots: [
                              for (final t in tools)
                                c.toolMaxOf(t) <= 0 ? 0.0 : c.toolDurability(t) / c.toolMaxOf(t),
                            ],
                            onTap: () => setState(() => _open = _open == 'tool' ? null : 'tool'),
                          ),
                        ),
                      if (tools.isNotEmpty && relics.isNotEmpty) const SizedBox(width: 6),
                      if (relics.isNotEmpty)
                        Expanded(
                          child: _StripButton(
                            key: const Key('bagStrip_treasure'),
                            on: _open == 'treasure',
                            icon: 'assets/images/${relics.first.asset}.webp',
                            title: '보물 ${relics.length}',
                            onTap: () => setState(() => _open = _open == 'treasure' ? null : 'treasure'),
                          ),
                        ),
                    ]),
                  if (_open == 'tool' && tools.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _ToolList(controller: c),
                  ],
                  if (_open == 'treasure' && relics.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    PreciousPanel(controller: c),
                  ],
                  // 묶음 69 #282: 품는 중인 알은 펫 쉼터에서
                  if (c.pets.eggs.any((e) => e.incubatedAt != null))
                    Padding(
                      key: const Key('bagIncubating'),
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                          '품는 중인 알 ${c.pets.eggs.where((e) => e.incubatedAt != null).length}개 · 펫 쉼터에서 볼 수 있어요',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                    ),
                  // 묶음 47 #240: 가방이 가득해 받지 못하고 기다리는 것
                  if (c.hasBagHold) ...[
                    const SizedBox(height: 8),
                    BagHoldBanner(controller: c),
                  ],
                  const SizedBox(height: 8),
                  OrnatePanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ⑤ 가방 35 / 35칸 + 칸 막대 + 골라서 버리기
                        Row(children: [
                          const GameIcon('bag', size: 26),
                          const SizedBox(width: 5),
                          Text('가방', style: AppText.title(17)),
                          const SizedBox(width: 6),
                          Text('$used / $cap칸',
                              key: const Key('bagCap'),
                              style: TextStyle(
                                  color: used >= cap ? AppColors.danger : AppColors.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                key: const Key('bagCapBar'),
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: const Color(0xFF0E0C22),
                                valueColor: AlwaysStoppedAnimation(capColor),
                              ),
                            ),
                          ),
                          // 전투 자동 마시기 (11-11 #93): 작은 물약 아이콘
                          IconButton(
                            key: const Key('bagAutoUse'),
                            tooltip: '전투에서 자동으로 마시기',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => showAutoUseSheet(context, c),
                            icon: Icon(Icons.local_drink_rounded,
                                size: 20,
                                color: c.alchemy.autoHp > 0 || c.alchemy.autoCure
                                    ? AppColors.goldBright
                                    : AppColors.textMuted),
                          ),
                          _MiniButton(
                            key: const Key('bagPickToggle'),
                            label: '골라서 버리기',
                            on: _picking,
                            onTap: () => setState(() {
                              _picking = !_picking;
                              _picked.clear();
                            }),
                          ),
                        ]),
                        if (used > cap)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            // 묶음 72 #305: 칸이 줄어 넘친 까닭에 맞게
                            child: KText(
                                c.bigPackEnded
                                    ? '늘어났던 칸이 끝나서 칸보다 많아요. 정리하면 새로 얻는 것을 받을 수 있어요.'
                                    : '칸보다 많이 들어 있어요. 정리하면 새로 얻는 것을 받을 수 있어요.',
                                key: const Key('bagOverLine'),
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ),
                        const SizedBox(height: 8),
                        // ⑥ 탭 한 줄 + 개수 · 정렬
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            for (final f in BagFilter.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 5),
                                child: _MiniButton(
                                  key: Key('bagTab_${f.name}'),
                                  label: '${f.label} ${f == BagFilter.all ? all.length : all.where((e) => e.kind == f).length}',
                                  on: _filter == f,
                                  tab: true,
                                  onTap: () => setState(() {
                                    _filter = f;
                                    _picked.clear();
                                  }),
                                ),
                              ),
                          ]),
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          Expanded(
                            child: Text(_picking ? '버릴 칸을 골라요' : '칸을 누르면 아래에 자세히',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          ),
                          GestureDetector(
                            key: const Key('bagSort'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => c.setBagSort(BagSort.values[(c.bagSort.index + 1) % BagSort.values.length]),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text('${c.bagSort.label} ▾',
                                  style: const TextStyle(color: AppColors.goldBright, fontSize: 11.5, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ]),
                        if (_picking)
                          Container(
                            key: const Key('bagPickBar'),
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
                            decoration: BoxDecoration(
                              color: const Color(0x1FEF6B62),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x80EF6B62)),
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Text(_picked.isEmpty ? '버릴 것을 골라요' : '${_picked.length}칸 골랐어요',
                                    style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
                              ),
                              _MiniButton(
                                key: const Key('bagPickGo'),
                                label: '버리기',
                                on: _picked.isNotEmpty,
                                onTap: _picked.isEmpty ? null : () => _discardPicked(shown),
                              ),
                            ]),
                          ),
                        const SizedBox(height: 4),
                        if (shown.isEmpty && empty == 0)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: KText('여기에 든 것이 없어요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textMuted)),
                          )
                        else
                          // ⑦ 5칸 격자
                          GridView.count(
                            key: const Key('bagGrid'),
                            crossAxisCount: cols,
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 5,
                            crossAxisSpacing: 5,
                            children: [
                              for (final (i, e) in shown.indexed)
                                TutorialGlow(
                                  on: c.tutorialStep == TutorialStep.bag &&
                                      e is MaterialEntry &&
                                      (e.id == MaterialId.slimeJelly || e.id == MaterialId.slimeCore),
                                  child: BagSlot(
                                    key: Key('bagCell_$i'),
                                    entry: e,
                                    controller: c,
                                    mark: e is EquipEntry ? c.equipMark(e.item) : null,
                                    isNew: c.bagIsNew(bagKey(e)),
                                    picked: _picked.contains(i),
                                    dim: _picking && !_pickable(e),
                                    onTap: _picking
                                        ? (_pickable(e)
                                            ? () => setState(() => _picked.contains(i) ? _picked.remove(i) : _picked.add(i))
                                            : null)
                                        : () {
                                            unawaited(c.markBagSeen(bagKey(e)));
                                            showBagEntry(context, c, e);
                                          },
                                  ),
                                ),
                              for (var i = 0; i < empty; i++) const BagSlot(dotted: true),
                              for (var i = 0; i < locks; i++)
                                BagSlot(
                                    key: i == 0 ? const Key('bagExpandSlot') : null,
                                    locked: true,
                                    // 묶음 16 #118: 자물쇠만. 바로 다음 칸은 조금 밝게
                                    nextLock: i == 0,
                                    onTap: _expand),
                            ],
                          ),
                        const SizedBox(height: 6),
                        // 칸 아래 표시 뜻 한 줄
                        const _MarkLegend(),
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

/// 묶음 81 #378: 가방 칸 열쇠 (새로 얻음 · 최근 차례)
String bagKey(BagEntry e) => switch (e) {
      EquipEntry(:final item) => 'e:${item.uid}',
      MaterialEntry(:final id) => 'm:${id.name}',
      ItemEntry(:final item) => 'i:${item.name}',
      PotionEntry(:final key) => 'p:$key',
      EggEntry(:final egg) => 'g:${egg.id}',
      PouchEntry() => 'pouch',
    };

/// 열쇠마다 개수 (99개로 나뉜 칸은 합침)
Map<String, int> bagCounts(List<BagEntry> all) {
  final out = <String, int>{};
  for (final e in all) {
    final n = switch (e) {
      MaterialEntry(:final count) || ItemEntry(:final count) || PotionEntry(:final count) || PouchEntry(:final count) =>
        count,
      _ => 1,
    };
    out[bagKey(e)] = (out[bagKey(e)] ?? 0) + n;
  }
  return out;
}

/// ① 머리 줄 오른쪽 마석 · 금화 작은 칩
class _WalletChips extends StatelessWidget {
  const _WalletChips({required this.manaStones, required this.gold});

  final int manaStones;
  final int gold;

  Widget _chip(Key key, String icon, int n) => Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(3, 2, 9, 2),
        decoration: BoxDecoration(
          color: const Color(0xE615133A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GameIcon(icon, size: 20),
          const SizedBox(width: 3),
          Text(comma(n), style: const TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ]),
      );

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        _chip(const Key('bagManaChip'), 'mana_stone', manaStones),
        const SizedBox(width: 5),
        _chip(const Key('bagGoldChip'), 'gold', gold),
      ]);
}

/// ③ 도구 · 보물 띠 버튼
class _StripButton extends StatelessWidget {
  const _StripButton({super.key, required this.on, required this.icon, required this.title, required this.onTap, this.dots});

  final bool on;
  final String icon;
  final String title;
  final VoidCallback onTap;

  /// 도구 내구도 (0~1, 거의 닳으면 빨강)
  final List<double>? dots;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 8, 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1C40),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? AppColors.goldBright : const Color(0xFF3A3468), width: 1.5),
          ),
          child: Row(children: [
            Image.asset(icon, width: 26, height: 26, errorBuilder: (_, __, ___) => const SizedBox(width: 26)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w800)),
                if (dots != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      for (final d in dots!)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d < 0.25 ? const Color(0xFFEF6B62) : const Color(0xFF6BD97A),
                          ),
                        ),
                    ]),
                  ),
              ]),
            ),
            Icon(on ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: AppColors.textMuted),
          ]),
        ),
      );
}

/// ③ 도구 펼침: 도구마다 막대 · ○/○
class _ToolList extends StatelessWidget {
  const _ToolList({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      key: const Key('bagToolList'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF26224D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3468)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('채집 도구', style: AppText.title(13, color: AppColors.goldBright)),
        const SizedBox(height: 4),
        for (final t in HarvestTool.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              Image.asset('assets/images/tool_${t.name}_${c.toolTier(t).name}.webp',
                  key: Key('bagTool_${t.name}'),
                  width: 24,
                  height: 24,
                  errorBuilder: (_, __, ___) => const SizedBox(width: 24)),
              const SizedBox(width: 6),
              Expanded(
                flex: 5,
                child: Text('${c.toolTier(t).label} ${HarvestRules.toolName(t)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.text, fontSize: 12)),
              ),
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: c.toolMaxOf(t) <= 0 ? 0 : (c.toolDurability(t) / c.toolMaxOf(t)).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFF0E0C22),
                    valueColor: AlwaysStoppedAnimation(c.toolMaxOf(t) > 0 && c.toolDurability(t) / c.toolMaxOf(t) < 0.25
                        ? const Color(0xFFEF6B62)
                        : const Color(0xFF6BD97A)),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text('${c.toolDurability(t)}/${c.toolMaxOf(t)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: c.toolDurability(t) > 0 ? AppColors.textMuted : AppColors.danger, fontSize: 11)),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// 작은 테 버튼 (탭 · 골라서 버리기)
class _MiniButton extends StatelessWidget {
  const _MiniButton({super.key, required this.label, required this.on, this.onTap, this.tab = false});

  final String label;
  final bool on;
  final bool tab;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: tab ? 11 : 9, vertical: tab ? 5 : 3),
          decoration: BoxDecoration(
            color: on ? AppColors.gold : (tab ? const Color(0xFF1D1A40) : Colors.transparent),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: tab && !on ? const Color(0xFF3A3468) : AppColors.gold, width: 1.2),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? AppColors.night : (tab ? AppColors.text : AppColors.goldBright),
                  fontSize: tab ? 12.5 : 11.5,
                  fontWeight: FontWeight.w800)),
        ),
      );
}

/// 칸 아래 표시 뜻 한 줄
class _MarkLegend extends StatelessWidget {
  const _MarkLegend();

  Widget _b(String t, Color bg, {Color fg = AppColors.night}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.w900)),
      );

  @override
  Widget build(BuildContext context) {
    const st = TextStyle(color: AppColors.textMuted, fontSize: 10.5);
    return Wrap(key: const Key('bagLegend'), spacing: 8, runSpacing: 2, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [_b('▲', kMarkUp), const Text(' 입은 것보다 좋음', style: st)]),
      Row(mainAxisSize: MainAxisSize.min, children: [_b('▼', kMarkDown, fg: Colors.white), const Text(' 나쁨', style: st)]),
      Row(mainAxisSize: MainAxisSize.min, children: [_b('⇄', kMarkMix), const Text(' 섞임', style: st)]),
      Row(mainAxisSize: MainAxisSize.min, children: [_b('새', kMarkUp), const Text(' 빈 부위', style: st)]),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: kNewDot)),
        const Text(' 새로 얻음', style: st),
      ]),
    ]);
  }
}

const Color kMarkUp = Color(0xFF6BD97A);
const Color kMarkDown = Color(0xFFEF6B62);
const Color kMarkMix = Color(0xFFF2C94C);
const Color kNewDot = Color(0xFFFF8A3D);

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
      this.nextLock = false,
      this.mark,
      this.isNew = false,
      this.picked = false,
      this.dim = false,
      this.dotted = false});

  /// 묶음 81 #377: 장비 비교 표시 (▲ ▼ ⇄ 새)
  final CompareMark? mark;

  /// 묶음 81 #378: 새로 얻은 것 (주황 점)
  final bool isNew;

  /// 「골라서 버리기」로 고름
  final bool picked;

  /// 「골라서 버리기」 중 고를 수 없는 칸
  final bool dim;

  /// 남은 빈 칸 (점선)
  final bool dotted;

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
    if (dotted && e == null) {
      return CustomPaint(
        painter: _DashedBox(color: const Color(0xFF3A3468)),
        child: const SizedBox.expand(),
      );
    }
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
    final cell = GestureDetector(
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
                    grade: controller != null && controller!.farewellDone ? egg.grade : EggGrade.common,
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
              bottom: 2,
              child: Text('+${item.enhance}',
                  style: const TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 3)])),
            ),
          // 묶음 81 #377: 장비 비교 표시 (오른쪽 위)
          if (mark != null)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                key: Key('cmp_${mark!.name}'),
                padding: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: switch (mark!) {
                    CompareMark.up || CompareMark.fresh => kMarkUp,
                    CompareMark.down => kMarkDown,
                    CompareMark.mix => kMarkMix,
                  },
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                    switch (mark!) {
                      CompareMark.up => '▲',
                      CompareMark.down => '▼',
                      CompareMark.mix => '⇄',
                      CompareMark.fresh => '새',
                    },
                    style: TextStyle(
                        color: mark == CompareMark.down ? Colors.white : AppColors.night,
                        fontSize: 9.5,
                        height: 1.4,
                        fontWeight: FontWeight.w900)),
              ),
            ),
          // 묶음 81 #378: 새로 얻은 것 (주황 점, 왼쪽 위)
          if (isNew)
            Positioned(
              left: 3,
              top: 3,
              child: Container(
                  key: const Key('bagNewDot'),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: kNewDot)),
            ),
          if (picked)
            Positioned.fill(
              child: Container(
                key: const Key('bagPicked'),
                decoration: BoxDecoration(
                  color: const Color(0x59EF6B62),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Center(
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 24)),
              ),
            ),
        ]),
      ),
    );
    return dim ? Opacity(opacity: 0.35, child: cell) : cell;
  }
}

/// 남은 빈 칸 점선 테
class _DashedBox extends CustomPainter {
  _DashedBox({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)).deflate(0.7);
    final path = Path()..addRRect(r);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBox old) => old.color != color;
}

String bagEntryName(BagEntry e, [AppController? c]) => switch (e) {
      MaterialEntry(:final id) => Materials.info(id).name,
      ItemEntry(:final item) =>
        c == null ? TownRules.info(item).name : c.itemName(item),
      EquipEntry(:final item) => item.name,
      EggEntry(:final egg) => c != null && c.farewellDone ? egg.grade.label : '신비한 알',
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
            if (e is EquipEntry) ...[
              // 묶음 13 A4: 스탯은 메달 + 숫자, 지금 입은 것과 비교
              ItemStats(e.item,
                  compare: c.armory.wornIn(e.item.slot), fontSize: 14),
              // 묶음 81 #377: 지금 입은 것과 비교 줄 (대장간과 같은 계산)
              const SizedBox(height: 6),
              EquipCompareBox(item: e.item, worn: c.armory.wornIn(e.item.slot)),
            ]
            else if (desc.isNotEmpty)
              KText(desc,
                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
            const SizedBox(height: 6),
            KText(sell,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 14),
            if (action != null) ...[action, const SizedBox(height: 8)],
            // 묶음 33 #205: 버튼인 줄 알게 금테 테두리 버튼 + 휴지통, 「모두 버리기」만 붉은 테두리
            Row(children: [
              if (count > 1) ...[
                Expanded(
                  child: _DiscardButton(
                    key: const Key('discardOne'),
                    label: '1개 버리기',
                    onPressed: () => _discard(context, 1),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _DiscardButton(
                  key: const Key('discardAll'),
                  label: count > 1 ? '모두 버리기' : '버리기',
                  danger: true,
                  onPressed: () => _discard(context, count),
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
          // 묶음 75 #327: 알은 가방에서 품지 않고 펫 쉼터 알 부화장에서
          children.addAll([
            KText(
                '펫 쉼터 알 부화장에서 품을 수 있어요. '
                '품으면 ${PetRules.hatchTime.inHours}시간 뒤 깨어나요.',
                key: const Key('eggSheetHatchery'),
                style: const TextStyle(color: AppColors.text, fontSize: 14)),
            const SizedBox(height: 12),
            GoldButton(
              key: const Key('eggSheetGo'),
              label: '알 부화장으로',
              height: 46,
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ShelterScreen(controller: c)));
              },
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
            // 묶음 32 #187: 광고 보고 남은 시간 절반 (알 하나에 한 번)
            if (c.canAdHalveEgg(e)) ...[
              const SizedBox(height: 8),
              AdButton(
                key: const Key('adHalveEgg'),
                label: '광고 보고 남은 시간 절반',
                onPressed: () async {
                  final ok = await c.adHalveEgg(e.id);
                  if (!ok && context.mounted) {
                    showTopNotice(context, '광고를 불러오지 못했어요.');
                  }
                },
              ),
            ],
          ]);
        }
        // 묶음 81 #372: 펫이 가득이면 깨울 수 없음 (그대로 두거나 팔 수 있음)
        if (e != null && c.farewellDone && c.petsFull) {
          children.addAll([
            const SizedBox(height: 10),
            const KText(PetsOps.petsFullLine,
                key: Key('eggSheetPetsFull'),
                style: TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]);
        }
        // 묶음 80 #365: 잡화상에서 팔기 (정령이 떠난 뒤 · 품지 않은 알만)
        if (e != null) {
          const muted = TextStyle(color: AppColors.textMuted, fontSize: 12);
          children.add(const SizedBox(height: 14));
          if (!c.farewellDone) {
            children.add(const KText('아직 팔 수 없어요', key: Key('eggSellNot'), style: muted));
          } else if (e.incubatedAt != null) {
            children.add(const KText('품는 중이라 팔 수 없어요', key: Key('eggSellHatching'), style: muted));
          } else {
            children.addAll([
              KText('잡화상에서 금화 ${comma(e.grade.price)}', key: const Key('eggSellPrice'), style: muted),
              const SizedBox(height: 8),
              FrameButton(
                key: const Key('eggSellGo'),
                label: '잡화상에서 팔기',
                gameIcon: 'gold',
                height: 44,
                onPressed: () {
                  final nav = Navigator.of(context)..pop();
                  nav.push(MaterialPageRoute<void>(
                      builder: (_) => ShopScreen(controller: c, sellGroup: SellGroup.egg)));
                },
              ),
            ]);
          }
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
                        size: 96,
                        grade: c.farewellDone ? egg.grade : EggGrade.common,
                        glowing: e != null && c.eggReady(e))),
                const SizedBox(height: 6),
                Text(c.farewellDone ? egg.grade.label : '신비한 알',
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

/// 튜토리얼에서 볼 곳이 은은하게 반짝 (묶음 18 #148)
class TutorialGlow extends StatefulWidget {
  const TutorialGlow({super.key, required this.on, required this.child});

  final bool on;
  final Widget child;

  @override
  State<TutorialGlow> createState() => _TutorialGlowState();
}

class _TutorialGlowState extends State<TutorialGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.on) _a.repeat(reverse: true, count: 8);
  }

  @override
  void didUpdateWidget(TutorialGlow old) {
    super.didUpdateWidget(old);
    if (widget.on && !old.on) _a.repeat(reverse: true, count: 8);
    if (!widget.on && _a.isAnimating) _a.stop();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.on) return widget.child;
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (context, child) => DecoratedBox(
        key: const Key('tutorialGlow'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: AppColors.goldBright
                    .withValues(alpha: 0.35 + 0.45 * _a.value),
                blurRadius: 10 + 10 * _a.value),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// 버리기 버튼 (금테·어두운 바탕 + 휴지통, [danger] 면 붉은 테두리)
class _DiscardButton extends StatelessWidget {
  const _DiscardButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.danger = false,
      this.icon = Icons.delete_outline_rounded});

  final String label;
  final VoidCallback onPressed;
  final bool danger;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final edge = danger ? const Color(0xFFC0473C) : AppColors.gold;
    return Material(
      color: const Color(0xFF1B1E4C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: edge, width: 1.4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 18, color: danger ? const Color(0xFFE07A6E) : AppColors.goldBright),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: danger ? const Color(0xFFF0A79C) : AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }
}


/// 묶음 45 #232 · 81 #378: 가방 「보물」 펼침 — 가지고만 있으면 효과 (팔기·거래·버리기 안 됨)
class PreciousPanel extends StatelessWidget {
  const PreciousPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final items = controller.ownedRelics;
    return Container(
      key: const Key('preciousPanel'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF26224D),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3A3468)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('보물', style: AppText.title(13, color: AppColors.goldBright)),
            const SizedBox(width: 6),
            const Text('가지고만 있으면 효과',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 4),
          for (final r in items)
            GestureDetector(
              key: Key(r.stages.isEmpty ? 'precious_${r.asset}' : 'precious_${r.npc.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => showDialog<void>(
                context: context,
                builder: (d) => GameAlert(
                  title: Text(r.name, style: AppText.title(18)),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    Image.asset('assets/images/${r.asset}.webp',
                        height: 96, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    const SizedBox(height: 8),
                    KText(r.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.4)),
                    const SizedBox(height: 6),
                    const KText('가지고 있으면 효과가 있어요. 팔거나 버릴 수 없어요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(d).pop(), child: const Text('닫기')),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xCC1A1238),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA06EE6)),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Image.asset('assets/images/${r.asset}.webp',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.card_giftcard_rounded, color: AppColors.goldBright, size: 20)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
                      Text(r.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    ]),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// 묶음 47 #240: 가방 탭 위 「받지 못한 것」 띠 — 「보기」(창) · 「다시 받기」
class BagHoldBanner extends StatelessWidget {
  const BagHoldBanner({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final n = c.bagHoldList.length;
    return OrnatePanel(
      key: const Key('bagHoldBanner'),
      child: Row(children: [
        const Icon(Icons.inventory_2_rounded, color: AppColors.goldBright, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: KText('받지 못한 것 $n가지',
              style: const TextStyle(
                  color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          key: const Key('bagHoldView'),
          onPressed: () => showBagHoldSheet(context, c),
          child: const Text('보기',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ),
        const SizedBox(width: 2),
        SizedBox(
          width: 112,
          child: _DiscardButton(
          key: const Key('bagHoldRetry'),
          label: '다시 받기',
          icon: Icons.download_rounded,
          onPressed: () async {
            final before = c.bagHoldList.length;
            final left = await c.retryHold();
            if (!context.mounted) return;
            showTopNotice(
                context,
                left == 0
                    ? '모두 가방에 넣었어요!'
                    : left < before
                        ? '들어가는 만큼 넣었어요. 아직 $left가지가 남았어요.'
                        : '가방에 빈칸이 없어요. 안 쓰는 것을 팔거나 정리해 주세요.');
          },
        ),
        ),
      ]),
    );
  }
}

/// 묶음 81 #377: 「지금 입은 ○○와 비교」 + 초록 ↑ / 빨강 ↓ (입은 게 없으면 「이 부위는 비어 있어요」)
class EquipCompareBox extends StatelessWidget {
  const EquipCompareBox({super.key, required this.item, required this.worn});

  final EquipItem item;
  final EquipItem? worn;

  @override
  Widget build(BuildContext context) {
    final w = worn;
    if (w != null && w.uid == item.uid) return const SizedBox.shrink();
    final lines = w == null ? const <(bool, String)>[] : EquipmentRules.compareItems(item, w);
    return Container(
      key: const Key('equipCompare'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(color: const Color(0xFF15133A), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (w == null)
          const Text('이 부위는 비어 있어요 · 입으면 바로 좋아져요',
              key: Key('equipCompareEmpty'),
              style: TextStyle(color: kMarkUp, fontSize: 12.5, fontWeight: FontWeight.w700))
        else ...[
          Text('지금 입은 ${josa(w.name, '와/과')} 비교',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          if (lines.isEmpty)
            const Text('같아요', style: TextStyle(color: AppColors.text, fontSize: 12.5))
          else
            for (final (up, t) in lines)
              Text('${up ? '↑' : '↓'} $t',
                  style: TextStyle(color: up ? kMarkUp : kMarkDown, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }
}
