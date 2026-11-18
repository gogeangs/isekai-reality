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

  AppController get c => widget.controller;

  static const tabs = ['만들기', '강화', '수리', '속성', '재료 가공', '보스 장비'];

  void _snack(String text) => showTopNotice(context, text);

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

  /// 재료·마석이 다 있다 (가방이 가득 찬 것은 따로)
  bool _ready(EquipBaseInfo info) {
    final check = c.canCraft(info.id);
    return check == CraftCheck.ok || check == CraftCheck.bagFull;
  }

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

  /// 만들기 확인 창 (#221 시안 ②)
  Future<void> _craftSheet(EquipBaseInfo info) async {
    final p = c.player;
    final rares = [
      for (final m in Materials.rares)
        if (p.materialCount(m) >= (info.recipe[m] ?? 0) + 1) m,
    ];
    MaterialId? rare;
    final go = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: StatefulBuilder(builder: (sheet, setSheet) {
          // 묶음 26 #174: 등급 확률은 숨긴다. 나올 수 있는 등급 색 점만
          final chances = EquipmentRules.gradeChances(
              rare: rare != null, crafts: c.armory.crafts);
          return SingleChildScrollView(
            key: const Key('craftSheet'),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  EquipIcon(base: info.id, size: 60),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.name,
                            style: AppText.title(18, color: AppColors.text)),
                        KText(
                            '${EquipmentRules.slotLabel(info.slot)} · ${info.statLabel}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                const Text('드는 재료',
                    style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                _NeedWrap(info: info, controller: c, rare: rare),
                if (rares.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('귀한 재료 넣기', style: AppText.title(15)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    ChoiceChip(
                      key: const Key('rare_none'),
                      label: const Text('넣지 않기'),
                      selected: rare == null,
                      onSelected: (_) => setSheet(() => rare = null),
                    ),
                    for (final m in rares)
                      ChoiceChip(
                        key: Key('rare_${m.name}'),
                        label: Text(
                            '${Materials.info(m).name} ${p.materialCount(m)}'),
                        avatar: MaterialIcon(m, size: 20),
                        selected: rare == m,
                        onSelected: (on) =>
                            setSheet(() => rare = on ? m : null),
                      ),
                  ]),
                ],
                const SizedBox(height: 12),
                Row(key: const Key('gradeDots'), children: [
                  const Text('나올 수 있는 등급',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(width: 8),
                  for (var i = 0; i < EquipGrade.values.length; i++)
                    if (chances[i] > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Tooltip(
                          message:
                              EquipmentRules.gradeLabel(EquipGrade.values[i]),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: equipGradeColor(EquipGrade.values[i]),
                              border: Border.all(
                                  color: const Color(0x66000000), width: 1),
                            ),
                          ),
                        ),
                      ),
                ]),
                if (rare != null) ...[
                  const SizedBox(height: 4),
                  const KText('좋은 등급이 나오기 쉬워져요',
                      key: Key('rareHint'),
                      style: TextStyle(
                          color: AppColors.goldBright,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('craftCancel'),
                      onPressed: () => Navigator.of(sheet).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: BorderSide(
                            color: AppColors.gold.withValues(alpha: 0.7)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('그만두기',
                          style: TextStyle(color: AppColors.text)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GoldButton(
                      key: const Key('craftConfirm'),
                      label: '만들기',
                      height: 46,
                      fontSize: 16,
                      onPressed: c.canCraft(info.id, rare: rare) ==
                              CraftCheck.ok
                          ? () => Navigator.of(sheet).pop(true)
                          : null,
                    ),
                  ),
                ]),
              ],
            ),
          );
        }),
      ),
    );
    if (go != true || !mounted) return;
    final item = await c.craft(info.id, rare: rare);
    if (!mounted || item == null) return;
    await _showMade(item);
  }

  Future<void> _showMade(EquipItem item) => showDialog<void>(
        context: context,
        builder: (d) => GameAlert(
          title: KText('${EquipmentRules.gradeLabel(item.grade)} 등급!',
              textAlign: TextAlign.center,
              style: AppText.title(22, color: equipGradeColor(item.grade))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            EquipIcon(base: item.base, grade: item.grade, size: 96),
            const SizedBox(height: 10),
            EquipName(item, size: 18),
            const SizedBox(height: 4),
            ItemStats(item, fontSize: 14),
            const SizedBox(height: 6),
            const KText('가방에서 입을 수 있어요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          actions: [
            TextButton(
              key: const Key('equipNow'),
              onPressed: () async {
                await c.equip(item.uid);
                if (d.mounted) Navigator.of(d).pop();
              },
              child: const Text('바로 입기'),
            ),
            TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('닫기'),
            ),
          ],
        ),
      );

  /// 입는 중 · 가방 두 묶음 (#222)
  List<Widget> _grouped(Widget Function(EquipItem item, bool worn) card) {
    final items = c.armory.items;
    final worn = [
      for (final s in EquipSlot.values)
        if (c.armory.wornIn(s) case final w?) w,
    ];
    final bag = [for (final i in items) if (!c.armory.isWorn(i)) i];
    return [
      if (worn.isNotEmpty) ...[
        const _GroupLabel('입는 중', key: Key('group_worn')),
        for (final i in worn) ...[card(i, true), const SizedBox(height: 10)],
      ],
      if (bag.isNotEmpty) ...[
        const _GroupLabel('가방', key: Key('group_bag')),
        for (final i in bag) ...[card(i, false), const SizedBox(height: 10)],
      ],
    ];
  }

  // ───────────────────────── 강화 (#222)

  List<Widget> _enhanceTab() {
    if (c.armory.items.isEmpty) {
      return [const _Empty('강화할 장비가 없어요. 먼저 만들어 보세요.')];
    }
    return _grouped((item, worn) => _ItemCard(
          key: Key('enhanceCard_${item.uid}'),
          item: item,
          worn: worn,
          bottom: _enhanceRow(item),
        ));
  }

  Widget _enhanceRow(EquipItem item) {
    final check = c.canEnhance(item);
    if (check == CraftCheck.maxed) {
      return KText('+${EquipmentRules.maxEnhance} 최고 단계예요',
          style: AppText.title(14, color: AppColors.goldBright));
    }
    final to = item.enhance + 1;
    final cost = EquipmentRules.enhanceCost(to);
    final chance = (c.enhanceChanceShown(to) * 100).round();
    final p = c.player;
    // 묶음 66: +8부터 영지 특산물
    final sp = EquipmentRules.enhanceSpecial(item.slot, to);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: KText(
              '+${item.enhance} → +$to · 성공 $chance%\n'
              '마석 ${cost.manaStones} · 금화 ${cost.gold}',
              style: const TextStyle(color: AppColors.text, fontSize: 12)),
        ),
        SizedBox(
          width: 96,
          child: GoldButton(
            key: Key('enhance_${item.uid}'),
            label: '강화',
            height: 40,
            fontSize: 14,
            onPressed: check == CraftCheck.ok
                ? () async {
                    final ok = await c.enhance(item.uid);
                    if (!mounted || ok == null) return;
                    _snack(ok
                        ? '강화 성공! ${item.info.name} +$to'
                        : c.lastEnhanceSafe
                            ? '강화 실패… 그래도 무사해요! 쓴 마석과 금화를 돌려받았어요.'
                            : '강화 실패… 장비는 그대로예요.');
                  }
                : null,
          ),
        ),
      ]),
      if (sp != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(key: Key('enhanceSpecial_${item.uid}'), children: [
            Image.asset(Materials.info(sp.mat).asset, width: 22, height: 22, errorBuilder: (_, __, ___) => const SizedBox(width: 22)),
            const SizedBox(width: 4),
            Text('${Materials.info(sp.mat).name} ${p.materialCount(sp.mat)}/${sp.n}',
                style: TextStyle(
                    color: p.materialCount(sp.mat) >= sp.n ? AppColors.text : const Color(0xFFFF8A65),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      if (check != CraftCheck.ok)
        _Short(
          key: Key('short_${item.uid}'),
          lines: [
            if (p.manaStones < cost.manaStones)
              (_ic('mana_stone'), '마석 ${cost.manaStones - p.manaStones}개'),
            if (p.gold < cost.gold) (_ic('gold'), '금화 ${cost.gold - p.gold}'),
            if (sp != null && p.materialCount(sp.mat) < sp.n)
              (Image.asset(Materials.info(sp.mat).asset, width: 18, height: 18), '${Materials.info(sp.mat).name} ${sp.n - p.materialCount(sp.mat)}개'),
          ],
        ),
      // 묶음 42 #226: 도르군의 숫돌 → 이번 강화는 꼭 성공 (마석·금화는 그대로 듦)
      if (check == CraftCheck.ok && c.whetstones > 0) ...[
        const SizedBox(height: 6),
        FrameButton(
          key: Key('whetstone_${item.uid}'),
          label: '도르군의 숫돌로 강화 · 꼭 성공 (${c.whetstones}개)',
          height: 38,
          onPressed: () async {
            final ok = await c.enhance(item.uid, whetstone: true);
            if (!mounted || ok == null) return;
            _snack('숫돌이 반짝! 강화 성공! ${item.info.name} +$to');
          },
        ),
      ],
    ]);
  }

  // ───────────────────────── 수리 (#222)

  List<Widget> _repairTab() {
    final p = c.player;
    final damaged = [
      for (final w in c.armory.worn)
        if (c.masteryRepairCost(w) > 0) w,
    ];
    final total =
        damaged.fold<int>(0, (s, w) => s + c.masteryRepairCost(w));
    return [
      // 맨 위 금빛 칸: 입은 장비 모두 수리
      OrnatePanel(
        key: const Key('repairAllPanel'),
        highlight: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KText(
                damaged.isEmpty
                    ? '입은 장비가 모두 멀쩡해요 · 0이 되면 능력이 절반이에요'
                    : '입은 장비 ${damaged.length}개가 닳았어요 · 0이 되면 능력이 절반이에요',
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            GoldButton(
              key: const Key('repairAll'),
              label: damaged.isEmpty ? '모두 멀쩡해요' : '모두 수리 · 금화 $total',
              height: 42,
              fontSize: 15,
              onPressed: damaged.isNotEmpty && p.gold >= total
                  ? () async {
                      var ok = true;
                      for (final w in damaged) {
                        ok = await c.repair(w.uid) && ok;
                      }
                      if (mounted && ok) _snack('입은 장비를 모두 고쳤어요!');
                    }
                  : null,
            ),
            if (damaged.isNotEmpty && p.gold < total)
              _Short(lines: [(_ic('gold'), '금화 ${total - p.gold}')]),
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (c.armory.items.isEmpty)
        const _Empty('가진 장비가 없어요.')
      else
        ..._grouped((item, worn) {
          final cost = c.masteryRepairCost(item);
          return _ItemCard(
            key: Key('repairCard_${item.uid}'),
            item: item,
            worn: worn,
            showDurability: true,
            menu: _SalvageMenu(
              uid: item.uid,
              worn: worn,
              onSalvage: () => _confirmSalvage(item),
            ),
            bottom: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: 160,
                      child: GoldButton(
                        key: Key('repair_${item.uid}'),
                        label: cost == 0 ? '멀쩡해요' : '수리 · 금화 $cost',
                        height: 40,
                        fontSize: 14,
                        onPressed: cost > 0 && p.gold >= cost
                            ? () async {
                                if (await c.repair(item.uid)) {
                                  _snack('다 고쳤어요!');
                                }
                              }
                            : null,
                      ),
                    ),
                  ),
                  if (cost > 0 && p.gold < cost)
                    _Short(lines: [(_ic('gold'), '금화 ${cost - p.gold}')]),
                ]),
          );
        }),
      const SizedBox(height: 6),
      ToolRepairPanel(controller: c, smithy: true),
    ];
  }

  Future<void> _confirmSalvage(EquipItem item) async {
    final back = EquipmentRules.salvage(item);
    final list = [
      '마석 ${back.manaStones}',
      for (final e in back.materials.entries)
        '${Materials.info(e.key).name} ${e.value}',
    ].join(', ');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text('${josa(item.name, '을/를')} 분해할까요?',
            style: AppText.title(19, color: AppColors.text)),
        content: KText('돌려받는 것: $list\n분해한 장비는 되돌릴 수 없어요.',
            style: const TextStyle(color: AppColors.text)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('그만두기')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('분해하기')),
        ],
      ),
    );
    if (ok != true) return;
    await c.disassemble(item.uid);
    if (mounted) _snack('분해했어요. $list');
  }

  // ───────────────────────── 속성 (#223)

  /// 장비 속성 (11-11 #74): 입히기 · 바꾸기 · 추출 · 강화.
  /// 실패 확률과 강화 배율은 숨기고, 강화 단계는 아이콘 빛으로만 보여 준다.
  List<Widget> _elementTab() {
    return [
      const KText('무기는 그 속성으로 공격해요. 방어구·장신구는 그 속성 몬스터에게 덜 다쳐요.',
          key: Key('elementIntro'),
          style: TextStyle(color: AppColors.text, fontSize: 13)),
      const SizedBox(height: 2),
      const KText('도르군의 망치질은 가끔 빗나가요. 그때는 금화만 들고, 코어는 돌려받아요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      const SizedBox(height: 8),
      if (c.armory.items.isEmpty)
        const _Empty('가진 장비가 없어요.')
      else
        ..._grouped((item, worn) => _ItemCard(
              key: Key('elementCard_${item.uid}'),
              item: item,
              worn: worn,
              trailing: item.element == null
                  ? null
                  : ElementIcon(item.element,
                      key: Key('elementOf_${item.uid}'),
                      size: 30,
                      level: item.elementLevel),
              bottom: item.element == null
                  ? _applyBox(item)
                  : _elementButtons(item),
            )),
      const SizedBox(height: 6),
      const LockedJobPanel(
        title: '대장장이',
        lines: ['속성 작업이 더 싸고 잘 돼요', '속성 강화의 힘이 더 커요'],
      ),
    ];
  }

  bool _canSmith(SmithAction a, Element? e) =>
      c.player.gold >= SmithRules.gold(a) &&
      (SmithRules.cores(a) == 0 ||
          (e != null &&
              c.player.materialCount(EquipmentRules.imbueCore(e)) >=
                  SmithRules.cores(a)));

  /// 모자란 것 한 줄 (금화 · 빛나는 코어)
  List<(Widget, String)> _smithShort(SmithAction a, Element? e) {
    final p = c.player;
    final gold = SmithRules.gold(a);
    final cores = SmithRules.cores(a);
    final have = e == null ? 0 : p.materialCount(EquipmentRules.imbueCore(e));
    return [
      if (cores > 0 && e != null && have < cores)
        (
          MaterialIcon(EquipmentRules.imbueCore(e), size: 16),
          '${Materials.info(EquipmentRules.imbueCore(e)).name} ${cores - have}개'
        ),
      if (p.gold < gold) (_ic('gold'), '금화 ${gold - p.gold}'),
    ];
  }

  String _smithCost(SmithAction a, Element? e) => [
        '금화 ${SmithRules.gold(a)}',
        if (SmithRules.cores(a) > 0)
          e == null
              ? '빛나는 속성 코어 ${SmithRules.cores(a)}'
              : '${Materials.info(EquipmentRules.imbueCore(e)).name} ${SmithRules.cores(a)}',
      ].join(' + ');

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

  /// 속성이 없는 장비: 속성 고르기 + 「입히기」
  Widget _applyBox(EquipItem it) => _pickBox(it, SmithAction.apply);

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

Widget _ic(String name) => GameIcon(name,
    size: 16,
    fallback: name == 'gold'
        ? Icons.monetization_on_rounded
        : Icons.diamond_rounded);

/// 탭 바로 위 오른쪽 작은 한 줄 (마석 · 금화)
class _WalletLine extends StatelessWidget {
  const _WalletLine({required this.manaStones, required this.gold});

  final int manaStones;
  final int gold;

  @override
  Widget build(BuildContext context) {
    Widget one(String icon, IconData fb, int n, Key key) => Row(
          key: key,
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(icon, size: 18, fallback: fb),
            const SizedBox(width: 3),
            Text(comma(n),
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        );
    return Row(
      key: const Key('smithyWallet'),
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        one('mana_stone', Icons.diamond_rounded, manaStones,
            const Key('wallet_mana')),
        const SizedBox(width: 12),
        one('gold', Icons.monetization_on_rounded, gold,
            const Key('wallet_gold')),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? kGoldGradient : null,
            color: selected ? null : const Color(0xAA12153A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label,
                maxLines: 1,
                style: TextStyle(
                    color: selected ? AppColors.goldInk : AppColors.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
        ),
      );
}

class _SlotChip extends StatelessWidget {
  const _SlotChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0x55F2C14E) : const Color(0x8812153A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected
                    ? AppColors.goldBright
                    : AppColors.gold.withValues(alpha: 0.45)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppColors.goldBright : AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 0, 6),
        child: Text(text,
            style: AppText.title(15, color: AppColors.goldBright)),
      );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => OrnatePanel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted)),
        ),
      );
}

