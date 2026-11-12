#!/usr/bin/env python3
"""앱 그림 줄이기 (묶음 17 #145).

assets/images 아래 PNG·JPG 를 WebP 로 바꾸고, 작게 보이는 그림은 화면에 보이는
크기의 2~3배로 줄인다. 이미 바꾼 그림은 건너뛴다(여러 번 돌려도 같음).

- 대표가 올리는 그림은 지금처럼 PNG 로 올리면 된다. 빌드·테스트 때 이 스크립트가
  먼저 돌아 같은 이름의 .webp 로 바꾸고 PNG 는 지운다.
- 같은 이름의 PNG 를 새로 올리면 그 그림으로 .webp 를 다시 만든다.
- 크게 보이는 그림(배경·각성자·몬스터·정령 등)은 크기를 그대로 두고 형식만 바꾼다.
- 부위 그림(rig)·금테 틀(ui_)·무기(weapon_)는 코드가 그림 안 픽셀 좌표를 쓰므로
  크기를 절대 바꾸지 않는다.

    python3 tool/optimize_images.py            # 바꾸기
    python3 tool/optimize_images.py --check    # 바꿀 그림이 남았는지만 (있으면 1)
"""
from __future__ import annotations

import io
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / 'assets' / 'images'

# 이름 앞부분 → 가장 긴 변(px). 화면에 보이는 가장 큰 크기의 약 2.5~3배.
# 목록에 없으면 크기는 그대로 (형식만 WebP).
MAX_SIDE: list[tuple[str, int]] = [
    ('equip_', 256),      # 장비 아이콘: 가장 크게 96
    ('mat_', 192),        # 재료: 가장 크게 64
    ('potion_', 160),     # 물약: 40~56
    ('stat_', 160),       # 스탯 메달: 52
    ('status_', 128),     # 상태 이상: 24~40
    ('tool_', 160),       # 채집 도구: 48
    ('title_', 160),      # 칭호 배지: 38~48
    ('icon_', 192),       # 게임 아이콘: 가장 크게 56~64
    ('item_', 192),       # 잡화상 물건: 56
    ('pet_map_', 128),    # 지도 위 펫: 40
    ('map_', 160),        # 지도 표시: 40~56
]

# 크기를 절대 바꾸지 않는 그림 (그림 안 좌표를 코드가 씀)
FIXED = ('rig/', 'ui_', 'weapon_', 'banner_', 'ribbon_')

# 테두리가 또렷해야 하는 그림은 무손실
LOSSLESS = ('ui_', 'map_step_', 'slot_')

QUALITY = 90          # 눈으로 차이 없는 품질
ALPHA_QUALITY = 100   # 투명 테두리는 손실 없이


def max_side(rel: str) -> int | None:
    if rel.startswith(FIXED):
        return None
    for prefix, side in MAX_SIDE:
        if rel.startswith(prefix):
            return side
    return None


def encode(img: Image.Image, rel: str) -> bytes:
    has_alpha = img.mode in ('RGBA', 'LA') or (
        img.mode == 'P' and 'transparency' in img.info)
    img = img.convert('RGBA' if has_alpha else 'RGB')
    outs = []
    lossy = io.BytesIO()
    img.save(lossy, 'WEBP', quality=QUALITY, alpha_quality=ALPHA_QUALITY,
             method=6)
    outs.append(lossy.getvalue())
    if rel.startswith(LOSSLESS) or img.width * img.height <= 128 * 128:
        lossless = io.BytesIO()
        img.save(lossless, 'WEBP', lossless=True, method=6)
        outs.append(lossless.getvalue())
        if rel.startswith(LOSSLESS):
            return outs[-1]
    return min(outs, key=len)


def convert(src: Path) -> tuple[int, int]:
    rel = src.relative_to(ROOT).as_posix()
    img = Image.open(src)
    img.load()
    side = max_side(rel)
    if side and max(img.size) > side:
        scale = side / max(img.size)
        size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
        img = img.convert('RGBA').resize(size, Image.LANCZOS)
    data = encode(img, rel)
    dst = src.with_suffix('.webp')
    before = src.stat().st_size
    dst.write_bytes(data)
    src.unlink()
    return before, len(data)


def main() -> int:
    # 부위를 잘라 내는 원본 시트(*_parts_*)는 바꾸지 않는다 (tool/cut_hero_parts.py 가 읽음)
    todo = sorted(p for p in ROOT.rglob('*')
                  if p.suffix.lower() in ('.png', '.jpg', '.jpeg')
                  and '_parts_' not in p.name)
    if '--check' in sys.argv:
        for p in todo:
            print(p.relative_to(ROOT))
        return 1 if todo else 0
    total_b = total_a = 0
    for p in todo:
        b, a = convert(p)
        total_b += b
        total_a += a
    if todo:
        print(f'그림 {len(todo)}장: {total_b / 1e6:.1f}MB → {total_a / 1e6:.1f}MB')
    else:
        print('바꿀 그림이 없어요.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
