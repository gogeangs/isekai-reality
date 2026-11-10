import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 감정 사진을 앨범에 저장하고 공유한다. 게임 안에는 사진을 남기지 않는다.
/// (공유할 때 잠깐 만든 파일은 화면을 닫을 때 지운다)
class LensOutput {
  LensOutput._();

  /// 테스트에서 바꿔 끼운다
  static Future<String?> Function(Uint8List png) saver = _save;
  static Future<void> Function(Uint8List png, String text, Rect? origin)
      sharer = _share;

  static final List<String> _temp = [];

  /// 앨범에 저장 (실패하면 이유)
  static Future<String?> _save(Uint8List png) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        return '사진 저장 권한이 꺼져 있어요. 휴대폰 설정에서 허용해 주세요.';
      }
      await Gal.putImageBytes(png,
          name: 'arca_${DateTime.now().millisecondsSinceEpoch}');
      return null;
    } on GalException catch (e) {
      return e.type == GalExceptionType.accessDenied
          ? '사진 저장 권한이 꺼져 있어요. 휴대폰 설정에서 허용해 주세요.'
          : '저장하지 못했어요.';
    } catch (_) {
      return '저장하지 못했어요.';
    }
  }

  static Future<void> _share(Uint8List png, String text, Rect? origin) async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/arca_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(png, flush: true);
    _temp.add(path);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path, mimeType: 'image/png')],
      text: text,
      sharePositionOrigin: origin,
    ));
  }

  /// 공유하려고 만든 임시 파일을 지운다
  static Future<void> cleanUp() async {
    for (final p in [..._temp]) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    _temp.clear();
  }
}
