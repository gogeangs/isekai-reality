import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../status/status_screen.dart' show heroBaseAsset;
import 'skill_icon.dart';

/// 묶음 76 #340: 스킬을 쓰는 곳 (칩 글)
String skillPlaceLabel(SkillPlace p) => switch (p) {
      SkillPlace.battle => '전투',
      SkillPlace.map || SkillPlace.nightMap => '지도',
      SkillPlace.anywhere => '어디서나',
      SkillPlace.harvest || SkillPlace.relic => '채집할 때',
      SkillPlace.alchemy => '가마솥',
      SkillPlace.shop => '가게',
      SkillPlace.lens => '감정 렌즈',
      SkillPlace.smithyEnhance || SkillPlace.smithyCraft || SkillPlace.smithyWork => '대장간',
      SkillPlace.board => '의뢰판',
      SkillPlace.petExpedition || SkillPlace.expeditionSend => '펫 원정',
      SkillPlace.passive => '늘 켜짐',
    };

/// 묶음 76 #340: Lv.15 「직업 고르기」 한 화면 — 미리보기 카드 · 추천 이유 · 전투/생산 탭 · 3칸 격자 · 스킬 판 · 아래 고정 버튼
class JobPicker extends StatefulWidget {
  const JobPicker({super.key, required this.controller, required this.onPick});

  final AppController controller;
  final ValueChanged<JobId> onPick;

  @override
  State<JobPicker> createState() => _JobPickerState();
}

class _JobPickerState extends State<JobPicker> {
  AppController get c => widget.controller;
  late final JobId _rec = c.recommendedJob;
  late final String _reason = c.recommendReason;
  late JobId _job = _rec;
  late bool _combatTab = JobPairRules.combat.contains(_rec);
  JobSkill? _skill;

  bool _combat(JobId j) => JobPairRules.combat.contains(j);

  void _choose(JobId j) => setState(() {
        _job = j;
        _skill = null;
      });

