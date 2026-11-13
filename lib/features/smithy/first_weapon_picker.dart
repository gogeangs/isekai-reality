import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/hero_rig.dart';
import '../battle/battle_view.dart' show HeroSprite, HeroPose;
import 'equipment_view.dart';

/// 첫 무기 고르기 (묶음 19 #5): 5종 카드 + 고른 무기로 휘두르는 모습 미리보기.
/// 화면에는 수치 대신 성격 한 줄만.
class FirstWeaponPicker extends StatefulWidget {
  const FirstWeaponPicker({
    super.key,
    required this.controller,
    required this.onCraft,
    this.onPicked,
  });

  final AppController controller;

  /// 고른 무기로 만들기 (무료)
  final ValueChanged<EquipBase> onCraft;

  /// 카드를 골랐을 때 (튜토리얼이 다음 단계로)
  final ValueChanged<EquipBase>? onPicked;

  static const choices = [
    EquipBase.ironSword,
    EquipBase.woodAxe,
    EquipBase.ironSpear,
    EquipBase.dagger,
    EquipBase.staff,
  ];

  @override
  State<FirstWeaponPicker> createState() => _FirstWeaponPickerState();
}

class _FirstWeaponPickerState extends State<FirstWeaponPicker>
    with SingleTickerProviderStateMixin {
  EquipBase? _pick;

  // 미리보기: 휘두르기 → 잠깐 쉬기를 몇 번 (무한 반복 없음)
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _choose(EquipBase b) {
    setState(() => _pick = b);
    _a
      ..reset()
      ..repeat(count: 4);
    widget.onPicked?.call(b);
  }

  @override
  Widget build(BuildContext context) {
    final pick = _pick;
    final look = widget.controller.profile.look;
    return OrnatePanel(
      key: const Key('firstWeaponPicker'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('첫 무기 고르기', style: AppText.title(17)),
          const SizedBox(height: 2),
          const KText('하나만 무료로 만들 수 있어요. 다른 무기는 나중에 재료로 만들 수 있어요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in FirstWeaponPicker.choices)
                _Card(
                  base: b,
                  selected: pick == b,
                  onTap: () => _choose(b),
                ),
            ],
          ),
          if (pick != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: Row(children: [
                Expanded(
                  child: AnimatedBuilder(
                    animation: _a,
                    builder: (context, _) {
                      // 앞 70% 휘두르기, 뒤 30% 숨 고르기
                      final v = _a.value;
                      final swing = v < 0.7;
                      return HeroRig(
                        key: const Key('firstWeaponPreview'),
                        look: look,
                        weapon: weaponKindOf(pick),
                        action: swing ? RigAction.attack : RigAction.idle,
                        t: swing ? v / 0.7 : 0,
                        breath: v,
                        reduced:
                            MediaQuery.maybeDisableAnimationsOf(context) ?? false,
                        fallback: HeroSprite(
                            look: look,
                            pose: swing ? HeroPose.attack : HeroPose.idle),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(EquipmentRules.info(pick).name,
                          style: AppText.title(18, color: AppColors.goldBright)),
                      const SizedBox(height: 4),
                      KText(EquipmentRules.info(pick).trait ?? '',
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 14)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            GoldButton(
              key: const Key('firstWeaponCraft'),
              label: '만들기 (무료)',
              height: 46,
              fontSize: 16,
              onPressed: () => widget.onCraft(pick),
            ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.base, required this.selected, required this.onTap});

  final EquipBase base;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final info = EquipmentRules.info(base);
    return GestureDetector(
      key: Key('firstWeapon_${base.name}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 96,
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0x553A2E0A) : const Color(0x66101333),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? AppColors.goldBright : const Color(0x55C9A24A),
              width: selected ? 2 : 1),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          EquipIcon(base: base, size: 48),
          const SizedBox(height: 4),
          Text(info.name,
              textAlign: TextAlign.center,
              style: AppText.title(13, color: AppColors.text)),
          const SizedBox(height: 2),
          KText(info.trait ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
      ),
    );
  }
}
