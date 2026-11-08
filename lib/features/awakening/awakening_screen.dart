import 'package:flutter/material.dart';

import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';

/// 첫 실행 화면: 불씨의 짧은 소개 → 외형(남·여)과 이름 정하기 → 깨어나기.
///
/// 종족 선택은 페이즈 2에서 '진짜 모습의 각성'으로 연다.
class AwakeningScreen extends StatefulWidget {
  const AwakeningScreen({super.key, required this.onAwaken});

  final Future<void> Function(String name, HeroLook look) onAwaken;

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
    await widget.onAwaken(_nameController.text.trim(), _look);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        child: _inIntro ? _buildIntro() : _buildForm(),
      ),
    );
  }

  /// 위쪽 그림 (노을 속 각성자)
  Widget _art(double height, {Widget? overlay}) {
    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        Image.asset('assets/images/bg_awakening.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0.2, -0.2),
            errorBuilder: (_, __, ___) => const SizedBox()),
        const Align(
            alignment: Alignment.bottomCenter,
            child: FadeToNight(height: 120)),
        if (overlay != null) overlay,
      ]),
    );
  }

  Widget _buildIntro() {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        _art(420 + top,
            overlay: Positioned(
              top: top + 14,
              left: 0,
              right: 0,
              child: const Center(child: EyeEmblem(size: 56)),
            )),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              children: [
                BulssiBubble(line: _introLines[_introStep], size: 96),
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
                          image: 'assets/images/portrait_male.jpg',
                          selected: _look == HeroLook.male,
                          onTap: () => setState(() => _look = HeroLook.male),
                        ),
                        const SizedBox(width: 12),
                        _LookCard(
                          label: '여',
                          image: 'assets/images/portrait_female.jpg',
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
                      const BulssiBubble(line: '뭐라고 불러 줄까?', size: 64),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
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
