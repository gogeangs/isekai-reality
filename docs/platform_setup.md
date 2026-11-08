# 휴대폰별 설정 (건강 앱 · 위치 · 네이버 지도)

`flutter create .` 로 `android/`, `ios/` 폴더를 만든 뒤 아래 내용을 추가합니다.
(GitHub의 자동 테스트는 이 설정 없이도 돌아갑니다. 실제 휴대폰에서 실행할 때만 필요해요.)

## 안드로이드 (헬스 커넥트)

1. `android/app/build.gradle` 의 `minSdkVersion` 을 **26** 이상으로 올립니다.

2. `android/app/src/main/AndroidManifest.xml` 의 `<manifest>` 안에 권한을 추가합니다.

```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_SLEEP"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

3. 같은 파일의 `<activity android:name=".MainActivity" ...>` 안에, 헬스 커넥트가 권한 설명 화면을 열 수 있게 추가합니다.

```xml
<intent-filter>
    <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
</intent-filter>
```

4. `MainActivity.kt` 가 `FlutterFragmentActivity` 를 상속하도록 바꿉니다.

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

## 아이폰 (건강 앱 / HealthKit)

1. Xcode 에서 `ios/Runner.xcworkspace` 를 열고, Runner → Signing & Capabilities → **+ Capability → HealthKit** 을 추가합니다.

2. `ios/Runner/Info.plist` 에 사용 목적을 적습니다. (사용자에게 그대로 보이는 문장)

```xml
<key>NSHealthShareUsageDescription</key>
<string>걸음 수와 수면 기록으로 상태창의 레벨과 던전 열쇠를 계산해요. 건강 데이터는 휴대폰 밖으로 보내지 않아요.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>건강 앱에 기록을 쓰지 않아요. 읽기만 해요.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>동네의 잿빛 안개를 걷고 가까운 이세계 장소를 찾을 때 위치를 써요. 앱을 보고 있을 때만 사용해요.</string>
```

## 네이버 지도

1. [네이버 클라우드 플랫폼](https://www.ncloud.com) 콘솔 → Maps → Application 등록 → **Dynamic Map** 선택
2. 안드로이드 패키지 이름 `kr.itso.isekai_reality`, iOS Bundle ID 를 입력 (`flutter create --org kr.itso` 로 만든 경우)
3. 발급받은 **Client ID** 를 실행할 때 넣습니다. 저장소에는 올리지 않아요.

```bash
flutter run --dart-define=NAVER_MAP_CLIENT_ID=발급받은ID
```

Client ID 없이 실행하면 지도 탭에 '탐험 현황'(밝힌 칸 수, 방문한 장소)이 대신 나옵니다.

## 예시 데이터로 실행

건강 앱 없이 2주치 예시 기록으로 화면만 보고 싶을 때:

```bash
flutter run --dart-define=DEMO=true
```
