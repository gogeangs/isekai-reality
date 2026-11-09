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
<uses-permission android:name="android.permission.INTERNET"/>  <!-- 지도·날씨 -->
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
<string>걸음 수로 상태창의 레벨과 던전 열쇠를 계산해요. 건강 데이터는 휴대폰 밖으로 보내지 않아요.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>건강 앱에 기록을 쓰지 않아요. 읽기만 해요.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>동네의 잿빛 안개를 걷고 가까운 이세계 장소를 찾을 때 위치를 써요. 앱을 보고 있을 때만 사용해요.</string>
```

## 네이버 지도

1. [네이버 클라우드 플랫폼](https://www.ncloud.com) 콘솔 → Maps → Application 등록 → **Dynamic Map** 선택
2. 안드로이드 패키지 이름 `kr.itso.isekai_reality`, iOS Bundle ID 를 입력 (`flutter create --org kr.itso` 로 만든 경우)
   - 2026년 11월 9일 등록 완료: 앱 이름 `isekai-reality`, iOS Bundle ID `kr.itso.isekaiReality`. Client ID는 콘솔 → Maps → Application → isekai-reality → 인증 정보에서 확인 (Client Secret은 모바일 지도에 필요 없음)
3. 발급받은 **Client ID** 를 실행할 때 넣습니다. 저장소에는 올리지 않아요.

```bash
flutter run --dart-define=NAVER_MAP_CLIENT_ID=발급받은ID
```

Client ID 없이 실행하면 지도 탭에 '탐험 현황'(밝힌 칸 수, 방문한 장소)이 대신 나옵니다.

## 날씨

불씨 색(맑음 황금, 비 하늘색, 밤 보라, 눈 흰색)은 [Open-Meteo](https://open-meteo.com) 무료 날씨 API 로 정합니다. 키가 필요 없고, 위치는 소수점 둘째 자리(약 1km)까지만 보냅니다. 30분에 한 번만 읽고, 실패하면 시간(밤이면 보라)으로만 정합니다.
상업적으로 출시할 때는 Open-Meteo 이용 조건(상업 이용은 유료 요금제)을 다시 확인하세요.

## 앱 아이콘

아이콘 원본은 `assets/branding/app_icon.png`(1024×1024)입니다. `flutter create` 로 휴대폰 폴더를 만든 뒤 한 번만 실행합니다.

```bash
flutter pub add dev:flutter_launcher_icons
dart run flutter_launcher_icons --image-path assets/branding/app_icon.png
```

시작 화면 그림은 `assets/images/splash.jpg` 이고, 앱이 불러오는 동안 보여 줍니다.

## 예시 데이터로 실행

건강 앱 없이 2주치 예시 기록으로 화면만 보고 싶을 때:

```bash
flutter run --dart-define=DEMO=true
```

## 테스트용 Android 설치 파일 (APK)

컴퓨터에 개발 도구를 설치하지 않고 GitHub 서버에서 만듭니다 (`.github/workflows/android.yml`).

- 코드를 올리면 자동으로 다시 만들고, [Releases › android-test](https://github.com/gogeangs/isekai-reality/releases/tag/android-test) 에 `isekai-reality.apk` 로 올라갑니다.
- 휴대폰용 설정(권한, 헬스 커넥트, 앱 아이콘)은 `tool/prepare_android.py` 가 넣습니다.
- 네이버 지도 Client ID 는 저장소 Settings › Secrets and variables › Actions 의 `NAVER_MAP_CLIENT_ID` 에서 읽습니다. 없으면 지도 탭에 탐험 현황이 나옵니다.
- 빌드 기록은 `android-log` 브랜치에 남습니다.
- 테스트용이라 개발용 서명으로 만듭니다. 설치할 때 '출처를 알 수 없는 앱 허용'이 필요하고, Play 스토어 출시 전에는 정식 서명 키를 만들어야 합니다.
