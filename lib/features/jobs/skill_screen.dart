import 'dart:math' as math;

import 'skill_icon.dart';
import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

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

/// 묶음 86 #433: 탭 없이 한 화면 — 포인트 · 전투 칸(위에 붙음) · 주 직업 · 보조 직업 · 공용 · 숙련
class _SkillScreenState extends State<SkillScreen> {
  AppController get c => widget.controller;

  /// 「칸에」로 고른 스킬 (위 전투 칸을 누르면 끼움)
  String? _pick;
  String? _toast;
  JobSkill? _open;

  final _scroll = ScrollController();
  final _secMain = GlobalKey();
  final _secSub = GlobalKey();
  final _secCommon = GlobalKey();
  final _secMastery = GlobalKey();

  static const double _stickyH = 164;

  @override
  void initState() {
    super.initState();
    if (widget.tab != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(widget.tab == 2 ? _secMastery : _secMain, animate: false));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final n = c.takeDrillNotice();
      if (n != null && mounted) showTopNotice(context, n);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goTo(GlobalKey k, {bool animate = true}) {
    final ctx = k.currentContext;
    if (ctx == null || !_scroll.hasClients) return;
    final box = ctx.findRenderObject();
    if (box == null) return;
    final vp = RenderAbstractViewport.of(box);
    final target = (vp.getOffsetToReveal(box, 0).offset - _stickyH - 6)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

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
              final main = c.jobsOpen ? c.mainJob : null;
              final sub = c.subJobsOpen ? c.subJob : null;
              return CustomScrollView(
                key: const Key('skillScroll'),
                controller: _scroll,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(14, top + 6, 14, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        OrnateTopBar(title: '스킬', onBack: () => Navigator.of(context).maybePop()),
                        const SizedBox(height: 8),
                        if (c.jobsOpen) ...[
                          _poolCard(),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              key: const Key('skillReset'),
                              style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 6)),
                              onPressed: () => _reset(context),
                              child: const Text('포인트 다시 나누기',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 12, decoration: TextDecoration.underline)),
                            ),
                          ),
                        ],
                      ]),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _Sticky(height: _stickyH, child: _stickyBar(main, sub)),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 40),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (main != null) ..._mainSection(main),
                        if (sub != null) ..._subSection(sub),
                        if (c.jobsOpen) ..._commonSection(),
                        ..._masterySection(),
                      ]),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ───────────── 맨 위: 스킬 포인트

  Widget _poolCard() => Container(
        key: const Key('skillHead'),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1C40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF8A6A2A), width: 1.5),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('스킬 포인트', style: AppText.title(17, color: AppColors.goldBright)),
              const KText('레벨이 오를 때마다 3 · 직업 · 공용 스킬에 나눠 써요',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ]),
          ),
          Container(
            key: const Key('skillPointsLeft'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF6D88A), Color(0xFFD9A94A)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${c.skillPointsLeft}',
                  style: const TextStyle(color: Color(0xFF2A1D08), fontSize: 20, fontWeight: FontWeight.w900, height: 1.1)),
              const Text('남은 포인트',
                  style: TextStyle(color: Color(0xFF2A1D08), fontSize: 10, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
      );

  // ───────────── 위에 붙은 전투 칸 · 바로가기 칩

  Widget _stickyBar(JobId? main, JobId? sub) {
    final four = c.fourSlots;
    final slots = four ? c.battleSlots : c.battleLoadout;
    String? slotAt(int i) => i < slots.length && slots[i].isNotEmpty ? slots[i] : null;

    Widget fixed(_Fixed f) {
      final (name, _, art) = _fixedInfo(f);
      final id = _fixedId(f);
      final cell = _BarCell(
        key: Key('battleFixed_${f.name}'),
        icon: _btnArt(art, 40),
        name: name,
        sub: '늘 있음',
        dim: true,
        onTap: () => setState(() => _toast = f == _Fixed.pet ? '펫 버튼은 늘 있어요 · 함께 있는 펫을 바꾸면 바뀌어요' : '$name은 늘 있어요'),
      );
      return id == null ? cell : SkillMasterFrame(id: id, stage: c.skillStageOf(id), child: cell);
    }

    Widget slot(int i) {
      final e = slotAt(i);
      final id = e == null ? null : _entryId(e);
      final cell = _BarCell(
        key: Key('skillSlot_$i'),
        icon: e == null ? _btnArt('btn_skill_empty', 40) : _entryIcon(e, size: 40),
        name: e == null ? '비어 있음' : _entryName(e),
        sub: e == null ? '「칸에」로 끼워요' : _entryMp(e),
        ribbon: '칸 ${i + 1}',
        dashed: true,
        on: _pick != null,
        onTap: () => _tapSlot(i),
      );
      return e != null && e.startsWith('base:') ? SkillMasterFrame(id: id!, stage: c.skillStageOf(id), child: cell) : cell;
    }

    return Container(
      key: const Key('battleBar'),
      color: AppColors.deepNight,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('전투 칸', style: TextStyle(color: AppColors.goldBright, fontSize: 13, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                _pick != null ? '「${_entryName(_pick!)}」${josa(_entryName(_pick!), '을/를').substring(_entryName(_pick!).length)} 끼울 칸을 눌러요' : '전투 화면 아래 버튼',
                key: const Key('battleSlotHint'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _pick != null ? AppColors.goldBright : AppColors.textMuted, fontSize: 11.5)),
          ),
          if (_pick != null)
            GestureDetector(
              key: const Key('battlePickCancel'),
              onTap: () => setState(() => _pick = null),
              child: const Text('그만두기', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 묶음 85 #420: 각성 뒤엔 강타 · 방어 태세 자리가 칸 3 · 4
          Expanded(child: four ? slot(2) : fixed(_Fixed.strike)),
          Expanded(child: four ? slot(3) : fixed(_Fixed.guard)),
          Expanded(child: slot(0)),
          Expanded(child: slot(1)),
          Expanded(child: fixed(_Fixed.pet)),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: ListView(
            key: const Key('skillChips'),
            scrollDirection: Axis.horizontal,
            children: [
              if (main != null) _jump('주 직업 · ${JobRules.info(main).name}', _secMain, const Key('skillChip_main')),
              if (sub != null) _jump('보조 직업 · ${JobRules.info(sub).name}', _secSub, const Key('skillChip_sub')),
              if (c.jobsOpen) _jump('공용', _secCommon, const Key('skillChip_common')),
              _jump('숙련', _secMastery, const Key('skillChip_mastery')),
            ],
          ),
        ),
        if (_toast case final t?)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(t,
                key: const Key('battleSlotToast'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFBFF0C6), fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }

  Widget _jump(String label, GlobalKey k, Key key) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: GestureDetector(
          key: key,
          onTap: () => _goTo(k),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1F1C40),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF3A3468)),
            ),
            child: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 12)),
          ),
        ),
      );

  /// 「칸에」 → 위 칸 누르기
  void _pickEntry(String e) => setState(() {
        _pick = e;
        _toast = null;
      });

  Future<void> _tapSlot(int i) async {
    final e = _pick;
    if (e == null) {
      setState(() => _toast = '아래 스킬의 「칸에」를 누르고 이 칸을 누르면 끼워져요');
      return;
    }
    final hadBash = c.fourSlots && c.battleSlots.contains('base:bash');
    final cur = c.fourSlots ? c.battleSlots : c.battleLoadout;
    final other = cur.indexOf(e);
    // 이미 다른 칸에 있으면 옮김 (그 칸은 비움)
    if (other >= 0 && other != i) await c.setLoadout(other, null);
    await c.setLoadout(i, e);
    if (!mounted) return;
    final name = _entryName(e);
    final lostBash = hadBash && !c.battleSlots.contains('base:bash');
    setState(() {
      _pick = null;
      _toast = lostBash ? '강타를 빼면 MP가 없을 때 쓸 버튼이 줄어요' : '칸 ${i + 1}에 「$name」${_obj(name)} 끼웠어요';
    });
  }

  // ───────────── 전투 칸 그림 · 이름

  String _entryId(String e) {
    if (e == 'base:bash') return 'bash';
    if (e == 'base:stance') return 'stance';
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
    if (e == 'base:bash') return '강타';
    if (e == 'base:stance') return '방어 태세';
    return '';
  }

  String _entryMp(String e) {
    if (_jobOf(e) case final s?) return 'MP ${c.skillCost(s)}';
    if (e.startsWith('base:')) return 'MP 없음';
    return '숙련 · MP 없음';
  }

  Widget _entryIcon(String e, {double size = 44, bool dim = false}) {
    if (_jobOf(e) case final s?) return SkillArt.jobIcon(s, size: size, dim: dim);
    if (_masteryOf(e) case final m?) return SkillArt.masteryIcon(m, active: true, size: size, dim: dim);
    if (e == 'base:bash') return _btnArt('btn_strike', size);
    if (e == 'base:stance') return _btnArt('btn_guard', size);
    return _btnArt('btn_skill_empty', size);
  }

  Widget _btnArt(String art, double size) => Image.asset('assets/images/$art.webp',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Icon(Icons.bolt_rounded, size: size * 0.5, color: AppColors.goldBright));

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

  /// 「이름」 뒤 을/를
  static String _obj(String name) => josa(name, '을/를').substring(name.length);

  // ───────────── 칸들

  Widget _head(String title, String sub, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
          Text(title, style: AppText.title(16, color: AppColors.goldBright)),
          Text(sub, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      );

  Widget _traitCard(JobId job, {bool half = false}) => Container(
        key: Key('skillTrait_${job.name}'),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(color: const Color(0xFF26224D), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          FramedArt(frame: SkillFrame.passive, art: 'job_${job.name}', size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                const Text('고유 기술', style: TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                const KindTag(active: false),
                if (half) const _Chip('절반 세기', key: Key('skillTraitHalf')),
              ]),
              const SizedBox(height: 2),
              KText(JobRules.info(job).trait, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
            ]),
          ),
        ]),
      );

  Widget _row(JobSkill s, {bool sub = false, bool pair = false}) => _SkillRow(
        controller: c,
        skill: s,
        sub: sub,
        pair: pair,
        open: _open == s,
        onToggle: () => setState(() => _open = _open == s ? null : s),
        onRaise: () => _raise(s),
        onPutSlot: () => _pickEntry('job:${s.name}'),
      );

  List<Widget> _mainSection(JobId main) {
    final info = JobRules.info(main);
    final pair = c.activePair?.skill;
    return [
      _head('주 직업 · ${info.name}', '포인트로 올려요', key: _secMain),
      _traitCard(main),
      for (final s in info.skills) _row(s),
      if (pair != null && !info.skills.contains(pair)) _row(pair, pair: true),
      _DrillRow(controller: c, job: main, onRaise: () => setState(() {})),
    ];
  }

  List<Widget> _subSection(JobId sub) => [
        _head('보조 직업 · ${JobRules.info(sub).name}', 'MP 1.5배', key: _secSub),
        _traitCard(sub, half: true),
        for (final s in JobRules.info(sub).skills) _row(s, sub: true),
      ];

  List<Widget> _commonSection() {
    final list = c.commonSkills;
    return [
      _head('공용 스킬', '조합에서 산 스킬북', key: _secCommon),
      if (list.isEmpty)
        const Padding(
          key: Key('skillCommonEmpty'),
          padding: EdgeInsets.symmetric(vertical: 6),
          child: KText('조합에서 스킬북을 살 수 있어요', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        )
      else
        for (final s in list) _row(s),
    ];
  }

  List<Widget> _masterySection() {
    // 묶음 85 #416: 돋보기를 끄면 「감정」 숙련은 숨김 (조금이라도 쌓인 사람은 그대로)
    final order = [
      for (final m in Mastery.values)
        if (m != Mastery.appraise || LensRules.lensOn || c.masteryOf(m) > 0) m
    ]..sort((a, b) => c.masteryStage(b).index.compareTo(c.masteryStage(a).index));
    final growth = !c.jobsOpen
        ? null
        : c.subJobsOpen && c.subJobs.isNotEmpty
            ? '주 직업 숙련 1.5배 · 보조 1.2배'
            : '주 직업 숙련 1.5배';
    return [
      _head('숙련 스킬', '포인트 없이 숙련도로 올라요', key: _secMastery),
      if (growth != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(growth, key: const Key('masteryGrowth'), style: const TextStyle(color: AppColors.gold, fontSize: 12)),
        ),
      for (final m in order)
        _MasteryCard(
          key: Key('masteryRow_${m.name}'),
          controller: c,
          mastery: m,
          onPut: () => _pickEntry('mastery:${m.name}'),
        ),
    ];
  }

  // ───────────── 포인트

  Future<void> _reset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.night,
        title: const Text('포인트 다시 나누기', style: TextStyle(color: AppColors.text)),
        content: const Text('모든 직업 · 직업 숙련 · 공용 스킬에 쓴 포인트를 한꺼번에 돌려받아요. 직업마다 첫 스킬과 산 스킬북은 Lv.1로 남아요.',
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
    if (context.mounted) showTopNotice(context, '포인트를 돌려받았어요. 다시 나눠 보세요!');
  }

  Future<void> _raise(JobSkill s) async {
    final was = c.skillLevel(s);
    if (!await c.raiseSkill(s)) return;
    if (!mounted) return;
    final name = JobRules.skill(s).name;
    final left = c.skillPointsLeft;
    showTopNotice(context,
        was == 0 ? '「$name」${_obj(name)} 배웠어요 · 남은 포인트 $left' : '「$name」 Lv.${was + 1}로 올렸어요 · 남은 포인트 $left');
  }
}

