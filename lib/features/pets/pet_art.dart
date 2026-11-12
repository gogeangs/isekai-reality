import 'package:flutter/material.dart';

import '../../core/models/pet_state.dart';
import '../../core/rules/pet_rules.dart';
import '../../theme/app_colors.dart';

/// 펫 색 (빛, 그림이 없을 때 아이콘 색)
Color petColor(PetSpecies s) => switch (s) {
      PetSpecies.crow => const Color(0xFF9AA6D8),
      PetSpecies.blackCat => const Color(0xFFC79BFF),
      PetSpecies.toad => const Color(0xFF7FD0A0),
      PetSpecies.owl => const Color(0xFFE8C66A),
      PetSpecies.lizard => const Color(0xFFFF9E5E),
      PetSpecies.homunculus => const Color(0xFF7FD0FF),
    };

IconData petIcon(PetSpecies s) => switch (s) {
      PetSpecies.crow => Icons.flutter_dash_rounded,
      PetSpecies.blackCat => Icons.pets_rounded,
      PetSpecies.toad => Icons.water_drop_rounded,
      PetSpecies.owl => Icons.visibility_rounded,
      PetSpecies.lizard => Icons.local_fire_department_rounded,
      PetSpecies.homunculus => Icons.science_rounded,
    };

/// 펫 그림 (pet_<종류>_baby/adult.png). 그림이 오기 전에는 아이콘으로.
class PetArt extends StatelessWidget {
  const PetArt(
      {super.key, required this.species, this.adult = false, this.size = 64});

  PetArt.of(Pet pet, {super.key, this.size = 64})
      : species = pet.species,
        adult = pet.adult;

  final PetSpecies species;
  final bool adult;
  final double size;

  @override
  Widget build(BuildContext context) {
    final info = PetRules.info(species);
    return Image.asset(
      info.asset(adult: adult),
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

/// 펫 알 그림
class EggArt extends StatelessWidget {
  const EggArt({super.key, this.size = 64, this.glowing = false});

  final double size;
  final bool glowing;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/pet_egg.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.egg_rounded,
            size: size * 0.9,
            color: glowing ? AppColors.goldBright : const Color(0xFFF2E6CF)),
      );
}
