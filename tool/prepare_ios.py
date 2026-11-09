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

# 1. Info.plist: 앱 이름, 권한 설명, 수출 규정(암호화 없음)
info_path = runner / "Info.plist"
info = plistlib.loads(info_path.read_bytes())
info.update({
    "CFBundleDisplayName": "이세계가 현실이라면?",
    "NSHealthShareUsageDescription":
        "걸음 수로 상태창의 레벨과 던전 열쇠를 계산해요. 건강 데이터는 휴대폰 밖으로 보내지 않아요.",
    "NSHealthUpdateUsageDescription": "건강 앱에 기록을 쓰지 않아요. 읽기만 해요.",
    "NSLocationWhenInUseUsageDescription":
        "동네의 잿빛 안개를 걷고 가까운 이세계 장소를 찾을 때 위치를 써요. 앱을 보고 있을 때만 사용해요.",
    "ITSAppUsesNonExemptEncryption": False,
})
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
s = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;", "IPHONEOS_DEPLOYMENT_TARGET = 14.0;", s)
pbx.write_text(s)

podfile = ios / "Podfile"
if podfile.exists():
    p = podfile.read_text()
    p = re.sub(r"#?\s*platform :ios, '[\d.]+'", "platform :ios, '14.0'", p)
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
