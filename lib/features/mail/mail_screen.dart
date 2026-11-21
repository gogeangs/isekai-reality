import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/armory.dart';
import '../../core/models/mail_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../alchemy/alchemy_screen.dart' show PotionIcon;
import '../pets/pet_art.dart' show EggArt;
import '../smithy/equipment_view.dart' show EquipIcon, equipGradeColor;
import '../town/bag_sheet.dart' show bagIconAsset;
import '../town/material_view.dart' show MaterialIcon;

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
            final cur =
                c.mail.mails.firstWhere((x) => x.id == m.id, orElse: () => m);
            return ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              children: [
                Text(mailText(cur.title), style: AppText.title(19)),
                const SizedBox(height: 2),
                Text('${cur.from} · ${cur.sentAt.month}월 ${cur.sentAt.day}일',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
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
                  KText(mailText(cur.body),
                      style:
                          const TextStyle(color: AppColors.text, height: 1.5)),
                if (cur.gifts.isNotEmpty ||
                    cur.equips.isNotEmpty ||
                    cur.taken.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // 묶음 75 #333: 선물을 그림 칸으로 (받은 것은 흐리게)
                  OrnatePanel(
                    key: const Key('mailGifts'),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(cur.claimed ? '받은 선물' : '선물',
                              style: AppText.title(15,
                                  color: cur.claimed
                                      ? AppColors.textMuted
                                      : AppColors.goldBright)),
                          const SizedBox(height: 8),
                          GiftGrid(controller: c, mail: cur),
                          if (cur.expiresAt != null && !cur.claimed) ...[
                            const SizedBox(height: 6),
                            Text(
                                '${MailRules.daysLeft(cur.expiresAt!, now)}일 뒤 사라져요',
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 12)),
                          ],
                        ]),
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
                  FrameButton(
                      label: '닫기', onPressed: () => Navigator.of(sheet).pop()),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 묶음 75 #336: 한 쪽 15통 · 지금 쪽
  static const int perPage = 15;
  int _page = 0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _goPage(int p) {
    setState(() => _page = p);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
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
              1 => [
                  for (final m in all)
                    if (m.kind == MailKind.notice) m
                ],
              _ => all,
            };
            final pages = math.max(1, (list.length + perPage - 1) ~/ perPage);
            final page = _page.clamp(0, pages - 1);
            final shown = list.skip(page * perPage).take(perPage).toList();
            final giftCount = list.where((m) => m.hasGifts).length;
            // 위쪽은 고정 (제목 · 탭 · 모두 받기 · 안내), 목록 판 안에서만 내려간다
            return Padding(
              padding:
                  EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OrnateTopBar(
                      title: '우편함',
                      onBack: () => Navigator.of(context).maybePop()),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final (i, label) in [
                      (0, '전체'),
                      (1, '공지'),
                    ]) ...[
                      ChoiceChip(
                        key: Key('mailFilter_$i'),
                        label: Text(label),
                        selected: _tab == i,
                        onSelected: (_) => setState(() {
                          _tab = i;
                          _page = 0;
                          if (_scroll.hasClients) _scroll.jumpTo(0);
                        }),
                        selectedColor: AppColors.gold,
                        backgroundColor: AppColors.chipBg,
                        labelStyle: TextStyle(
                            color: _tab == i ? AppColors.night : AppColors.text,
                            fontWeight: FontWeight.w700),
                        showCheckmark: false,
                      ),
                      const SizedBox(width: 6),
                    ],
                    const Spacer(),
                    if (giftCount > 0)
                      TextButton.icon(
                        key: const Key('mailGiftJump'),
                        style: TextButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            foregroundColor: AppColors.goldBright),
                        onPressed: () {
                          // 받을 선물이 있는 가장 가까운 쪽
                          var best = -1;
                          for (var i = 0; i < list.length; i++) {
                            if (!list[i].hasGifts) continue;
                            final p = i ~/ perPage;
                            if (best < 0 ||
                                (p - page).abs() < (best - page).abs()) {
                              best = p;
                            }
                          }
                          if (best >= 0) _goPage(best);
                        },
                        icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                        label: Text('선물 $giftCount통',
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ]),
                  const SizedBox(height: 8),
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
                    const Text(
                        '가방이 가득하면 들어가지 않는 물건은 우편에 남아요. 자리를 만든 뒤 다시 받아요. 금화·마석은 언제나 받아요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
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
                    )
                  else
                    // 큰 금테 판 하나 안에 한 줄씩 (11-11 #88) — 판 안에서만 내려간다
                    Flexible(
                      child: OrnatePanel(
                        key: const Key('mailList'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        child: ListView.separated(
                          key: const Key('mailScroll'),
                          controller: _scroll,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: shown.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 0.6,
                              color: AppColors.gold.withValues(alpha: 0.25)),
                          itemBuilder: (_, i) => _MailRow(
                              key: Key('mailRow_${shown[i].id}'),
                              controller: c,
                              mail: shown[i],
                              onTap: () => _open(shown[i])),
                        ),
                      ),
                    ),
                  if (pages > 1) ...[
                    const SizedBox(height: 6),
                    MailPager(page: page, pages: pages, onPage: _goPage),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 묶음 75 #336: 「‹ 1 2 3 ›」 (지금 쪽 금색, 많으면 「‹ 1 … 4 5 6 … 12 ›」, 누르는 칸 44 이상)
class MailPager extends StatelessWidget {
  const MailPager(
      {super.key,
      required this.page,
      required this.pages,
      required this.onPage});

  final int page;
  final int pages;
  final ValueChanged<int> onPage;

  /// 보일 쪽 번호 (0부터, null 은 「…」)
  static List<int?> marks(int page, int pages) {
    if (pages <= 7) return [for (var i = 0; i < pages; i++) i];
    final out = <int?>[0];
    final a = math.max(1, math.min(page - 1, pages - 4));
    final b = math.min(pages - 2, math.max(page + 1, 3));
    if (a > 1) out.add(null);
    for (var i = a; i <= b; i++) {
      out.add(i);
    }
    if (b < pages - 2) out.add(null);
    out.add(pages - 1);
    return out;
  }

  Widget _cell(Widget child, {Key? key, VoidCallback? onTap}) => InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 44, height: 44, child: Center(child: child)),
      );

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          key: const Key('mailPager'),
          mainAxisSize: MainAxisSize.min,
          children: [
            _cell(
                Icon(Icons.chevron_left_rounded,
                    color: page > 0
                        ? AppColors.gold
                        : AppColors.textMuted.withValues(alpha: 0.4)),
                key: const Key('mailPagePrev'),
                onTap: page > 0 ? () => onPage(page - 1) : null),
            for (final m in marks(page, pages))
              if (m == null)
                _cell(const Text('…',
                    style: TextStyle(color: AppColors.textMuted)))
              else
                _cell(
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: m == page
                        ? BoxDecoration(
                            gradient: kGoldGradient,
                            borderRadius: BorderRadius.circular(9))
                        : null,
                    child: Text('${m + 1}',
                        style: TextStyle(
                            color:
                                m == page ? AppColors.goldInk : AppColors.text,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                  key: Key('mailPage_${m + 1}'),
                  onTap: m == page ? null : () => onPage(m),
                ),
            _cell(
                Icon(Icons.chevron_right_rounded,
                    color: page < pages - 1
                        ? AppColors.gold
                        : AppColors.textMuted.withValues(alpha: 0.4)),
                key: const Key('mailPageNext'),
                onTap: page < pages - 1 ? () => onPage(page + 1) : null),
          ],
        ),
      );
}

