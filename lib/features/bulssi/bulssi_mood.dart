import 'package:flutter/widgets.dart';

import '../../data/storage/record_store.dart';
import '../../core/rules/pet_rules.dart';
import '../pets/pet_art.dart';
import 'spirit_art.dart';


/// 불씨의 빛 색: 맑음 황금, 비 하늘색, 밤 보라, 눈 흰색
enum BulssiMood { gold, sky, night, snow }

extension BulssiMoodColor on BulssiMood {
  Color get color => switch (this) {
        BulssiMood.gold => const Color(0xFFF5C451),
        BulssiMood.sky => const Color(0xFF7FC8F5),
        BulssiMood.night => const Color(0xFFB08CF0),
        BulssiMood.snow => const Color(0xFFF4F7FF),
      };
}

class BulssiMoods {
  BulssiMoods._();

  /// 밤(저녁 8시 ~ 아침 6시)은 보라, 그 밖에는 황금. 기기 시간만 쓴다
  /// (날씨 기능은 묶음 13에서 뺐다).
  static BulssiMood of({required DateTime now}) {
    final night = now.hour >= 20 || now.hour < 6;
    return night ? BulssiMood.night : BulssiMood.gold;
  }
}

/// 화면 어디서나 불씨 색과 이름을 알 수 있게 내려 준다
class BulssiScope extends InheritedWidget {
  const BulssiScope({
    super.key,
    required this.mood,
    required this.spiritName,
    this.kind = SpiritKind.fire,
    this.petSpecies,
    this.petAdult = false,
    required super.child,
  });

  /// 정령이 떠난 뒤 데리고 다니는 펫 (11-11 #38). 있으면 그림·빛이 펫으로 바뀐다.
  final PetSpecies? petSpecies;
  final bool petAdult;

  final BulssiMood mood;
  final String spiritName;

  /// 함께하는 정령 종류
  final SpiritKind kind;

  /// 정령 빛 색: 속성 색을 바탕으로, 비·눈·밤에는 살짝 물든다
  Color get glow {
    final base = petSpecies != null ? petColor(petSpecies!) : spiritColor(kind);
    if (mood == BulssiMood.gold) return base;
    return Color.lerp(base, mood.color, 0.35)!;
  }

  static BulssiScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BulssiScope>();

  @override
  bool updateShouldNotify(BulssiScope oldWidget) =>
      mood != oldWidget.mood ||
      spiritName != oldWidget.spiritName ||
      kind != oldWidget.kind ||
      petSpecies != oldWidget.petSpecies ||
      petAdult != oldWidget.petAdult;
}

/// 지금 함께하는 동료 그림: 정령, 또는 정령이 떠난 뒤의 펫
class CompanionArt extends StatelessWidget {
  const CompanionArt(
      {super.key, this.size = 64, this.mood = SpiritMood.normal, this.kind});

  final double size;
  final SpiritMood mood;

  /// 정령 종류를 따로 정할 때 (없으면 [BulssiScope])
  final SpiritKind? kind;

  @override
  Widget build(BuildContext context) {
    final scope = BulssiScope.maybeOf(context);
    final pet = scope?.petSpecies;
    if (pet != null && kind == null) {
      return SizedBox(
          width: size,
          height: size * 1.1,
          child: Center(
              child: PetArt(species: pet, adult: scope!.petAdult, size: size)));
    }
    return SpiritArt(
        kind: kind ?? scope?.kind ?? SpiritKind.fire,
        size: size,
        name: scope?.spiritName,
        mood: mood);
  }
}

/// MP 이름: 정령이 떠난 뒤에는 펫들이 나눠 쓰는 「펫 MP」
String mpLabel(BuildContext context) =>
    BulssiScope.maybeOf(context)?.petSpecies != null ? '펫 MP' : '정령 MP';

/// 던전 스킬 이름: 정령의 일격, 또는 동행 펫의 스킬
String skillLabel(BuildContext context) {
  final pet = BulssiScope.maybeOf(context)?.petSpecies;
  return pet == null ? '정령의 일격!' : '${PetRules.info(pet).skillName}!';
}