  @override
  Widget build(BuildContext context) {
    final info = JobRules.info(_job);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 1. 제목 — 어두운 판 위 글
      Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: const Color(0xE60B0D26),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('직업 고르기', key: const Key('jobPickTitle'), style: AppText.title(21, color: AppColors.goldBright)),
          const SizedBox(height: 2),
          const Text('주 직업 하나를 골라요. 나중에 조합에서 바꿀 수 있어요.',
              style: TextStyle(color: AppColors.text, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: SingleChildScrollView(
          key: const Key('jobPickScroll'),
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _preview(info),
            const SizedBox(height: 6),
            _reasonBand(),
            const SizedBox(height: 8),
            _tabs(),
            const SizedBox(height: 8),
            _grid(),
            const SizedBox(height: 10),
            _skills(info),
          ]),
        ),
      ),
      // 7. 아래 고정 버튼
      const SizedBox(height: 6),
      GoldButton(
        key: const Key('jobPickMain'),
        label: '${josa(info.name, '으로/로')} 시작할래요',
        onPressed: () => widget.onPick(_job),
      ),
    ]);
  }

  // 2. 미리보기 카드
  Widget _preview(JobInfo info) {
    final art = JobRules.heroArtJob(_job)?.name;
    final combat = _combat(_job);
    final weapons = [
      for (final w in JobPairRules.preferredWeapons(_job)) MasteryRules.weaponLabels[w] ?? w,
    ];
    return OrnatePanel(
      key: const Key('jobPreview'),
      highlight: true,
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 8),
      child: SizedBox(
        height: 150,
        child: Row(children: [
          SizedBox(
            width: 104,
            child: Image.asset(heroBaseAsset(c.profile.look, job: art),
                key: Key('jobPreviewHero_${art ?? 'base'}'),
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.7),
                errorBuilder: (_, __, ___) => JobEmblem(_job, size: 80)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    _chip(combat ? '전투' : '생산', color: combat ? const Color(0xFFE0645A) : const Color(0xFF6CC27A)),
                    if (_job == _rec) _chip('추천', gold: true, key: const Key('jobPreviewRec')),
                  ]),
                  const SizedBox(height: 4),
                  Text(info.name, key: const Key('jobPreviewName'), style: AppText.title(24, color: AppColors.goldBright)),
                  Text(combat ? '이 직업 차림으로 싸워요' : '전투 땐 가까운 전투 직업 차림이에요',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 4, runSpacing: 4, children: [
                    _chip('잘 맞는 스탯 · ${info.mainStat.label}', gold: true, fill: true, key: const Key('jobPreviewStat')),
                    _chip(combat && weapons.isNotEmpty ? '잘 맞는 무기 · ${weapons.join('·')}' : '공격 스킬 2개로도 싸워요'),
                  ]),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String t, {bool gold = false, bool fill = false, Color? color, Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: fill
              ? AppColors.gold.withValues(alpha: 0.85)
              : color?.withValues(alpha: 0.18) ?? const Color(0x22000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color ?? (gold ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.6))),
        ),
        child: Text(t,
            style: TextStyle(
                color: fill ? AppColors.goldInk : color ?? (gold ? AppColors.goldBright : AppColors.text),
                fontSize: 11.5,
                fontWeight: FontWeight.w800)),
      );

  // 3. 추천 이유 띠
  Widget _reasonBand() {
    final onRec = _job == _rec;
    final text = onRec
        ? '✦ 추천 이유 · $_reason'
        : '✦ 추천은 ${JobRules.info(_rec).name} · $_reason';
    return GestureDetector(
      key: const Key('jobRecBand'),
      onTap: onRec
          ? null
          : () => setState(() {
                _job = _rec;
                _skill = null;
                _combatTab = _combat(_rec);
              }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xCC1A1638),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          if (!onRec)
            const Text(' 보기 ›', style: TextStyle(color: AppColors.gold, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  // 4. 탭
  Widget _tabs() {
    Widget tab(bool combat, String label) {
      final on = _combatTab == combat;
      final dot = _combat(_rec) == combat && _combatTab != combat;
      return Expanded(
        child: GestureDetector(
          key: Key(combat ? 'jobTabCombat' : 'jobTabCraft'),
          onTap: () => setState(() => _combatTab = combat),
          child: Container(
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: on ? kGoldGradient : null,
              color: on ? null : const Color(0xCC14163A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.gold.withValues(alpha: on ? 1 : 0.4)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: TextStyle(
                      color: on ? AppColors.goldInk : AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
              if (dot) ...[
                const SizedBox(width: 5),
                Container(
                  key: Key('jobTabDot_${combat ? 'combat' : 'craft'}'),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.goldBright, shape: BoxShape.circle),
                ),
              ],
            ]),
          ),
        ),
      );
    }

    return Row(children: [
      tab(true, '전투 ${JobPairRules.combat.length}'),
      const SizedBox(width: 8),
      tab(false, '생산 ${JobPairRules.craftShown(c.ownedJobs.toSet()).length}'),
    ]);
  }

  // 5. 3칸 격자
  Widget _grid() {
    final list = _combatTab ? JobPairRules.combat : JobPairRules.craftShown(c.ownedJobs.toSet());
    return GridView.count(
      key: const Key('jobGrid'),
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.45,
      children: [
        for (final j in list)
          Semantics(
            button: true,
            label: '${JobRules.info(j).name} 고르기',
            child: GestureDetector(
              key: Key('jobPick_${j.name}'),
              onTap: () => _choose(j),
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: j == _job ? AppColors.gold.withValues(alpha: 0.18) : const Color(0xCC14163A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: j == _job ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.35),
                          width: j == _job ? 2.2 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      JobEmblem(j, size: 36),
                      const SizedBox(height: 3),
                      Text(JobRules.info(j).name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: j == _job ? AppColors.goldBright : AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
                if (j == _rec)
                  Positioned(
                    right: -2,
                    top: -4,
                    child: Container(
                      key: Key('jobRecRibbon_${j.name}'),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(gradient: kGoldGradient, borderRadius: BorderRadius.circular(6)),
                      child: const Text('추천',
                          style: TextStyle(color: AppColors.goldInk, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ]),
            ),
          ),
      ],
    );
  }

  // 6. 스킬 판
  Widget _skills(JobInfo info) {
    final skills = info.skills.take(7).toList();
    final first = JobRules.firstOf(_job);
    final sel = _skill;
    final selInfo = sel == null ? null : JobRules.skill(sel);
    return OrnatePanel(
      key: const Key('jobSkills'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text('액티브 ${skills.length} · MP · ${josa(info.mainStat.label, '으로/로')} 세져요',
                key: const Key('jobSkillsHead'),
                style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
          ),
          _legend(const Color(0xFFE0645A), '전투'),
          const SizedBox(width: 6),
          _legend(const Color(0xFF6CC27A), '생활'),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, box) {
          final cell = (box.maxWidth / 7).clamp(40.0, 56.0);
          return Row(
            mainAxisAlignment: skills.length >= 6 ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in skills)
                Semantics(
                  button: true,
                  label: '${JobRules.skill(s).name} 스킬',
                  child: GestureDetector(
                    key: Key('jobSkill_${s.name}'),
                    onTap: () => setState(() => _skill = _skill == s ? null : s),
                    child: SizedBox(
                      width: cell,
                      child: Column(children: [
                        Stack(clipBehavior: Clip.none, children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: s == sel ? Border.all(color: AppColors.goldBright, width: 2) : null,
                            ),
                            child: SkillArt.jobIcon(s, size: cell - 6),
                          ),
                          if (s == first)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                width: 15,
                                height: 15,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(gradient: kGoldGradient, shape: BoxShape.circle),
                                child: const Text('1',
                                    style: TextStyle(color: AppColors.goldInk, fontSize: 10, fontWeight: FontWeight.w900)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 2),
                        Text(JobRules.skill(s).name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: s == sel ? AppColors.goldBright : AppColors.text,
                                fontSize: 10,
                                height: 1.1,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
            ],
          );
        }),
        if (selInfo != null) ...[
          const SizedBox(height: 8),
          Container(
            key: const Key('jobSkillDetail'),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0x66101333),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 2, children: [
                Text(selInfo.name, style: AppText.title(15, color: AppColors.goldBright)),
                _chip(skillPlaceLabel(selInfo.place),
                    color: selInfo.isBattle ? const Color(0xFFE0645A) : const Color(0xFF6CC27A)),
                Text(sel == first ? '처음부터 열려요' : '스킬 포인트로 열어요',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ]),
              const SizedBox(height: 3),
              KText(selInfo.text, style: const TextStyle(color: AppColors.text, fontSize: 13)),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Divider(height: 1, color: AppColors.gold.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(alignment: Alignment.center, children: [
              Image.asset('assets/images/skill_frame_passive.webp',
                  width: 44, height: 44, errorBuilder: (_, __, ___) => const SizedBox()),
              JobEmblem(_job, size: 28),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('패시브 · 고유 기술 · 늘 켜져 있어요',
                  style: TextStyle(color: AppColors.goldBright, fontSize: 12, fontWeight: FontWeight.w800)),
              KText(info.trait, key: const Key('jobTrait'), style: const TextStyle(color: AppColors.text, fontSize: 13)),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 2)),
        ),
        const SizedBox(width: 3),
        Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      ]);
}
