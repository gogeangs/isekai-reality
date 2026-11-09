import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

enum LegalDoc {
  privacy('개인정보처리방침', 'assets/legal/privacy.txt'),
  locationTerms('위치기반서비스 이용약관', 'assets/legal/location_terms.txt');

  const LegalDoc(this.title, this.asset);
  final String title;
  final String asset;
}

/// 약관 보기. 앱에 함께 넣은 글(assets/legal)을 그대로 보여 준다.
/// '# ' 줄은 빼고, '## ' 줄은 조 제목으로 굵게 표시한다.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  static Future<void> open(BuildContext context, LegalDoc doc) =>
      Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => LegalScreen(doc: doc)));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        child: FutureBuilder<String>(
          future: rootBundle.loadString(doc.asset),
          builder: (context, snap) {
            final lines = (snap.data ?? '').split('\n');
            return ListView(
              padding: EdgeInsets.fromLTRB(16, top + 6, 16, 32),
              children: [
                OrnateTopBar(
                  title: doc.title,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: 8),
                for (final line in lines)
                  if (line.startsWith('# '))
                    const SizedBox.shrink()
                  else if (line.startsWith('## '))
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 4),
                      child: Text(line.substring(3),
                          style: AppText.title(16, color: AppColors.goldBright)),
                    )
                  else if (line.trim().isEmpty)
                    const SizedBox(height: 6)
                  else
                    Text(line,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14, height: 1.5)),
              ],
            );
          },
        ),
      ),
    );
  }
}
