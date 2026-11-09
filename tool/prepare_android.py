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
        f.write_text(s)

# 2. 권한, 앱 이름, 헬스 커넥트 연결
manifest = app / "src" / "main" / "AndroidManifest.xml"
s = manifest.read_text()
perms = """
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACTIVITY_RECOGNITION"/>
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
"""
if "health.READ_STEPS" not in s:
    s = re.sub(r"(<manifest[^>]*>)", r"\1" + perms, s, count=1)
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

print("android/ 준비 완료")
