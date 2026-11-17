"""묶음 55 #245: 저장소 비밀값(FIREBASE_IOS_PLIST · FIREBASE_ANDROID_JSON)에서 Firebase 설정값을 꺼내
빌드에 넣을 --dart-define 목록을 build/firebase_defines.txt 에 쓴다 (한 줄에 하나).
iOS 는 구글 로그인 주소(REVERSED_CLIENT_ID)를 Info.plist 에 넣고, Apple 로그인 권한을 더한다.

값은 화면(빌드 기록)에 찍지 않는다. 비밀값이 없으면 빈 목록 → 앱은 로그인 「준비 중」.

python3 tool/firebase_setup.py ios|android
"""
import json
import os
import pathlib
import plistlib
import sys

root = pathlib.Path(__file__).resolve().parent.parent
target = sys.argv[1] if len(sys.argv) > 1 else "android"
defines = {}

raw_plist = os.environ.get("FIREBASE_IOS_PLIST", "").strip()
raw_json = os.environ.get("FIREBASE_ANDROID_JSON", "").strip()

ios = None
if raw_plist:
    try:
        ios = plistlib.loads(raw_plist.encode())
    except Exception:
        print("FIREBASE_IOS_PLIST 를 읽지 못했어요")
if ios:
    defines.update({
        "FB_PROJECT_ID": ios.get("PROJECT_ID", ""),
        "FB_SENDER_ID": ios.get("GCM_SENDER_ID", ""),
        "FB_STORAGE_BUCKET": ios.get("STORAGE_BUCKET", ""),
        "FB_API_KEY_IOS": ios.get("API_KEY", ""),
        "FB_APP_ID_IOS": ios.get("GOOGLE_APP_ID", ""),
        "FB_IOS_CLIENT_ID": ios.get("CLIENT_ID", ""),
    })

android = None
if raw_json:
    try:
        android = json.loads(raw_json)
    except Exception:
        print("FIREBASE_ANDROID_JSON 을 읽지 못했어요")
if android:
    info = android.get("project_info", {})
    defines.setdefault("FB_PROJECT_ID", info.get("project_id", ""))
    defines.setdefault("FB_SENDER_ID", info.get("project_number", ""))
    defines.setdefault("FB_STORAGE_BUCKET", info.get("storage_bucket", ""))
    web = ""
    for c in android.get("client", []):
        pkg = c.get("client_info", {}).get("android_client_info", {}).get("package_name")
        oauth = list(c.get("oauth_client", []))
        oauth += c.get("services", {}).get("appinvite_service", {}).get("other_platform_oauth_client", [])
        for o in oauth:
            if o.get("client_type") == 3 and not web:
                web = o.get("client_id", "")
        if pkg == "kr.itso.isekai_reality":
            defines["FB_APP_ID_ANDROID"] = c.get("client_info", {}).get("mobilesdk_app_id", "")
            keys = c.get("api_key", [])
            if keys:
                defines["FB_API_KEY_ANDROID"] = keys[0].get("current_key", "")
    if web:
        defines["FB_WEB_CLIENT_ID"] = web

out = root / "build" / "firebase_defines.txt"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("".join(f"--dart-define={k}={v}\n" for k, v in defines.items() if v))
print(f"Firebase 설정값 {sum(1 for v in defines.values() if v)}개 (값은 찍지 않음)")
if target == "android" and "FB_WEB_CLIENT_ID" not in defines:
    print("::warning::google-services.json 에 웹 OAuth 클라이언트(client_type 3)가 없어 Android 구글 로그인이 안 될 수 있어요")

if target == "ios":
    runner = root / "ios" / "Runner"
    info_path = runner / "Info.plist"
    if info_path.exists() and ios and ios.get("REVERSED_CLIENT_ID"):
        info = plistlib.loads(info_path.read_bytes())
        types = [t for t in info.get("CFBundleURLTypes", []) if t.get("CFBundleURLName") != "google"]
        types.append({"CFBundleURLName": "google",
                      "CFBundleURLSchemes": [ios["REVERSED_CLIENT_ID"]]})
        info["CFBundleURLTypes"] = types
        if ios.get("CLIENT_ID"):
            info["GIDClientID"] = ios["CLIENT_ID"]
        info_path.write_bytes(plistlib.dumps(info))
    ent = runner / "Runner.entitlements"
    if ent.exists():
        e = plistlib.loads(ent.read_bytes())
        e["com.apple.developer.applesignin"] = ["Default"]
        ent.write_bytes(plistlib.dumps(e))
    print("iOS 로그인 설정 넣음")
