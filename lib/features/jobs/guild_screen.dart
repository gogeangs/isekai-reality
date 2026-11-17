import '../village/npc_header.dart';
import 'skill_icon.dart';
import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../bulssi/bulssi_bubble.dart';
import '../pets/pet_art.dart';
import 'job_skill_bar.dart';

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
  const GuildScreen({super.key, required this.controller});

  final AppController controller;

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

  Future<void> _pickFor(JobId j) async {
    final main = c.mainJob, sub = c.subJob;
    final pick = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.night,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (j != main)
            ListTile(
                key: const Key('jobAsMain'),
                title: Text('주 직업으로 · ${JobRules.info(j).name}', style: const TextStyle(color: AppColors.text)),
                onTap: () => Navigator.of(s).pop(0)),
          if (j != sub && j != main)
            ListTile(
                key: const Key('jobAsSub'),
                title: Text('보조 직업으로 · ${JobRules.info(j).name}', style: const TextStyle(color: AppColors.text)),
                onTap: () => Navigator.of(s).pop(1)),
        ]),
      ),
    );
    if (pick == null || main == null) return;
    if (pick == 0) {
      await _change(j, sub == j ? main : sub);
    } else {
      await _change(main, j);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final main = c.mainJob;
            final sub = c.subJob;
            final owned = c.ownedJobs.toSet();
            final hint = c.seraPairHint;
            Widget group(JobGroup g, List<JobId> list) {
              final shown = [for (final j in list) if (owned.contains(j)) j];
              if (shown.isEmpty) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 12),
                Text('${g.label} 직업', style: AppText.title(16)),
                const SizedBox(height: 6),
                for (final j in shown)
                  _JobCard(
                    key: Key('guildJob_${j.name}'),
                    job: j,
                    fresh: _fresh.contains(j),
                    isMain: j == main,
                    isSub: j == sub,
                    apprentice: false,
                    canSub: false,
                    onMain: () => _pickFor(j),
                    onSub: () {},
                  ),
              ]);
            }

            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 30),
              children: [
                OrnateTopBar(
                    title: '조합', onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 6),
                // 묶음 35: 길드 홀 그림 (띠처럼) + 길드장 세라
                ClipRRect(
                  key: const Key('guildHall'),
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 110,
                    child: Image.asset('assets/images/guild_hall.webp',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.1),
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),
                const SizedBox(height: 8),
                NpcHeader(controller: c, npc: Npc.sera),
                const SizedBox(height: 8),
                SpiritBadgeRow(
                    key: const Key('guildGreeting'),
                    line: hint ?? '주 직업 하나에 보조 직업 하나. 짝에 따라 이름도 힘도 달라져!'),
                const SizedBox(height: 10),
                OrnatePanel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          if (main != null) ...[
                            JobEmblem(main, size: 44),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.pairName ?? '-',
                                  key: const Key('guildPair'),
                                  style: AppText.title(19, color: AppColors.goldBright)),
                              Text('주 직업 · ${c.mainJobLabel ?? '-'}',
                                  key: const Key('guildMain'),
                                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
                              Text('보조 직업 · ${sub == null ? '비어 있음' : JobRules.info(sub).name}',
                                  key: const Key('guildSub0'),
                                  style: const TextStyle(color: AppColors.text, fontSize: 14)),
                            ]),
                          ),
                        ]),
                        if (main != null) ...[
                          const SizedBox(height: 6),
                          JobSummary(job: main),
                        ],
                        if (c.imprintLine != null) ...[
                          const SizedBox(height: 6),
                          KText('보조 각인${c.imprintDeep ? ' 2단계' : ''} · ${c.imprintLine}',
                              key: const Key('guildImprint'),
                              style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
                        ],
                        if (c.activePair != null) ...[
                          const SizedBox(height: 4),
                          KText('숨은 짝 · ${c.activePair!.text}',
                              key: const Key('guildSpecial'),
                              style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
                        ],
                        const SizedBox(height: 8),
                        JobMpBar(controller: c),
                      ]),
                ),
                const SizedBox(height: 8),
                // 전직의 증표 · 조합 상점 (주에 1장)
                OrnatePanel(
                  key: const Key('guildTokens'),
                  child: Row(children: [
                    Image.asset('assets/images/item_jobToken.webp',
                        width: 36,
                        height: 36,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.verified_rounded, color: AppColors.gold, size: 30)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('전직의 증표 ${c.jobTokens}장',
                            key: const Key('guildTokenCount'),
                            style: AppText.title(15, color: AppColors.text)),
                        KText(
                            c.jobChangeFree
                                ? '첫 번째 바꾸기는 무료예요'
                                : '바꿀 때마다 증표 1장 + 금화 ${JobPairRules.changeGold}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                      ]),
                    ),
                    TextButton(
                      key: const Key('guildBuyToken'),
                      onPressed: c.jobTokenBoughtThisWeek
                          ? null
                          : () async {
                              final ok = await c.buyJobToken();
                              if (!context.mounted) return;
                              showTopNotice(context,
                                  ok ? '전직의 증표를 샀어요' : '금화가 모자라요',
                                  icon: ok ? Icons.verified_rounded : Icons.info_outline_rounded);
                            },
                      child: Text(c.jobTokenBoughtThisWeek ? '이번 주 삼' : '금화 ${JobPairRules.tokenShopGold}'),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                const KText('스킬은 상태 → 스킬에서 배우고 강화해요. 직업을 바꿔도 키운 것은 그대로예요.',
                    key: Key('guildSkillNote'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                if (c.foundPairs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('찾은 숨은 짝 ${c.foundPairs.length}', style: AppText.title(16)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in c.foundPairs)
                      Chip(
                        key: Key('guildPairFound_${p.id}'),
                        label: Text(p.name),
                        backgroundColor: const Color(0x33F2C14E),
                      ),
                  ]),
                ],
                group(JobGroup.combat, JobPairRules.combat),
                group(JobGroup.craft, JobPairRules.craft),
                group(JobGroup.hidden, JobPairRules.hidden),
              ],
            );
          },
        ),
      ),
    );
  }
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

