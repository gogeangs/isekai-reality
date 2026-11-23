import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Element;

import '../../app_controller.dart';
import '../../core/models/highland_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart' show HeroSprite, HeroPose, MonsterPicture;
import '../town/material_view.dart';

/// 구름 걷기가 끝난 까닭
enum SkyEnd { left, noWind, hpZero, islandGone }

/// 묶음 83 #389: 하이랜드 쿼터뷰 구름 걷기.
/// 위: 섬 이름 · 층 이름 · 층 점 ①②③ · 바람 · HP · 유물 조각 · 얻은 것 →
/// 가운데: 2:1 쿼터뷰 판 (카메라가 주인공을 따라가고, 끌어서 둘러봄 · 오른쪽 위 작은 지도) →
/// 아래: 한 줄 소식 · 「내려가기」 · 「위층으로」(꼭대기는 「제단에서 수호자 깨우기」).
class SkyWalkView extends StatefulWidget {
  const SkyWalkView({
    super.key,
    required this.controller,
    required this.onSoldier,
    required this.onWake,
    required this.onEnd,
    this.firstLine,
    this.tile = 84,
  });

  final AppController controller;

  /// 석상 병사 칸을 밝혔을 때 (바로 짧게 싸움)
  final VoidCallback onSoldier;

  /// 「제단에서 수호자 깨우기」
  final VoidCallback onWake;
  final void Function(SkyEnd) onEnd;

  /// 처음 섬에 올랐을 때 첫 펫 한마디
  final String? firstLine;

  /// 칸 너비 (마름모 가로)
  final double tile;

  @override
  State<SkyWalkView> createState() => _SkyWalkViewState();
}

class _Pop {
  _Pop(this.id, this.cell, this.asset, this.text);
  final int id;
  final int cell;
  final String? asset;
  final String? text;
}

class _SkyWalkViewState extends State<SkyWalkView> with TickerProviderStateMixin {
  AppController get c => widget.controller;
  double get w => widget.tile;

