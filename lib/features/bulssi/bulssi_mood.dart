import 'package:flutter/widgets.dart';

import '../../data/storage/record_store.dart';
import 'spirit_art.dart';

import '../../data/weather/weather_source.dart';

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

  /// 밤(저녁 8시 ~ 아침 6시, 또는 해가 진 뒤)은 보라가 우선.
  /// 그 밖에는 날씨를 따른다. 날씨를 모르면 황금.
  static BulssiMood of({WeatherNow? weather, required DateTime now}) {
    final night = now.hour >= 20 || now.hour < 6 || weather?.isDay == false;
    if (night) return BulssiMood.night;
    return switch (weather?.kind) {
      WeatherKind.rain => BulssiMood.sky,
      WeatherKind.snow => BulssiMood.snow,
      _ => BulssiMood.gold,
    };
  }
}

/// 화면 어디서나 불씨 색과 이름을 알 수 있게 내려 준다
class BulssiScope extends InheritedWidget {
  const BulssiScope({
    super.key,
    required this.mood,
    required this.spiritName,
    this.kind = SpiritKind.fire,
    required super.child,
  });

  final BulssiMood mood;
  final String spiritName;

  /// 함께하는 정령 종류
  final SpiritKind kind;

  /// 정령 빛 색: 속성 색을 바탕으로, 비·눈·밤에는 살짝 물든다
  Color get glow {
    final base = spiritColor(kind);
    if (mood == BulssiMood.gold) return base;
    return Color.lerp(base, mood.color, 0.35)!;
  }

  static BulssiScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BulssiScope>();

  @override
  bool updateShouldNotify(BulssiScope oldWidget) =>
      mood != oldWidget.mood ||
      spiritName != oldWidget.spiritName ||
      kind != oldWidget.kind;
}
