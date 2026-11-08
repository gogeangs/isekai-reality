/// 네이버 지도 Client ID.
///
/// 저장소에 올리지 않고 실행할 때 넣는다:
///   flutter run --dart-define=NAVER_MAP_CLIENT_ID=발급받은ID
/// 비어 있으면 지도 대신 '탐험 현황' 화면을 보여 준다 (테스트·CI 포함).
const String kNaverMapClientId =
    String.fromEnvironment('NAVER_MAP_CLIENT_ID');

bool get naverMapEnabled => kNaverMapClientId.isNotEmpty;
