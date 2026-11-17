import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/act3_state.dart';
import '../../core/models/armory.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../smithy/equipment_view.dart';
import 'act3_screen.dart' show AllyFace;

const List<String> _statNames = ['힘', '체력', '민첩', '지능'];

/// 주점 「동료」 탭 (묶음 52 #243): 데려가는 동료 둘 · 이야기 동료 · 이름 없는 동료 · 모집
class AllyTab extends StatelessWidget {
  const AllyTab({super.key, required this.controller});

  final AppController controller;

  Future<void> _recruit(BuildContext context) async {
    final c = controller;
    if (c.rosterFull) {
      showTopNotice(context, '동료 자리가 꽉 찼어요 · 리안과 친해지면 늘어요',
          icon: Icons.info_outline_rounded);
      return;
    }
    final a = await c.recruit();
    if (!context.mounted) return;
    if (a == null) {
      showTopNotice(context, '모집권이 없어요', icon: Icons.info_outline_rounded);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (d) => GameAlert(
        key: const Key('recruitResult'),
        title: Text('새 동료', style: AppText.title(18)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          AllyFace(look: c.allyLook(a), size: 64),
          const SizedBox(height: 8),
          Text(a.name, style: AppText.title(20)),
          Text(c.allyJobName(a),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 6),
          _Stats(ally: a),
          const SizedBox(height: 4),
          _Traits(ally: a),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('좋아요')),
        ],
      ),
    );
  }

  Future<void> _odds(BuildContext context) => showDialog<void>(
        context: context,
        builder: (d) => GameAlert(
          key: const Key('oddsDialog'),
          title: Text('모집 확률', style: AppText.title(18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in Act3Rules.odds())
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: KText('· $l',
                      style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.4)),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d), child: const Text('닫기')),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final party = c.act3.party;
    final story = [for (final a in c.allies) if (a.isStory) a];
    return Column(
      key: const Key('allyTab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrnatePanel(
          key: const Key('allyParty'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('데려가는 동료 (2명)', style: AppText.title(16)),
              const SizedBox(height: 4),
              const KText('다리 너머에서 함께 싸워요. 동료를 눌러 넣거나 빼요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              Row(children: [
                for (var i = 0; i < 2; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: i < c.partyAllies.length
                        ? _PartySlot(controller: c, ally: c.partyAllies[i])
                        : Container(
                            height: 60,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                            ),
                            child: const Text('빈 자리',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                          ),
                  ),
                ],
              ]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text('이야기 동료', style: AppText.title(15, color: AppColors.goldBright)),
        const SizedBox(height: 6),
        for (final a in story) ...[
          _AllyRow(controller: c, ally: a, inParty: party.contains(a.id)),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Text('모험가 ${c.nameless.length} / ${c.rosterLimit}',
                style: AppText.title(15, color: AppColors.goldBright)),
          ),
          TextButton(
            key: const Key('oddsButton'),
            onPressed: () => _odds(context),
            child: const Text('확률 보기'),
          ),
        ]),
        const SizedBox(height: 4),
        for (final a in c.nameless) ...[
          _AllyRow(controller: c, ally: a, inParty: party.contains(a.id)),
          const SizedBox(height: 6),
        ],
        if (c.nameless.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: KText('아직 함께하는 모험가가 없어요. 모집권으로 불러 보세요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ),
        const SizedBox(height: 6),
        OrnatePanel(
          key: const Key('allyRecruit'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Image.asset(Act3Rules.ticketImage,
                    width: 40,
                    height: 40,
                    errorBuilder: (_, __, ___) => const Icon(Icons.confirmation_number_rounded,
                        color: AppColors.goldBright, size: 32)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('모집권 ${c.recruitTickets}장',
                      key: const Key('ticketCount'), style: AppText.title(16)),
                ),
              ]),
              const SizedBox(height: 4),
              KText(
                  '다리 너머에서 ${comma(Act3Rules.ticketSteps)}보 걸을 때마다 1장 (하루 ${Act3Rules.ticketStepsPerDay}장까지)',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              GoldButton(
                key: const Key('recruitButton'),
                label: '모험가 부르기 · 모집권 1장',
                height: 46,
                onPressed: c.recruitTickets > 0 ? () => _recruit(context) : null,
              ),
              if (c.canAdTicket) ...[
                const SizedBox(height: 8),
                AdButton(
                  key: const Key('adTicket'),
                  label: '광고 보고 모집권 1장 (하루 1번)',
                  onPressed: () async {
                    final ok = await c.adTicket();
                    if (!ok && context.mounted) showTopNotice(context, '광고를 불러오지 못했어요.');
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PartySlot extends StatelessWidget {
  const _PartySlot({required this.controller, required this.ally});

  final AppController controller;
  final AllyData ally;

  @override
  Widget build(BuildContext context) => Container(
        key: Key('partySlot_${ally.id}'),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0x33E8C77A),
          border: Border.all(color: AppColors.goldBright, width: 1.2),
        ),
        child: Row(children: [
          AllyFace(look: controller.allyLook(ally), size: 40),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ally.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                Text('Lv.${ally.level}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ],
            ),
          ),
        ]),
      );
}

/// 동료 한 줄 (누르면 자세히 · 오른쪽 버튼으로 데려가기)
class _AllyRow extends StatelessWidget {
  const _AllyRow({required this.controller, required this.ally, required this.inParty});

  final AppController controller;
  final AllyData ally;
  final bool inParty;

  Future<void> _toggle(BuildContext context) async {
    final c = controller;
    final p = [...c.act3.party];
    if (inParty) {
      p.remove(ally.id);
    } else {
      if (p.length >= 2) {
        showTopNotice(context, '두 명까지 데려갈 수 있어요 · 한 명을 먼저 빼 주세요',
            icon: Icons.info_outline_rounded);
        return;
      }
      p.add(ally.id);
    }
    await c.setParty(p);
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return OrnatePanel(
      key: Key('allyRow_${ally.id}'),
      highlight: inParty,
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => AllyDetailScreen(controller: c, allyId: ally.id))),
        child: Row(children: [
          AllyFace(look: c.allyLook(ally), size: 44),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${ally.name}  Lv.${ally.level}',
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                Text(c.allyJobName(ally),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                _Stats(ally: ally, small: true),
              ],
            ),
          ),
          TextButton(
            key: Key('partyToggle_${ally.id}'),
            style: gameButtonStyle(gold: !inParty),
            onPressed: () => _toggle(context),
            child: Text(inParty ? '빼기' : '데려가기'),
          ),
        ]),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.ally, this.small = false});

  final AllyData ally;
  final bool small;

  @override
  Widget build(BuildContext context) => Text(
        [for (var i = 0; i < 4; i++) '${_statNames[i]} ${ally.stats[i]}'].join(' · '),
        style: TextStyle(color: AppColors.goldBright, fontSize: small ? 11.5 : 13),
      );
}

