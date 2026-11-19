import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'pet_art.dart';
import 'pet_screen.dart';

/// 묶음 73 #313: 상태 화면 스탯 줄 아래 「함께하는 펫」 칸.
/// 동행 펫 얼굴 · 이름 · Lv · 특성 한 줄 + 「내 펫 ○마리 보기」. 정령이 떠나기 전엔 칸 없음
class CompanionPetPanel extends StatelessWidget {
  const CompanionPetPanel({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          if (!c.farewellDone) return const SizedBox.shrink();
          final pet = c.companionPet;
          void open() => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => PetScreen(controller: c)));
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              key: const Key('statusPets'),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xAA12142E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('함께하는 펫', style: AppText.title(14, color: AppColors.goldBright)),
                const SizedBox(height: 6),
                if (pet != null)
                  Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.slotBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
                      ),
                      child: Center(child: PetArt.of(pet, size: 46)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: Text(pet.name,
                                key: const Key('statusPetName'),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 6),
                          Text('Lv.${pet.level}', style: AppText.level(13)),
                        ]),
                        const SizedBox(height: 2),
                        KText(pet.adult ? pet.info.specialAdult : pet.info.special,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ]),
                    ),
                  ])
                else
                  const KText('함께할 펫을 골라 보세요',
                      key: Key('statusPetNone'),
                      style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FrameButton(
                  key: const Key('statusPetsOpen'),
                  label: '내 펫 ${c.pets.pets.length}마리 보기',
                  icon: Icons.pets_rounded,
                  height: 40,
                  onPressed: open,
                ),
              ]),
            ),
          );
        },
      );
}
