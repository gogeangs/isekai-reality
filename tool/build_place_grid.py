#!/usr/bin/env python3
"""OpenStreetMap 으로 전국 「장소 종류」 격자를 만든다 (묶음 13 C7).

채집 자리 종류와 필드 전투 배경을 실제 장소(공원·숲·물·바다·산·도심·마을)에 맞출 때 쓴다.
앱 안에 넣어 두고 휴대폰 안에서만 찾는다 (서버 없음, 위치가 기기 밖으로 나가지 않음).

입력 (GitHub Actions place-grid.yml 이 받는다)
  - south-korea-latest.osm.pbf  (Geofabrik, © OpenStreetMap 기여자, ODbL)
  - land-polygons-split-4326    (osmdata.openstreetmap.de, 육지 = 바다 아닌 곳)

결과: assets/data/place_grid.bin  (gzip)
  'PG1\\0' + uint32 머리말 길이 + 머리말 JSON
    {north, west, latStep, lngStep, rows, cols, tile, kinds}
  + uint32 × (타일 수)  타일 시작 위치 (자료 부분 기준, 0xFFFFFFFF = 없음)
  + 자료: 타일마다 [종류 1바이트, 길이 varint] 반복 (타일 안 행 우선)
  행 0 = 북쪽.

종류: 0 마을·주택가(그 밖의 땅) 1 공원 2 숲 3 강·호수 4 바다 5 산 6 도심
"""
import gzip
import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

NORTH, WEST, SOUTH, EAST = 38.7, 124.5, 33.0, 131.0
CELL_M = 100.0
TILE = 64

VILLAGE, PARK, FOREST, WATER, SEA, MOUNTAIN, CITY = range(7)
SQUARE = 100  # 그리는 동안만 쓰는 표시 (최종은 도심)
KINDS = ['village', 'park', 'forest', 'water', 'sea', 'mountain', 'city']

MID = math.radians((NORTH + SOUTH) / 2)
LAT_STEP = CELL_M / 111_320.0
LNG_STEP = CELL_M / (111_320.0 * math.cos(MID))
ROWS = math.ceil((NORTH - SOUTH) / LAT_STEP)
COLS = math.ceil((EAST - WEST) / LNG_STEP)

# 산: 봉우리 둘레 이 반경 안의 숲은 산으로 본다
PEAK_R_M = 900
PEAK_MIN_ELE = 150


def xy(lng, lat):
    return ((lng - WEST) / LNG_STEP, (NORTH - lat) / LAT_STEP)


# 묶음 14 A3: 1만㎡ 미만 공원·놀이터는 마을로 (칸 하나 = 100m × 100m = 1만㎡)
PARK_MIN_M2 = 10_000


def kind_of(tags):
    """면(area) 태그 → 종류 (None = 쓰지 않음)"""
    g = tags.get
    # 광장(포장된 광장·역전 광장)은 도심. 공원 태그가 함께 있어도 광장이 이긴다
    if g('place') == 'square' or (g('highway') == 'pedestrian' and g('area') == 'yes'):
        return SQUARE
    if g('natural') == 'water' or g('waterway') == 'riverbank' or \
            g('landuse') in ('reservoir', 'basin'):
        return WATER
    if g('leisure') in ('park', 'garden') or \
            g('landuse') in ('recreation_ground', 'village_green'):
        return PARK
    if g('landuse') == 'forest' or g('natural') in ('wood', 'scrub'):
        return FOREST
    if g('landuse') in ('commercial', 'retail', 'industrial'):
        return CITY
    return None


def draw_land(img, path):
    """육지 다각형을 마을(0)로 칠한다. 처음엔 모두 바다(4)."""
    import shapefile  # pyshp
    draw = ImageDraw.Draw(img)
    r = shapefile.Reader(path)
    n = 0
    for shp in r.iterShapes(bbox=[WEST, SOUTH, EAST, NORTH]):
        parts = list(shp.parts) + [len(shp.points)]
        for i in range(len(parts) - 1):
            pts = [xy(x, y) for x, y in shp.points[parts[i]:parts[i + 1]]]
            if len(pts) >= 3:
                # 첫 고리는 바깥, 나머지는 구멍 (구멍은 바다)
                draw.polygon(pts, fill=VILLAGE if i == 0 else SEA)
        n += 1
    print(f'육지 다각형 {n}개', flush=True)


