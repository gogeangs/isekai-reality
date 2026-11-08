import 'package:flutter/material.dart';

import 'app.dart';
import 'app_controller.dart';
import 'data/health/device_health_source.dart';
import 'data/storage/record_store.dart';

/// 예시 데이터로 실행: flutter run --dart-define=DEMO=true
const bool kDemoMode = bool.fromEnvironment('DEMO');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = kDemoMode
      ? AppController.demo()
      : AppController(
          store: SharedPrefsRecordStore(),
          health: DeviceHealthSource(),
        );
  runApp(IsekaiRealityApp(controller: controller));
  controller.init();
}