class _JobCard extends StatelessWidget {
  const _JobCard({
    super.key,
    required this.job,
    required this.fresh,
    required this.isMain,
    required this.isSub,
    required this.apprentice,
    required this.canSub,
    required this.onMain,
    required this.onSub,
  });

  final JobId job;
  final bool fresh, isMain, isSub, apprentice, canSub;
  final VoidCallback onMain, onSub;

  @override
  Widget build(BuildContext context) {
    final info = JobRules.info(job);
    final card = OrnatePanel(
      highlight: isMain || fresh,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          JobEmblem(job, size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Text(apprentice ? '견습 ${info.name}' : info.name,
                style: AppText.title(16, color: AppColors.text)),
          ),
          if (isMain)
            const _Tag('주 직업')
          else if (isSub)
            const _Tag('보조'),
        ]),
        const SizedBox(height: 4),
        JobSummary(job: job, sub: isSub),
        if (!isMain) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                key: Key('jobChange_${job.name}'),
                onPressed: onMain,
                child: Text(isSub ? '주 직업으로 바꾸기' : '이 직업으로 바꾸기')),
          ),
        ],
      ]),
    );
    final out = Padding(padding: const EdgeInsets.only(bottom: 10), child: card);
    if (!fresh) return out;
    // 처음 보는 직업은 금빛으로 한 번 빛난다
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1, end: 0),
      duration: const Duration(milliseconds: 1600),
      builder: (_, t, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: AppColors.goldBright.withValues(alpha: 0.6 * t),
                blurRadius: 18 * t),
          ],
        ),
        child: child,
      ),
      child: out,
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x33F2C14E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold),
        ),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.goldBright,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      );
}

