import 'dart:convert';
import 'dart:typed_data';

import '../geo/geo.dart';

/// 장소 종류 (묶음 13 C7): OpenStreetMap 으로 미리 만든 100m 격자
enum LandKind { village, park, forest, water, sea, mountain, city }

/// 장소 종류 격자 (assets/data/place_grid.bin 을 풀어 둔 것).
/// 휴대폰 안에서만 찾는다 (서버 없음). 만든 방법: tool/build_place_grid.py
class PlaceGrid {
  PlaceGrid._(this._bytes, this._dataStart, this.north, this.west, this.latStep,
      this.lngStep, this.rows, this.cols, this.tile);

  final Uint8List _bytes;
  final int _dataStart;
  final double north, west, latStep, lngStep;
  final int rows, cols, tile;
  late final int _tileCols = (cols + tile - 1) ~/ tile;
  late final int _tileRows = (rows + tile - 1) ~/ tile;

  /// 풀어 둔 타일 (최근 것 몇 개만)
  final Map<int, Uint8List> _cache = {};

  /// gzip 을 푼 바이트로 만든다. 모양이 틀리면 null.
  static PlaceGrid? tryParse(Uint8List b) {
    try {
      if (b.length < 8 || b[0] != 0x50 || b[1] != 0x47 || b[2] != 0x31) {
        return null;
      }
      final bd = ByteData.sublistView(b);
      final headLen = bd.getUint32(4, Endian.little);
      final head =
          jsonDecode(utf8.decode(b.sublist(8, 8 + headLen))) as Map<String, dynamic>;
      final rows = (head['rows'] as num).toInt();
      final cols = (head['cols'] as num).toInt();
      final tile = (head['tile'] as num).toInt();
      final tiles = ((rows + tile - 1) ~/ tile) * ((cols + tile - 1) ~/ tile);
      final indexStart = 8 + headLen;
      return PlaceGrid._(
        b,
        indexStart + tiles * 4,
        (head['north'] as num).toDouble(),
        (head['west'] as num).toDouble(),
        (head['latStep'] as num).toDouble(),
        (head['lngStep'] as num).toDouble(),
        rows,
        cols,
        tile,
      );
    } catch (_) {
      return null;
    }
  }

  int _offset(int t) => ByteData.sublistView(_bytes)
      .getUint32(_dataStart - _tileRows * _tileCols * 4 + t * 4, Endian.little);

  Uint8List _tileAt(int t) {
    final hit = _cache.remove(t);
    if (hit != null) {
      _cache[t] = hit;
      return hit;
    }
    final out = Uint8List(tile * tile);
    var p = _dataStart + _offset(t);
    var i = 0;
    while (i < out.length && p < _bytes.length) {
      final v = _bytes[p++];
      var run = 0, shift = 0;
      while (true) {
        final b = _bytes[p++];
        run |= (b & 0x7F) << shift;
        if (b < 0x80) break;
        shift += 7;
      }
      final end = i + run > out.length ? out.length : i + run;
      out.fillRange(i, end, v);
      i = end;
    }
    _cache[t] = out;
    if (_cache.length > 24) _cache.remove(_cache.keys.first);
    return out;
  }

  /// 그 자리의 장소 종류 (격자 밖이면 null)
  LandKind? kindAt(GeoPoint p) {
    final r = ((north - p.lat) / latStep).floor();
    final c = ((p.lng - west) / lngStep).floor();
    if (r < 0 || c < 0 || r >= rows || c >= cols) return null;
    final t = (r ~/ tile) * _tileCols + (c ~/ tile);
    final v = _tileAt(t)[(r % tile) * tile + (c % tile)];
    return v < LandKind.values.length ? LandKind.values[v] : null;
  }
}
