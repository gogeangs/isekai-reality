import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/armory.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../alchemy/alchemy_screen.dart' show PotionIcon;
import '../pets/pet_art.dart' show EggArt;
import '../settings/account_section.dart' show LoginButton, signInFlow;
import '../smithy/equipment_view.dart';
import '../town/material_view.dart';
import '../town/shop_screen.dart' show ShopItemIcon;
import '../tutorial/feature_tour.dart' show TourScreenMark;
import 'npc_header.dart';

/// 바르칸 대사 (개발 초안)
const _introLine = '허허, 드디어 장을 여는군! 값을 정해 걸어 두든, 경매에 붙이든 자네 마음일세. '
    '다만 장부는 내가 꼼꼼히 보네. 같은 집 식구끼리 주고받는 건 안 되고, 터무니없는 값도 안 받네.';
const _openGuide = '물건을 걸어 두면 내가 대신 팔아 주지. 팔린 금화와 산 물건은 내 이름으로 우편으로 보내네.';
/// 묶음 61: 거래 지갑 처음 볼 때 (개발 초안)
const _walletIntro = '장부를 하나 더 만들었네. 장에서 쓰는 금화는 내게 맡겨 두게 — 「거래 지갑」일세. '
    '사고, 걸고, 부르는 건 지갑 금화로만 하고, 판 금화와 돌려받는 금화도 지갑으로 들어오지. '
    '꺼내고 싶을 땐 언제든 말하게. 우편으로 보내 주겠네.';
const _loginGuide = '장은 열렸네. 다만 장부에 이름을 올려야 하니, 로그인한 각성자만 거래할 수 있네.';

