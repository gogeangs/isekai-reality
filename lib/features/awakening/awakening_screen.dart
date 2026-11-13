import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/rules/age_rules.dart';

import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/bulssi_mood.dart';
import '../bulssi/spirit_art.dart';
import '../legal/legal_screen.dart';

/// 첫 실행 화면 (2026-11-10 개편):
/// 세계관 도입(일러스트 + 대사창) → 정령 고르기 → 정령 이름 → 동의 →
/// 외형(남·여)과 이름 → 각성 장면 → 깨어나기.
class AwakeningScreen extends StatefulWidget {
  const AwakeningScreen(
      {super.key, required this.onAwaken, this.onTooYoung, this.now});

  /// 만 14세 미만으로 확인됐을 때 (11-11 #86). 앱이 이용 불가 화면으로 바꾼다.
  final VoidCallback? onTooYoung;

  /// 지금 시각 (테스트용, 없으면 기기 시각)
  final DateTime Function()? now;

  final Future<void> Function(
      String name, HeroLook look, SpiritKind spirit, String spiritName) onAwaken;

  @override
  State<AwakeningScreen> createState() => _AwakeningScreenState();
}

/// 도입 장면 하나: 일러스트 + 대사 몇 줄
class IntroScene {
  const IntroScene(this.image, this.lines,
      {this.speaker, this.dialogTop = false, this.speakers});

  final String image;
  final List<String> lines;

  /// 말하는 이 (없으면 주인공의 혼잣말)
  final String? speaker;

  /// 줄마다 말하는 이가 다를 때 (묶음 25 #164). null 칸은 주인공
  final List<String?>? speakers;

  String? speakerOf(int line) {
    final s = speakers;
    if (s != null && line < s.length) return s[line];
    return speaker;
  }

  /// 대사창을 위에 띄울지 (그림의 중요한 것이 아래에 있을 때)
  final bool dialogTop;
}

enum _Stage { intro, spirit, spiritName, consent, tooYoung, form, finale }

class _AwakeningScreenState extends State<AwakeningScreen> {
  static const scenes = [
    IntroScene('assets/images/intro_01_alley.webp', ['오늘도 별일 없는 하루였어.'],
        dialogTop: true),
    IntroScene('assets/images/intro_02_glitch.webp',
        ['…어? 화면이 왜 이래?', '바닥에서… 보랏빛 안개가 올라와.'],
        dialogTop: true),
    IntroScene('assets/images/intro_03_tower.webp',
        ['저긴 분명히 아파트밖에 없던 곳인데…', '저 탑은 대체 뭐야?']),
    IntroScene('assets/images/intro_04_onlyme.webp',
        ['다들 안 보여? 설마… 나만 보이는 거야?'],
        dialogTop: true),
    IntroScene('assets/images/intro_05_lights.webp',
        ['안개를 헤치고 작은 빛 셋이 날아온다!', '찾았다! 탑이 고른 각성자!'],
        dialogTop: true,
        speakers: [null, '정령들']),
    IntroScene(
      'assets/images/intro_06_spirits.webp',
      [
        '여명의 탑 아르카의 불꽃이 깨져 버렸어.',
        '그 틈으로 우리 세계가 네 세계 위에 겹쳐 버렸지.',
        '왜 겹쳤는지 우리랑 같이 알아내 줘. 넘어온 몬스터를 정화하면 단서가 모일 거야. 방법은 간단해, 걷는 거야!',
        '그리고… 우리 중 누구와 함께 갈래?',
      ],
      speaker: '정령들',
    ),
  ];

  static String spiritIntro(SpiritKind k) => switch (k) {
        SpiritKind.fire => '나는 불의 정령! 씩씩하게 앞장설게. 같이 가자!',
        SpiritKind.water => '나는 물의 정령이야… 네가 지치지 않게 곁에서 지켜 줄게.',
        SpiritKind.plant => '식물의 정령이야~ 천천히, 새로운 길을 같이 찾아보자.',
      };

  static String spiritTrait(SpiritKind k) => switch (k) {
        SpiritKind.fire => '씩씩하고 다정해요',
        SpiritKind.water => '차분하고 걱정이 많아요',
        SpiritKind.plant => '느긋하고 호기심이 많아요',
      };

