/// 묶음 55 #245: Firebase 설정값. GitHub 빌드가 저장소 비밀값(GoogleService-Info.plist ·
/// google-services.json)에서 꺼내 --dart-define 으로 넣는다. 없으면 로그인 · 백업 칸은
/// 「준비 중」으로 보이고, 게임은 지금처럼 휴대폰 기록만 쓴다.
class CloudConfig {
  CloudConfig._();

  static const String projectId = String.fromEnvironment('FB_PROJECT_ID');
  static const String apiKeyIos = String.fromEnvironment('FB_API_KEY_IOS');
  static const String apiKeyAndroid = String.fromEnvironment('FB_API_KEY_ANDROID');
  static const String appIdIos = String.fromEnvironment('FB_APP_ID_IOS');
  static const String appIdAndroid = String.fromEnvironment('FB_APP_ID_ANDROID');
  static const String senderId = String.fromEnvironment('FB_SENDER_ID');
  static const String storageBucket = String.fromEnvironment('FB_STORAGE_BUCKET');

  /// iOS 구글 로그인 (GoogleService-Info.plist 의 CLIENT_ID)
  static const String iosClientId = String.fromEnvironment('FB_IOS_CLIENT_ID');

  /// 서버용(웹) OAuth 클라이언트 (google-services.json 의 client_type 3). Android 구글 로그인에 필요
  static const String webClientId = String.fromEnvironment('FB_WEB_CLIENT_ID');

  static bool get configured => projectId.isNotEmpty && senderId.isNotEmpty;

  /// Firestore 문서 주소 앞부분 (REST)
  static String get documents =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';
}
