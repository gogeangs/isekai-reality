import 'dart:async';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry, compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_naver_map/flutter_naver_map.dart';

import 'app.dart';
import 'app_controller.dart';
import 'core/rules/exclusion_index.dart';
import 'core/rules/place_grid.dart';
import 'core/rules/road_mask.dart';
import 'data/route/route_tile_source.dart';
import 'data/health/device_health_source.dart';
import 'data/location/location_source.dart';
import 'data/notify/notifier.dart';
import 'data/sound/sfx.dart';
import 'data/storage/record_store.dart';
import 'features/map/map_config.dart';

/// 예시 데이터로 실행: flutter run --dart-define=DEMO=true
/// 네이버 지도 사용: --dart-define=NAVER_MAP_CLIENT_ID=발급받은ID
const bool kDemoMode = bool.fromEnvironment('DEMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 효과음 출처 (CC BY 4.0): 오픈소스 라이선스 화면에도 싣는다
  LicenseRegistry.addLicense(() => Stream.value(const LicenseEntryWithLineBreaks(
      ['Oculus Audio Pack 01 (sounds)'],
      'Sounds: "Oculus Audio Pack 01" by Oculus VR, LLC (Meta), '
      'licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). '
      'Some sounds were edited (layered, trimmed, faded).')));

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
  if (!kDemoMode) controller.routeTiles = GithubRouteTiles();
  try {
    controller.roads = RoadMask.tryParse(
        await rootBundle.loadString('assets/data/road_mask.json'));
  } catch (_) {
    // 격자가 없으면 길 검사 없이 둔다
  }
  // 장소 종류 격자 (묶음 13 C7): 크니 화면을 띄운 뒤 따로 풀어 둔다
  unawaited(_loadLands(controller));
  try {
    controller.exclusions = ExclusionIndex.tryParse(
        await rootBundle.loadString('assets/data/exclusions.json'));
  } catch (_) {
    // 자료가 없으면 이름을 아는 제외 구역만 쓴다
  }
  Sfx.init(); // 기다리지 않는다 (소리 준비가 늦어도 화면은 바로)
  runApp(IsekaiRealityApp(controller: controller));
  controller.init();
}

/// 장소 종류 격자를 풀어 컨트롤러에 넣는다 (없거나 틀리면 예전처럼 고르게)
Future<void> _loadLands(AppController c) async {
  try {
    final data = await rootBundle.load('assets/data/place_grid.bin');
    final raw = await compute(_gunzip, data.buffer.asUint8List());
    c.lands = PlaceGrid.tryParse(raw);
  } catch (_) {}
}

Uint8List _gunzip(Uint8List b) => Uint8List.fromList(gzip.decode(b));