  static const int maxNameLength = 10;
  static const int maxSpiritNameLength = 8;

  final _nameController = TextEditingController();
  final _spiritNameController = TextEditingController();
  _Stage _stage = _Stage.intro;
  int _scene = 0;
  int _line = 0;
  SpiritKind _spirit = SpiritKind.fire;
  HeroLook _look = HeroLook.male;
  bool _submitting = false;

  // 동의 (필수 3개 + 선택 1개)
  bool _agreeHealth = false;
  bool _agreeLocation = false;
  // 이용 연령 (11-11 #86): 출생 연도만. 묶음 25 #162: 굴려서 고르는 휠
  static const _firstYear = 1920;
  static const _defaultYear = 2000;
  late final _yearWheel =
      FixedExtentScrollController(initialItem: _defaultYear - _firstYear);
  int? _birthYear;
  bool? _birthdayPassed;

  DateTime get _now => (widget.now ?? DateTime.now)();

  bool get _agreeAge {
    final y = _birthYear;
    if (!AgeRules.validYear(y, _now)) return false;
    if (AgeRules.needsBirthdayQuestion(y!, _now)) return _birthdayPassed != null;
    return true;
  }

  bool get _requiredAgreed => _agreeHealth && _agreeLocation && _agreeAge;

  bool get _canAwaken =>
      _nameController.text.trim().isNotEmpty && !_submitting;

  String get _spiritName {
    final n = _spiritNameController.text.trim();
    return n.isEmpty ? _spirit.defaultName : n;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _spiritNameController.dispose();
    _yearWheel.dispose();
    super.dispose();
  }

  void _nextLine() {
    setState(() {
      if (_line < scenes[_scene].lines.length - 1) {
        _line++;
      } else if (_scene < scenes.length - 1) {
        _scene++;
        _line = 0;
      } else {
        _stage = _Stage.spirit;
      }
    });
  }

  Future<void> _awaken() async {
    if (!_canAwaken) return;
    setState(() => _submitting = true);
    await widget.onAwaken(
        _nameController.text.trim(), _look, _spirit, _spiritName);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    // 고른 정령이 말풍선에 나오도록 이 화면 안에서는 따로 감싼다
    return BulssiScope(
      mood: BulssiMood.gold,
      spiritName: _spiritName,
      kind: _spirit,
      child: Scaffold(
        backgroundColor: AppColors.deepNight,
        body: switch (_stage) {
          _Stage.intro => _buildIntro(),
          _Stage.spirit => _buildSpiritPick(),
          _Stage.spiritName => NightBackground(child: _buildSpiritName()),
          _Stage.consent => NightBackground(child: _buildConsent()),
          _Stage.tooYoung => const NightBackground(child: AgeBlockedView()),
          _Stage.form => NightBackground(child: _buildForm()),
          _Stage.finale => _buildFinale(),
        },
      ),
    );
  }

  // ───────────────────────────────────────────── 도입

  Widget _buildIntro() {
    final scene = scenes[_scene];
    final speaker = scene.speakerOf(_line);
    return IllustratedScene(
      key: ValueKey('scene$_scene'),
      image: scene.image,
      speaker: speaker,
      // 묶음 25 #164: 꼬리는 말하는 쪽으로. 주인공(그림을 보는 나)은 화면 아래,
      // 정령들은 그림 가운데 (대사창이 위면 아래쪽, 아래면 위쪽)
      tailUp: speaker != null && !scene.dialogTop,
      line: scene.lines[_line],
      lineKey: '$_scene-$_line',
      dialogTop: scene.dialogTop,
      onNext: _nextLine,
      onSkip: () => setState(() => _stage = _Stage.spirit),
    );
  }

  // ───────────────────────────────────────────── 정령 고르기

