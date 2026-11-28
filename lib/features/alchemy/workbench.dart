import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/rules/material_tints.dart';
import '../../core/rules/rules.dart';
import '../../data/sound/sfx.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../town/material_view.dart';
import 'alchemy_screen.dart' show ProcessPanel, showBrewResult, PotionIcon;
import 'convert_panel.dart';

/// 묶음 70 #297: 작업대에 무엇을 넣을지 (레시피 「채우기」 → 가마솥에 차례로)
class WorkbenchBus extends ChangeNotifier {
  /// 가마솥 번호 → 아직 끓이지 않고 넣어 둔 재료 (넣은 순서)
  final Map<int, List<MaterialId>> drafts = {};

  /// 묶음 75 #318: 「채우기」로 차례로 떨어뜨릴 재료 (가마솥마다)
  final Map<int, List<MaterialId>> queue = {};

  /// 보여 줄 판 (한 번 쓰면 비움)
  int? goTo;

  /// 지금 보고 있는 판
  int current = 0;

  void fill(int slot, List<MaterialId> put) {
    drafts[slot] = [];
    queue[slot] = [...put];
    goTo = slot;
    notifyListeners();
  }

  /// 옆 판으로 (‹ ›)
  void go(int page) {
    goTo = page;
    notifyListeners();
  }

  void changed() => notifyListeners();
}

/// 묶음 75 #318: 재료 선반 갈래
enum ShelfGroup {
  all('전체'),
  herb('약초·물'),
  mineral('광물'),
  monster('몬스터'),
  special('특산물');

  const ShelfGroup(this.label);
  final String label;

  static const Set<MaterialId> _herbWater = {
    MaterialId.dewHerb,
    MaterialId.riverPearl,
    MaterialId.twig,
    MaterialId.hardWood,
    MaterialId.sturdyKnot,
    MaterialId.herbExtract,
    MaterialId.shadeMushroom,
    MaterialId.poisonMushroom,
    MaterialId.moonMushroom,
    MaterialId.springPetal,
    MaterialId.summerPetal,
    MaterialId.autumnPetal,
    MaterialId.winterPetal,
    MaterialId.sunPollen,
    MaterialId.breezeBloom,
    MaterialId.herbSeed,
    MaterialId.flowerSeed,
    MaterialId.sporeSeed,
    MaterialId.glowSeed,
    MaterialId.sunDew,
    MaterialId.fallsPearl,
    MaterialId.elderBark,
  };

  static const Set<MaterialId> _mineral = {
    MaterialId.ironShard,
    MaterialId.ironIngot,
    MaterialId.manaOre,
    MaterialId.labyrinthStone,
    MaterialId.runeStone,
    MaterialId.roughGem,
    MaterialId.ancientShard,
    MaterialId.relicSeal,
    MaterialId.skyStone,
    MaterialId.cloudCrystal,
    MaterialId.frostCrystal,
    MaterialId.stardust,
    MaterialId.essence,
  };

  static ShelfGroup of(MaterialId m) {
    if (AlchemyRules.isAdditive(m)) return special;
    if (Materials.isHerb(m) || _herbWater.contains(m)) return herb;
    if (_mineral.contains(m) || m.name.startsWith('stone') || m.name.startsWith('gem')) return mineral;
    return monster;
  }
}

/// 묶음 75 #318: 지금 넣은 재료로 만들어질 물약 (아는 레시피로만 맞춤)
class BrewForecast {
  const BrewForecast({this.id, this.quality, this.minutes, this.more = 0, this.next, this.partial = false, this.uses = const {}});

  /// 맞는 레시피 (없으면 null)
  final PotionId? id;
  final PotionQuality? quality;
  final int? minutes;

  /// 레시피 중간: 몇 개 더 · 다음에 넣을 것 (순서를 모르면 null)
  final int more;
  final MaterialId? next;
  final bool partial;

  /// 지금 레시피(들)에 쓰는 재료 — 선반에서 금테
  final Set<MaterialId> uses;

  bool get exact => id != null;
  bool get unknown => id == null && !partial;

  static BrewForecast of(AppController c, List<MaterialId> put) {
    final base = AlchemyRules.asRecipe([for (final x in put) if (!AlchemyRules.isAdditive(x)) x]);
    final known = c.knownRecipes;
    Set<MaterialId> usesOf(Iterable<PotionId> ids) => {
          for (final id in ids)
            for (final m in AlchemyRules.info(id).recipe)
              if (m == MaterialId.herb) ...Materials.herbGroup else m,
          for (final id in ids)
            if (AlchemyRules.specialtyFor(id) case final sp?) sp,
        };
    if (base.isEmpty) return BrewForecast(partial: true, uses: usesOf(known.where(c.hasRecipeMats)));
    final m = AlchemyRules.match(base);
    if (m != null && known.contains(m.id)) {
      final q = AlchemyRules.qualityWith(m.id, perfect: m.perfect, put: put);
      return BrewForecast(id: m.id, quality: q, minutes: c.brewMinutesOf(m.id), uses: usesOf([m.id]));
    }
    // 레시피 중간: 만들어 본 레시피는 순서대로 앞부분이 같아야, 쪽지로만 아는 레시피는 재료 수만
    PotionId? best;
    var bestMore = 99;
    MaterialId? next;
    final cands = <PotionId>[];
    for (final id in known) {
      final rec = AlchemyRules.info(id).recipe;
      if (rec.length <= base.length) continue;
      bool fits;
      if (c.recipeDiscovered(id)) {
        fits = true;
        for (var i = 0; i < base.length; i++) {
          if (rec[i] != base[i]) fits = false;
        }
      } else {
        final left = [...rec];
        fits = base.every(left.remove);
      }
      if (!fits) continue;
      cands.add(id);
      final more = rec.length - base.length;
      if (more < bestMore) {
        bestMore = more;
        best = id;
        next = c.recipeDiscovered(id) ? rec[base.length] : null;
      }
    }
    if (best == null) return const BrewForecast();
    return BrewForecast(partial: true, more: bestMore, next: next, uses: usesOf(cands));
  }
}

