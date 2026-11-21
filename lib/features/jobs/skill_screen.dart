import 'dart:math' as math;

import 'skill_icon.dart';
import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../tutorial/feature_tour.dart';
import 'job_skill_bar.dart';

/// 스킬 페이지 (묶음 31 #198 → 묶음 78 #363 #364): 전투 칸 · 고유 스킬(Lv.15 각성 뒤) · 숙련 스킬
class SkillScreen extends StatefulWidget {
  const SkillScreen({super.key, required this.controller, this.tab = 0});

  final AppController controller;

  /// 처음 여는 칸 (0 전투 칸 · 1 고유 스킬 · 2 숙련 스킬)
  final int tab;

  @override
  State<SkillScreen> createState() => _SkillScreenState();
}

/// 전투 버튼 줄의 늘 있는 버튼
enum _Fixed { strike, guard, pet }

class _SkillScreenState extends State<SkillScreen> {
  AppController get c => widget.controller;
  late int _tab = widget.tab;

  // 전투 칸
  int _sel = 0;
  String? _focus; // 'job:…' · 'mastery:…' · 'fixed:strike' …
  String? _slotToast;

  // 고유 스킬
  int _jobView = 0; // 0 주 직업 · 1 보조 직업
  JobSkill? _open;
  String? _jobToast;

  // 숙련 스킬
  Mastery? _mSel;

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
                  OrnateTopBar(title: '스킬', onBack: () => Navigator.of(context).maybePop()),
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

  // ───────────── 전투 칸 (#363)

  String _entryId(String e) {
    if (e.startsWith('job:')) return e.substring(4);
    if (e.startsWith('mastery:')) return 'm_${e.substring(8)}';
    return e;
  }

  JobSkill? _jobOf(String e) => e.startsWith('job:') ? JobRules.parseSkill(e.substring(4)) : null;

  Mastery? _masteryOf(String e) =>
      e.startsWith('mastery:') ? Mastery.values.where((x) => x.name == e.substring(8)).firstOrNull : null;

  String _entryName(String e) {
    if (_jobOf(e) case final s?) return JobRules.skill(s).name;
    if (_masteryOf(e) case final m?) return JobRules.masteryActive(m).name;
    return '';
  }

  String _entryMp(String e) {
    if (_jobOf(e) case final s?) return 'MP ${c.skillCost(s)}';
    return '숙련 · MP 없음';
  }

  Widget _entryIcon(String e, {double size = 44, bool dim = false}) {
    if (_jobOf(e) case final s?) return SkillArt.jobIcon(s, size: size, dim: dim);
    if (_masteryOf(e) case final m?) return SkillArt.masteryIcon(m, active: true, size: size, dim: dim);
    return _btnArt('btn_skill_empty', size);
  }

  Widget _btnArt(String art, double size) => Image.asset('assets/images/$art.webp',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Icon(Icons.bolt_rounded, size: size * 0.5, color: AppColors.goldBright));

  /// 아래 격자: 직업 전투 스킬(주 · 보조, 안 배운 것은 잠김) + 숨은 이명 스킬 + 숙련된 단계 숙련 액티브
  List<(String, bool)> get _gridEntries {
    final out = <(String, bool)>[];
    void add(String e, bool locked) {
      if (!out.any((x) => x.$1 == e)) out.add((e, locked));
    }

    if (c.jobsOpen) {
      for (final j in [if (c.mainJob case final m?) m, ...c.subJobs]) {
        for (final s in JobRules.info(j).skills) {
          if (JobRules.skill(s).isBattle) add('job:${s.name}', c.skillLevel(s) == 0);
        }
      }
      if (c.activePair?.skill case final s? when JobRules.skill(s).isBattle) add('job:${s.name}', false);
    }
    for (final m in Mastery.values) {
      if (c.masteryStage(m).index >= MasteryStage.expert.index) add('mastery:${m.name}', false);
    }
    return out;
  }

