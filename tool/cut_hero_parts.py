#!/usr/bin/env python3
"""각성자 부위 시트(hero_parts_<성별>.png)를 부위별 그림으로 자른다 (묶음 14 #81 2단계).

시트의 부위 13개를 투명한 곳으로 나눠 찾고, 줄(위→아래)·칸(왼→오른) 차례로 이름을 붙인다.
결과: assets/images/rig/hero_<성별>_<부위>.png (가로·세로 절반 크기)
부위를 다시 그리면 이 스크립트를 다시 돌린다:  python3 tool/cut_hero_parts.py
"""
import pathlib

import numpy as np
from PIL import Image
from scipy import ndimage

root = pathlib.Path(__file__).resolve().parent.parent
NAMES = ['head', 'torso', 'arm_back_upper', 'arm_front_upper', 'arm_back_fore',
         'hand_back', 'arm_front_fore', 'hand_front', 'leg_back_thigh',
         'leg_back_shin', 'leg_front_thigh', 'leg_front_shin', 'tail']

for g in ['male', 'female']:
    src = root / 'art_src' / f'hero_parts_{g}.png'
    if not src.exists():
        continue
    a = np.array(Image.open(src).convert('RGBA'))
    m = ndimage.binary_closing(a[:, :, 3] > 20, iterations=6)
    lab, _ = ndimage.label(m)
    objs = ndimage.find_objects(lab)
    parts = [(s, i + 1) for i, s in enumerate(objs) if (lab[s] == i + 1).sum() >= 3000]
    parts.sort(key=lambda r: (r[0][0].start // 300, r[0][1].start))
    if len(parts) != len(NAMES):
        raise SystemExit(f'{g}: 부위가 {len(parts)}개 (13개여야 함)')
    out = root / 'assets' / 'images' / 'rig'
    out.mkdir(exist_ok=True)
    for (s, idx), name in zip(parts, NAMES):
        sub = a[s].copy()
        sub[~ndimage.binary_dilation(lab[s] == idx, iterations=3)] = 0
        p = Image.fromarray(sub)
        p = p.resize((p.width // 2, p.height // 2), Image.LANCZOS)
        p.save(out / f'hero_{g}_{name}.png', optimize=True)
    print(g, '완료')
