import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/pet_state.dart';
import '../../core/rules/pet_rules.dart';
import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../awakening/awakening_screen.dart' show IllustratedScene;
import 'pet_art.dart';

/// 컷신 한 줄: 그림 · 말하는 이(null 이면 내레이션) · 대사
typedef FarewellLine = ({String image, String? speaker, bool hero, String line});

/// Lv.11 정령의 이별 컷신과 첫 펫 (묶음 29 #182).
/// 장면 5개(그림 + 대사 넘기기) → 빛 조각 → 알 → 깨어남 → 이름 짓기 → 첫 펫 한마디.
/// 건너뛰기 없음. 이름을 지을 때 저장하므로, 도중에 앱을 끄면 처음부터 다시 본다.
class FarewellScreen extends StatefulWidget {
  const FarewellScreen({super.key, required this.controller});

  final AppController controller;

  /// 컷신 대사 (○○ = 플레이어 이름). 그림은 각성자 성별·고른 정령에 맞춘다
  static List<FarewellLine> linesFor({
    required String hero,
    required String spirit,
    required HeroLook look,
    required SpiritKind kind,
  }) {
    final g = look == HeroLook.female ? '_female' : '';
    final smile = switch (kind) {
      SpiritKind.fire => 'fire',
      SpiritKind.water => 'water',
      SpiritKind.plant => 'leaf',
    };
    String img(String n) => 'assets/images/$n.webp';
    return [
      (
        image: img('farewell_01_gate$g'),
        speaker: spirit,
        hero: false,
        line: '여기야. 내가 처음 떨어졌던 곳.',
      ),
      (
        image: img('farewell_02_lookup$g'),
        speaker: spirit,
        hero: false,
        line: '문이 이대로면 두 세계 다 흐려져. 고칠 수 있는 건 문지기 빛뿐이야. 바로 나.',
      ),
      (
        image: img('farewell_02_lookup$g'),
        speaker: hero,
        hero: true,
        line: '…같이 가면 안 돼?',
      ),
      (
        image: img('farewell_03_smile_$smile'),
        speaker: spirit,
        hero: false,
        line: '너는 여기서 빛을 지켜 줘. 네가 강해지는 거, 내가 처음부터 다 봤잖아. '
            '이제 혼자서도 괜찮아.',
      ),
      (
        image: img('farewell_04_light'),
        speaker: spirit,
        hero: false,
        line: '고마웠어, $hero. 내 빛을 조금 남겨 둘게.',
      ),
      (
        image: img('farewell_05_eyes$g'),
        speaker: null,
        hero: false,
        line: '문 너머, 잿빛 속에서 누군가 이쪽을 보고 있었다.',
      ),
    ];
  }

  /// 첫 펫 기본 이름 제안
  static String suggestName(PetSpecies s) => switch (s) {
        PetSpecies.crow => '까망',
        PetSpecies.blackCat => '나비',
        PetSpecies.toad => '개굴',
        PetSpecies.owl => '부엉',
        PetSpecies.lizard => '도롱',
        PetSpecies.homunculus => '호문',
      };

  /// 첫 펫의 마지막 한마디 (Lv.15 직업 각성 복선)
  static const String petLine = '곧 너만의 길도 찾게 될 거야.';

  @override
  State<FarewellScreen> createState() => _FarewellScreenState();
}

enum _Stage { scenes, hatch, name, talk }