  (String, String, String) _fixedInfo(_Fixed f) {
    final pet = c.companionPet;
    return switch (f) {
      _Fixed.strike => ('강타', '몇 턴마다 크게 쳐요', 'btn_strike'),
      _Fixed.guard => ('방어 태세', '몇 턴마다 잠시 받는 피해를 줄여요', 'btn_guard'),
      _Fixed.pet => pet != null
          ? (pet.info.skillName, '함께 있는 펫의 스킬 — 펫을 바꾸면 바뀌어요', 'btn_pet')
          : ('정령의 일격', '정령이 함께 싸워요', 'btn_pet'),
    };
  }

  String? _fixedId(_Fixed f) => switch (f) {
        _Fixed.strike => 'bash',
        _Fixed.guard => 'stance',
        _Fixed.pet => null,
      };

  void _goLearn(JobSkill s) => setState(() {
        _tab = 1;
        _open = s;
        _jobToast = null;
        _jobView = c.mainJob != null && JobRules.jobOf(s) != c.mainJob && c.subJobs.contains(JobRules.jobOf(s)) ? 1 : 0;
      });

  List<Widget> _battleTab(BuildContext context) {
    final slots = c.battleLoadout;
    final entries = _gridEntries;
    String? slotAt(int i) => i < slots.length && slots[i].isNotEmpty ? slots[i] : null;

    Widget fixed(_Fixed f) {
      final (name, _, art) = _fixedInfo(f);
      final id = _fixedId(f);
      final cell = _BarCell(
        key: Key('battleFixed_${f.name}'),
        icon: _btnArt(art, 44),
        name: name,
        sub: '늘 있음',
        dim: true,
        on: _focus == 'fixed:${f.name}',
        onTap: () => setState(() {
          _focus = 'fixed:${f.name}';
          _slotToast = null;
        }),
      );
      return id == null ? cell : SkillMasterFrame(id: id, stage: c.skillStageOf(id), child: cell);
    }

    Widget slot(int i) {
      final e = slotAt(i);
      return _BarCell(
        key: Key('skillSlot_$i'),
        icon: e == null ? _btnArt('btn_skill_empty', 44) : _entryIcon(e),
        name: e == null ? '비어 있음' : _entryName(e),
        sub: e == null ? '눌러서 고르기' : _entryMp(e),
        ribbon: '칸 ${i + 1}',
        dashed: true,
        on: _sel == i,
        onTap: () => setState(() {
          _sel = i;
          _focus = e;
          _slotToast = null;
        }),
      );
    }

    return [
      Container(
        key: const Key('battleBar'),
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const RadialGradient(
              center: Alignment.topCenter, radius: 1.4, colors: [Color(0xFF3A2F6A), Color(0xFF191636)]),
          border: Border.all(color: const Color(0xFF8A6A2A), width: 1.5),
        ),
        child: Column(children: [
          Text('전투 화면 아래 버튼이 이렇게 놓여요',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.goldBright, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: fixed(_Fixed.strike)),
            Expanded(child: fixed(_Fixed.guard)),
            Expanded(child: slot(0)),
            Expanded(child: slot(1)),
            Expanded(child: fixed(_Fixed.pet)),
          ]),
          const SizedBox(height: 8),
          KText('아래에서 칸 ${_sel + 1}에 넣을 스킬을 고르세요',
              key: const Key('battleSlotHint'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('칸 ${_sel + 1}에 넣을 스킬', key: const Key('battlePickTitle'), style: AppText.title(16, color: AppColors.goldBright)),
        const SizedBox(width: 6),
        const Flexible(
            child: Text('MP를 써요 · 2칸에 하나씩',
                overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMuted, fontSize: 11.5))),
      ]),
      const SizedBox(height: 6),
      if (entries.isEmpty)
        const Padding(
          key: Key('battleGridEmpty'),
          padding: EdgeInsets.symmetric(vertical: 10),
          child: KText('아직 넣을 스킬이 없어요. Lv.15 직업 각성이나 숙련 「숙련된」 단계에서 생겨요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        )
      else
        GridView.count(
          key: const Key('battleGrid'),
          crossAxisCount: 4,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.74,
          children: [
            for (final (e, locked) in entries)
              _GridCell(
                key: Key('battlePick_$e'),
                icon: _entryIcon(e, size: 42, dim: locked),
                name: _entryName(e),
                mp: _entryMp(e),
                tag: slots.contains(e) ? '칸 ${slots.indexOf(e) + 1}' : locked ? '포인트로 열기' : null,
                locked: locked,
                inSlot: slots.contains(e),
                focus: _focus == e,
                onTap: () => setState(() {
                  _focus = e;
                  _slotToast = null;
                }),
              ),
          ],
        ),
      const SizedBox(height: 10),
      _battleDetail(context, entries, slots),
      if (_slotToast case final t?)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: KText(t,
              key: const Key('battleSlotToast'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFBFF0C6), fontSize: 13, fontWeight: FontWeight.w700)),
        ),
    ];
  }

  Widget _battleDetail(BuildContext context, List<(String, bool)> entries, List<String> slots) {
    final f = _focus;
    Widget panel(List<Widget> children) => Container(
          key: const Key('battleDetail'),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF26224D),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3A3468)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        );
    if (f == null) {
      return panel(const [
        KText('스킬을 누르면 여기에 설명이 나와요. 늘 있는 버튼(강타 · 방어 태세 · 펫)을 눌러도 설명이 나와요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
      ]);
    }
    if (f.startsWith('fixed:')) {
      final fx = _Fixed.values.where((x) => 'fixed:${x.name}' == f).firstOrNull ?? _Fixed.strike;
      final (name, text, _) = _fixedInfo(fx);
      final id = _fixedId(fx);
      return panel([
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(name, style: AppText.title(16, color: AppColors.goldBright)),
          const _Chip('늘 있음 · 바꿀 수 없어요', key: Key('battleFixedChip')),
          if (id != null && MasteryRules.skillStageWord(c.skillStageOf(id)) != null)
            _Chip('스킬 숙련 · ${MasteryRules.skillStageWord(c.skillStageOf(id))}'),
        ]),
        const SizedBox(height: 4),
        KText(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      ]);
    }
    final locked = entries.firstWhere((x) => x.$1 == f, orElse: () => (f, false)).$2;
    final where = slots.indexOf(f);
    final name = _entryName(f);
    final js = _jobOf(f);
    final ms = _masteryOf(f);
    final text = js != null ? JobRules.skill(js).text : ms != null ? JobRules.masteryActive(ms).text : '';
    final stageWord = MasteryRules.skillStageWord(c.skillStageOf(_entryId(f)));
    final kind = js != null
        ? '${JobRules.info(JobRules.jobOf(js)).name} 스킬${c.skillLevel(js) > 0 ? ' · Lv.${c.skillLevel(js)}' : ''}'
        : ms != null
            ? '${ms.label} 숙련 · ${MasteryRules.stageLabel(c.masteryStage(ms))}'
            : '';
    final label = locked
        ? '포인트로 열기'
        : where == _sel
            ? '이미 칸 ${_sel + 1}에 있어요'
            : where >= 0
                ? '칸 ${_sel + 1}에 넣기 (칸 ${where + 1}과 바꿈)'
                : '칸 ${_sel + 1}에 넣기';
    return panel([
      Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(name, style: AppText.title(16, color: AppColors.goldBright)),
        _Chip(_entryMp(f), color: kJobMpColor),
        if (kind.isNotEmpty) _Chip(kind),
        if (stageWord != null) _Chip('스킬 숙련 · $stageWord'),
      ]),
      const SizedBox(height: 4),
      KText(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
      const SizedBox(height: 8),
      TextButton(
        key: const Key('battlePut'),
        style: gameButtonStyle(gold: !locked),
        onPressed: where == _sel
            ? null
            : locked
                ? () {
                    if (js != null) _goLearn(js);
                  }
                : () async {
                    final i = _sel;
                    await c.setLoadout(i, f);
                    if (!mounted) return;
                    setState(() => _slotToast = '칸 ${i + 1}에 「$name」${_obj(name)} 넣었어요');
                  },
        child: Text(label, maxLines: 1),
      ),
    ]);
  }

  /// 「이름」 뒤 을/를
  static String _obj(String name) => josa(name, '을/를').substring(name.length);

  // ───────────── 고유 스킬 (#364)

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.night,
        title: const Text('포인트 다시 나누기', style: TextStyle(color: AppColors.text)),
        content: const Text('쓴 포인트를 모두 돌려받아요. 직업마다 첫 스킬은 그대로 남아요.',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('그만두기')),
          TextButton(
              key: const Key('skillResetOk'), onPressed: () => Navigator.of(d).pop(true), child: const Text('다시 나누기')),
        ],
      ),
    );
    if (ok != true) return;
    await c.resetSkills();
    if (!mounted) return;
    setState(() => _jobToast = null);
    if (context.mounted) showTopNotice(context, '포인트를 돌려받았어요. 다시 나눠 보세요!');
  }

  Future<void> _raise(JobSkill s, JobId job) async {
    final was = c.skillLevel(s);
    if (!await c.raiseSkill(s)) return;
    if (!mounted) return;
    final name = JobRules.skill(s).name;
    final left = c.skillPointsLeftOn(job);
    setState(() => _jobToast = was == 0
        ? '「$name」${_obj(name)} 배웠어요 · 남은 포인트 $left'
        : '「$name」 Lv.${was + 1}로 올렸어요 · 남은 포인트 $left');
  }

  void _putInSlot(JobSkill s) {
    final slots = c.battleLoadout;
    final empty = slots.length < 2 ? slots.length : 0;
    setState(() {
      _tab = 0;
      _sel = empty;
      _focus = 'job:${s.name}';
      _slotToast = null;
    });
  }

  List<Widget> _jobTab(BuildContext context) {
    final main = c.mainJob;
    if (main == null) {
      return const [
        KText('아직 직업이 없어요. Lv.15에 직업을 고르면 고유 스킬이 생겨요.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      ];
    }
    // #357: Lv.20부터 보조 직업이 있으면 주 · 보조 두 칸
    final subs = c.subJobsOpen ? c.subJobs : const <JobId>[];
    if (subs.isEmpty) _jobView = 0;
    final job = _jobView == 1 && subs.isNotEmpty ? subs.first : main;
    final sub = job != main;
    final info = JobRules.info(job);
    final skills = info.skills;
    final battle = [for (final s in skills) if (JobRules.skill(s).isBattle) s];
    final life = [for (final s in skills) if (!JobRules.skill(s).isBattle) s];
    final pair = !sub ? c.activePair?.skill : null;
    final left = c.skillPointsLeftOn(job);

    Widget row(JobSkill s, {bool pairSkill = false}) => _SkillRow(
          controller: c,
          skill: s,
          sub: sub,
          pair: pairSkill,
          open: _open == s,
          onToggle: () => setState(() => _open = _open == s ? null : s),
          onRaise: () => _raise(s, job),
          onPutSlot: () => _putInSlot(s),
        );

    return [
      if (subs.isNotEmpty) ...[
        Row(children: [
          for (final (i, j) in [(0, main), (1, subs.first)])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _TabChip(
                  key: Key('skillJobView_$i'),
                  label: '${i == 0 ? '주 직업' : '보조 직업'} · ${JobRules.info(j).name}',
                  on: _jobView == i,
                  dot: c.skillPointsLeftOn(j) > 0,
                  onTap: () => setState(() {
                    _jobView = i;
                    _open = null;
                    _jobToast = null;
                  }),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
      ],
      Container(
        key: const Key('skillHead'),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1C40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8A6A2A), width: 1.5),
        ),
        child: Row(children: [
          JobEmblem(job, size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${info.name} 스킬', style: AppText.title(17, color: AppColors.goldBright)),
              const KText('레벨이 오를 때마다 포인트 2 · 원하는 순서로',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ]),
          ),
          Container(
            key: Key(sub ? 'skillPointsLeft_${job.name}' : 'skillPointsLeft'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF6D88A), Color(0xFFD9A94A)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$left',
                  style: const TextStyle(color: Color(0xFF2A1D08), fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
              const Text('남은 포인트',
                  style: TextStyle(color: Color(0xFF2A1D08), fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          key: const Key('skillReset'),
          style: TextButton.styleFrom(
              minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 6)),
          onPressed: () => _reset(context),
          child: const Text('포인트 다시 나누기',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, decoration: TextDecoration.underline)),
        ),
      ),
      Container(
        key: const Key('skillTrait'),
        padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
        decoration: BoxDecoration(color: const Color(0xFF26224D), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          FramedArt(frame: SkillFrame.passive, art: 'job_${job.name}', size: 36),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('고유 기술 · 늘 켜짐',
                  style: TextStyle(color: AppColors.goldBright, fontSize: 12, fontWeight: FontWeight.w800)),
              KText(info.trait, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (battle.isNotEmpty || pair != null) ...[
        const _SecHead('전투 스킬', '전투 칸에 넣어 MP로 써요'),
        for (final s in battle) row(s),
        if (pair != null && !skills.contains(pair)) row(pair, pairSkill: true),
        const SizedBox(height: 6),
      ],
      if (life.isNotEmpty) ...[
        const _SecHead('생활 스킬', '지도 · 시설에서 MP로 써요'),
        for (final s in life) row(s),
      ],
      if (_jobToast case final t?)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: KText(t,
              key: const Key('skillToast'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFBFF0C6), fontSize: 13, fontWeight: FontWeight.w700)),
        ),
    ];
  }

  // ───────────── 숙련 스킬 (#364)

  List<Widget> _masteryTab() {
    final order = [...Mastery.values]
      ..sort((a, b) => c.masteryStage(b).index.compareTo(c.masteryStage(a).index));
    final sel = _mSel ?? order.first;
    final growth = !c.jobsOpen
        ? null
        : c.subJobsOpen && c.subJobs.isNotEmpty
            ? '주 직업 숙련 1.5배 · 보조 1.2배'
            : '주 직업 숙련 1.5배';
    return [
      const _SecHead('숙련도 8가지', '같은 일을 되풀이하면 오르고, 단계마다 스킬이 생겨요'),
      if (growth != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(growth, key: const Key('masteryGrowth'), style: const TextStyle(color: AppColors.gold, fontSize: 12)),
        ),
      for (final m in order)
        _MasteryRow(
          key: Key('masteryRow_${m.name}'),
          mastery: m,
          stage: c.masteryStage(m),
          value: c.masteryOf(m),
          selected: m == sel,
          onTap: () => setState(() => _mSel = m),
        ),
      const SizedBox(height: 6),
      _masteryDetail(sel),
    ];
  }

  Widget _masteryDetail(Mastery m) {
    final st = c.masteryStage(m);
    return Container(
      key: Key('masteryDetail_${m.name}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF26224D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A3468)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${m.label} · ${MasteryRules.stageLabel(st)}', style: AppText.title(16, color: AppColors.goldBright)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFF15133A), borderRadius: BorderRadius.circular(10)),
          child: KText('이렇게 올라요 · ${MasteryRules.howUp(m)}',
              key: const Key('masteryHow'), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
        const SizedBox(height: 6),
        for (final s in MasteryStage.values.skip(1))
          if (JobRules.masterySkills.where((x) => x.mastery == m && x.stage == s).firstOrNull case final x?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Opacity(
                opacity: st.index >= s.index ? 1 : 0.5,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(
                      color: st.index >= s.index ? AppColors.gold : const Color(0xFF15133A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(MasteryRules.stageLabel(s),
                        style: TextStyle(
                            color: st.index >= s.index ? const Color(0xFF2A1D08) : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        Text(x.name,
                            style: TextStyle(
                                color: st.index >= s.index ? AppColors.text : AppColors.textMuted,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                        if (x.active) const _Chip('전투', color: Color(0xFFF2C3BD)),
                      ]),
                      KText(x.text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      if (x.active)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            key: Key('masteryToSlot_${m.name}'),
                            style: TextButton.styleFrom(
                                minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 4)),
                            onPressed: st.index >= MasteryStage.expert.index
                                ? () => setState(() {
                                      _tab = 0;
                                      final slots = c.battleLoadout;
                                      _sel = slots.length < 2 ? slots.length : 0;
                                      _focus = 'mastery:${m.name}';
                                      _slotToast = null;
                                    })
                                : null,
                            child: const Text('전투 · 전투 칸에 넣기', style: TextStyle(fontSize: 12.5)),
                          ),
                        ),
                    ]),
                  ),
                ]),
              ),
            ),
      ]),
    );
  }
}

