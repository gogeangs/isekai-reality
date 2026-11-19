import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/pet_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import 'pet_art.dart';
import 'pet_screen.dart';

/// 묶음 75 #328: 상태 화면 스탯 줄 아래 「내 펫 ○마리」 3칸 격자.
/// 함께하는 펫이 맨 앞(금테 + 「함께」 리본), 원정 중 · 훈련 중은 흐리게 + 작은 띠.
/// 칸을 누르면 그 펫 자세히. 6마리까지 보이고 넘으면 「모두 보기 (○마리)」. 정령이 떠나기 전엔 칸 없음
class CompanionPetPanel extends StatelessWidget {
  const CompanionPetPanel({super.key, required this.controller});

  final AppController controller;

  static const shown = 6;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final c = controller;
          if (!c.farewellDone) return const SizedBox.shrink();
          final comp = c.companionPet;
          final all = [
            if (comp != null) comp,
            for (final p in c.pets.pets)
              if (p.uid != comp?.uid) p,
          ];
          final away = {
            for (final e in c.activeExpeditions)
              if (e.petUid != null) e.petUid!,
          };
          void open([String? uid]) => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => PetScreen(controller: c, focus: uid)));
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
                Text('내 펫 ${all.length}마리',
                    key: const Key('statusPetsTitle'), style: AppText.title(14, color: AppColors.goldBright)),
                const SizedBox(height: 6),
                if (all.isEmpty)
                  const KText('함께할 펫을 골라 보세요',
                      key: Key('statusPetNone'),
                      style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700))
                else
                  GridView.count(
                    key: const Key('statusPetGrid'),
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.86,
                    children: [
                      for (final p in all.take(shown))
                        _PetTile(
                          pet: p,
                          together: p.uid == comp?.uid,
                          badge: away.contains(p.uid)
                              ? '원정 중'
                              : c.petInTraining(p.uid)
                                  ? '훈련 중'
                                  : null,
                          onTap: () => open(p.uid),
                        ),
                    ],
                  ),
                if (all.length > shown) ...[
                  const SizedBox(height: 8),
                  FrameButton(
                    key: const Key('statusPetsOpen'),
                    label: '모두 보기 (${all.length}마리)',
                    icon: Icons.pets_rounded,
                    height: 40,
                    onPressed: open,
                  ),
                ],
              ]),
            ),
          );
        },
      );
}

class _PetTile extends StatelessWidget {
  const _PetTile({required this.pet, required this.together, this.badge, required this.onTap});

  final Pet pet;
  final bool together;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      decoration: BoxDecoration(
        color: AppColors.slotBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: together ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.4), width: together ? 2 : 1),
        boxShadow: together ? const [BoxShadow(color: Color(0x66FFD86B), blurRadius: 6)] : null,
      ),
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
      child: Stack(clipBehavior: Clip.none, children: [
        Column(children: [
          Expanded(child: Center(child: PetArt.of(pet, size: 56))),
          Text(pet.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
          Text('Lv.${pet.level}', style: AppText.level(11.5)),
        ]),
        if (together)
          Positioned(
            left: -4,
            top: -6,
            child: Container(
              key: const Key('statusPetTogether'),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: AppColors.goldBright, borderRadius: BorderRadius.circular(8)),
              child: const Text('함께', style: TextStyle(color: AppColors.night, fontSize: 10.5, fontWeight: FontWeight.w900)),
            ),
          ),
        if (badge != null)
          Positioned(
            left: 0,
            right: 0,
            top: 30,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xCC0B0D26), borderRadius: BorderRadius.circular(8)),
                child: Text(badge!, style: const TextStyle(color: AppColors.text, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
      ]),
    );
    return GestureDetector(
      key: Key('statusPet_${pet.uid}'),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: badge != null ? Opacity(opacity: 0.55, child: tile) : tile,
    );
  }
}
