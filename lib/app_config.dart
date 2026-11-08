/// 실행할 때 넣는 설정값 (저장소에는 올리지 않음)
///
/// 제외 구역 요청·문의를 받을 곳:
///   flutter run --dart-define=SUPPORT_CONTACT=문의받을이메일또는링크
const String kSupportContact = String.fromEnvironment('SUPPORT_CONTACT');

/// 화면에 보이는 앱 버전 (pubspec.yaml 의 version 과 맞춘다)
const String kAppVersion = '0.1.0';