/// 전투 버튼 줄의 한 칸
class _BarCell extends StatelessWidget {
  const _BarCell({
    super.key,
    required this.icon,
    required this.name,
    required this.sub,
    required this.onTap,
    this.ribbon,
    this.dashed = false,
    this.dim = false,
    this.on = false,
  });

  final Widget icon;
  final String name;
  final String sub;
  final String? ribbon;
  final bool dashed;
  final bool dim;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 5),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Opacity(opacity: dim && !on ? 0.72 : 1, child: icon),
        const SizedBox(height: 2),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.text, fontSize: 10.5, height: 1.2)),
        Text(sub,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: dashed ? kJobMpColor : AppColors.textMuted, fontSize: 9.5)),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          CustomPaint(
            painter: dashed
                ? _DashedBox(color: on ? AppColors.goldBright : AppColors.goldBright.withValues(alpha: 0.7), solid: on)
                : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: dashed
                    ? AppColors.gold.withValues(alpha: on ? 0.18 : 0.06)
                    : on
                        ? Colors.white.withValues(alpha: 0.06)
                        : null,
                border: !dashed && on ? Border.all(color: AppColors.textMuted) : null,
                boxShadow: dashed && on ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 12)] : null,
              ),
              child: body,
            ),
          ),
          if (ribbon != null)
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(7)),
                  child: Text(ribbon!,
                      style: const TextStyle(color: Color(0xFF2A1D08), fontSize: 9.5, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// 금빛 점선 테 (고른 칸은 실선)
class _DashedBox extends CustomPainter {
  _DashedBox({required this.color, required this.solid});
  final Color color;
  final bool solid;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    final path = Path()..addRRect(rr);
    if (solid) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBox old) => old.color != color || old.solid != solid;
}

/// 「칸 ○에 넣을 스킬」 격자의 한 칸
class _GridCell extends StatelessWidget {
  const _GridCell({
    super.key,
    required this.icon,
    required this.name,
    required this.mp,
    required this.onTap,
    this.tag,
    this.locked = false,
    this.inSlot = false,
    this.focus = false,
  });

  final Widget icon;
  final String name;
  final String mp;
  final String? tag;
  final bool locked;
  final bool inSlot;
  final bool focus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: locked ? 0.55 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F1C40),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: focus
                      ? AppColors.goldBright
                      : inSlot
                          ? AppColors.gold
                          : const Color(0xFF3A3468),
                  width: focus ? 2 : 1.5),
            ),
            child: Stack(clipBehavior: Clip.none, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 4),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  icon,
                  const SizedBox(height: 2),
                  Text(name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text, fontSize: 10.5, height: 1.2)),
                  Text(mp,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: kJobMpColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
                ]),
              ),
              if (tag != null)
                Positioned(
                  top: -1,
                  right: -1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: locked ? const Color(0xFF4A4478) : AppColors.gold,
                      borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(11), bottomLeft: Radius.circular(8)),
                    ),
                    child: Text(tag!,
                        style: TextStyle(
                            color: locked ? const Color(0xFFD8CFEE) : const Color(0xFF2A1D08),
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
            ]),
          ),
        ),
      );
}

