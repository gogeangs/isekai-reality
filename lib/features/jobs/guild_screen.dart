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

  Future<void> _setMain(JobId j) async {
    await c.setMainJob(j);
    if (mounted) {
      showTopNotice(context, '주 직업 · ${c.mainJobLabel ?? JobRules.info(j).name}');
    }
  }

  Future<void> _setSub(JobId j) async {
    final slots = c.subJobSlots;
    final subs = c.subJobs;
    var i = subs.length < slots ? subs.length : 0;
    if (subs.contains(j)) {
      await c.setSubJob(subs.indexOf(j), null);
      return;
    }
    if (subs.length >= slots && slots > 1 && mounted) {
      final pick = await showModalBottomSheet<int>(
        context: context,
        backgroundColor: AppColors.night,
        builder: (s) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var k = 0; k < slots; k++)
              ListTile(
                title: Text(
                    '보조 ${k + 1} · ${JobRules.info(subs[k]).name} 대신',
                    style: const TextStyle(color: AppColors.text)),
                onTap: () => Navigator.of(s).pop(k),
              ),
          ]),
        ),
      );
      if (pick == null) return;
      i = pick;
    }
    await c.setSubJob(i, j);
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
            final subs = c.subJobs;
            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 30),
              children: [
                OrnateTopBar(
                    title: '길드', onBack: () => Navigator.of(context).maybePop()),
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
                const SpiritBadgeRow(
                    key: Key('guildGreeting'),
                    line: '직업은 언제든 바꿀 수 있어. 마음 가는 길을 골라 봐!'),
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
                            child: Text('주 직업 · ${c.mainJobLabel ?? '-'}',
                                key: const Key('guildMain'),
                                style: AppText.title(18,
                                    color: AppColors.goldBright)),
                          ),
                        ]),
                        if (main != null) ...[
                          const SizedBox(height: 4),
                          JobSummary(job: main),
                        ],
                        const SizedBox(height: 10),
                        for (var i = 0; i < c.subJobSlots; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                                '보조 ${i + 1} · ${i < subs.length ? JobRules.info(subs[i]).name : '비어 있음'}',
                                key: Key('guildSub$i'),
                                style: const TextStyle(
                                    color: AppColors.text, fontSize: 14)),
                          ),
                        const SizedBox(height: 8),
                        JobMpBar(controller: c),
                      ]),
                ),
                const SizedBox(height: 6),
                const KText('스킬은 상태 → 스킬에서 배우고 강화해요.',
                    key: Key('guildSkillNote'),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                // 묶음 31 #192: 곧 열릴 것 같은 직업 (숫자 없이)
                if (c.nearJobs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('곧 열릴 것 같은 직업', style: AppText.title(17)),
                  const SizedBox(height: 6),
                  for (final j in c.nearJobs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OrnatePanel(
                        key: Key('guildNear_${j.name}'),
                        child: Row(children: [
                          const Icon(Icons.explore_rounded,
                              color: AppColors.gold, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(JobRules.info(j).name,
                                      style: AppText.title(15,
                                          color: AppColors.text)),
                                  KText(JobRules.hintLine(j),
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13)),
                                ]),
                          ),
                        ]),
                      ),
                    ),
                ],
                const SizedBox(height: 14),
                Text('얻은 직업 ${c.ownedJobs.length}개',
                    style: AppText.title(17)),
                const SizedBox(height: 4),
                const KText('누르면 주 직업이나 보조 직업으로 둘 수 있어요.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                const SizedBox(height: 8),
                for (final j in c.ownedJobs)
                  _JobCard(
                    key: Key('guildJob_${j.name}'),
                    job: j,
                    fresh: _fresh.contains(j),
                    isMain: j == main,
                    isSub: subs.contains(j),
                    apprentice: j == main && c.jobApprentice,
                    canSub: c.subJobSlots > 0 && j != main,
                    onMain: () => _setMain(j),
                    onSub: () => _setSub(j),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
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
          const SizedBox(height: 8),
          Row(children: [
            TextButton(onPressed: onMain, child: const Text('주 직업으로')),
            if (canSub)
              TextButton(
                  onPressed: onSub,
                  child: Text(isSub ? '보조에서 빼기' : '보조로')),
          ]),
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
          _Bubble(name: c.companionName, line: JobRules.awakenLine),
          const SizedBox(height: 22),
          GoldButton(
              key: const Key('jobAwakenGo'),
              label: '길드에 가기',
              onPressed: () => setState(() => _step = 1)),
        ]),
      1 => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('직업 고르기', style: AppText.title(22, color: AppColors.goldBright)),
          const SizedBox(height: 6),
          KText(
              _apprentice
                  ? '아직 열린 직업이 없어요. 가장 익숙한 일의 견습으로 시작해요. 그 일에 더 익숙해지면 견습을 떼요.'
                  : '지금까지 해 온 일로 열린 직업이에요. 주 직업 하나를 골라요. 나중에 길드에서 언제든 바꿀 수 있어요.',
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
          const KText('보조 직업은 고유 기술을 조금 쓰고, 그 직업 스킬도 쓸 수 있어요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
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
          Text('${c.mainJobLabel ?? ''}의 길이 열렸어요!',
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