/// 거래소 (묶음 58 #229): 사기 · 올리기 · 경매 · 내 장부. 로그인한 각성자만
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key, required this.controller, this.tab = 0});

  final AppController controller;
  final int tab;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  AppController get c => widget.controller;
  late int _tab = widget.tab;
  MarketKind? _cat;
  final _query = TextEditingController();
  List<MarketListing>? _rows;
  ({List<MarketListing> selling, List<MarketListing> bidding})? _mine;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (c.cloud.signedIn && c.marketIntroPending && mounted) {
        await showDialog<void>(
          context: context,
          builder: (d) => GameAlert(
            key: const Key('marketIntro'),
            title: Text('바르칸', style: AppText.title(18)),
            content: const KText(_introLine, style: TextStyle(color: AppColors.text, height: 1.5)),
            actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('좋아요'))],
          ),
        );
        await c.markMarketIntro();
      }
      if (c.cloud.signedIn && c.walletIntroPending && mounted) {
        await showDialog<void>(
          context: context,
          builder: (d) => GameAlert(
            key: const Key('walletIntro'),
            title: Text('바르칸 · 거래 지갑', style: AppText.title(18)),
            content: const KText(_walletIntro, style: TextStyle(color: AppColors.text, height: 1.5)),
            actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('알겠어요'))],
          ),
        );
        await c.markWalletIntro();
      }
      if (c.cloud.signedIn && c.marketWallet == null) await c.refreshWallet();
      await _reload();
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!c.cloud.signedIn || !mounted) return;
    setState(() => _loading = true);
    if (_tab == 0 || _tab == 2) {
      final r = await c.browseMarket(kind: _cat, query: _query.text, auction: _tab == 2);
      if (mounted) setState(() => _rows = r);
    } else if (_tab == 3) {
      final r = await c.myMarket();
      if (mounted) setState(() => _mine = r);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _err() => showTopNotice(context, MarketOps.marketErrorText(c.marketError),
      icon: Icons.info_outline_rounded);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return TourScreenMark(
      name: 'market',
      child: Scaffold(
        key: const Key('marketScreen'),
        backgroundColor: AppColors.deepNight,
        body: NightBackground(
          header: true,
          child: ListenableBuilder(
            listenable: c,
            builder: (context, _) => ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(title: '거래소', onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 6),
                NpcHeader(controller: c, npc: Npc.barkan, guide: c.cloud.signedIn ? _openGuide : _loginGuide),
                const SizedBox(height: 10),
                if (!c.cloud.signedIn) _login() else ..._open(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _login() => OrnatePanel(
        key: const Key('marketClosed'),
        child: Column(children: [
          const Icon(Icons.menu_book_rounded, color: AppColors.goldBright, size: 34),
          const SizedBox(height: 6),
          const KText('거래소는 로그인한 각성자끼리 열려요.\n로그인하면 기록이 서버에 함께 맡겨져요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text, fontSize: 13.5, height: 1.5)),
          const SizedBox(height: 10),
          if (c.cloudAvailable)
            for (final p in c.loginProviders) ...[
              LoginButton(provider: p, busy: c.cloudBusy, onPressed: () async {
                await signInFlow(context, c, p);
                if (mounted && c.cloud.signedIn) await _reload();
              }),
              const SizedBox(height: 8),
            ]
          else
            const Text('로그인은 준비 중이에요.', style: TextStyle(color: AppColors.textMuted)),
        ]),
      );

  /// 묶음 61: 지갑 ○ 금화 · 맡기기 · 꺼내기
  Widget _walletBar() {
    final w = c.marketWallet;
    return OrnatePanel(
      key: const Key('walletBar'),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(children: [
        const Icon(Icons.account_balance_wallet_rounded, color: AppColors.goldBright, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('거래 지갑', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            Text(w == null ? '…' : '금화 ${comma(w)}', key: const Key('walletGold'), style: AppText.title(17)),
          ]),
        ),
        TextButton(key: const Key('walletDeposit'), onPressed: c.marketBusy ? null : () => _walletSheet(true), child: const Text('맡기기')),
        TextButton(
            key: const Key('walletWithdraw'),
            onPressed: c.marketBusy || (w ?? 0) <= 0 ? null : () => _walletSheet(false),
            child: const Text('꺼내기')),
      ]),
    );
  }

  Future<void> _walletSheet(bool deposit) async {
    final max = deposit ? c.player.gold : (c.marketWallet ?? 0);
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => WalletSheet(c: c, deposit: deposit, max: max),
    );
    if (!mounted || done == null) return;
    if (done) {
      showTopNotice(context, deposit ? '바르칸에게 맡겼어요' : '꺼낸 금화는 바르칸 우편으로 와요',
          icon: Icons.account_balance_wallet_rounded);
      setState(() {});
    } else {
      _err();
    }
  }

  List<Widget> _open() => [
        _walletBar(),
        const SizedBox(height: 8),
        Row(children: [
          for (final (i, t) in const ['사기', '올리기', '경매', '내 장부'].indexed) ...[
            if (i > 0) const SizedBox(width: 5),
            Expanded(
              child: ChoiceChip(
                key: Key('marketTab_$i'),
                label: SizedBox(width: double.infinity, child: Text(t, textAlign: TextAlign.center)),
                selected: _tab == i,
                onSelected: (_) {
                  setState(() => _tab = i);
                  _reload();
                },
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        if (_tab != 3) _cats(),
        if (_tab == 0 || _tab == 2) ...[
          const SizedBox(height: 6),
          TextField(
            key: const Key('marketSearch'),
            controller: _query,
            style: const TextStyle(color: AppColors.text),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _reload(),
            decoration: InputDecoration(
              isDense: true,
              hintText: '이름 찾기',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (_loading && (_tab != 1))
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: AppColors.goldBright)),
          )
        else
          ...switch (_tab) {
            0 || 2 => _browse(),
            1 => _sellList(),
            _ => _ledger(),
          },
      ];

  Widget _cats() => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final k in <MarketKind?>[if (_tab != 1) null, ...MarketKind.values])
          ChoiceChip(
            key: Key('marketCat_${k?.name ?? 'all'}'),
            label: Text(k?.label ?? '모두'),
            selected: _cat == k || (_tab == 1 && _cat == null && k == MarketKind.mat),
            onSelected: (_) {
              setState(() => _cat = k);
              _reload();
            },
          ),
      ]);

  // ───────────── 사기 · 경매

  List<Widget> _browse() {
    final rows = _rows;
    if (rows == null) {
      return [
        if (c.marketError != null)
          _note(MarketOps.marketErrorText(c.marketError), retry: true)
        else
          const SizedBox(),
      ];
    }
    if (rows.isEmpty) {
      return [_note(_tab == 2 ? '지금 열린 경매가 없어요.' : '지금 걸린 물건이 없어요.')];
    }
    return [
      if (_tab == 0)
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('싼 순서', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
      for (final l in rows) ...[
        _row(l, action: _tab == 2 ? (l.myBid ? '더 부르기' : '입찰') : '사기', onTap: () => _tab == 2 ? _bid(l) : _buy(l)),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _icon(MarketKind k, String key, EquipItem? e, {double size = 44}) => SizedBox(
        width: size,
        height: size,
        child: switch (k) {
          MarketKind.mat => switch (Materials.byName(key)) {
              final m? => MaterialIcon(m, size: size),
              null => const Icon(Icons.inventory_2_rounded),
            },
          MarketKind.item => switch (ShopItem.values.where((i) => i.name == key).firstOrNull) {
              final i? => ShopItemIcon(c: c, info: TownRules.info(i)),
              null => const Icon(Icons.local_drink_rounded),
            },
          MarketKind.equip => e == null
              ? const Icon(Icons.shield_rounded)
              : EquipIcon(base: e.base, grade: e.grade, size: size),
          MarketKind.egg => EggArt(size: size),
          MarketKind.alc => switch (PotionId.values.where((p) => p.name == key).firstOrNull) {
              final p? => PotionIcon(potion: p, size: size),
              null => const Icon(Icons.science_rounded),
            },
        },
      );

  String _left(DateTime? end) {
    if (end == null) return '';
    final d = end.difference(c.now);
    if (d.isNegative) return '곧 끝나요';
    if (d.inHours >= 1) return '${d.inHours}시간 남음';
    return '${d.inMinutes.clamp(1, 59)}분 남음';
  }

  Widget _row(MarketListing l, {String? action, VoidCallback? onTap, Widget? trailing}) => OrnatePanel(
        key: Key('listing_${l.id}'),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(children: [
          _icon(l.kind, l.key, l.equip),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (l.equip case final e?)
                EquipName(e, size: 14)
              else
                Text(l.qty > 1 ? '${l.name} ×${l.qty}' : l.name,
                    style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
              if (l.equip case final e?) ItemStats(e, fontSize: 11.5),
              Text(
                  [
                    if (!l.mine && l.sellerName.isNotEmpty) l.sellerName,
                    if (l.auction) l.bids > 0 ? '입찰 ${l.bids}번' : '입찰 없음',
                    if (l.status == 'open') _left(l.endsAt) else _status(l.status),
                    if (l.myBid) '내가 가장 높아요',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ]),
          ),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('금화 ${comma(l.now)}',
                style: const TextStyle(color: AppColors.goldBright, fontSize: 13.5, fontWeight: FontWeight.w800)),
            if (l.auction && l.buyNow != null)
              Text('바로 사기 ${comma(l.buyNow!)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            if (action != null)
              TextButton(
                key: Key('listingAct_${l.id}'),
                style: gameButtonStyle(gold: true),
                onPressed: c.marketBusy ? null : onTap,
                child: Text(action),
              ),
            if (trailing != null) trailing,
          ]),
        ]),
      );

  String _status(String s) => switch (s) {
        'sold' => '팔렸어요',
        'expired' => '안 팔려 돌아왔어요',
        'cancelled' => '내렸어요',
        _ => '',
      };

  Future<String> _priceLine(MarketKind k, String key) async {
    final p = await c.marketPrice(k, key);
    if (p == null || p.count == 0) return '최근 시세 · 아직 거래가 없어요';
    return '최근 시세(하나) · 마지막 ${comma(p.last)} · 평균 ${comma(p.avg)} · ${comma(p.min)}~${comma(p.max)}';
  }

  Future<void> _buy(MarketListing l) async {
    final price = await _priceLine(l.kind, l.equip?.base.name ?? l.key);
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        key: const Key('buyConfirm'),
        title: Text(l.qty > 1 ? '${l.name} ×${l.qty}' : l.name, style: AppText.title(18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('금화 ${comma(l.price ?? 0)}에 살까요?', style: const TextStyle(color: AppColors.text, fontSize: 15)),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          Text('거래 지갑 금화로 사요 · 산 물건은 바르칸 우편으로 와요',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('그만두기')),
          TextButton(key: const Key('buyOk'), onPressed: () => Navigator.pop(d, true), child: const Text('사기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (await c.buyOnMarket(l)) {
      if (mounted) showTopNotice(context, '샀어요! 우편함에서 받아요', icon: Icons.mail_rounded);
    } else if (mounted) {
      _err();
    }
    await _reload();
  }

  Future<void> _bid(MarketListing l) async {
    final next = l.next ?? l.now;
    final ctl = TextEditingController(text: '$next');
    final price = await _priceLine(l.kind, l.equip?.base.name ?? l.key);
    if (!mounted) return;
    final amount = await showDialog<int>(
      context: context,
      builder: (d) => GameAlert(
        key: const Key('bidDialog'),
        title: Text('입찰 · ${l.name}', style: AppText.title(18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('지금 ${comma(l.now)} · 다음은 ${comma(next)} 이상',
              style: const TextStyle(color: AppColors.text, fontSize: 14)),
          const SizedBox(height: 6),
          TextField(
            key: const Key('bidAmount'),
            controller: ctl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: AppColors.text, fontSize: 18),
            decoration: const InputDecoration(suffixText: '금화'),
          ),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const Text('부른 금화는 묶어 두고, 다른 손님이 더 높게 부르면 우편으로 돌려받아요.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('그만두기')),
          if (l.buyNow != null)
            TextButton(
                key: const Key('bidBuyNow'),
                onPressed: () => Navigator.pop(d, l.buyNow),
                child: Text('바로 사기 ${comma(l.buyNow!)}')),
          TextButton(
              key: const Key('bidOk'),
              onPressed: () => Navigator.pop(d, int.tryParse(ctl.text)),
              child: const Text('부르기')),
        ],
      ),
    );
    ctl.dispose();
    if (amount == null || !mounted) return;
    if (amount < next) {
      showTopNotice(context, '${comma(next)} 이상 불러야 해요');
      return;
    }
    final r = await c.bidOnMarket(l, amount);
    if (!mounted) return;
    if (r.ok) {
      showTopNotice(context, r.sold ? '바로 샀어요! 우편함에서 받아요' : '입찰했어요 · 가장 높은 값이에요', icon: Icons.gavel_rounded);
    } else {
      _err();
    }
    await _reload();
  }

  // ───────────── 올리기

  List<Widget> _sellList() {
    final k = _cat ?? MarketKind.mat;
    final own = c.marketOwn(k);
    return [
      KText(
          '올릴 때 금화 조금(값의 2%, 안 팔려도 돌려주지 않아요) · 팔리면 수수료 '
          '${((c.marketBest ? MarketRules.feeRateBest : MarketRules.feeRate) * 100).round()}%'
          '${c.hasBarkanSeal ? ' · 상단 인장으로 올리는 금화 절반' : ''}',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      const SizedBox(height: 8),
      if (own.isEmpty)
        _note(k == MarketKind.equip
            ? '올릴 수 있는 장비가 없어요. 입고 있는 장비 · 보스 장비 · 이름 있는 장비는 올릴 수 없어요.'
            : '올릴 수 있는 ${k.label}이(가) 없어요.'),
      for (final o in own) ...[
        OrnatePanel(
          key: Key('own_${o.key}'),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Row(children: [
            _icon(o.kind, o.equip?.base.name ?? o.key, o.equip),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (o.equip case final e?) EquipName(e, size: 14) else
                  Text(o.name, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(o.equip != null ? '' : '가진 것 ${o.have}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
              ]),
            ),
            TextButton(
              key: Key('sell_${o.key}'),
              style: gameButtonStyle(gold: true),
              onPressed: c.marketBusy ? null : () => _sell(o),
              child: const Text('올리기'),
            ),
          ]),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  Future<void> _sell(MarketOwn o) async {
    final price = await _priceLine(o.kind, o.equip?.base.name ?? o.key);
    if (!mounted) return;
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => _SellSheet(c: c, own: o, priceLine: price),
    );
    if (!mounted || done == null) return;
    if (done) {
      showTopNotice(context, '거래소에 올렸어요', icon: Icons.storefront_rounded);
      setState(() {});
    } else {
      _err();
    }
  }

  // ───────────── 내 장부

  List<Widget> _ledger() {
    final m = _mine;
    if (m == null) return [_note(MarketOps.marketErrorText(c.marketError), retry: true)];
    final open = m.selling.where((l) => l.status == 'open').length;
    return [
      Text('올려 둔 것 $open / ${c.marketSlots}', key: const Key('marketSlots'), style: AppText.title(16)),
      const SizedBox(height: 6),
      if (m.selling.isEmpty) _note('올려 둔 물건이 없어요.'),
      for (final l in m.selling) ...[
        _row(l,
            action: l.status == 'open' && (!l.auction || l.bids == 0) ? '내리기' : null,
            onTap: () async {
              if (await c.cancelMarket(l)) {
                if (mounted) showTopNotice(context, '내렸어요 · 물건은 우편으로 돌아와요');
              } else if (mounted) {
                _err();
              }
              await _reload();
            }),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 8),
      Text('입찰한 경매', style: AppText.title(16)),
      const SizedBox(height: 6),
      if (m.bidding.isEmpty) _note('입찰한 경매가 없어요.'),
      for (final l in m.bidding) ...[
        _row(l),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _note(String text, {bool retry = false}) => OrnatePanel(
        child: Column(children: [
          KText(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          if (retry) TextButton(onPressed: _reload, child: const Text('다시 불러오기')),
        ]),
      );
}

/// 올리기 창: 개수 · 값을 정해/경매 · 값 (한도 안) · 바로 사기 값 · 올리는 금화
class _SellSheet extends StatefulWidget {
  const _SellSheet({required this.c, required this.own, required this.priceLine});

  final AppController c;
  final MarketOwn own;
  final String priceLine;

  @override
  State<_SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends State<_SellSheet> {
  late int _qty = 1;
  bool _auction = false;
  late final _price = TextEditingController(text: '${widget.own.base * 2}');
  final _buyNow = TextEditingController();

  /// 개수를 바꾸면 값도 그만큼 (값을 고쳐 쓰지 않았을 때)
  bool _edited = false;
  void _setQty(int q) => setState(() {
        _qty = q;
        if (!_edited) _price.text = '${widget.own.base * 2 * q}';
      });

  int get _min => MarketRules.minPrice(widget.own.base, _qty);
  int get _max => MarketRules.maxPrice(widget.own.base, _qty);
  int get _p => int.tryParse(_price.text) ?? 0;
  int? get _bn => int.tryParse(_buyNow.text);

  @override
  void dispose() {
    _price.dispose();
    _buyNow.dispose();
    super.dispose();
  }

  bool get _valid =>
      _p >= _min && _p <= _max && (!_auction || _bn == null || (_bn! > _p && _bn! <= _max));

  @override
  Widget build(BuildContext context) {
    final o = widget.own;
    final c = widget.c;
    final stack = o.kind == MarketKind.mat || o.kind == MarketKind.item;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SafeArea(
        child: Column(
          key: const Key('sellSheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('올리기 · ${o.name}', style: AppText.title(18)),
            const SizedBox(height: 8),
            Row(children: [
              for (final (a, t) in [(false, '값을 정해 · ${widget.c.marketFixedHours}시간'), (true, '경매 · 24시간')]) ...[
                Expanded(
                  child: ChoiceChip(
                    key: Key(a ? 'sellAuction' : 'sellFixed'),
                    label: SizedBox(width: double.infinity, child: Text(t, textAlign: TextAlign.center)),
                    selected: _auction == a,
                    onSelected: (_) => setState(() => _auction = a),
                  ),
                ),
                if (!a) const SizedBox(width: 6),
              ],
            ]),
            if (stack) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Text('개수', style: TextStyle(color: AppColors.text)),
                const Spacer(),
                IconButton(
                    onPressed: _qty > 1 ? () => _setQty(_qty - 1) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.goldBright)),
                Text('$_qty', key: const Key('sellQty'), style: AppText.title(18)),
                IconButton(
                    key: const Key('sellQtyUp'),
                    onPressed: _qty < o.have && _qty < MarketRules.maxQty ? () => _setQty(_qty + 1) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.goldBright)),
              ]),
            ],
            const SizedBox(height: 6),
            TextField(
              key: const Key('sellPrice'),
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() => _edited = true),
              style: const TextStyle(color: AppColors.text, fontSize: 18),
              decoration: InputDecoration(
                labelText: _auction ? '시작 값' : '값',
                suffixText: '금화',
                helperText: '${comma(_min)} ~ ${comma(_max)} 사이',
              ),
            ),
            if (_auction)
              TextField(
                key: const Key('sellBuyNow'),
                controller: _buyNow,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: AppColors.text, fontSize: 18),
                decoration: const InputDecoration(labelText: '바로 사기 값 (고르면)', suffixText: '금화'),
              ),
            const SizedBox(height: 8),
            Text(widget.priceLine, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            Text(
                '올리는 금화 ${comma(c.marketListFee(_p))} · 팔리면 수수료 '
                '${comma(MarketRules.saleFee(_p, best: c.marketBest))}(처음 값 기준)',
                key: const Key('sellFees'),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(height: 12),
            GoldButton(
              key: const Key('sellOk'),
              label: c.marketBusy ? '올리는 중…' : '올리기',
              height: 48,
              fontSize: 18,
              onPressed: !_valid || c.marketBusy
                  ? null
                  : () async {
                      final ok = await c.listOnMarket(o,
                          qty: _qty, auction: _auction, price: _p, buyNow: _auction ? _bn : null);
                      if (context.mounted) Navigator.pop(context, ok);
                    },
            ),
          ],
        ),
      ),
    );
  }
}

/// 묶음 61: 맡기기 · 꺼내기 창 (금화 정하기)
class WalletSheet extends StatefulWidget {
  const WalletSheet({super.key, required this.c, required this.deposit, required this.max});

  final AppController c;
  final bool deposit;
  final int max;

  @override
  State<WalletSheet> createState() => _WalletSheetState();
}

class _WalletSheetState extends State<WalletSheet> {
  final _amount = TextEditingController();

  int get _a => int.tryParse(_amount.text) ?? 0;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final dep = widget.deposit;
    final ok = _a > 0 && _a <= widget.max;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + MediaQuery.viewInsetsOf(context).bottom),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(dep ? '거래 지갑에 맡기기' : '거래 지갑에서 꺼내기', style: AppText.title(18)),
            const SizedBox(height: 6),
            KText(
              dep
                  ? '내 금화 ${comma(c.player.gold)} 중에서 맡겨요. 맡긴 금화는 거래소에서만 쓰고, 언제든 꺼낼 수 있어요.'
                  : '지갑 금화 ${comma(widget.max)} 중에서 꺼내요. 바르칸 이름으로 우편이 와요.',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('walletAmount'),
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.text, fontSize: 18),
              decoration: InputDecoration(labelText: dep ? '맡길 금화' : '꺼낼 금화', suffixText: '금화'),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: [
              for (final v in const [100, 500, 1000, 5000])
                if (v <= widget.max)
                  ActionChip(label: Text(comma(v)), onPressed: () => setState(() => _amount.text = '$v')),
              if (widget.max > 0)
                ActionChip(
                    key: const Key('walletAll'),
                    label: const Text('전부'),
                    onPressed: () => setState(() => _amount.text = '${widget.max}')),
            ]),
            const SizedBox(height: 12),
            GoldButton(
              key: const Key('walletOk'),
              label: c.marketBusy ? '바르칸이 세는 중…' : (dep ? '맡기기' : '꺼내기'),
              height: 48,
              fontSize: 18,
              onPressed: !ok || c.marketBusy
                  ? null
                  : () async {
                      final r = dep ? await c.depositWallet(_a) : await c.withdrawWallet(_a);
                      if (context.mounted) Navigator.pop(context, r);
                    },
            ),
          ],
        ),
        ),
      ),
    );
  }
}
