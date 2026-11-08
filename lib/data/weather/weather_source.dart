import 'dart:convert';
import 'dart:io';

import '../../core/geo/geo.dart';

enum WeatherKind { clear, cloudy, rain, snow }

extension WeatherKindLabel on WeatherKind {
  String get koreanName => switch (this) {
        WeatherKind.clear => '맑음',
        WeatherKind.cloudy => '흐림',
        WeatherKind.rain => '비',
        WeatherKind.snow => '눈',
      };
}

/// 지금 날씨 (현재 값만 쓴다)
class WeatherNow {
  const WeatherNow({required this.kind, this.isDay = true, this.temperatureC});

  final WeatherKind kind;
  final bool isDay;
  final double? temperatureC;

  /// WMO 날씨 코드 → 네 가지로 묶는다
  static WeatherKind kindFromWmo(int code) {
    if (code <= 1) return WeatherKind.clear;
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return WeatherKind.snow;
    }
    if ((code >= 51 && code <= 67) ||
        (code >= 80 && code <= 82) ||
        code >= 95) {
      return WeatherKind.rain;
    }
    return WeatherKind.cloudy; // 2, 3, 45, 48 (구름·안개)
  }
}

abstract class WeatherSource {
  /// 실패하면 null (날씨 없이도 게임은 돌아간다)
  Future<WeatherNow?> current(GeoPoint at);
}

/// Open-Meteo (키가 필요 없는 무료 날씨 API). 위치는 소수점 2자리(약 1km)로만 보낸다.
class OpenMeteoWeatherSource implements WeatherSource {
  OpenMeteoWeatherSource({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<WeatherNow?> current(GeoPoint at) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': at.lat.toStringAsFixed(2),
        'longitude': at.lng.toStringAsFixed(2),
        'current': 'weather_code,is_day,temperature_2m',
        'timezone': 'auto',
      });
      final request =
          await _client.getUrl(uri).timeout(const Duration(seconds: 8));
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = await response.transform(utf8.decoder).join();
      return parse(jsonDecode(body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static WeatherNow? parse(Map<String, dynamic> json) {
    final current = json['current'];
    if (current is! Map) return null;
    final code = current['weather_code'];
    if (code is! num) return null;
    return WeatherNow(
      kind: WeatherNow.kindFromWmo(code.toInt()),
      isDay: (current['is_day'] as num?)?.toInt() != 0,
      temperatureC: (current['temperature_2m'] as num?)?.toDouble(),
    );
  }
}

class FakeWeatherSource implements WeatherSource {
  FakeWeatherSource([this.weather]);

  WeatherNow? weather;
  int calls = 0;

  @override
  Future<WeatherNow?> current(GeoPoint at) async {
    calls++;
    return weather;
  }
}