class _FarewellScreenState extends State<FarewellScreen>
    with SingleTickerProviderStateMixin {
  AppController get c => widget.controller;

  var _stage = _Stage.scenes;
  int _line = 0;
  late final PetSpecies _species = c.firstPetSpecies;
  late final _name =
      TextEditingController(text: FarewellScreen.suggestName(_species));
  Pet? _pet;
  bool _saving = false;

  /// 빛 조각 → 알 → 깨어남
  late final AnimationController _hatch = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _stage = _Stage.name);
      }
    });

  late final List<FarewellLine> _lines = FarewellScreen.linesFor(
    hero: c.profile.name,
    spirit: c.profile.spiritName,
    look: c.profile.look,
    kind: c.profile.spiritKind,
  );

  @override
  void dispose() {
    _hatch.dispose();
    _name.dispose();
    super.dispose();
  }

  void _next() {
    if (_line < _lines.length - 1) {
      setState(() => _line++);
      return;
    }
    setState(() => _stage = _Stage.hatch);
    _hatch.forward(from: 0);
  }

  Future<void> _confirmName() async {
    if (_saving) return;
    _saving = true;
    final pet = await c.completeFarewell(_name.text);
    if (!mounted) return;
    setState(() {
      _pet = pet;
      _stage = _Stage.talk;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_stage) {
      _Stage.scenes => _scene(),
      _Stage.hatch => _hatchView(),
      _Stage.name => _nameView(),
      _Stage.talk => _talkView(),
    };
    return PopScope(
      canPop: _stage == _Stage.talk,
      child: Scaffold(
        key: const Key('farewellScreen'),
        backgroundColor: AppColors.deepNight,
        body: body,
      ),
    );
  }

  Widget _scene() {
    final l = _lines[_line];
    return IllustratedScene(
      key: ValueKey('farewell$_line'),
      image: l.image,
      speaker: l.speaker,
      // #164: 꼬리는 말하는 쪽. 정령은 그림 속(위), 각성자는 화면 아래(보는 나)
      tailUp: l.speaker != null && !l.hero,
      tailX: l.hero ? 0.25 : 0.5,
      line: l.line,
      lineKey: 'farewell-$_line',
      onNext: _next,
    );
  }

  Widget _hatchView() => NightBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _hatch,
            builder: (_, __) {
              final t = _hatch.value;
              // 0~0.35 손바닥의 빛 조각, 0.35~0.65 알, 0.65~ 깨어남
              if (t < 0.35) {
                final k = Curves.easeOut.transform(t / 0.35);
                return Opacity(
                  opacity: k,
                  child: Transform.scale(
                      scale: 0.6 + 0.4 * k, child: const _LightShard(size: 120)),
                );
              }
              if (t < 0.65) {
                final k = (t - 0.35) / 0.3;
                final shake = math.sin(k * math.pi * 8) * 0.06 * k;
                return Stack(alignment: Alignment.center, children: [
                  Opacity(
                      opacity: 1 - k,
                      child: const _LightShard(size: 120)),
                  Transform.rotate(
                    angle: shake,
                    child: Transform.scale(
                        scale: 0.4 + 0.6 * Curves.easeOutBack.transform(k),
                        child: const EggArt(size: 130, glowing: true)),
                  ),
                ]);
              }
              final k = Curves.elasticOut.transform((t - 0.65) / 0.35);
              return Stack(alignment: Alignment.center, children: [
                Image.asset('assets/images/scene_hatch.webp',
                    width: 280,
                    height: 280,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                Transform.scale(
                    scale: 0.3 + 0.7 * k,
                    child: PetArt(species: _species, size: 170)),
              ]);
            },
          ),
        ),
      );

  Widget _nameView() {
    final info = PetRules.info(_species);
    return NightBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(alignment: Alignment.center, children: [
                Image.asset('assets/images/scene_hatch.webp',
                    width: 240,
                    height: 240,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                PetArt(species: _species, size: 150),
              ]),
              const SizedBox(height: 8),
              Text('빛 조각에서 ${josa(info.name, '이/가')} 태어났어요!',
                  textAlign: TextAlign.center,
                  style: AppText.title(21, color: AppColors.goldBright)),
              const SizedBox(height: 6),
              KText(
                  '원정 특기: ${info.special}\n던전 스킬: ${info.skillName} (${info.skillText})',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 14)),
              const SizedBox(height: 16),
              const KText('이름을 지어 주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.text, fontSize: 15)),
              const SizedBox(height: 8),
              TextField(
                key: const Key('petName'),
                controller: _name,
                maxLength: 8,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.text, fontSize: 19),
                decoration: InputDecoration(
                  hintText: FarewellScreen.suggestName(_species),
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
            ]),
          ),
        ),
      ),
    );
  }

  Widget _talkView() {
    final pet = _pet!;
    // 11-15 결정 F: 빛 조각 장면(farewell_04_light)을 흐리게 배경으로
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: AppColors.deepNight),
      Opacity(
        opacity: 0.55,
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Image.asset('assets/images/farewell_04_light.webp',
              key: const Key('farewellTalkBg'),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
      ),
      _talkBody(pet),
    ]);
  }

  Widget _talkBody(Pet pet) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PetArt.of(pet, size: 150),
              const SizedBox(height: 16),
              _Bubble(name: pet.name, line: FarewellScreen.petLine),
              const SizedBox(height: 22),
              GoldButton(
                label: '${josa(pet.name, '와/과')} 함께 가기',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// 손바닥 위의 빛 조각 (정령이 남긴 빛)
class _LightShard extends StatelessWidget {
  const _LightShard({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * 1.6,
        height: size * 1.6,
        child: Stack(alignment: Alignment.center, children: [
          Container(
            width: size * 1.5,
            height: size * 1.5,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color(0x99FFE9A8),
                Color(0x33FFD36B),
                Color(0x00FFD36B),
              ]),
            ),
          ),
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFFFE08A)],
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0xCCFFE08A), blurRadius: 24),
                ],
              ),
            ),
          ),
        ]),
      );
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
                    style: AppText.title(19, color: AppColors.goldBright)),
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
                    style: const TextStyle(color: AppColors.text, fontSize: 19),
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
                    style: AppText.title(19, color: AppColors.goldBright)),
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
