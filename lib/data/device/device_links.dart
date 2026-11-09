import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// 휴대폰의 다른 앱 열기 (메일, 앱 설정). 실패하면 false.
class DeviceLinks {
  DeviceLinks._();

  /// 메일 앱을 받는 사람·제목·본문이 채워진 채로 연다
  static Future<bool> openMail({
    required String to,
    required String subject,
    required String body,
  }) async {
    final uri = Uri.parse('mailto:$to'
        '?subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// 이 앱의 휴대폰 설정 화면 (권한 켜고 끄기)
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