  Widget _buildSpiritPick() {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(fit: StackFit.expand, children: [
      ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Image.asset('assets/images/intro_06_spirits.webp',
            fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
      ),
      const ColoredBox(color: Color(0x990B0D26)),
      ListView(
        padding: EdgeInsets.fromLTRB(18, top + 14, 18, 28),
        children: [
          const RibbonHeading('함께할 정령', size: 24),
          const SizedBox(height: 14),
          Row(children: [
            for (final k in SpiritKind.values)
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _spirit = k),
                  child: Semantics(
                    button: true,
                    selected: _spirit == k,
                    label: k.elementName,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _spirit == k ? 1 : 0.5,
                      child: Column(children: [
                        SpiritArt(kind: k, size: 72),
                        const SizedBox(height: 2),
                        Text(k.elementName,
                            style: AppText.title(14,
                                color: _spirit == k
                                    ? AppColors.goldBright
                                    : AppColors.text)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          OrnatePanel(
            highlight: true,
            child: Column(children: [
              Container(
                height: 210,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    spiritColor(_spirit).withValues(alpha: 0.45),
                    spiritColor(_spirit).withValues(alpha: 0),
                  ]),
                ),
                child: SpiritArt(kind: _spirit, size: 170),
              ),
              Text(_spirit.elementName, style: AppText.title(22)),
              const SizedBox(height: 2),
              // 11-10 B1: 세 정령의 소개를 겹쳐 두고 고른 것만 보인다.
              // 가장 긴 소개만큼 자리를 잡아 박스와 버튼이 움직이지 않는다.
              _SameHeight(
                selected: _spirit.index,
                children: [
                  for (final k in SpiritKind.values)
                    Column(children: [
                      Text(keepAll(spiritTrait(k)),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 10),
                      Text(keepAll(spiritIntro(k)),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              height: 1.45)),
                    ]),
                ],
              ),
              const SizedBox(height: 6),
              Text(keepAll('세 정령은 생김새와 말투만 달라요. 마음에 드는 정령을 골라 주세요.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 16),
          GoldButton(
            label: '이 정령과 함께하기',
            onPressed: () async {
              final ok = await _confirmFinal(
                  '${josa(_spirit.elementName, '와/과')} 함께할까요?');
              if (!ok || !mounted) return;
              setState(() {
                _spiritNameController.text = _spirit.defaultName;
                _stage = _Stage.spiritName;
              });
            },
          ),
        ],
      ),
    ]);
  }

  /// '으로' / '로' (받침에 맞춰)
  static String _ro(String name) => josa(name, '으로/로').substring(name.length);

  /// 「한 번 정하면 바꿀 수 없어요」 확인 창 (11-11 #53)
  Future<bool> _confirmFinal(String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: Text(title, style: AppText.title(19, color: AppColors.text)),
        content: const Text('한 번 정하면 바꿀 수 없어요.',
            style: TextStyle(color: AppColors.text)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('다시 고를래요')),
          TextButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('확정')),
        ],
      ),
    );
    return ok == true;
  }

  // ───────────────────────────────────────────── 정령 이름

  Widget _buildSpiritName() {
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.fromLTRB(18, top + 14, 18, 28),
      children: [
        const RibbonHeading('정령의 이름', size: 24),
        const SizedBox(height: 8),
        const BulssiLine(line: '나를 뭐라고 불러 줄래?'),
        const SizedBox(height: 12),
        Center(child: SpiritArt(kind: _spirit, size: 150)),
        const SizedBox(height: 16),
        OrnatePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field(_spiritNameController,
                  label: '정령 이름', max: maxSpiritNameLength),
              const SizedBox(height: 4),
              const Text('한 번 정하면 바꿀 수 없어요.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 14),
              GoldButton(
                label: '이 이름으로',
                onPressed: () async {
                  final ok = await _confirmFinal(
                      '「$_spiritName」${_ro(_spiritName)} 부를까요?');
                  if (!ok || !mounted) return;
                  setState(() => _stage = _Stage.consent);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(TextEditingController controller,
      {required String label, required int max, String? hint}) {
    return TextField(
      controller: controller,
      maxLength: max,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: AppColors.text, fontSize: 19),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFF14173E),
        suffixIcon: const Icon(Icons.edit_rounded, color: AppColors.goldBright),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.panelBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: const BorderSide(color: AppColors.goldBright, width: 2),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────── 각성 장면

  /// 묶음 25 #163: 무대 그림(1122×1402)에서 마법진 가운데 자리 (그림 비율)
  static const _stageW = 1122.0, _stageH = 1402.0;
  static const _circleX = 0.504, _circleY = 0.72;

  Widget _buildFinale() {
    return LayoutBuilder(builder: (context, box) {
      final g = FinaleLayout.of(box.biggest);
      return Stack(fit: StackFit.expand, children: [
        // 묶음 18 #147: 공통 무대 배경 1장 + 투명 배경 각성자. 남·여를 바꾸면
        // 각성자만 짧게 빛나며 바뀐다 (배경·정령·말풍선은 그대로)
        IllustratedScene(
          image: 'assets/images/bg_status_stage.webp',
          speaker: _spiritName,
          line: '준비됐어, ${_nameController.text.trim()}? 아르카의 빛을 되찾으러 가자!',
          lineKey: 'finale',
          onNext: _awaken,
          // 그림 위에 사람을 세우므로 당겨 보이지 않는다 (자리가 어긋나지 않게)
          zoom: false,
          // 꼬리는 위의 정령 쪽으로
          tailUp: true,
          tailX: ((g.spirit.center.dx - 14) / (box.maxWidth - 28))
              .clamp(0.1, 0.9),
          // 마법진 한가운데 각성자, 어깨 옆에 고른 정령
          decoration: Stack(children: [
            Positioned.fromRect(
              key: const Key('finaleHero'),
              rect: g.hero,
              child: _AwakenHero(look: _look),
            ),
            Positioned.fromRect(
              key: const Key('finaleSpirit'),
              rect: g.spirit,
              child: _FloatingSpirit(kind: _spirit, size: g.spirit.width),
            ),
          ]),
          nextLabel: _submitting ? null : '깨어나기',
        ),
      ]);
    });
  }

  /// 위쪽 그림 (노을 속 각성자)
  Widget _art(double height, {Widget? overlay}) {
    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        // 제목 자리를 비우려고 그림을 조금 내린다
        Positioned.fill(
          top: overlay != null ? MediaQuery.paddingOf(context).top + 46 : 0,
          child: Image.asset(
              _look == HeroLook.female
                  ? 'assets/images/bg_status_female.webp'
                  : 'assets/images/bg_status_male.webp',
              fit: BoxFit.cover,
              alignment: const Alignment(-0.42, -0.6),
              errorBuilder: (_, __, ___) => const SizedBox()),
        ),
        const Align(
            alignment: Alignment.bottomCenter,
            child: FadeToNight(height: 120)),
        if (overlay != null) ...[
          // 제목이 그림 위에서도 읽히게 위쪽을 어둡게
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              height: MediaQuery.paddingOf(context).top + 110,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.abyss, AppColors.abyss, Color(0x000B0D26)],
                  stops: [0, 0.4, 1],
                ),
              ),
            ),
          ),
          overlay,
        ],
      ]),
    );
  }

  // ───────────────────────────────────────────── 동의

  void _pickYear(int y) {
    if (_birthYear == y) return;
    setState(() {
      _birthYear = y;
      _birthdayPassed = null;
    });
  }

  /// 묶음 25 #162: 「태어난 해」 + 고른 해를 크게, 옆에 위아래로 굴리는 휠.
  /// 키보드는 뜨지 않는다. 처음엔 2000년에 놓여 있고, 굴리거나 누르면 고른 것
  Widget _yearPicker() {
    final last = _now.year;
    final y = _birthYear;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('태어난 해',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 2),
          Text(
            y == null ? '골라 주세요' : '$y년',
            key: const Key('birthYearValue'),
            style: TextStyle(
              color: y == null ? AppColors.textMuted : AppColors.goldBright,
              fontSize: y == null ? 16 : 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ]),
      ),
      Container(
        key: const Key('birthYear'),
        width: 120,
        height: 132,
        decoration: BoxDecoration(
          color: const Color(0x33000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
        ),
        child: Stack(children: [
          // 가운데 고르는 줄
          Center(
            child: Container(
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _yearWheel,
            itemExtent: 34,
            diameterRatio: 1.6,
            perspective: 0.003,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) => _pickYear(_firstYear + i),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: last - _firstYear + 1,
              builder: (context, i) {
                final year = _firstYear + i;
                return GestureDetector(
                  key: Key('birthYear_$year'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _pickYear(year);
                    _yearWheel.animateToItem(i,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut);
                  },
                  child: Center(
                    child: Text('$year',
                        style: TextStyle(
                          color: year == y
                              ? AppColors.goldBright
                              : AppColors.text,
                          fontSize: 18,
                          fontWeight:
                              year == y ? FontWeight.w800 : FontWeight.w500,
                        )),
                  ),
                );
              },
            ),
          ),
        ]),
      ),
    ]);
  }

  /// 출생 연도 (필수). 올해 14살이 되는 해면 생일이 지났는지 한 번 더 묻는다.
  Widget _ageRow() {
    final y = _birthYear;
    final ask = AgeRules.validYear(y, _now) &&
        AgeRules.needsBirthdayQuestion(y!, _now);
    Widget chip(String label, bool v) => ChoiceChip(
          label: Text(label),
          selected: _birthdayPassed == v,
          onSelected: (_) => setState(() => _birthdayPassed = v),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '(필수) ',
                    style: TextStyle(
                        color: AppColors.goldBright,
                        fontWeight: FontWeight.w700)),
                TextSpan(text: '만 14세 이상만 이용할 수 있어요. 태어난 해를 골라 주세요.'),
              ]),
              style: TextStyle(
                  color: AppColors.text, fontSize: 14, height: 1.45)),
          const SizedBox(height: 6),
          _yearPicker(),
          if (ask) ...[
            const SizedBox(height: 8),
            const Text('올해 생일이 지났나요?',
                style: TextStyle(color: AppColors.text, fontSize: 14)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [chip('지났어요', true), chip('아직이에요', false)]),
          ],
          const SizedBox(height: 4),
          const Text('태어난 해는 나이 확인에만 쓰고 저장하지 않아요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildConsent() {
    final top = MediaQuery.paddingOf(context).top;
    Widget item({
      required bool value,
      required ValueChanged<bool> onChanged,
      required String label,
      required String text,
      LegalDoc? doc,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.gold,
              checkColor: AppColors.night,
              side: const BorderSide(color: AppColors.gold, width: 1.5),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(!value),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: '($label) ',
                            style: const TextStyle(
                                color: AppColors.goldBright,
                                fontWeight: FontWeight.w700)),
                        TextSpan(text: text),
                      ]),
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              height: 1.45)),
                      if (doc != null)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => LegalScreen.open(context, doc),
                          child: Text('${doc.title} 보기 ›',
                              style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.gold)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, top + 10, 16, 28),
      children: [
        const RibbonHeading('시작하기 전에', size: 22),
        const SizedBox(height: 8),
        const BulssiLine(
            line: '네 하루를 이세계에 비추려면 몇 가지가 필요해. 모두 네 휴대폰 안에만 있어!'),
        const SizedBox(height: 12),
        OrnatePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              item(
                value: _agreeHealth,
                onChanged: (v) => setState(() => _agreeHealth = v),
                label: '필수',
                text: '걸음 수를 건강 앱에서 읽어 레벨과 던전 열쇠를 계산합니다. '
                    '휴대폰 밖으로 보내지 않습니다.',
                doc: LegalDoc.privacy,
              ),
              item(
                value: _agreeLocation,
                onChanged: (v) => setState(() => _agreeLocation = v),
                label: '필수',
                text: '앱을 보고 있는 동안 위치를 써서 주변 몬스터를 찾습니다. '
                    '좌표는 저장하지 않습니다.',
                doc: LegalDoc.locationTerms,
              ),
              _ageRow(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GoldButton(
          label: '동의하고 다음',
          onPressed: _requiredAgreed
              ? () {
                  if (!AgeRules.allowed(_birthYear!, _now,
                      birthdayPassed: _birthdayPassed)) {
                    widget.onTooYoung?.call();
                    setState(() => _stage = _Stage.tooYoung);
                    return;
                  }
                  setState(() => _stage = _Stage.form);
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildForm() {
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 8),
      children: [
        _art(330 + top,
            overlay: Positioned.fill(
              child: Stack(children: [
                Positioned(
                  top: top + 8,
                  left: 20,
                  right: 20,
                  child: const RibbonHeading('당신의 각성', size: 24),
                ),
                // 11-10 A3: 그림 속 각성자 오른쪽 빈자리에 작은 정령
                Positioned(
                  top: top + 80,
                  right: 12,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.48),
                    child: const ArtSpirit(line: '너는 뭐라고 부를까?'),
                  ),
                ),
              ]),
            )),
        Transform.translate(
          offset: const Offset(0, -40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xEE1A1D4A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.goldBright),
                    ),
                    child: Column(children: [
                      Text('각성자', style: AppText.title(22)),
                      const Text('당신의 진짜 모습이 곧 깨어날 거예요…',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 14)),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                OrnatePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        _LookCard(
                          label: '남',
                          image: 'assets/images/portrait_male.webp',
                          selected: _look == HeroLook.male,
                          onTap: () => setState(() => _look = HeroLook.male),
                        ),
                        const SizedBox(width: 12),
                        _LookCard(
                          label: '여',
                          image: 'assets/images/portrait_female.webp',
                          selected: _look == HeroLook.female,
                          onTap: () =>
                              setState(() => _look = HeroLook.female),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _field(_nameController,
                          label: '이름',
                          max: maxNameLength,
                          hint: '정령이 부를 이름'),
                      const SizedBox(height: 12),
                      GoldButton(
                        label: '다음',
                        onPressed: _canAwaken
                            ? () => setState(() => _stage = _Stage.finale)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 여러 내용 중 [selected] 하나만 보이되, 가장 큰 것만큼 자리를 잡는다
class _SameHeight extends StatelessWidget {
  const _SameHeight({required this.selected, required this.children});

  final int selected;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.topCenter, children: [
      for (var i = 0; i < children.length; i++)
        Visibility(
          visible: i == selected,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: children[i],
        ),
    ]);
  }
}

class _LookCard extends StatelessWidget {
  const _LookCard({
    required this.label,
    required this.image,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: OrnatePanel(
            highlight: selected,
            radius: 14,
            padding: const EdgeInsets.all(4),
            child: Column(children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3A3F86), Color(0xFF1B1E4C)],
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Opacity(
                    opacity: selected ? 1 : 0.6,
                    child: Image.asset(image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.person_rounded,
                            size: 80,
                            color: AppColors.textMuted)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: AppText.title(19,
                      color: selected ? AppColors.goldBright : AppColors.text)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 일러스트 한 장 + 대사창. 화면 어디를 눌러도 다음 대사로 넘어간다.
/// 글자는 한 글자씩 찍히고, 그림은 아주 천천히 다가온다.
class IllustratedScene extends StatelessWidget {
  const IllustratedScene({
    super.key,
    required this.image,
    required this.line,
    required this.lineKey,
    required this.onNext,
    this.speaker,
    this.dialogTop = false,
    this.onSkip,
    this.decoration,
    this.nextLabel,
    this.tailUp = false,
    this.tailX = 0.5,
    this.zoom = true,
  });

  /// 말풍선 꼬리: true 면 위쪽(말하는 이가 대사창 위), false 면 아래쪽
  final bool tailUp;

  /// 꼬리 자리 (대사창 너비 비율, 0 왼쪽 ~ 1 오른쪽). 이름표도 그쪽에
  final double tailX;

  /// 그림을 천천히 당겨 보이기 (각성 장면처럼 그림 위에 사람을 올릴 때는 끈다)
  final bool zoom;

  final String image;
  final String line;

  /// 대사가 바뀔 때마다 달라지는 키 (한 글자씩 찍기를 다시 시작)
  final String lineKey;
  final String? speaker;
  final bool dialogTop;
  final VoidCallback onNext;
  final VoidCallback? onSkip;

  /// 그림 위에 더 올릴 것 (예: 각성 장면의 정령)
  final Widget? decoration;

  /// 있으면 대사창 아래에 버튼으로 보여 준다 (없으면 화면을 눌러 넘김)
  final String? nextLabel;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final dialog = _DialogBox(
      speaker: speaker,
      line: line,
      lineKey: lineKey,
      showTapHint: nextLabel == null,
      tailUp: tailUp,
      tailX: tailX,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: nextLabel == null ? onNext : null,
      child: Stack(fit: StackFit.expand, children: [
        ClipRect(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(image),
            tween: Tween(begin: 1.0, end: zoom ? 1.06 : 1.0),
            duration: const Duration(seconds: 8),
            curve: Curves.easeOut,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Image.asset(image,
                  key: ValueKey(image),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFF1B1840))),
            ),
          ),
        ),
        if (decoration != null) Positioned.fill(child: decoration!),
        Positioned(
          left: 14,
          right: 14,
          top: dialogTop ? pad.top + 56 : null,
          bottom: dialogTop ? null : pad.bottom + 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dialog,
              if (nextLabel != null) ...[
                const SizedBox(height: 12),
                GoldButton(label: nextLabel!, onPressed: onNext),
              ],
            ],
          ),
        ),
        if (onSkip != null)
          Positioned(
            top: pad.top + 8,
            right: 12,
            child: TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                backgroundColor: const Color(0x990B0D26),
                shape: const StadiumBorder(),
              ),
              child: const Text('건너뛰기 ›',
                  style: TextStyle(
                      color: AppColors.text, fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }
}

class _DialogBox extends StatelessWidget {
  const _DialogBox({
    required this.speaker,
    required this.line,
    required this.lineKey,
    required this.showTapHint,
    this.tailUp = false,
    this.tailX = 0.5,
  });

  final String? speaker;
  final String line;
  final String lineKey;
  final bool showTapHint;
  final bool tailUp;
  final double tailX;

  static const _fill = Color(0xF0121541);

  @override
  Widget build(BuildContext context) {
    final monologue = speaker == null;
    final box = Container(
      key: const Key('dialogBox'),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBright, width: 1.6),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: tailX > 0.6
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!monologue) ...[
            // 이름표는 말하는 쪽 위에
            Text(speaker!,
                key: const Key('dialogSpeaker'),
                style: AppText.title(14, color: AppColors.goldBright)),
            const SizedBox(height: 4),
          ],
          // 한 글자씩
          SizedBox(
            width: double.infinity,
            child: TweenAnimationBuilder<int>(
              key: ValueKey(lineKey),
              tween: IntTween(begin: 0, end: line.characters.length),
              duration: Duration(milliseconds: 35 * line.characters.length),
              builder: (context, n, _) => Text(
                line.characters.take(n).toString(),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: monologue ? 16 : 17,
                  fontStyle: monologue ? FontStyle.italic : FontStyle.normal,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (showTapHint)
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.arrow_drop_down_rounded,
                  color: AppColors.goldBright, size: 22),
            ),
        ],
      ),
    );
    // 묶음 25 #164: 꼬리가 말하는 쪽을 가리킨다
    return Stack(clipBehavior: Clip.none, children: [
      box,
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            key: Key(tailUp ? 'dialogTailUp' : 'dialogTailDown'),
            painter: _TailPainter(up: tailUp, x: tailX, fill: _fill),
          ),
        ),
      ),
    ]);
  }
}

