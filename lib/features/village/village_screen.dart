import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/rules/rules.dart'
    show AskKind, Building, BuildingRules, GardenRules, JobRules, Npc, TrainingRules, VillageRules;
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../bulssi/bulssi_bubble.dart';
import '../town/inn_screen.dart';
import '../town/shop_screen.dart';
import '../smithy/smithy_screen.dart';
import '../alchemy/alchemy_screen.dart';
import 'board_screen.dart';
import 'npc_request.dart' show askLook;
import 'shelter_screen.dart';
import 'garden_screen.dart';
import 'tavern_screen.dart';
import 'training_screen.dart';
import '../jobs/guild_screen.dart';
import '../act3/act3_screen.dart' show openJourney;

/// 마을 시설 (묶음 35: 펫 쉼터 추가)
/// 묶음 51: 주점 (결말 뒤 만남 장면 다음 바로 열림, 그 전엔 빈 공터)
enum Facility { inn, shop, board, guild, smithy, alchemy, shelter, market, training, garden, tavern }

/// 마을 탭을 열 때마다 1씩 (묶음 51: 마을 「방문」 — 만남 장면 · 거래소 완공을 방문마다 나눔)
final ValueNotifier<int> villageVisits = ValueNotifier<int>(0);

/// 시설 모아 보기 묶음 (쉬기·사고팔기 / 만들기 / 의뢰·직업 / 펫·마을)
enum FacilityGroup { rest, craft, work, pet }

class FacilityInfo {
  const FacilityInfo(this.facility, this.name, this.group, this.spot);

  final Facility facility;
  final String name;
  final FacilityGroup group;

  /// 마을 바탕(village_bg 1536×1024) 위 건물 자리: 가운데 x, 아래 y, 너비 (그림 픽셀)
  final ({double x, double y, double w}) spot;

  /// 묶음 51 #229: 거래소는 완공 전엔 공사 그림 한 장 (village_market_build)
  String get asset => 'assets/images/village_${facility.name}.webp';

  /// 묶음 54: 건물 레벨업 단계 그림 (★1 은 [asset])
  String assetAt(int star) =>
      star >= 2 ? 'assets/images/village_${facility.name}_$star.webp' : asset;
  static const String marketBuild = 'assets/images/village_market_build.webp';

  /// 묶음 44 #225: 공사 중 그림 (1 터 닦기 · 2 뼈대 · 3 거의 완성)
  String buildAsset(int stage) => facility == Facility.market
      ? marketBuild
      : 'assets/images/village_${facility.name}_build$stage.webp';
}

/// 하단 메뉴 '마을' 탭 (묶음 35 개편 · 묶음 38 #211 전체 화면).
/// 마을 그림이 화면 전체를 채우고(높이에 맞춤), 처음부터 좌우로 끌어서 둘러본다.
/// 건물마다 아래에 작은 이름표(#212). 막(이별 전 · 2막 · 결말 뒤)마다 바탕이 바뀐다.
class VillageScreen extends StatefulWidget {
  const VillageScreen({super.key, required this.controller, this.visits});

  final AppController controller;

  /// 마을 탭을 열 때마다 바뀌는 수 (앱에서는 [villageVisits]). 없으면 화면을 만들 때 한 번 들른 것으로
  final ValueListenable<int>? visits;

  /// 마을 바탕 크기 (그림 픽셀)
  static const Size art = Size(1536, 1024);

  /// 여명의 탑 자리 (바탕 그림 픽셀, 누를 수 없는 배경)
  static const Rect tower = Rect.fromLTWH(738, 12, 72, 195);

  /// 묶음 52 #243: 탑 오른쪽 뒤 빛의 다리 (이름표 자리, 그림 픽셀)
  static const Offset bridge = Offset(905, 150);

  /// 건물 3×3 묶음 (가운데 칸은 우물). 처음 들어올 때 이 가운데에 맞춘다
  static const Rect cluster = Rect.fromLTRB(565, 370, 975, 775);

