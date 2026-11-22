import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../alchemy/convert_panel.dart' show LockedJobPanel;
import '../battle/element_view.dart';
import '../town/material_view.dart';
import 'equipment_view.dart';
import 'equip_now_button.dart';

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
        // 묶음 75 #322: 세트 판 위 작은 줄 (대장장이가 아니면)
        if (!c.bossSmith)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: KText('대장장이가 만들 수 있어요',
                key: Key('bossSmithLine'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        const SizedBox(height: 10),
        for (final s in BossGearRules.sets) ...[
          c.bossSetOpen(s.id)
              ? _SetCard(controller: c, set: s)
              : _HiddenSet(set: s),
          const SizedBox(height: 10),
        ],
        // 묶음 50 #146: 하이랜드 수호 기사 (수호자를 하나라도 쓰러뜨리면 보인다)
        c.bossSetOpen(BossSet.sky)
            ? _SetCard(controller: c, set: BossGearRules.skySet)
            : const _HiddenSet(set: BossGearRules.skySet),
        const SizedBox(height: 10),
        // 묶음 56 #236: 파티 보스 세트 「동행」 (파티 보스 재료가 하나라도 생기면 보인다)
        if (c.partyOpen) ...[
          c.bossSetOpen(BossSet.party)
              ? _SetCard(controller: c, set: BossGearRules.partySet)
              : const _HiddenSet(set: BossGearRules.partySet),
          const SizedBox(height: 10),
        ],
        // 묶음 34: 잿빛 왕의 유품 (만들 수 없음, 분신·본체에게서). 하나라도 얻으면 보인다
        if (BossGearRules.relicSet.parts.any((x) => c.hasBossPart(x.$1))) ...[
          _RelicCard(controller: c),
          const SizedBox(height: 10),
        ],
        // 묶음 53 #243: 3막 지역 무기 (등불을 켜면)
        if (c.baldrinLit) ...[
          _RegionWeapon(controller: c),
          const SizedBox(height: 10),
        ],
        // 묶음 57: 지역 2~5 무기
        for (final r in c.litRegionWeapons) ...[
          _RegionWeapon(controller: c, region: r),
          const SizedBox(height: 10),
        ],
        const LockedJobPanel(
          title: '대장장이',
          lines: ['보스 장비를 만들 수 있어요'],
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

/// 묶음 75 #322: 대장장이가 아닌 사람이 보스 장비 만들기를 눌렀을 때
const String bossSmithOnly = '보스 장비는 대장장이만 만들 수 있어요 · 조합에서 대장장이를 두면 돼요';

/// 「잿빛 왕의 유품」 (묶음 34): 만들기 버튼 없이 얻은 부위만 밝게
class _RelicCard extends StatelessWidget {
  const _RelicCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    const set = BossGearRules.relicSet;
    final got = set.parts.where((x) => c.hasBossPart(x.$1)).length;
    const style = TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4);
    return OrnatePanel(
      key: const Key('bossSet_ash'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: Color(0xFFB9B2C9), size: 22),
            const SizedBox(width: 6),
            Expanded(
              child: Text(set.name,
                  style: AppText.title(19, color: Color(set.aura))),
            ),
            Text('$got / 6',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          ]),
          const SizedBox(height: 4),
          const KText('2개 · 잿빛 몬스터에게 받는 피해가 줄어요', style: style),
          const KText('4개 · 잿빛 몬스터에게 주는 피해가 늘어요', style: style),
          KText('6개 · ${set.abilityName}: ${set.abilityText} · 「${set.look}」 모습',
              style: style),
          const SizedBox(height: 8),
          for (final part in set.parts)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                Opacity(
                  opacity: c.hasBossPart(part.$1) ? 1 : 0.35,
                  child: EquipIcon(base: part.$1, size: 42),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          c.hasBossPart(part.$1) ? part.$2 : '???',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.hasBossPart(part.$1)
                                  ? AppColors.text
                                  : AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text(
                          '${EquipmentRules.slotLabel(EquipmentRules.info(part.$1).slot)} · '
                          '${c.hasBossPart(part.$1) ? part.$3 : '잿빛 군주에게서 얻어요'}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
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
    if (set.id == BossSet.party) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KText('2개 · 파티 보스에게 주는 피해가 조금 커져요', style: style),
          const KText('4개 · 파티원과 함께 있을 때 사냥 경험치가 조금 더', style: style),
          KText('6개 · 「${set.look}」 모습 · ${set.abilityText}', style: style),
        ],
      );
    }
    if (set.id == BossSet.sky) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KText('2개 · 걸을 때 하늘 깃털이 조금 더 잘 모여요', style: style),
          const KText('4개 · 바람·번개·빛·얼음·물 속성 공격에 받는 피해가 줄어요',
              style: style),
          KText('6개 · 「${set.look}」 모습 · ${set.abilityText}', style: style),
        ],
      );
    }
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
    await showBossMade(context, controller, base, r);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final p = c.player;
    final info = EquipmentRules.info(base);
    final has = c.hasBossPart(base);
    final cost = BossGearRules.partCost(base, blacksmith: c.blacksmith);
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
              KText(
                  [
                    EquipmentRules.slotLabel(info.slot),
                    for (final e in cost.mats.entries)
                      '${e.key == MaterialId.bossShard ? '조각' : Materials.info(e.key).name} '
                          '${need(p.materialCount(e.key), e.value)}',
                    '금화 ${cost.gold}',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // 묶음 75 #322: 대장장이가 아니면 흐린 자물쇠 「대장장이만」 → 누르면 안내
        if (check == CraftCheck.notSmith)
          TextButton.icon(
            key: Key('bossCraftLocked_${base.name}'),
            style: gameButtonStyle(gold: false),
            onPressed: () => showTopNotice(context, bossSmithOnly, icon: Icons.lock_rounded),
            icon: const Icon(Icons.lock_rounded, size: 14, color: AppColors.textMuted),
            label: const Text('대장장이만', style: TextStyle(color: AppColors.textMuted)),
          )
        else
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

/// 지역 무기 「관문의 빛 창」 (빈 갑주 조각 + 철 주괴 + 마석 + 금화)
class _RegionWeapon extends StatelessWidget {
  const _RegionWeapon({required this.controller, this.region});

  final AppController controller;
  final RegionContent? region;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final r = region;
    final base = r?.weapon ?? EquipBase.baldrinSpear;
    final info = EquipmentRules.info(base);
    final elName = (r?.weaponElement ?? Element.light).label;
    return OrnatePanel(
      key: Key(r == null ? 'regionWeapon' : 'regionWeapon_${r.prefix}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            EquipIcon(base: base, size: 56),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.name, style: AppText.title(16)),
                  KText('${r == null ? '발드린 관문' : Act3Rules.region(r.region).name}의 지역 무기 · $elName 속성',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 4, children: [
            for (final e in info.recipe.entries)
              Row(mainAxisSize: MainAxisSize.min, children: [
                MaterialIcon(e.key, size: 22),
                const SizedBox(width: 3),
                Text('${c.player.materialCount(e.key)}/${e.value}',
                    style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
              ]),
            Text('마석 ${info.manaStones} · 금화 ${r == null ? BaldrinRules.spearGold : RegionRules.weaponGold}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ]),
          const SizedBox(height: 8),
          GoldButton(
            key: Key(r == null ? 'craftSpear' : 'craftRegion_${r.prefix}'),
            label: '만들기',
            height: 44,
            fontSize: 18,
            onPressed: (r == null ? c.spearCraftable : c.regionWeaponCraftable(r))
                ? () async {
                    final it = r == null ? await c.craftSpear() : await c.craftRegionWeapon(r);
                    if (it != null && context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (d) => GameAlert(
                          title: Text(info.name),
                          content: Row(children: [
                            EquipIcon(base: it.base, grade: it.grade, size: 56),
                            const SizedBox(width: 10),
                            Expanded(child: EquipName(it, size: 15)),
                          ]),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d), child: const Text('좋아요')),
                          ],
                        ),
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }
}


/// 왕의 장비 · 보스 장비 만든 결과 창 (묶음 82: 캡처에서도 씀)
Future<void> showBossMade(BuildContext context, AppController controller, EquipBase base, BossCraftResult r) async {
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
          if (r.ok) EquipNowButton(key: const Key('bossEquipNow'), controller: controller, item: r.item!),
          TextButton(
              onPressed: () => Navigator.of(d).pop(), child: const Text('확인')),
        ],
      ),
    );
  }
