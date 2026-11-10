import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/armory.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../town/material_view.dart';
import 'equipment_view.dart';

/// 마을 대장간 (11-10 #27): 장비 만들기 · 강화 · 수리 · 분해.
/// 장비는 대장간에서만 만든다.
class SmithyScreen extends StatefulWidget {
  const SmithyScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SmithyScreen> createState() => _SmithyScreenState();
}

class _SmithyScreenState extends State<SmithyScreen> {
  int _tab = 0;
  MaterialId? _rare;

  AppController get c => widget.controller;

  static const _tabs = ['만들기', '강화', '수리 · 분해'];

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final p = c.player;
            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                  title: '대장간',
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 6),
                BulssiLine(
                    line: switch (_tab) {
                  0 => '몬스터 재료로 장비를 만들 수 있어. 귀한 재료를 넣으면 좋은 등급이 잘 나와!',
                  1 => '강화는 실패해도 장비가 부서지지 않아. 마석과 금화만 써.',
                  _ => '닳은 장비는 고치고, 안 쓰는 장비는 분해해서 재료로 돌려받자.',
                }),
                const SizedBox(height: 8),
                Center(
                  child: Image.asset('assets/images/icon_smithy.png',
                      height: 90, errorBuilder: (_, __, ___) => const SizedBox()),
                ),
                const SizedBox(height: 8),
                OrnatePanel(
                  child: WalletRow(manaStones: p.manaStones, gold: p.gold),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  for (var i = 0; i < _tabs.length; i++) ...[
                    Expanded(
                      child: _TabButton(
                        label: _tabs[i],
                        selected: _tab == i,
                        onTap: () => setState(() => _tab = i),
                      ),
                    ),
                    if (i < _tabs.length - 1) const SizedBox(width: 6),
                  ],
                ]),
                const SizedBox(height: 12),
                ...switch (_tab) {
                  0 => _craftTab(),
                  1 => _enhanceTab(),
                  _ => _repairTab(),
                },
              ],
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────── 만들기

  List<Widget> _craftTab() {
    final p = c.player;
    final rares = [
      for (final m in Materials.rares)
        if (p.materialCount(m) > 0) m,
    ];
    if (_rare != null && !rares.contains(_rare)) _rare = null;
    final chances =
        EquipmentRules.gradeChances(rare: _rare != null, crafts: c.armory.crafts);
    String fmt(double v) =>
        v == v.roundToDouble() ? v.round().toString() : v.toString();
    return [
      OrnatePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('귀한 재료 넣기', style: AppText.title(16)),
            const SizedBox(height: 4),
            if (rares.isEmpty)
              const Text('귀한 재료가 없어요. 몬스터가 가끔 떨어뜨려요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12))
            else
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in rares)
                  ChoiceChip(
                    label: Text(
                        '${Materials.info(m).name} ${p.materialCount(m)}'),
                    avatar: MaterialIcon(m, size: 20),
                    selected: _rare == m,
                    onSelected: (on) => setState(() => _rare = on ? m : null),
                  ),
              ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 2, children: [
              for (var i = 0; i < EquipGrade.values.length; i++)
                Text(
                    '${EquipmentRules.gradeLabel(EquipGrade.values[i])} '
                    '${fmt(chances[i])}%',
                    style: TextStyle(
                        color: equipGradeColor(EquipGrade.values[i]),
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 2),
            Text(
                '만든 장비 ${c.armory.crafts}개 · 숙련도 파랑 +'
                '${EquipmentRules.masteryBonus(c.armory.crafts)}%p '
                '(10개마다 +1%p)',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      for (final info in EquipmentRules.all) ...[
        _RecipeCard(
          info: info,
          controller: c,
          rare: _rare,
          onCraft: () async {
            final item = await c.craft(info.id, rare: _rare);
            if (!mounted || item == null) return;
            await _showMade(item);
          },
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Future<void> _showMade(EquipItem item) => showDialog<void>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: AppColors.night,
          title: Text('${EquipmentRules.gradeLabel(item.grade)} 등급!',
              textAlign: TextAlign.center,
              style: AppText.title(22, color: equipGradeColor(item.grade))),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            EquipIcon(base: item.base, grade: item.grade, size: 96),
            const SizedBox(height: 10),
            EquipName(item, size: 18),
            const SizedBox(height: 4),
            Text(EquipmentRules.itemStatLabel(item),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
            const SizedBox(height: 6),
            const Text('가방에서 입을 수 있어요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ]),
          actions: [
            TextButton(
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

  // ───────────────────────── 강화

  List<Widget> _enhanceTab() {
    final items = c.armory.items;
    if (items.isEmpty) return [const _Empty('강화할 장비가 없어요. 먼저 만들어 보세요.')];
    return [
      for (final item in items) ...[
        _ItemCard(
          item: item,
          worn: c.armory.isWorn(item),
          bottom: _enhanceRow(item),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  Widget _enhanceRow(EquipItem item) {
    final check = c.canEnhance(item);
    if (check == CraftCheck.maxed) {
      return Text('+${EquipmentRules.maxEnhance} 최고 단계예요',
          style: AppText.title(14, color: AppColors.goldBright));
    }
    final to = item.enhance + 1;
    final cost = EquipmentRules.enhanceCost(to);
    final chance = (EquipmentRules.enhanceChance(to) * 100).round();
    return Row(children: [
      Expanded(
        child: Text(
            '+${item.enhance} → +$to · 성공 $chance%\n'
            '마석 ${cost.manaStones} · 금화 ${cost.gold}',
            style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
      ),
      SizedBox(
        width: 96,
        child: GoldButton(
          label: '강화',
          height: 40,
          fontSize: 15,
          onPressed: check == CraftCheck.ok
              ? () async {
                  final ok = await c.enhance(item.uid);
                  if (!mounted || ok == null) return;
                  _snack(ok
                      ? '강화 성공! ${item.info.name} +$to'
                      : '강화 실패… 장비는 그대로예요.');
                }
              : null,
        ),
      ),
    ]);
  }

  // ───────────────────────── 수리 · 분해

  List<Widget> _repairTab() {
    final items = c.armory.items;
    if (items.isEmpty) return [const _Empty('가진 장비가 없어요.')];
    return [
      const Text('필드 전투 한 번에 입은 장비 내구도 -1, 던전 한 번에 -2. 0이 되면 능력이 절반이에요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
      const SizedBox(height: 8),
      for (final item in items) ...[
        _ItemCard(
          item: item,
          worn: c.armory.isWorn(item),
          showDurability: true,
          bottom: Row(children: [
            TextButton(
              onPressed: () => _confirmSalvage(item),
              child: const Text('분해',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            const Spacer(),
            SizedBox(
              width: 150,
              child: GoldButton(
                label: EquipmentRules.repairCost(item) == 0
                    ? '멀쩡해요'
                    : '수리 · 금화 ${EquipmentRules.repairCost(item)}',
                height: 40,
                fontSize: 14,
                onPressed: EquipmentRules.repairCost(item) > 0 &&
                        c.player.gold >= EquipmentRules.repairCost(item)
                    ? () async {
                        if (await c.repair(item.uid)) _snack('다 고쳤어요!');
                      }
                    : null,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
      ],
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
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.night,
        title: Text('${item.name}을(를) 분해할까요?',
            style: AppText.title(18, color: AppColors.text)),
        content: Text('돌려받는 것: $list\n분해한 장비는 되돌릴 수 없어요.',
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
}

class _TabButton extends StatelessWidget {
  const _TabButton(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? kGoldGradient : null,
            color: selected ? null : const Color(0xAA12153A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? const Color(0xFF3A2208) : AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 14)),
        ),
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

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.info,
    required this.controller,
    required this.rare,
    required this.onCraft,
  });

  final EquipBaseInfo info;
  final AppController controller;
  final MaterialId? rare;
  final VoidCallback onCraft;

  @override
  Widget build(BuildContext context) {
    final p = controller.player;
    final check = controller.canCraft(info.id, rare: rare);
    Widget need(Widget icon, String name, int have, int n) => Container(
          padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0x66101333),
            border: Border.all(
                color: have >= n
                    ? const Color(0x997BE08A)
                    : const Color(0x99E57373)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(width: 3),
            Text('$name $have/$n',
                style: TextStyle(
                    color: have >= n ? AppColors.text : const Color(0xFFE5A0A0),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ]),
        );
    return OrnatePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            EquipIcon(base: info.id, size: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.name, style: AppText.title(17, color: AppColors.text)),
                  Text(
                      '${EquipmentRules.slotLabel(info.slot)} · ${info.statLabel}'
                      '${info.job == null ? '' : ' · 어울리는 직업 ${info.job}'}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in info.recipe.entries)
              need(MaterialIcon(e.key, size: 18), Materials.info(e.key).name,
                  p.materialCount(e.key), e.value),
            if (info.manaStones > 0)
              need(
                  const GameIcon('mana_stone',
                      size: 18, fallback: Icons.diamond_rounded),
                  '마석',
                  p.manaStones,
                  info.manaStones),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 120,
              child: GoldButton(
                label: '만들기',
                height: 40,
                fontSize: 15,
                onPressed: check == CraftCheck.ok ? onCraft : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 가진 장비 카드 (강화·수리 탭)
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.worn,
    required this.bottom,
    this.showDurability = false,
  });

  final EquipItem item;
  final bool worn;
  final Widget bottom;
  final bool showDurability;

  @override
  Widget build(BuildContext context) => OrnatePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
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
                                color: AppColors.goldBright, fontSize: 11)),
                      ],
                    ]),
                    Text(EquipmentRules.itemStatLabel(item),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
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
}