/// 모자란 것 한 줄: 아이콘 + 「마석 1개 모자라요」
class _Short extends StatelessWidget {
  const _Short({super.key, required this.lines});

  /// (아이콘, 「마석 1개」)
  final List<(Widget, String)> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        SizedBox(width: 16, height: 16, child: lines.first.$1),
        const SizedBox(width: 4),
        Expanded(
          child: KText('${lines.map((l) => l.$2).join(' · ')} 모자라요',
              style: const TextStyle(
                  color: Color(0xFFE5A0A0),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// 드는 재료 칸 (모자란 칸은 빨갛게)
class _NeedWrap extends StatelessWidget {
  const _NeedWrap({required this.info, required this.controller, this.rare});

  final EquipBaseInfo info;
  final AppController controller;
  final MaterialId? rare;

  @override
  Widget build(BuildContext context) {
    final p = controller.player;
    Widget need(Widget icon, String name, int have, int n) => Container(
          padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: have >= n ? const Color(0x66101333) : const Color(0x55E57373),
            border: Border.all(
                color: have >= n
                    ? const Color(0x997BE08A)
                    : const Color(0xFFE57373)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(width: 3),
            Text('$name $have/$n',
                style: TextStyle(
                    color: have >= n ? AppColors.text : const Color(0xFFFFB4B4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        );
    final recipe = {...info.recipe};
    if (rare != null) recipe[rare!] = (recipe[rare!] ?? 0) + 1;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final e in recipe.entries)
        need(MaterialIcon(e.key, size: 18), Materials.needName(e.key),
            p.materialCount(e.key), e.value),
      if (info.manaStones > 0)
        need(
            const GameIcon('mana_stone',
                size: 18, fallback: Icons.diamond_rounded),
            '마석',
            p.manaStones,
            info.manaStones),
    ]);
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.info,
    required this.controller,
    required this.ready,
    required this.onCraft,
  });

  final EquipBaseInfo info;
  final AppController controller;
  final bool ready;
  final VoidCallback onCraft;

  /// 모자란 재료 한 줄 「박쥐 날개 1개 모자라요」
  String _missing() {
    final p = controller.player;
    final parts = [
      for (final e in info.recipe.entries)
        if (p.materialCount(e.key) < e.value)
          '${Materials.needName(e.key)} ${e.value - p.materialCount(e.key)}개',
      if (p.manaStones < info.manaStones)
        '마석 ${info.manaStones - p.manaStones}개',
    ];
    return '${parts.join(' · ')} 모자라요';
  }

  @override
  Widget build(BuildContext context) {
    final check = controller.canCraft(info.id);
    final worn = controller.armory.wornIn(info.slot);
    const up = Color(0xFF7BE08A);
    Widget compare;
    if (!ready) {
      compare = KText(_missing(),
          key: Key('missing_${info.id.name}'),
          style: const TextStyle(
              color: Color(0xFFFFB4B4),
              fontSize: 12.5,
              fontWeight: FontWeight.w700));
    } else if (worn == null) {
      compare = const Text('새 부위',
          style: TextStyle(
              color: Color(0xFF7FB8FF),
              fontSize: 12.5,
              fontWeight: FontWeight.w800));
    } else {
      final lines = EquipmentRules.compareWith(info.id, worn);
      compare = lines.isEmpty
          ? const Text('지금 입은 것과 같아요',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5))
          : Wrap(spacing: 10, runSpacing: 2, children: [
              for (final (good, text) in lines)
                Text('${good ? '▲' : '▼'} $text',
                    style: TextStyle(
                        color: good ? up : AppColors.danger,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800)),
            ]);
    }
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          EquipIcon(base: info.id, size: 52),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(info.name,
                          style: AppText.title(16, color: AppColors.text)),
                      if (ready)
                        Container(
                          key: Key('canMake_${info.id.name}'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0x337BE08A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0x997BE08A)),
                          ),
                          child: const Text('만들 수 있어요',
                              style: TextStyle(
                                  color: up,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                    ]),
                Text(
                    // 묶음 26 #178: 어울리는 직업은 직업이 생긴 뒤에 (지금은 숨김)
                    '${EquipmentRules.slotLabel(info.slot)} · ${info.statLabel}'
                    '${info.job == null || !LockedJobPanel.jobsVisible ? '' : ' · 어울리는 직업 ${info.job}'}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 6),
        compare,
        const SizedBox(height: 8),
        _NeedWrap(info: info, controller: controller),
        const SizedBox(height: 8),
        Row(children: [
          if (check == CraftCheck.bagFull)
            const Expanded(
              child: KText('가방이 가득 찼어요. 가방을 비우거나 늘려 주세요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            )
          else
            const Spacer(),
          SizedBox(
            width: 120,
            child: GoldButton(
              key: Key('craft_${info.id.name}'),
              label: '만들기',
              height: 40,
              fontSize: 14,
              onPressed: check == CraftCheck.ok ? onCraft : null,
            ),
          ),
        ]),
      ],
    );
    return OrnatePanel(
      key: Key('recipe_${info.id.name}'),
      child: ready ? body : Opacity(opacity: 0.72, child: body),
    );
  }
}

/// 가진 장비 카드 (강화·수리·속성 탭). 입는 중이면 금테를 굵게
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.item,
    required this.worn,
    required this.bottom,
    this.showDurability = false,
    this.menu,
    this.trailing,
  });

