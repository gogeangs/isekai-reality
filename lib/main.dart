import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'app.dart';
import 'app_controller.dart';
import 'core/rules/exclusion_index.dart';
import 'core/rules/road_mask.dart';
import 'data/health/device_health_source.dart';
import 'data/location/location_source.dart';
import 'data/notify/notifier.dart';
import 'data/storage/record_store.dart';
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
          notifier: DeviceNotifier(),
          // 실제 앱은 위치를 알기 전에는 몬스터를 두지 않는다
          fallbackCenter: null,
        );
  try {
    controller.roads = RoadMask.tryParse(
        await rootBundle.loadString('assets/data/road_mask.json'));
  } catch (_) {
    // 격자가 없으면 길 검사 없이 둔다
  }
  try {
    controller.exclusions = ExclusionIndex.tryParse(
        await rootBundle.loadString('assets/data/exclusions.json'));
  } catch (_) {
    // 자료가 없으면 이름을 아는 제외 구역만 쓴다
  }
  runApp(IsekaiRealityApp(controller: controller));
  controller.init();
}