/// 가마솥 그림의 물 높이 (그림 높이 비율, 묶음 72 큰 가마솥 그림)
const double _mouthY = 0.17;

/// 재료 그림의 대표 색 (그림이 없으면 이름으로 정한 색)
Color materialTint(MaterialId m) {
  final asset = Materials.info(m).asset;
  final name = asset.substring(asset.lastIndexOf('/') + 1, asset.length - 5);
  final v = kMaterialTint[name];
  if (v != null) return Color(v);
  final h = (m.name.hashCode % 360).abs().toDouble();
  return HSVColor.fromAHSV(1, h, 0.6, 0.9).toColor();
}

/// 넣은 재료로 섞인 물 색 (아무것도 없으면 맑은 물)
Color brewTint(List<MaterialId> put) {
  const water = Color(0xFF4FB7D6);
  if (put.isEmpty) return water;
  double r = 0, g = 0, b = 0;
  for (final m in put) {
    final c = materialTint(m);
    r += c.r;
    g += c.g;
    b += c.b;
  }
  final n = put.length;
  final mix = Color.from(alpha: 1, red: r / n, green: g / n, blue: b / n);
  return Color.lerp(water, mix, math.min(0.85, 0.45 + n * 0.1))!;
}

/// 작업대: 가마솥 1..n → 증류기(가공) → 변환 제단(변환) → 「가마솥 하나 더」. 옆으로 넘긴다
class AlchemyWorkbench extends StatefulWidget {
  const AlchemyWorkbench({super.key, required this.controller, required this.bus});

  final AppController controller;
  final WorkbenchBus bus;

  @override
  State<AlchemyWorkbench> createState() => _AlchemyWorkbenchState();
}

class _AlchemyWorkbenchState extends State<AlchemyWorkbench> {
  AppController get c => widget.controller;
  late int _page = _firstPage();
  late final PageController _pages = PageController(initialPage: _page);

  /// 다 끓은 가마솥부터
  int _firstPage() {
    final go = widget.bus.goTo;
    if (go != null) {
      widget.bus.goTo = null;
      return go;
    }
    for (var i = 0; i < c.cauldronCount; i++) {
      if (c.brewReady(i)) return i;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    widget.bus.addListener(_onBus);
  }

  @override
  void dispose() {
    widget.bus.removeListener(_onBus);
    _pages.dispose();
    super.dispose();
  }

  void _onBus() {
    final go = widget.bus.goTo;
    if (go != null && _pages.hasClients) {
      widget.bus.goTo = null;
      _pages.animateToPage(go, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    if (mounted) setState(() {});
  }

  int get _count => c.cauldronCount + 2 + (c.cauldronGold != null ? 1 : 0);

  String _label(int i) {
    final n = c.cauldronCount;
    if (i < n) {
      final b = c.alchemy.brews[i];
      if (b == null) return '가마솥 ${i + 1} · 비어 있어요';
      if (c.brewReady(i)) return '가마솥 ${i + 1} · 다 끓었어요!';
      final left = b.readyAt.difference(c.now);
      final t = left.inMinutes >= 60
          ? '${left.inHours}시간 ${left.inMinutes % 60}분'
          : '${left.inMinutes + 1}분';
      return '가마솥 ${i + 1} · 끓는 중 $t 남음';
    }
    if (i == n) return '증류기 · 가공';
    if (i == n + 1) return '변환 제단 · 변환';
    return '가마솥 하나 더';
  }

  @override
  Widget build(BuildContext context) {
    final n = c.cauldronCount;
    final count = _count;
    if (_page >= count) _page = count - 1;
    widget.bus.current = _page;
    // 묶음 75 #318: 이름 띠는 판마다 (가마솥은 솥 아래 「가마솥 1 / 3」 + 점, 좌우 ‹ ›)
    return PageView(
      key: const Key('benchPages'),
      controller: _pages,
      onPageChanged: (i) => setState(() {
        _page = i;
        widget.bus.current = i;
      }),
      children: [
        for (var i = 0; i < n; i++)
          _CauldronPage(key: Key('cauldronPage_$i'), controller: c, slot: i, bus: widget.bus, pages: count),
        _StationPage(
          bus: widget.bus,
          page: n,
          pages: count,
          label: _label(n),
          art: 'alchemy_still',
          fallback: 'icon_alchemy',
          child: ProcessPanel(controller: c),
        ),
        _StationPage(
          bus: widget.bus,
          page: n + 1,
          pages: count,
          label: _label(n + 1),
          art: 'alchemy_altar',
          fallback: 'icon_convert_table',
          child: ConvertPanel(controller: c),
        ),
        if (c.cauldronGold != null)
          _StationPage(
            bus: widget.bus,
            page: n + 2,
            pages: count,
            label: _label(n + 2),
            art: 'alchemy_cauldron',
            fallback: 'icon_alchemy',
            dim: true,
            child: _BuyPage(controller: c),
          ),
      ],
    );
  }
}

/// 판 머리: ‹ 이름 › (증류기 · 변환 제단 · 가마솥 하나 더)
class _PageHead extends StatelessWidget {
  const _PageHead({required this.bus, required this.page, required this.pages, required this.label});

  final WorkbenchBus bus;
  final int page;
  final int pages;
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        _Arrow(key: const Key('benchPrev'), left: true, onTap: page > 0 ? () => bus.go(page - 1) : null),
        Expanded(
          child: Text(label,
              key: const Key('benchLabel'), textAlign: TextAlign.center, style: AppText.title(16, color: AppColors.goldBright)),
        ),
        _Arrow(key: const Key('benchNext'), left: false, onTap: page < pages - 1 ? () => bus.go(page + 1) : null),
      ]);
}

/// 둥근 ‹ › 단추 (누르는 칸 44)
class _Arrow extends StatelessWidget {
  const _Arrow({super.key, required this.left, this.onTap});

