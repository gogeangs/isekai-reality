"""GitHub 서버에서 Android 설치 파일을 만들기 전에, `flutter create` 가 만든
android/ 폴더에 이 게임에 필요한 설정을 넣는다. (docs/platform_setup.md 의 안드로이드 항목)

python3 tool/prepare_android.py
"""
import pathlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
app = root / "android" / "app"

# 1. 최소 안드로이드 버전 26 (헬스 커넥트)
for name in ["build.gradle.kts", "build.gradle"]:
    f = app / name
    if f.exists():
        s = f.read_text()
        s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 26", s)
        s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", "minSdkVersion 26", s)
        # 휴대폰 알림(flutter_local_notifications)에 필요한 자바 라이브러리 desugaring
        if "CoreLibraryDesugaring" not in s and "coreLibraryDesugaring" not in s:
            if name.endswith(".kts"):
                s = s.replace("compileOptions {",
                              "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", 1)
                s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
            else:
                s = s.replace("compileOptions {",
                              "compileOptions {\n        coreLibraryDesugaringEnabled true", 1)
                s += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        f.write_text(s)

# 2. 권한, 앱 이름, 헬스 커넥트 연결
manifest = app / "src" / "main" / "AndroidManifest.xml"
s = manifest.read_text()
perms = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
"""
if "health.READ_STEPS" not in s:
    s = re.sub(r"(<manifest[^>]*>)", r"\1" + perms, s, count=1)
# 11-11 #60 마법 돋보기: 카메라, 사진 저장(안드로이드 9 이하)
s = re.sub(r'android:label="[^"]*"', 'android:label="이세계가 현실이라면?"', s, count=1)
rationale = """
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>"""
if "SHOW_PERMISSIONS_RATIONALE" not in s:
    s = s.replace("</activity>", rationale + "\n        </activity>", 1)
alias = """
        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
                <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
            </intent-filter>
        </activity-alias>"""
if "ViewPermissionUsageActivity" not in s:
    s = s.replace("</application>", alias + "\n    </application>", 1)
queries = """
        <package android:name="com.google.android.apps.healthdata" />"""
if "com.google.android.apps.healthdata" not in s:
    if "<queries>" in s:
        s = s.replace("<queries>", "<queries>" + queries, 1)
    else:
        s = s.replace("</manifest>", "    <queries>" + queries + "\n    </queries>\n</manifest>", 1)
receivers = """
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>"""
if "ScheduledNotificationReceiver" not in s:
    s = s.replace("</application>", receivers + "\n    </application>", 1)
manifest.write_text(s)

# 3. MainActivity 는 FlutterFragmentActivity (헬스 커넥트 권한 창)
for f in (app / "src" / "main").rglob("MainActivity.kt"):
    f.write_text(
        "package " + re.search(r"package\s+([\w.]+)", f.read_text()).group(1) + "\n\n"
        "import io.flutter.embedding.android.FlutterFragmentActivity\n\n"
        "class MainActivity : FlutterFragmentActivity()\n"
    )

# 4. 앱 아이콘 (assets/branding/app_icon.png → 해상도별 아이콘)
icon = root / "assets" / "branding" / "app_icon.png"
sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
if icon.exists():
    from PIL import Image  # pip install pillow

    src = Image.open(icon).convert("RGBA")
    for dpi, px in sizes.items():
        out = app / "src" / "main" / "res" / f"mipmap-{dpi}" / "ic_launcher.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        src.resize((px, px), Image.LANCZOS).save(out)


# 11-12 #60 Snap Camera Kit: 앱 ID·API 토큰(저장소 비밀 값)과 AppCompat 테마(Snap 카메라 화면이 요구)
import os
snap_id = os.environ.get("SNAP_APP_ID", "")
snap_token = os.environ.get("SNAP_API_TOKEN", "")
manifest = app / "src" / "main" / "AndroidManifest.xml"
s = manifest.read_text()
if "com.snap.camerakit.app.id" not in s:
    meta = f"""
        <meta-data android:name="com.snap.camerakit.app.id" android:value="{snap_id}" />
        <meta-data android:name="com.snap.camerakit.api.token" android:value="{snap_token}" />"""
    s = re.sub(r"(<application[^>]*>)", lambda m: m.group(1) + meta, s, count=1)
if 'android:theme="@style/SnapAppCompat"' not in s:
    s = re.sub(r"<application", '<application android:theme="@style/SnapAppCompat"', s, count=1)
# 묶음 15 #103 보상형 광고 (AdMob): 앱 ID 가 없으면 광고 SDK 가 앱을 멈추므로 언제나 넣는다
admob_id = os.environ.get("ADMOB_APP_ID_ANDROID") or "ca-app-pub-3940256099942544~3347511713"
if "com.google.android.gms.ads.APPLICATION_ID" not in s:
    s = re.sub(r"(<application[^>]*>)", lambda m: m.group(1) + f"""
        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="{admob_id}" />""", s, count=1)
manifest.write_text(s)
styles = app / "src" / "main" / "res" / "values" / "styles.xml"
if styles.exists():
    st = styles.read_text()
    if "SnapAppCompat" not in st:
        st = st.replace("</resources>",
                        '    <style name="SnapAppCompat" parent="Theme.AppCompat.NoActionBar">\n    </style>\n</resources>')
        styles.write_text(st)

# 11-12 #60: camerakit_flutter 가 compileSdk 33 으로 되어 있어 새 androidx 와 맞지 않는다 → 36 으로 올린다
root_gradle = root / "android" / "build.gradle.kts"
if root_gradle.exists():
    g = root_gradle.read_text()
    if "camerakit_flutter" not in g:
        g = """subprojects {
    // camerakit_flutter 가 가져오는 옛 Kotlin 때문에 출시 전 lint 검사가 다른 플러그인에서 멈춘다 → lintVital 끔
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
    afterEvaluate {
        if (project.name == "camerakit_flutter") {
            project.extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?.compileSdk = 36
        }
    }
}

""" + g
        root_gradle.write_text(g)
else:
    root_groovy = root / "android" / "build.gradle"
    if root_groovy.exists():
        g = root_groovy.read_text()
        if "camerakit_flutter" not in g:
            g = """subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach { enabled = false }
    afterEvaluate { p ->
        if (p.name == "camerakit_flutter" && p.hasProperty("android")) {
            p.android.compileSdkVersion 36
        }
    }
}

""" + g
            root_groovy.write_text(g)

print("android/ 준비 완료")