  /// 건물 자리 (뒤쪽부터 그린다, 묶음 38 세로 화면용 바탕: 3×3 중 우물 뺀 8칸).
  /// 양옆 큰 공터 6곳은 새 건물 자리로 비워 둔다
  static const facilities = [
    FacilityInfo(Facility.alchemy, '연금술 공방', FacilityGroup.craft, (x: 635, y: 505, w: 132)),
    FacilityInfo(Facility.guild, '조합', FacilityGroup.work, (x: 770, y: 505, w: 132)),
    FacilityInfo(Facility.market, '거래소', FacilityGroup.rest, (x: 908, y: 505, w: 132)),
    FacilityInfo(Facility.inn, '여관', FacilityGroup.rest, (x: 635, y: 642, w: 132)),
    FacilityInfo(Facility.shop, '잡화상', FacilityGroup.rest, (x: 908, y: 642, w: 132)),
    FacilityInfo(Facility.smithy, '대장간', FacilityGroup.craft, (x: 635, y: 772, w: 132)),
    FacilityInfo(Facility.board, '의뢰 게시판', FacilityGroup.work, (x: 770, y: 772, w: 132)),
    FacilityInfo(Facility.shelter, '펫 쉼터', FacilityGroup.pet, (x: 908, y: 772, w: 132)),
    // 묶음 43 #228: 오른쪽 가운데 공터 (처음 화면 밖, 끌어서 보거나 완공 때 그쪽으로)
    FacilityInfo(Facility.training, '훈련장', FacilityGroup.work, (x: 1168, y: 652, w: 160)),
    // 묶음 48 #230: 왼쪽 가운데 공터 (훈련장 맞은편, 처음 화면 밖)
    FacilityInfo(Facility.garden, '약초밭', FacilityGroup.pet, (x: 368, y: 652, w: 160)),
    // 묶음 51 #242: 왼쪽 위 공터 (탑으로 가는 길 옆, 결말 뒤 만남 장면 다음에 생김)
    FacilityInfo(Facility.tavern, '주점', FacilityGroup.rest, (x: 405, y: 492, w: 150)),
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

  /// 묶음 44 #225: 이번에 완공 연출을 보여 줄 건물
  Set<Facility> _built = const {};

  /// 묶음 54: 이번에 레벨업 연출을 보여 줄 건물
  Set<Facility> _starred = const {};

  /// 탑 불꽃 연출을 다시 시작하는 번호 (방문마다)
  int _lightRun = 0;
  bool _meetShowing = false;

  @override
  void initState() {
    super.initState();
    final v = widget.visits;
    if (v == null) {
      _visit();
    } else {
      v.addListener(_onVisit);
    }
  }

  @override
  void dispose() {
    widget.visits?.removeListener(_onVisit);
    super.dispose();
  }

  void _onVisit() {
    if (mounted) setState(_visit);
  }

  /// 마을에 들어올 때: 거래소 완공(만남 다음 방문) → 완공 연출 · 한마디 → 결말 뒤 탑 불꽃 → 만남 장면
  void _visit() {
    unawaited(controller.villageVisit());
    _moment = controller.villageMoment;
    final meet = controller.meetPending;
    _lit = controller.towerLightPending || meet;
    if (_lit) _lightRun++;
    final built = controller.builtPending;
    _built = {
      for (final f in Facility.values)
        if (built.contains(f.name)) f,
    };
    if (built.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.markBuilt(built);
      });
    }
    // 묶음 54: 다 고친 건물 → 레벨업 연출 (한 번)
    final starred = controller.starPending;
    _starred = {
      for (final f in Facility.values)
        if (starred.contains(f.name)) f,
    };
    if (starred.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.markStarSeen(starred);
      });
    }
    if (_moment != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.markVillageMoment();
      });
    }
    // 묶음 51 #242: 탑 불꽃이 켜진 뒤 화면이 탑 아래로 내려가며 만남 장면 (한 번)
    if (meet) {
      Future<void>.delayed(const Duration(milliseconds: 1400), () async {
        if (!mounted || _meetShowing || !controller.meetPending) return;
        _meetShowing = true;
        await Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => MeetScreen(controller: controller)));
        _meetShowing = false;
        if (mounted) setState(() {});
      });
    }
  }

  /// 이 시설이 열렸는지 (안 열린 건물은 그림에는 두되 어둡게, 이름표 없음)
  bool _open(Facility f) => controller.facilityOpen(f.name);

  /// 마을 그림에 그리는 건물 (주점은 열린 뒤에만 — 그 전엔 빈 공터)
  List<FacilityInfo> get _shown => [
        for (final f in VillageScreen.facilities)
          if (f.facility != Facility.tavern || controller.tavernOpen) f,
      ];

  /// 묶음 44 #225: 안 열린 건물의 공사 단계 (1~3, 없으면 null)
  int? _stage(Facility f) => controller.buildStage(f.name);

  /// 묶음 54: 건물 단계 (★) · 고치는 중
  int _star(Facility f) =>
      controller.buildingsOpen ? controller.facilityStar(f.name) : 1;
  bool _fixing(Facility f) => switch (BuildingRules.parse(f.name)) {
        final Building b? => controller.buildingsOpen && controller.buildingFixing(b),
        null => false,
      };

  /// 새 소식 (빨간 점): 게시판 보상 · 쉼터의 깨어날 알
  bool _news(Facility f) => switch (f) {
        Facility.board => controller.questRewardsReady > 0,
        Facility.shelter => controller.shelterOpen && controller.readyEgg != null,
        // 묶음 48 #230: 다 자란 칸
        Facility.garden => controller.gardenReady > 0,
        _ => false,
      };

  /// 묶음 43·48: 화면 밖 건물(훈련장·약초밭)이 완공되면 그쪽으로 맞춰 들어온다
  double? get _focusX {
    for (final f in const [Facility.garden, Facility.training]) {
      if (_built.contains(f)) {
        return VillageScreen.facilities.firstWhere((x) => x.facility == f).spot.x;
      }
    }
    return null;
  }

  /// 묶음 43 #228: 은은한 점 (오늘 하루 훈련 전)
  bool _soft(Facility f) =>
      f == Facility.training && controller.trainingDailyPending;

  /// 묶음 42 #226: 그 시설 마을 사람 (거래소는 없음)
  static Npc? npcOf(Facility f) => switch (f) {
        Facility.inn => Npc.marta,
        Facility.shop => Npc.mina,
        Facility.smithy => Npc.dorgun,
        Facility.alchemy => Npc.eliel,
        Facility.board => Npc.hart,
        Facility.guild => Npc.sera,
        Facility.shelter => Npc.lumi,
        Facility.training => Npc.garen,
        Facility.garden => Npc.popo,
        Facility.tavern => Npc.lian,
        Facility.market => Npc.barkan,
      };

  /// 「!」: 큰 부탁은 금빛, 특별한 부탁은 보랏빛 별, 작은 부탁은 하늘빛 (빨간 점과 따로)
  AskKind? _ask(Facility f) => switch (npcOf(f)) {
        final n? => controller.npcAskKind(n),
        null => null,
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

  /// 안 열린 건물 이름표 뒤 글 (#212): 「Lv.7」 · 「첫 펫」
  String _lockLabel(Facility f) => switch (f) {
        Facility.smithy => 'Lv.${AppController.featureLevel[Feature.smithy]}',
        Facility.board => 'Lv.${AppController.featureLevel[Feature.board]}',
        Facility.alchemy => 'Lv.${AppController.featureLevel[Feature.alchemy]}',
        Facility.guild => 'Lv.${JobRules.awakenLevel}',
        Facility.shelter => '첫 펫',
        Facility.training => 'Lv.${TrainingRules.openLevel}',
        Facility.garden => 'Lv.${GardenRules.openLevel}',
        _ => '',
      };

  void _enter(FacilityInfo f) {
    if (f.facility == Facility.market && !_open(f.facility)) {
      showTopNotice(context, '거래소는 준비 중이에요', icon: Icons.construction_rounded);
      return;
    }
    if (!_open(f.facility)) {
      // 묶음 44 #225: 짓는 중인 건물
      if (_stage(f.facility) != null) {
        showTopNotice(
            context,
            f.facility == Facility.shelter
                ? '짓는 중이에요 · 첫 펫과 함께 완공!'
                : '짓는 중이에요 · ${_lockLabel(f.facility)}에 완공!',
            icon: Icons.construction_rounded);
        return;
      }
      showTopNotice(
          context,
          f.facility == Facility.shelter
              ? '첫 펫과 함께 열려요'
              : '${_lockLabel(f.facility)}에 열려요',
          icon: Icons.lock_rounded);
      return;
    }
    final Widget page = switch (f.facility) {
      Facility.inn => InnScreen(controller: controller),
      Facility.shop => ShopScreen(controller: controller),
      Facility.smithy => SmithyScreen(controller: controller),
      Facility.alchemy => AlchemyScreen(controller: controller),
      Facility.guild => GuildScreen(controller: controller),
      Facility.shelter => ShelterScreen(controller: controller),
      Facility.training => TrainingScreen(controller: controller),
      Facility.garden => GardenScreen(controller: controller),
      Facility.tavern => TavernScreen(controller: controller),
      Facility.market => MarketScreen(controller: controller),
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
                                    child: Image.asset(f.assetAt(_star(f.facility)),
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox()),
                                  ),
                                  if (_news(f.facility))
                                    const Positioned(
                                        right: 4, top: 4, child: _RedDot()),
                                ]),
                              ),
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(f.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: AppColors.text,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    if (_star(f.facility) >= 2)
                                      StarMark(
                                          key: Key('allStar_${f.facility.name}'),
                                          star: _star(f.facility)),
                                  ]),
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
    final pad = MediaQuery.paddingOf(context);
    final open = _openList;
    // 시설이 12곳 넘게 생기면 「전체 ○」 (예시 모드는 미리 보기)
    final many = open.length >= VillageRules.wideFrom || c.villageWide;
    if (_intro == null && c.villageIntroPending) {
      // 처음 들어올 때 소개 (한 번만, 건너뛰기 가능)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _intro == null && c.villageIntroPending) {
          setState(() => _intro = 0);
        }
      });
    }
    final introLines = c.villageIntroLines;
    return ColoredBox(
      color: AppColors.deepNight,
      child: Stack(children: [
        Positioned.fill(
          child: _VillageArt(
            key: const Key('villageArt'),
            act: c.villageAct,
            all: _shown,
            open: _open,
            news: _news,
            ask: _ask,
            soft: _soft,
            stage: _stage,
            built: _built,
            star: _star,
            fixing: _fixing,
            starred: _starred,
            // 묶음 43: 화면 밖 건물(훈련장)이 완공되면 그쪽으로 맞춰 들어온다
            focusX: _focusX,
            lockLabel: _lockLabel,
            lighting: _lit,
            lightRun: _lightRun,
            towerGlow: _intro != null,
            bottomPad: pad.bottom,
            onTap: _enter,
            // 묶음 52 #243: 탑 옆 빛의 다리 (Lv.21 · 결말 뒤 만남을 지나면)
            onBridge: c.act3Available ? () => openJourney(context, c) : null,
          ),
        ),
        // 위쪽 버튼 뒤 살짝 어두운 그라데이션
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: pad.top + 120,
          child: const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xB30B0D26), Color(0x000B0D26)],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: pad.top + 6,
          child: Column(children: [
            const OrnateTopBar(title: '마을'),
            const SizedBox(height: 6),
            SpiritBadgeRow(
                key: const Key('villageGreeting'), line: _moment ?? _greeting),
          ]),
        ),
        if (many)
          Positioned(
            right: 14,
            bottom: pad.bottom + 22,
            child: _AllButton(
                count: open.length,
                news: open.any((f) => _news(f.facility)),
                onTap: _showAll),
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
      ]),
    );
  }
}

