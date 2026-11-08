import 'package:flutter/material.dart';

import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.duskPink, AppColors.dusk, AppColors.night],
            stops: [0, 0.4, 0.85],
          ),
        ),
        child: SafeArea(
          child: _inIntro ? _buildIntro() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          const Icon(Icons.remove_red_eye_outlined,
              color: AppColors.gold, size: 64, semanticLabel: '탑의 문장'),
          const SizedBox(height: 32),
          BulssiBubble(line: _introLines[_introStep], size: 88),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => setState(() => _introStep++),
              style: _goldButton,
              child: Text(
                  _introStep == _introLines.length - 1 ? '좋아!' : '다음',
                  style: _buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        const Text('당신의 각성',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.goldBright,
                fontSize: 24,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: Image.asset(
            _look == HeroLook.female
                ? 'assets/images/hero_female.png'
                : 'assets/images/hero_male.png',
            semanticLabel: '기본 각성자',
            errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded,
                size: 160, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 8),
        const Text('각성자',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.goldBright,
                fontSize: 20,
                fontWeight: FontWeight.w700)),
        const Text('당신의 진짜 모습이 곧 깨어날 거예요…',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        const SizedBox(height: 20),
        Row(children: [
          _LookCard(
            label: '남',
            selected: _look == HeroLook.male,
            onTap: () => setState(() => _look = HeroLook.male),
          ),
          const SizedBox(width: 12),
          _LookCard(
            label: '여',
            selected: _look == HeroLook.female,
            onTap: () => setState(() => _look = HeroLook.female),
          ),
        ]),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          maxLength: maxNameLength,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _awaken(),
          style: const TextStyle(color: AppColors.text, fontSize: 18),
          decoration: InputDecoration(
            labelText: '이름',
            labelStyle: const TextStyle(color: AppColors.textMuted),
            hintText: '불씨가 부를 이름',
            prefixIcon: const Icon(Icons.edit_rounded, color: AppColors.gold),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.panelBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.gold, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const BulssiBubble(line: '뭐라고 불러 줄까?'),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _canAwaken ? _awaken : null,
          style: _goldButton,
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.night))
              : const Text('깨어나기', style: _buttonText),
        ),
      ],
    );
  }

  // 글자 크기는 Text 에 준다 (ButtonStyle.textStyle 은 테마 글꼴과 합쳐지지 않음)
  static const TextStyle _buttonText =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w800);

  static final ButtonStyle _goldButton = FilledButton.styleFrom(
    backgroundColor: AppColors.gold,
    foregroundColor: AppColors.night,
    disabledBackgroundColor: AppColors.track,
    minimumSize: const Size.fromHeight(56),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  );
}

class _LookCard extends StatelessWidget {
  const _LookCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.gold : AppColors.panelBorder.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Semantics(
            selected: selected,
            button: true,
            child: SizedBox(
              height: 64,
              child: Center(
                child: Text(label,
                    style: TextStyle(
                        color: selected ? AppColors.goldBright : AppColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
