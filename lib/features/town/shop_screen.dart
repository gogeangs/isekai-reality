import '../village/npc_header.dart';
import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../village/board_parchment.dart' show EqualHeightRow;
import 'bag_sheet.dart';
import 'material_view.dart';
import 'sell_sheet.dart';
import '../../theme/top_notice.dart';
import '../jobs/job_skill_bar.dart';

/// 사기 탭 묶음 (묶음 41 #227)
enum ShopGroup { potion, travel, material }

extension ShopGroupInfo on ShopGroup {
  String get label => switch (this) {
        ShopGroup.potion => '물약',
        ShopGroup.travel => '여행 도구',
        ShopGroup.material => '재료',
      };

  static ShopGroup of(ShopItem item) => switch (item) {
        ShopItem.healSmall ||
        ShopItem.heal ||
        ShopItem.manaSmall ||
        ShopItem.mana ||
        ShopItem.jobManaSmall ||
        ShopItem.jobMana ||
        ShopItem.bulssiPotion =>
          ShopGroup.potion,
        ShopItem.ironShard ||
        ShopItem.twig ||
        ShopItem.herb ||
        ShopItem.herbSeed =>
          ShopGroup.material,
        ShopItem.expeditionCompass ||
        ShopItem.purifyIncense ||
        ShopItem.spareKey ||
        ShopItem.raceLens ||
        ShopItem.magicLens =>
          ShopGroup.travel,
      };
}