class _MailRow extends StatelessWidget {
  const _MailRow(
      {super.key,
      required this.controller,
      required this.mail,
      required this.onTap});

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
      if (m.hasGifts) giftLabel(controller, m.gifts, m.equips),
      if (m.expiresAt != null && m.hasGifts)
        '${MailRules.daysLeft(m.expiresAt!, controller.now)}일 남음',
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(
            width: 34,
            child: Stack(clipBehavior: Clip.none, children: [
              // 묶음 75 #333: 선물 우편은 첫 선물 그림(32) + 여럿이면 「+N」
              if (m.hasGifts)
                KeyedSubtree(
                    key: const Key('mailGiftMark'),
                    child: giftArt(controller, giftCells(m).first, size: 32))
              else
                Icon(icon,
                    color: unread ? AppColors.goldBright : AppColors.textMuted,
                    size: 24),
              if (m.hasGifts && giftCells(m).length > 1)
                Positioned(
                  right: -4,
                  bottom: -3,
                  child: Container(
                    key: const Key('mailGiftMore'),
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xE60B0D26),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.6),
                          width: 0.8),
                    ),
                    child: Text('+${giftCells(m).length - 1}',
                        style: const TextStyle(
                            color: AppColors.goldBright,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              if (unread) const Positioned(right: 0, top: -2, child: _RedDot()),
            ]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mailText(m.title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: unread ? AppColors.text : AppColors.textMuted,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14)),
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 6),
          Text(when(m.sentAt, controller.now),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.gold, size: 20),
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

/// 묶음 47 #237: 마을 「길드」는 「조합」으로 이름이 바뀜 — 예전에 받은 편지 글도 새 이름으로
String mailText(String s) => s.replaceAll('길드', '조합');

/// 묶음 75 #333: 선물 칸 하나 (열쇠 · 개수 · 장비 · 이미 받았는지)
class GiftCellData {
  const GiftCellData(this.key, this.count, {this.equip, this.taken = false});
  final String key;
  final int count;
  final EquipItem? equip;
  final bool taken;
}

/// 우편 선물 칸들: 이미 받은 것(흐리게) 먼저, 남은 것. 다 받은 우편은 모두 받은 것
List<GiftCellData> giftCells(MailItem m) {
  final left = m.claimed ? <String, int>{} : m.gifts;
  final taken = m.claimed
      ? {
          ...m.taken,
          for (final e in m.gifts.entries)
            e.key: (m.taken[e.key] ?? 0) + e.value,
        }
      : m.taken;
  return [
    for (final e in left.entries) GiftCellData(e.key, e.value),
    if (!m.claimed)
      for (final e in m.equips) GiftCellData('equip', 1, equip: e),
    for (final e in taken.entries) GiftCellData(e.key, e.value, taken: true),
    for (final e in [...m.takenEquips, if (m.claimed) ...m.equips])
      GiftCellData('equip', 1, equip: e, taken: true),
  ];
}

/// 선물 이름 (개수 없이)
String giftItemName(AppController c, String key) => switch (key) {
      Wallet.gold => '금화',
      Wallet.manaStone => '마석',
      Wallet.exp => '경험치',
      'note' => '레시피 쪽지',
      'tools' => '채집 도구',
      final k when EggGrade.ofKey(k) != null => EggGrade.ofKey(k)!.label,
      final k when k.startsWith('alc:') => c.potionName(k.substring(4)),
      final k when k.startsWith('item:') => () {
          for (final it in ShopItem.values) {
            if (it.name == k.substring(5)) return c.itemName(it);
          }
          return k;
        }(),
      final k => Materials.byName(k) == null
          ? k
          : Materials.info(Materials.byName(k)!).name,
    };

/// 선물 그림
Widget giftArt(AppController c, GiftCellData g, {double size = 56}) {
  Widget img(String a) => Image.asset('assets/images/$a.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => GameIcon('bag', size: size * 0.9));
  if (g.equip case final e?) {
    return EquipIcon(base: e.base, grade: e.grade, size: size);
  }
  final k = g.key;
  return switch (k) {
    Wallet.gold => img('icon_gold'),
    Wallet.manaStone => img('icon_mana_stone'),
    Wallet.exp => img('icon_exp'),
    'note' => img('item_recipe_note'),
    'tools' => img('tool_axe_stone'),
    _ when EggGrade.ofKey(k) != null =>
      EggArt(size: size, grade: EggGrade.ofKey(k)!),
    _ when k.startsWith('alc:') => PotionIcon(
        potion: AlchemyRules.parseKey(k.substring(4))?.id,
        suspicious: k.substring(4).startsWith('?:'),
        size: size),
    _ when k.startsWith('item:') => () {
        for (final it in ShopItem.values) {
          if (it.name == k.substring(5)) {
            return Image.asset(bagIconAsset(c, it),
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    GameIcon('bag', size: size * 0.9));
          }
        }
        return GameIcon('bag', size: size * 0.9);
      }(),
    _ when Materials.byName(k) != null =>
      MaterialIcon(Materials.byName(k)!, size: size),
    _ => GameIcon('bag', size: size * 0.9),
  };
}

/// 묶음 75 #333: 선물 칸 격자 (가방 칸 모양 56 · 한 줄 5칸 · 아래 이름)
class GiftGrid extends StatelessWidget {
  const GiftGrid({super.key, required this.controller, required this.mail});

  final AppController controller;
  final MailItem mail;

  @override
  Widget build(BuildContext context) {
    final cells = giftCells(mail);
    return LayoutBuilder(builder: (context, box) {
      const gap = 6.0;
      final w = math.min(64.0, (box.maxWidth - gap * 4) / 5);
      return Wrap(
        spacing: gap,
        runSpacing: 8,
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              key: Key(
                  'giftCell_${cells[i].taken ? 'got_' : ''}${cells[i].equip?.base.name ?? cells[i].key}'),
              width: w,
              child: Opacity(
                opacity: cells[i].taken ? 0.38 : 1,
                child: Column(children: [
                  Container(
                    width: w,
                    height: w,
                    decoration: BoxDecoration(
                      color: AppColors.slotBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: cells[i].equip != null
                              ? equipGradeColor(cells[i].equip!.grade)
                              : AppColors.gold.withValues(
                                  alpha: cells[i].taken ? 0.3 : 0.6)),
                    ),
                    child: Stack(children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: FittedBox(
                              child: SizedBox(
                                  width: 56,
                                  height: 56,
                                  child: giftArt(controller, cells[i]))),
                        ),
                      ),
                      if (cells[i].count > 1)
                        Positioned(
                          right: 2,
                          bottom: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xE60B0D26),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.6),
                                  width: 0.8),
                            ),
                            child: Text('${cells[i].count}',
                                style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 3),
                  Text(
                      cells[i].equip != null
                          ? EquipmentRules.info(cells[i].equip!.base).name
                          : giftItemName(controller, cells[i].key),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: cells[i].taken
                              ? AppColors.textMuted
                              : AppColors.text,
                          fontSize: 11,
                          height: 1.15,
                          fontWeight: cells[i].taken
                              ? FontWeight.w500
                              : FontWeight.w700)),
                ]),
              ),
            ),
        ],
      );
    });
  }
}

/// 선물 글 ('금화 100, 약초 3')
String giftLabel(AppController c, Map<String, int> gifts,
        [List<EquipItem> equips = const []]) =>
    [
      for (final e in gifts.entries)
        switch (e.key) {
          Wallet.gold => '금화 ${e.value}',
          Wallet.manaStone => '마석 ${e.value}',
          Wallet.exp => '경험치 ${e.value}',
          'note' => '레시피 쪽지 ${e.value}',
          'tools' => '채집 도구 한 벌',
          final k when EggGrade.ofKey(k) != null =>
            '${EggGrade.ofKey(k)!.label} ${e.value}',
          final k when k.startsWith('alc:') =>
            '${c.potionName(k.substring(4))} ${e.value}',
          final k when k.startsWith('item:') => () {
              for (final it in ShopItem.values) {
                if (it.name == k.substring(5)) {
                  return '${c.itemName(it)} ${e.value}';
                }
              }
              return k;
            }(),
          final k =>
            '${Materials.byName(k) == null ? k : Materials.info(Materials.byName(k)!).name} ${e.value}',
        },
      for (final e in equips) EquipmentRules.info(e.base).name,
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