  final bool left;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          onPressed: onTap,
          style: IconButton.styleFrom(backgroundColor: const Color(0x990B0D26)),
          icon: Icon(left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              color: onTap == null ? AppColors.textMuted.withValues(alpha: 0.4) : AppColors.goldBright),
        ),
      );
}

/// 그림이 있으면 그 그림, 없으면 대신 그림
Widget _art(String name, String fallback, double size) => Image.asset(
      'assets/images/$name.webp',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Image.asset('assets/images/$fallback.webp',
          width: size,
          height: size,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.science_rounded, size: size * 0.6, color: AppColors.goldBright)),
    );

class _StationPage extends StatelessWidget {
  const _StationPage({
    required this.bus,
    required this.page,
    required this.pages,
    required this.label,
    required this.art,
    required this.fallback,
    required this.child,
    this.dim = false,
  });

  final WorkbenchBus bus;
  final int page;
  final int pages;
  final String label;
  final String art;
  final String fallback;
  final Widget child;
  final bool dim;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          children: [
            _PageHead(bus: bus, page: page, pages: pages, label: label),
            const SizedBox(height: 4),
            Center(
                child: Opacity(
                    opacity: dim ? 0.45 : 1, child: _art(art, fallback, math.min(box.maxWidth * 0.5, 170)))),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
}

class _BuyPage extends StatelessWidget {
  const _BuyPage({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final gold = c.cauldronGold!;
    return FrameButton(
      key: const Key('buyCauldron'),
      label: '가마솥 하나 더 · 금화 ${comma(gold)}'
          '${c.cauldronStone > 0 ? ' + 미궁 석재 ${c.cauldronStone}' : ''}',
      gameIcon: 'gold',
      height: 46,
      onPressed: () async {
        final ok = await c.buyCauldron();
        if (!context.mounted) return;
        showTopNotice(context, ok ? '가마솥이 하나 늘었어요!' : '금화나 재료가 모자라요.');
      },
    );
  }
}

/// 넣는 중인 재료 하나 (포물선으로 떨어짐)
class _Drop {
  _Drop(this.m, this.from);
  final MaterialId m;
  final Offset from;
  double t = 0;
}

/// 가마솥 한 칸 (묶음 75 #318 B안: 가마솥 크게)
class _CauldronPage extends StatefulWidget {
  const _CauldronPage(
      {super.key, required this.controller, required this.slot, required this.bus, required this.pages});

  final AppController controller;
  final int slot;
  final WorkbenchBus bus;

  /// 판 수 (가마솥 + 증류기 · 변환 제단 …)
  final int pages;

  @override
  State<_CauldronPage> createState() => _CauldronPageState();
}

class _CauldronPageState extends State<_CauldronPage> with TickerProviderStateMixin {
  AppController get c => widget.controller;
  List<MaterialId> get _put => widget.bus.drafts[widget.slot] ??= [];

  /// 거품 · 불 · 반짝임 · 떠 있는 재료 흔들림
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

  /// 시험(pumpAndSettle)에서는 늘 도는 움직임을 멈춘다
  static bool disabledForTests = const bool.fromEnvironment('FLUTTER_TEST') ||
      (() {
        try {
          return Platform.environment.containsKey('FLUTTER_TEST');
        } catch (_) {
          return false;
        }
      })();

  void _syncLoop(bool on) {
    on = on && !disabledForTests && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
    if (on && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!on && _loop.isAnimating) {
      _loop.stop();
    }
  }

  final List<_Drop> _drops = [];

  /// 첨벙 (재료 색, 시작 시각)
  final List<(Color, double)> _splashes = [];
  late final AnimationController _fx =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
        ..addListener(_tick);
  double _fxLast = 0;

  /// 물 색 (바뀔 때 부드럽게)
  Color _liquid = _empty;
  Color _liquidFrom = _empty;
  double _liquidT = 1;

  /// 빈 가마솥: 물 없이 어둡게
  static const Color _empty = Color(0xFF1C1626);

  bool _busy = false;
  bool _filling = false;
  int _fillRun = 0;

  @override
  void initState() {
    super.initState();
    _liquid = _liquidFrom = _waterOf(_put);
    widget.bus.addListener(_onBus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onBus());
  }

  @override
  void dispose() {
    widget.bus.removeListener(_onBus);
    _loop.dispose();
    _fx.dispose();
    super.dispose();
  }

  /// 「채우기」: ① → ⑤ 순서대로 하나씩 떨어짐
  void _onBus() {
    final q = widget.bus.queue.remove(widget.slot);
    if (q == null || !mounted) return;
    final run = ++_fillRun;
    setState(() {
      _put.clear();
      _filling = true;
      _liquidFrom = _liquid = _waterOf(_put);
    });
    () async {
      for (final m in q) {
        await Future<void>.delayed(const Duration(milliseconds: 160));
        if (!mounted || run != _fillRun) return;
        _add(m);
      }
      if (mounted && run == _fillRun) setState(() => _filling = false);
    }();
  }