/// 잡화상 (앱 안 시설): 몬스터가 떨어뜨린 마석을 금화로 팔고, 금화로 물건을 산다.
///
/// 묶음 41 (#227): 위쪽(뒤로 가기 · 미나 · 마석·금화 · 사기/팔기 탭)은 화면 위에 붙어 있고
/// 아래 내용만 굴러간다.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.controller});

  final AppController controller;

  static String reason(PurchaseCheck check, ShopItemInfo info, int gold) =>
      switch (check) {
        PurchaseCheck.ok => '',
        // 11-11 #67: 다시 살 수 있는 때
        PurchaseCheck.limitReached =>
          info.limit == ShopLimit.perDay ? '내일 다시' : '월요일에 다시',
        PurchaseCheck.notEnoughCrystals => '금화 ${info.price - gold} 부족',
        PurchaseCheck.needsLocation => '위치를 켜 주세요',
        PurchaseCheck.levelTooLow => 'Lv.${info.minLevel}부터',
        PurchaseCheck.bagFull => '가방이 가득 찼어요',
      };

  static String boughtLine(ShopItem item) => switch (item) {
        ShopItem.spareKey => '여분의 열쇠를 샀어요. 던전 열쇠가 하나 늘었어요!',
        ShopItem.bulssiPotion => '가방에 넣었어요!',
        ShopItem.magicLens => '마법 돋보기는 더 이상 팔지 않아요.',
        ShopItem.raceLens =>
          '마법 돋보기를 가방에 넣었어요. 가방에서 「감정하기」로 친구의 종족을 감정해 봐요!',
        ShopItem.expeditionCompass =>
          '원정 나침반을 가방에 넣었어요. 원정을 보내기 전에 써요!',
        ShopItem.purifyIncense =>
          '성장의 향을 가방에 넣었어요. 몬스터를 잡으러 가는 날 피워요!',
        ShopItem.ironShard ||
        ShopItem.twig ||
        ShopItem.herb ||
        ShopItem.herbSeed =>
          '${josa(TownRules.info(item).name, '을/를')} 재료 주머니에 넣었어요.',
        ShopItem.healSmall ||
        ShopItem.heal ||
        ShopItem.manaSmall ||
        ShopItem.mana ||
        ShopItem.jobManaSmall ||
        ShopItem.jobMana =>
          '가방에 넣었어요. 필요할 때 가방에서 마셔요!',
      };

  /// 카드의 짧은 효과 한 줄
  static String effectLine(AppController c, ShopItem item) {
    final i = TownRules.info(item);
    String pct(double r) => '${(r * 100).round()}%';
    if (i.hpRatio > 0) return 'HP ${pct(i.hpRatio)} 회복';
    if (i.mpRatio > 0) return '기력 ${pct(i.mpRatio)} 회복';
    if (i.jobMpRatio > 0) return 'MP ${pct(i.jobMpRatio)} 회복';
    return switch (item) {
      ShopItem.bulssiPotion =>
        c.farewellDone ? '펫 경험치·친밀도' : '던전 스킬 게이지 빨리',
      ShopItem.spareKey => '오늘 던전 열쇠 +1',
      ShopItem.expeditionCompass => '다음 원정 이동 시간 절반',
      ShopItem.purifyIncense => '피운 날 몬스터 경험치 더',
      ShopItem.raceLens => '사람의 이세계 종족 감정',
      ShopItem.magicLens => '주변 안개 걷기',
      ShopItem.ironShard => '무기 재료',
      ShopItem.twig => '지팡이 재료',
      ShopItem.herb => '회복 물약 재료',
      ShopItem.herbSeed => '약초밭에 심는 씨앗',
      _ => '',
    };
  }

  /// 가진 수 (가방·재료 주머니). 여분의 열쇠는 던전 열쇠 수
  static int owned(AppController c, ShopItem item) {
    final mat = TownRules.info(item).material;
    if (mat != null) return c.player.materialCount(mat);
    if (item == ShopItem.spareKey) return c.player.gauge.keysAvailable;
    if (TownRules.bagItems.contains(item)) return c.bagCount(item);
    return 0;
  }

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  AppController get c => widget.controller;

  int _tab = 0;

  /// 사기 탭 묶음 칩 (null = 전체)
  ShopGroup? _group;

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
            final p = c.player;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── 위쪽 묶음 (붙어 있음)
                Padding(
                  key: const Key('shopHeader'),
                  padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OrnateTopBar(
                        title: '잡화상',
                        onBack: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(height: 6),
                      // 묶음 38 #213: 정령 띠 대신 마을 사람이 안내
                      NpcHeader(
                          controller: c,
                          npc: Npc.mina,
                          guide: VillageRules.shopGuide),
                      const SizedBox(height: 6),
                      JobSkillBar(
                          controller: c, places: const [SkillPlace.shop]),
                      ShopWalletLine(manaStones: p.manaStones, gold: p.gold),
                      const SizedBox(height: 4),
                      Row(children: [
                        for (final (i, label) in const [(0, '사기'), (1, '팔기')]) ...[
                          Expanded(
                            child: ShopTabButton(
                              key: Key('shopTab_$i'),
                              label: label,
                              selected: _tab == i,
                              onTap: () => setState(() => _tab = i),
                            ),
                          ),
                          if (i == 0) const SizedBox(width: 8),
                        ],
                      ]),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
                // ── 아래 내용 (굴러감)
                Expanded(
                  child: Stack(children: [
                    Positioned.fill(
                      child: _tab == 0
                          ? ListView(
                              key: const Key('shopList'),
                              padding: EdgeInsets.fromLTRB(
                                  14, 8, 14, 28 + pad.bottom),
                              children: _buyTab(),
                            )
                          : ShopSellTab(controller: c),
                    ),
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 14,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: Key('shopHeaderShadow'),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x99000000), Color(0x00000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────── 사기 탭

  /// 살 수 없는 카드(다 산 것·레벨 전)는 흐리게 맨 아래로
  bool _dim(PurchaseCheck check) =>
      check == PurchaseCheck.limitReached || check == PurchaseCheck.levelTooLow;

  List<Widget> _buyTab() {
    final hasLocation = c.lastFix != null;
    final items = c.shopItems;
    final groups = _group == null ? ShopGroup.values : [_group!];
    return [
      SingleChildScrollView(
        key: const Key('shopChips'),
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final g in <ShopGroup?>[null, ...ShopGroup.values]) ...[
            ShopChip(
              key: Key('shopChip_${g?.name ?? 'all'}'),
              label: g?.label ?? '전체',
              selected: _group == g,
              onTap: () => setState(() => _group = g),
            ),
            const SizedBox(width: 6),
          ],
        ]),
      ),
      const SizedBox(height: 10),
      for (final g in groups) ...() {
        final mine = [
          for (final i in items)
            if (ShopGroupInfo.of(i.item) == g) i
        ];
        if (mine.isEmpty) return const <Widget>[];
        final checks = {
          for (final i in mine)
            i.item: c.canBuy(i.item, hasLocation: hasLocation)
        };
        final sorted = [
          for (final i in mine)
            if (!_dim(checks[i.item]!)) i,
          for (final i in mine)
            if (_dim(checks[i.item]!)) i,
        ];
        return <Widget>[
          if (_group == null)
            Padding(
              key: Key('shopGroup_${g.name}'),
              padding: const EdgeInsets.fromLTRB(4, 4, 0, 6),
              child: Text(g.label,
                  style: AppText.title(15, color: AppColors.goldBright)),
            ),
          if (g == ShopGroup.potion) ...[
            _VitalBars(controller: c),
            const SizedBox(height: 8),
          ],
          for (var k = 0; k < sorted.length; k += 2) ...[
            EqualHeightRow(gap: 10, children: [
              for (final i in sorted.skip(k).take(2))
                _ItemCard(
                  key: Key('shopItem_${i.item.name}'),
                  controller: c,
                  info: i,
                  check: checks[i.item]!,
                  dim: _dim(checks[i.item]!),
                  onTap: () => _tapItem(i, checks[i.item]!),
                ),
              if (sorted.length - k == 1) const SizedBox.shrink(),
            ]),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
        ];
      }(),
    ];
  }

  Future<void> _tapItem(ShopItemInfo info, PurchaseCheck check) async {
    if (check != PurchaseCheck.ok) {
      showTopNotice(context, switch (check) {
        PurchaseCheck.limitReached => info.limit == ShopLimit.perDay
            ? '내일 다시 살 수 있어요'
            : '월요일에 다시 살 수 있어요',
        _ => ShopScreen.reason(check, info, c.player.gold),
      });
      return;
    }
    final n = await showBuySheet(context, c, info);
    if (n == null || n <= 0 || !mounted) return;
    final (bought, last) = await c.buyMany(info.item, n);
    if (!mounted) return;
    showTopNotice(
        context,
        bought > 0
            ? '${ShopScreen.boughtLine(info.item)}${bought > 1 ? ' ×$bought' : ''}'
            : ShopScreen.reason(last, info, c.player.gold));
  }
}

/// 몇 개 살지 고르기 (#227 시안 ②). 최대가 1이면 − + 없이 바로 확인
Future<int?> showBuySheet(
    BuildContext context, AppController c, ShopItemInfo info) {
  final max = c.shopMaxBuy(info.item);
  var n = 1;
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: AppColors.night,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheet) => SafeArea(
      child: StatefulBuilder(builder: (sheet, set) {
        final gold = c.player.gold;
        final total = n * info.price;
        final left = c.shopLeft(info.item);
        final period = info.limit == ShopLimit.perDay ? '오늘' : '이번 주';
        Widget round(IconData icon, Key key, VoidCallback? on) => SizedBox(
              width: 48,
              height: 48,
              child: OutlinedButton(
                key: key,
                onPressed: on,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                  side: BorderSide(
                      color: AppColors.gold
                          .withValues(alpha: on == null ? 0.25 : 0.8)),
                ),
                child: Icon(icon,
                    color: on == null ? AppColors.textMuted : AppColors.goldBright),
              ),
            );
        return SingleChildScrollView(
          key: const Key('buySheet'),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                SizedBox(
                    width: 72, height: 72, child: ShopItemIcon(c: c, info: info)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.itemName(info.item),
                          style: AppText.title(19, color: AppColors.text)),
                      const SizedBox(height: 2),
                      KText(c.itemDescription(info.item),
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 13, height: 1.35)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              KText(
                  '${info.item == ShopItem.spareKey ? '열쇠' : '가진 것'} ${ShopScreen.owned(c, info.item)} · '
                  '$period $left개 더 살 수 있어요',
                  key: const Key('buyOwned'),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13)),
              if (max > 1) ...[
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  round(Icons.remove_rounded, const Key('buyMinus'),
                      n > 1 ? () => set(() => n--) : null),
                  SizedBox(
                    width: 72,
                    child: Text('$n',
                        key: const Key('buyCount'),
                        textAlign: TextAlign.center,
                        style: AppText.title(26, color: AppColors.text)),
                  ),
                  round(Icons.add_rounded, const Key('buyPlus'),
                      n < max ? () => set(() => n++) : null),
                  const SizedBox(width: 10),
                  TextButton(
                    key: const Key('buyMax'),
                    onPressed: n < max ? () => set(() => n = max) : null,
                    child: Text('최대 $max',
                        style: const TextStyle(
                            color: AppColors.goldBright,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
              ],
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const GameIcon('gold',
                    size: 20, fallback: Icons.monetization_on_rounded),
                const SizedBox(width: 4),
                Text('합계 금화 ${comma(total)}',
                    key: const Key('buyTotal'),
                    style: AppText.title(16, color: AppColors.goldBright)),
                const SizedBox(width: 6),
                Text('(남는 금화 ${comma(gold - total)})',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12.5)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('buyCancel'),
                    onPressed: () => Navigator.of(sheet).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      side: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.7)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('그만두기',
                        style: TextStyle(color: AppColors.text)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GoldButton(
                    key: const Key('buyConfirm'),
                    label: '$n개 사기',
                    height: 46,
                    fontSize: 16,
                    onPressed: max > 0 ? () => Navigator.of(sheet).pop(n) : null,
                  ),
                ),
              ]),
            ],
          ),
        );
      }),
    ),
  );
}

