import 'dart:math' as math;

import 'skill_icon.dart';
import '../village/npc_header.dart';
import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../pets/pet_art.dart';
import 'job_skill_bar.dart';
import 'job_picker.dart';

/// 직업 하나의 짧은 소개 (고유 기술 한 줄 · 스킬 이름)
class JobSummary extends StatelessWidget {
  const JobSummary({super.key, required this.job, this.sub = false});

  final JobId job;

  /// 보조 직업으로 볼 때 (예전 호출과 맞춤)
  final bool sub;

  @override
  Widget build(BuildContext context) {
    final info = JobRules.info(job);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      KText(info.trait,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      // 묶음 76 #341
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text('잘 맞는 스탯 · ${info.mainStat.label}',
            key: Key('jobStat_${job.name}'),
            style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          const Icon(Icons.bolt_rounded, size: 15, color: kJobMpColor),
          const SizedBox(width: 3),
          Flexible(
            child: KText(
                [for (final s in info.skills) JobRules.skill(s).name].join(' · '),
                style: const TextStyle(color: AppColors.text, fontSize: 13)),
          ),
        ]),
      ),
    ]);
  }
}

/// 마을 「길드」 (묶음 30 #55, Lv.15 직업 각성 뒤): 얻은 직업, 주·보조 바꾸기(무료)
class GuildScreen extends StatefulWidget {
  const GuildScreen({super.key, required this.controller, this.glowSub = false});

  final AppController controller;

  /// 묶음 77 #357: Lv.20 보조 직업 카드에서 왔으면 빈 보조 칸이 세 번 빛남
  final bool glowSub;

  @override
  State<GuildScreen> createState() => _GuildScreenState();
}

class _GuildScreenState extends State<GuildScreen> {
  AppController get c => widget.controller;