  /// 물 색: 비면 어둡게, 맞는 레시피면 그 물약 색, 아니면 재료 색을 섞은 색
  Color _waterOf(List<MaterialId> put) {
    if (put.isEmpty) return _empty;
    final f = BrewForecast.of(c, put);
    if (f.id != null) return Color.lerp(PotionIcon.colorOf(f.id), Colors.white, 0.12)!;
    return brewTint(put);
  }

  void _tick() {
    final v = _fx.value;
    final dt = (v - _fxLast).clamp(0.0, 1.0) * 1.4; // 초
    _fxLast = v;
    setState(() {
      for (final d in _drops) {
        d.t += dt / 0.45;
      }
      final landed = _drops.where((d) => d.t >= 1).toList();
      for (final d in landed) {
        _drops.remove(d);
        _land(d.m);
      }
      for (var i = 0; i < _splashes.length; i++) {
        _splashes[i] = (_splashes[i].$1, _splashes[i].$2 + dt / 0.5);
      }
      _splashes.removeWhere((s) => s.$2 >= 1);
      if (_liquidT < 1) _liquidT = math.min(1, _liquidT + dt / 0.5);
    });
    if (_drops.isEmpty && _splashes.isEmpty && _liquidT >= 1) {
      _fx.stop();
    }
  }

  void _kickFx() {
    if (!_fx.isAnimating || _fx.value > 0.6) {
      _fxLast = 0;
      _fx.forward(from: 0);
    }
  }

  void _recolor() {
    _liquidFrom = Color.lerp(_liquidFrom, _liquid, _liquidT)!;
    _liquid = _waterOf(_put);
    _liquidT = 0;
  }

  void _land(MaterialId m) {
    _splashes.add((materialTint(m), 0));
    _recolor();
    if (c.sound) Sfx.play(SfxKind.pong, volume: 0.7);
    if (c.vibrate) HapticFeedback.lightImpact();
  }

  int _left(MaterialId m) => c.player.materialCount(m) - _put.where((x) => x == m).length;

  bool _canAdd(MaterialId m) {
    if (_left(m) <= 0) return false;
    if (AlchemyRules.isAdditive(m)) return !_put.any(AlchemyRules.isAdditive);
    return _put.where((x) => !AlchemyRules.isAdditive(x)).length < AlchemyRules.maxIngredients;
  }

  /// 재료를 넣는다 (선반 아래에서 솥으로 떨어짐)
  void _add(MaterialId m) {
    if (!_canAdd(m)) return;
    setState(() {
      _put.add(m);
      _drops.add(_Drop(m, const Offset(0.5, 1.3)));
    });
    widget.bus.changed();
    _kickFx();
  }

  /// [i] 번째 재료를 뺀다 (뒤 재료가 한 칸씩 당겨짐)
  void _removeAt(int i) {
    if (i < 0 || i >= _put.length) return;
    setState(() {
      _put.removeAt(i);
      _recolor();
    });
    widget.bus.changed();
    _kickFx();
  }

  void _removeLast() => _removeAt(_put.length - 1);

  Future<void> _boil({bool unknown = false}) async {
    if (_put.isEmpty || _busy) return;
    if (unknown) {
      final go = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          backgroundColor: AppColors.night,
          title: Text('모르는 조합이에요', style: AppText.title(18)),
          content: const KText('어떤 물약이 나올지 몰라요. 그래도 끓일까요?',
              style: TextStyle(color: AppColors.text, fontSize: 14)),
          actions: [
            TextButton(key: const Key('unknownBrewNo'), onPressed: () => Navigator.pop(d, false), child: const Text('그만두기')),
            TextButton(key: const Key('unknownBrewYes'), onPressed: () => Navigator.pop(d, true), child: const Text('그래도 끓이기')),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    setState(() => _busy = true);
    final ok = await c.startBrew(widget.slot, [..._put]);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) _put.clear();
    });
    widget.bus.changed();
    if (!ok) showTopNotice(context, '끓이지 못했어요.');
  }

