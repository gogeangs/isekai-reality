import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart' show VillageRules;
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../bulssi/bulssi_bubble.dart';
import '../town/inn_screen.dart';
import '../town/shop_screen.dart';
import '../smithy/smithy_screen.dart';
import '../alchemy/alchemy_screen.dart';
import 'board_screen.dart';
import 'shelter_screen.dart';
import '../jobs/guild_screen.dart';

/// 마을 시설 (묶음 35: 펫 쉼터 추가)
enum Facility { inn, shop, board, guild, smithy, alchemy, shelter, market }

/// 시설 모아 보기 묶음 (쉬기·사고팔기 / 만들기 / 의뢰·직업 / 펫·마을)
enum FacilityGroup { rest, craft, work, pet }

class FacilityInfo {
  const FacilityInfo(this.facility, this.name, this.group, this.spot);

  final Facility facility;
  final String name;
  final FacilityGroup group;

  /// 마을 바탕(village_bg 1536×1024) 위 건물 자리: 가운데 x, 아래 y, 너비 (그림 픽셀)
  final ({double x, double y, double w}) spot;

  String get asset => 'assets/images/village_${switch (facility) {
        Facility.market => 'market_build',
        _ => facility.name,
      }}.webp';
}

/// 하단 메뉴 '마을' 탭 (묶음 35 개편): 스크롤 없이 마을 그림을 크게, 그림 속 건물을 누르면
/// 들어간다. 아래엔 열린 시설 이름표 한 줄. 막(이별 전 · 2막 · 결말 뒤)마다 바탕이 바뀐다.
/// 시설이 12곳부터는 바탕 전체를 좌우로 끌어서 둘러보고, 「전체」로 모아 본다.
class VillageScreen extends StatefulWidget {
  const VillageScreen({super.key, required this.controller});

  final AppController controller;

  /// 마을 바탕 크기 (그림 픽셀)
  static const Size art = Size(1536, 1024);

  /// 여명의 탑 자리 (바탕 그림 픽셀, 누를 수 없는 배경)
  static const Rect tower = Rect.fromLTWH(975, 0, 135, 200);

  /// 시설이 적을 때 화면에 들어오게 하는 바탕 부분 (탑 쪽)
  static const Rect home = Rect.fromLTWH(650, 300, 760, 600);

  /// 건물 자리 (뒤쪽부터 그린다). 나중에 ★2·★3 그림이 조금 커져도 맞게 둘레를 남겼다
  static const facilities = [
    FacilityInfo(Facility.market, '거래소', FacilityGroup.rest, (x: 1010, y: 445, w: 200)),
    FacilityInfo(Facility.alchemy, '연금술 공방', FacilityGroup.craft, (x: 815, y: 470, w: 220)),
    FacilityInfo(Facility.guild, '길드', FacilityGroup.work, (x: 1250, y: 480, w: 240)),
    FacilityInfo(Facility.inn, '여관', FacilityGroup.rest, (x: 815, y: 665, w: 240)),
    FacilityInfo(Facility.shop, '잡화상', FacilityGroup.rest, (x: 1262, y: 670, w: 230)),
    FacilityInfo(Facility.board, '의뢰 게시판', FacilityGroup.work, (x: 1030, y: 795, w: 200)),
    FacilityInfo(Facility.smithy, '대장간', FacilityGroup.craft, (x: 812, y: 860, w: 240)),
    FacilityInfo(Facility.shelter, '펫 쉼터', FacilityGroup.pet, (x: 1255, y: 870, w: 230)),
  ];

  static const groupNames = {
    FacilityGroup.rest: '쉬기 · 사고팔기',
    FacilityGroup.craft: '만들기',
    FacilityGroup.work: '의뢰 · 직업',
    FacilityGroup.pet: '펫 · 마을',
  };

  @override
  State<VillageScreen> createState() => _VillageScreenState();
}

