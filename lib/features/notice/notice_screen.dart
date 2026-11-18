import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 묶음 59: 운영 공지 띠 (홈 위, 닫으면 그 공지는 다시 안 뜸)
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final n = controller.noticeBanner;
    if (n == null) return const SizedBox.shrink();
    return Material(
      key: const Key('noticeBanner'),
      color: const Color(0xEE1B1F45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => NoticeScreen.open(context, controller),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
          ),
          child: Row(children: [
            const Icon(Icons.campaign_rounded, color: AppColors.goldBright, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(keepAll('공지 · ${n.title}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.35)),
            ),
            IconButton(
              key: const Key('noticeBannerClose'),
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
              onPressed: () => controller.dismissNotice(n.id),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 공지 목록
class NoticeScreen extends StatelessWidget {
  const NoticeScreen({super.key, required this.controller});

  final AppController controller;

  static Future<void> open(BuildContext context, AppController c) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NoticeScreen(controller: c)));

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('noticeScreen'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => ListView(
            padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24),
            children: [
              OrnateTopBar(title: '공지', onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 8),
              if (c.notices.isEmpty)
                const KText('지금은 공지가 없어요.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
              for (final n in c.notices) ...[
                OrnatePanel(
                  key: Key('notice_${n.id}'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(n.title, style: AppText.title(16)),
                    Text('${n.from.year}.${n.from.month}.${n.from.day}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                    const SizedBox(height: 6),
                    KText(n.body, style: const TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.5)),
                  ]),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
