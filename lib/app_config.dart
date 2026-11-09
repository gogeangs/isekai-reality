/// 앱 설정값
///
/// 제외 구역 요청·문의를 받을 곳 (2026-11-09 결정). 바꾸려면:
///   flutter run --dart-define=SUPPORT_CONTACT=다른이메일또는링크
const String kSupportContact = String.fromEnvironment('SUPPORT_CONTACT',
    defaultValue: 'biz@project30s.co.kr');

/// 화면에 보이는 앱 버전 (pubspec.yaml 의 version 과 맞춘다)
const String kAppVersion = '0.1.0';