  Future<void> _collect() async {
    if (_busy) return;
    setState(() => _busy = true);
    final r = await c.collectBrew(widget.slot);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _liquid = _liquidFrom = _empty;
    });
    if (r != null) await showBrewResult(context, c, r);
  }

  /// 다음 빈 가마솥 (없으면 null)
  int? get _nextEmpty {
    final n = c.cauldronCount;
    for (var k = 1; k < n; k++) {
      final i = (widget.slot + k) % n;
      if (c.alchemy.brews[i] == null) return i;
    }
    return null;
  }

  static String _min(int m) => m >= 60 ? '${m ~/ 60}시간${m % 60 > 0 ? ' ${m % 60}분' : ''}' : '$m분';

  @override
  Widget build(BuildContext context) {
    final brew = c.alchemy.brews[widget.slot];
    final ready = c.brewReady(widget.slot);
    final idle = brew == null;
    final n = c.cauldronCount;
    final forecast = idle ? BrewForecast.of(c, _put) : null;
    _syncLoop(brew != null || _put.isNotEmpty || (forecast?.exact ?? false));
    final brewPut = brew == null
        ? const <MaterialId>[]
        : [for (final n in brew.put) if (Materials.byName(n) case final m?) m];
    return LayoutBuilder(builder: (context, box) {
      final pot = math.max(150.0, box.maxWidth * 0.72);
      final liquid = brew == null
          ? Color.lerp(_liquidFrom, _liquid, Curves.easeOut.transform(_liquidT))!
          : (BrewForecast.of(c, brewPut).id != null
              ? Color.lerp(PotionIcon.colorOf(BrewForecast.of(c, brewPut).id), Colors.white, 0.12)!
              : brewTint(brewPut));
      final pct = brew == null
          ? 0.0
          : () {
              final total = brew.readyAt.difference(brew.startedAt).inSeconds;
              final done = c.now.difference(brew.startedAt).inSeconds;
              return total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);
            }();
      final floating = idle ? _put : brewPut;
      final potArea = GestureDetector(
        onTap: ready ? _collect : null,
        child: SizedBox(
          key: const Key('cauldronPot'),
          width: pot,
          height: pot,
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, _) => Stack(clipBehavior: Clip.none, children: [
              // 끓는 동안 아래 불빛
              if (brew != null && !ready)
                Positioned.fill(
                  child: CustomPaint(painter: _FirePainter(t: _loop.value, big: true, ready: ready)),
                ),
              Positioned.fill(
                  child: Image.asset('assets/images/alchemy_cauldron.webp',
                      key: const Key('cauldronArt'),
                      errorBuilder: (_, __, ___) => Image.asset('assets/images/alchemy_cauldron_base.webp'))),
              Positioned.fill(
                child: ColorFiltered(
                  key: Key(floating.isEmpty && idle ? 'cauldronEmpty' : 'cauldronWater'),
                  colorFilter: ColorFilter.mode(liquid, BlendMode.modulate),
                  child: Image.asset('assets/images/alchemy_brew.webp',
                      key: const Key('cauldronLiquid'), errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
              for (final (color, p) in _splashes)
                Positioned(
                  left: pot * (0.5 - 0.22 * (0.7 + p * 0.5)),
                  top: pot * (_mouthY - 0.3 * (0.7 + p * 0.5)),
                  width: pot * 0.44 * (0.7 + p * 0.5),
                  height: pot * 0.44 * (0.7 + p * 0.5),
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: (1 - p).clamp(0.0, 1.0),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(color, BlendMode.modulate),
                        child: Image.asset('assets/images/fx_splash.webp',
                            key: const Key('fxSplash'), errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BrewFx(
                      t: _loop.value,
                      liquid: liquid,
                      boiling: brew != null && !ready,
                      splashes: [..._splashes],
                      glow: idle && (forecast?.exact ?? false),
                      hover: false,
                      empty: idle && _put.isEmpty,
                    ),
                  ),
                ),
              ),
              // 넣은 재료가 물 위에 순서대로 둥둥 (누르면 빠짐)
              for (final (i, m) in floating.indexed)
                () {
                  final k = floating.length;
                  final s = pot * 0.13;
                  final span = pot * 0.46;
                  final x = pot * 0.5 + (k == 1 ? 0 : (i / (k - 1) - 0.5) * span) - s / 2;
                  final bob = math.sin((_loop.value + i * 0.23) * math.pi * 2);
                  final y = pot * _mouthY - s * 0.62 + bob * pot * 0.008 + ((i % 2) * pot * 0.018);
                  final special = AlchemyRules.isAdditive(m);
                  return Positioned(
                    key: Key('float_$i'),
                    left: x,
                    top: y,
                    width: s,
                    height: s,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: idle && !_filling ? () => _removeAt(i) : null,
                      child: Transform.rotate(
                        angle: bob * 0.08,
                        child: Container(
                          decoration: special
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.goldBright, width: 2),
                                  boxShadow: const [BoxShadow(color: Color(0x99FFD86B), blurRadius: 6)],
                                )
                              : null,
                          child: MaterialIcon(m, size: s),
                        ),
                      ),
                    ),
                  );
                }(),
              for (final d in _drops)
                () {
                  final t = Curves.easeIn.transform(d.t.clamp(0.0, 1.0));
                  final x = d.from.dx + (0.5 - d.from.dx) * t;
                  final y0 = d.from.dy, y1 = _mouthY;
                  final y = y0 + (y1 - y0) * t - math.sin(t * math.pi) * 0.35;
                  final s = pot * 0.16 * (1 - t * 0.3);
                  return Positioned(
                    left: x * pot - s / 2,
                    top: y * pot - s / 2,
                    child: IgnorePointer(
                        child: Transform.rotate(angle: t * 2.4, child: MaterialIcon(d.m, size: s))),
                  );
                }(),
              if (ready)
                Positioned(
                  left: pot * 0.5 - pot * 0.14,
                  top: pot * (_mouthY - 0.16 - 0.04 * math.sin(_loop.value * 2 * math.pi)),
                  child: Container(
                    key: const Key('brewRise'),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Color(0xAAFFE38A), blurRadius: 18, spreadRadius: 2)],
                    ),
                    // 묶음 86 #430: 다 끓으면 그 물약 그림 (그림이 없는 물약만 아이콘)
                    child: switch (BrewForecast.of(c, brewPut)) {
                      final f when f.exact && f.id != null => PotionIcon(potion: f.id, size: pot * 0.3),
                      _ => Icon(Icons.science_rounded, size: pot * 0.26, color: Color.lerp(liquid, Colors.white, 0.25)),
                    },
                  ),
                ),
              if (brew != null && !ready)
                Positioned(
                  right: 0,
                  top: pot * 0.04,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        key: const Key('brewRing'),
                        value: pct,
                        strokeWidth: 4,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(AppColors.goldBright),
                      ),
                      Text(() {
                        final left = brew.readyAt.difference(c.now);
                        return left.inMinutes >= 60 ? '${left.inHours}h' : '${left.inMinutes + 1}분';
                      }(),
                          style: const TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      );
      final page = widget.slot;
      final next = _nextEmpty;
      return ListView(
        key: Key('cauldronScroll_${widget.slot}'),
        padding: EdgeInsets.zero,
        children: [
          // 「만들어질 물약」 띠
          _ForecastBand(
            controller: c,
            forecast: idle ? forecast! : BrewForecast.of(c, brewPut),
            empty: idle && _put.isEmpty,
            boiling: !idle,
          ),
          const SizedBox(height: 4),
          // ‹ 가마솥 ›
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _Arrow(
                key: const Key('benchPrev'),
                left: true,
                onTap: page > 0 ? () => widget.bus.go(page - 1) : null),
            Expanded(child: Center(child: potArea)),
            _Arrow(
                key: const Key('benchNext'),
                left: false,
                onTap: page < widget.pages - 1 ? () => widget.bus.go(page + 1) : null),
          ]),
          // 「가마솥 1 / 3」 + 점 (끓는 가마솥은 금빛)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 6),
            child: Column(children: [
              Text('가마솥 ${page + 1} / $n',
                  key: const Key('benchLabel'), style: AppText.title(14, color: AppColors.goldBright)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < n; i++)
                  GestureDetector(
                    onTap: () => widget.bus.go(i),
                    child: Container(
                      key: Key('benchDot_$i'),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == page ? 16 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: c.alchemy.brews[i] != null
                            ? AppColors.goldBright
                            : i == page
                                ? AppColors.gold
                                : AppColors.gold.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: c.alchemy.brews[i] != null
                            ? const [BoxShadow(color: Color(0xCCFFD86B), blurRadius: 6)]
                            : null,
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          if (ready)
            GoldButton(
              key: Key('brewCollect_${widget.slot}'),
              label: '눌러서 받기',
              height: 42,
              fontSize: 15,
              onPressed: _busy ? null : _collect,
            ),
          // ①~⑤ + ✦ (누르면 빠짐)
          _Slots(put: idle ? _put : brewPut, glow: idle && (forecast?.exact ?? false), onRemove: idle ? _removeAt : null),
          if (idle) ...[
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: KText('① → ⑤ 순서대로 · 칸이나 솥 위 재료를 누르면 빠져요',
                  key: Key('brewGuide'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
            ),
            const SizedBox(height: 6),
            Row(children: [
              SizedBox(
                width: 92,
                child: FrameButton(
                  key: Key('brewUndo_${widget.slot}'),
                  label: '빼기',
                  height: 44,
                  onPressed: _put.isEmpty || _filling ? null : _removeLast,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: forecast!.unknown && _put.isNotEmpty
                    ? FrameButton(
                        key: Key('brewBoil_${widget.slot}'),
                        label: '모르는 조합이에요 · 그래도 끓이기',
                        height: 44,
                        onPressed: _busy || _filling ? null : () => _boil(unknown: true),
                      )
                    : GoldButton(
                        key: Key('brewBoil_${widget.slot}'),
                        label: forecast.exact ? '끓이기 · ${_min(forecast.minutes!)}' : '끓이기',
                        height: 44,
                        fontSize: 16,
                        onPressed: forecast.exact && !_busy && !_filling ? () => _boil() : null,
                      ),
              ),
            ]),
            const SizedBox(height: 8),
            _Shelf(
              controller: c,
              left: _left,
              canAdd: _canAdd,
              uses: forecast.uses,
              onTap: _filling ? (_) {} : _add,
            ),
          ] else if (!ready && next != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: FrameButton(
                key: const Key('brewNextEmpty'),
                label: '빈 가마솥으로 (${next + 1} / $n) ›',
                height: 44,
                onPressed: () => widget.bus.go(next),
              ),
            ),
          const SizedBox(height: 8),
        ],
      );
    });
  }
}

/// 가마솥 위 띠 「만들어질 물약」: 그림 · 이름 · 품질 · 시간 / 「○개 더 · 다음에 넣을 것」 / 「? 모르는 조합」
class _ForecastBand extends StatelessWidget {
  const _ForecastBand({required this.controller, required this.forecast, required this.empty, required this.boiling});

  final AppController controller;
  final BrewForecast forecast;
  final bool empty;
  final bool boiling;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    Widget icon;
    String title;
    String sub;
    if (empty) {
      icon = const Icon(Icons.science_outlined, color: AppColors.textMuted, size: 30);
      title = '빈 가마솥';
      sub = '재료를 넣거나 오른쪽 위 「레시피」에서 채워 보세요';
    } else if (f.exact) {
      icon = PotionIcon(potion: f.id, size: 40);
      title = AlchemyRules.info(f.id!).name;
      sub = '품질 ${f.quality!.label == '좋음' ? '상' : f.quality!.label} · ${_CauldronPageState._min(f.minutes!)}';
    } else if (f.partial) {
      icon = Stack(alignment: Alignment.center, children: [
        const Opacity(opacity: 0.35, child: PotionIcon(size: 40, suspicious: true)),
        Text('${f.more}', style: AppText.title(16, color: AppColors.goldBright)),
      ]);
      title = '${f.more}개 더';
      sub = f.next == null ? '레시피 중간이에요' : '다음에 넣을 것: ${Materials.needName(f.next!)}';
    } else {
      icon = Text('?', style: AppText.title(28, color: AppColors.textMuted));
      title = '?';
      sub = '모르는 조합';
    }
    return Container(
      key: Key(empty
          ? 'forecastEmpty'
          : f.exact
              ? 'forecast_${f.id!.name}'
              : f.partial
                  ? 'forecastPartial'
                  : 'forecastUnknown'),
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: const Color(0xCC12142E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: f.exact ? AppColors.goldBright : AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        SizedBox(width: 44, height: 44, child: Center(child: icon)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(boiling ? '끓이는 물약' : '만들어질 물약',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w700)),
            Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: f.exact ? AppColors.goldBright : AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
            KText(sub,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
          ]),
        ),
      ]),
    );
  }
}