/// 위에 붙는 전투 칸
class _Sticky extends SliverPersistentHeaderDelegate {
  _Sticky({required this.height, required this.child});
  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox(height: height, child: OverflowBox(alignment: Alignment.topCenter, maxHeight: height + 40, child: child));

  @override
  bool shouldRebuild(covariant _Sticky old) => true;
}

/// 묶음 86 #433: 액티브(금색) · 패시브(초록) 표시
class KindTag extends StatelessWidget {
  const KindTag({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE3B95A) : const Color(0xFF2E7A62),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(active ? '액티브' : '패시브',
            style: TextStyle(
                color: active ? const Color(0xFF2A1D05) : const Color(0xFFE6FFF3), fontSize: 10, fontWeight: FontWeight.w800)),
      );
}

/// 숙련 한 장: 지금 단계 패시브 · 다음 단계까지 막대 · 공격 스킬(숙련된부터 · 「칸에」)
class _MasteryCard extends StatelessWidget {
  const _MasteryCard({super.key, required this.controller, required this.mastery, required this.onPut});

  final AppController controller;
  final Mastery mastery;
  final VoidCallback onPut;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final m = mastery;
    final st = c.masteryStage(m);
    final v = c.masteryOf(m);
    final steps = MasteryRules.bigSteps;
    final next = st.index + 1 < MasteryStage.values.length ? MasteryStage.values[st.index + 1] : null;
    final lo = steps[st.index];
    final hi = next == null ? lo : steps[next.index];
    final frac = next == null ? 1.0 : ((v - lo) / math.max(1, hi - lo)).clamp(0.0, 1.0);
    MasterySkillInfo? at(MasteryStage s) =>
        JobRules.masterySkills.where((x) => x.mastery == m && x.stage == s).firstOrNull;
    final passive = [
      for (final s in [MasteryStage.master, MasteryStage.skilled, MasteryStage.familiar])
        if (st.index >= s.index && at(s) != null && !at(s)!.active) at(s)!,
    ].firstOrNull;
    final active = at(MasteryStage.expert);
    final hasActive = active != null && st.index >= MasteryStage.expert.index;
    return SkillMasterFrame(
      id: 'm_${m.name}',
      stage: st == MasteryStage.master ? st : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1C40),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3A3468)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Image.asset('assets/images/mastery_${m.name}.webp',
                width: 36,
                height: 36,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 36, height: 36, child: Icon(Icons.auto_awesome, color: AppColors.goldBright))),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('${m.label} 숙련', style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(MasteryRules.stageLabel(st),
                      key: Key('masteryStage_${m.name}'),
                      style: const TextStyle(color: AppColors.goldBright, fontSize: 12, fontWeight: FontWeight.w900)),
                  if (passive != null) ...[
                    Text(passive.name, style: const TextStyle(color: AppColors.text, fontSize: 12.5)),
                    const KindTag(active: false),
                  ],
                ]),
                if (passive != null)
                  KText(passive.text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 5,
                    child: Stack(children: [
                      Container(color: const Color(0xFF0E1030)),
                      FractionallySizedBox(
                        key: Key('masteryBar_${m.name}'),
                        widthFactor: frac,
                        child: Container(color: const Color(0xFF7FD6A4)),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 6),
            Text(next == null ? '끝까지' : '숙련도로\n${MasteryRules.stageLabel(next)}까지',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Color(0xFF7FD6A4), fontSize: 10.5, height: 1.25)),
          ]),
          if (active != null) ...[
            const SizedBox(height: 6),
            Opacity(
              opacity: hasActive ? 1 : 0.5,
              child: Row(children: [
                SkillArt.masteryIcon(m, active: true, size: 32, dim: !hasActive),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(active.name, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
                      const KindTag(active: true),
                      const _Chip('전투 · MP 없음', color: Color(0xFFF2C3BD)),
                    ]),
                    KText(hasActive ? active.text : '${m.label} 숙련 「${MasteryRules.stageLabel(MasteryStage.expert)}」에 생겨요',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  ]),
                ),
                if (hasActive)
                  _PutButton(key: Key('masteryToSlot_${m.name}'), onTap: onPut),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

/// 「칸에」 작은 버튼
class _PutButton extends StatelessWidget {
  const _PutButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF272A58),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF3B3F7A)),
          ),
          child: const Text('칸에', style: TextStyle(color: AppColors.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
      );
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
      if (c.skillLockedAt(skill) case final at?) {
        return Container(
          key: Key('skillLocked_${skill.name}'),
          constraints: const BoxConstraints(minWidth: 64, minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF2A2650),
            border: Border.all(color: const Color(0xFF3A3468), width: 2),
          ),
          child: Text('Lv.$at에\n열려요',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w800, height: 1.15)),
        );
      }
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
                    Wrap(spacing: 6, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(info.name, style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      Text(lv > 0 ? 'Lv.$lv' : '아직',
                          style: TextStyle(
                              color: lv > 0 ? AppColors.goldBright : AppColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                      // 묶음 86 #433: 액티브(금색) · 패시브(초록) + 전투 / 생활
                      KindTag(key: Key('skillKind_${skill.name}'), active: info.mode != SkillMode.passive),
                      _Chip(info.isBattle ? '전투' : '생활', color: info.isBattle ? const Color(0xFFF2C3BD) : const Color(0xFFBFF0C6)),
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
                      if (info.mode != SkillMode.passive) _Chip('MP ${c.skillCost(skill, sub: sub)}', color: kJobMpColor),
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
                Column(mainAxisSize: MainAxisSize.min, children: [
                  button(),
                  // 묶음 86 #433: 전투 스킬은 「칸에」 → 위 전투 칸을 누르면 끼움
                  if (info.isBattle && lv > 0) _PutButton(key: Key('skillToSlot_${skill.name}'), onTap: onPutSlot),
                ]),
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
                          child: Text(
                              i > lv && !JobRules.levelOpen(i, c.player.level.level)
                                  ? 'Lv.${JobRules.levelOpensAt(i)}에\n열려요'
                                  : 'Lv.$i\n${i == 1 ? '배우기' : up}',
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
              ],
            ]),
          ),
        ),
      ),
    );
  }
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

