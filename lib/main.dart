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
import 'core/rules/name_rules.dart';
import 'package:app_links/app_links.dart';
import 'core/rules/place_grid.dart';
import 'core/rules/road_mask.dart';
import 'data/cloud/arca_api.dart';
import 'data/cloud/backup_server.dart';
import 'data/cloud/cloud_auth.dart';
import 'data/route/route_tile_source.dart';
import 'data/health/device_health_source.dart';
import 'data/location/location_source.dart';
import 'data/notify/notifier.dart';
import 'data/sound/sfx.dart';
import 'data/storage/record_store.dart';
import 'features/map/map_config.dart';
import 'theme/app_colors.dart';

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

  // 묶음 55 #245: 로그인 · 백업 · 서버 시간 (설정값이 없는 빌드는 지금처럼 휴대폰 기록만)
  final cloud = kDemoMode ? null : await FirebaseCloudAuth.start();
  final clock = ServerClock();
  final host = AppBinder(cloud: cloud, clock: clock);
  final controller = host.make(null);
  // 묶음 57: 이름 금칙어 (서버와 같은 목록, 서버에서 바뀐 목록은 앱이 켜진 뒤 받음)
  try {
    NameRules.load(await rootBundle.loadString('assets/data/banned_words.txt'));
  } catch (_) {}
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
  // 묶음 57: 파티 초대 링크 (Universal Links · App Links · arca://join/코드)
  if (!kDemoMode) {
    try {
      final links = AppLinks();
      links.uriLinkStream.listen((u) => (host.current ?? controller).handleInviteLink(u));
    } catch (_) {}
  }
  runApp(AppHost(host: host, first: controller));
  controller.init();
}

/// 컨트롤러를 만들고, 서버 기록으로 바꾼 뒤에는 새로 만든다 (묶음 55 #245)
class AppBinder {
  AppBinder({required this.cloud, required this.clock});

  final CloudAuth? cloud;
  final ServerClock clock;
  RetirableStore? _store;
  VoidCallback? onSwap;
  AppController? current;

  AppController make(AppController? from) {
    _store = RetirableStore(SharedPrefsRecordStore());
    final c = kDemoMode
        ? AppController.demo()
        : AppController(
            store: _store!,
            health: DeviceHealthSource(),
            location: DeviceLocationSource(),
            notifier: DeviceNotifier(),
            // 실제 앱은 위치를 알기 전에는 몬스터를 두지 않는다
            fallbackCenter: null,
            clock: clock.now,
          );
    if (!kDemoMode) {
      c.routeTiles = GithubRouteTiles();
      c.serverClock = clock;
      if (cloud != null) {
        c.cloudAuth = cloud;
        c.backupServer = FirestoreBackupServer();
      }
      // 묶음 56: 파티 · 문의 서버 (문의는 로그인 없이도)
      c.arcaApi = HttpArcaApi();
      c.consentGate = true; // 묶음 57: 처음 시작 · 바뀐 약관 동의
      c.onRestored = () => _restart(c);
    }
    if (from != null) {
      c.roads = from.roads;
      c.exclusions = from.exclusions;
      c.lands = from.lands;
    }
    current = c;
    return c;
  }

  Future<void> _restart(AppController old) async {
    _store?.retired = true;
    old.retire();
    make(old);
    onSwap?.call();
  }
}

/// 묶음 55: 서버 기록을 받아 오면 앱을 새 기록으로 다시 띄운다
class AppHost extends StatefulWidget {
  const AppHost({super.key, required this.host, required this.first});

  final AppBinder host;
  final AppController first;

  @override
  State<AppHost> createState() => _AppHostState();
}

class _AppHostState extends State<AppHost> {
  late AppController _c = widget.first;
  int _gen = 0;
  bool _swapping = false;

  @override
  void initState() {
    super.initState();
    widget.host.onSwap = _swap;
  }

  void _swap() {
    // 한 프레임 비우고(예전 화면을 모두 내린 뒤) 새 컨트롤러로
    setState(() => _swapping = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _c = widget.host.current!;
        _gen++;
        _swapping = false;
      });
      _c.init();
    });
  }

  @override
  Widget build(BuildContext context) => _swapping
      ? const ColoredBox(color: AppColors.deepNight)
      : IsekaiRealityApp(key: ValueKey(_gen), controller: _c);
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