class _VillageScreenState extends State<VillageScreen> {
  AppController get controller => widget.controller;

  /// 소개 줄 (null 이면 소개 없음)
  int? _intro;

  /// 이번에 들어올 때의 한마디 (결말 뒤 탑 불꽃 · 이별 뒤 · 넓어진 마을)
  String? _moment;
  bool _lit = false;

  @override
  void initState() {
    super.initState();
    _moment = controller.villageMoment;
    _lit = controller.towerLightPending;
    if (_moment != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.markVillageMoment();
      });
    }
  }

  /// 이 시설이 열렸는지 (안 열린 건물은 그림에는 두되 어둡게, 이름표 없음)
  bool _open(Facility f) => switch (f) {
        Facility.inn || Facility.shop => true,
        Facility.smithy => controller.featureOpen(Feature.smithy),
        Facility.board => controller.featureOpen(Feature.board),
        Facility.alchemy => controller.featureOpen(Feature.alchemy),
        Facility.guild => controller.jobsOpen,
        Facility.shelter => controller.shelterOpen,
        Facility.market => false,
      };

  /// 새 소식 (빨간 점): 게시판 보상 · 쉼터의 깨어날 알
  bool _news(Facility f) => switch (f) {
        Facility.board => controller.questRewardsReady > 0,
        Facility.shelter => controller.shelterOpen && controller.readyEgg != null,
        _ => false,
      };

  List<FacilityInfo> get _openList => [
        for (final f in VillageScreen.facilities)
          if (_open(f.facility)) f,
      ];

  /// 정령 인사: 열린 시설만 말한다
  String get _greeting {
    if (!controller.featureOpen(Feature.board)) {
      return '어서 와! 마을에서 쉬고, 물건을 살 수 있어.';
    }
    return '어서 와! 마을에서 쉬고, 사고, 의뢰를 받을 수 있어.';
  }

  void _enter(FacilityInfo f) {
    if (f.facility == Facility.market) {
      showTopNotice(context, '거래소는 준비 중이에요', icon: Icons.construction_rounded);
      return;
    }
    if (!_open(f.facility)) return;
    final Widget page = switch (f.facility) {
      Facility.inn => InnScreen(controller: controller),
      Facility.shop => ShopScreen(controller: controller),
      Facility.smithy => SmithyScreen(controller: controller),
      Facility.alchemy => AlchemyScreen(controller: controller),
      Facility.guild => GuildScreen(controller: controller),
      Facility.shelter => ShelterScreen(controller: controller),
      _ => BoardScreen(controller: controller),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _showAll() => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.night,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (sheet) => SafeArea(
          child: ConstrainedBox(
           constraints: BoxConstraints(
               maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
           child: SingleChildScrollView(
           child: Padding(
            key: const Key('villageAll'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('시설 모아 보기', style: AppText.title(19)),
                for (final g in FacilityGroup.values)
                  if (_openList.any((f) => f.group == g)) ...[
                    const SizedBox(height: 12),
                    Text(VillageScreen.groupNames[g]!,
                        style: AppText.title(14, color: AppColors.goldBright)),
                    const SizedBox(height: 6),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.85,
                      children: [
                        for (final f in _openList.where((f) => f.group == g))
                          GestureDetector(
                            key: Key('villageAll_${f.facility.name}'),
                            onTap: () {
                              Navigator.of(sheet).pop();
                              _enter(f);
                            },
                            child: Column(children: [
                              Expanded(
                                child: Stack(children: [
                                  Positioned.fill(
                                    child: Image.asset(f.asset,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox()),
                                  ),
                                  if (_news(f.facility))
                                    const Positioned(
                                        right: 4, top: 4, child: _RedDot()),
                                ]),
                              ),
                              Text(f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: AppColors.text,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                      ],
                    ),
                  ],
              ],
            ),
          ),
        ),
        ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final top = MediaQuery.paddingOf(context).top;
    final open = _openList;
    final wide = open.length >= VillageRules.wideFrom || c.villageWide;
    if (_intro == null && c.villageIntroPending) {
      // 처음 들어올 때 소개 (한 번만, 건너뛰기 가능)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _intro == null && c.villageIntroPending) {
          setState(() => _intro = 0);
        }
      });
    }
    final introLines = c.villageIntroLines;
    return Stack(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(14, top + 6, 14, 0),
        child: Column(children: [
          const OrnateTopBar(title: '마을'),
          const SizedBox(height: 6),
          SpiritBadgeRow(
              key: const Key('villageGreeting'), line: _moment ?? _greeting),
          const SizedBox(height: 8),
          Expanded(
            child: _VillageArt(
              key: const Key('villageArt'),
              act: c.villageAct,
              all: VillageScreen.facilities,
              open: _open,
              news: _news,
              wide: wide,
              lighting: _lit,
              towerGlow: _intro != null,
              onTap: _enter,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Row(children: [
              Expanded(
                // 한꺼번에 그려 둔다 (안내가 화면 밖 이름표도 찾아 굴릴 수 있게)
                child: SingleChildScrollView(
                  key: const Key('villageTags'),
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final f in open)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _NameTag(
                          key: Key('facility_${f.facility.name}'),
                          name: f.name,
                          news: _news(f.facility),
                          onTap: () => _enter(f),
                        ),
                      ),
                  ]),
                ),
              ),
              if (wide) ...[
                const SizedBox(width: 6),
                _AllButton(
                    count: open.length,
                    news: open.any((f) => _news(f.facility)),
                    onTap: _showAll),
              ],
            ]),
          ),
          const SizedBox(height: 8),
        ]),
      ),
      if (_intro != null && _intro! < introLines.length)
        Positioned.fill(
          child: _IntroOverlay(
            line: introLines[_intro!],
            last: _intro == introLines.length - 1,
            onNext: () {
              if (_intro! < introLines.length - 1) {
                setState(() => _intro = _intro! + 1);
              } else {
                setState(() => _intro = introLines.length);
                c.markVillageIntro();
              }
            },
            onSkip: () {
              setState(() => _intro = introLines.length);
              c.markVillageIntro();
            },
          ),
        ),
    ]);
  }
}

