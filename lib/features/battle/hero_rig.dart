import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/rules/equipment_rules.dart';

/// 묶음 73 #261: 부위 애니메이션(HeroRig)은 그만 쓰고 통 그림(HeroSprite)으로 바꿨다.
/// 무기 종류는 장비 성격·효과(화살 등)에 그대로 쓴다.

/// 무기 종류 (장비마다 하나). 없으면 맨손.
enum WeaponKind { sword, axe, dagger, spear, staff, bow }

/// 장비 → 무기 종류 (보스 장비는 가장 가까운 종류로)
WeaponKind? weaponKindOf(EquipBase? base) => switch (base) {
      EquipBase.dagger ||
      EquipBase.hornDagger ||
      EquipBase.nightWeapon ||
      EquipBase.uniqArbelDagger ||
      EquipBase.uniqMoonFang =>
        WeaponKind.dagger,
      EquipBase.staff ||
      EquipBase.flameWeapon ||
      EquipBase.elowinStaff ||
      EquipBase.uniqNaomiStaff =>
        WeaponKind.staff,
      EquipBase.ironSword || EquipBase.morvalWeapon || EquipBase.morvalSword => WeaponKind.sword,
      EquipBase.woodAxe ||
      EquipBase.seleniaWeapon ||
      EquipBase.seleniaAxe ||
      EquipBase.uniqGrumHammer =>
        WeaponKind.axe,
      EquipBase.ironSpear || EquipBase.elowinWeapon || EquipBase.aurelWeapon => WeaponKind.spear,
      EquipBase.bow || EquipBase.aurelBow => WeaponKind.bow,
      EquipBase.wardenWeapon ||
      EquipBase.frostWeapon ||
      EquipBase.ashWeapon ||
      EquipBase.skyWeapon ||
      EquipBase.baldrinWeapon =>
        WeaponKind.sword,
      EquipBase.groveWeapon => WeaponKind.axe,
      EquipBase.stormWeapon ||
      EquipBase.uniqTeoSpear ||
      EquipBase.baldrinSpear =>
        WeaponKind.spear,
      _ => null,
    };

/// 상태 화면 서기(숨쉬기): 통 그림을 아주 조금 늘였다 줄인다.
/// 「동작 줄이기」·테스트에서는 멈춘 그림.
class BreathingHero extends StatefulWidget {
  const BreathingHero({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<BreathingHero> createState() => _BreathingHeroState();
}

class _BreathingHeroState extends State<BreathingHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3200));

  /// 테스트(pumpAndSettle)가 끝나지 않는 일이 없게 멈춘다
  static bool disabledForTests =
      Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant BreathingHero old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final on = widget.enabled &&
        !disabledForTests &&
        !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (on && !_c.isAnimating) {
      unawaited(_c.repeat());
    } else if (!on && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          final s = math.sin(_c.value * math.pi * 2);
          return Transform(
            key: const Key('heroBreath'),
            alignment: Alignment.bottomCenter,
            transform: Matrix4.diagonal3Values(1 - s * 0.004, 1 + s * 0.012, 1),
            child: child,
          );
        },
      );
}
