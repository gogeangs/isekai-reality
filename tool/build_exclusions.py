#!/usr/bin/env python3
"""OpenStreetMap 에서 전국 제외 구역(학교·유치원·병원·묘지)을 받아 원 목록으로 만든다.

몬스터·전투를 두지 않을 곳이다 (게임이 열리면 안 되는 장소 원칙).
결과: assets/data/exclusions.json
  {"source", "count", "kinds", "data": base64([int32 위도×1e5, int32 경도×1e5, uint16 반경m] × n, little-endian)}

GitHub Actions (exclusions.yml) 에서 돌린다. 지도 자료 © OpenStreetMap 기여자 (ODbL).
"""
import base64
import json
import math
import struct
import sys
import time
import urllib.parse
import urllib.request

# 대한민국 (제주·울릉도 포함). 위도 띠로 나눠 받는다
SOUTH, WEST, NORTH, EAST = 33.0, 124.5, 38.7, 131.0
BANDS = [(33.0, 35.0), (35.0, 36.0), (36.0, 37.0), (37.0, 37.5), (37.5, 38.7)]

# 종류별 여유(m)와 최소·최대 반경
BUFFER = 30
MIN_R = {'school': 80, 'kindergarten': 50, 'childcare': 40, 'hospital': 80,
         'grave_yard': 60, 'cemetery': 60}
MAX_R = 800  # 앱 색인 칸(0.01°)보다 작게

ENDPOINTS = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
]


def query(s, n):
    bb = f'{s},{WEST},{n},{EAST}'
    return f"""
[out:json][timeout:600];
(
  nwr["amenity"~"^(school|kindergarten|childcare|hospital|grave_yard)$"]({bb});
  nwr["landuse"="cemetery"]({bb});
);
out center bb qt;
"""


def fetch(q):
    data = urllib.parse.urlencode({'data': q}).encode()
    last = None
    for attempt in range(4):
        for url in ENDPOINTS:
            try:
                req = urllib.request.Request(
                    url, data=data,
                    headers={'User-Agent': 'isekai-reality-exclusions/1.0'})
                with urllib.request.urlopen(req, timeout=700) as r:
                    return json.load(r)
            except Exception as e:  # noqa: BLE001
                last = e
                print(f'  {url} 실패: {e}', file=sys.stderr)
        time.sleep(30)
    raise SystemExit(f'Overpass 실패: {last}')


def dist_m(lat1, lng1, lat2, lng2):
    dy = (lat2 - lat1) * 111320
    dx = (lng2 - lng1) * 111320 * math.cos(math.radians((lat1 + lat2) / 2))
    return math.hypot(dx, dy)


def main(out_path):
    zones = {}
    kinds = {}
    for s, n in BANDS:
        print(f'{s}~{n} 받는 중…')
        for e in fetch(query(s, n)).get('elements', []):
            tags = e.get('tags', {})
            kind = tags.get('amenity') or ('cemetery' if tags.get('landuse') == 'cemetery' else None)
            if kind not in MIN_R:
                continue
            if e['type'] == 'node':
                lat, lng = e['lat'], e['lon']
                r = MIN_R[kind]
            else:
                c = e.get('center')
                b = e.get('bounds')
                if not c or not b:
                    continue
                lat, lng = c['lat'], c['lon']
                half = dist_m(b['minlat'], b['minlon'], b['maxlat'], b['maxlon']) / 2
                r = max(MIN_R[kind], half + BUFFER)
            if not (SOUTH <= lat <= NORTH and WEST <= lng <= EAST):
                continue
            r = min(MAX_R, int(r))
            key = (e['type'], e['id'])
            zones[key] = (round(lat * 1e5), round(lng * 1e5), r)
            kinds[kind] = kinds.get(kind, 0) + 1
        time.sleep(10)

    print(f'제외 구역 {len(zones)}곳 {kinds}')
    if len(zones) < 5000:
        raise SystemExit('너무 적어요. 자료를 확인해 주세요.')
    buf = b''.join(struct.pack('<iiH', *z) for z in zones.values())
    out = {
        'source': 'OpenStreetMap contributors (ODbL)',
        'count': len(zones),
        'kinds': kinds,
        'data': base64.b64encode(buf).decode(),
    }
    with open(out_path, 'w') as f:
        json.dump(out, f, separators=(',', ':'))
    print(f'저장: {out_path} ({len(buf) // 1024}KB)')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'assets/data/exclusions.json')
