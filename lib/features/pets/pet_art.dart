import 'package:flutter/material.dart';

import '../../core/models/pet_state.dart';
import '../../core/rules/pet_rules.dart';
import '../../theme/app_colors.dart';

/// 등급 꼬리표: 「 · 희귀」 · 「 · 영웅」 (일반은 없음)
String petGradeTag(PetGrade g) => switch (g) {
      PetGrade.rare => ' · 희귀',
      PetGrade.hero => ' · 영웅',
      PetGrade.legend => ' · 전설',
      PetGrade.common => '',
    };

/// 펫 색 (빛, 그림이 없을 때 아이콘 색)
Color petColor(PetSpecies s) => switch (s) {
      PetSpecies.crow => const Color(0xFF9AA6D8),
      PetSpecies.blackCat => const Color(0xFFC79BFF),
      PetSpecies.toad => const Color(0xFF7FD0A0),
      PetSpecies.owl => const Color(0xFFE8C66A),
      PetSpecies.lizard => const Color(0xFFFF9E5E),
      PetSpecies.homunculus => const Color(0xFF7FD0FF),
      PetSpecies.griffin => const Color(0xFFFFE066),
      PetSpecies.direwolf => const Color(0xFFA8E0FF),
      PetSpecies.drake => const Color(0xFFFF7A4A),
      PetSpecies.kelpie => const Color(0xFF5EC8F0),
      PetSpecies.mimic => const Color(0xFFD9B36A),
      PetSpecies.golem => const Color(0xFFB8A27A),
      // 묶음 49 #235 영웅 펫
      PetSpecies.wolf => const Color(0xFFCFE8FF),
      PetSpecies.turtle => const Color(0xFF8FCB6A),
      PetSpecies.panther => const Color(0xFFA98BFF),
      PetSpecies.whale => const Color(0xFF9FD8F5),
      PetSpecies.phoenix => const Color(0xFFFF8A3D),
      PetSpecies.stag => const Color(0xFFFFE08A),
      // 묶음 57 #244 전설 펫
      PetSpecies.pegasus => const Color(0xFFE6F2FF),
      PetSpecies.behemoth => const Color(0xFFB59A6A),
      PetSpecies.nightmare => const Color(0xFF8A6BFF),
      PetSpecies.leviathan => const Color(0xFF4FB3E8),
      PetSpecies.dragon => const Color(0xFFFF5A3D),
      PetSpecies.unicorn => const Color(0xFFFFF2B8),
    };

IconData petIcon(PetSpecies s) => switch (s) {
      PetSpecies.crow => Icons.flutter_dash_rounded,
      PetSpecies.blackCat => Icons.pets_rounded,
      PetSpecies.toad => Icons.water_drop_rounded,
      PetSpecies.owl => Icons.visibility_rounded,
      PetSpecies.lizard => Icons.local_fire_department_rounded,
      PetSpecies.homunculus => Icons.science_rounded,
      PetSpecies.griffin => Icons.bolt_rounded,
      PetSpecies.direwolf => Icons.ac_unit_rounded,
      PetSpecies.drake => Icons.whatshot_rounded,
      PetSpecies.kelpie => Icons.waves_rounded,
      PetSpecies.mimic => Icons.inventory_2_rounded,
      PetSpecies.golem => Icons.landscape_rounded,
      PetSpecies.wolf => Icons.air_rounded,
      PetSpecies.turtle => Icons.eco_rounded,
      PetSpecies.panther => Icons.nightlight_round,
      PetSpecies.whale => Icons.cloud_rounded,
      PetSpecies.phoenix => Icons.local_fire_department_rounded,
      PetSpecies.stag => Icons.wb_sunny_rounded,
      PetSpecies.pegasus => Icons.auto_awesome_rounded,
      PetSpecies.behemoth => Icons.terrain_rounded,
      PetSpecies.nightmare => Icons.dark_mode_rounded,
      PetSpecies.leviathan => Icons.tsunami_rounded,
      PetSpecies.dragon => Icons.whatshot_rounded,
      PetSpecies.unicorn => Icons.star_rounded,
    };

/// 펫 그림 (pet_<종류>_baby/adult.png). 그림이 오기 전에는 아이콘으로.
class PetArt extends StatelessWidget {
  const PetArt(
      {super.key,
      required this.species,
      this.adult = false,
      this.awake = false,
      this.size = 64});

  PetArt.of(Pet pet, {super.key, this.size = 64})
      : species = pet.species,
        adult = pet.adult,
        awake = pet.awake;

  final PetSpecies species;
  final bool adult;

  /// 묶음 49 #235: 영웅 펫 단짝 「각성 모습」
  final bool awake;
  final double size;

  @override
  Widget build(BuildContext context) {
    final info = PetRules.info(species);
    return Image.asset(
      info.asset(adult: adult, awake: awake),
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: info.name,
      errorBuilder: (_, __, ___) => Image.asset(
        // 성체 그림이 없으면 아기 그림
        info.asset(adult: false),
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.chipBg,
            border: Border.all(color: petColor(species), width: adult ? 2 : 1.2),
          ),
          child: Icon(petIcon(species),
              size: size * 0.56, color: petColor(species)),
        ),
      ),
    );
  }
}

/// 묶음 72 더하기: 전투 무대의 펫 (전투용 그림 · 왼쪽을 보는 그림은 뒤집어 몬스터 쪽으로)
class PetBattleArt extends StatelessWidget {
  const PetBattleArt(
      {super.key, required this.species, this.adult = false, this.awake = false, this.size = 64});

  final PetSpecies species;
  final bool adult;
  final bool awake;
  final double size;

  @override
  Widget build(BuildContext context) {
    final flip = PetRules.flipInBattle(species, adult: adult, awake: awake);
    return Transform.flip(
      key: Key('petBattle_${species.name}${flip ? '_flip' : ''}'),
      flipX: flip,
      child: Image.asset(
        PetRules.battleAsset(species, adult: adult, awake: awake),
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticLabel: PetRules.info(species).name,
        errorBuilder: (_, __, ___) =>
            PetArt(species: species, adult: adult, awake: awake, size: size),
      ),
    );
  }
}

/// 펫 알 그림
class EggArt extends StatelessWidget {
  const EggArt({super.key, this.size = 64, this.glowing = false});

  final double size;
  final bool glowing;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/pet_egg.webp',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.egg_rounded,
            size: size * 0.9,
            color: glowing ? AppColors.goldBright : const Color(0xFFF2E6CF)),
      );
}
