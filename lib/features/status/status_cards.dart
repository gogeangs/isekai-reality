import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../jobs/skill_icon.dart';
import '../jobs/skill_screen.dart' show SkillMasterFrame;
import 'stat_icon.dart';

/// 묶음 77 #355: 상태 화면 스탯 · 스킬 = 같은 높이 카드 둘 나란히
class StatusCards extends StatelessWidget {
  const StatusCards({super.key, required this.controller, this.onOpenStats, this.onOpenSkills});

  final AppController controller;
  final VoidCallback? onOpenStats;
  final VoidCallback? onOpenSkills;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _StatCard(c: controller, onTap: onOpenStats)),
          const SizedBox(width: 8),
          Expanded(child: _SkillCard(c: controller, onTap: onOpenSkills)),
        ]),
      );
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.title, required this.busy, required this.child, this.onTap, this.badge});

  final String title;
  final bool busy;
  final Widget child;
  final Widget? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xCC14163A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: busy ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.45), width: busy ? 2 : 1),
            boxShadow: busy ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 12)] : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text(title, style: AppText.title(15, color: AppColors.text)),
              const Spacer(),
              if (badge != null) badge!,
              if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.goldBright, size: 20),
            ]),
            const SizedBox(height: 4),
            Expanded(child: child),
          ]),
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.c, this.onTap});

  final AppController c;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final stats = c.shownStats;
    final main = c.mainJob;
    final mainStat = main == null ? null : JobRules.mainStat(main);
    final unspent = c.unspentPoints;
    final open = c.player.level.level >= 2;
    return _Card(
      key: const Key('statsOpen'),
      title: '스탯',
      busy: open && unspent > 0,
      onTap: open ? onTap : null,
      badge: open && unspent > 0
          ? Container(
              key: const Key('statsSplit'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: AppColors.alert, borderRadius: BorderRadius.circular(8)),
              child: Text('+$unspent 나누기',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
            )
          : null,
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final k in StatKind.values)
          Row(children: [
            StatIcon(k, size: 22, color: k == mainStat ? AppColors.goldBright : AppColors.textMuted),
            const SizedBox(width: 5),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: k.label),
                  if (k == mainStat)
                    TextSpan(
                        text: ' · ${JobRules.info(main!).name}',
                        style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                ]),
                key: Key('statCard_${k.name}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: k == mainStat ? AppColors.goldBright : AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Text('${stats.of(k)}',
                style: TextStyle(
                    color: k == mainStat ? AppColors.goldBright : AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
          ]),
      ]),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({required this.c, this.onTap});

  final AppController c;
  final VoidCallback? onTap;

  String _id(String e) {
    if (e.startsWith('job:')) return e.substring(4);
    if (e.startsWith('mastery:')) return 'm_${e.substring(8)}';
    return e;
  }

  Widget _cell(Widget art, String name, {String? id}) => Column(mainAxisSize: MainAxisSize.min, children: [
        SkillMasterFrame(
          id: id ?? name,
          stage: id == null ? null : c.skillStageOf(id),
          child: SizedBox(width: 40, height: 40, child: Center(child: art)),
        ),
        const SizedBox(height: 2),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.text, fontSize: 10.5, fontWeight: FontWeight.w700)),
      ]);

  Widget _btn(String art) => Image.asset('assets/images/$art.webp',
      width: 38, height: 38, errorBuilder: (_, __, ___) => const Icon(Icons.bolt_rounded, color: AppColors.gold));

  @override
  Widget build(BuildContext context) {
    final open = c.skillPageOpen;
    final points = c.skillPointsLeft;
    final slots = open ? (c.fourSlots ? c.battleSlots : c.battleLoadout) : const <String>[];
    Widget slot(int i) {
      if (i >= slots.length) return _cell(_btn('btn_skill_empty'), '빈 칸');
      final e = slots[i];
      // 묶음 85 #420: 각성 뒤 강타 · 방어 태세도 칸에
      if (e == 'base:bash') return _cell(_btn('btn_strike'), '강타', id: 'bash');
      if (e == 'base:stance') return _cell(_btn('btn_guard'), '방어 태세', id: 'stance');
      if (e.startsWith('job:')) {
        final s = JobRules.parseSkill(e.substring(4));
        if (s != null) return _cell(SkillArt.jobIcon(s, size: 38), JobRules.skill(s).name, id: _id(e));
      }
      final m = Mastery.values.where((x) => 'mastery:${x.name}' == e).firstOrNull;
      if (m != null) {
        return _cell(SkillArt.masteryIcon(m, active: true, size: 38), JobRules.masteryActive(m).name, id: _id(e));
      }
      return _cell(_btn('btn_skill_empty'), '빈 칸');
    }

    return _Card(
      key: const Key('skillsOpen'),
      title: '스킬',
      busy: open && c.skillRaisable,
      onTap: open ? onTap : null,
      badge: open && c.skillRaisable
          ? Container(
              key: const Key('skillsDot'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(gradient: kGoldGradient, borderRadius: BorderRadius.circular(8)),
              child: Text('포인트 $points',
                  style: const TextStyle(color: AppColors.goldInk, fontSize: 11.5, fontWeight: FontWeight.w800)),
            )
          : null,
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Expanded(child: c.fourSlots ? slot(2) : _cell(_btn('btn_strike'), '강타', id: 'bash')),
          Expanded(child: c.fourSlots ? slot(3) : _cell(_btn('btn_guard'), '방어 태세', id: 'stance')),
        ]),
        if (open)
          Row(children: [
            Expanded(child: slot(0)),
            Expanded(child: slot(1)),
          ])
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Lv.${JobRules.awakenLevel}에 열려요',
                key: Key('skillsLocked'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        Text(open ? '전투에 가져가는 4칸' : '전투에 가져가는 스킬',
            textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
      ]),
    );
  }
}