/// 마을 그림: 바탕 위에 건물을 한 채씩. 넓을 땐 좌우로 끌어서 둘러본다.
class _VillageArt extends StatefulWidget {
  const _VillageArt({
    super.key,
    required this.act,
    required this.all,
    required this.open,
    required this.news,
    required this.wide,
    required this.lighting,
    required this.towerGlow,
    required this.onTap,
  });

  final int act;
  final List<FacilityInfo> all;
  final bool Function(Facility) open;
  final bool Function(Facility) news;
  final bool wide;

  /// 결말 뒤 처음: 탑 불꽃이 켜지는 연출
  final bool lighting;

  /// 소개 중: 탑을 금빛 테두리로
  final bool towerGlow;
  final ValueChanged<FacilityInfo> onTap;

  @override
  State<_VillageArt> createState() => _VillageArtState();
}

class _VillageArtState extends State<_VillageArt> {
  final _scroll = ScrollController();
  bool _placed = false;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 끝까지 끌 수 있는 거리 (아직 그리기 전이면 0)
  double get _max => _scroll.hasClients &&
          _scroll.position.hasContentDimensions
      ? _scroll.position.maxScrollExtent
      : 0;

  void _page(int dir, double viewW) {
    if (!_scroll.hasClients) return;
    final to = (_scroll.offset + dir * viewW * 0.7).clamp(0.0, _max);
    _scroll.animateTo(to,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        const art = VillageScreen.art;
        if (widget.wide) {
          // 넓은 마을: 높이에 맞추고 좌우로 끌기 (처음엔 탑 쪽)
          final s = h / art.height;
          final fullW = art.width * s;
          if (!_placed) {
            _placed = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients) {
                _scroll.jumpTo((VillageScreen.tower.center.dx * s - w / 2)
                    .clamp(0.0, _max));
              }
            });
          }
          return Stack(children: [
            SingleChildScrollView(
              key: const Key('villageScroll'),
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                  width: fullW, height: h, child: _scene(s, Offset.zero)),
            ),
            Positioned(
              left: 4,
              top: h / 2 - 20,
              child: _ArrowButton(
                  key: const Key('villageLeft'),
                  icon: Icons.chevron_left_rounded,
                  onTap: () => _page(-1, w)),
            ),
            Positioned(
              right: 4,
              top: h / 2 - 20,
              child: _ArrowButton(
                  key: const Key('villageRight'),
                  icon: Icons.chevron_right_rounded,
                  onTap: () => _page(1, w)),
            ),
            // 아래 작은 위치 막대
            Positioned(
              left: w * 0.3,
              right: w * 0.3,
              bottom: 8,
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  final max = _max;
                  final at = max <= 0
                      ? 0.5
                      : (_scroll.offset / max).clamp(0.0, 1.0);
                  final frac = (w / fullW).clamp(0.1, 1.0);
                  return LayoutBuilder(builder: (context, bar) {
                    final bw = bar.maxWidth;
                    return Container(
                      key: const Key('villageBar'),
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0x66000000),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Stack(children: [
                        Positioned(
                          left: (bw - bw * frac) * at,
                          width: bw * frac,
                          top: 0,
                          bottom: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.goldBright,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ]),
                    );
                  });
                },
              ),
            ),
          ]);
        }
        // 시설이 적을 때: 탑 쪽 부분이 화면에 들어오게 (빈틈 없이 채움)
        const home = VillageScreen.home;
        final s = math.max(
            math.min(w / home.width, h / home.height),
            math.max(w / art.width, h / art.height));
        final left = (w / 2 - (home.center.dx) * s)
            .clamp(w - art.width * s, 0.0);
        final topY = (h / 2 - home.center.dy * s).clamp(h - art.height * s, 0.0);
        return _scene(s, Offset(left, topY));
      }),
    );
  }

  /// 바탕 + 건물 (그림 픽셀 → 화면: ×[s], [o] 만큼 옮김)
  Widget _scene(double s, Offset o) {
    const art = VillageScreen.art;
    final bg = widget.act == 3
        ? 'assets/images/village_bg_end.webp'
        : 'assets/images/village_bg.webp';
    Rect r(double x, double y, double w, double h) =>
        Rect.fromLTWH(o.dx + x * s, o.dy + y * s, w * s, h * s);
    final t = VillageScreen.tower;
    return Stack(clipBehavior: Clip.hardEdge, children: [
      Positioned.fromRect(
        rect: r(0, 0, art.width, art.height),
        child: Image.asset(bg,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF1A1D4A))),
      ),
      // 2막: 가장자리·아래 잿빛 안개
      if (widget.act == 2)
        Positioned.fromRect(
          key: const Key('villageFog'),
          rect: r(0, 0, art.width, art.height),
          child: IgnorePointer(
            child: Image.asset('assets/images/village_fog.webp',
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        ),
      // 결말 뒤 처음: 탑 불꽃이 켜진다 (1초쯤)
      if (widget.lighting)
        Positioned.fromRect(
          key: const Key('towerLight'),
          rect: r(t.left - 120, t.top - 60, t.width + 240, t.height + 120),
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1100),
              builder: (context, k, _) => Opacity(
                opacity: math.sin(k * math.pi) * 0.9,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(colors: [
                      Color(0xFFFFE9A0),
                      Color(0x88FFB347),
                      Color(0x00FFB347),
                    ], stops: [0, 0.35, 1]),
                  ),
                ),
              ),
            ),
          ),
        ),
      for (final f in widget.all) _building(f, r),
      // 소개 중: 탑을 금빛 테두리로 비춤
      if (widget.towerGlow)
        Positioned.fromRect(
          key: const Key('towerGlow'),
          rect: r(t.left - 14, t.top + 4, t.width + 28, t.height + 10),
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.goldBright, width: 2.5),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.6),
                      blurRadius: 16),
                ],
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _building(
      FacilityInfo f, Rect Function(double, double, double, double) r) {
    final open = widget.open(f.facility);
    final sp = f.spot;
    // 건물 그림은 정사각형, 아래 3% 는 여백
    final rect = r(sp.x - sp.w / 2, sp.y - sp.w * 0.97, sp.w, sp.w);
    final dim = !open && f.facility != Facility.market;
    Widget pic = Image.asset(f.asset,
        fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox());
    if (dim) {
      pic = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0xFF3A3A55), BlendMode.modulate),
        child: pic,
      );
    }
    return Positioned.fromRect(
      key: Key('building_${f.facility.name}'),
      rect: rect,
      child: Semantics(
        button: open,
        label: f.name,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: dim ? null : () => widget.onTap(f),
          child: Stack(children: [
            Positioned.fill(child: pic),
            if (open && widget.news(f.facility))
              Positioned(
                right: rect.width * 0.18,
                top: rect.height * 0.2,
                child: const _RedDot(),
              ),
          ]),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xAA0B0D26),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.8)),
          ),
          child: Icon(icon, color: AppColors.goldBright),
        ),
      );
}