  final EquipItem item;
  final bool worn;
  final Widget bottom;
  final bool showDurability;
  final Widget? menu;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final card = OrnatePanel(
      highlight: worn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            EquipIcon(base: item.base, grade: item.grade, size: 48),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: EquipName(item, size: 16)),
                    if (worn) ...[
                      const SizedBox(width: 6),
                      const Text('입는 중',
                          style: TextStyle(
                              color: AppColors.goldBright, fontSize: 12)),
                    ],
                  ]),
                  ItemStats(item, fontSize: 12),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
            if (menu != null) menu!,
          ]),
          if (showDurability) ...[
            const SizedBox(height: 6),
            DurabilityBar(value: item.durability),
          ],
          const SizedBox(height: 6),
          bottom,
        ],
      ),
    );
    if (!worn) return card;
    // 입는 중: 금테를 굵게
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.goldBright, width: 2.4),
        boxShadow: const [
          BoxShadow(color: Color(0x55F2C14E), blurRadius: 8),
        ],
      ),
      child: card,
    );
  }
}

/// 카드 오른쪽 위 ⋯ : 「분해하기」
class _SalvageMenu extends StatelessWidget {
  const _SalvageMenu(
      {required this.uid, required this.worn, required this.onSalvage});

  final String uid;
  final bool worn;
  final VoidCallback onSalvage;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 32,
        height: 32,
        child: PopupMenuButton<int>(
          key: Key('more_$uid'),
          padding: EdgeInsets.zero,
          color: AppColors.night,
          icon: const Icon(Icons.more_horiz_rounded,
              color: AppColors.goldBright),
          onSelected: (_) => onSalvage(),
          itemBuilder: (_) => [
            PopupMenuItem<int>(
              key: Key('salvage_$uid'),
              value: 0,
              enabled: !worn,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('분해하기',
                      style: TextStyle(
                          color: worn
                              ? AppColors.textMuted
                              : AppColors.danger,
                          fontWeight: FontWeight.w800)),
                  Text(
                      worn ? '입는 중이에요' : '마석과 재료 일부를 돌려받아요',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 속성 탭 버튼 (금빛 · 보통). 비용은 작게
class _CostButton extends StatelessWidget {
  const _CostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.cost,
    this.gold = false,
  });

  final String label;
  final String? cost;
  final bool gold;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final on = onPressed != null;
    final ink = gold && on ? AppColors.goldInk : AppColors.text;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: on ? 1 : 0.5,
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            gradient: gold && on ? kGoldGradient : null,
            color: gold && on ? null : const Color(0xAA12153A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            KText(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
            if (cost != null)
              KText(cost!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: ink.withValues(alpha: 0.8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// 속성 고르기 한 칸 (코어가 있는 속성만 밝게)
class _ElementCell extends StatelessWidget {
  const _ElementCell({
    super.key,
    required this.element,
    required this.width,
    required this.owned,
    required this.selected,
    required this.onTap,
  });

  final Element element;
  final double width;
  final bool owned;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: owned ? 1 : 0.4,
          child: Container(
            width: width,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? const Color(0x55F2C14E) : const Color(0x6612153A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected
                      ? AppColors.goldBright
                      : AppColors.gold.withValues(alpha: 0.35),
                  width: selected ? 2 : 1),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ElementIcon(element, size: 24),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(element.label,
                    maxLines: 1,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
}

/// 첫 채집 도구 (Lv.5, 무료)
class _FirstToolPanel extends StatelessWidget {
  const _FirstToolPanel({required this.onMake});

  final VoidCallback onMake;

  @override
  Widget build(BuildContext context) => OrnatePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('첫 채집 도구', style: AppText.title(17)),
            const SizedBox(height: 4),
            const KText('낫·곡괭이·도끼·낚싯대·붓을 한 벌 만들어요. 처음 한 번은 무료예요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 10),
            GoldButton(
              key: const Key('firstToolMake'),
              label: '만들기 (무료)',
              height: 46,
              fontSize: 16,
              onPressed: onMake,
            ),
          ],
        ),
      );
}
