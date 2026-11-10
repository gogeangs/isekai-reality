import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/pet_state.dart';
import '../../core/rules/pet_rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/spirit_art.dart';
import 'pet_art.dart';

/// Lv.11 정령의 이별과 첫 펫의 부화 (11-11 #37).
/// 작별 인사 → 알을 깨움 → 펫이 태어남 → 이름 짓기 → 정령이 떠남.
class FarewellScreen extends StatefulWidget {
  const FarewellScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<FarewellScreen> createState() => _FarewellScreenState();
}

class _FarewellScreenState extends State<FarewellScreen>
    with SingleTickerProviderStateMixin {
  int _page = 0;
  late final PetSpecies _species = widget.controller.rollFirstPet();
  late final bool _hadEgg = widget.controller.hasEggForFarewell;
  final _name = TextEditingController();
  Pet? _pet;
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  void _next() {
    setState(() => _page++);
    // 알이 빛나는 건 알을 깨우기 직전 장면에서만
    if (_page == 2) {
      _glow.repeat(reverse: true);
    } else {
      _glow.stop();
    }
  }

  AppController get c => widget.controller;

  @override
  void dispose() {
    _glow.dispose();
    _name.dispose();
    super.dispose();
  }

  List<String> get _lines {
    final me = c.profile.name;
    return [
      'Lv.11 축하해, $me! 이제 넌 혼자서도 충분히 강한 각성자야.',
      '사실 나는 처음 열 걸음을 함께 걷는 안내 정령이야. '
          '이제 여명의 탑으로 돌아가야 해.',
      _hadEgg
          ? '가방에 있는 그 알… 내가 남은 힘을 모두 담아 깨워 줄게.'
          : '떠나기 전에 작은 알 하나를 선물로 남길게. 지금 바로 깨워 줄게!',
    ];
  }

  Future<void> _confirmName() async {
    final name = _name.text.trim().isEmpty
        ? PetRules.info(_species).name
        : _name.text.trim();
    final pet = await c.completeFarewell(_species, name);
    if (!mounted) return;
    setState(() {
      _pet = pet;
      _page = 4;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = c.profile.spiritKind;
    final spiritName = c.profile.spiritName;
    final info = PetRules.info(_species);
    Widget body;
    if (_page < 3) {
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        SpiritArt(kind: kind, size: 150),
        const SizedBox(height: 18),
        _Bubble(name: spiritName, line: _lines[_page]),
        if (_page == 2) ...[
          const SizedBox(height: 18),
          FadeTransition(
            opacity: Tween(begin: 0.6, end: 1.0).animate(_glow),
            child: const EggArt(size: 110, glowing: true),
          ),
        ],
        const SizedBox(height: 22),
        GoldButton(
          label: _page == 2 ? '알을 깨운다' : '다음',
          onPressed: _next,
        ),
      ]);
    } else if (_page == 3) {
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.elasticOut,
          builder: (_, t, child) => Transform.scale(scale: t, child: child),
          child: PetArt(species: _species, size: 170),
        ),
        const SizedBox(height: 10),
        Text('${josa(info.name, '이/가')} 태어났어요!',
            textAlign: TextAlign.center,
            style: AppText.title(24, color: AppColors.goldBright)),
        const SizedBox(height: 6),
        KText('원정 특기: ${info.special}\n던전 스킬: ${info.skillName} (${info.skillText})',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 16),
        _Bubble(
            name: spiritName,
            line: '이 아이에게 이름을 지어 줘. 앞으로 네 곁을 지켜 줄 거야.'),
        const SizedBox(height: 12),
        TextField(
          key: const Key('petName'),
          controller: _name,
          maxLength: 8,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.text, fontSize: 18),
          decoration: InputDecoration(
            hintText: info.name,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            counterStyle: const TextStyle(color: AppColors.textMuted),
            filled: true,
            fillColor: const Color(0xFF1B1E45),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.gold),
            ),
          ),
        ),
        const SizedBox(height: 8),
        GoldButton(label: '이름 짓기', onPressed: _confirmName),
      ]);
    } else {
      final pet = _pet!;
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Opacity(opacity: 0.55, child: SpiritArt(kind: kind, size: 110)),
          const SizedBox(width: 8),
          PetArt.of(pet, size: 110),
        ]),
        const SizedBox(height: 16),
        _Bubble(
            name: spiritName,
            line: '${josa(pet.name, '와/과')} 함께라면 걱정 없겠다. '
                '고마웠어! 특별한 날에는 편지할게.'),
        const SizedBox(height: 10),
        KText(
            '$spiritName${josa(spiritName, '은/는').substring(spiritName.length)} '
            '여명의 탑으로 돌아갔어요. 프로필에 「처음 함께한 정령」으로 남아요.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        const SizedBox(height: 22),
        GoldButton(
          label: '${pet.name}${josa(pet.name, '와/과').substring(pet.name.length)} 함께 가기',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ]);
    }
    return PopScope(
      canPop: _page >= 4,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1233),
        body: NightBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: body,
              ),
            ),
          ),
        ),
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
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            KText(line,
                style: const TextStyle(
                    color: AppColors.text, fontSize: 16, height: 1.45)),
          ],
        ),
      );
}

/// 다 품은 알에서 펫이 태어난다 (이름 짓기). 펫이 6마리면 안내만.
Future<void> showHatchSheet(
    BuildContext context, AppController c, PetEgg egg) async {
  final name = TextEditingController();
  Pet? born;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.night,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 16 + MediaQuery.viewInsetsOf(sheet).bottom),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (born == null) ...[
                const Center(child: EggArt(size: 110, glowing: true)),
                const SizedBox(height: 8),
                Text('알이 깨어나려 해요!',
                    textAlign: TextAlign.center,
                    style: AppText.title(20, color: AppColors.goldBright)),
                const SizedBox(height: 10),
                if (c.pets.pets.length >= PetRules.maxPets)
                  const KText(
                      '펫이 6마리라 더 함께할 수 없어요. 펫 하나를 자연으로 돌려보내면 '
                      '이 알이 깨어나요. 알은 가방에 그대로 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted))
                else ...[
                  TextField(
                    controller: name,
                    maxLength: 8,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.text, fontSize: 18),
                    decoration: const InputDecoration(
                      hintText: '태어날 아이의 이름',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      counterStyle: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                  GoldButton(
                    label: '깨우기',
                    onPressed: () async {
                      final pet = await c.hatch(egg.id, name.text);
                      if (pet != null) setState(() => born = pet);
                    },
                  ),
                ],
              ] else ...[
                Center(child: PetArt.of(born!, size: 150)),
                const SizedBox(height: 8),
                Text('${born!.info.name} ${born!.name}${josa(born!.name, '이/가').substring(born!.name.length)} 태어났어요!',
                    textAlign: TextAlign.center,
                    style: AppText.title(20, color: AppColors.goldBright)),
                const SizedBox(height: 6),
                KText('원정 특기: ${born!.info.special}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 14),
                GoldButton(
                    label: '좋아요', onPressed: () => Navigator.of(sheet).pop()),
              ],
            ],
          ),
        ),
      ),
    ),
  );
  name.dispose();
}
