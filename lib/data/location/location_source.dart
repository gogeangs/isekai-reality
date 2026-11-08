import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../core/geo/geo.dart';

/// 현재 위치를 읽는 곳. 실제 기기는 [DeviceLocationSource],
/// 테스트는 [FakeLocationSource] 를 쓴다.
abstract class LocationSource {
  /// 위치 권한을 요청한다. 허용되면 true.
  Future<bool> requestPermission();

  /// 위치가 바뀔 때마다 알려 준다 (앱을 보고 있을 때만)
  Stream<LocationFix> fixes();
}

class DeviceLocationSource implements LocationSource {
  @override
  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  @override
  Stream<LocationFix> fixes() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15, // 15m 움직일 때마다
        ),
      ).map((p) => LocationFix(
            point: GeoPoint(p.latitude, p.longitude),
            speedMps: p.speed < 0 ? 0 : p.speed,
          ));
}

/// 테스트용: [emit] 으로 위치를 직접 넣는다
class FakeLocationSource implements LocationSource {
  FakeLocationSource({this.granted = true});

  final bool granted;
  final _controller = StreamController<LocationFix>.broadcast();

  void emit(LocationFix fix) => _controller.add(fix);

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Stream<LocationFix> fixes() => _controller.stream;
}