/// 물건 그림
class ShopItemIcon extends StatelessWidget {
  const ShopItemIcon({super.key, required this.c, required this.info});

  final AppController c;
  final ShopItemInfo info;

  @override
  Widget build(BuildContext context) {
    if (info.material case final mat?) return MaterialIcon(mat, size: 48);
    return Image.asset(
        info.item == ShopItem.bulssiPotion
            ? bagIconAsset(c, info.item)
            : 'assets/images/${info.icon}.webp',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const GameIcon('gold', size: 48));
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.controller,
    required this.info,
    required this.check,
    required this.dim,
    required this.onTap,
  });

  final AppController controller;
  final ShopItemInfo info;
  final PurchaseCheck check;
  final bool dim;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final ok = check == PurchaseCheck.ok;
    final period = info.limit == ShopLimit.perDay ? '오늘' : '이번 주';
    final left = c.shopLeft(info.item);
    final note = switch (check) {
      PurchaseCheck.ok => null,
      _ => ShopScreen.reason(check, info, c.player.gold),
    };
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 44, height: 44, child: ShopItemIcon(c: c, info: info)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KText(c.itemName(info.item),
                    maxLines: 2,
                    style: AppText.title(14.5, color: AppColors.text)),
                KText(ShopScreen.effectLine(c, info.item),
                    maxLines: 2,
                    style: const TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
            '${info.item == ShopItem.spareKey ? '열쇠' : '가진 것'} ${ShopScreen.owned(c, info.item)}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        if (!dim)
          Text('$period $left개 남음',
              key: Key('left_${info.item.name}'),
              style: const TextStyle(color: AppColors.text, fontSize: 11.5))
        else
          Text(note ?? '',
              key: Key('again_${info.item.name}'),
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        if (!dim && note != null)
          KText(note,
              key: Key('short_${info.item.name}'),
              style: const TextStyle(
                  color: Color(0xFFE5A0A0),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        GoldButton(
          key: Key('price_${info.item.name}'),
          label: comma(info.price),
          leading: const GameIcon('gold',
              size: 18, fallback: Icons.monetization_on_rounded),
          height: 38,
          fontSize: 15,
          onPressed: ok ? onTap : null,
        ),
      ],
    );
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: OrnatePanel(
        padding: const EdgeInsets.all(10),
        child: dim ? Opacity(opacity: 0.5, child: body) : body,
      ),
    );
  }
}

