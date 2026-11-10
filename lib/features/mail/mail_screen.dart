import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/mail_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';

/// 우편함 (11-11 #65): 「선물」 탭(받을 것, 보상 우편은 30일) · 「편지」 탭(계속 보관)
class MailScreen extends StatefulWidget {
  const MailScreen({super.key, required this.controller, this.initialTab = 0});

  final AppController controller;
  final int initialTab;

  @override
  State<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends State<MailScreen> {
  late int _tab = widget.initialTab;

  AppController get c => widget.controller;

  void _snack(String s) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(s)));

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
                Text(cur.title, style: AppText.title(20)),
                const SizedBox(height: 2),
                Text('${cur.from} · ${cur.sentAt.month}월 ${cur.sentAt.day}일',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                if (cur.kind == MailKind.letter &&
                    cur.id.startsWith('spirit_')) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset('assets/images/letter_spirit.png',
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
                        style: const TextStyle(color: AppColors.goldBright, fontSize: 13)),
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
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final gifts = c.giftMails;
            final letters = c.letterMails;
            final list = _tab == 0 ? gifts : letters;
            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(title: '우편함', onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 10),
                Row(children: [
                  for (final (i, label) in [(0, '선물 ${gifts.length}'), (1, '편지 ${letters.length}')]) ...[
                    Expanded(
                      child: ChoiceChip(
                        label: SizedBox(
                            width: double.infinity,
                            child: Text(label, textAlign: TextAlign.center)),
                        selected: _tab == i,
                        onSelected: (_) => setState(() => _tab = i),
                        selectedColor: AppColors.gold,
                        backgroundColor: const Color(0xFF1E2250),
                        labelStyle: TextStyle(
                            color: _tab == i ? AppColors.night : AppColors.text,
                            fontWeight: FontWeight.w700),
                        showCheckmark: false,
                      ),
                    ),
                    if (i == 0) const SizedBox(width: 8),
                  ],
                ]),
                const SizedBox(height: 10),
                if (_tab == 0 && gifts.isNotEmpty) ...[
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
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  const SizedBox(height: 8),
                ],
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: KText(_tab == 0 ? '받을 선물이 없어요.' : '아직 편지가 없어요.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMuted)),
                  ),
                for (final m in list) ...[
                  _MailRow(controller: c, mail: m, onTap: () => _open(m)),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MailRow extends StatelessWidget {
  const _MailRow({required this.controller, required this.mail, required this.onTap});

  final AppController controller;
  final MailItem mail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = mail;
    final icon = switch (m.kind) {
      MailKind.reward => Icons.card_giftcard_rounded,
      MailKind.letter => Icons.mail_rounded,
      MailKind.notice => Icons.campaign_rounded,
    };
    return GestureDetector(
      onTap: onTap,
      child: OrnatePanel(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Stack(clipBehavior: Clip.none, children: [
            Icon(icon, color: AppColors.goldBright, size: 30),
            if (!m.read || m.hasGifts)
              const Positioned(
                  right: -2, top: -2, child: _RedDot()),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(15.5, color: AppColors.text)),
              Text(
                  [
                    m.from,
                    if (m.hasGifts) giftLabel(controller, m.gifts),
                    if (m.expiresAt != null && m.hasGifts)
                      '${MailRules.daysLeft(m.expiresAt!, controller.now)}일 남음',
                  ].join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
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
          color: const Color(0xFFE5484D),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xCC14163A),
              border: Border.all(color: AppColors.gold, width: 1.5),
            ),
            child: Image.asset('assets/images/icon_mail.png',
                width: 26,
                height: 26,
                errorBuilder: (_, __, ___) => const Icon(Icons.mail_rounded,
                    color: AppColors.goldBright, size: 22)),
          ),
          if (hasNew) const Positioned(right: 0, top: 0, child: _RedDot()),
        ]),
      );
}
