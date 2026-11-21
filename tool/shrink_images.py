#!/usr/bin/env python3
"""묶음 80 #370: 큰 그림 크기 · 품질 줄이기 (같은 이름으로 덮어씀, 원본은 art_src/b80_before/ 에 보관).

기준
- 화면에 실제로 그려지는 가장 큰 크기(물리 픽셀)는 시험을 IMG_LOG 로 돌려 모은 표
  (그림 경로 · 가로 · 세로)에서 읽는다. 같은 묶음(이름 앞부분)에서 가장 크게 그려진 비율보다
  작게는 줄이지 않는다(시험에 안 나온 화면 대비). 그보다 큰 그림만 그 크기(+여유 10%)까지 줄인다.
- 그림 안 픽셀 좌표를 코드가 쓰는 그림(ui_ · weapon_ · banner_ · ribbon_ · 돋보기 틀 · 종족 장식 ·
  로고 · 마을 바탕 · 5막 지도 · 부위 원본)은 크기를 바꾸지 않는다.
- 여섯 칸 그림(hero_*_attack_* · ally_*_attack)은 칸 너비가 정수로 남게 줄인다.
- WebP 품질: 불투명 80 · 투명 80 + 투명 테두리는 손실 없이(alpha_quality 100).
- 새 파일이 원래보다 5% 넘게 작아질 때만 덮어쓴다.

    python3 tool/shrink_images.py <크기표.tsv> [--dry]

크기표 만드는 법 (묶음 80): test/flutter_test_config.dart 에서 시험마다 debugOnPaintImage 로
ImageSizeInfo(source · displaySize)를 모아 tearDownAll 에 「경로\t가로\t세로」로 적고, 캡처 시험 ·
일반 시험을 모두 돌림. (Flutter 시험은 이 값을 바꾸면 멈추므로 그때만 painting/debug.dart 의
debugOnPaintImage 확인을 잠깐 빼고 돌린 뒤 되돌림)
"""
from __future__ import annotations

import io
import math
import re
import shutil
import sys
from collections import defaultdict
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / 'assets' / 'images'
KEEP = ROOT / 'art_src' / 'b80_before'

QUALITY = 80
ALPHA_QUALITY = 100
MARGIN = 1.1

FIXED = ('ui_', 'weapon_', 'banner_', 'ribbon_', 'lens_', 'filter_', 'logo_', 'village_bg', 'map_erbard')
SHEETS = (re.compile(r'^hero_.*attack.*\.webp$'), re.compile(r'^ally_.*_attack\.webp$'))
FRAMES = 6

# 줄이는 묶음 (먼저 배경 · 주인공, 그다음 몬스터 · 스킬 · 마을 · 동료 …)
GROUPS = ('bg_', 'hero_', 'monster_', 'skill_', 'village_', 'ally_', 'npc_', 'pet_', 'scene_',
          'map_region_', 'ending_', 'intro_', 'farewell_', 'town_', 'harvest_', 'job_', 'fx_',
          'spirit_', 'deco_', 'boss_', 'act', 'raid_', 'guild_', 'erbard_')


def group_of(name: str) -> str:
    m = re.match(r'([a-z]+_?)', name)
    return m.group(1) if m else name


def load_sizes(path: str) -> dict[str, tuple[int, int]]:
    most: dict[str, tuple[int, int]] = {}
    for line in Path(path).read_text().splitlines():
        parts = line.split('\t')
        if len(parts) != 3:
            continue
        name = parts[0].split('/')[-1]
        w, h = int(parts[1]), int(parts[2])
        o = most.get(name, (0, 0))
        most[name] = (max(o[0], w), max(o[1], h))
    return most


def encode(img: Image.Image) -> bytes:
    alpha = img.mode in ('RGBA', 'LA') or (img.mode == 'P' and 'transparency' in img.info)
    img = img.convert('RGBA' if alpha else 'RGB')
    if alpha:
        # 완전히 투명한 곳은 색을 버려도 되지만 테두리 색이 번지지 않게 그대로 둔다 (exact)
        pass
    b = io.BytesIO()
    img.save(b, 'WEBP', quality=QUALITY, alpha_quality=ALPHA_QUALITY, method=6)
    return b.getvalue()


def target_size(name: str, img: Image.Image, need: float) -> tuple[int, int] | None:
    """need: 그림 대비 그려지는 비율(가로 · 세로 중 큰 쪽). 1 이상이면 줄이지 않음."""
    s = need * MARGIN
    if s >= 0.97:
        return None
    w, h = img.size
    if any(p.match(name) for p in SHEETS) and w % FRAMES == 0:
        fw = max(1, math.ceil(w / FRAMES * s))
        return fw * FRAMES, max(1, math.ceil(h * s))
    return max(1, math.ceil(w * s)), max(1, math.ceil(h * s))


def main() -> int:
    sizes = load_sizes(sys.argv[1])
    dry = '--dry' in sys.argv
    # 묶음마다 가장 크게 그려진 비율 (표에 없는 그림에 씀)
    ratio: dict[str, float] = {}
    group_ratio: dict[str, float] = defaultdict(float)
    files = sorted(p for p in IMAGES.glob('*.webp'))
    dims = {}
    for p in files:
        with Image.open(p) as im:
            dims[p.name] = im.size
    for name, (dw, dh) in sizes.items():
        if name not in dims:
            continue
        w, h = dims[name]
        r = max(dw / w, dh / h)
        ratio[name] = r
        g = group_of(name)
        group_ratio[g] = max(group_ratio[g], r)
    before = after = 0
    rows = []
    for p in files:
        name = p.name
        if name.startswith(FIXED) or not name.startswith(GROUPS):
            continue
        # 같은 묶음에서 가장 크게 그려진 비율보다 작게는 줄이지 않는다 (시험에 안 나온 화면 대비)
        guessed = name not in ratio
        need = max(ratio.get(name, 0.0), group_ratio.get(group_of(name), 1.0))
        img = Image.open(p)
        img.load()
        old = p.stat().st_size
        size = target_size(name, img, need)
        out = img if size is None else img.convert('RGBA' if img.mode in ('RGBA', 'LA', 'P') else 'RGB').resize(size, Image.LANCZOS)
        data = encode(out)
        if len(data) > old * 0.95:
            continue
        before += old
        after += len(data)
        rows.append((name, img.size, out.size, old, len(data), guessed, round(need, 3)))
        if not dry:
            KEEP.mkdir(parents=True, exist_ok=True)
            keep = KEEP / name
            if not keep.exists():
                shutil.copy2(p, keep)
            p.write_bytes(data)
    for r in rows:
        print('\t'.join(str(x) for x in r))
    print(f'바꾼 그림 {len(rows)}장: {before / 1e6:.1f}MB → {after / 1e6:.1f}MB (−{(before - after) / 1e6:.1f}MB)', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