/// 마을 그림: 바탕 위에 건물을 한 채씩. 높이에 맞추고 처음부터 좌우로 끌어서 둘러본다
/// (양쪽 끝에서 멈춤, 아래 작은 위치 막대). 처음엔 건물 3×3 묶음 가운데.
class _VillageArt extends StatefulWidget {
  const _VillageArt({
    super.key,
    required this.act,
    required this.all,
    required this.open,
    required this.news,
    required this.ask,
    required this.soft,
    this.focusX,
    required this.stage,
    required this.built,
    this.star = _one,
    this.fixing = _no,
    this.starred = const {},
    required this.lockLabel,
    required this.lighting,
    this.lightRun = 0,
    required this.towerGlow,
    required this.bottomPad,
    required this.onTap,
    this.onBridge,
  });

  final int act;
  final List<FacilityInfo> all;
  final bool Function(Facility) open;
  final bool Function(Facility) news;
  final AskKind? Function(Facility) ask;

  /// 묶음 43 #228: 은은한 점 (빨간 점과 따로) · 처음 맞출 가로 자리 (그림 픽셀)
  final bool Function(Facility) soft;
  final double? focusX;

  /// 묶음 44 #225: 안 열린 건물의 공사 단계 · 이번에 완공 연출을 볼 건물
  final int? Function(Facility) stage;
  final Set<Facility> built;
  final String Function(Facility) lockLabel;