/// 고유 스킬 한 줄 (누르면 그 자리에서 펼침)
class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.controller,
    required this.skill,
    required this.sub,
    required this.open,
    required this.onToggle,
    required this.onRaise,
    required this.onPutSlot,
    this.pair = false,
  });

  final AppController controller;
  final JobSkill skill;
  final bool sub;
  final bool pair;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onRaise;
  final VoidCallback onPutSlot;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = JobRules.skill(skill);
    final lv = c.skillLevel(skill);
    const max = JobRules.maxSkillLevel;
    final can = c.canRaiseSkill(skill);
    final up = info.attack || info.isBattle ? '더 세져요' : 'MP가 덜 들어요';
    final stage = lv > 0 ? c.skillStageOf(skill.name) : null;

    Widget button() {
      if (pair) return const _Chip('이명', color: AppColors.goldBright);
      if (lv >= max) {
        return Container(
          key: Key('skillMax_${skill.name}'),
          constraints: const BoxConstraints(minWidth: 64, minHeight: 36),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold, width: 2),
          ),
          child: const Text('MAX', style: TextStyle(color: AppColors.goldBright, fontSize: 12, fontWeight: FontWeight.w900)),
        );
      }
      return GestureDetector(
        key: Key('skillRaise_${skill.name}'),
        onTap: can ? onRaise : null,
        child: Container(
          constraints: const BoxConstraints(minWidth: 64, minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: can ? const Color(0xFF2F8A3C) : const Color(0xFF3A3468), width: 2),
            gradient: can
                ? const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8DE59A), Color(0xFF4FBF61)])
                : null,
            color: can ? null : const Color(0xFF2A2650),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(lv == 0 ? '배우기' : '+ 강화',
                style: TextStyle(
                    color: can ? const Color(0xFF0D2412) : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    height: 1.1)),
            Text('포인트 1',
                style: TextStyle(
                    color: can ? const Color(0xFF0D2412) : AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SkillMasterFrame(
        id: skill.name,
        stage: stage,
        child: GestureDetector(
          key: Key('jobSkillTile_${skill.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1C40),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: open ? AppColors.goldBright : const Color(0xFF3A3468), width: 1.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                SkillArt.jobIcon(skill, size: 40, dim: lv == 0),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(info.name, style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text(lv > 0 ? 'Lv.$lv' : '아직',
                          style: TextStyle(
                              color: lv > 0 ? AppColors.goldBright : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      for (var i = 0; i < max; i++)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < lv ? AppColors.gold : null,
                            border: Border.all(color: AppColors.gold),
                          ),
                        ),
                      const SizedBox(width: 4),
                      _Chip('MP ${c.skillCost(skill, sub: sub)}', color: kJobMpColor),
                      if (stage != null && MasteryRules.skillStageWord(stage) != null) ...[
                        const SizedBox(width: 4),
                        Flexible(child: _Chip(MasteryRules.skillStageWord(stage)!, key: Key('skillStage_${skill.name}'))),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(info.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  ]),
                ),
                const SizedBox(width: 8),
                button(),
              ]),
              if (open) ...[
                const SizedBox(height: 8),
                const Divider(height: 1, color: Color(0xFF3A3468)),
                const SizedBox(height: 8),
                KText(info.text, key: Key('skillOpen_${skill.name}'), style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                const SizedBox(height: 6),
                Row(children: [
                  for (var i = 1; i <= max; i++) ...[
                    if (i > 1) const SizedBox(width: 4),
                    Expanded(
                      child: CustomPaint(
                        painter: i == lv + 1 && !pair ? _DashedBox(color: const Color(0xFF6BD97A), solid: false) : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: i <= lv ? AppColors.gold.withValues(alpha: 0.12) : null,
                            border: i <= lv
                                ? Border.all(color: AppColors.gold)
                                : i == lv + 1 && !pair
                                    ? null
                                    : Border.all(color: const Color(0xFF3A3468)),
                          ),
                          child: Text('Lv.$i · ${i == 1 ? '배우기' : up}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: i <= lv
                                      ? AppColors.goldBright
                                      : i == lv + 1
                                          ? const Color(0xFFBFF0C6)
                                          : AppColors.textMuted,
                                  fontSize: 10.5)),
                        ),
                      ),
                    ),
                  ],
                ]),
                if (info.isBattle && lv > 0) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    key: Key('skillToSlot_${skill.name}'),
                    style: gameButtonStyle(gold: false),
                    onPressed: onPutSlot,
                    child: const Text('전투 칸에 넣기', maxLines: 1),
                  ),
                ],
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// 숙련도 한 줄: 그림 · 이름 · 단계 · 4칸 막대 · 단계 스킬 동그라미 4개 · 장인 배지
class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    super.key,
    required this.mastery,
    required this.stage,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final Mastery mastery;
  final MasteryStage stage;
  final double value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final master = stage == MasteryStage.master;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1C40),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppColors.goldBright : const Color(0xFF3A3468), width: selected ? 1.6 : 1),
          ),
          child: Row(children: [
            Image.asset('assets/images/mastery_${mastery.name}.webp',
                width: 40,
                height: 40,
                errorBuilder: (_, __, ___) => const SizedBox(
                    width: 40, height: 40, child: Icon(Icons.auto_awesome, color: AppColors.goldBright))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(mastery.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    key: Key('masteryStage_${mastery.name}'),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
                    child: Text(MasteryRules.stageLabel(stage),
                        style: const TextStyle(color: AppColors.goldBright, fontSize: 10.5, fontWeight: FontWeight.w900)),
                  ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  for (var k = 0; k < 4; k++) ...[
                    if (k > 0) const SizedBox(width: 3),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 6,
                          child: Stack(children: [
                            Container(color: const Color(0xFF0E0C22)),
                            FractionallySizedBox(
                              widthFactor: MasteryRules.segmentFill(value, k),
                              child: Container(
                                decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: [Color(0xFFD9A94A), Color(0xFFF6D88A)])),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  for (final (i, s) in MasteryStage.values.skip(1).indexed) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(s == MasteryStage.expert ? 7 : 12),
                        color: stage.index >= s.index ? AppColors.gold.withValues(alpha: 0.18) : const Color(0xFF15133A),
                        border: Border.all(color: stage.index >= s.index ? AppColors.gold : const Color(0xFF3A3468)),
                      ),
                      child: Text(s == MasteryStage.expert ? '⚔' : '${i + 1}',
                          style: TextStyle(
                              color: stage.index >= s.index ? AppColors.goldBright : AppColors.textMuted, fontSize: 10)),
                    ),
                  ],
                ]),
              ]),
            ),
            if (master)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Image.asset(
                    'assets/images/${TitleRules.asset(MasteryRules.titles[mastery]!.$2)}.webp',
                    key: Key('masteryBadge_${mastery.name}'),
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.military_tech_rounded, color: AppColors.goldBright, size: 26)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _SecHead extends StatelessWidget {
  const _SecHead(this.title, this.sub);
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.end, children: [
          Text(title, style: const TextStyle(color: AppColors.goldBright, fontSize: 13, fontWeight: FontWeight.w900)),
          Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        ]),
      );
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {super.key, this.color = AppColors.textMuted});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(color: const Color(0xFF15133A), borderRadius: BorderRadius.circular(9)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
}

