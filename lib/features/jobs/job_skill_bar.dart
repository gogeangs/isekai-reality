import 'skill_icon.dart';
import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';

/// 직업 스킬 MP 색 (기력과 헷갈리지 않게 보라)
const Color kJobMpColor = Color(0xFFB27BFF);

/// 그 화면에서 쓰는 직업 스킬 「스킬 쓰기」 줄 (묶음 30 #55).
/// 직업 각성 전이거나 이 화면에서 쓸 스킬이 없으면 아무것도 그리지 않는다.
class JobSkillBar extends StatelessWidget {
  const JobSkillBar({
    super.key,
    required this.controller,
    required this.places,
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  final AppController controller;
  final List<SkillPlace> places;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          if (!c.jobsOpen) return const SizedBox.shrink();
          final list = c.skillsAt(places);
          if (list.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: padding,
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (s, sub) in list)
                JobSkillChip(controller: c, skill: s, sub: sub),
            ]),
          );
        },
      );
}

/// 스킬 하나 (이름 · MP 비용 · 써 둔 상태)
class JobSkillChip extends StatelessWidget {
  const JobSkillChip(
      {super.key, required this.controller, required this.skill, this.sub = false});

  final AppController controller;
  final JobSkill skill;
  final bool sub;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = JobRules.skill(skill);
    final cost = c.skillCost(skill, sub: sub);
    final on = c.skillPending(skill) || c.skillTimedOn(skill);
    final left = c.skillLeft(skill);
    final low = c.jobMp < cost;
    final sub2 = on
        ? (left != null ? '${left.inMinutes + 1}분 남음' : '준비됨')
        : 'MP $cost';
    return Opacity(
      opacity: low && !on ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('jobSkill_${skill.name}'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => useSkillFromUi(context, c, skill, sub: sub),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            decoration: BoxDecoration(
              color: on ? const Color(0x553C2A66) : const Color(0xCC14163A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: on ? kJobMpColor : kJobMpColor.withValues(alpha: 0.6),
                  width: on ? 1.6 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              // 묶음 35: 직업 문장 + 종류 테두리
              SkillArt.jobIcon(skill, size: 30),
              const SizedBox(width: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(on ? info.name : '스킬 쓰기 · ${info.name}',
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(sub2,
                      style: const TextStyle(color: kJobMpColor, fontSize: 11)),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 화면에서 스킬을 누를 때. MP가 모자라면 「MP가 모자라요」
Future<void> useSkillFromUi(BuildContext context, AppController c, JobSkill s,
    {bool sub = false}) async {
  final info = JobRules.skill(s);
  if (c.skillPending(s) || c.skillTimedOn(s)) {
    showTopNotice(context, '${info.name} · 이미 써 두었어요');
    return;
  }
  if (c.jobMp < c.skillCost(s, sub: sub)) {
    showTopNotice(context, 'MP가 모자라요', icon: Icons.bolt_rounded);
    return;
  }
  switch (s) {
    case JobSkill.runeCarve:
      await _runeCarve(context, c);
      return;
    case JobSkill.polish:
      await _polish(context, c);
      return;
    case JobSkill.negotiate:
      await _negotiate(context, c);
      return;
    case JobSkill.quickRepair:
      await _quickRepair(context, c);
      return;
    case JobSkill.snackPouch:
      await _snack(context, c);
      return;
    case JobSkill.track:
      await _track(context, c);
      return;
    default:
      break;
  }
  final r = await c.useJobSkill(s);
  if (!context.mounted) return;
  showTopNotice(
      context,
      switch (r) {
        SkillUse.ok => '${info.name}! ${info.text}',
        SkillUse.notEnoughMp => 'MP가 모자라요',
        SkillUse.already => '${info.name} · 이미 써 두었어요',
        SkillUse.cannot => switch (s) {
            JobSkill.cheer => '원정 간 펫이 없어요',
            JobSkill.lightResonance => '기력이 이미 가득해요',
            JobSkill.eggWarm => '품고 있는 알이 없어요',
            JobSkill.firstAid => 'HP가 이미 가득해요',
            _ => '지금은 쓸 수 없어요',
          },
      },
      icon: Icons.bolt_rounded);
}

Future<T?> _pick<T>(BuildContext context, String title, List<(T, String)> items) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(title, style: AppText.title(18)),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('고를 것이 없어요',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final (v, label) in items)
                ListTile(
                  title: Text(label,
                      style: const TextStyle(color: AppColors.text)),
                  onTap: () => Navigator.of(sheet).pop(v),
                ),
            ]),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

void _result(BuildContext context, SkillUse r, String ok) {
  if (!context.mounted) return;
  showTopNotice(
      context,
      switch (r) {
        SkillUse.ok => ok,
        SkillUse.notEnoughMp => 'MP가 모자라요',
        _ => '지금은 쓸 수 없어요',
      },
      icon: Icons.bolt_rounded);
}

Future<void> _runeCarve(BuildContext context, AppController c) async {
  final uid = await _pick<String>(context, '룬을 새길 장비', [
    for (final i in c.armory.items) (i.uid, i.name),
  ]);
  if (uid == null || !context.mounted) return;
  final e = await _pick<Element>(context, '새길 속성', [
    for (final x in Element.values) (x, x.label),
  ]);
  if (e == null || !context.mounted) return;
  _result(context, await c.runeCarve(uid, e), '룬을 새겼어요 · ${e.label} 속성');
}

Future<void> _polish(BuildContext context, AppController c) async {
  final uid = await _pick<String>(context, '광택을 낼 장신구', [
    for (final i in c.armory.items)
      if (EquipmentRules.info(i.base).slot == EquipSlot.accessory) (i.uid, i.name),
  ]);
  if (uid == null || !context.mounted) return;
  final before = c.armory.byUid(uid)?.extras ?? const <String, int>{};
  final after = await c.polishRoll(uid);
  if (!context.mounted) return;
  if (after == null) {
    _result(context, SkillUse.cannot, '');
    return;
  }
  String line(Map<String, int> m) => m.isEmpty
      ? '추가 능력치 없음'
      : [
          for (final e in m.entries)
            '${EquipmentRules.statName(e.key)} +${e.value}',
        ].join(' · ');
  final keepNew = await _pick<bool>(context, '어느 쪽을 남길까요?', [
    (false, '이전 · ${line(before)}'),
    (true, '새것 · ${line(after)}'),
  ]);
  if (!context.mounted) return;
  if (keepNew == true) {
    await c.polishKeep(uid, after);
    if (context.mounted) showTopNotice(context, '광택을 냈어요 · 새 능력치를 남겼어요');
  } else {
    showTopNotice(context, '광택을 냈어요 · 이전 능력치를 남겼어요');
  }
}

Future<void> _quickRepair(BuildContext context, AppController c) async {
  final uid = await _pick<String>(context, '고칠 장비', [
    for (final i in c.armory.items)
      if (i.durability < EquipmentRules.maxDurability) (i.uid, i.name),
  ]);
  if (uid == null || !context.mounted) return;
  _result(context, await c.quickRepair(uid), '장비를 고쳤어요');
}

Future<void> _snack(BuildContext context, AppController c) async {
  final uid = await _pick<String>(context, '간식을 줄 펫', [
    for (final p in c.pets.pets)
      if (p.bond < PetRules.maxBond) (p.uid, p.name),
  ]);
  if (uid == null || !context.mounted) return;
  _result(context, await c.snackPouch(uid), '펫과 한층 친해졌어요');
}

Future<void> _track(BuildContext context, AppController c) async {
  final m = await _pick<MonsterId>(context, '쫓을 몬스터', [
    for (final x in MonsterId.values)
      if (c.purifiedEver.contains(x) && !Monsters.info(x).isBoss)
        (x, Monsters.info(x).name),
  ]);
  if (m == null || !context.mounted) return;
  _result(context, await c.trackMonster(m), '${Monsters.info(m).name}의 흔적을 찾았어요');
}

Future<void> _negotiate(BuildContext context, AppController c) async {
  final b = c.board;
  final slot = await _pick<int>(context, '바꿀 길드 의뢰', [
    for (var i = 0; i < b.slots.length; i++)
      if (BoardRules.template(b.slots[i].templateId) case final t?) (i, t.title),
  ]);
  if (slot == null || !context.mounted) return;
  _result(context, await c.negotiateErrand(slot), '의뢰를 바꿨어요');
}

/// MP 막대 (상태·길드·지도)
class JobMpBar extends StatelessWidget {
  const JobMpBar({super.key, required this.controller, this.compact = false});

  final AppController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final max = c.jobMpMax;
    final v = c.jobMp;
    final ratio = max <= 0 ? 0.0 : (v / max).clamp(0.0, 1.0);
    return Row(key: const Key('jobMpBar'), children: [
      Text('MP',
          style: TextStyle(
              color: kJobMpColor,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w800)),
      const SizedBox(width: 6),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: compact ? 6 : 9,
            backgroundColor: const Color(0x33B27BFF),
            valueColor: const AlwaysStoppedAnimation(kJobMpColor),
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('$v / $max',
          style: TextStyle(color: AppColors.text, fontSize: compact ? 11 : 13)),
    ]);
  }
}