  late final AnimationController _breath =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  late final AnimationController _rise =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800), value: 1);

  bool _busy = false;
  String _news = '';

  /// 끌어서 둘러본 만큼 (밝히면 다시 주인공에게)
  Offset _drag = Offset.zero;
  bool _dragging = false;
  bool _afterDrag = false;
  Timer? _dragTimer;

  /// 흩어지는 구름 · 떠오르는 것
  final Set<int> _scatter = {};
  final List<_Pop> _pops = [];
  int _popId = 0;

  /// 한 번 흔들리는 구름
  int? _shakeCell;
  int _shakeNo = 0;

  /// 층 띠 (「2층 · 무너진 회랑」)
  String? _band;
  Timer? _bandTimer;

  /// 처음 오를 때 안내 (첫 카드에서 저장)
  late bool _guiding;
  ({String text, int cell})? _guide;
  bool _guideNumber = false;
  bool _guideStair = false;
  final List<Timer> _timers = [];

  @override
  void initState() {
    super.initState();
    _guiding = !c.skyGuideSeen;
    final cl = c.skyClimb;
    final b = c.skyBoard;
    _news = widget.firstLine ?? (cl != null && cl.opened.length <= 1 ? '밝힌 곳과 맞닿은 구름을 눌러 걷어 봐요.' : '구름 위를 계속 걸어요.');
    if (_guiding && b != null && cl != null) {
      final first = b.neighbors4(cl.hero).where((i) => !cl.opened.contains(i)).firstOrNull;
      if (first != null) {
        _guide = (text: '입구 둘레 구름부터 걷어 봐요', cell: first);
        unawaited(c.markSkyGuide());
      }
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _rise.dispose();
    _dragTimer?.cancel();
    _bandTimer?.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _later(Duration d, VoidCallback f) {
    _timers.add(Timer(d, () {
      if (mounted) f();
    }));
  }

  // ───────────── 판 좌표

  double _ox(SkyBoard b) => (b.n - 1) * w / 2;
  double get _oy => w * 1.9;

  Rect _tileRect(SkyBoard b, int i) {
    final x = b.xOf(i), y = b.yOf(i);
    return Rect.fromLTWH(_ox(b) + (x - y) * w / 2, _oy + (x + y) * w / 4, w, w * 0.75);
  }

  Offset _center(SkyBoard b, int i) => _tileRect(b, i).topLeft + Offset(w / 2, w / 4);

  Size _boardSize(SkyBoard b) => Size(b.n * w, _oy + (2 * b.n - 2) * w / 4 + w * 0.75 + b.n * w * 0.35);

  int? _cellAt(SkyBoard b, Offset p) {
    final a = (p.dx - _ox(b) - w / 2) / (w / 2);
    final s = (p.dy - _oy - w / 4 + w * 0.08) / (w / 4);
    final x = ((a + s) / 2).round(), y = ((s - a) / 2).round();
    if (x < 0 || y < 0 || x >= b.n || y >= b.n) return null;
    final i = y * b.n + x;
    return b.inside(i) ? i : null;
  }

  Offset _camera(SkyBoard b, Size view, int hero) {
    final h = _center(b, hero);
    final size = _boardSize(b);
    var o = Offset(view.width / 2 - h.dx, view.height * 0.56 - h.dy) + _drag;
    // 판이 화면보다 작으면 가운데
    if (size.width <= view.width) o = Offset((view.width - size.width) / 2 + _drag.dx, o.dy);
    return o;
  }

  // ───────────── 누르기

  Future<void> _tap(SkyBoard b, Offset local, Offset cam) async {
    if (_busy || _afterDrag || _rise.isAnimating) return;
    final cl = c.skyClimb;
    if (cl == null || cl.soldier != null) return;
    final i = _cellAt(b, local - cam);
    if (i == null) return;
    final opened = cl.opened.toSet();
    if (opened.contains(i)) return;
    if (!b.canReveal(i, opened) || cl.wind < SkyWalkRules.windPerCell) {
      setState(() {
        _shakeCell = i;
        _shakeNo++;
        if (cl.wind < SkyWalkRules.windPerCell) _news = '바람이 다했어요.';
      });
      return;
    }
    _busy = true;
    final step = await c.revealSkyCell(i);
    if (!mounted) return;
    _busy = false;
    if (step == null) return;
    _afterReveal(b, step);
  }

  void _afterReveal(SkyBoard b, SkyStep step) {
    final cl = c.skyClimb;
    final i = step.cell;
    setState(() {
      _drag = Offset.zero;
      _scatter.add(i);
      _news = switch (step.kind) {
        SkyCell.empty => step.hint > 0 ? '둘레에 유물 조각 ${step.hint}개의 기운이 느껴져요' : '아무것도 없어요',
        SkyCell.crystal => '하늘 결정을 주웠어요',
        SkyCell.stone => '하늘 돌 조각을 주웠어요',
        SkyCell.spring => '바람 샘이에요! 바람이 ${SkyWalkRules.springWind} 늘었어요',
        SkyCell.soldier => '석상 병사가 길을 막아요!',
        SkyCell.shard => '유물 조각을 찾았어요 (${cl?.shards ?? 0} / ${SkyWalkRules.floorCount})',
        SkyCell.stair => '하늘 계단을 찾았어요!',
        SkyCell.altar => (cl?.shards ?? 0) >= SkyWalkRules.floorCount
            ? '제단을 찾았어요! 수호자를 깨울 수 있어요'
            : '제단을 찾았어요. 유물 조각 3개가 있어야 깨울 수 있어요',
      };
      final pop = switch (step.kind) {
        SkyCell.crystal => (asset: 'assets/images/mat_${SkyWalkRules.crystalOf(c.skyIsland?.isle ?? Isle.wind).name}.webp', text: null),
        SkyCell.stone => (asset: 'assets/images/mat_skyStone.webp', text: null),
        SkyCell.shard => (asset: SkyWalkRules.shardArt, text: null),
        SkyCell.spring => (asset: null, text: '바람 +${SkyWalkRules.springWind}'),
        _ => null,
      };
      if (pop != null) {
        final id = _popId++;
        _pops.add(_Pop(id, i, pop.asset, pop.text));
        _later(const Duration(milliseconds: 1000), () => setState(() => _pops.removeWhere((p) => p.id == id)));
      }
      // 안내
      if (_guiding) {
        _guide = null;
        if (!_guideNumber && step.kind == SkyCell.empty && step.hint > 0) {
          _guideNumber = true;
          _guide = (text: '숫자는 둘레 8칸에 숨은 유물 조각 수예요', cell: i);
        } else if (!_guideStair) {
          _guideStair = true;
          _guide = (text: b.info.top ? '금빛 기둥 아래가 수호자 제단이에요' : '금빛 기둥 아래가 하늘 계단이에요. 바람이 다하기 전에 닿아 봐요', cell: b.goal);
        }
      }
    });
    _later(const Duration(milliseconds: 520), () => setState(() => _scatter.remove(i)));
    if (step.kind == SkyCell.soldier) {
      _later(const Duration(milliseconds: 700), widget.onSoldier);
      return;
    }
    if (c.skyStuck) _later(const Duration(milliseconds: 900), () => widget.onEnd(SkyEnd.noWind));
  }

  Future<void> _up() async {
    if (_busy) return;
    _busy = true;
    final ok = await c.climbUp();
    _busy = false;
    if (!ok || !mounted) return;
    final cl = c.skyClimb!;
    final f = SkyWalkRules.floor(cl.floor);
    setState(() {
      _drag = Offset.zero;
      _band = '${f.floor}층 · ${f.name}';
      _news = '바람이 ${f.wind} 불어와요';
      _guide = null;
    });
    _rise.forward(from: 0);
    _bandTimer?.cancel();
    _bandTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _band = null);
    });
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: Text('내려갈까요?', style: AppText.title(18, color: AppColors.text)),
        content: const Text('얻은 것은 그대로예요. 다시 오르려면 하늘 깃털이 하나 있어야 해요.',
            style: TextStyle(color: AppColors.textMuted, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('더 걷기')),
          TextButton(key: const Key('skyLeaveYes'), onPressed: () => Navigator.pop(d, true), child: const Text('내려가기')),
        ],
      ),
    );
    if (ok == true && mounted) widget.onEnd(SkyEnd.left);
  }

  // ───────────── 화면

  @override
  Widget build(BuildContext context) {
    final cl = c.skyClimb;
    final b = c.skyBoard;
    final s = c.skyIsland;
    if (cl == null || b == null || s == null) {
      return const Center(
          child: Text('섬이 구름 속으로 사라졌어요.', style: TextStyle(color: AppColors.textMuted)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(cl, b, s),
      const SizedBox(height: 6),
      Expanded(child: _view(cl, b, s)),
      const SizedBox(height: 6),
      Container(
        key: const Key('skyNews'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        constraints: const BoxConstraints(minHeight: 34),
        decoration: BoxDecoration(color: const Color(0x44000000), borderRadius: BorderRadius.circular(8)),
        child: KText(_news, style: const TextStyle(color: AppColors.text, fontSize: 13)),
      ),
      const SizedBox(height: 8),
      _buttons(cl, b),
    ]);
  }

  Widget _chip(Widget icon, String text, {Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.fromLTRB(3, 1, 9, 1),
        decoration: BoxDecoration(
          color: const Color(0xFF15133A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF3A3468)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 22, height: 22, child: icon),
          const SizedBox(width: 3),
          Text(text, style: const TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _header(SkyClimb cl, SkyBoard b, SkyIsland s) {
    final hpRatio = c.maxHp <= 0 ? 0.0 : c.hp / c.maxHp;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(s.info.place, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: AppText.title(17, color: AppColors.goldBright)),
        ),
        Text(b.info.name, key: const Key('skyFloorName'), style: const TextStyle(color: AppColors.text, fontSize: 13)),
        const SizedBox(width: 6),
        for (var f = 1; f <= SkyWalkRules.floorCount; f++)
          Container(
            key: Key('skyFloorDot_$f${f < cl.floor ? '_done' : f == cl.floor ? '_now' : ''}'),
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(left: 3),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: f < cl.floor ? AppColors.gold : Colors.transparent,
              border: Border.all(color: f <= cl.floor ? AppColors.goldBright : const Color(0xFF3A3468), width: 1.5),
              boxShadow: f == cl.floor ? const [BoxShadow(color: Color(0x88F6D88A), blurRadius: 8)] : null,
            ),
            child: Text('$f',
                style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                    color: f < cl.floor
                        ? const Color(0xFF2A1D08)
                        : f == cl.floor
                            ? AppColors.goldBright
                            : AppColors.textMuted)),
          ),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        _chip(const MaterialIcon(MaterialId.skyFeather, size: 22), '바람 ${cl.wind}', key: const Key('skyWind')),
        const SizedBox(width: 8),
        const Text('HP', style: TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const Key('skyHp'),
              value: hpRatio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: const Color(0xFF0E0C22),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFEF6B62)),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        const Text('유물 조각', style: TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        const SizedBox(width: 4),
        for (var k = 0; k < SkyWalkRules.floorCount; k++)
          Container(
            key: Key('skyShard_$k${k < cl.shards ? '_on' : ''}'),
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: k < cl.shards ? AppColors.goldBright : const Color(0xFF6B628F)),
              boxShadow: k < cl.shards ? const [BoxShadow(color: Color(0x88F6D88A), blurRadius: 6)] : null,
            ),
            child: k < cl.shards
                ? Image.asset(SkyWalkRules.shardArt, errorBuilder: (_, __, ___) => const SizedBox())
                : null,
          ),
        Text('${cl.shards} / ${SkyWalkRules.floorCount}',
            key: const Key('skyShards'), style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
        const Spacer(),
        _chip(MaterialIcon(SkyWalkRules.crystalOf(s.isle), size: 22), '${cl.crystals}', key: const Key('skyGotCrystal')),
        const SizedBox(width: 4),
        _chip(const MaterialIcon(MaterialId.skyStone, size: 22), '${cl.stones}', key: const Key('skyGotStone')),
      ]),
    ]);
  }

  Widget _buttons(SkyClimb cl, SkyBoard b) {
    final top = b.info.top;
    final ok = top ? c.canWakeGuardian : c.canClimbUp;
    return Row(children: [
      Expanded(
        flex: 2,
        child: FrameButton(key: const Key('skyLeave'), label: '내려가기', onPressed: _busy ? null : _leave),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 3,
        child: GoldButton(
          key: Key(top ? 'skyWake' : 'skyUp'),
          label: top ? '제단에서 수호자 깨우기' : '위층으로',
          fontSize: top ? 15 : 19,
          height: 50,
          onPressed: ok && !_busy ? (top ? widget.onWake : _up) : null,
        ),
      ),
    ]);
  }

  Widget _view(SkyClimb cl, SkyBoard b, SkyIsland s) => LayoutBuilder(builder: (context, box) {
        final view = Size(box.maxWidth, box.maxHeight);
        final cam = _camera(b, view, cl.hero);
        final size = _boardSize(b);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _tap(b, d.localPosition, cam),
            onPanStart: (_) => setState(() => _dragging = true),
            onPanUpdate: (d) => setState(() {
              final lim = Offset(size.width * 0.6, size.height * 0.5);
              final n = _drag + d.delta;
              _drag = Offset(n.dx.clamp(-lim.dx, lim.dx), n.dy.clamp(-lim.dy, lim.dy));
            }),
            onPanEnd: (_) {
              setState(() {
                _dragging = false;
                _afterDrag = true;
              });
              _dragTimer?.cancel();
              _dragTimer = Timer(const Duration(milliseconds: 220), () {
                if (mounted) setState(() => _afterDrag = false);
              });
            },
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned.fill(
                child: Image.asset(s.info.background,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFF2B2F7A), Color(0xFFC9B8E8)]))))),
              const Positioned.fill(child: ColoredBox(color: Color(0x22000020))),
              AnimatedPositioned(
                duration: _dragging ? Duration.zero : const Duration(milliseconds: 420),
                curve: Curves.easeOut,
                left: cam.dx,
                top: cam.dy,
                width: size.width,
                height: size.height,
                child: AnimatedBuilder(
                  animation: _rise,
                  builder: (context, child) {
                    final v = Curves.easeOutCubic.transform(_rise.value);
                    return Transform.translate(
                      offset: Offset(0, (1 - v) * 160),
                      child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
                    );
                  },
                  child: _board(cl, b, s, size),
                ),
              ),
              Positioned(right: 8, top: 8, child: _miniMap(cl, b)),
              if (_guide case final gd? when gd.cell == b.goal)
                Positioned(
                  left: 12,
                  right: 108,
                  top: 10,
                  child: IgnorePointer(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.keyboard_double_arrow_up_rounded, color: AppColors.goldBright, size: 22),
                      _GuideCard(text: gd.text, tail: false),
                    ]),
                  ),
                ),
              if (_band != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_band),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1400),
                        builder: (context, v, child) => Opacity(
                          opacity: v < 0.2 ? v / 0.2 : (v > 0.8 ? (1 - v) / 0.2 : 1),
                          child: child,
                        ),
                        child: Container(
                          key: const Key('skyFloorBand'),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          color: const Color(0xAA0E0C22),
                          alignment: Alignment.center,
                          child: Text(_band!, style: AppText.title(22, color: AppColors.goldBright)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        );
      });

  Widget _board(SkyClimb cl, SkyBoard b, SkyIsland s, Size size) {
    final opened = cl.opened.toSet();
    final order = [for (var i = 0; i < b.cells.length; i++) if (b.inside(i)) i]
      ..sort((p, q) {
        final d = (b.xOf(p) + b.yOf(p)) - (b.xOf(q) + b.yOf(q));
        return d != 0 ? d : b.xOf(p) - b.xOf(q);
      });
    final tile = SkyWalkRules.tile(s.isle, b.floor);
    final color = Color(s.info.color);
    final kids = <Widget>[
      // 섬 아래 (섬 색을 살짝 입힘)
      Positioned(
        left: -size.width * 0.04,
        top: _oy + b.n * w / 4 - size.width * 0.16,
        width: size.width * 1.08,
        height: size.width * 1.08 * 0.75,
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(Color.lerp(Colors.white, color, 0.35)!, BlendMode.modulate),
          child: Image.asset(SkyWalkRules.under,
              key: const Key('skyUnder'), fit: BoxFit.fill, errorBuilder: (_, __, ___) => const SizedBox()),
        ),
      ),
    ];
    for (final i in order) {
      final r = _tileRect(b, i);
      final ctr = _center(b, i);
      kids.add(Positioned.fromRect(
        rect: r,
        child: Image.asset(tile,
            key: Key('skyTile_$i'),
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => CustomPaint(painter: _DiamondPainter(color))),
      ));
      if (opened.contains(i)) {
        kids.addAll(_opened(cl, b, i, ctr, opened));
      } else {
        kids.add(_cloud(b, i, r, opened, cl.wind));
      }
      if (i == cl.hero) kids.add(_hero(b, i, ctr));
    }
    // 걷히는 구름
    for (final i in _scatter) {
      final r = _tileRect(b, i).shift(Offset(0, -w * 0.18));
      kids.add(Positioned.fromRect(
        rect: r,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            key: ValueKey('scatter$i'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 480),
            builder: (context, v, child) => Opacity(
              opacity: (1 - v).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, -w * 0.5 * v),
                child: Transform.scale(scale: 1 + 0.4 * v, child: child),
              ),
            ),
            child: Image.asset(i.isEven ? SkyWalkRules.cloudA : SkyWalkRules.cloudB,
                fit: BoxFit.fill, errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        ),
      ));
    }
    // 계단 · 제단 빛기둥 (구름 위로도 보임)
    final g = _center(b, b.goal);
    kids.add(Positioned(
      left: g.dx - w * 0.14,
      top: g.dy - w * 2.3,
      width: w * 0.28,
      height: w * 2.3,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: opened.contains(b.goal)
              ? Tween<double>(begin: 0.2, end: 0.4).animate(_breath)
              : Tween<double>(begin: 0.55, end: 1).animate(_breath),
          child: DecoratedBox(
            key: const Key('skyPillar'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(w * 0.14),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x00FFE9A8), Color(0xBFFFE9A8), Color(0xF2FFF6C8)],
                stops: [0, 0.7, 1],
              ),
              boxShadow: const [BoxShadow(color: Color(0x66FFE9A8), blurRadius: 14)],
            ),
          ),
        ),
      ),
    ));
    // 떠오르는 것 (주운 재료 · 조각 · 바람)
    for (final p in _pops) {
      final ctr = _center(b, p.cell);
      kids.add(Positioned(
        left: ctr.dx - w * 0.3,
        top: ctr.dy - w * 0.9,
        width: w * 0.6,
        height: w * 0.6,
        child: IgnorePointer(
          child: TweenAnimationBuilder<double>(
            key: ValueKey('pop${p.id}'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 950),
            builder: (context, v, child) => Opacity(
              opacity: v < 0.6 ? 1 : ((1 - v) / 0.4).clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, -w * 0.6 * v), child: child),
            ),
            child: p.asset != null
                ? Image.asset(p.asset!, key: Key('skyPop_${p.cell}'), errorBuilder: (_, __, ___) => const SizedBox())
                : Center(
                    child: Text(p.text ?? '',
                        style: const TextStyle(
                            color: Color(0xFF9FF0FF),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            shadows: [Shadow(color: Colors.black, blurRadius: 3)]))),
          ),
        ),
      ));
    }
    // 안내 카드 (계단 · 제단 안내는 화면 위에 따로)
    if (_guide case final gd? when gd.cell != b.goal) {
      final p = _center(b, gd.cell);
      kids.add(Positioned(
        left: p.dx - 105,
        top: p.dy - w * 1.15 - 44,
        width: 210,
        child: IgnorePointer(child: _GuideCard(text: gd.text)),
      ));
    }
    return Stack(clipBehavior: Clip.none, children: kids);
  }

  List<Widget> _opened(SkyClimb cl, SkyBoard b, int i, Offset ctr, Set<int> opened) {
    final out = <Widget>[];
    Widget obj(Widget child, {double size = 0.8, double lift = 0.12, Key? key}) => Positioned(
          key: key,
          left: ctr.dx - w * size / 2,
          top: ctr.dy + w * lift - w * size,
          width: w * size,
          height: w * size,
          child: IgnorePointer(child: child),
        );
    if (b.columns.contains(i)) {
      out.add(obj(Image.asset(SkyWalkRules.columnArt, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
          size: 0.95, lift: 0.1, key: Key('skyColumn_$i')));
    }
    switch (b.at(i)) {
      case SkyCell.spring:
        out.add(obj(
            Opacity(
                opacity: 0.5,
                child: Image.asset(SkyWalkRules.springArt, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox())),
            key: Key('skySpring_$i')));
      case SkyCell.soldier:
        out.add(obj(
            Opacity(
              opacity: cl.soldier == i ? 1 : 0.3,
              child: MonsterPicture(monster: MonsterId.stoneSoldier, size: w * 0.8, tint: c.skyIsland?.info.color),
            ),
            key: Key('skySoldier_$i')));
      case SkyCell.stair:
        out.add(obj(CustomPaint(painter: _StairPainter()), size: 0.62, lift: 0.08, key: const Key('skyStair')));
      case SkyCell.altar:
        out.add(obj(
            Stack(fit: StackFit.expand, children: [
              Image.asset(SkyWalkRules.altarArt, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
              for (var k = 0; k < SkyWalkRules.floorCount; k++)
                Align(
                  alignment: Alignment(-0.32 + 0.32 * k, 0.28),
                  child: Container(
                    key: Key('skySocket_$k${k < cl.shards ? '_on' : ''}'),
                    width: w * 0.1,
                    height: w * 0.1,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: k < cl.shards ? const Color(0xFFFFF6C8) : const Color(0x33223355),
                      boxShadow: k < cl.shards ? const [BoxShadow(color: Color(0xFFF6D88A), blurRadius: 10, spreadRadius: 2)] : null,
                    ),
                  ),
                ),
            ]),
            size: 1.0,
            lift: 0.16,
            key: const Key('skyAltar')));
      case SkyCell.empty:
        final h = b.hint(i, opened);
        if (h > 0) {
          out.add(Positioned(
            key: Key('skyHint_$i'),
            left: ctr.dx - w * 0.25,
            top: ctr.dy - w * 0.17,
            width: w * 0.5,
            height: w * 0.34,
            child: IgnorePointer(
              child: Center(
                child: Text('$h',
                    style: TextStyle(
                      color: const Color(0xFFFFE9A8),
                      fontSize: w * 0.24,
                      fontWeight: FontWeight.w900,
                      shadows: const [
                        Shadow(color: Color(0xFFE3B75A), blurRadius: 8),
                        Shadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 2),
                      ],
                    )),
              ),
            ),
          ));
        }
      default:
    }
    return out;
  }

  Widget _cloud(SkyBoard b, int i, Rect tileRect, Set<int> opened, int wind) {
    final r = tileRect.shift(Offset(0, -w * 0.18)).inflate(w * 0.04);
    final asset = ((i * 7 + b.floor) % 3 == 0) ? SkyWalkRules.cloudB : SkyWalkRules.cloudA;
    final can = b.canReveal(i, opened) && wind >= SkyWalkRules.windPerCell;
    Widget img = Image.asset(asset, fit: BoxFit.fill, errorBuilder: (_, __, ___) => const SizedBox());
    if (can) {
      img = Stack(fit: StackFit.expand, children: [
        img,
        FadeTransition(
          opacity: Tween<double>(begin: 0.15, end: 0.75).animate(_breath),
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(Color(0xAAFFD98A), BlendMode.srcATop),
            child: Image.asset(asset, fit: BoxFit.fill, errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        ),
      ]);
    }
    if (_shakeCell == i) {
      img = TweenAnimationBuilder<double>(
        key: ValueKey('shake$i-$_shakeNo'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 360),
        builder: (context, v, child) =>
            Transform.translate(offset: Offset(math.sin(v * math.pi * 4) * w * 0.05 * (1 - v), 0), child: child),
        child: img,
      );
    }
    return Positioned.fromRect(
      key: Key(can ? 'skyCloud_${i}_can' : 'skyCloud_$i'),
      rect: r,
      child: IgnorePointer(child: img),
    );
  }

  Widget _hero(SkyBoard b, int i, Offset ctr) {
    final hh = w * 1.15;
    final hw = hh * 768 / 1024;
    // 기둥 · 계단 · 제단 · 샘 · 병사 칸이면 오른쪽 앞에 선다
    final col = b.columns.contains(i) || (b.at(i) != SkyCell.empty && i != b.entrance);
    return AnimatedPositioned(
      key: const ValueKey('skyHero'),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      left: ctr.dx - hw / 2 + (col ? w * 0.3 : 0),
      top: ctr.dy - hh + w * 0.1 + (col ? w * 0.12 : 0),
      width: hw,
      height: hh,
      child: IgnorePointer(
        child: HeroSprite(look: c.profile.look, pose: HeroPose.idle, job: c.heroJobArt),
      ),
    );
  }

  Widget _miniMap(SkyClimb cl, SkyBoard b) => Container(
        key: const Key('skyMiniMap'),
        width: 92,
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0xBF0E0C22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3A3468)),
        ),
        child: CustomPaint(painter: _MiniPainter(b, cl.opened.toSet(), cl.hero, _breath)),
      );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.text, this.tail = true});
  final String text;
  final bool tail;

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          key: const Key('skyGuide'),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
          decoration: BoxDecoration(
            color: const Color(0xF01F1C40),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldBright, width: 1.4),
            boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
          ),
          child: KText(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w700)),
        ),
        if (tail) CustomPaint(size: const Size(16, 9), painter: _TailPainter()),
      ]);
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = AppColors.goldBright);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 그림이 없을 때 마름모
class _DiamondPainter extends CustomPainter {
  _DiamondPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final p = Path()
      ..moveTo(w / 2, 0)
      ..lineTo(w, w / 4)
      ..lineTo(w / 2, w / 2)
      ..lineTo(0, w / 4)
      ..close();
    canvas.drawPath(p, Paint()..color = color.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter old) => old.color != color;
}