/// 대사창 위나 아래로 튀어나온 작은 꼬리
class _TailPainter extends CustomPainter {
  _TailPainter({required this.up, required this.x, required this.fill});

  final bool up;
  final double x;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 18.0, h = 11.0;
    final cx = (size.width * x).clamp(28.0, size.width - 28);
    final edge = up ? 0.8 : size.height - 0.8;
    final tip = up ? -h : size.height + h;
    final path = Path()
      ..moveTo(cx - w / 2, edge)
      ..lineTo(cx, tip)
      ..lineTo(cx + w / 2, edge)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
        Path()
          ..moveTo(cx - w / 2, edge)
          ..lineTo(cx, tip)
          ..lineTo(cx + w / 2, edge),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.goldBright);
  }

  @override
  bool shouldRepaint(_TailPainter old) =>
      old.up != up || old.x != x || old.fill != fill;
}

/// 각성 장면에서 어깨 옆에 둥실 떠 있는 정령
class _FloatingSpirit extends StatelessWidget {
  const _FloatingSpirit({required this.kind, required this.size});

  final SpiritKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 30), child: child),
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: spiritColor(kind).withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 4),
          ],
        ),
        child: SpiritArt(kind: kind, size: size),
      ),
    );
  }
}


/// 만 14세 미만 (11-11 #86): 이용할 수 없다는 안내만 보여 준다.
class AgeBlockedView extends StatelessWidget {
  const AgeBlockedView({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: OrnatePanel(
            key: const Key('ageBlocked'),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_clock_rounded,
                  size: 48, color: AppColors.goldBright),
              const SizedBox(height: 10),
              Text(AgeRules.blockedLine,
                  textAlign: TextAlign.center, style: AppText.title(19)),
              const SizedBox(height: 8),
              const Text('「이세계가 현실이라면?」은 만 14세 이상만 이용할 수 있어요.\n'
                  '조금 더 자란 뒤에 다시 만나요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.text, fontSize: 14, height: 1.5)),
            ]),
          ),
        ),
      );
}

