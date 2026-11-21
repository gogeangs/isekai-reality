import '../village/npc_header.dart';
import 'package:flutter/material.dart' hide Element;

import '../../core/format.dart';
import '../../app_controller.dart';
import '../../core/models/armory.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../town/material_view.dart';
import '../alchemy/alchemy_screen.dart' show ProcessPanel;
import '../alchemy/convert_panel.dart' show LockedJobPanel;
import 'boss_gear_tab.dart';
import 'equipment_view.dart';
import 'first_weapon_picker.dart';
import '../tutorial/feature_tour.dart';
import '../battle/element_view.dart';
import '../harvest/harvest_sheet.dart' show ToolRepairPanel;
import '../../theme/top_notice.dart';
import '../jobs/job_skill_bar.dart';

part 'smithy_screen/tabs.dart';

part 'smithy_screen/widgets.dart';

/// 마을 대장간 (11-10 #27): 장비 만들기 · 강화 · 수리 · 속성 · 재료 가공 · 보스 장비.
/// 장비는 대장간에서만 만든다.
///
/// 묶음 40 (#220~#223): 위쪽(뒤로 가기 · 도르군 · 마석·금화 · 탭 두 줄)은 화면 위에 붙어 있고
/// 아래 내용만 굴러간다.
class SmithyScreen extends StatefulWidget {
  const SmithyScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SmithyScreen> createState() => _SmithyScreenState();
}

class _SmithyScreenState extends State<SmithyScreen> {
  int _tab = 0;

  /// 탭을 바꾼 뒤 마을 사람 말풍선 (탭 안내)
  String? _tabLine;

  /// 만들기 탭 부위 칩 (null = 전체)
  EquipSlot? _slot;

  /// 속성 탭: 「바꾸기」를 펼친 장비 · 고른 속성 · 「더 보기」를 연 장비
  final _changing = <String>{};
  final _picked = <String, Element>{};
  final _more = <String>{};

  static const tabs = ['만들기', '강화', '수리', '속성', '재료 가공', '보스 장비'];

