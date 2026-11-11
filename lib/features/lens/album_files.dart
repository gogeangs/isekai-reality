import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 감정 앨범 사진 파일 (11-11 #97): 휴대폰 안 앱 폴더에만 둔다 (서버 없음).
/// 앱을 지우면 함께 사라질 수 있다.
class AlbumFiles {
  AlbumFiles._();

  /// 테스트에서 바꿔 끼운다
  static Future<String?> Function(String id, Uint8List png) writer = _write;
  static Future<Uint8List?> Function(String file) reader = _read;
  static Future<void> Function(String file) deleter = _delete;

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/album');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// 저장하고 파일 이름을 돌려준다 (실패하면 null)
  static Future<String?> _write(String id, Uint8List png) async {
    try {
      final d = await _dir();
      final name = '$id.png';
      await File('${d.path}/$name').writeAsBytes(png, flush: true);
      return name;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _read(String file) async {
    try {
      final d = await _dir();
      final f = File('${d.path}/$file');
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// 모든 기록 지우기: 앨범 폴더째 지운다
  static Future<void> deleteAll() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      final d = Directory('${base.path}/album');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
  }

  static Future<void> _delete(String file) async {
    try {
      final d = await _dir();
      final f = File('${d.path}/$file');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
