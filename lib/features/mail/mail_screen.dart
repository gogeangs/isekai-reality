import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/mail_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';

/// 우편함 (11-11 #65, #100): 선물과 편지를 한 목록으로. 물건이 든 편지는 30일 안에 받기,
/// 받은 뒤 편지는 계속 보관. 필터: 전체 / 공지 (묶음 15 #117: 물건 든 편지는 선물 상자 표시로)
class MailScreen extends StatefulWidget {
  const MailScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  /// 0 전체 · 1 공지
  int _tab = 0;

  AppController get c => widget.controller;

  void _snack(String s) => showTopNotice(context, s);

  Future<void> _open(MailItem m) async {
    await c.readMail(m.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.night,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (sheet, _) {
            final now = c.now;
            final cur = c.mail.mails.firstWhere((x) => x.id == m.id, orElse: () => m);
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              children: [
                Text(cur.title, style: AppText.title(19)),
                const SizedBox(height: 2),
                Text('${cur.from} · ${cur.sentAt.month}월 ${cur.sentAt.day}일',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                if (cur.kind == MailKind.letter &&
                    cur.id.startsWith('spirit_')) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset('assets/images/letter_spirit.webp',
                        height: 110,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ],
                const SizedBox(height: 10),
                if (cur.body.isNotEmpty)
                  KText(cur.body,
                      style: const TextStyle(color: AppColors.text, height: 1.5)),
                if (cur.gifts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  OrnatePanel(
                    child: KText(
                        '${cur.claimed ? '받은 선물' : '선물'}: ${giftLabel(c, cur.gifts)}'
                        '${cur.expiresAt != null && !cur.claimed ? '\n${MailRules.daysLeft(cur.expiresAt!, now)}일 뒤 사라져요' : ''}',
                        style: const TextStyle(color: AppColors.goldBright, fontSize: 14)),
                  ),
                ],
                const SizedBox(height: 12),
                if (cur.hasGifts)
                  GoldButton(
                    key: const Key('mailClaim'),
                    label: '받기',
                    onPressed: () async {
                      final got = await c.claimMail(cur.id);
                      if (!sheet.mounted) return;
                      Navigator.of(sheet).pop();
                      if (got != null) _snack('받았어요! $got');
                    },
                  )
                else
                  FrameButton(label: '닫기', onPressed: () => Navigator.of(sheet).pop()),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final gifts = c.giftMails;
            final all = c.allMails;
            final list = switch (_tab) {
              1 => [for (final m in all) if (m.kind == MailKind.notice) m],
              _ => all,
            };
            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(title: '우편함', onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 10),
                Wrap(spacing: 6, children: [
                  for (final (i, label) in [
                    (0, '전체'),
                    (1, '공지'),
                  ])
                    ChoiceChip(
                      key: Key('mailFilter_$i'),
                      label: Text(label),
                      selected: _tab == i,
                      onSelected: (_) => setState(() => _tab = i),
                      selectedColor: AppColors.gold,
                      backgroundColor: AppColors.chipBg,
                      labelStyle: TextStyle(
                          color: _tab == i ? AppColors.night : AppColors.text,
                          fontWeight: FontWeight.w700),
                      showCheckmark: false,
                    ),
                ]),
                const SizedBox(height: 10),
                if (gifts.isNotEmpty) ...[
                  GoldButton(
                    key: const Key('mailClaimAll'),
                    label: '모두 받기',
                    height: 48,
                    onPressed: () async {
                      final n = await c.claimAllMail();
                      if (mounted) _snack('우편 $n통의 선물을 받았어요!');
                    },
                  ),
                  const SizedBox(height: 4),
                  const Text('가방이 가득하면 넘치는 물건은 금화로 바꿔 받아요. 금화·마석은 언제나 받아요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                ],
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: KText(
                        switch (_tab) {
                          1 => '공지가 없어요.',
                          _ => '아직 편지가 없어요.',
                        },
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
                // 큰 금테 판 하나 안에 한 줄씩 (11-11 #88)
                if (list.isNotEmpty)
                  OrnatePanel(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Column(children: [
                      for (var i = 0; i < list.length; i++) ...[
                        if (i > 0)
                          Divider(
                              height: 1,
                              thickness: 0.6,
                              color: AppColors.gold.withValues(alpha: 0.25)),
                        _MailRow(
                            key: Key('mailRow_${list[i].id}'),
                            controller: c,
                            mail: list[i],
                            onTap: () => _open(list[i])),
                      ],
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MailRow extends StatelessWidget {
  const _MailRow(
      {super.key, required this.controller, required this.mail, required this.onTap});

  final AppController controller;
  final MailItem mail;
  final VoidCallback onTap;

  /// 받은 때 (오늘·어제·3일 전·11월 2일)
  static String when(DateTime sent, DateTime now) {
    final a = DateTime(sent.year, sent.month, sent.day);
    final b = DateTime(now.year, now.month, now.day);
    final d = b.difference(a).inDays;
    if (d <= 0) return '오늘';
    if (d == 1) return '어제';
    if (d < 7) return '$d일 전';
    return '${sent.month}월 ${sent.day}일';
  }

  @override
  Widget build(BuildContext context) {
    final m = mail;
    final unread = !m.read;
    // 11-11 #100: 모두 편지. 공지만 확성기, 물건이 들어 있으면 작은 선물 상자
    final icon = m.kind == MailKind.notice
        ? Icons.campaign_rounded
        : unread
            ? Icons.mail_rounded
            : Icons.drafts_rounded;
    final sub = [
      m.from,
      if (m.hasGifts) giftLabel(controller, m.gifts),
      if (m.expiresAt != null && m.hasGifts)
        '${MailRules.daysLeft(m.expiresAt!, controller.now)}일 남음',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(
            width: 30,
            child: Stack(clipBehavior: Clip.none, children: [
              Icon(icon,
                  color: unread ? AppColors.goldBright : AppColors.textMuted,
                  size: 24),
              if (unread) const Positioned(right: 0, top: -2, child: _RedDot()),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: unread ? AppColors.text : AppColors.textMuted,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
          if (m.hasGifts) ...[
            const SizedBox(width: 4),
            const Icon(Icons.card_giftcard_rounded,
                key: Key('mailGiftMark'), color: AppColors.goldBright, size: 18),
          ],
          const SizedBox(width: 6),
          Text(when(m.sentAt, controller.now),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Icon(Icons.chevron_right_rounded, color: AppColors.gold, size: 20),
        ]),
      ),
    );
  }
}

class _RedDot extends StatelessWidget {
  const _RedDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.alert,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.night, width: 1.5),
        ),
      );
}

/// 선물 글 ('금화 100, 약초 3')
String giftLabel(AppController c, Map<String, int> gifts) => [
      for (final e in gifts.entries)
        switch (e.key) {
          Wallet.gold => '금화 ${e.value}',
          Wallet.manaStone => '마석 ${e.value}',
          Wallet.exp => '경험치 ${e.value}',
          'note' => '레시피 쪽지 ${e.value}',
          'tools' => '채집 도구 한 벌',
          'egg' => '알 ${e.value}',
          final k when k.startsWith('item:') => () {
              for (final it in ShopItem.values) {
                if (it.name == k.substring(5)) return '${c.itemName(it)} ${e.value}';
              }
              return k;
            }(),
          final k => '${Materials.byName(k) == null ? k : Materials.info(Materials.byName(k)!).name} ${e.value}',
        },
    ].join(', ');

/// 위쪽 우편 버튼 (새 우편이 있으면 빨간 점)
class MailButton extends StatelessWidget {
  const MailButton({super.key, required this.hasNew, required this.onTap});

  final bool hasNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('mailButton'),
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xCC14163A),
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Image.asset('assets/images/icon_mail.webp',
                width: 26,
                height: 26,
                errorBuilder: (_, __, ___) => const Icon(Icons.mail_rounded,
                    color: AppColors.goldBright, size: 22)),
          ),
          if (hasNew) const Positioned(right: 0, top: 0, child: _RedDot()),
        ]),
      );
}