/// 하늘 계단 (그림 없이 코드로: 위로 좁아지는 흰 돌계단)
class _StairPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const steps = 5;
    for (var k = 0; k < steps; k++) {
      final t0 = k / steps, t1 = (k + 1) / steps;
      final y0 = h * (1 - t1), y1 = h * (1 - t0);
      final half0 = w * (0.5 - 0.28 * t0), half1 = w * (0.5 - 0.28 * t1);
      final p = Path()
        ..moveTo(w / 2 - half0, y1)
        ..lineTo(w / 2 + half0, y1)
        ..lineTo(w / 2 + half1, y0)
        ..lineTo(w / 2 - half1, y0)
        ..close();
      canvas.drawPath(
          p,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFBEA), Color(0xFFD9CFB2)],
            ).createShader(Rect.fromLTRB(0, y0, w, y1)));
      canvas.drawLine(Offset(w / 2 - half1, y0), Offset(w / 2 + half1, y0),
          Paint()
            ..color = const Color(0xFFE3B75A)
            ..strokeWidth = 1.4);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MiniPainter extends CustomPainter {
  _MiniPainter(this.b, this.opened, this.hero, Animation<double> breath) : super(repaint: breath) {
    _breath = breath;
  }
  final SkyBoard b;
  final Set<int> opened;
  final int hero;
  late final Animation<double> _breath;

  @override
  void paint(Canvas canvas, Size size) {
    final n = b.n;
    final cw = math.min((size.width - 8) / n, (size.height - 8) * 2 / n);
    final ch = cw / 2;
    final ox = size.width / 2;
    final oy = (size.height - n * ch) / 2;
    Offset at(int i) => Offset(ox + (b.xOf(i) - b.yOf(i)) * cw / 2, oy + (b.xOf(i) + b.yOf(i)) * ch / 2 + ch / 2);
    void dia(Offset c, Color color, [double k = 1]) {
      final p = Path()
        ..moveTo(c.dx, c.dy - ch / 2 * k)
        ..lineTo(c.dx + cw / 2 * k, c.dy)
        ..lineTo(c.dx, c.dy + ch / 2 * k)
        ..lineTo(c.dx - cw / 2 * k, c.dy)
        ..close();
      canvas.drawPath(p, Paint()..color = color);
    }

    for (var i = 0; i < b.cells.length; i++) {
      if (!b.inside(i)) continue;
      dia(at(i), opened.contains(i) ? const Color(0xFF6BD97A) : const Color(0x55B9B0D4), 0.9);
    }
    final g = at(b.goal);
    canvas.drawCircle(g, 3 + _breath.value * 1.5,
        Paint()
          ..color = const Color(0xFFFFE9A8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    dia(at(hero), const Color(0xFFF6D88A), 1.3);
  }

  @override
  bool shouldRepaint(covariant _MiniPainter old) => true;
}