class _RedDot extends StatelessWidget {
  const _RedDot();

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFFF4D4D),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
      );
}

/// 아래 이름표 (열린 시설만)
class _NameTag extends StatelessWidget {
  const _NameTag(
      {super.key, required this.name, required this.news, required this.onTap});

  final String name;
  final bool news;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            height: 36,
            margin: const EdgeInsets.only(top: 2, right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.8)),
            ),
            child: Text(name,
                style: AppText.title(14, color: AppColors.text)),
          ),
          if (news) const Positioned(right: 0, top: 0, child: _RedDot()),
        ]),
      );
}

/// 이름표 줄 끝 「전체 ○」 (시설 12곳부터)
class _AllButton extends StatelessWidget {
  const _AllButton(
      {required this.count, required this.news, required this.onTap});

  final int count;
  final bool news;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('villageAllButton'),
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            height: 36,
            margin: const EdgeInsets.only(top: 2, right: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFE8C46A), Color(0xFFB8862E)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text('전체 $count',
                style: AppText.title(14, color: AppColors.night)),
          ),
          if (news) const Positioned(right: 0, top: 0, child: _RedDot()),
        ]),
      );
}

/// 마을 탭 처음 소개 (탑을 비추며 3줄, 건너뛰기 가능)
class _IntroOverlay extends StatelessWidget {
  const _IntroOverlay({
    required this.line,
    required this.last,
    required this.onNext,
    required this.onSkip,
  });

  final String line;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('villageIntro'),
        behavior: HitTestBehavior.opaque,
        onTap: onNext,
        child: ColoredBox(
          color: const Color(0x66000000),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 70),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BulssiBubble(
                      key: const Key('villageIntroLine'), line: line, size: 52),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    if (!last)
                      TextButton(
                        key: const Key('villageIntroSkip'),
                        onPressed: onSkip,
                        child: const Text('건너뛰기'),
                      ),
                    const SizedBox(width: 8),
                    GoldButtonLiteBox(
                      label: last ? '알겠어' : '다음',
                      onTap: onNext,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      );
}

/// 작은 금빛 버튼
class GoldButtonLiteBox extends StatelessWidget {
  const GoldButtonLiteBox({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('villageIntroNext'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFE8C46A), Color(0xFFB8862E)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(label, style: AppText.title(15, color: AppColors.night)),
        ),
      );
}