  void _select(int i) => setState(() {
        _tab = i;
        _tabLine = i == 0 && c.firstWeaponFree
            ? VillageRules.smithyFree
            : VillageRules.smithyGuide(i);
      });

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return TourScreenMark(name: 'smithy', child: Scaffold(
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        header: true,
        interior: 'smithy', // 묶음 67 #272
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final p = c.player;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 위쪽 묶음 (붙어 있음)
                Padding(
                  key: const Key('smithyHeader'),
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OrnateTopBar(
                        title: '대장간',
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 6),
                      // 묶음 38 #213: 정령 띠 대신 마을 사람이 안내 (탭을 바꾸면 그 탭 안내)
                      NpcHeader(
                        controller: c,
                        npc: Npc.dorgun,
                        guide: VillageRules.smithyGuide(0),
                        situation:
                            c.firstWeaponFree ? VillageRules.smithyFree : null,
                        tabLine: _tabLine,
                      ),
                      const SizedBox(height: 6),
                      // 묶음 30 #55: 대장간에서 쓰는 직업 스킬 (직업이 있을 때만)
                      JobSkillBar(controller: c, places: const [
                        SkillPlace.smithyEnhance,
                        SkillPlace.smithyCraft,
                        SkillPlace.smithyWork,
                      ]),
                      _WalletLine(manaStones: p.manaStones, gold: p.gold),
                      const SizedBox(height: 4),
                      for (final row in const [
                        [0, 1, 2],
                        [3, 4, 5],
                      ]) ...[
                        Row(children: [
                          for (final i in row) ...[
                            Expanded(
                              child: _TabButton(
                                key: Key('smithyTab_$i'),
                                label: tabs[i],
                                selected: _tab == i,
                                onTap: () => _select(i),
                              ),
                            ),
                            if (i != row.last) const SizedBox(width: 6),
                          ],
                        ]),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
                // ── 아래 내용 (굴러감)
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(
                      child: ListView(
                        key: const Key('smithyList'),
                        // 묶음 26 #173: 아래 홈 표시줄만큼 더 비워 마지막 버튼이 가려지지 않게
                        padding:
                            EdgeInsets.fromLTRB(14, 8, 14, 28 + pad.bottom),
                        children: switch (_tab) {
                          0 => _craftTab(),
                          1 => _enhanceTab(),
                          2 => _repairTab(),
                          3 => _elementTab(),
                          4 => [ProcessPanel(controller: c, smithy: true)],
                          _ => [BossGearTab(controller: c)],
                        },
                      ),
                    ),
                    // 위쪽 묶음 아래 옅은 그림자 (지나가는 카드와 나뉘어 보이게)
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 14,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: Key('smithyHeaderShadow'),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x99000000), Color(0x00000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    ));
  }

  // ───────────────────────── 만들기 (#221)

  List<Widget> _craftTab() {
    final recipes = [
      for (final info in EquipmentRules.all)
        if ((_slot == null || info.slot == _slot) &&
            EquipmentRules.shownAt(info.id, c.player.level.level))
          info,
    ];
    // 재료가 다 있는 장비를 맨 위로 (나머지는 지금 순서)
    final ready = [for (final i in recipes) if (_ready(i)) i];
    final rest = [for (final i in recipes) if (!_ready(i)) i];
    return [
      SingleChildScrollView(
        key: const Key('slotChips'),
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final s in <EquipSlot?>[null, ...EquipSlot.values]) ...[
            _SlotChip(
              key: Key('slotChip_${s?.name ?? 'all'}'),
              label: s == null ? '전체' : EquipmentRules.slotLabel(s),
              selected: _slot == s,
              onTap: () => setState(() => _slot = s),
            ),
            const SizedBox(width: 6),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      // 묶음 19 #4-2: 채집이 열리면 첫 채집 도구는 무료
      if (c.featureOpen(Feature.harvest) && !c.harvestToolsReady) ...[
        _FirstToolPanel(onMake: () async {
          if (await c.makeFirstTools() && mounted) {
            _snack('채집 도구를 만들었어요! 지도에서 꽃과 버섯을 딸 수 있어요.');
          }
        }),
        const SizedBox(height: 10),
      ],
      if (c.firstWeaponFree) ...[
        FirstWeaponPicker(
          controller: c,
          onCraft: (base) async {
            final item = await c.craft(base);
            if (!mounted || item == null) return;
            await _showMade(item);
          },
        ),
        const SizedBox(height: 10),
      ],
      for (final info in [...ready, ...rest]) ...[
        _RecipeCard(
          info: info,
          controller: c,
          ready: _ready(info),
          onCraft: () => _craftSheet(info),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  // ───────────────────────── 강화 (#222)

  // ───────────────────────── 수리 (#222)

  // ───────────────────────── 속성 (#223)

  /// 묶음 66: 「특산물 더 넣기」를 고른 장비
  final Set<String> _extra = {};

  Future<void> _runSmith(EquipItem it, SmithAction a, {Element? to}) async {
    final r = await c.smith(it.uid, a, to: to, special: a == SmithAction.upgrade && _extra.contains(it.uid));
    if (!mounted) return;
    if (r == SmithResult.ok) {
      setState(() {
        _changing.remove(it.uid);
        _picked.remove(it.uid);
      });
    }
    _snack(switch (r) {
      SmithResult.ok => switch (a) {
          SmithAction.apply => '${to!.label} 속성을 입혔어요!',
          SmithAction.change => '${to!.label} 속성으로 바꿨어요!',
          SmithAction.extract => '속성을 뽑아 빛나는 코어를 돌려받았어요.',
          SmithAction.upgrade => '속성이 더 진하게 빛나요!',
        },
      SmithResult.failed => SmithRules.failLine,
      SmithResult.cannot => '금화나 빛나는 속성 코어가 모자라요.',
    });
  }

  /// 속성이 있는 장비: 「속성 강화」 · 「바꾸기」 · 「추출」
  Widget _elementButtons(EquipItem it) {
    final el = it.element!;
    final maxed = it.elementLevel >= SmithRules.maxLevel;
    final changing = _changing.contains(it.uid);
    final canUp = !maxed && _canSmith(SmithAction.upgrade, el);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 5,
          child: _CostButton(
            key: Key('smith_upgrade_${it.uid}'),
            gold: true,
            label: maxed ? '가장 진하게 빛나요' : '속성 강화',
            cost: maxed ? null : _smithCost(SmithAction.upgrade, el),
            onPressed: canUp ? () => _runSmith(it, SmithAction.upgrade) : null,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: _CostButton(
            key: Key('smith_change_${it.uid}'),
            label: changing ? '접기' : '바꾸기',
            onPressed: () => setState(() => changing
                ? _changing.remove(it.uid)
                : _changing.add(it.uid)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 3,
          child: _CostButton(
            key: Key('smith_extract_${it.uid}'),
            label: '추출',
            cost: '금화 ${SmithRules.gold(SmithAction.extract)}',
            onPressed: _canSmith(SmithAction.extract, el)
                ? () => _runSmith(it, SmithAction.extract)
                : null,
          ),
        ),
      ]),
      if (!maxed && !_canSmith(SmithAction.upgrade, el) && !changing)
        _Short(lines: _smithShort(SmithAction.upgrade, el)),
      // 묶음 66: 특산물 하나를 더 넣으면 망치질이 안정됨 (숫자는 숨김)
      if (!maxed && c.extraSpecialty != null)
        InkWell(
          key: Key('smith_extra_${it.uid}'),
          onTap: () => setState(() => _extra.contains(it.uid) ? _extra.remove(it.uid) : _extra.add(it.uid)),
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(_extra.contains(it.uid) ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: AppColors.goldBright, size: 20),
              const SizedBox(width: 4),
              Image.asset(Materials.info(c.extraSpecialty!).asset, width: 20, height: 20, errorBuilder: (_, __, ___) => const SizedBox(width: 20)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                    _extra.contains(it.uid)
                        ? '특산물 더 넣기 · ${Materials.info(c.extraSpecialty!).name} 1 — 망치질이 한결 안정돼요'
                        : '특산물 더 넣기 (${Materials.info(c.extraSpecialty!).name} 1)',
                    style: const TextStyle(color: AppColors.text, fontSize: 12)),
              ),
            ]),
          ),
        ),
      if (changing) ...[
        const SizedBox(height: 8),
        _pickBox(it, SmithAction.change),
      ],
    ]);
  }