class _Traits extends StatelessWidget {
  const _Traits({required this.ally});

  final AllyData ally;

  @override
  Widget build(BuildContext context) {
    final names = [
      for (final t in ally.traits)
        if (Act3Rules.trait(t) case final x?) x.name,
    ];
    if (names.isEmpty) return const SizedBox();
    return Wrap(spacing: 6, runSpacing: 4, children: [
      for (final n in names)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Text(n, style: const TextStyle(color: AppColors.text, fontSize: 11.5)),
        ),
    ]);
  }
}

/// 동료 자세히: 능력치 · 특성 · 레벨 · 장비 6칸 · 스킬 4칸 · 이름 바꾸기 · 내보내기
class AllyDetailScreen extends StatelessWidget {
  const AllyDetailScreen({super.key, required this.controller, required this.allyId});

  final AppController controller;
  final String allyId;

  Future<void> _rename(BuildContext context, AllyData a) async {
    final text = TextEditingController(text: a.name);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => GameAlert(
        title: const Text('이름 바꾸기'),
        content: TextField(controller: text, maxLength: 8, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('그만둘래요')),
          TextButton(onPressed: () => Navigator.pop(d, text.text), child: const Text('바꾸기')),
        ],
      ),
    );
    text.dispose();
    if (name == null) return;
    final ok = await controller.renameAlly(a.id, name);
    if (!ok && name.trim().isNotEmpty && context.mounted) {
      showTopNotice(context, '마을 사람 이름은 쓸 수 없어요', icon: Icons.info_outline_rounded);
    }
  }

  Future<void> _release(BuildContext context, AllyData a) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (d) => GameAlert(
            title: Text('${a.name} 내보내기'),
            content: KText(
                '${josa(a.name, '은/는')} 떠나요. '
                '금화 ${Act3Rules.releaseGold}을 받고, 입던 장비는 가방으로 돌아와요.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('그만둘래요')),
              TextButton(
                  key: const Key('releaseYes'),
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('내보내기')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await controller.releaseAlly(a.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _pickGear(BuildContext context, AllyData a, EquipSlot slot) async {
    final c = controller;
    final worn = [for (final g in a.gear) if (g.slot == slot) g];
    final choices = c.allyGearChoices(slot);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: ListView(
            key: Key('allyGearSheet_${slot.name}'),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            children: [
              Text(EquipmentRules.slotLabel(slot), style: AppText.title(19)),
              const SizedBox(height: 4),
              const KText('가방에 있는 장비를 건네요. 동료가 입은 장비는 내가 입을 수 없어요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 8),
              if (worn.isNotEmpty)
                TextButton(
                  key: const Key('allyUnequip'),
                  onPressed: () async {
                    Navigator.pop(sheet);
                    await c.unequipAlly(a.id, slot);
                  },
                  child: const Text('벗겨서 가방으로'),
                ),
              if (choices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: KText('가방에 이 칸 장비가 없어요.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
              for (final it in choices)
                ListTile(
                  key: Key('allyGear_${it.uid}'),
                  contentPadding: EdgeInsets.zero,
                  leading: EquipIcon(base: it.base, grade: it.grade, size: 44),
                  title: EquipName(it, size: 14),
                  subtitle: ItemStats(it, fontSize: 11.5),
                  onTap: () async {
                    Navigator.pop(sheet);
                    await c.equipAlly(a.id, it.uid);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final c = controller;
    return Scaffold(
      key: const Key('allyDetail'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final a = c.act3.ally(allyId);
            if (a == null) return const SizedBox();
            final skills = c.allySkills(a);
            final points = c.allyPoints(a);
            final inParty = c.act3.party.contains(a.id);
            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(title: a.name, onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 8),
                OrnatePanel(
                  ornament: true,
                  child: Column(children: [
                    Row(children: [
                      a.isStory && c.allyLook(a).art != null
                          ? Image.asset(c.allyLook(a).art!,
                              width: 96,
                              height: 120,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  AllyFace(look: c.allyLook(a), size: 80))
                          : AllyFace(look: c.allyLook(a), size: 80),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name, style: AppText.title(20)),
                            Text(c.allyJobName(a),
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 13)),
                            if (c.allyElement(a) case final e?)
                              Text('${e.label} 속성 마법',
                                  style: const TextStyle(
                                      color: AppColors.goldBright, fontSize: 12.5)),
                            const SizedBox(height: 4),
                            Text('Lv.${a.level} · 경험치 ${a.exp} / ${c.allyExpToNext(a)}',
                                key: const Key('allyLevel'),
                                style: const TextStyle(color: AppColors.text, fontSize: 13)),
                            const SizedBox(height: 3),
                            GlowBar(
                                ratio: a.exp / c.allyExpToNext(a),
                                colors: BarColors.exp,
                                height: 6),
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    _Stats(ally: a),
                    const SizedBox(height: 6),
                    _Traits(ally: a),
                    const SizedBox(height: 4),
                    const KText('동료 레벨은 함께 싸우면 오르고, 내 레벨을 넘지 않아요.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  ]),
                ),
                const SizedBox(height: 10),
                GoldButton(
                  key: const Key('allyPartyToggle'),
                  label: inParty ? '데려가는 동료에서 빼기' : '데려가기',
                  height: 44,
                  onPressed: () async {
                    final p = [...c.act3.party];
                    if (inParty) {
                      p.remove(a.id);
                    } else if (p.length >= 2) {
                      showTopNotice(context, '두 명까지 데려갈 수 있어요 · 한 명을 먼저 빼 주세요',
                          icon: Icons.info_outline_rounded);
                      return;
                    } else {
                      p.add(a.id);
                    }
                    await c.setParty(p);
                  },
                ),
                const SizedBox(height: 10),
                OrnatePanel(
                  key: const Key('allyGear'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('장비', style: AppText.title(16)),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.95,
                        children: [
                          for (final s in EquipSlot.values)
                            _GearSlot(
                              slot: s,
                              item: [for (final g in a.gear) if (g.slot == s) g].firstOrNull,
                              fits: s == EquipSlot.weapon && c.allyWeaponFits(a),
                              onTap: () => _pickGear(context, a, s),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                OrnatePanel(
                  key: const Key('allySkills'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(child: Text('스킬', style: AppText.title(16))),
                        Text('포인트 $points',
                            key: const Key('allyPoints'),
                            style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
                      ]),
                      const SizedBox(height: 2),
                      KText(
                          '동료 레벨 ${Act3Rules.levelsPerPoint}마다 포인트 1. 1번 → 2·3번 → 4번 순서로 열어요. 싸움 버튼에는 하나를 끼워요.',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                      for (final (i, s) in skills.indexed)
                        _SkillRow(
                          index: i,
                          info: s,
                          open: a.skills.contains(i),
                          equipped: a.slot == i,
                          quest: a.isStory &&
                              Act3Rules.lockedByQuest(StoryAlly.values.byName(a.story!), i) &&
                              !c.garenRosterDone,
                          canUnlock: c.canUnlockSkill(a, i),
                          cost: Act3Rules.skillCost(i),
                          onUnlock: () => c.unlockAllySkill(a.id, i),
                          onEquip: () => c.setAllySkill(a.id, i),
                        ),
                    ],
                  ),
                ),
                if (!a.isStory) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextButton(
                        key: const Key('allyRename'),
                        style: gameButtonStyle(gold: false),
                        onPressed: () => _rename(context, a),
                        child: const Text('이름 바꾸기'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        key: const Key('allyRelease'),
                        style: gameButtonStyle(gold: false),
                        onPressed: () => _release(context, a),
                        child: const Text('내보내기'),
                      ),
                    ),
                  ]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GearSlot extends StatelessWidget {
  const _GearSlot({required this.slot, required this.item, required this.onTap, this.fits = false});

  final EquipSlot slot;
  final EquipItem? item;
  final VoidCallback onTap;

  /// 직업에 잘 맞는 무기 (묶음 53)
  final bool fits;

  @override
  Widget build(BuildContext context) => InkWell(
        key: Key('allySlot_${slot.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              item == null
                  ? const Icon(Icons.add_rounded, color: AppColors.textMuted, size: 30)
                  : EquipIcon(base: item!.base, grade: item!.grade, size: 44),
              const SizedBox(height: 4),
              Text(
                  item == null
                      ? EquipmentRules.slotLabel(slot)
                      : EquipmentRules.info(item!.base).name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 11)),
              if (fits)
                const Text('잘 맞아요',
                    key: Key('weaponFits'),
                    style: TextStyle(color: AppColors.goldBright, fontSize: 10.5)),
            ],
          ),
        ),
      );
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.index,
    required this.info,
    required this.open,
    required this.equipped,
    required this.quest,
    required this.canUnlock,
    required this.cost,
    required this.onUnlock,
    required this.onEquip,
  });

  final int index;
  final AllySkillInfo info;
  final bool open, equipped, quest, canUnlock;
  final int cost;
  final VoidCallback onUnlock, onEquip;

  @override
  Widget build(BuildContext context) => Padding(
        key: Key('allySkill_$index'),
        padding: const EdgeInsets.only(top: 8),
        child: Opacity(
          opacity: open ? 1 : 0.6,
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: equipped ? AppColors.goldBright : const Color(0x33E8C77A),
              ),
              child: Text('${index + 1}',
                  style: TextStyle(
                      color: equipped ? AppColors.deepNight : AppColors.text,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.name,
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
                  KText(quest && !open ? '가렌의 부탁을 끝내면 열려요.' : info.text,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            if (!open)
              TextButton(
                key: Key('unlockSkill_$index'),
                style: gameButtonStyle(gold: canUnlock),
                onPressed: canUnlock ? onUnlock : null,
                child: Text(quest ? '잠김' : '열기 · $cost'),
              )
            else if (equipped)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('끼움', style: TextStyle(color: AppColors.goldBright, fontSize: 12.5)),
              )
            else
              TextButton(
                key: Key('equipSkill_$index'),
                style: gameButtonStyle(gold: false),
                onPressed: onEquip,
                child: const Text('끼우기'),
              ),
          ]),
        ),
      );
}
