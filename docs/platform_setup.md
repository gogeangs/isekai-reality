# 건강 앱 연동을 위한 휴대폰별 설정

`flutter create .` 로 `android/`, `ios/` 폴더를 만든 뒤 아래 내용을 추가합니다.
(GitHub의 자동 테스트는 이 설정 없이도 돌아갑니다. 실제 휴대폰에서 실행할 때만 필요해요.)

## 안드로이드 (헬스 커넥트)

1. `android/app/build.gradle` 의 `minSdkVersion` 을 **26** 이상으로 올립니다.

2. `android/app/src/main/AndroidManifest.xml` 의 `<manifest>` 안에 권한을 추가합니다.

```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_SLEEP"/>
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
```

## 예시 데이터로 실행

건강 앱 없이 2주치 예시 기록으로 화면만 보고 싶을 때:

```bash
flutter run --dart-define=DEMO=true
```
