import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../core/format.dart';
import '../../app_controller.dart';
import '../../core/geo/geo.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../battle/modifier_view.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/bulssi_lines.dart';
import '../bulssi/spirit_art.dart';
import '../harvest/harvest_sheet.dart';
import '../town/bag_tab.dart' show showMerchantSheet;
import '../town/material_view.dart';
import 'expedition_sheet.dart';
import '../alchemy/alchemy_screen.dart' show PotionIcon;
import '../../core/models/alchemy_state.dart' show ActiveBuff;
import '../../core/models/pet_state.dart' show Pet;
import '../../core/models/vitals.dart' show Expedition;
import 'map_config.dart';
import '../../theme/top_notice.dart';
import '../tutorial/targets.dart';
import '../lens/lens_screen.dart' show openLens;
import '../jobs/job_skill_bar.dart';
import '../act2/ash_battle_screen.dart' show openRift;
import '../highland/highland_screen.dart' show openSkyIsland;
import '../act3/act3_screen.dart' show openJourney;

part 'map_overlays.dart';
part 'naver_map_layer.dart';

/// 지도: 내 둘레의 필드 몬스터 · 정령 · 내 위치 (11-10 전국, 안개 없음)
///
/// 11-11 #76~#78: 위쪽 「내 주변」 박스를 없애 지도를 넓게. 아래는 던전 띠 + 원정 한 줄 띠,
/// 지도의 내 위치 버튼·NAVER 로고·축척은 늘 그 위에 오도록 지도 여백을 띠 높이만큼 올린다.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.controller,
    this.onOpenDungeon,
    this.onShowExpeditionResults,
    this.onOpenBag,
  });

  final AppController controller;

  /// 가방 탭으로 (튜토리얼: 받은 것 보기)
  final VoidCallback? onOpenBag;

  /// 던전 열기 (11-11 #68: 상태 화면에서 지도 아래 띠로 옮겼다)
  final VoidCallback? onOpenDungeon;

  /// 돌아온 원정 결과 카드 보기 (11-11 #78: 띠를 눌러서)
  final VoidCallback? onShowExpeditionResults;

  /// 아래 던전 띠 높이
  static const double stripH = 58;

  /// 원정 한 줄 띠 높이 (던전 띠보다 낮게)
  static const double expStripH = 44;

  /// 펼친 원정 카드 하나의 높이
  static const double expCardH = 68;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _expOpen = false;

  AppController get controller => widget.controller;

  // 묶음 66 #267: 몬스터 칸이 바뀌는 때 (30초마다 확인, 바뀌면 짧게 사라졌다 나타남)
  Timer? _slotTimer;
  late String _slot;
  bool _slotFade = false;

  @override
  void initState() {
    super.initState();
    _slot = controller.spawnSlot;
    _slotTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkSlot());
  }

  @override
  void dispose() {
    _slotTimer?.cancel();
    super.dispose();
  }

  void _checkSlot() {
    if (!mounted) return;
    final now = controller.spawnSlot;
    if (now == _slot) {
      setState(() {}); // 남은 시간 줄
      return;
    }
    _slot = now;
    // 묶음 67: 지도를 보고 있을 때만 위쪽 띠 한 번 (다른 탭 · 다른 화면이 위에 있으면 안 띄움)
    final onMap = TickerMode.valuesOf(context).enabled && (ModalRoute.of(context)?.isCurrent ?? true);
    if (onMap) showTopNotice(context, '새 몬스터가 나타났어요!', icon: Icons.pets_rounded);
    setState(() => _slotFade = true);
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      controller.spawnSlotChanged();
      setState(() => _slotFade = false);
    });
  }

  /// 원정 하나를 바로 돌아오게 할지 묻는다 (묶음 18 #151). 돌아오면 결과 카드
  Future<void> _rush(Expedition ex) async {
    final done = await showRushSheet(context, controller, ex);
    if (done && mounted) widget.onShowExpeditionResults?.call();
  }

  void _closeExp() {
    if (_expOpen && mounted) setState(() => _expOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final gauge = controller.player.gauge;
    final spawn = controller.nearbySpawn;
    final actives = controller.activeExpeditions;
    final returned = controller.finishedExpeditions;
    final away = actives.isNotEmpty || returned.isNotEmpty;
    final top = MediaQuery.paddingOf(context).top;
    final buffs = controller.activeBuffs;
    // 아래에서부터 쌓이는 것들: 던전 띠 → 원정 띠(펼치면 카드) → 몬스터·발견 카드
    final expH = !away
        ? 0.0
        : _expOpen && actives.isNotEmpty && returned.isEmpty
            ? math.min(MapScreen.expStripH + 4 + MapScreen.expCardH * actives.length,
                MediaQuery.sizeOf(context).height * 0.5)
            : MapScreen.expStripH;
    // 묶음 78 #360: 원정 목록을 펼친 동안 (뒤 지도 어둡게 · 돋보기 · 칩은 숨김)
    final expOpen = _expOpen && actives.isNotEmpty && returned.isEmpty;
    const expBottom = MapScreen.stripH + 2;
    final cardBottom = expBottom + (away ? expH + 6 : 0);
    final card = controller.lastDiscovery != null || spawn != null;
    final coverBottom = cardBottom + (card ? 150 : 0) + 4;
    // 위쪽: 프로필·설정 버튼 줄 (+ 걸린 물약이 있으면 작은 줄)
    // 묶음 20 #158: 프로필·정령 배지·우편·설정 아래까지 (그 뒤에 몬스터·채집이 숨지 않게)
    final coverTop = top + 112 + (buffs.isEmpty ? 0 : 34);
    final tut = controller.inTutorial;
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedOpacity(
            opacity: _slotFade ? 0.35 : 1,
            duration: const Duration(milliseconds: 350),
            child: naverMapEnabled
              ? _NaverMapLayer(
                  controller: controller,
                  safeTop: coverTop,
                  safeBottom: coverBottom,
                  onUserMove: _closeExp,
                  onRush: _rush,
                )
              : _ExploreSummary(controller: controller),
          ),
        ),
        // 상태 표시줄 뒤로 몬스터 이름표가 비치지 않게 가린다 (11-11 #43)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: top,
          child: const IgnorePointer(
            child: ColoredBox(color: Color(0xE60B0D26)),
          ),
        ),
        // 묶음 16 #126: 상태 화면의 정령 한마디를 지도 구석에도 작게
        // 묶음 33 #199: 기능 안내(손가락) 중에는 배지 말풍선을 띄우지 않는다
        if (!controller.inTutorial &&
            !controller.guideTourActive &&
            controller.player.today != null)
          Positioned(
            left: 14, // 프로필 동그라미와 같은 줄
            top: top + 64,
            child: _SpiritCorner(controller: controller),
          ),
        // 걸린 물약만 작게 (11-11 #76). 없으면 아무것도 띄우지 않는다
        if (!tut && (buffs.isNotEmpty || controller.tired))
          Positioned(
            left: 70,
            right: 70,
            top: top + 114,
            child: _BuffBar(controller: controller, buffs: buffs),
          ),
        // 묶음 77 #354: 기력 칩 — 위쪽 버튼 줄 아래 오른쪽 고정 (몬스터 · 채집 아이콘을 덮지 않게)
        if (!tut && controller.player.today != null)
          Positioned(
            right: 14,
            top: top + 62,
            child: _JobMapButton(controller: controller),
          ),
        if (expOpen)
          Positioned.fill(
            child: GestureDetector(
              key: const Key('expeditionBackdrop'),
              onTap: _closeExp,
              child: const ColoredBox(color: Color(0x77000000)),
            ),
          ),
        if (away)
          Positioned(
            left: 12,
            right: 12,
            bottom: expBottom,
            child: KeyedSubtree(
              key: tutorialStripKey,
              child: ExpeditionStrip(
                controller: controller,
                open: _expOpen,
                onToggle: () => setState(() => _expOpen = !_expOpen),
                onRush: _rush,
                onShowResults: widget.onShowExpeditionResults,
              ),
            ),
          ),
        // 묶음 18 #148: 튜토리얼 중에는 아래 몬스터 카드·발견 카드·던전 띠를 숨긴다
        if (!tut && controller.lastDiscovery != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: cardBottom,
            child: _DiscoveryCard(
              place: controller.lastDiscovery!,
              onClose: controller.clearDiscovery,
            ),
          )
        else if (!tut && spawn != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: cardBottom,
            child: _MonsterCard(
              spawn: spawn,
              onPurify: () => showSpawnSheet(context, controller, spawn),
            ),
          ),
        // 묶음 19 #154: 돋보기 (Lv.6부터, 내 위치 버튼 반대편 오른쪽 아래)
        if (!tut && !expOpen && controller.featureOpen(Feature.lens))
          Positioned(
            right: 12,
            bottom: (card ? cardBottom + 150 : cardBottom) + 8,
            child: KeyedSubtree(
              key: tutorialLensKey,
              child: _LensButton(controller: controller),
            ),
          ),
        // 묶음 52 #243: 3막 「여정」 (돋보기 위)
        if (!tut && !expOpen && controller.act3Available)
          Positioned(
            right: 12,
            bottom: (card ? cardBottom + 150 : cardBottom) +
                8 +
                (controller.featureOpen(Feature.lens) ? 62 : 0),
            child: _JourneyButton(controller: controller),
          ),
        // 묶음 66 #267: 몬스터가 바뀌기까지 (던전 띠 바로 위 왼쪽 작은 줄)
        if (!tut && !expOpen)
          Positioned(
            left: 12,
            bottom: (away ? cardBottom - 6 : MapScreen.stripH) + (card ? 150 : 0) + 2,
            child: IgnorePointer(
              child: Container(
                key: const Key('spawnSlotLine'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xCC141638),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(controller.spawnSlotText,
                      style: const TextStyle(color: AppColors.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        // 던전 게이지·열쇠·던전 열기 (11-11 #68): 아래 메뉴 바로 위 얇은 띠
        if (!tut)
        Positioned(
          left: 10,
          right: 10,
          bottom: 4,
          height: MapScreen.stripH - 8,
          child: DungeonStrip(
            gauge: gauge,
            onOpen: widget.onOpenDungeon,
          ),
        ),
      ],
    );
  }
}