/// 묶음 75 #325: 스킬 이름 옆 숙련 단계 말 (서툰은 안 씀)
class SkillStageWord extends StatelessWidget {
  const SkillStageWord({super.key, required this.id, required this.stage});

  final String id;
  final MasteryStage? stage;

  @override
  Widget build(BuildContext context) {
    final w = stage == null ? null : MasteryRules.skillStageWord(stage!);
    if (w == null) return const SizedBox.shrink();
    final master = stage == MasteryStage.master;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        key: Key('skillStage_$id'),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: master ? AppColors.gold.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: master ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Text(w,
            style: TextStyle(
                color: master ? AppColors.goldBright : AppColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// 묶음 75 #325: 장인 스킬 칸은 금테
class SkillMasterFrame extends StatelessWidget {
  const SkillMasterFrame({super.key, required this.id, required this.stage, required this.child});

  final String id;
  final MasteryStage? stage;
  final Widget child;

  @override
  Widget build(BuildContext context) => stage != MasteryStage.master
      ? child
      : DecoratedBox(
          key: Key('skillMaster_$id'),
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.goldBright, width: 2.5),
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 10)],
          ),
          child: child,
        );
}

class _TabChip extends StatelessWidget {
  const _TabChip({super.key, required this.label, required this.on, required this.onTap, this.dot = false});

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
            border: Border.all(color: on ? AppColors.goldBright : AppColors.gold, width: on ? 1.6 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: on ? AppColors.goldBright : AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            if (dot) ...[
              const SizedBox(width: 4),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(color: AppColors.alert, shape: BoxShape.circle),
              ),
            ],
          ]),
        ),
      );
}