/// 넣은 재료 칸 ①~⑤ + ✦ (넣은 순서). 칸을 누르면 그 재료가 빠짐
class _Slots extends StatelessWidget {
  const _Slots({required this.put, required this.glow, this.onRemove});

  final List<MaterialId> put;
  final bool glow;

  /// put 의 몇 번째를 뺄지 (끓는 중이면 null)
  final ValueChanged<int>? onRemove;

  static const _nums = ['①', '②', '③', '④', '⑤'];

  @override
  Widget build(BuildContext context) {
    final base = [for (final (i, m) in put.indexed) if (!AlchemyRules.isAdditive(m)) (i, m)];
    final add = [for (final (i, m) in put.indexed) if (AlchemyRules.isAdditive(m)) (i, m)].firstOrNull;
    Widget cell((int, MaterialId)? at, String mark, int k, {bool special = false}) => Expanded(
          child: GestureDetector(
            key: Key(special ? 'brewSlotAdd' : 'brewSlot_$k'),
            onTap: at == null || onRemove == null ? null : () => onRemove!(at.$1),
            child: Container(
              height: 44,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: AppColors.slotBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: glow || (special && at != null)
                        ? AppColors.goldBright
                        : special
                            ? AppColors.gold.withValues(alpha: 0.6)
                            : AppColors.gold.withValues(alpha: 0.35),
                    width: glow ? 1.6 : 1),
                boxShadow: glow ? const [BoxShadow(color: Color(0x88FFD86B), blurRadius: 8)] : null,
              ),
              child: Stack(children: [
                if (at != null) Center(child: MaterialIcon(at.$2, size: 32)),
                Positioned(
                  left: 3,
                  top: 1,
                  child: Text(mark,
                      style: TextStyle(
                          color: special ? AppColors.goldBright : AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ),
        );
    return Row(key: const Key('brewSlots'), children: [
      for (var i = 0; i < AlchemyRules.maxIngredients; i++) cell(i < base.length ? base[i] : null, _nums[i], i),
      cell(add, '✦', 5, special: true),
    ]);
  }
}

/// 재료 선반 (묶음 75 #318): 갈래 탭 + 4칸 격자 (그림 · 이름 · ×개수), 2줄 반 보이고 내림.
/// 지금 레시피에 쓰는 재료는 금테, 남은 게 0이면 흐리게. 누르면 하나 더 들어감
class _Shelf extends StatefulWidget {
  const _Shelf(
      {required this.controller, required this.left, required this.canAdd, required this.uses, required this.onTap});

  final AppController controller;
  final int Function(MaterialId) left;
  final bool Function(MaterialId) canAdd;
  final Set<MaterialId> uses;
  final ValueChanged<MaterialId> onTap;

  @override
  State<_Shelf> createState() => _ShelfState();
}

class _ShelfState extends State<_Shelf> {
  ShelfGroup _group = ShelfGroup.all;

  @override
  Widget build(BuildContext context) {
    final have = widget.controller.player.materials;
    // 지금 레시피에 쓰는 재료가 앞으로
    final mats = [
      for (final used in [true, false])
        for (final m in Materials.displayOrder)
          if ((have[m] ?? 0) > 0 &&
              (_group == ShelfGroup.all || ShelfGroup.of(m) == _group) &&
              widget.uses.contains(m) == used)
            m,
    ];
    final groups = [
      ShelfGroup.all,
      for (final g in ShelfGroup.values.skip(1))
        if (have.entries.any((e) => e.value > 0 && ShelfGroup.of(e.key) == g)) g,
    ];
    return Container(
      key: const Key('brewShelf'),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xAA1E140C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8C6A42)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 32,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  key: Key('shelfGroup_${g.name}'),
                  label: Text(g.label),
                  selected: _group == g,
                  onSelected: (_) => setState(() => _group = g),
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.chipBg,
                  labelStyle: TextStyle(
                      color: _group == g ? AppColors.night : AppColors.text, fontWeight: FontWeight.w700, fontSize: 12),
                  visualDensity: VisualDensity.compact,
                  showCheckmark: false,
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        if (mats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(14),
            child: KText('가방에 재료가 없어요.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          )
        else
          LayoutBuilder(builder: (context, box) {
            final tileW = (box.maxWidth - 3 * 6) / 4;
            final tileH = tileW + 22;
            return SizedBox(
              height: tileH * 2.5 + 6 * 2,
              child: GridView.builder(
                key: const Key('shelfGrid'),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: tileW / tileH,
                ),
                itemCount: mats.length,
                itemBuilder: (context, i) {
                  final m = mats[i];
                  final left = widget.left(m);
                  final ok = widget.canAdd(m);
                  final used = widget.uses.contains(m);
                  return GestureDetector(
                    key: Key('shelf_${m.name}'),
                    onTap: ok ? () => widget.onTap(m) : null,
                    child: Opacity(
                      opacity: left <= 0 ? 0.35 : ok ? 1 : 0.6,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF3A2A1A), Color(0xFF24180E)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: used ? AppColors.goldBright : const Color(0xFF8C6A42), width: used ? 2 : 1),
                          boxShadow: used ? const [BoxShadow(color: Color(0x66FFD86B), blurRadius: 6)] : null,
                        ),
                        padding: const EdgeInsets.fromLTRB(2, 4, 2, 3),
                        child: Column(children: [
                          Expanded(child: Center(child: MaterialIcon(m, size: tileW * 0.6))),
                          Text(Materials.info(m).name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.text, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          Text('×$left',
                              key: Key('shelfCount_${m.name}'),
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            );
          }),
      ]),
    );
  }
}

/// 가마솥 아래 불
class _FirePainter extends CustomPainter {
  _FirePainter({required this.t, required this.big, required this.ready});

  final double t;
  final bool big;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cy = size.height * 0.93;
    final n = big ? 7 : 4;
    final h = w * (big ? 0.2 : 0.08);
    for (var i = 0; i < n; i++) {
      final f = (i + 0.5) / n;
      final x = w * (0.32 + f * 0.36);
      final ph = t * 2 * math.pi * 2 + i * 1.3;
      final hh = h * (0.7 + 0.3 * math.sin(ph));
      final path = Path()
        ..moveTo(x - w * 0.035, cy)
        ..quadraticBezierTo(x - w * 0.03, cy - hh * 0.5, x + math.sin(ph) * w * 0.01, cy - hh)
        ..quadraticBezierTo(x + w * 0.03, cy - hh * 0.5, x + w * 0.035, cy)
        ..close();
      canvas.drawPath(
          path,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: big
                  ? const [Color(0xFFFFE07A), Color(0xFFFF7A2A), Color(0x00FF3D00)]
                  : const [Color(0xCCFFC46B), Color(0x88FF7A2A), Color(0x00FF3D00)],
            ).createShader(Rect.fromLTWH(x - w * 0.04, cy - hh, w * 0.08, hh))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  @override
  bool shouldRepaint(_FirePainter old) => old.t != t || old.big != big || old.ready != ready;
}

/// 거품 · 첨벙 · 맞는 순서 반짝임
class _BrewFx extends CustomPainter {
  _BrewFx({
    required this.t,
    required this.liquid,
    required this.boiling,
    required this.splashes,
    required this.glow,
    required this.hover,
    this.empty = false,
  });

  /// 빈 가마솥 (거품 없음)
  final bool empty;

  final double t;
  final Color liquid;
  final bool boiling;
  final List<(Color, double)> splashes;
  final bool glow;
  final bool hover;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final mouth = Offset(w * 0.5, w * _mouthY);
    // 끓는 동안 김 (위로 피어오름)
    if (boiling) {
      for (var i = 0; i < 5; i++) {
        final ph = (t * 0.8 + i / 5) % 1;
        final x = mouth.dx + w * 0.16 * math.sin(i * 1.9 + ph * 3);
        final y = mouth.dy - w * 0.08 - ph * w * 0.32;
        canvas.drawCircle(
            Offset(x, y),
            w * (0.04 + ph * 0.05),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.22 * (1 - ph))
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
    }
    // 거품 (끓는 중이면 많이 · 높이, 빈 가마솥은 없음)
    final bubbles = empty ? 0 : boiling ? 9 : 3;
    for (var i = 0; i < bubbles; i++) {
      final ph = (t * (boiling ? 2 : 1) + i / bubbles) % 1;
      final x = mouth.dx + w * 0.18 * math.sin(i * 2.7);
      final y = mouth.dy - ph * w * (boiling ? 0.16 : 0.05);
      final r = w * (boiling ? 0.022 : 0.014) * (1 - ph * 0.4);
      final a = (1 - ph);
      canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = Color.lerp(liquid, Colors.white, 0.45)!.withValues(alpha: a * 0.85));
      canvas.drawCircle(
          Offset(x - r * 0.3, y - r * 0.3),
          r * 0.3,
          Paint()..color = Colors.white.withValues(alpha: a * 0.7));
    }
    // 첨벙: 재료 색 방울이 위로 튀었다 떨어짐
    for (final (color, p) in splashes) {
      for (var i = 0; i < 10; i++) {
        final ang = -math.pi / 2 + (i - 4.5) * 0.28;
        final sp = w * (0.13 + (i % 3) * 0.04);
        final x = mouth.dx + math.cos(ang) * sp * p;
        final y = mouth.dy + math.sin(ang) * sp * p * 1.4 + p * p * w * 0.18;
        canvas.drawCircle(Offset(x, y), w * 0.016 * (1 - p * 0.6),
            Paint()..color = color.withValues(alpha: 1 - p));
      }
      canvas.drawOval(
          Rect.fromCenter(center: mouth, width: w * 0.3 * (0.6 + p), height: w * 0.06 * (0.6 + p)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: 0.6 * (1 - p)));
    }
    // 만들어 본 레시피 순서 그대로면 금빛 반짝임
    if (glow) {
      for (var i = 0; i < 6; i++) {
        final ph = (t + i / 6) % 1;
        final x = mouth.dx + w * 0.3 * math.cos(i * 1.05 + t * 2);
        final y = mouth.dy - w * 0.05 - ph * w * 0.2;
        _star(canvas, Offset(x, y), w * 0.03 * (1 - ph), const Color(0xFFFFE38A).withValues(alpha: 1 - ph));
      }
    }
    if (hover) {
      canvas.drawOval(
          Rect.fromCenter(center: mouth, width: w * 0.55, height: w * 0.14),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xAAFFE38A));
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final rr = i.isEven ? r : r * 0.35;
      final a = i * math.pi / 4;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BrewFx old) => true;
}