/// 묶음 25 #163: 각성 장면 자리 계산. 무대 그림은 화면을 꽉 채우게(cover)
/// 놓이므로, 그림 속 마법진 가운데가 화면 어디에 오는지 구해 그 위에 세운다.
/// 크기도 그림 배율을 따라가서 어느 화면에서나 같은 자리·같은 비율.
class FinaleLayout {
  const FinaleLayout(this.circle, this.hero, this.spirit);

  /// 마법진 가운데 (화면 좌표)
  final Offset circle;

  /// 각성자 그림 칸 (아래쪽 가운데가 마법진 가운데)
  final Rect hero;

  /// 정령 칸 (각성자 오른쪽 어깨 높이)
  final Rect spirit;

  static FinaleLayout of(Size screen) {
    const w = _AwakeningScreenState._stageW, h = _AwakeningScreenState._stageH;
    final scale =
        screen.width / w > screen.height / h ? screen.width / w : screen.height / h;
    final rw = w * scale, rh = h * scale;
    final left = (screen.width - rw) / 2, top = (screen.height - rh) / 2;
    final c = Offset(left + rw * _AwakeningScreenState._circleX,
        top + rh * _AwakeningScreenState._circleY);
    // 각성자 키: 그림 높이의 0.44 (그림 비율 460×705)
    final heroH = rh * 0.44;
    final heroW = heroH * 460 / 705;
    final hero = Rect.fromLTWH(c.dx - heroW / 2, c.dy - heroH, heroW, heroH);
    final size = heroH * 0.26;
    final shoulderY = c.dy - heroH * 0.80;
    // 오른쪽 어깨 옆 (좁은 화면에서도 화면 밖으로 나가지 않게)
    final sx = (c.dx + heroW * 0.58).clamp(0.0, screen.width - size / 2 - 6);
    final spirit = Rect.fromCenter(
        center: Offset(sx, shoulderY),
        width: size,
        height: size);
    return FinaleLayout(c, hero, spirit);
  }
}

/// 각성 장면의 각성자 (묶음 18 #147): 남·여를 바꾸면 짧게 빛나며 바뀐다
class _AwakenHero extends StatelessWidget {
  const _AwakenHero({required this.look});

  final HeroLook look;

  @override
  Widget build(BuildContext context) {
    final asset = look == HeroLook.female
        ? 'assets/images/hero_stand_female.webp'
        : 'assets/images/hero_stand_male.webp';
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: AnimatedBuilder(
          animation: anim,
          child: child,
          builder: (context, child) {
            // 바뀌는 순간 하얗게 빛났다가 원래 색으로
            final glow = (1 - (anim.value - 0.5).abs() * 2).clamp(0.0, 1.0);
            return ColorFiltered(
              colorFilter: ColorFilter.mode(
                  Colors.white.withValues(alpha: 0.55 * glow),
                  BlendMode.srcATop),
              child: child,
            );
          },
        ),
      ),
      child: Image.asset(
        asset,
        key: ValueKey(asset),
        fit: BoxFit.contain,
        alignment: Alignment.bottomCenter,
        errorBuilder: (_, __, ___) => const SizedBox(),
      ),
    );
  }
}