/// 물약 묶음 제목 아래 HP · 기력 (· MP) 막대 (숫자 없이)
class _VitalBars extends StatelessWidget {
  const _VitalBars({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    Widget bar(String label, int v, int max, Color color, Key key) => Expanded(
          child: Row(key: key, children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: max <= 0 ? 0 : (v / max).clamp(0, 1).toDouble(),
                  minHeight: 7,
                  color: color,
                  backgroundColor: const Color(0x55000000),
                ),
              ),
            ),
          ]),
        );
    return Row(key: const Key('shopVitals'), children: [
      bar('HP', c.hp, c.maxHp, const Color(0xFFE5534B), const Key('bar_hp')),
      const SizedBox(width: 10),
      bar('기력', c.mp, c.mpMax, const Color(0xFF5AA9F0), const Key('bar_mp')),
      if (c.jobsOpen) ...[
        const SizedBox(width: 10),
        bar('MP', c.jobMp, c.jobMpMax, const Color(0xFFA27BF0),
            const Key('bar_jobMp')),
      ],
    ]);
  }
}

/// 탭 바로 위 오른쪽 작은 한 줄 (마석 · 금화)
class ShopWalletLine extends StatelessWidget {
  const ShopWalletLine({super.key, required this.manaStones, required this.gold});

  final int manaStones;
  final int gold;

  @override
  Widget build(BuildContext context) {
    Widget one(String icon, IconData fb, int n, Key key) => Row(
          key: key,
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(icon, size: 18, fallback: fb),
            const SizedBox(width: 3),
            Text(comma(n),
                style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        );
    return Row(
      key: const Key('shopWallet'),
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        one('mana_stone', Icons.diamond_rounded, manaStones,
            const Key('shopWallet_mana')),
        const SizedBox(width: 12),
        one('gold', Icons.monetization_on_rounded, gold,
            const Key('shopWallet_gold')),
      ],
    );
  }
}

class ShopTabButton extends StatelessWidget {
  const ShopTabButton(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? kGoldGradient : null,
            color: selected ? null : const Color(0xAA12153A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
          ),
          child: Text(label,
              maxLines: 1,
              style: TextStyle(
                  color: selected ? AppColors.goldInk : AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
        ),
      );
}

class ShopChip extends StatelessWidget {
  const ShopChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0x55F2C14E) : const Color(0x8812153A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected
                    ? AppColors.goldBright
                    : AppColors.gold.withValues(alpha: 0.45)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? AppColors.goldBright : AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      );
}
