#!/usr/bin/env python3
"""전국 길 조각 만들기 (11-11 #42, 원정 길찾기).

Geofabrik 의 대한민국 OpenStreetMap 자료(south-korea-latest.osm.pbf)를 읽어
약 5km × 5km 조각으로 나눈다. 조각 하나는 10m 칸 500 × 500, 칸마다 1바이트:
  1 = 걸을 수 있는 길 (인도·골목·공원 길·보통 차도. 고속도로·자동차 전용도로는 빼고)
  2 = 큰 차도 (고속도로·자동차 전용·간선·보조 간선, 나중에 몬스터 차단용)
  4 = 철로 (지하 구간 빼고)
조각 이름: t/<행>_<열>.bin (zlib). 행 = floor((위도 - 33) / 0.045), 열 = floor((경도 - 124) / 0.05625).
앱 lib/core/geo/route_grid.dart 의 RouteTiles 와 같은 값이어야 한다.

GitHub Actions (route-tiles.yml) 에서 돌린다. 지도 자료 © OpenStreetMap 기여자 (ODbL).
쓰는 법: python3 build_route_tiles.py <pbf> <출력 폴더>
"""
import os
import sys
import zlib

import numpy as np
import osmium

ORIGIN_LAT, ORIGIN_LNG = 33.0, 124.0
TILE_LAT, TILE_LNG = 0.045, 0.05625
CELLS = 500
CELL_LAT, CELL_LNG = TILE_LAT / CELLS, TILE_LNG / CELLS
MAX_LAT, MAX_LNG = 39.0, 132.0
NROWS = int(round((MAX_LAT - ORIGIN_LAT) / CELL_LAT)) + 1
NCOLS = int(round((MAX_LNG - ORIGIN_LNG) / CELL_LNG)) + 1

WALK = 1
BIG = 2
RAIL = 4

# 걸을 수 없는 길
NO_WALK = {'motorway', 'motorway_link', 'trunk', 'trunk_link', 'construction',
           'proposed', 'raceway', 'bus_guideway', 'abandoned', 'platform',
           'corridor', 'elevator', 'escape', 'busway', 'via_ferrata'}
BIG_ROADS = {'motorway', 'motorway_link', 'trunk', 'trunk_link',
             'primary', 'primary_link', 'secondary', 'secondary_link'}
RAILS = {'rail', 'subway', 'light_rail', 'narrow_gauge', 'monorail'}


class Collector(osmium.SimpleHandler):
    def __init__(self):
        super().__init__()
        self.keys = []
        self.flags = []
        self.pending = 0
        self.ways = 0

    def way(self, w):
        t = w.tags
        hw = t.get('highway')
        rw = t.get('railway')
        flag = 0
        if hw:
            foot = t.get('foot')
            access = t.get('access')
            walk = hw not in NO_WALK
            if access in ('private', 'no') or foot in ('no', 'private'):
                walk = False
            if foot in ('yes', 'designated', 'permissive'):
                walk = True
            if walk and t.get('area') != 'yes':
                flag |= WALK
            if hw in BIG_ROADS and t.get('tunnel') not in ('yes', 'building_passage'):
                flag |= BIG
        if rw in RAILS and t.get('tunnel') != 'yes':
            flag |= RAIL
        if not flag:
            return
        try:
            pts = np.array([(n.lat, n.lon) for n in w.nodes], dtype=np.float64)
        except osmium.InvalidLocationError:
            return
        if len(pts) < 2:
            return
        r = (pts[:, 0] - ORIGIN_LAT) / CELL_LAT
        c = (pts[:, 1] - ORIGIN_LNG) / CELL_LNG
        dr = np.diff(r)
        dc = np.diff(c)
        n = (np.ceil(np.maximum(np.abs(dr), np.abs(dc)) * 2.5)).astype(np.int64) + 1
        seg = np.repeat(np.arange(len(dr)), n)
        start = np.repeat(np.cumsum(n) - n, n)
        tt = (np.arange(n.sum()) - start) / np.repeat(n, n)
        rr = np.concatenate([r[seg] + dr[seg] * tt, r[-1:]])
        cc = np.concatenate([c[seg] + dc[seg] * tt, c[-1:]])
        ri = np.floor(rr).astype(np.int64)
        ci = np.floor(cc).astype(np.int64)
        ok = (ri >= 0) & (ri < NROWS) & (ci >= 0) & (ci < NCOLS)
        if not ok.any():
            return
        k = np.unique(ri[ok] * NCOLS + ci[ok])
        self.keys.append(k)
        self.flags.append(np.full(len(k), flag, dtype=np.uint8))
        self.pending += len(k)
        self.ways += 1
        if self.pending > 20_000_000:
            self.compact()

    def compact(self):
        if len(self.keys) <= 1:
            return
        k = np.concatenate(self.keys)
        f = np.concatenate(self.flags)
        order = np.argsort(k, kind='stable')
        k = k[order]
        f = f[order]
        uniq, idx = np.unique(k, return_index=True)
        f = np.bitwise_or.reduceat(f, idx)
        self.keys = [uniq]
        self.flags = [f]
        self.pending = 0
        print(f'  길 {self.ways:,}개, 칸 {len(uniq):,}개', flush=True)


def main(pbf, out_dir):
    h = Collector()
    h.apply_file(pbf, locations=True, idx='flex_mem')
    h.compact()
    keys, flags = h.keys[0], h.flags[0]
    rows = keys // NCOLS
    cols = keys % NCOLS
    tile = (rows // CELLS) * 10_000 + (cols // CELLS)
    order = np.argsort(tile, kind='stable')
    tile, rows, cols, flags = tile[order], rows[order], cols[order], flags[order]
    bounds = np.flatnonzero(np.diff(tile)) + 1
    starts = np.concatenate([[0], bounds])
    ends = np.concatenate([bounds, [len(tile)]])
    os.makedirs(os.path.join(out_dir, 't'), exist_ok=True)
    total = 0
    for s, e in zip(starts, ends):
        tid = int(tile[s])
        tr, tc = tid // 10_000, tid % 10_000
        grid = np.zeros(CELLS * CELLS, dtype=np.uint8)
        grid[(rows[s:e] % CELLS) * CELLS + (cols[s:e] % CELLS)] = flags[s:e]
        data = zlib.compress(grid.tobytes(), 9)
        with open(os.path.join(out_dir, 't', f'{tr}_{tc}.bin'), 'wb') as fp:
            fp.write(data)
        total += len(data)
    print(f'조각 {len(starts):,}개, 합계 {total / 1e6:.1f}MB')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