  Widget _pickBox(EquipItem it, SmithAction a) {
    final p = c.player;
    int has(Element e) => p.materialCount(EquipmentRules.imbueCore(e));
    // 코어가 있는 속성을 앞으로
    final options = [
      for (final e in Element.values)
        if (e != it.element && has(e) > 0) e,
      for (final e in Element.values)
        if (e != it.element && has(e) == 0) e,
    ];
    final more = _more.contains(it.uid);
    final shown = more ? options : options.take(5).toList();
    final picked = _picked[it.uid];
    final verb = a == SmithAction.apply ? '입히기' : '바꾸기';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LayoutBuilder(builder: (context, box) {
        final w = (box.maxWidth - 4 * 6) / 5;
        return Wrap(spacing: 6, runSpacing: 6, children: [
          for (final e in shown)
            _ElementCell(
              key: Key('pick_${a.name}_${it.uid}_${e.name}'),
              element: e,
              width: w,
              owned: has(e) > 0,
              selected: picked == e,
              onTap: () => setState(() => _picked[it.uid] = e),
            ),
        ]);
      }),
      if (options.length > 5)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: Key('pickMore_${it.uid}'),
            onPressed: () => setState(
                () => more ? _more.remove(it.uid) : _more.add(it.uid)),
            child: Text(more ? '접기' : '더 보기',
                style: const TextStyle(color: AppColors.goldBright)),
          ),
        )
      else
        const SizedBox(height: 6),
      GoldButton(
        key: Key('smith_${a.name}_${it.uid}'),
        label: '$verb · ${_smithCost(a, picked)}',
        height: 42,
        fontSize: 13.5,
        onPressed: picked != null && _canSmith(a, picked)
            ? () => _runSmith(it, a, to: picked)
            : null,
      ),
      if (picked != null && !_canSmith(a, picked))
        _Short(lines: _smithShort(a, picked)),
    ]);
  }
}