/// 묶음 85 #414: 직업 숙련 — 스킬을 모두 끝까지 올린 뒤 남는 포인트 (1점 = 스킬 +1%)
class _DrillRow extends StatelessWidget {
  const _DrillRow({required this.controller, required this.job, required this.onRaise});

  final AppController controller;
  final JobId job;
  final VoidCallback onRaise;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final n = c.jobDrill(job);
    final can = c.canRaiseDrill(job);
    final open = c.jobSkillsMaxed(job);
    return Container(
      key: Key('jobDrill_${job.name}'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(color: const Color(0xFF26224D), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('직업 숙련 $n점 · 스킬 +$n%',
                key: const Key('jobDrillText'),
                style: TextStyle(
                    color: open ? AppColors.goldBright : AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w800)),
            KText(
                n >= JobRules.drillMax
                    ? '끝까지 올렸어요'
                    : open
                        ? '남은 포인트를 넣을 수 있어요'
                        : '스킬을 모두 Lv.${JobRules.maxSkillLevel}까지 올리면 열려요',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ),
        GestureDetector(
          key: Key('jobDrillRaise_${job.name}'),
          onTap: can
              ? () async {
                  await c.raiseDrill(job);
                  onRaise();
                }
              : null,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: can ? const Color(0xFF2F8A3C) : const Color(0xFF3A3468), width: 2),
              gradient: can
                  ? const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8DE59A), Color(0xFF4FBF61)])
                  : null,
              color: can ? null : const Color(0xFF2A2650),
            ),
            child: Icon(Icons.add_rounded, size: 22, color: can ? const Color(0xFF0D2412) : AppColors.textMuted),
          ),
        ),
      ]),
    );
  }
}
