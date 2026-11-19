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
import 'alchemy_screen.dart' show ProcessPanel, showBrewResult;
import 'convert_panel.dart';

/// 묶음 70 #297: 작업대에 무엇을 넣을지 (레시피 상세 「가마솥에 넣기」 → 빈 가마솥 쪽으로)
class WorkbenchBus extends ChangeNotifier {
  /// 가마솥 번호 → 아직 끓이지 않고 넣어 둔 재료 (넣은 순서)
  final Map<int, List<MaterialId>> drafts = {};

  /// 보여 줄 가마솥 (한 번 쓰면 비움)
  int? goTo;

  void fill(int slot, List<MaterialId> put) {
    drafts[slot] = [...put];
    goTo = slot;
    notifyListeners();
  }

  void changed() => notifyListeners();
}

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
    return Column(children: [
      // 이름 띠
      Row(children: [
        IconButton(
          key: const Key('benchPrev'),
          visualDensity: VisualDensity.compact,
          onPressed: _page > 0
              ? () => _pages.previousPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut)
              : null,
          icon: const Icon(Icons.chevron_left_rounded, color: AppColors.goldBright),
        ),
        Expanded(
          child: Text(_label(_page),
              key: const Key('benchLabel'),
              textAlign: TextAlign.center,
              style: AppText.title(16, color: AppColors.goldBright)),
        ),
        IconButton(
          key: const Key('benchNext'),
          visualDensity: VisualDensity.compact,
          onPressed: _page < count - 1
              ? () => _pages.nextPage(duration: const Duration(milliseconds: 260), curve: Curves.easeOut)
              : null,
          icon: const Icon(Icons.chevron_right_rounded, color: AppColors.goldBright),
        ),
      ]),
      Expanded(
        child: PageView(
          key: const Key('benchPages'),
          controller: _pages,
          onPageChanged: (i) => setState(() => _page = i),
          children: [
            for (var i = 0; i < n; i++)
              _CauldronPage(key: Key('cauldronPage_$i'), controller: c, slot: i, bus: widget.bus),
            _StationPage(
              art: 'alchemy_still',
              fallback: 'icon_alchemy',
              child: ProcessPanel(controller: c),
            ),
            _StationPage(
              art: 'alchemy_altar',
              fallback: 'icon_convert_table',
              child: ConvertPanel(controller: c),
            ),
            if (c.cauldronGold != null) _BuyPage(controller: c),
          ],
        ),
      ),
      // 점 (다 끓은 가마솥은 금빛 반짝)
      Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < count; i++)
            GestureDetector(
              onTap: () => _pages.animateToPage(i,
                  duration: const Duration(milliseconds: 260), curve: Curves.easeOut),
              child: Container(
                key: Key('benchDot_$i'),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i < n && c.brewReady(i)
                      ? AppColors.goldBright
                      : i == _page
                          ? AppColors.gold
                          : AppColors.gold.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: i < n && c.brewReady(i)
                      ? const [BoxShadow(color: Color(0xCCFFD86B), blurRadius: 6)]
                      : null,
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
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
  const _StationPage({required this.art, required this.fallback, required this.child});

  final String art;
  final String fallback;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          children: [
            Center(child: _art(art, fallback, math.min(box.maxWidth * 0.5, 170))),
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
    return LayoutBuilder(
      builder: (context, box) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        children: [
          Center(
            child: Opacity(
              opacity: 0.45,
              child: Image.asset('assets/images/alchemy_cauldron_base.webp',
                  width: math.min(box.maxWidth * 0.55, 200)),
            ),
          ),
          const SizedBox(height: 10),
          FrameButton(
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
          ),
        ],
      ),
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

/// 가마솥 한 칸
class _CauldronPage extends StatefulWidget {
  const _CauldronPage({super.key, required this.controller, required this.slot, required this.bus});

  final AppController controller;
  final int slot;
  final WorkbenchBus bus;

  @override
  State<_CauldronPage> createState() => _CauldronPageState();
}

class _CauldronPageState extends State<_CauldronPage> with TickerProviderStateMixin {
  AppController get c => widget.controller;
  List<MaterialId> get _put => widget.bus.drafts[widget.slot] ??= [];

  /// 늘 도는 시계 (거품·불·반짝임)
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(seconds: 3));

  /// 끓는 중 · 다 끓음 · 맞는 순서 반짝임일 때만 돈다 (가만히 있는 빈 가마솥은 멈춤)
  void _syncLoop(bool on) {
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
  Color _liquid = brewTint(const []);
  Color _liquidFrom = brewTint(const []);
  double _liquidT = 1;

  final GlobalKey _potKey = GlobalKey();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _liquid = _liquidFrom = brewTint(_put);
  }

  @override
  void dispose() {
    _loop.dispose();
    _fx.dispose();
    super.dispose();
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
    if (!_fx.isAnimating) {
      _fxLast = 0;
      _fx.forward(from: 0);
    } else if (_fx.value > 0.6) {
      _fxLast = 0;
      _fx.forward(from: 0);
    }
  }

  void _land(MaterialId m) {
    _splashes.add((materialTint(m), 0));
    _liquidFrom = Color.lerp(_liquidFrom, _liquid, _liquidT)!;
    _liquid = brewTint(_put);
    _liquidT = 0;
    if (c.sound) Sfx.play(SfxKind.pong, volume: 0.7);
    if (c.vibrate) HapticFeedback.lightImpact();
  }

  int _left(MaterialId m) => c.player.materialCount(m) - _put.where((x) => x == m).length;

  bool _canAdd(MaterialId m) {
    if (_left(m) <= 0) return false;
    if (AlchemyRules.isAdditive(m)) return !_put.any(AlchemyRules.isAdditive);
    return _put.where((x) => !AlchemyRules.isAdditive(x)).length < AlchemyRules.maxIngredients;
  }

  /// 재료를 넣는다 ([from] 은 화면 위 출발점, 없으면 아래 선반 가운데)
  void _add(MaterialId m, {Offset? from}) {
    if (!_canAdd(m)) return;
    setState(() {
      _put.add(m);
      _drops.add(_Drop(m, from ?? const Offset(0.5, 1.4)));
    });
    widget.bus.changed();
    _kickFx();
  }

  void _removeLast() {
    if (_put.isEmpty) return;
    setState(() {
      _put.removeLast();
      _liquidFrom = Color.lerp(_liquidFrom, _liquid, _liquidT)!;
      _liquid = brewTint(_put);
      _liquidT = 0;
    });
    widget.bus.changed();
    _kickFx();
  }

  /// 만들어 본 레시피와 순서까지 똑같으면 금빛 반짝임
  bool get _matches {
    final base = [for (final x in _put) if (!AlchemyRules.isAdditive(x)) x];
    if (base.isEmpty) return false;
    final r = AlchemyRules.asRecipe(base);
    for (final id in c.knownRecipes) {
      if (!c.recipeDiscovered(id)) continue;
      final rec = AlchemyRules.info(id).recipe;
      if (rec.length == r.length && [for (var i = 0; i < r.length; i++) rec[i] == r[i]].every((x) => x)) {
        return true;
      }
    }
    return false;
  }

  Future<void> _boil() async {
    if (_put.isEmpty || _busy) return;
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
      _liquid = _liquidFrom = brewTint(const []);
    });
    if (r != null) await showBrewResult(context, c, r);
  }

  @override
  Widget build(BuildContext context) {
    final brew = c.alchemy.brews[widget.slot];
    final ready = c.brewReady(widget.slot);
    _syncLoop(brew != null || _matches);
    return LayoutBuilder(builder: (context, box) {
      final idle = brew == null;
      // 아래 칸(넣은 재료 줄·버튼·선반)을 뺀 만큼, 폭의 70%까지
      final below = idle ? 196.0 : 110.0;
      final pot = math.max(120.0, math.min(box.maxWidth * 0.7, box.maxHeight - below));
      final brewPut = brew == null
          ? const <MaterialId>[]
          : [for (final n in brew.put) if (Materials.byName(n) case final m?) m];
      final liquid = brew == null
          ? Color.lerp(_liquidFrom, _liquid, Curves.easeOut.transform(_liquidT))!
          : brewTint(brewPut);
      final pct = brew == null
          ? 0.0
          : () {
              final total = brew.readyAt.difference(brew.startedAt).inSeconds;
              final done = c.now.difference(brew.startedAt).inSeconds;
              return total <= 0 ? 1.0 : (done / total).clamp(0.0, 1.0);
            }();
      final potArea = DragTarget<MaterialId>(
        onWillAcceptWithDetails: (d) => idle && _canAdd(d.data),
        onAcceptWithDetails: (d) {
          final rb = _potKey.currentContext?.findRenderObject() as RenderBox?;
          Offset? from;
          if (rb != null) {
            final local = rb.globalToLocal(d.offset);
            from = Offset(local.dx / rb.size.width, local.dy / rb.size.height);
          }
          _add(d.data, from: from);
        },
        builder: (context, cand, _) => GestureDetector(
          onTap: ready ? _collect : null,
          child: SizedBox(
            key: _potKey,
            width: pot,
            height: pot,
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) => Stack(clipBehavior: Clip.none, children: [
                // 불 (끓는 중이면 크게)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _FirePainter(
                        t: _loop.value, big: brew != null && !ready, ready: ready),
                  ),
                ),
                Positioned.fill(
                    child: Image.asset('assets/images/alchemy_cauldron_base.webp',
                        key: const Key('cauldronArt'))),
                Positioned.fill(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(liquid, BlendMode.modulate),
                    child: Image.asset('assets/images/alchemy_liquid.webp',
                        key: const Key('cauldronLiquid')),
                  ),
                ),
                // 거품 · 첨벙 · 떨어지는 재료 · 반짝임
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BrewFx(
                      t: _loop.value,
                      liquid: liquid,
                      boiling: brew != null && !ready,
                      splashes: [..._splashes],
                      glow: idle && _matches,
                      hover: cand.isNotEmpty,
                    ),
                  ),
                ),
                for (final d in _drops)
                  () {
                    // 포물선: 출발점 → 위로 살짝 → 가마솥 입구 (0.5, 0.37)
                    final t = Curves.easeIn.transform(d.t.clamp(0.0, 1.0));
                    final x = d.from.dx + (0.5 - d.from.dx) * t;
                    final y0 = d.from.dy, y1 = 0.37;
                    final y = y0 + (y1 - y0) * t - math.sin(t * math.pi) * 0.35;
                    final s = pot * 0.2 * (1 - t * 0.35);
                    return Positioned(
                      left: x * pot - s / 2,
                      top: y * pot - s / 2,
                      child: Transform.rotate(
                          angle: t * 2.4, child: MaterialIcon(d.m, size: s)),
                    );
                  }(),
                // 다 끓으면 물약이 떠오름
                if (ready)
                  Positioned(
                    left: pot * 0.5 - pot * 0.14,
                    top: pot * (0.12 - 0.04 * math.sin(_loop.value * 2 * math.pi)),
                    child: Column(children: [
                      Container(
                        key: const Key('brewRise'),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Color(0xAAFFE38A), blurRadius: 18, spreadRadius: 2)],
                        ),
                        child: Icon(Icons.science_rounded,
                            size: pot * 0.26, color: Color.lerp(liquid, Colors.white, 0.25)),
                      ),
                    ]),
                  ),
                // 끓는 시간 고리
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
                            style: const TextStyle(
                                color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      );
      return Column(children: [
        Center(child: potArea),
        if (ready)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GoldButton(
              key: Key('brewCollect_${widget.slot}'),
              label: '눌러서 받기',
              height: 42,
              fontSize: 15,
              onPressed: _busy ? null : _collect,
            ),
          ),
        const SizedBox(height: 6),
        // 넣은 재료 ①~⑤ (+ 특산물 칸)
        _Slots(put: idle ? _put : brewPut, glow: idle && _matches),
        if (idle) ...[
          const SizedBox(height: 6),
          Row(children: [
            Material(
              color: AppColors.slotBg,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5))),
              child: IconButton(
                key: Key('brewUndo_${widget.slot}'),
                tooltip: '마지막 재료 빼기',
                onPressed: _put.isEmpty ? null : _removeLast,
                icon: Icon(Icons.undo_rounded,
                    color: _put.isEmpty ? AppColors.textMuted : AppColors.goldBright),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GoldButton(
                key: Key('brewBoil_${widget.slot}'),
                label: '끓이기',
                height: 42,
                fontSize: 16,
                onPressed: _put.isEmpty || _busy ? null : _boil,
              ),
            ),
          ]),
          const SizedBox(height: 6),
          _Shelf(
            controller: c,
            left: _left,
            canAdd: _canAdd,
            onTap: (m) => _add(m),
          ),
        ],
      ]);
    });
  }
}