/// Lv.15 직업 각성 (묶음 30 #55): 첫 펫 한마디 → 직업 고르기(추천 맨 위) → 보조(건너뛰기) → MP
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
  JobId? _sub;
  late final List<JobId> _choices = c.jobChoices;
  late final bool _apprentice = c.jobStartsApprentice;
  late final JobId _rec = c.recommendedJob;
  late final bool _repick = c.jobRepick;

  /// 직업을 고른 순간 금빛 터짐 (묶음 35, 고를 때마다 1씩)
  int _burst = 0;

  void _pick(JobId j) => setState(() {
        _main = j;
        _burst++;
      });

  Future<void> _finish() async {
    await c.awakenJob(_main!, subs: [if (_sub != null) _sub!]);
    if (mounted) setState(() => _step = 3);
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
                  ? '조합의 직업이 전투 · 생산 · 히든으로 다시 나뉘었어. 주 직업 하나와 보조 직업 하나를 대가 없이 새로 골라 봐! 쓴 스킬 포인트도 모두 돌려받았어.'
                  : JobRules.awakenLine),
          const SizedBox(height: 22),
          GoldButton(
              key: const Key('jobAwakenGo'),
              label: '조합에 가기',
              onPressed: () => setState(() => _step = 1)),
        ]),
      1 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('직업 고르기', style: AppText.title(22, color: AppColors.goldBright)),
          const SizedBox(height: 6),
          KText(
              _apprentice
                  ? '아직 열린 직업이 없어요. 가장 익숙한 일의 견습으로 시작해요. 그 일에 더 익숙해지면 견습을 떼요.'
                  : '주 직업 하나를 골라요. 전투 · 생산 직업은 처음엔 자유롭게 고를 수 있고, 「추천」은 지금까지 해 온 일에서 골랐어요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 12),
          for (final j in _choices)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                key: Key('jobPick_${j.name}'),
                onTap: () => _pick(j),
                child: OrnatePanel(
                  highlight: _main == j,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          // 묶음 35: 직업 문장
                          JobEmblem(j, size: 40),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                                _apprentice
                                    ? '견습 ${JobRules.info(j).name}'
                                    : JobRules.info(j).name,
                                style: AppText.title(17, color: AppColors.text)),
                          ),
                          if (j == _rec) const _Tag('추천'),
                        ]),
                        const SizedBox(height: 4),
                        JobSummary(job: j),
                      ]),
                ),
              ),
            ),
          const SizedBox(height: 8),
          GoldButton(
              key: const Key('jobPickMain'),
              label: '이 길로 갈래요',
              onPressed: _main == null
                  ? null
                  : () {
                      final rest = _choices.where((x) => x != _main).toList();
                      if (rest.isEmpty || c.subJobSlots <= 0) {
                        _finish();
                      } else {
                        setState(() => _step = 2);
                      }
                    }),
        ]),
      2 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('보조 직업', style: AppText.title(22, color: AppColors.goldBright)),
          const SizedBox(height: 6),
          const KText('보조 직업은 주 직업에 각인을 하나 새기고, 그 직업 스킬도 쓸 수 있어요. 짝에 따라 이름이 달라져요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          if (_main != null && _sub != null) ...[
            const SizedBox(height: 8),
            Text(c.jobPreview(_main!, _sub).name,
                key: const Key('jobAwakenPair'),
                textAlign: TextAlign.center,
                style: AppText.title(18, color: AppColors.goldBright)),
          ],
          const SizedBox(height: 12),
          for (final j in _choices)
            if (j != _main)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  key: Key('jobSub_${j.name}'),
                  onTap: () => setState(() => _sub = _sub == j ? null : j),
                  child: OrnatePanel(
                    highlight: _sub == j,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            JobEmblem(j, size: 36),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(JobRules.info(j).name,
                                  style: AppText.title(17, color: AppColors.text)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          JobSummary(job: j, sub: true),
                        ]),
                  ),
                ),
              ),
          const SizedBox(height: 8),
          GoldButton(
              key: const Key('jobPickSub'),
              label: _sub == null ? '건너뛰기' : '이렇게 할래요',
              onPressed: _finish),
        ]),
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
            child: Center(
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
