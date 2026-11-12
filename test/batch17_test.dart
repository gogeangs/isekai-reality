import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('#145 그림 줄이기', () {
    test('앱에 들어가는 그림은 WebP (원본 부위 시트만 예외)', () {
      final left = [
        for (final f in Directory('assets/images').listSync(recursive: true))
          if (f is File &&
              RegExp(r'\.(png|jpe?g)$').hasMatch(f.path) &&
              !f.path.contains('_parts_'))
            f.path,
      ];
      expect(left, isEmpty);
    });

    test('코드에 적힌 그림 경로는 모두 있다', () {
      final pat = RegExp(r"'(assets/images/[A-Za-z0-9_/]+\.(?:webp|png|jpg))'");
      final missing = <String>{};
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final m in pat.allMatches(f.readAsStringSync())) {
          if (!File(m.group(1)!).existsSync()) missing.add(m.group(1)!);
        }
      }
      expect(missing, isEmpty);
    });
  });
}
