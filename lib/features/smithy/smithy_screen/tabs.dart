part of '../smithy_screen.dart';

extension _SmithyTabs on _SmithyScreenState {
  AppController get c => widget.controller;

  void _snack(String text) => showTopNotice(context, text);

  /// 재료·마석이 다 있다 (가방이 가득 찬 것은 따로)
  bool _ready(EquipBaseInfo info) {
    final check = c.canCraft(info.id);
    return check == CraftCheck.ok || check == CraftCheck.bagFull;
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

  List<Widget> _repairTab() {
    final p = c.player;
    final damaged = [
      for (final w in c.armory.worn)
        if (c.masteryRepairCost(w) > 0) w,
    ];
    // 묶음 70 #302: 닳은 채집 도구도 함께 (재료가 모자란 도구는 빼고, 그 줄은 빨간색)
    final tools = c.featureOpen(Feature.harvest) && c.harvestToolsReady && c.harvest.granted
        ? [for (final t in HarvestTool.values) if (c.toolDurability(t) < c.toolMaxOf(t)) t]
        : const <HarvestTool>[];
    final toolsOk = [for (final t in tools) if (c.player.materialCount(HarvestRules.repairMaterial(t)) > 0) t];
    final toolsShort = [for (final t in tools) if (!toolsOk.contains(t)) t];
    final total = damaged.fold<int>(0, (s, w) => s + c.masteryRepairCost(w)) + toolsOk.length * HarvestRules.repairGold;
    final any = damaged.isNotEmpty || toolsOk.isNotEmpty;
    return [
      // 맨 위 금빛 칸: 입은 장비 모두 수리
      OrnatePanel(
        key: const Key('repairAllPanel'),
        // 묶음 71: 뒤에 남던 베이지색 강조 상자는 뺌
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KText(
                !any
                    ? '입은 장비가 모두 멀쩡해요 · 0이 되면 능력이 절반이에요'
                    : [
                        if (damaged.isNotEmpty) '입은 장비 ${damaged.length}개',
                        if (toolsOk.isNotEmpty) '채집 도구 ${toolsOk.length}개',
                      ].join(' · ') + '가 닳았어요 · 0이 되면 능력이 절반이에요',
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            GoldButton(
              key: const Key('repairAll'),
              label: !any ? '모두 멀쩡해요' : '모두 수리 · 금화 $total',
              height: 42,
              fontSize: 15,
              onPressed: any && p.gold >= total
                  ? () async {
                      var ok = true;
                      for (final w in damaged) {
                        ok = await c.repair(w.uid) && ok;
                      }
                      for (final t in toolsOk) {
                        ok = await c.repairTool(t) && ok;
                      }
                      if (mounted && ok) _snack('모두 고쳤어요!');
                    }
                  : null,
            ),
            if (any && p.gold < total)
              _Short(lines: [(_ic('gold'), '금화 ${total - p.gold}')]),
            for (final t in toolsShort)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    '${HarvestRules.toolName(t)} · ${josa(Materials.needName(HarvestRules.repairMaterial(t)), '이/가')} 없어 못 고쳐요',
                    key: Key('repairAllShort_${t.name}'),
                    style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
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
      // 묶음 70 #302: 채집 도구 다섯 가지 모두 여기서
      ToolRepairPanel(controller: c),
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

  /// 속성이 없는 장비: 속성 고르기 + 「입히기」
  Widget _applyBox(EquipItem it) => _pickBox(it, SmithAction.apply);
}
