import 'package:flutter/material.dart';

import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../legal/legal_screen.dart';

/// 첫 실행 화면: 불씨의 짧은 소개 → 동의 → 외형(남·여)과 이름 정하기 → 깨어나기.
///
/// 종족 선택은 페이즈 2에서 '진짜 모습의 각성'으로 연다.
class AwakeningScreen extends StatefulWidget {
  const AwakeningScreen({super.key, required this.onAwaken});

  /// [weather] 날씨 조회(선택 동의)를 켰는지
  final Future<void> Function(String name, HeroLook look, bool weather)
      onAwaken;

  @override
  State<AwakeningScreen> createState() => _AwakeningScreenState();
}

class _AwakeningScreenState extends State<AwakeningScreen> {
  /// 불씨 대사 1~4 (기획 문서 '불씨 대사 50마디')
  static const _introLines = [
    '드디어 찾았다! 너구나, 탑이 고른 각성자.',
    '나는 불씨야. 여명의 탑 아르카에서 흩어진 작은 불꽃이지.',
    '이세계가 조금씩 바래 가고 있어. 네 하루가 그곳을 다시 밝혀 줄 거야.',
    '걷고, 자고, 배우는 것. 그게 전부야. 어렵지 않지?',
  ];

  static const int maxNameLength = 10;

  final _nameController = TextEditingController();
  int _introStep = 0;
  HeroLook _look = HeroLook.male;
  bool _submitting = false;

  // 동의 (필수 3개 + 선택 1개)
  bool _consentDone = false;
  bool _agreeHealth = false;
  bool _agreeLocation = false;
  bool _agreeAge = false;
  bool _agreeWeather = true;

  bool get _requiredAgreed => _agreeHealth && _agreeLocation && _agreeAge;

  bool get _inIntro => _introStep < _introLines.length;
  bool get _canAwaken =>
      _nameController.text.trim().isNotEmpty && !_submitting;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _awaken() async {
    if (!_canAwaken) return;
    setState(() => _submitting = true);
    await widget.onAwaken(_nameController.text.trim(), _look, _agreeWeather);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        child: _inIntro
            ? _buildIntro()
            : !_consentDone
                ? _buildConsent()
                : _buildForm(),
      ),
    );
  }

  /// 위쪽 그림 (노을 속 각성자)
  Widget _art(double height, {Widget? overlay, bool intro = false}) {
    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        // 이름 짓기 화면은 제목 자리를 비우려고 그림을 조금 내린다
        Positioned.fill(
          top: overlay != null ? MediaQuery.paddingOf(context).top + 46 : 0,
          child: Image.asset(
            intro
                ? 'assets/images/splash.jpg'
                : _look == HeroLook.female
                    ? 'assets/images/bg_status_female.jpg'
                    : 'assets/images/bg_status_male.jpg',
            fit: BoxFit.cover,
            alignment: intro
                ? const Alignment(0, -0.5)
                : const Alignment(-0.42, -0.6),
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
                  colors: [Color(0xFF0B0D26), Color(0xFF0B0D26), Color(0x000B0D26)],
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

  Widget _buildIntro() {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        _art(460 + top, intro: true),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                BulssiBubble(line: _introLines[_introStep], size: 120),
                const Spacer(),
                GoldButton(
                  label: _introStep == _introLines.length - 1 ? '좋아!' : '다음',
                  onPressed: () => setState(() => _introStep++),
                ),
              ],
            ),
          ),
        ),
      ],
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
                                  fontSize: 13,
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
        const SizedBox(height: 12),
        const BulssiBubble(
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
                text: '걸음 수와 수면 시간을 건강 앱에서 읽어 레벨과 던전 열쇠를 계산합니다. '
                    '휴대폰 밖으로 보내지 않습니다.',
                doc: LegalDoc.privacy,
              ),
              item(
                value: _agreeLocation,
                onChanged: (v) => setState(() => _agreeLocation = v),
                label: '필수',
                text: '앱을 보고 있는 동안 위치를 써서 동네 안개를 걷고 장소·몬스터를 찾습니다. '
                    '좌표는 저장하지 않습니다.',
                doc: LegalDoc.locationTerms,
              ),
              item(
                value: _agreeWeather,
                onChanged: (v) => setState(() => _agreeWeather = v),
                label: '선택',
                text: '약 1km 단위의 대략 위치로 날씨를 조회해 불씨 색을 바꿉니다 '
                    '(해외 날씨 서비스 Open-Meteo).',
              ),
              item(
                value: _agreeAge,
                onChanged: (v) => setState(() => _agreeAge = v),
                label: '필수',
                text: '만 14세 이상입니다.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GoldButton(
          label: '동의하고 다음',
          onPressed: _requiredAgreed
              ? () => setState(() => _consentDone = true)
              : null,
        ),
      ],
    );
  }

  Widget _buildForm() {
    final top = MediaQuery.paddingOf(context).top;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _art(330 + top,
            overlay: Positioned(
              top: top + 8,
              left: 20,
              right: 20,
              child: const RibbonHeading('당신의 각성', size: 24),
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
                              color: AppColors.textMuted, fontSize: 13)),
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
                          image: 'assets/images/portrait_male.png',
                          selected: _look == HeroLook.male,
                          onTap: () => setState(() => _look = HeroLook.male),
                        ),
                        const SizedBox(width: 12),
                        _LookCard(
                          label: '여',
                          image: 'assets/images/portrait_female.png',
                          selected: _look == HeroLook.female,
                          onTap: () =>
                              setState(() => _look = HeroLook.female),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        maxLength: maxNameLength,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _awaken(),
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 18),
                        decoration: InputDecoration(
                          labelText: '이름',
                          labelStyle:
                              const TextStyle(color: AppColors.textMuted),
                          hintText: '불씨가 부를 이름',
                          filled: true,
                          fillColor: const Color(0xFF14173E),
                          suffixIcon: const Icon(Icons.edit_rounded,
                              color: AppColors.goldBright),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide:
                                const BorderSide(color: AppColors.panelBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                                color: AppColors.goldBright, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const BulssiBubble(line: '뭐라고 불러 줄까?', size: 80),
                      const SizedBox(height: 16),
                      _submitting
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.gold))
                          : GoldButton(
                              label: '깨어나기',
                              onPressed: _canAwaken ? _awaken : null,
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
                  style: AppText.title(20,
                      color: selected ? AppColors.goldBright : AppColors.text)),
            ]),
          ),
        ),
      ),
    );
  }
}
