#!/usr/bin/env python3
"""OpenStreetMap 에서 안산의 큰길·철로를 받아 20m 격자로 만든다.

필드 몬스터가 차도·철로 위에 나오지 않게 할 때 쓴다.
결과: assets/data/road_mask.json
  {south, west, latStep, lngStep, rows, cols, bits(base64, 1칸=1비트, 행 우선)}

GitHub Actions (road-mask.yml) 에서 돌린다. 지도 자료 © OpenStreetMap 기여자 (ODbL).
"""
import base64
import json
import math
import sys
import time
import urllib.parse
import urllib.request

SOUTH, WEST, NORTH, EAST = 37.262, 126.735, 37.372, 126.920
CELL_M = 20.0

# 길 종류별 둘레 반경 (m) — 길 폭의 절반 + 여유
BUFFER = {
    'motorway': 30, 'motorway_link': 20,
    'trunk': 30, 'trunk_link': 20,
    'primary': 25, 'primary_link': 15,
    'secondary': 20, 'secondary_link': 12,
    'tertiary': 15, 'tertiary_link': 10,
    'rail': 20, 'subway': 20, 'light_rail': 15,
}

QUERY = f"""
[out:json][timeout:180];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary)(_link)?$"]["tunnel"!~"yes"]({SOUTH},{WEST},{NORTH},{EAST});
  way["railway"~"^(rail|subway|light_rail)$"]["tunnel"!~"yes"]({SOUTH},{WEST},{NORTH},{EAST});
);
out geom;
"""

ENDPOINTS = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
]


def fetch():
    data = urllib.parse.urlencode({'data': QUERY}).encode()
    last = None
    for attempt in range(3):
        for url in ENDPOINTS:
            try:
                req = urllib.request.Request(
                    url, data=data,
                    headers={'User-Agent': 'isekai-reality-road-mask/1.0'})
                with urllib.request.urlopen(req, timeout=240) as r:
                    return json.load(r)
            except Exception as e:  # noqa: BLE001
                last = e
                print(f'  {url} 실패: {e}', file=sys.stderr)
        time.sleep(20)
    raise SystemExit(f'Overpass 실패: {last}')


def main(out_path):
    mid = math.radians((SOUTH + NORTH) / 2)
    m_lat = 111_320.0
    m_lng = 111_320.0 * math.cos(mid)
    lat_step = CELL_M / m_lat
    lng_step = CELL_M / m_lng
    rows = math.ceil((NORTH - SOUTH) / lat_step)
    cols = math.ceil((EAST - WEST) / lng_step)
    grid = bytearray((rows * cols + 7) // 8)

    def mark(r, c):
        if 0 <= r < rows and 0 <= c < cols:
            i = r * cols + c
            grid[i >> 3] |= 1 << (i & 7)

    def to_xy(lat, lng):  # 미터 좌표
        return (lng - WEST) * m_lng, (lat - SOUTH) * m_lat

    def seg(ax, ay, bx, by, buf):
        # 선분 둘레 buf 안에 중심이 드는 칸을 칠한다
        minx, maxx = min(ax, bx) - buf, max(ax, bx) + buf
        miny, maxy = min(ay, by) - buf, max(ay, by) + buf
        c0, c1 = int(minx // CELL_M), int(maxx // CELL_M)
        r0, r1 = int(miny // CELL_M), int(maxy // CELL_M)
        dx, dy = bx - ax, by - ay
        ll = dx * dx + dy * dy
        b2 = buf * buf
        for r in range(max(r0, 0), min(r1, rows - 1) + 1):
            cy = (r + 0.5) * CELL_M
            for c in range(max(c0, 0), min(c1, cols - 1) + 1):
                cx = (c + 0.5) * CELL_M
                t = 0.0 if ll == 0 else max(0.0, min(1.0, ((cx - ax) * dx + (cy - ay) * dy) / ll))
                px, py = ax + t * dx - cx, ay + t * dy - cy
                if px * px + py * py <= b2:
                    mark(r, c)

    print('Overpass 에서 길을 받는 중…')
    data = fetch()
    ways = [e for e in data.get('elements', []) if e.get('type') == 'way']
    kinds = {}
    for w in ways:
        tags = w.get('tags', {})
        kind = tags.get('highway') or tags.get('railway')
        buf = BUFFER.get(kind)
        if buf is None or 'geometry' not in w:
            continue
        kinds[kind] = kinds.get(kind, 0) + 1
        pts = [to_xy(g['lat'], g['lon']) for g in w['geometry']]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            seg(ax, ay, bx, by, buf)

    filled = sum(bin(b).count('1') for b in grid)
    print(f'길 {len(ways)}개 {kinds}')
    print(f'격자 {rows}x{cols}, 길 칸 {filled} ({filled / (rows * cols):.1%})')
    if len(ways) < 50:
        raise SystemExit('길이 너무 적어요. 자료를 확인해 주세요.')

    out = {
        'source': 'OpenStreetMap contributors (ODbL)',
        'cellM': CELL_M,
        'south': SOUTH, 'west': WEST,
        'latStep': lat_step, 'lngStep': lng_step,
        'rows': rows, 'cols': cols,
        'bits': base64.b64encode(bytes(grid)).decode(),
    }
    with open(out_path, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    print(f'저장: {out_path}')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'assets/data/road_mask.json')
