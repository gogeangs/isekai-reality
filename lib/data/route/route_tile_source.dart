import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../core/geo/route_grid.dart';

/// 길 조각을 받아 온다 (11-11 #42). 받지 못하면 null → 원정은 직선으로.
abstract class RouteTileSource {
  Future<Uint8List?> load(String key);
}

/// 받을 조각이 없다 (테스트·데모)
class NoRouteTiles implements RouteTileSource {
  const NoRouteTiles();
  @override
  Future<Uint8List?> load(String key) async => null;
}

/// 테스트용: 미리 넣어 둔 조각
class MemoryRouteTiles implements RouteTileSource {
  MemoryRouteTiles(this.tiles);
  final Map<String, Uint8List> tiles;
  @override
  Future<Uint8List?> load(String key) async => tiles[key];
}

/// GitHub(공개 저장소)의 route-tiles 가지에서 받는다. 앱을 켜 둔 동안 기억한다.
class GithubRouteTiles implements RouteTileSource {
  GithubRouteTiles({
    this.base =
        'https://raw.githubusercontent.com/gogeangs/isekai-reality/route-tiles/t',
  });

  final String base;
  final _cache = <String, Uint8List?>{};
  final _pending = <String, Future<Uint8List?>>{};

  @override
  Future<Uint8List?> load(String key) {
    if (_cache.containsKey(key)) return Future.value(_cache[key]);
    return _pending[key] ??= _fetch(key).then((v) {
      _pending.remove(key);
      // 받지 못한 것(인터넷 없음)은 기억하지 않고 다음에 다시 받는다. 없는 조각(404)만 기억.
      if (v != null || _missing.contains(key)) _cache[key] = v;
      return v;
    });
  }

  final _missing = <String>{};

  Future<Uint8List?> _fetch(String key) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(Uri.parse('$base/$key.bin'));
      final res = await req.close().timeout(const Duration(seconds: 12));
      if (res.statusCode == 404) {
        _missing.add(key);
        await res.drain<void>();
        return null;
      }
      if (res.statusCode != 200) {
        await res.drain<void>();
        return null;
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in res.timeout(const Duration(seconds: 15))) {
        bytes.add(chunk);
      }
      final raw = Uint8List.fromList(zlib.decode(bytes.takeBytes()));
      return raw.length == RouteTiles.cells * RouteTiles.cells ? raw : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }
}