def collect(pbf):
    import osmium

    class H(osmium.SimpleHandler):
        def __init__(self):
            super().__init__()
            # 종류마다 바로 칠한다 (전국 숲 다각형을 모두 들고 있으면 메모리가 모자라다)
            self.layers = {k: Image.new('L', (COLS, ROWS), 0)
                           for k in (WATER, PARK, FOREST, CITY, SQUARE)}
            self.small_parks = 0
            self.draws = {k: ImageDraw.Draw(v) for k, v in self.layers.items()}
            self.count = {k: 0 for k in self.layers}
            self.rivers = 0
            self.peaks = []

        def area(self, a):
            k = kind_of(a.tags)
            if k is None:
                return
            try:
                for outer in a.outer_rings():
                    ring = [xy(n.lon, n.lat) for n in outer]
                    if len(ring) >= 3:
                        if k == PARK and area_m2(ring) < PARK_MIN_M2:
                            self.small_parks += 1
                            continue
                        self.draws[k].polygon(ring, fill=1)
                        self.count[k] += 1
            except Exception:  # noqa: BLE001  깨진 다각형은 건너뛴다
                pass

        def way(self, w):
            if w.tags.get('waterway') == 'river':
                try:
                    line = [xy(n.lon, n.lat) for n in w.nodes]
                    if len(line) >= 2:
                        self.draws[WATER].line(line, fill=1, width=2)
                        self.rivers += 1
                except Exception:  # noqa: BLE001
                    pass

        def node(self, n):
            if n.tags.get('natural') == 'peak':
                try:
                    ele = float((n.tags.get('ele') or '0').replace('m', '').strip())
                except ValueError:
                    ele = 0
                if ele >= PEAK_MIN_ELE:
                    self.peaks.append(xy(n.location.lon, n.location.lat))

    h = H()
    h.apply_file(pbf, locations=True, idx='flex_mem')
    for k, v in h.count.items():
        print(f"{'square' if k == SQUARE else KINDS[k]} 면 {v}개", flush=True)
    print(f'강 줄기 {h.rivers}개, 봉우리 {len(h.peaks)}개, 작은 공원(마을로) {h.small_parks}개',
          flush=True)
    return h


def area_m2(ring):
    """격자 좌표(칸 = CELL_M) 다각형 넓이 (㎡)"""
    s = 0.0
    for i in range(len(ring)):
        x1, y1 = ring[i]
        x2, y2 = ring[(i + 1) % len(ring)]
        s += x1 * y2 - x2 * y1
    return abs(s) / 2 * CELL_M * CELL_M


def rle_tile(a):
    out = bytearray()
    flat = a.reshape(-1)
    i = 0
    n = len(flat)
    change = np.flatnonzero(np.diff(flat)) + 1
    starts = np.concatenate(([0], change))
    ends = np.concatenate((change, [n]))
    for s, e in zip(starts, ends):
        out.append(int(flat[s]))
        run = int(e - s)
        while True:
            b = run & 0x7F
            run >>= 7
            if run:
                out.append(b | 0x80)
            else:
                out.append(b)
                break
    return bytes(out)


def encode(grid):
    trows = math.ceil(ROWS / TILE)
    tcols = math.ceil(COLS / TILE)
    index = []
    data = bytearray()
    for tr in range(trows):
        for tc in range(tcols):
            t = np.full((TILE, TILE), SEA, dtype=np.uint8)
            part = grid[tr * TILE:(tr + 1) * TILE, tc * TILE:(tc + 1) * TILE]
            t[:part.shape[0], :part.shape[1]] = part
            index.append(len(data))
            data += rle_tile(t)
    head = json.dumps({
        'north': NORTH, 'west': WEST, 'latStep': LAT_STEP, 'lngStep': LNG_STEP,
        'rows': ROWS, 'cols': COLS, 'tile': TILE, 'kinds': KINDS,
        'source': '© OpenStreetMap contributors (ODbL)',
    }).encode()
    blob = b'PG1\0' + struct.pack('<I', len(head)) + head
    blob += struct.pack(f'<{len(index)}I', *index) + bytes(data)
    return blob


def main(pbf, land_shp, out_path):
    print(f'격자 {ROWS} × {COLS} (칸 {CELL_M:.0f}m)', flush=True)
    img = Image.new('L', (COLS, ROWS), SEA)
    draw_land(img, land_shp)
    h = collect(pbf)
    grid = np.array(img, dtype=np.uint8)
    land = grid != SEA
    # 겹치면 뒤의 것이 이긴다: 도심 → 숲 → 공원 → 물 (물은 바다 위에도: 강 하구·호수)
    for k in (CITY, FOREST, PARK):
        lay = np.array(h.layers[k], dtype=bool)
        grid[lay & land] = k
    grid[np.array(h.layers[WATER], dtype=bool)] = WATER
    # 광장은 공원 위에도 도심으로
    grid[np.array(h.layers[SQUARE], dtype=bool) & land] = CITY
    # 산: 봉우리 둘레의 숲
    mask = Image.new('1', (COLS, ROWS), 0)
    md = ImageDraw.Draw(mask)
    r = PEAK_R_M / CELL_M
    for x, y in h.peaks:
        md.ellipse([x - r, y - r, x + r, y + r], fill=1)
    m = np.array(mask, dtype=bool)
    grid[(grid == FOREST) & m] = MOUNTAIN
    counts = np.bincount(grid.reshape(-1), minlength=7)
    for k, c in enumerate(counts):
        print(f'  {KINDS[k]}: {c / grid.size * 100:.1f}%')
    blob = encode(grid)
    gz = gzip.compress(blob, compresslevel=9, mtime=0)
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, 'wb') as f:
        f.write(gz)
    print(f'원본 {len(blob) / 1e6:.1f}MB → gzip {len(gz) / 1e6:.2f}MB', flush=True)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