/// 넣은 재료 칸 (넣은 순서, 동그라미 숫자)
class _Slots extends StatelessWidget {
  const _Slots({required this.put, required this.glow});

  final List<MaterialId> put;
  final bool glow;

  static const _nums = ['①', '②', '③', '④', '⑤'];

  @override
  Widget build(BuildContext context) {
    final base = [for (final m in put) if (!AlchemyRules.isAdditive(m)) m];
    final add = put.where(AlchemyRules.isAdditive).firstOrNull;
    Widget cell(Widget? child, String mark, {bool special = false}) => Expanded(
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: AppColors.slotBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: glow
                      ? AppColors.goldBright
                      : special
                          ? const Color(0xFF9FE3A8).withValues(alpha: 0.6)
                          : AppColors.gold.withValues(alpha: 0.35),
                  width: glow ? 1.6 : 1),
              boxShadow: glow ? const [BoxShadow(color: Color(0x88FFD86B), blurRadius: 8)] : null,
            ),
            child: Stack(children: [
              if (child != null) Center(child: child),
              Positioned(
                left: 3,
                top: 1,
                child: Text(mark,
                    style: TextStyle(
                        color: special ? const Color(0xFF9FE3A8) : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        );
    return Row(key: const Key('brewSlots'), children: [
      for (var i = 0; i < AlchemyRules.maxIngredients; i++)
        cell(i < base.length ? MaterialIcon(base[i], size: 32) : null, _nums[i]),
      cell(add == null ? null : MaterialIcon(add, size: 32), '✦', special: true),
    ]);
  }
}

/// 재료 선반 (가로로 넘김, 개수 표시). 누르거나 가마솥으로 끌어 넣는다
class _Shelf extends StatelessWidget {
  const _Shelf({required this.controller, required this.left, required this.canAdd, required this.onTap});

  final AppController controller;
  final int Function(MaterialId) left;
  final bool Function(MaterialId) canAdd;
  final ValueChanged<MaterialId> onTap;

  @override
  Widget build(BuildContext context) {
    final have = controller.player.materials;
    final mats = [
      for (final m in Materials.displayOrder)
        if ((have[m] ?? 0) > 0) m,
    ];
    if (mats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: KText('가방에 재료가 없어요.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
      );
    }
    Widget tile(MaterialId m, {bool ghost = false}) => Container(
          width: 58,
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3A2A1A), Color(0xFF24180E)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF8C6A42)),
          ),
          child: Stack(children: [
            Center(child: MaterialIcon(m, size: 40)),
            if (!ghost)
              Positioned(
                right: 4,
                bottom: 2,
                child: Text('${left(m)}',
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(blurRadius: 3)])),
              ),
          ]),
        );
    return SizedBox(
      height: 66,
      child: ListView.separated(
        key: const Key('brewShelf'),
        scrollDirection: Axis.horizontal,
        itemCount: mats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final m = mats[i];
          final ok = canAdd(m);
          final t = Opacity(opacity: ok ? 1 : 0.35, child: tile(m));
          if (!ok) return KeyedSubtree(key: Key('shelf_${m.name}'), child: t);
          return Draggable<MaterialId>(
            key: Key('shelf_${m.name}'),
            data: m,
            feedback: Material(
                type: MaterialType.transparency, child: MaterialIcon(m, size: 48)),
            childWhenDragging: Opacity(opacity: 0.5, child: tile(m)),
            child: GestureDetector(onTap: () => onTap(m), child: t),
          );
        },
      ),
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
  });

  final double t;
  final Color liquid;
  final bool boiling;
  final List<(Color, double)> splashes;
  final bool glow;
  final bool hover;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final mouth = Offset(w * 0.5, w * 0.38);
    // 거품 (끓는 중이면 많이 · 높이)
    final bubbles = boiling ? 9 : 3;
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
