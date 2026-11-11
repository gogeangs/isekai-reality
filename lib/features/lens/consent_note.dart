import 'package:flutter/material.dart';

import '../../theme/ornaments.dart';

/// 다른 사람 얼굴 동의 안내 (묶음 13 B5)
const String othersConsentLine = '다른 사람을 비출 때는 먼저 물어봐 주세요';

/// 사진을 저장·공유하기 직전에 한 번 같은 안내. 계속하면 true.
Future<bool> confirmOthersConsent(BuildContext context, {required bool share}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => GameAlert(
      key: const Key('consentAlert'),
      title: Text(share ? '공유하기 전에' : '저장하기 전에'),
      content: const KText('$othersConsentLine. 함께 찍힌 사람이 있다면 '
          '저장하거나 보내도 되는지 확인해 주세요.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('그만둘래요')),
        TextButton(
            key: const Key('consentOk'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(share ? '공유하기' : '저장하기')),
      ],
    ),
  );
  return ok == true;
}
