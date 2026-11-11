/// 앱 설정값
///
/// 제외 구역 요청·문의를 받을 곳 (2026-11-09 결정). 바꾸려면:
///   flutter run --dart-define=SUPPORT_CONTACT=다른이메일또는링크
const String kSupportContact = String.fromEnvironment('SUPPORT_CONTACT',
    defaultValue: 'biz@project30s.co.kr');

/// 화면에 보이는 앱 버전 (pubspec.yaml 의 version 과 맞춘다)
const String kAppVersion = '0.1.0';

/// 빌드 번호와 커밋 (GitHub 빌드가 넣어 준다). 받은 테스트 앱이 몇 번째인지 확인용.
const String kAppBuild = String.fromEnvironment('APP_BUILD');
const String kAppCommit = String.fromEnvironment('APP_COMMIT');

/// 설정 화면에 보이는 버전 (예: '0.1.0 (44 · 4ba1dc2)')
String get appVersionLabel => kAppBuild.isEmpty
    ? kAppVersion
    : '$kAppVersion ($kAppBuild${kAppCommit.isEmpty ? '' : ' · ${kAppCommit.length > 7 ? kAppCommit.substring(0, 7) : kAppCommit}'})';
