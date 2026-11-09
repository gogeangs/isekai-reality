import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'app.dart';
import 'app_controller.dart';
import 'core/rules/road_mask.dart';
import 'data/health/device_health_source.dart';
import 'data/location/location_source.dart';
import 'data/notify/notifier.dart';
import 'data/storage/record_store.dart';
import 'data/weather/weather_source.dart';
import 'features/map/map_config.dart';

/// 예시 데이터로 실행: flutter run --dart-define=DEMO=true
/// 네이버 지도 사용: --dart-define=NAVER_MAP_CLIENT_ID=발급받은ID
const bool kDemoMode = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (naverMapEnabled) {
    await FlutterNaverMap().init(
      clientId: kNaverMapClientId,
      onAuthFailed: (error) => debugPrint('네이버 지도 인증 실패: $error'),
    );
  }

  final controller = kDemoMode
      ? AppController.demo()
      : AppController(
          store: SharedPrefsRecordStore(),
          health: DeviceHealthSource(),
          location: DeviceLocationSource(),
          weatherSource: OpenMeteoWeatherSource(),
          notifier: DeviceNotifier(),
        );
  try {
    controller.roads = RoadMask.tryParse(
        await rootBundle.loadString('assets/data/road_mask.json'));
  } catch (_) {
    // 격자가 없으면 길 검사 없이 둔다
  }
  runApp(IsekaiRealityApp(controller: controller));
  controller.init();
}
