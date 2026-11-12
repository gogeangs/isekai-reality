import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../alchemy/convert_panel.dart' show LockedJobPanel;
import '../battle/element_view.dart';
import '../town/material_view.dart';
import 'equipment_view.dart';

/// 대장간 「보스 장비」 탭 (11-11 #82): 세트마다 만든 부위 / 못 만든 부위.
/// 아직 못 잡은 보스의 세트는 그림자로 숨긴다.
class BossGearTab extends StatelessWidget {
  const BossGearTab({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.player;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrnatePanel(
          child: Row(children: [
            const MaterialIcon(MaterialId.bossShard, size: 30),
            const SizedBox(width: 8),
            Expanded(
              child: KText(
                  '보스 장비 조각 ${p.materialCount(MaterialId.bossShard)}개 · '
                  '던전 보스가 가끔 떨어뜨려요',
                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        for (final s in BossGearRules.sets) ...[
          c.bossSetOpen(s.id)
              ? _SetCard(controller: c, set: s)
              : _HiddenSet(set: s),
          const SizedBox(height: 10),
        ],
        const LockedJobPanel(
          title: '대장장이',
          lines: ['보스 장비가 덜 실패해요', '금화가 덜 들어요'],
        ),
      ],
    );
  }
}

class _HiddenSet extends StatelessWidget {
  const _HiddenSet({required this.set});

  final BossSetInfo set;

  @override
  Widget build(BuildContext context) => OrnatePanel(
        key: Key('bossSetHidden_${set.id.name}'),
        child: Row(children: [
          const Icon(Icons.lock_rounded, color: AppColors.textMuted, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('??? 세트', style: AppText.title(16, color: AppColors.textMuted)),
                const KText('아직 만나지 못한 보스의 장비예요.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.abyss,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF2C3360)),
                    ),
                  ),
                ),
            ],
          ),
        ]),
      );
}

class _SetCard extends StatelessWidget {
  const _SetCard({required this.controller, required this.set});

  final AppController controller;
  final BossSetInfo set;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final made = set.parts.where((x) => c.hasBossPart(x.$1)).length;
    final color = Color(set.aura);
    return OrnatePanel(
      key: Key('bossSet_${set.id.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            ElementIcon(set.element, size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(set.name, style: AppText.title(19, color: color)),
            ),
            Text('$made / 6',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          _Effects(set: set),
          const SizedBox(height: 8),
          for (final part in set.parts)
            _PartRow(controller: c, set: set, base: part.$1),
        ],
      ),
    );
  }
}

class _Effects extends StatelessWidget {
  const _Effects({required this.set});

  final BossSetInfo set;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4);
    final el = set.element.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KText('2개 · $el 속성 공격에 강해져요', style: style),
        KText('4개 · $el 속성 공격이 세져요', style: style),
        KText('6개 · ${set.abilityName}: ${set.abilityText} · 「${set.look}」 모습',
            style: style),
      ],
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.controller, required this.set, required this.base});

  final AppController controller;
  final BossSetInfo set;
  final EquipBase base;

  Future<void> _craft(BuildContext context) async {
    final r = await controller.craftBoss(base);
    if (r == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (d) => GameAlert(
        title: KText(
            r.ok
                ? '${EquipmentRules.gradeLabel(r.item!.grade)} 등급!'
                : '만들지 못했어요',
            textAlign: TextAlign.center,
            style: AppText.title(19,
                color: r.ok ? equipGradeColor(r.item!.grade) : AppColors.text)),
        content: r.ok
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                EquipIcon(base: base, grade: r.item!.grade, size: 88),
                const SizedBox(height: 8),
                EquipName(r.item!, size: 17),
                const SizedBox(height: 4),
                ItemStats(r.item!, fontSize: 14),
              ])
            : KText(r.line ?? '', style: const TextStyle(color: AppColors.text)),
        actions: [
          if (r.ok)
            TextButton(
              onPressed: () async {
                await controller.equip(r.item!.uid);
                if (d.mounted) Navigator.of(d).pop();
              },
              child: const Text('바로 입기'),
            ),
          TextButton(
              onPressed: () => Navigator.of(d).pop(), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.player;
    final info = EquipmentRules.info(base);
    final has = c.hasBossPart(base);
    final cost = BossGearRules.cost(info.slot, blacksmith: c.blacksmith);
    final check = c.canCraftBoss(base);
    String need(int have, int want) => '$have/$want';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Opacity(
          opacity: has ? 1 : 0.45,
          child: EquipIcon(base: base, size: 42),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Flexible(
                  child: Text(info.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: has ? AppColors.text : AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
                if (has) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: AppColors.goldBright),
                ],
              ]),
              Text(
                  '${EquipmentRules.slotLabel(info.slot)} · 조각 '
                  '${need(p.materialCount(MaterialId.bossShard), cost.shards)} · '
                  '${Materials.info(set.material).name} '
                  '${need(p.materialCount(set.material), cost.mats)} · 금화 ${cost.gold}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        TextButton(
          key: Key('bossCraft_${base.name}'),
          style: gameButtonStyle(gold: check == CraftCheck.ok),
          onPressed: check == CraftCheck.ok ? () => _craft(context) : null,
          child: Text(has ? '또 만들기' : '만들기'),
        ),
      ]),
    );
  }
}
