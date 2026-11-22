import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/pet_state.dart' show Pet;
import '../../theme/app_colors.dart';
import '../pets/pet_art.dart';

/// 남은 시간 「1시간 5분」 · 「12분」
String petPickMinutes(Duration d) {
  final m = d.inMinutes;
  if (m >= 60) return '${m ~/ 60}시간 ${m % 60}분';
  return '${m < 1 ? 1 : m}분';
}

/// 묶음 81 #374: 원정 보내기 창 펫 고르기 — 한 줄 얼굴 칸.
/// 동그란 펫 얼굴 + 아래 이름, 골라진 펫은 금빛 테. 잘 맞는 펫은 오른쪽 위 ★.
/// 원정 중 · 지쳐 쉬는 중 · 훈련 중인 펫은 흐리게 + 남은 시간, 누를 수 없음.
class ExpeditionPetPicker extends StatelessWidget {
  const ExpeditionPetPicker({
    super.key,
    required this.controller,
    required this.pets,
    required this.chosen,
    required this.onPick,
    this.suits,
  });

  final AppController controller;

  /// 보여 줄 순서 (잘 맞는 펫을 앞에)
  final List<Pet> pets;
  final String? chosen;
  final ValueChanged<String> onPick;

  /// 이 몬스터와 잘 맞는 펫인지 (없으면 ★ 없음)
  final bool Function(Pet)? suits;

  /// 칸 아래 작은 글 (보낼 수 없을 때 이유 · 남은 시간)
  static String? statusOf(AppController c, Pet p) {
    final away = c.petAwayLeft(p.uid);
    if (away != null) return '원정 중 ${petPickMinutes(away)}';
    final tired = c.petTiredLeft(p.uid);
    if (tired != null) return '쉬는 중 ${petPickMinutes(tired)}';
    if (c.petInTraining(p.uid)) return '훈련 중';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final anySuits = suits != null && pets.any((p) => suits!(p) && c.petCanSend(p.uid));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          key: const Key('expPetPicker'),
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final p in pets)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _Cell(
                  key: Key('expPet_${p.uid}'),
                  pet: p,
                  selected: p.uid == chosen,
                  suits: suits?.call(p) ?? false,
                  status: statusOf(c, p),
                  onTap: c.petCanSend(p.uid) ? () => onPick(p.uid) : null,
                ),
              ),
          ]),
        ),
        if (anySuits)
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text('★ 이 몬스터와 잘 맞아요',
                key: Key('expSuitsLine'),
                style: TextStyle(color: AppColors.goldBright, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.pet,
    required this.selected,
    required this.suits,
    required this.status,
    required this.onTap,
  });

  final Pet pet;
  final bool selected;
  final bool suits;
  final String? status;
  final VoidCallback? onTap;

  static const double face = 56;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    final cell = SizedBox(
      width: face + 14,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: face,
            height: face,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.chipBg,
              border: Border.all(
                  color: selected ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.35),
                  width: selected ? 2.5 : 1),
              boxShadow: selected ? const [BoxShadow(color: Color(0x66F5DC94), blurRadius: 8)] : null,
            ),
            child: ClipOval(child: Padding(padding: const EdgeInsets.all(4), child: PetArt.of(pet, size: face - 8))),
          ),
          if (suits)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                key: Key('suits_${pet.uid}'),
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold,
                    border: Border.all(color: AppColors.night, width: 1.5)),
                child: const Text('★', style: TextStyle(color: AppColors.night, fontSize: 11, fontWeight: FontWeight.w900, height: 1.1)),
              ),
            ),
        ]),
        const SizedBox(height: 3),
        Text(pet.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: selected ? AppColors.goldBright : AppColors.text,
                fontSize: 11.5,
                fontWeight: FontWeight.w700)),
        if (status != null)
          // 「원정 중 1시간 5분」처럼 길면 두 줄로 (잘리지 않게)
          Text(status!,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10, height: 1.2)),
      ]),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: off ? Opacity(opacity: 0.45, child: cell) : cell,
    );
  }
}
