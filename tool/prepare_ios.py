"""GitHub 서버(Mac)에서 iPhone 앱을 만들기 전에, `flutter create` 가 만든
ios/ 폴더에 이 게임에 필요한 설정을 넣는다. (docs/platform_setup.md 의 아이폰 항목)

python3 tool/prepare_ios.py
"""
import json
import pathlib
import plistlib
import re

root = pathlib.Path(__file__).resolve().parent.parent
ios = root / "ios"
runner = ios / "Runner"

# 1. Info.plist: 앱 이름, 권한 설명(카메라·사진 저장은 11-11 #60 마법 돋보기), 수출 규정(암호화 없음)
info_path = runner / "Info.plist"
info = plistlib.loads(info_path.read_bytes())
info.update({
    "CFBundleDisplayName": "이세계가 현실이라면?",
    "NSHealthShareUsageDescription":
        "걸음 수로 상태창의 레벨과 던전 열쇠를 계산해요. 건강 데이터는 휴대폰 밖으로 보내지 않아요.",
    "NSHealthUpdateUsageDescription": "건강 앱에 기록을 쓰지 않아요. 읽기만 해요.",
    "NSLocationWhenInUseUsageDescription":
        "동네의 잿빛 안개를 걷고 가까운 이세계 장소를 찾을 때 위치를 써요. 앱을 보고 있을 때만 사용해요.",
    "NSCameraUsageDescription":
        "마법 돋보기로 감정할 때 카메라를 써요. 얼굴 인식은 휴대폰 안에서만 하고, 사진을 보내거나 저장해 두지 않아요.",
    "NSPhotoLibraryAddUsageDescription":
        "감정한 사진을 저장하기를 누르면 사진 앨범에 넣어요.",
    # 11-11: 카메라·사진 저장 패키지가 들어 있으면 애플이 이 설명도 요구한다
    # (없으면 업로드 뒤 처리에서 빌드가 빠진다). 마이크는 쓰지 않는다.
    "NSMicrophoneUsageDescription":
        "마법 돋보기는 소리를 쓰지 않아요. 카메라 기능에 함께 들어 있는 항목이라 설명만 적어 둬요.",
    "NSPhotoLibraryUsageDescription":
        "감정한 사진을 사진 앨범에 저장할 때만 써요. 앨범의 다른 사진은 보지 않아요.",
    "ITSAppUsesNonExemptEncryption": False,
})
# 11-12 #60 Snap Camera Kit: 앱 ID·API 토큰 (저장소 비밀 값, 없으면 렌즈 없이 지금 장식만)
import os
if os.environ.get("SNAP_APP_ID") and os.environ.get("SNAP_API_TOKEN"):
    info["SCCameraKitClientID"] = os.environ["SNAP_APP_ID"]
    info["SCCameraKitAPIToken"] = os.environ["SNAP_API_TOKEN"]
    # Snap 카메라는 동영상 녹화도 할 수 있어 마이크 설명이 필요하다
    info["NSMicrophoneUsageDescription"] = (
        "마법 돋보기의 렌즈 카메라에서 동영상을 찍을 때만 소리를 담아요. 소리를 따로 보내지 않아요.")

# 묶음 15 #103 보상형 광고 (AdMob): 앱 ID 가 없으면 광고 SDK 가 앱을 멈추므로 언제나 넣는다.
# 저장소 변수 ADMOB_APP_ID_IOS 가 없으면 Google 시험 앱 ID
info["GADApplicationIdentifier"] = os.environ.get(
    "ADMOB_APP_ID_IOS") or "ca-app-pub-3940256099942544~1458002511"
# 묶음 16: 앱 추적 투명성(ATT) 창 설명. 거부하면 맞춤이 아닌 광고만
info["NSUserTrackingUsageDescription"] = (
    "허용하면 관심사에 맞는 광고가 나와요. 허용하지 않아도 광고 보상은 똑같아요.")
info["SKAdNetworkItems"] = [{"SKAdNetworkIdentifier": "cstr6suwn9.skadnetwork"}]

info_path.write_bytes(plistlib.dumps(info))

# 2. HealthKit 권한 (entitlements)
ent = runner / "Runner.entitlements"
ent.write_bytes(plistlib.dumps({"com.apple.developer.healthkit": True,
                                "com.apple.developer.healthkit.access": []}))

pbx = ios / "Runner.xcodeproj" / "project.pbxproj"
s = pbx.read_text()
if "CODE_SIGN_ENTITLEMENTS" not in s:
    # Runner 앱 타깃의 빌드 설정(번들 ID 가 있는 곳)마다 넣는다. 테스트 타깃은 번들 ID 가 .RunnerTests 로 끝난다.
    s = re.sub(
        r"(\n(\s*)PRODUCT_BUNDLE_IDENTIFIER = kr\.itso\.isekaiReality;)",
        r"\n\2CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;\1",
        s,
    )
s = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 15.5;", s)
pbx.write_text(s)
# 11-11 #60: 얼굴 인식(Google ML Kit)이 iOS 15.5 이상을 요구한다

podfile = ios / "Podfile"
if podfile.exists():
    p = podfile.read_text()
    p = re.sub(r"#?\s*platform :ios, '[\d.]+'", "platform :ios, '15.5'", p)
    # 11-12 #60: Snap Camera Kit 화면 모듈이 iOS 15.5 이상이라 모든 라이브러리를 15.5 로 맞춘다
    if "IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'" not in p:
        p = p.replace(
            "flutter_additional_ios_build_settings(target)",
            "flutter_additional_ios_build_settings(target)\n"
            "    target.build_configurations.each do |config|\n"
            "      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.5'\n"
            "    end",
            1)
    podfile.write_text(p)

# 3. 앱 아이콘 (assets/branding/app_icon.png → 크기별, 투명 없이)
icon = root / "assets" / "branding" / "app_icon.png"
iconset = runner / "Assets.xcassets" / "AppIcon.appiconset"
if icon.exists() and iconset.exists():
    from PIL import Image  # pip install pillow

    src = Image.open(icon).convert("RGB")
    contents = json.loads((iconset / "Contents.json").read_text())
    for img in contents.get("images", []):
        name = img.get("filename")
        if not name:
            continue
        size = float(img["size"].split("x")[0])
        scale = int(img.get("scale", "1x").rstrip("x"))
        px = round(size * scale)
        src.resize((px, px), Image.LANCZOS).save(iconset / name)

print("ios/ 준비 완료")