  /// 처음 들어올 때 새 직업 (한 번 빛남)
  late final Set<JobId> _fresh = {
    for (final j in c.ownedJobs)
      if (c.jobIsNew(j)) j,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.markJobsSeen());
  }

  /// 바꾸기: 미리보기 → 확인 (묶음 57: 첫 번째 무료, 그 뒤 증표 1 + 금화)
  Future<void> _change(JobId main, JobId? sub) async {
    final pv = c.jobPreview(main, sub);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        key: const Key('jobPreview'),
        title: const Text('이렇게 바꿀까요?'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            JobEmblem(main, size: 40),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('주 ${JobRules.info(main).name}${sub == null ? '' : ' · 보조 ${JobRules.info(sub).name}'}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                pv.special
                    ? _Sparkle(child: Text(pv.name, key: const Key('jobPreviewName'), style: AppText.title(19, color: AppColors.goldBright)))
                    : Text(pv.name, key: const Key('jobPreviewName'), style: AppText.title(19, color: AppColors.goldBright)),
              ]),
            ),
          ]),
          if (pv.imprint != null) ...[
            const SizedBox(height: 8),
            KText('보조 각인 · ${pv.imprint}', style: const TextStyle(color: AppColors.text, fontSize: 13.5)),
          ],
          const SizedBox(height: 10),
          KText(
              pv.free
                  ? '첫 번째 바꾸기는 무료예요. 직업마다 키운 스킬은 그대로 남아요.'
                  : '전직의 증표 1장과 금화 ${JobPairRules.changeGold}이 들어요. 직업마다 키운 스킬은 그대로 남아요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('그만두기')),
          TextButton(key: const Key('jobChangeOk'), onPressed: () => Navigator.pop(d, true), child: const Text('바꾸기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await c.changeJobs(main, sub);
    if (!mounted) return;
    switch (r) {
      case JobChange.ok:
        showTopNotice(context, '이제 ${c.pairName ?? JobRules.info(main).name}예요');
      case JobChange.noToken:
        showTopNotice(context, '전직의 증표가 없어요. 많이 걷거나 조합 상점에서 구해요', icon: Icons.info_outline_rounded);
      case JobChange.noGold:
        showTopNotice(context, '금화가 모자라요', icon: Icons.info_outline_rounded);
      case JobChange.same:
      case JobChange.cannot:
        break;
    }
  }

  /// 묶음 77 #356: 고른 칸 (아래 판) · 탭
  JobId? _sel;
  JobGroup? _tab;

  Future<void> _tokenSheet() => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.night,
        builder: (s) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: ListenableBuilder(
              listenable: c,
              builder: (s, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('전직의 증표 ${c.jobTokens}장', key: const Key('guildTokenCount'), style: AppText.title(17)),
                const SizedBox(height: 4),
                KText(
                    c.jobChangeFree
                        ? '첫 번째 바꾸기는 무료예요. 그다음부터 증표 1장 + 금화 ${JobPairRules.changeGold}'
                        : '바꿀 때마다 증표 1장 + 금화 ${JobPairRules.changeGold} · 많이 걸으면 생겨요',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 10),
                GoldButton(
                  key: const Key('guildBuyToken'),
                  label: c.jobTokenBoughtThisWeek ? '이번 주에 샀어요' : '조합 상점에서 사기 · 금화 ${JobPairRules.tokenShopGold}',
                  onPressed: c.jobTokenBoughtThisWeek
                      ? null
                      : () async {
                          final ok = await c.buyJobToken();
                          if (!s.mounted) return;
                          showTopNotice(s, ok ? '전직의 증표를 샀어요' : '금화가 모자라요',
                              icon: ok ? Icons.verified_rounded : Icons.info_outline_rounded);
                        },
                ),
              ]),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        interior: 'guild', // 묶음 67 #272
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final main = c.mainJob;
            final sub = c.subJob;
            final open20 = c.subJobsOpen;
            final owned = c.ownedJobs.toSet();
            final hidden = [for (final j in JobPairRules.visibleHidden) if (owned.contains(j)) j];
            final tab = _tab ?? (main == null ? JobGroup.combat : JobPairRules.groupOf(main));
            final list = switch (tab) {
              JobGroup.craft => JobPairRules.craft,
              JobGroup.hidden => hidden,
              _ => JobPairRules.combat,
            };
            final sel = _sel ?? main;
            final hint = open20 ? c.seraPairHint : null;
            final found = {for (final p in c.foundPairs) p.id};
            bool star(JobId j) {
              if (!open20 || main == null || j == main) return false;
              final sp = JobPairRules.specialOf(main, j);
              return sp != null && found.contains(sp.id);
            }
            return Column(children: [
              Expanded(
                child: ListView(
                  key: const Key('guildScroll'),
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 12),
                  children: [
                    // 위: 뒤로 · 조합 + 증표 칩
                    Row(children: [
                      Expanded(child: OrnateTopBar(title: '조합', onBack: () => Navigator.of(context).maybePop())),
                      const SizedBox(width: 6),
                      GestureDetector(
                        key: const Key('guildTokenChip'),
                        onTap: _tokenSheet,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(4, 3, 9, 3),
                          decoration: BoxDecoration(
                            color: const Color(0xCC14163A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Image.asset('assets/images/item_jobToken.webp',
                                width: 22, height: 22,
                                errorBuilder: (_, __, ___) => const Icon(Icons.verified_rounded, color: AppColors.gold, size: 18)),
                            const SizedBox(width: 3),
                            Text(c.jobChangeFree ? '증표 ${c.jobTokens} · 첫 바꾸기 무료' : '증표 ${c.jobTokens}',
                                style: const TextStyle(color: AppColors.goldBright, fontSize: 11.5, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    // 묶음 80 #366: 다른 시설처럼 위 줄 → 마을 사람 머리줄(세라) (그림 띠 없음)
                    NpcHeader(
                      key: const Key('guildSeraLine'),
                      controller: c,
                      npc: Npc.sera,
                      situation: hint,
                      guide: open20
                          ? '주 직업 하나에 보조 직업 하나. 이명에 따라 이름도 힘도 달라지지.'
                          : '직업은 언제든 바꿀 수 있다. 한 길을 깊게 걸어 보거라.',
                    ),
                    const SizedBox(height: 8),
                    _myJob(main, sub, open20),
                    const SizedBox(height: 10),
                    // 탭 전투 6 · 생산 6 · 히든 (찾은 것만)
                    Row(children: [
                      for (final (g, n) in [
                        (JobGroup.combat, JobPairRules.combat.length),
                        (JobGroup.craft, JobPairRules.craft.length),
                        if (hidden.isNotEmpty) (JobGroup.hidden, hidden.length),
                      ]) ...[
                        Expanded(
                          child: GestureDetector(
                            key: Key('guildTab_${g.name}'),
                            onTap: () => setState(() => _tab = g),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: tab == g ? kGoldGradient : null,
                                color: tab == g ? null : const Color(0xCC14163A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.gold.withValues(alpha: tab == g ? 1 : 0.4)),
                              ),
                              child: Text('${g.label} $n',
                                  style: TextStyle(
                                      color: tab == g ? AppColors.goldInk : AppColors.text,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    GridView.count(
                      key: const Key('guildGrid'),
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.45,
                      children: [
                        for (final j in list)
                          _GuildCell(
                            key: Key('guildJob_${j.name}'),
                            job: j,
                            selected: j == sel,
                            ribbon: j == main
                                ? (open20 ? '주' : '지금')
                                : j == sub
                                    ? '보조'
                                    : null,
                            star: star(j),
                            fresh: _fresh.contains(j),
                            onTap: () => setState(() => _sel = j),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              // 아래 판 (화면 아래 고정)
              if (sel != null && main != null) _bottom(sel, main, sub, open20, pad.bottom),
            ]);
          },
        ),
      ),
    );
  }

  /// 「내 직업」 판
  Widget _myJob(JobId? main, JobId? sub, bool open20) {
    if (main == null) return const SizedBox.shrink();
    final info = JobRules.info(main);
    final sp = c.activePair;
    Widget slot(JobId? j, String label, {Key? key, bool glow = false}) {
      final empty = j == null;
      final box = Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: empty ? Colors.transparent : const Color(0x66101333),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: empty ? AppColors.gold.withValues(alpha: 0.5) : AppColors.gold.withValues(alpha: 0.8),
              width: empty ? 1.2 : 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (j != null) JobEmblem(j, size: 34) else const Icon(Icons.add_rounded, color: AppColors.gold, size: 26),
          const SizedBox(width: 6),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              Text(j == null ? '아래에서 고르기' : JobRules.info(j).name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: j == null ? AppColors.textMuted : AppColors.text,
                      fontSize: j == null ? 12.5 : 15,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      );
      if (!glow) return box;
      // 묶음 77 #357: 빈 보조 칸이 세 번 빛남
      return TweenAnimationBuilder<double>(
        key: const Key('guildSubGlow'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 2400),
        builder: (_, t, child) => DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [
            BoxShadow(
                color: AppColors.goldBright.withValues(alpha: t >= 1 ? 0 : 0.7 * math.sin(t * math.pi * 3).abs()),
                blurRadius: 16,
                spreadRadius: 2),
          ]),
          child: child,
        ),
        child: box,
      );
    }

    final dashed = sub == null;
    return OrnatePanel(
      key: const Key('guildMyJob'),
      highlight: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!open20)
          Row(children: [
            JobEmblem(main, size: 44),
            const SizedBox(width: 8),
            Expanded(
              child: Text('내 직업 · ${info.name}',
                  key: const Key('guildMain'), style: AppText.title(19, color: AppColors.goldBright)),
            ),
          ])
        else ...[
          Row(children: [
            Flexible(
              child: Text(c.pairName ?? info.name,
                  key: const Key('guildPair'), style: AppText.title(21, color: AppColors.goldBright)),
            ),
            if (sp != null && c.foundPairs.any((p) => p.id == sp.id)) ...[
              const SizedBox(width: 6),
              Container(
                key: const Key('guildPairStar'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(gradient: kGoldGradient, borderRadius: BorderRadius.circular(8)),
                child: const Text('★ 숨은 이명',
                    style: TextStyle(color: AppColors.goldInk, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: slot(main, '주 직업', key: const Key('guildMainSlot'))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.add_rounded, color: AppColors.goldBright, size: 20),
            ),
            Expanded(
                child: dashed
                    ? slot(null, '보조 직업', key: const Key('guildSub0'), glow: widget.glowSub)
                    : slot(sub, '보조 직업', key: const Key('guildSub0'))),
          ]),
        ],
        const SizedBox(height: 8),
        KText('고유 기술 · ${info.trait}',
            key: const Key('guildTrait'), style: const TextStyle(color: AppColors.text, fontSize: 13)),
        if (open20 && sub != null && c.imprintLine != null) ...[
          const SizedBox(height: 3),
          KText(
              '보조 각인${c.imprintDeep ? ' 2단계' : ''} · ${JobPairRules.imprintOf(sub).prefix} — ${c.imprintLine}',
              key: const Key('guildImprint'),
              style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
        ],
        if (open20 && sp != null && c.foundPairs.any((p) => p.id == sp.id)) ...[
          const SizedBox(height: 3),
          KText('숨은 이명 · ${sp.text}',
              key: const Key('guildSpecial'), style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
        ],
        const SizedBox(height: 3),
        Text('잘 맞는 스탯 · ${info.mainStat.label}',
            key: const Key('guildStat'),
            style: const TextStyle(color: AppColors.goldBright, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  /// 아래 판: 고른 직업 · 버튼
  Widget _bottom(JobId j, JobId main, JobId? sub, bool open20, double bottomPad) {
    final info = JobRules.info(j);
    final g = JobPairRules.groupOf(j);
    final pv = open20 && j != main ? c.jobPreview(main, j) : null;
    final chipColor = switch (g) {
      JobGroup.combat => const Color(0xFFE0645A),
      JobGroup.craft => const Color(0xFF6CC27A),
      _ => AppColors.goldBright,
    };
    Widget btn(String label, Key key, VoidCallback? onTap) => Expanded(
          child: GoldButton(key: key, label: label, height: 44, onPressed: onTap),
        );
    return Container(
      key: const Key('guildPick'),
      padding: EdgeInsets.fromLTRB(14, 10, 14, bottomPad + 8),
      decoration: BoxDecoration(
        color: const Color(0xF20B0D26),
        border: Border(top: BorderSide(color: AppColors.gold.withValues(alpha: 0.6))),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          JobEmblem(j, size: 36),
          const SizedBox(width: 8),
          Text(info.name, style: AppText.title(17, color: AppColors.goldBright)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: chipColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: chipColor),
            ),
            child: Text(g.label, style: TextStyle(color: chipColor, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          Text('잘 맞는 스탯 · ${info.mainStat.label}',
              style: const TextStyle(color: AppColors.goldBright, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 3),
        KText(info.trait, maxLines: 2, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        if (pv != null) ...[
          const SizedBox(height: 4),
          KText(
              pv.imprint == null
                  ? '보조로 달면 → ${pv.name}'
                  : '보조로 달면 → ${pv.name} · ${JobPairRules.imprintOf(j).prefix} 각인: ${pv.imprint}',
              key: const Key('guildPickPreview'),
              style: const TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 8),
        // 묶음 78 #359: 지금 내 직업(주 · 보조)을 골랐으면 버튼 대신 글
        if (j == main || (open20 && j == sub))
          Container(
            key: const Key('guildMine'),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: const Text('지금 내 직업이에요',
                style: TextStyle(color: AppColors.goldBright, fontSize: 14, fontWeight: FontWeight.w800)),
          )
        else if (!open20)
          Row(children: [
            btn('이 직업으로 바꾸기', const Key('jobAsMain'), () => _change(j, null)),
          ])
        else
          Row(children: [
            btn('주 직업으로', const Key('jobAsMain'), () => _change(j, sub)),
            const SizedBox(width: 8),
            btn('보조 직업으로', const Key('jobAsSub'), () => _change(main, j)),
          ]),
        const SizedBox(height: 4),
        const Text('바꾸기 · 첫 번째 무료 (그다음 증표 1장 + 금화 ${JobPairRules.changeGold})',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
      ]),
    );
  }
}

/// 묶음 77 #356: 조합 직업 칸 (직업 고르기와 같은 칸: 문장 · 이름 · 리본 · ★)
class _GuildCell extends StatelessWidget {
  const _GuildCell(
      {super.key,
      required this.job,
      required this.selected,
      required this.onTap,
      this.ribbon,
      this.star = false,
      this.fresh = false});

  final JobId job;
  final bool selected;
  final String? ribbon;
  final bool star;
  final bool fresh;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '${JobRules.info(job).name} 고르기',
        child: GestureDetector(
          onTap: onTap,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? AppColors.gold.withValues(alpha: 0.18) : const Color(0xCC14163A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected || fresh ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.35),
                      width: selected ? 2.2 : 1),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  JobEmblem(job, size: 36),
                  const SizedBox(height: 3),
                  Text(JobRules.info(job).name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: selected ? AppColors.goldBright : AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
            if (ribbon != null)
              Positioned(
                left: -2,
                top: -4,
                child: Container(
                  key: Key('guildRibbon_${job.name}'),
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(gradient: kGoldGradient, borderRadius: BorderRadius.circular(6)),
                  child: Text(ribbon!,
                      style: const TextStyle(color: AppColors.goldInk, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ),
            if (star)
              Positioned(
                right: 4,
                top: 2,
                child: Icon(Icons.star_rounded, key: Key('guildStar_${job.name}'), color: AppColors.goldBright, size: 18),
              ),
          ]),
        ),
      );
}

/// 특별 짝 미리보기의 반짝임
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        builder: (_, t, c) => DecoratedBox(
          decoration: BoxDecoration(boxShadow: [
            BoxShadow(color: AppColors.goldBright.withValues(alpha: 0.55 * (1 - (t - 0.5).abs() * 2)), blurRadius: 16),
          ]),
          child: c,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.goldBright, size: 18),
          const SizedBox(width: 4),
          child,
          const SizedBox(width: 4),
          const Icon(Icons.auto_awesome_rounded, color: AppColors.goldBright, size: 18),
        ]),
      );
}

/// Lv.15 직업 각성 (묶음 30 #55): 첫 펫 한마디 → 직업 고르기(묶음 76 #340 한 화면) → MP
class JobAwakenScreen extends StatefulWidget {
  const JobAwakenScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<JobAwakenScreen> createState() => _JobAwakenScreenState();
}

class _JobAwakenScreenState extends State<JobAwakenScreen> {
  AppController get c => widget.controller;
  int _step = 0;
  JobId? _main;
  late final bool _repick = c.jobRepick;

  /// 직업을 고른 순간 금빛 터짐 (묶음 35, 고를 때마다 1씩)
  int _burst = 0;

  /// 묶음 76 #340: 보조 직업 단계는 뺌 — 보조는 조합에서만 더한다
  Future<void> _finish() async {
    await c.awakenJob(_main!, subs: const []);
    if (mounted) {
      setState(() {
        _step = 3;
        _burst++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = c.voicePet;
    final Widget body = switch (_step) {
      0 => Column(mainAxisSize: MainAxisSize.min, children: [
          if (pet != null) PetArt.of(pet, size: 140),
          const SizedBox(height: 14),
          // 묶음 57: 개편 전 각성 계정은 다시 고르기 (한 번)
          if (_repick) ...[
            Text('직업이 새로 정리됐어요',
                key: const Key('jobRepickTitle'),
                textAlign: TextAlign.center,
                style: AppText.title(21, color: AppColors.goldBright)),
            const SizedBox(height: 10),
          ],
          _Bubble(
              name: c.companionName,
              line: _repick
                  ? '조합의 직업이 전투 · 생산 · 히든으로 다시 나뉘었어. 주 직업 하나를 대가 없이 새로 골라 봐! 쓴 스킬 포인트도 모두 돌려받았어.'
                  : JobRules.awakenLine),
          const SizedBox(height: 22),
          GoldButton(
              key: const Key('jobAwakenGo'),
              label: '조합에 가기',
              onPressed: () => setState(() => _step = 1)),
        ]),
      1 => JobPicker(
          controller: c,
          onPick: (j) {
            _main = j;
            _finish();
          }),
      _ => Column(mainAxisSize: MainAxisSize.min, children: [
          if (pet != null) PetArt.of(pet, size: 120),
          const SizedBox(height: 12),
          Text('${c.pairName ?? c.mainJobLabel ?? ''}의 길이 열렸어요!',
              textAlign: TextAlign.center,
              style: AppText.title(21, color: AppColors.goldBright)),
          const SizedBox(height: 10),
          const KText('직업 스킬에 쓰는 MP가 생겼어요. 걸으면 차고, 여관에서 쉬거나 레벨이 오르면 가득 차요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 10),
          JobMpBar(controller: c),
          const SizedBox(height: 22),
          GoldButton(
              key: const Key('jobAwakenDone'),
              label: '좋아요',
              onPressed: () => Navigator.of(context).pop()),
        ]),
    };
    return PopScope(
      canPop: _step == 3,
      child: Scaffold(
        key: const Key('jobAwakenScreen'),
        backgroundColor: AppColors.deepNight,
        // 묶음 35: 각성 배경 (가운데가 밝아 카드가 잘 읽히게 살짝 어둡게) + 고를 때 금빛 터짐
        body: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/images/bg_job_awaken.webp',
              key: const Key('jobAwakenBg'),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.deepNight)),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.9,
                colors: [Color(0x99060818), Color(0x66060818)],
              ),
            ),
          ),
          SafeArea(
            child: _step == 1
                // 묶음 76 #340: 한 화면 (가운데만 내려감, 아래 버튼 고정)
                ? Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), child: body)
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                      child: body,
                    ),
                  ),
          ),
          if (_burst > 0)
            IgnorePointer(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('burst$_burst'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1000),
                builder: (context, k, _) => k >= 1
                    ? const SizedBox.shrink()
                    : Center(
                        child: Opacity(
                          opacity: (1 - k) * (k < 0.15 ? k / 0.15 : 1),
                          child: Transform.scale(
                            scale: 0.6 + 0.8 * Curves.easeOut.transform(k),
                            child: Image.asset('assets/images/fx_job_awaken.webp',
                                key: const Key('jobAwakenFx'),
                                width: 360,
                                errorBuilder: (_, __, ___) => const SizedBox()),
                          ),
                        ),
                      ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.name, required this.line});

  final String name;
  final String line;

  @override
  Widget build(BuildContext context) => OrnatePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(name,
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            KText(line,
                style: const TextStyle(
                    color: AppColors.text, fontSize: 16, height: 1.45)),
          ],
        ),
      );
}