  /// 묶음 54: 건물 단계 · 고치는 중 · 이번에 레벨업 연출을 볼 건물
  final int Function(Facility) star;
  final bool Function(Facility) fixing;
  final Set<Facility> starred;
  static int _one(Facility _) => 1;
  static bool _no(Facility _) => false;

  /// 결말 뒤 처음: 탑 불꽃이 켜지는 연출
  final bool lighting;

  /// 묶음 51: 방문마다 탑 불꽃 연출을 다시 시작하는 번호
  final int lightRun;

  /// 소개 중: 탑을 금빛 테두리로
  final bool towerGlow;

  /// 아래 탭 막대 높이 (그림이 그 아래까지 깔린다)
  final double bottomPad;
  final ValueChanged<FacilityInfo> onTap;

  /// 묶음 52 #243: 빛의 다리 이름표 (3막으로)
  final VoidCallback? onBridge;

  @override
  State<_VillageArt> createState() => _VillageArtState();
}

class _VillageArtState extends State<_VillageArt> {
  final _scroll = ScrollController();
  /// 마지막으로 가운데 맞춘 화면 크기 (탭을 옮겨 높이가 바뀌면 다시 맞춤)
  Size? _placedFor;

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, h = box.maxHeight;
      const art = VillageScreen.art;
      const cl = VillageScreen.cluster;
      // 높이에 맞춘다 (아주 넓은 화면이면 폭에 맞추고 위아래를 조금 자름)
      final s = math.max(h / art.height, w / art.width);
      final fullW = art.width * s;
      final fullH = art.height * s;
      // 위아래가 남으면 3×3 묶음이 가운데 오게
      final oy = (h / 2 - cl.center.dy * s).clamp(h - fullH, 0.0);
      if (_placedFor != Size(w, h)) {
        _placedFor = Size(w, h);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(
                ((widget.focusX ?? cl.center.dx) * s - w / 2).clamp(0.0, _max));
          }
        });
      }
      return Stack(children: [
        SingleChildScrollView(
          key: const Key('villageScroll'),
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: const ClampingScrollPhysics(),
          child: SizedBox(
              width: fullW, height: h, child: _scene(s, Offset(0, oy), w)),
        ),
        // 아래 작은 위치 막대
        if (fullW > w + 1)
          Positioned(
            left: w * 0.32,
            right: w * 0.32,
            bottom: widget.bottomPad + 8,
            child: IgnorePointer(
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
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0x88000000),
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
          ),
      ]);
    });
  }

  /// 바탕 + 건물 (그림 픽셀 → 화면: ×[s], [o] 만큼 옮김)
  Widget _scene(double s, Offset o, double viewW) {
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
      // 결말 뒤 처음: 탑 불꽃이 켜진다 (1초쯤)
      if (widget.lighting)
        Positioned.fromRect(
          key: const Key('towerLight'),
          rect: r(t.left - 120, t.top - 60, t.width + 240, t.height + 120),
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(widget.lightRun),
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
      // 2막: 잿빛 안개는 그림과 같이 움직이지 않고 화면 가장자리에 고정 (건물·이름표 아래)
      if (widget.act == 2)
        AnimatedBuilder(
          key: const Key('villageFog'),
          animation: _scroll,
          builder: (context, child) => Positioned(
            left: _scroll.hasClients ? _scroll.offset : 0,
            top: 0,
            bottom: 0,
            width: viewW,
            child: child!,
          ),
          child: IgnorePointer(
            child: Image.asset('assets/images/village_fog.webp',
                fit: BoxFit.fill,
                errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        ),
      for (final f in widget.all) _building(f, r),
      // 건물 이름표 (#212): 건물 아래쪽 가운데, 건물보다 위에
      for (final f in widget.all) _tag(f, r),
      if (widget.onBridge != null && widget.act == 3) _bridgeTag(r),
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
    final stage = open ? null : widget.stage(f.facility);
    final dim = !open && f.facility != Facility.market && stage == null;
    Widget pic = Image.asset(
        stage != null
            ? f.buildAsset(stage)
            : f.facility == Facility.market && !open
                ? FacilityInfo.marketBuild
                : f.assetAt(open ? widget.star(f.facility) : 1),
        key: stage != null ? Key('build${stage}_${f.facility.name}') : null,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const SizedBox());
    // 묶음 44 #225: 열린 뒤 처음 → 공사 그림이 완공 그림으로 바뀌며 금빛으로 반짝 (1초쯤)
    if (open && widget.built.contains(f.facility)) {
      pic = _BuiltReveal(
          key: Key('builtReveal_${f.facility.name}'),
          from: f.buildAsset(3),
          to: pic,
          name: f.name);
    } else if (open && widget.starred.contains(f.facility)) {
      // 묶음 54: 레벨업 → 앞 단계 그림이 새 그림으로 바뀌며 금빛 + 「여관 ★2!」
      final s = widget.star(f.facility);
      pic = _BuiltReveal(
          key: Key('starReveal_${f.facility.name}'),
          from: f.assetAt(s - 1),
          to: pic,
          name: f.name,
          label: '${f.name} ★$s!');
    }
    if (dim) {
      pic = ColorFiltered(
        colorFilter: const ColorFilter.mode(Color(0xFF3A3A55), BlendMode.modulate),
        child: pic,
      );
    }
    // 누르는 곳은 건물 가운데 부분만 (이웃 건물과 겹친 투명한 둘레는 빼고)
    return Positioned.fromRect(
      key: Key('building_${f.facility.name}'),
      rect: rect,
      child: Stack(children: [
        Positioned.fill(child: IgnorePointer(child: pic)),
        Positioned.fromRect(
          rect: Rect.fromLTWH(rect.width * 0.1, rect.height * 0.12,
              rect.width * 0.8, rect.height * 0.88),
          child: Semantics(
            button: true,
            label: f.name,
            child: GestureDetector(
              // 열린 시설만 안내·시험이 찾는 이름 (facility_○○)
              key: open ? Key('facility_${f.facility.name}') : null,
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTap(f),
            ),
          ),
        ),
      ]),
    );
  }

  /// 건물 이름표 (#212): 열린 건물 「여관」 · 안 열린 건물 「🔒 연금술 공방 · Lv.7」 ·
  /// 거래소 「거래소 · 준비 중」. 빨간 점은 이름표 오른쪽 위
  /// 빛의 다리 (탑 오른쪽 뒤 그림 자리)
  Widget _bridgeTag(Rect Function(double, double, double, double) r) {
    final at = r(VillageScreen.bridge.dx, VillageScreen.bridge.dy, 0, 0);
    const half = 70.0;
    return Positioned(
      left: at.left - half,
      width: half * 2,
      top: at.top,
      child: Center(
        child: GestureDetector(
          key: const Key('tag_bridge'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onBridge,
          child: Container(
            padding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
            decoration: BoxDecoration(
              color: const Color(0xE61A1636),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.goldBright, width: 1.2),
              boxShadow: [
                BoxShadow(color: AppColors.gold.withValues(alpha: 0.6), blurRadius: 8),
              ],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.goldBright),
              SizedBox(width: 3),
              Text('빛의 다리',
                  style: TextStyle(
                      color: AppColors.text, fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tag(FacilityInfo f, Rect Function(double, double, double, double) r) {
    final open = widget.open(f.facility);
    // 묶음 51: 거래소는 완공되면 다른 건물과 같은 이름표
    final market = f.facility == Facility.market && !open;
    final sp = f.spot;
    final bottom = r(sp.x, sp.y, 0, 0);
    // 묶음 44 #225: 짓는 중인 건물은 🔨 + 「Lv.7 완공」 (펫 쉼터 「첫 펫과 함께 완공」)
    final building = !open && !market && widget.stage(f.facility) != null;
    // 안 열린 건물·거래소는 두 줄 (이름 / 열리는 때) — 작은 화면에서도 옆 이름표와 겹치지 않게
    final star = open ? widget.star(f.facility) : 1;
    final fixing = open && widget.fixing(f.facility);
    final sub = market
        ? '준비 중'
        : open
            ? (fixing ? '고치는 중' : null)
            : building
                ? f.facility == Facility.shelter
                    ? '첫 펫과 함께\n완공'
                    : '${widget.lockLabel(f.facility)} 완공'
                : widget.lockLabel(f.facility);
    const half = 80.0;
    return Positioned(
      left: bottom.left - half,
      width: half * 2,
      top: bottom.top - 14,
      child: Center(
        child: GestureDetector(
          key: Key(market
              ? 'tag_market'
              : open
                  ? 'tag_${f.facility.name}'
                  : 'locked_${f.facility.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTap(f),
          child: Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: EdgeInsets.fromLTRB(building ? 5 : 7, 2, building ? 5 : 7, 2),
              decoration: BoxDecoration(
                color: open
                    ? const Color(0xE61A1636)
                    : const Color(0xD9101024),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: open
                        ? AppColors.goldBright
                        : AppColors.gold.withValues(alpha: 0.5),
                    width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x88000000), blurRadius: 4),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (!open && !market) ...[
                    Icon(
                        building
                            ? Icons.construction_rounded
                            : Icons.lock_rounded,
                        size: 10,
                        color: building
                            ? AppColors.gold
                            : AppColors.textMuted),
                    const SizedBox(width: 2),
                  ],
                  Text(f.name,
                      maxLines: 1,
                      style: TextStyle(
                          color:
                              open ? AppColors.goldBright : const Color(0xFFCFC6E0),
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w800)),
                  // 묶음 54: 건물 단계 ★
                  if (star >= 2) ...[
                    const SizedBox(width: 2),
                    StarMark(key: Key('tagStar_${f.facility.name}'), star: star),
                  ],
                ]),
                if (sub != null)
                  Text(sub,
                      key: Key(fixing
                          ? 'tagFixing_${f.facility.name}'
                          : 'tagSub_${f.facility.name}'),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: building ? 9 : 9.5,
                          height: 1.15,
                          fontWeight: FontWeight.w700)),
              ]),
            ),
            // 묶음 43 #228: 오늘 하루 훈련 전이면 은은한 금빛 점 (왼쪽 위)
            if (open && widget.soft(f.facility) && !widget.news(f.facility))
              Positioned(
                  key: Key('soft_${f.facility.name}'),
                  left: -5,
                  top: -5,
                  child: const SoftDot()),
            if (open && widget.news(f.facility))
              Positioned(
                  left: widget.ask(f.facility) != null ? -5 : null,
                  right: widget.ask(f.facility) != null ? null : -5,
                  top: -6,
                  child: const _RedDot()),
            // 묶음 42 #226: 부탁 「!」 (오른쪽 위, 빨간 점은 왼쪽으로)
            if (widget.ask(f.facility) case final k? when open)
              Positioned(
                  key: Key('ask_${f.facility.name}'),
                  right: -7,
                  top: -8,
                  child: _AskMark(kind: k)),
          ]),
        ),
      ),
    );
  }
}

/// 묶음 44 #225: 완공 연출 — 공사 그림이 완공 그림으로 바뀌며 금빛으로 반짝 + 「○○ 완공!」
class _BuiltReveal extends StatelessWidget {
  const _BuiltReveal(
      {super.key, required this.from, required this.to, required this.name, this.label});

  final String from;
  final Widget to;
  final String name;

  /// 띄울 글 (없으면 「○○ 완공!」)
  final String? label;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1600),
        builder: (context, k, _) {
          // 0~0.6 공사 → 완공, 반짝임은 가운데에서 가장 밝게, 글자는 끝까지 남다가 사라짐
          final swap = (k / 0.6).clamp(0.0, 1.0);
          final glow = math.sin(k * math.pi);
          final label = k < 0.85 ? 1.0 : (1 - (k - 0.85) / 0.15);
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: glow * 0.9,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(colors: [
                        Color(0xFFFFF1B8),
                        Color(0x88FFC94A),
                        Color(0x00FFC94A),
                      ], stops: [0, 0.4, 1]),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 1 - swap,
                child: Image.asset(from,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox()),
              ),
            ),
            Positioned.fill(child: Opacity(opacity: swap, child: to)),
            Positioned(
              left: -40,
              right: -40,
              top: -6 - 10 * k,
              child: Opacity(
                opacity: label.clamp(0.0, 1.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 3),
                    decoration: BoxDecoration(
                      color: const Color(0xE61A1636),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.goldBright),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.7),
                            blurRadius: 10),
                      ],
                    ),
                    child: Text(this.label ?? '$name 완공!',
                        maxLines: 1,
                        style: const TextStyle(
                            color: AppColors.goldBright,
                            fontSize: 12,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
          ]);
        },
      );
}

