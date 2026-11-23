import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/pet_state.dart' show Pet;
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../battle/battle_view.dart';
import '../battle/element_view.dart';
import '../battle/hero_rig.dart';
import '../pets/pet_art.dart';
import '../town/shop_screen.dart' show ShopTabButton;
import 'npc_header.dart';
import 'village_screen.dart' show SoftDot;

/// 마을 새 건물 「훈련장」 (묶음 43 #228): 가렌 · 탭 4개(연습 · 하루 훈련 · 펫 훈련 · 시련).
/// 위쪽(뒤로 가기 · 가렌 · 탭)은 붙어 있고 아래 내용만 굴러간다 (잡화상·대장간과 같은 방식)
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key, required this.controller, this.tab = 0});

  final AppController controller;
  final int tab;

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  AppController get c => widget.controller;

  late int _tab = widget.tab;

  /// 탭을 바꿨는지 (바꾸면 가렌이 그 탭 안내)
  bool _tabChanged = false;

  /// 속성 허수아비에 고른 속성
  Element _element = Element.fire;

  static const _tabs = ['연습', '하루 훈련', '펫 훈련', '시련'];

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('trainingScreen'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                key: const Key('trainingHeader'),
                padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OrnateTopBar(
                      title: '훈련장',
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 6),
                    NpcHeader(
                      controller: c,
                      npc: Npc.garen,
                      guide: TrainingRules.tabGuide(0),
                      tabLine: _tabChanged ? TrainingRules.tabGuide(_tab) : null,
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final (i, label) in _tabs.indexed) ...[
                        Expanded(
                          child: Stack(clipBehavior: Clip.none, children: [
                            ShopTabButton(
                              key: Key('trainingTab_$i'),
                              label: label,
                              selected: _tab == i,
                              onTap: () => setState(() {
                                _tab = i;
                                _tabChanged = true;
                              }),
                            ),
                            if (i == 1 && c.trainingDailyPending)
                              const Positioned(
                                  right: 4, top: 4, child: SoftDot(size: 7)),
                          ]),
                        ),
                        if (i < _tabs.length - 1) const SizedBox(width: 5),
                      ],
                    ]),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
              Expanded(
                child: Stack(children: [
                  Positioned.fill(
                    child: ListView(
                      key: Key('trainingList_$_tab'),
                      padding: EdgeInsets.fromLTRB(14, 10, 14, 28 + pad.bottom),
                      children: switch (_tab) {
                        0 => _practiceTab(),
                        1 => _dailyTab(),
                        2 => _petTab(),
                        _ => _trialTab(),
                      },
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 14,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x99000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _push(Widget page) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => page));

  // ───────────── ① 연습

  List<Widget> _practiceTab() => [
        const _Note('언제든 몇 번이든 · HP·장비·MP는 그대로 · 보상은 없어요'),
        const SizedBox(height: 8),
        for (final k in DummyKind.values) ...[
          OrnatePanel(
            key: Key('dummy_${k.name}'),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  MonsterPicture(
                    monster: TrainingRules.monsterOf(k),
                    size: 64,
                    crystal: k == DummyKind.element ? elementColor(_element) : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(TrainingRules.dummyName(k),
                            style: AppText.title(16, color: AppColors.text)),
                        const SizedBox(height: 2),
                        KText(TrainingRules.dummyText(k),
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 88,
                    child: FrameButton(
                      key: Key('practice_${k.name}'),
                      label: '연습하기',
                      height: 40,
                      onPressed: () => _push(TrainingBattleScreen(
                          controller: c,
                          mode: TrainingMode.practice,
                          dummy: k,
                          element: _element)),
                    ),
                  ),
                ]),
                if (k == DummyKind.element) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final e in Element.values)
                      GestureDetector(
                        key: Key('dummyElement_${e.name}'),
                        onTap: () => setState(() => _element = e),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
                          decoration: BoxDecoration(
                            color: e == _element
                                ? elementColor(e).withValues(alpha: 0.35)
                                : const Color(0xAA12153A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: e == _element
                                    ? AppColors.goldBright
                                    : AppColors.gold.withValues(alpha: 0.35)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            ElementIcon(e, size: 15),
                            const SizedBox(width: 3),
                            Text(e.label,
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                  ]),
                  // 묶음 75 #324: 이 허수아비에게 잘 듣는 속성 (배율은 숨김)
                  const SizedBox(height: 6),
                  KText('잘 듣는 속성: ${ElementRules.beats(_element).map((e) => e.label).join(' · ')}',
                      key: const Key('dummyBeats'),
                      style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ];

  // ───────────── ② 하루 훈련

  List<Widget> _dailyTab() {
    final done = c.dailyTrainingDone;
    return [
      _Note(c.buildingStar(Building.training) >= 2 && c.buildingsOpen
          ? '하루 두 번 · 세 판을 이어서 · 자정에 다시'
          : '하루 한 번 · 세 판을 이어서 · 자정에 다시'),
      const SizedBox(height: 8),
      OrnatePanel(
        key: const Key('dailyPanel'),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            for (final (i, m) in const [
              MonsterId.dummy,
              MonsterId.trainingGolem,
              MonsterId.trainingGolem,
            ].indexed)
              Column(children: [
                MonsterPicture(monster: m, size: i == 2 ? 74 : 60),
                const SizedBox(height: 4),
                Text('${i + 1}판',
                    style: const TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
                Text(TrainingRules.dailyNames[i],
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ]),
          ]),
          const SizedBox(height: 10),
          const KText('넘긴 판마다 전투 숙련도와 금화 조금, 세 판을 다 넘기면 가끔 재료도 받아요',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 4),
          const KText('HP는 판마다 이어져요 · 지면 거기까지',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
        ]),
      ),
      const SizedBox(height: 12),
      GoldButton(
        key: const Key('dailyStart'),
        label: done
            ? '오늘 훈련 끝 · 내일 다시'
            // 묶음 54: 훈련장 ★2 → 한 번 더
            : c.dailyTrainingExtra
                ? '한 번 더 훈련하기'
                : '하루 훈련 시작',
        height: 52,
        fontSize: 18,
        onPressed: done || !c.trainingOpen
            ? null
            : () async {
                final b = await c.startDailyTraining();
                if (b == null || !mounted) return;
                await _push(TrainingBattleScreen(
                    controller: c, mode: TrainingMode.daily, battle: b));
              },
      ),
    ];
  }

  // ───────────── ③ 펫 훈련

  String _left(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60;
    if (h > 0) return '$h시간 $m분';
    return '${m < 1 ? 1 : m}분';
  }

  List<Widget> _petTab() {
    final pets = c.pets.pets;
    final now = c.trainingPet;
    final left = now == null ? null : c.petTrainingLeft(now.uid);
    return [
      const _Note('하루 한 번 · 8시간 뒤 펫이 조금 자라요 · 그동안 동행·원정·던전은 쉬어요'),
      const SizedBox(height: 8),
      if (now != null && left != null)
        OrnatePanel(
          key: const Key('petTraining'),
          highlight: true,
          child: Row(children: [
            PetArt.of(now, size: 64),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(now.name, style: AppText.title(17, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text('훈련 중 · ${_left(left)} 남음',
                      key: const Key('petTrainingLeft'),
                      style: const TextStyle(
                          color: AppColors.goldBright,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ]),
        )
      else if (c.petTrainedToday)
        const OrnatePanel(
          key: Key('petTrainedToday'),
          child: KText('오늘 펫 훈련은 끝났어요 · 내일 다시',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text, fontSize: 14)),
        )
      else if (pets.isEmpty)
        const OrnatePanel(
          child: KText('함께하는 펫이 생기면 맡길 수 있어요',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text, fontSize: 14)),
        )
      else
        for (final p in pets) ...[
          _petRow(p),
          const SizedBox(height: 6),
        ],
    ];
  }

  Widget _petRow(Pet p) {
    final block = c.petTrainingBlock(p);
    return OrnatePanel(
      key: Key('trainPet_${p.uid}'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(children: [
        Opacity(opacity: block == null ? 1 : 0.5, child: PetArt.of(p, size: 50)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: AppText.title(15, color: AppColors.text)),
              Text(
                  'Lv.${p.level}${c.companionPet?.uid == p.uid ? ' · 동행' : ''}'
                  '${block == null ? '' : ' · $block'}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        SizedBox(
          width: 84,
          child: FrameButton(
            key: Key('trainPetGo_${p.uid}'),
            label: '맡기기',
            height: 38,
            onPressed: block != null
                ? null
                : () async {
                    final ok = await c.startPetTraining(p.uid);
                    if (!mounted || !ok) return;
                    showTopNotice(context,
                        '${josa(p.name, '을/를')} 맡겼어요 · 8시간 뒤에 데려가요');
                  },
          ),
        ),
      ]),
    );
  }

  // ───────────── ④ 시련

  List<Widget> _trialTab() {
    final done = c.trialDoneToday;
    final best = c.trialBestThisWeek;
    final marks = c.trialMarksThisWeek;
    return [
      const _Note('매주 월요일에 새로 · 하루 한 번 · HP·MP는 이어지고 물약을 쓸 수 있어요'),
      const SizedBox(height: 8),
      OrnatePanel(
        key: const Key('trialPanel'),
        ornament: true,
        child: Column(children: [
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            MonsterPicture(monster: MonsterId.dummy, size: 52),
            MonsterPicture(monster: MonsterId.dummyHard, size: 56),
            MonsterPicture(monster: MonsterId.trainingGolem, size: 66),
          ]),
          const SizedBox(height: 6),
          const KText('훈련 몬스터가 끝없이 몰려와요. 판이 갈수록 강해져요',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 10),
          Text(best > 0 ? '이번 주 최고 $best판' : '이번 주 기록 없음',
              key: const Key('trialBest'),
              style: AppText.title(19, color: AppColors.goldBright)),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
            for (final m in c.trialMarks)
              Container(
                key: Key('trialMark_$m'),
                padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                decoration: BoxDecoration(
                  gradient: marks.contains(m) ? kGoldGradient : null,
                  color: marks.contains(m) ? null : const Color(0xAA12153A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      marks.contains(m)
                          ? Icons.check_circle_rounded
                          : Icons.card_giftcard_rounded,
                      size: 15,
                      color: marks.contains(m) ? AppColors.goldInk : AppColors.goldBright),
                  const SizedBox(width: 4),
                  Text('$m판',
                      style: TextStyle(
                          color: marks.contains(m) ? AppColors.goldInk : AppColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ]),
              ),
          ]),
          const SizedBox(height: 6),
          const KText('이번 주에 처음 넘기면 재료와 마석을 받아요',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 12),
      GoldButton(
        key: const Key('trialStart'),
        label: done ? '오늘 도전 끝 · 내일 다시' : '시련 도전',
        height: 52,
        fontSize: 18,
        onPressed: done || !c.trainingOpen
            ? null
            : () async {
                final b = await c.startTrial();
                if (b == null || !mounted) return;
                await _push(TrainingBattleScreen(
                    controller: c, mode: TrainingMode.trial, battle: b));
              },
      ),
    ];
  }
}

/// 탭 맨 위 작은 설명 한 줄
class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: const Color(0xAA0B0D26),
          borderRadius: BorderRadius.circular(10),
        ),
        child: KText(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFFE6DCC4),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );
}

// ═════════════════════════════ 훈련 전투

enum TrainingMode { practice, daily, trial }

/// 훈련 전투 한 판: 연습(그만하기로 끝) · 하루 훈련(3판) · 시련(끝없이) → 결과
class TrainingBattleScreen extends StatefulWidget {
  const TrainingBattleScreen({
    super.key,
    required this.controller,
    required this.mode,
    this.battle,
    this.dummy = DummyKind.normal,
    this.element,
    this.tickInterval = const Duration(milliseconds: 900),
  });

  final AppController controller;
  final TrainingMode mode;

  /// 하루 훈련·시련은 화면을 열기 전에 만든다 (연습은 여기서)
  final Battle? battle;
  final DummyKind dummy;
  final Element? element;
  final Duration tickInterval;

  @override
  State<TrainingBattleScreen> createState() => _TrainingBattleScreenState();
}

class _TrainingBattleScreenState extends State<TrainingBattleScreen> {
  AppController get _c => widget.controller;
  late final Battle? _battle = widget.battle ??
      _c.startPractice(widget.dummy, element: widget.element);

  bool _done = false;
  DailyTrainingResult? _daily;
  TrialResult? _trial;
  int _dealt = 0;
  PracticeResult? _practiceResult;

  @override
  void initState() {
    super.initState();
    _c.holdNoticesWhile(true);
  }

  @override
  void dispose() {
    _c.holdNoticesWhile(false);
    super.dispose();
  }

  bool get _practice => widget.mode == TrainingMode.practice;

  Future<void> _finish() async {
    final b = _battle;
    if (b == null || _done) return;
    _done = true;
    switch (widget.mode) {
      case TrainingMode.practice:
        _dealt = b.practiceDealt;
        _practiceResult = await _c.finishPractice(b, kind: widget.dummy, element: widget.element);
      case TrainingMode.daily:
        _daily = await _c.finishDailyTraining(b);
      case TrainingMode.trial:
        _trial = await _c.finishTrial(b);
    }
    if (mounted) setState(() {});
  }

  String get _title => switch (widget.mode) {
        TrainingMode.practice => TrainingRules.dummyName(widget.dummy),
        TrainingMode.daily => '하루 훈련',
        TrainingMode.trial => '시련',
      };

  String _floorLabel(Battle b) => switch (widget.mode) {
        TrainingMode.practice => '연습',
        TrainingMode.daily =>
          '${b.floor + 1}판 / 3판 · ${TrainingRules.dailyNames[b.floor.clamp(0, 2)]}',
        TrainingMode.trial => '${b.floor + 1}판째',
      };

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final b = _battle;
    return PopScope(
      canPop: _done || b == null,
      child: Scaffold(
        key: const Key('trainingBattle'),
        backgroundColor: AppColors.deepNight,
        bottomNavigationBar: _done || b == null
            ? _bottom(FrameButton(
                key: const Key('trainingBack'),
                label: '돌아가기',
                onPressed: () => Navigator.of(context).pop()))
            : _practice
                ? _bottom(FrameButton(
                    key: const Key('practiceStop'),
                    label: '그만하기',
                    onPressed: _finish))
                : null,
        body: NightBackground(
          child: _done || b == null
              ? ListView(
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 28),
                  children: [
                    OrnateTopBar(title: _title),
                    const SizedBox(height: 10),
                    ..._result(),
                  ],
                )
              : Padding(
                  padding: EdgeInsets.fromLTRB(
                      14, pad.top + 6, 14, _practice ? 4 : pad.bottom + 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OrnateTopBar(title: _title, onBack: null),
                      const SizedBox(height: 10),
                      Expanded(child: _battleView(b)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _bottom(Widget child) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x000F1233), AppColors.deepNight],
            stops: [0, 0.35],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: SafeArea(top: false, child: child),
      );

  Widget _battleView(Battle b) => BattleView(
        battle: b,
        fit: true,
        jobSkills: _c.battleJobSlots,
        emptySlots: _c.skillPageOpen,
        // 연습은 MP를 쓰지 않는다
        jobMp: _practice ? () => 9999 : () => _c.jobMp,
        onJobSkill: _practice ? (_) async => true : _c.payBattleSkill,
        onMasterySkill: _practice ? null : _c.payMasterySkill,
        background: 'assets/images/bg_field_village.webp',
        onFinished: _finish,
        tickInterval: widget.tickInterval,
        playerName: _c.profile.name,
        look: _c.profile.look,
        heroJob: _c.heroJobArt, // 묶음 76 #307
        vibrate: _c.vibrate,
        sound: _c.sound,
        hour: _c.now.hour,
        season: SeasonRules.of(_c.now),
        weapon: weaponKindOf(_c.armory.wornIn(EquipSlot.weapon)?.base),
        fast: _c.fastBattle,
        onFastChanged: _c.setFastBattle,
        onAutoChanged: (hp, cure) => _c.setAutoUse(hpPercent: hp, cure: cure),
        floorLabelOf: _floorLabel,
        // 묶음 75 #324: 연습 — 「끝없는 허수아비 ∞」 · 연습 기록 · 속성 허수아비는 「효과 좋음 / 잘 안 들어요」
        practiceHud: _practice,
        elementHints: _practice && widget.dummy == DummyKind.element,
        counterOf: switch (widget.mode) {
          TrainingMode.practice => (_) => '연습',
          TrainingMode.daily => null,
          TrainingMode.trial => (b) => '${b.purified.length}판',
        },
        aura: switch (_c.gear.sets.look) {
          final set? => Color(BossGearRules.info(set).aura),
          null => null,
        },
      );

  // ───────────── 결과

  Widget _garen(String line) => OrnatePanel(
        key: const Key('garenResult'),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NpcFace(npc: Npc.garen, size: 52),
          const SizedBox(width: 10),
          Expanded(
            child: KText(line,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _got(List<String> got) => OrnatePanel(
        key: const Key('trainingGot'),
        ornament: true,
        child: Column(children: [
          Text('받은 것', style: AppText.title(15, color: AppColors.goldBright)),
          const SizedBox(height: 6),
          for (final g in got)
            Text(g,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
        ]),
      );

  List<Widget> _result() {
    switch (widget.mode) {
      case TrainingMode.practice:
        return [
          _garen(_practiceResult?.skillFull == true
              ? MasteryRules.practiceFullLine
              : _dealt > 0
              ? '좋다! 손에 감이 오지? 몇 번이든 다시 와라!'
              : '한 대도 안 치고 끝내면 어쩌나! 다음엔 제대로 휘둘러라!'),
          const SizedBox(height: 12),
          OrnatePanel(
            ornament: true,
            child: Column(children: [
              Text('준 피해 합계',
                  style: AppText.title(15, color: AppColors.goldBright)),
              const SizedBox(height: 4),
              Text(comma(_dealt),
                  key: const Key('practiceDealt'),
                  style: AppText.title(30, color: AppColors.text)),
              // 묶음 75 #324: 연습 기록
              if (_practiceResult case final r?) ...[
                const SizedBox(height: 8),
                if (r.newRecord)
                  Text('새 기록!', key: const Key('practiceNewRecord'), style: AppText.title(18, color: AppColors.goldBright)),
                for (final (k, v) in [
                  ('1초당 피해', comma(r.dps)),
                  ('지난 최고 1초당', r.best > 0 ? comma(r.best) : '없음'),
                  ('가장 센 한 방', comma(r.max)),
                  ('치명타 비율', '${(r.critRate * 100).round()}%'),
                  ('강타', '${r.bashes}번'),
                  ('스킬', '${r.skills}번'),
                  ('친 시간', '${r.seconds.round() ~/ 60}:${(r.seconds.round() % 60).toString().padLeft(2, '0')}'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Row(children: [
                      Expanded(child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 13.5))),
                      Text(v, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                if (r.seconds <= TrainingRules.practiceRecordSec)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: KText('10초 넘게 친 판만 기록에 남아요',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                if (widget.dummy == DummyKind.element && widget.element != null) ...[
                  const SizedBox(height: 6),
                  KText('잘 듣는 속성: ${ElementRules.beats(widget.element!).map((e) => e.label).join(' · ')}',
                      key: const Key('practiceBeats'),
                      style: const TextStyle(color: AppColors.goldBright, fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ],
            ]),
          ),
        ];
      case TrainingMode.daily:
        final r = _daily;
        if (r == null) return const [];
        return [
          _garen(switch (r.cleared) {
            3 => '세 판 모두 넘겼다! 내 시험까지 통과하다니 훌륭하다!',
            0 => '오늘은 여기까지다! 넘어지는 것도 훈련이다. 내일 또 와라!',
            _ => '${r.cleared}판까지 버텼다! 내일은 한 판 더 넘겨 봐라!',
          }),
          const SizedBox(height: 12),
          Center(
            child: Text('${r.cleared}판 / 3판',
                key: const Key('dailyCleared'),
                style: AppText.title(26, color: AppColors.goldBright)),
          ),
          if (r.got.isNotEmpty) ...[
            const SizedBox(height: 10),
            _got([...r.got, '전투 숙련도']),
          ],
        ];
      case TrainingMode.trial:
        final r = _trial;
        if (r == null) return const [];
        return [
          _garen(r.floors >= 10
              ? '${r.floors}판이나 버텼다! 기사단 신병들도 이렇게는 못 했다!'
              : r.floors > 0
                  ? '${r.floors}판까지 버텼다! 다음엔 더 멀리 가 봐라!'
                  : '첫 판부터 쓰러지다니! 연습부터 다시 해라!'),
          const SizedBox(height: 12),
          Center(
            child: Text('${r.floors}판 넘김',
                key: const Key('trialFloors'),
                style: AppText.title(26, color: AppColors.goldBright)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
                r.newBest ? '이번 주 새 기록!' : '이번 주 최고 ${r.best}판',
                key: const Key('trialWeekBest'),
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ),
          if (r.got.isNotEmpty) ...[
            const SizedBox(height: 10),
            _got(r.got),
          ],
          if (r.title) ...[
            const SizedBox(height: 10),
            OrnatePanel(
              key: const Key('trialTitle'),
              child: Row(children: [
                const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.goldBright),
                const SizedBox(width: 8),
                Text('칭호 「${TitleRules.info(TitleId.trialEndurer).name}」',
                    style: AppText.title(15, color: AppColors.text)),
              ]),
            ),
          ],
        ];
    }
  }
}
