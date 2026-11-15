import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../tutorial/feature_tour.dart';
import 'job_skill_bar.dart';

/// 스킬 페이지 (묶음 31 #198): 전투 칸 · 고유 스킬(Lv.15 각성 뒤) · 숙련 스킬
class SkillScreen extends StatefulWidget {
  const SkillScreen({super.key, required this.controller, this.tab = 0});

  final AppController controller;

  /// 처음 여는 칸 (0 전투 칸 · 1 고유 스킬 · 2 숙련 스킬)
  final int tab;

  @override
  State<SkillScreen> createState() => _SkillScreenState();
}

class _SkillScreenState extends State<SkillScreen> {
  AppController get c => widget.controller;
  late int _tab = widget.tab;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return TourScreenMark(
      name: 'skills',
      child: Scaffold(
        key: const Key('skillScreen'),
        backgroundColor: AppColors.deepNight,
        body: NightBackground(
          header: true,
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final tabs = <(int, String)>[
                (0, '전투 칸'),
                if (c.jobsOpen) (1, '고유 스킬'),
                (2, '숙련 스킬'),
              ];
              if (!tabs.any((t) => t.$1 == _tab)) _tab = 0;
              return ListView(
                padding: EdgeInsets.fromLTRB(14, top + 6, 14, 30),
                children: [
                  OrnateTopBar(
                      title: '스킬',
                      onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 8),
                  Row(children: [
                    for (final (i, label) in tabs)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _TabChip(
                            key: Key('skillTab_$i'),
                            label: label,
                            on: _tab == i,
                            dot: i == 1 && c.skillPointsLeft > 0,
                            onTap: () => setState(() => _tab = i),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  ...switch (_tab) {
                    1 => _jobTab(context),
                    2 => _masteryTab(),
                    _ => _battleTab(context),
                  },
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ───────────── 전투 칸

  String _entryName(String e) {
    if (e.startsWith('job:')) {
      final s = JobRules.parseSkill(e.substring(4));
      return s == null ? '' : JobRules.skill(s).name;
    }
    final m = Mastery.values.where((x) => 'mastery:${x.name}' == e).firstOrNull;
    return m == null ? '' : JobRules.masteryActive(m).name;
  }

  String _entrySub(String e) {
    if (e.startsWith('job:')) {
      final s = JobRules.parseSkill(e.substring(4));
      return s == null ? '' : 'MP ${c.skillCost(s)}';
    }
    return '숙련 스킬 · 몇 턴마다';
  }

  Future<void> _pickSlot(BuildContext context, int i) async {
    final choices = c.loadoutChoices;
    final cur = c.battleLoadout;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.7),
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('전투 칸 ${i + 1}', style: AppText.title(18)),
            ),
            for (final e in choices)
              ListTile(
                key: Key('slotPick_$e'),
                title: Text(_entryName(e),
                    style: const TextStyle(color: AppColors.text)),
                subtitle: Text(_entrySub(e),
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                trailing: cur.contains(e)
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.goldBright)
                    : null,
                onTap: () => Navigator.of(sheet).pop(e),
              ),
            ListTile(
              key: const Key('slotPick_empty'),
              title: const Text('비우기',
                  style: TextStyle(color: AppColors.textMuted)),
              onTap: () => Navigator.of(sheet).pop(''),
            ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
    if (picked == null) return;
    await c.setLoadout(i, picked.isEmpty ? null : picked);
  }

  List<Widget> _battleTab(BuildContext context) {
    final slots = c.battleLoadout;
    final pet = c.companionPet;
    return [
      const KText('전투 화면에 나오는 스킬이에요. 칸을 눌러 바꿀 수 있어요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 10),
      const _FixedRow(name: '강타', text: '몇 턴마다 크게 쳐요'),
      const _FixedRow(name: '방어 태세', text: '몇 턴마다 잠시 받는 피해를 줄여요'),
      for (var i = 0; i < 2; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            key: Key('skillSlot_$i'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => _pickSlot(context, i),
            child: OrnatePanel(
              highlight: i < slots.length,
              child: Row(children: [
                Icon(
                    i < slots.length && slots[i].startsWith('job:')
                        ? Icons.bolt_rounded
                        : Icons.auto_awesome,
                    color: i < slots.length && slots[i].startsWith('job:')
                        ? kJobMpColor
                        : AppColors.goldBright,
                    size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('스킬 칸 ${i + 1}',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                        Text(
                            i < slots.length ? _entryName(slots[i]) : '비어 있음',
                            style: AppText.title(16, color: AppColors.text)),
                        if (i < slots.length)
                          Text(_entrySub(slots[i]),
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 12)),
                      ]),
                ),
                const Icon(Icons.swap_horiz_rounded, color: AppColors.gold),
              ]),
            ),
          ),
        ),
      _FixedRow(
          name: pet != null ? pet.info.skillName : '정령의 일격',
          text: pet != null ? '함께 있는 펫의 스킬' : '정령이 함께 싸워요'),
    ];
  }

  // ───────────── 고유 스킬

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.night,
        title: const Text('다시 나누기', style: TextStyle(color: AppColors.text)),
        content: const Text('쓴 포인트를 모두 돌려받아요. 직업마다 첫 스킬은 그대로 남아요.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('그만두기')),
          TextButton(
              key: const Key('skillResetOk'),
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('다시 나누기')),
        ],
      ),
    );
    if (ok != true) return;
    await c.resetSkills();
    if (context.mounted) showTopNotice(context, '포인트를 돌려받았어요. 다시 나눠 보세요!');
  }

  List<Widget> _jobTab(BuildContext context) {
    final jobs = [if (c.mainJob case final m?) m, ...c.subJobs];
    return [
      OrnatePanel(
        child: Row(children: [
          Expanded(
            child: Text('남은 포인트 ${c.skillPointsLeft}',
                key: const Key('skillPointsLeft'),
                style: AppText.title(17, color: AppColors.goldBright)),
          ),
          TextButton(
              key: const Key('skillReset'),
              onPressed: () => _reset(context),
              child: const Text('다시 나누기')),
        ]),
      ),
      const SizedBox(height: 6),
      const KText('레벨이 오를 때마다 포인트가 생겨요. 새 스킬을 배우거나 배운 스킬을 강화해요.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 10),
      for (final j in jobs) ...[
        Text(
            '${j == c.mainJob ? '주 직업' : '보조 직업'} · ${JobRules.info(j).name}',
            style: AppText.title(16, color: AppColors.text)),
        const SizedBox(height: 2),
        KText('고유 기술 · ${JobRules.info(j).trait}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        for (final s in JobRules.info(j).skills)
          _SkillTile(controller: c, skill: s, sub: j != c.mainJob),
        const SizedBox(height: 10),
      ],
    ];
  }

  // ───────────── 숙련 스킬

  List<Widget> _masteryTab() {
    final owned = c.masterySkillsOwned;
    if (owned.isEmpty) {
      return const [
        KText('아직 익힌 숙련 스킬이 없어요. 같은 일을 되풀이하면 익혀요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ];
    }
    return [
      for (final m in Mastery.values)
        if (owned.where((x) => x.mastery == m).toList() case final list
            when list.isNotEmpty) ...[
          Text(m.label, style: AppText.title(16, color: AppColors.text)),
          const SizedBox(height: 4),
          for (final x in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OrnatePanel(
                key: Key('masterySkill_${x.key}'),
                child: Row(children: [
                  Icon(x.active ? Icons.auto_awesome : Icons.spa_rounded,
                      color: AppColors.goldBright, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(x.name,
                              style: AppText.title(15, color: AppColors.text)),
                          KText(x.text,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ]),
                  ),
                  if (x.active) const _Badge('전투'),
                ]),
              ),
            ),
          const SizedBox(height: 6),
        ],
    ];
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile(
      {required this.controller, required this.skill, required this.sub});

  final AppController controller;
  final JobSkill skill;
  final bool sub;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = JobRules.skill(skill);
    final lv = c.skillLevel(skill);
    final tree = JobRules.info(JobRules.jobOf(skill)).skills;
    final i = tree.indexOf(skill);
    final can = c.canRaiseSkill(skill);
    final open = lv > 0 || JobRules.canLearn(skill, c.skillLevel);
    final need = i == 3
        ? '${josa(JobRules.skill(tree[1]).name, '이나/나')} ${josa(JobRules.skill(tree[2]).name, '을/를')} Lv.2까지 올리면 배울 수 있어요'
        : '${josa(JobRules.skill(tree[0]).name, '을/를')} 먼저 배워요';
    final up = info.attack || info.isBattle ? '더 세져요' : 'MP가 덜 들어요';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: open ? 1 : 0.55,
        child: OrnatePanel(
          key: Key('jobSkillTile_${skill.name}'),
          highlight: lv > 0,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Text('${'①②③④'[i]} ',
                      style: const TextStyle(
                          color: AppColors.goldBright, fontSize: 15)),
                  Expanded(
                    child: Text(info.name,
                        style: AppText.title(15, color: AppColors.text)),
                  ),
                  if (info.isBattle) const _Badge('전투'),
                  const SizedBox(width: 6),
                  Text(lv > 0 ? 'Lv.$lv' : '아직',
                      style: TextStyle(
                          color: lv > 0
                              ? AppColors.goldBright
                              : AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 2),
                KText(info.text,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 2),
                Text('MP ${c.skillCost(skill, sub: sub)}',
                    style: const TextStyle(color: kJobMpColor, fontSize: 12)),
                if (!open)
                  KText(need,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                if (open && lv < JobRules.maxSkillLevel)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: Key('skillRaise_${skill.name}'),
                      onPressed: can
                          ? () async {
                              if (await c.raiseSkill(skill) &&
                                  context.mounted) {
                                showTopNotice(
                                    context,
                                    lv == 0
                                        ? '${josa(info.name, '을/를')} 배웠어요'
                                        : '${info.name} Lv.${lv + 1} · $up');
                              }
                            }
                          : null,
                      child: Text(lv == 0 ? '배우기' : '강화 · $up'),
                    ),
                  ),
              ]),
        ),
      ),
    );
  }
}

class _FixedRow extends StatelessWidget {
  const _FixedRow({required this.name, required this.text});

  final String name;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: OrnatePanel(
          child: Row(children: [
            const Icon(Icons.lock_outline_rounded,
                color: AppColors.textMuted, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppText.title(15, color: AppColors.text)),
                    KText(text,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ]),
            ),
          ]),
        ),
      );
}

class _TabChip extends StatelessWidget {
  const _TabChip(
      {super.key,
      required this.label,
      required this.on,
      required this.onTap,
      this.dot = false});

  final String label;
  final bool on;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: on ? const Color(0x33F2C14E) : const Color(0xCC14163A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: on ? AppColors.goldBright : AppColors.gold,
                width: on ? 1.6 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: on ? AppColors.goldBright : AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            if (dot) ...[
              const SizedBox(width: 4),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: AppColors.alert, shape: BoxShape.circle),
              ),
            ],
          ]),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0x33F2C14E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold),
        ),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.goldBright,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
}