class _AskMark extends StatelessWidget {
  const _AskMark({required this.kind});

  final AskKind kind;

  @override
  Widget build(BuildContext context) {
    final look = askLook(kind);
    return Container(
      key: Key('askKind_${kind.name}'),
      width: 15,
      height: 15,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: look.fill,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
        shape: BoxShape.circle,
        border: Border.all(color: look.edge, width: 1.2),
        boxShadow: [BoxShadow(color: look.glow, blurRadius: 6)],
      ),
      child: kind == AskKind.special
          ? Icon(Icons.star_rounded, size: 11, color: look.ink)
          : Text('!',
              style: TextStyle(
                  color: look.ink,
                  fontSize: 11,
                  height: 1.0,
                  fontWeight: FontWeight.w900)),
    );
  }
}

/// 은은한 금빛 점 (묶음 43: 오늘 할 일이 남았을 때, 빨간 점보다 약하게)
class SoftDot extends StatelessWidget {
  const SoftDot({super.key, this.size = 9});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xCCF3D27A),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x88F3D27A), blurRadius: 5)],
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

/// 오른쪽 아래 「전체 ○」 (시설 12곳부터)
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

/// 묶음 54: 건물 단계 표시 (작은 금빛 별을 단계 수만큼)
class StarMark extends StatelessWidget {
  const StarMark({super.key, required this.star, this.size = 10});

  final int star;
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < star; i++)
          Icon(Icons.star_rounded, size: size, color: AppColors.goldBright),
      ]);
}
