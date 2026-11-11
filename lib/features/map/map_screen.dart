import 'dart:math' as math;

import 'package:flutter/material.dart';
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
import '../bulssi/spirit_art.dart';
import '../harvest/harvest_sheet.dart';
import '../town/bag_tab.dart' show showMerchantSheet;
import '../town/material_view.dart';
import 'expedition_sheet.dart';
import '../alchemy/alchemy_screen.dart' show PotionIcon;
import '../../core/models/alchemy_state.dart' show ActiveBuff;
import 'map_config.dart';
import '../../theme/top_notice.dart';

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
  });

  final AppController controller;

  /// 던전 열기 (11-11 #68: 상태 화면에서 지도 아래 띠로 옮겼다)
  final VoidCallback? onOpenDungeon;

  /// 돌아온 원정 결과 카드 보기 (11-11 #78: 띠를 눌러서)
  final VoidCallback? onShowExpeditionResults;

  /// 아래 던전 띠 높이
  static const double stripH = 58;

  /// 원정 한 줄 띠 높이 (던전 띠보다 낮게)
  static const double expStripH = 44;

  /// 펼친 원정 카드 하나의 높이
  static const double expCardH = 86;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _expOpen = false;

  AppController get controller => widget.controller;

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
        : _expOpen && actives.isNotEmpty
            ? MapScreen.expCardH * actives.length + 8
            : MapScreen.expStripH;
    final expBottom = MapScreen.stripH + 2;
    final cardBottom = expBottom + (away ? expH + 6 : 0);
    final card = controller.lastDiscovery != null || spawn != null;
    final coverBottom = cardBottom + (card ? 150 : 0) + 4;
    // 위쪽: 프로필·설정 버튼 줄 (+ 걸린 물약이 있으면 작은 줄)
    final coverTop = top + 58 + (buffs.isEmpty ? 0 : 34);
    return Stack(
      children: [
        Positioned.fill(
          child: naverMapEnabled
              ? _NaverMapLayer(
                  controller: controller,
                  safeTop: coverTop,
                  safeBottom: coverBottom,
                  onUserMove: _closeExp,
                )
              : _ExploreSummary(controller: controller),
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
        // 걸린 물약만 작게 (11-11 #76). 없으면 아무것도 띄우지 않는다
        if (buffs.isNotEmpty || controller.tired)
          Positioned(
            left: 70,
            right: 70,
            top: top + 62,
            child: _BuffBar(controller: controller, buffs: buffs),
          ),
        if (away)
          Positioned(
            left: 12,
            right: 12,
            bottom: expBottom,
            child: ExpeditionStrip(
              controller: controller,
              open: _expOpen,
              onToggle: () => setState(() => _expOpen = !_expOpen),
              onShowResults: widget.onShowExpeditionResults,
            ),
          ),
        if (controller.lastDiscovery != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: cardBottom,
            child: _DiscoveryCard(
              place: controller.lastDiscovery!,
              onClose: controller.clearDiscovery,
            ),
          )
        else if (spawn != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: cardBottom,
            child: _MonsterCard(
              spawn: spawn,
              onPurify: () => showSpawnSheet(context, controller, spawn),
            ),
          ),
        // 던전 게이지·열쇠·던전 열기 (11-11 #68): 아래 메뉴 바로 위 얇은 띠
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

/// 지금 걸린 물약 (11-11 #76): 작은 아이콘 + 남은 시간·전투·걸음
class _BuffBar extends StatelessWidget {
  const _BuffBar({required this.controller, required this.buffs});

  final AppController controller;
  final List<ActiveBuff> buffs;

  @override
  Widget build(BuildContext context) => Center(
        child: Wrap(
          key: const Key('mapBuffs'),
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            // 지친 상태 (11-11 #75): 패배 뒤 1시간, 여관에서 쉬면 풀림
            if (controller.tired) TiredBadge(controller: controller),
            for (final b in buffs)
              Container(
                padding: const EdgeInsets.fromLTRB(3, 2, 8, 2),
                decoration: BoxDecoration(
                  color: const Color(0xE60B0D26),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PotionIcon(
                      potion: AlchemyRules.byName(b.key),
                      suspicious: b.key.startsWith('?:'),
                      size: 22),
                  const SizedBox(width: 3),
                  Text(controller.buffLeftLabel(b).replaceAll(' 남음', ''),
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        ),
      );
}

/// 「지친 상태」 표시 (11-11 #75). 누르면 정령(펫)의 한마디.
class TiredBadge extends StatelessWidget {
  const TiredBadge({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: const Key('tiredBadge'),
        onTap: () => showTopNotice(context, AppController.tiredLine),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 3, 9, 3),
          decoration: BoxDecoration(
            color: const Color(0xE63A1630),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE07A7A)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.bedtime_rounded, size: 16, color: Color(0xFFF2B0B0)),
            SizedBox(width: 3),
            Text('지친 상태',
                style: TextStyle(
                    color: Color(0xFFF7D2D2),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

/// 지도 아래 던전 띠: 열쇠 · 게이지 · [던전 열기] (11-11 #68)
class DungeonStrip extends StatelessWidget {
  const DungeonStrip({super.key, required this.gauge, this.onOpen});

  final DungeonGaugeState gauge;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final keys = gauge.keysAvailable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141638),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.7)),
      ),
      child: Row(children: [
        const GameIcon('key', size: 24),
        const SizedBox(width: 4),
        Text('열쇠 $keys',
            key: const Key('stripKeys'),
            style: const TextStyle(
                color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlowBar(ratio: gauge.ratio, colors: BarColors.gauge, height: 7),
              const SizedBox(height: 2),
              Text(
                  gauge.dailyKeyLimitReached
                      ? '오늘은 다 모았어요'
                      : '${comma(gauge.stepsIntoNextKey)} / ${comma(gauge.stepsPerKey)}보',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // 열쇠가 있으면 금색으로 빛나고, 없으면 흐리게
        TextButton(
          key: const Key('openDungeon'),
          style: gameButtonStyle(gold: true).copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(92, 38)),
            padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 14)),
            textStyle: const WidgetStatePropertyAll(TextStyle(
                fontFamily: 'Title', fontWeight: FontWeight.w700, fontSize: 15)),
            shadowColor: WidgetStatePropertyAll(AppColors.gold),
            elevation: WidgetStateProperty.resolveWith(
                (s) => s.contains(WidgetState.disabled) ? 0 : 6),
          ),
          onPressed: keys > 0 ? onOpen : null,
          child: const Text('던전 열기', maxLines: 1),
        ),
      ]),
    );
  }
}

/// 장소 종류별 지도 표시 그림
String placeIconAsset(PlaceKind kind) => switch (kind) {
      PlaceKind.labyrinthGate => 'assets/images/map_gate.png',
      PlaceKind.spiritLake => 'assets/images/map_lake.png',
    };

// ───────────────────────────────────────────── 새 장소 발견

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({required this.place, required this.onClose});

  final GamePlace place;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.night,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KText('새 장소 발견! · ${place.name}',
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            KText('현실: ${place.realName} · 경험치 +${RuleConstants.newPlaceExp}',
                style: const TextStyle(color: AppColors.textMuted)),
            const SizedBox(height: 12),
            BulssiLine(line: _discoveryLine(place.kind)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    minimumSize: const Size(64, 44)),
                child: const Text('좋아'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _discoveryLine(PlaceKind kind) => switch (kind) {
        PlaceKind.labyrinthGate => '여기가 미궁 입구야! 여기서 던전을 열면 보상이 1.5배야.',
        PlaceKind.spiritLake => '물의 정령들이 반짝이고 있어. 비 오는 날엔 더 많아진대!',
      };
}

// ───────────────────────────────────────────── 필드 몬스터 만남

class _MonsterCard extends StatelessWidget {
  const _MonsterCard({required this.spawn, required this.onPurify});

  final FieldSpawn spawn;
  final VoidCallback onPurify;

  @override
  Widget build(BuildContext context) {
    final info = spawn.info;
    return Material(
      color: AppColors.night,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.gauge, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          MonsterPicture(monster: info.id, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${josa(spawn.name, '이/가')} 나타났어!',
                    style: TextStyle(
                        color: spawn.modifiers.isEmpty
                            ? AppColors.goldBright
                            : modGradeColor(spawn.grade),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const KText('멈춰 선 다음 사냥해 주세요',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          FilledButton(
            onPressed: onPurify,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gauge,
              foregroundColor: AppColors.night,
              minimumSize: const Size(88, 48),
            ),
            child: const Text('사냥하기'),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────────────────────────── 지도 없이 보는 탐험 현황

/// 네이버 지도 Client ID 가 없을 때(테스트, 설정 전) 보여 주는 화면
class _ExploreSummary extends StatelessWidget {
  const _ExploreSummary({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final visited = controller.everVisitedPlaceIds;
    final fix = controller.lastFix;
    return NightBackground(
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.paddingOf(context).top + 140, 16, 24),
        children: [
          const BulssiLine(
              line: '지도를 열려면 네이버 지도 키가 필요해. 그동안은 탐험 기록을 보여 줄게!'),
          const SizedBox(height: 16),
          if (fix != null)
            KText(
              '현재 위치 ${fix.point.lat.toStringAsFixed(4)}, '
              '${fix.point.lng.toStringAsFixed(4)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          KText(
            '오늘 남은 몬스터 ${controller.todaySpawns.length}마리 · '
            '가까이(${RuleConstants.fieldEncounterRadiusM.round()}m) 가면 만날 수 있어요',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _ExpeditionList(controller: controller),
          const SizedBox(height: 12),
          for (final place in controller.area.places)
            ListTile(
              leading: Image.asset(
                visited.contains(place.id)
                    ? placeIconAsset(place.kind)
                    : 'assets/images/map_unknown.png',
                width: 44,
                height: 44,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.place_rounded,
                    color: AppColors.gold),
              ),
              title: Text(
                visited.contains(place.id) ? place.name : '???',
                style: const TextStyle(color: AppColors.text),
              ),
              subtitle: Text(place.realName,
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────── 네이버 지도

class _NaverMapLayer extends StatefulWidget {
  const _NaverMapLayer({
    required this.controller,
    this.safeTop = 0,
    this.safeBottom = 0,
    this.onUserMove,
  });

  final AppController controller;

  /// 사용자가 지도를 움직이거나 눌렀을 때 (원정 띠 접기, 11-11 #78)
  final VoidCallback? onUserMove;

  /// 위 패널·아래 카드가 덮는 높이. 그 뒤에 숨은 몬스터는 가장자리 표시로 알린다.
  final double safeTop;
  final double safeBottom;

  @override
  State<_NaverMapLayer> createState() => _NaverMapLayerState();
}

class _NaverMapLayerState extends State<_NaverMapLayer> {
  NaverMapController? _map;
  int _drawnSpawns = -1;
  String? _drawnFix;
  String? _drawnSpirit;
  String? _drawnMerchant;

  static NLatLng _ll(GeoPoint p) => NLatLng(p.lat, p.lng);

  @override
  void didUpdateWidget(covariant _NaverMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _redraw();
    _focusRequested();
  }

  /// 위쪽 띠에서 「상인 보기」를 눌렀을 때 그 자리로 (11-11 #84)
  Future<void> _focusRequested() async {
    final map = _map;
    if (map == null) return;
    final p = widget.controller.takeMapFocus();
    if (p == null) return;
    try {
      await map.updateCamera(
          NCameraUpdate.scrollAndZoomTo(target: _ll(p), zoom: 16));
    } catch (_) {}
  }

  /// 장소·몬스터·내 위치를 다시 그린다 (바뀐 게 있을 때만)
  Future<void> _redraw() async {
    final map = _map;
    if (map == null) return;
    final c = widget.controller;
    final fix = c.lastFix;
    final fixKey = fix == null
        ? null
        : '${fix.point.lat.toStringAsFixed(5)},${fix.point.lng.toStringAsFixed(5)}';
    final spawns = c.todaySpawns;
    final actives = c.activeExpeditions;
    final positions = [for (final e in actives) e.positionAt(c.now)];
    final spiritKey = positions.isEmpty
        ? null
        : positions
            .map((p) => '${p.$1.toStringAsFixed(4)},${p.$2.toStringAsFixed(4)}')
            .join('|');
    final merchantAt = c.merchantPoint;
    final merchantKey =
        merchantAt == null ? null : '${c.merchantMinutesLeft}';
    if (_drawnSpawns == spawns.length &&
        _drawnFix == fixKey &&
        _drawnSpirit == spiritKey &&
        _drawnMerchant == merchantKey) {
      return;
    }
    _drawnSpawns = spawns.length;
    _drawnFix = fixKey;
    _drawnSpirit = spiritKey;
    _drawnMerchant = merchantKey;

    final area = c.area;
    final visited = c.everVisitedPlaceIds;

    _sized.clear();
    final overlays = <NAddableOverlay>{
      for (final place in area.places)
        NMarker(
          id: 'place_${place.id}',
          position: _ll(place.point),
          icon: NOverlayImage.fromAssetImage(visited.contains(place.id)
              ? placeIconAsset(place.kind)
              : 'assets/images/map_unknown.png'),
          size: const Size(46, 46),
          caption: NOverlayCaption(
            text: visited.contains(place.id) ? place.name : '???',
          ),
        ),
      // 시내 전체에 몬스터가 많아 이름은 빼고 그림만. 수식어 몬스터만 수식어를
      // 등급 색으로 보여 준다 (11-10 #21). 누르면 직접 사냥·정령 보내기
      for (final spawn in spawns)
        _monster(c, spawn, fix?.point),
      // 채집 자리 (11-11 #56): 1.5km 안, 남은 횟수는 점으로
      for (final h in c.harvestSpots)
        if (fix == null || h.point.distanceTo(fix.point) <= 1500)
          _harvest(c, h),
      // 정령·펫이 따라가는 길 (11-11 #42), 여러 마리면 마리마다
      for (var i = 0; i < actives.length; i++)
        if (actives[i].path.length >= 2)
          NPathOverlay(
            id: 'route_$i',
            coords: [for (final p in actives[i].path) NLatLng(p.$1, p.$2)],
            width: 5,
            color: const Color(0xCCF5DC94),
            outlineWidth: 1.5,
            outlineColor: const Color(0xFF0B0D26),
          ),
      for (var i = 0; i < actives.length; i++)
        NMarker(
          id: 'spirit_$i',
          position: NLatLng(positions[i].$1, positions[i].$2),
          icon: NOverlayImage.fromAssetImage(actives[i].petUid == null
              ? spiritAsset(c.profile.spiritKind)
              // 펫 그림이 들어오면 pet_*.png 로 바꾼다 (지도는 없는 그림을 못 그린다)
              : 'assets/images/icon_expedition.png'),
          size: const Size(42, 46),
          caption:
              NOverlayCaption(text: actives[i].petName ?? c.firstSpiritName),
        ),
      // 떠돌이 상인 (11-11 #84): 누르면 거리와 상관없이 바로 상점
      if (merchantAt != null)
        NMarker(
          id: 'merchant',
          position: _ll(merchantAt),
          icon: const NOverlayImage.fromAssetImage('assets/images/merchant.png'),
          size: const Size(58, 58),
          caption: NOverlayCaption(
            text: '떠돌이 상인 · ${c.merchantMinutesLeft}분',
            color: AppColors.goldBright,
            haloColor: const Color(0xFF0B0D26),
          ),
        )..setOnTapListener((_) {
            if (mounted) showMerchantSheet(context, c);
          }),
      if (fix != null)
        NMarker(
          id: 'player',
          position: _ll(fix.point),
          icon: const NOverlayImage.fromAssetImage(
              'assets/images/map_player.png'),
          // 내 위치는 몬스터보다 조금 크게 (11-11 #79)
          size: const Size(64, 64),
          caption: NOverlayCaption(text: c.profile.name),
        ),
    };

    await map.clearOverlays();
    await map.addOverlayAll(overlays);
    _scale = -1;
    await _resize();
    await _findHidden();
  }

  // ───────────── 아이콘 크기 (11-11 #79): 확대·축소에 따라, 최소·최대 사이

  final List<(NMarker, Size, bool)> _sized = [];
  double _scale = -1;

  /// 줌 15에서 1배, 한 단계마다 √2배. 0.55~1.15 사이.
  static double scaleAt(double zoom) =>
      math.pow(2, (zoom - 15) / 2).toDouble().clamp(0.55, 1.15);

  NMarker _monster(AppController c, FieldSpawn spawn, GeoPoint? me) {
    // 기본 40 → 60 (1.5배). 희귀 이상 수식어는 조금 더 크게
    final base = spawn.modifiers.isEmpty
        ? 60.0
        : spawn.grade.index >= ModGrade.rare.index
            ? 70.0
            : 64.0;
    final m = NMarker(
      id: 'monster_${spawn.id}',
      position: _ll(spawn.point),
      icon: const NOverlayImage.fromAssetImage('assets/images/map_monster.png'),
      size: Size(base, base),
      caption: spawn.modifiers.isEmpty
          ? null
          : NOverlayCaption(
              text: spawn.modifiers
                  .map((m) => ModifierRules.info(m).name)
                  .join(' '),
              color: modGradeColor(spawn.grade),
              haloColor: const Color(0xFF0B0D26),
            ),
    )..setOnTapListener((_) {
        if (mounted) showSpawnSheet(context, c, spawn);
      });
    // 11-11 #80: 지도를 축소하면 먼 몬스터는 숨기고 가까운 몬스터 위주로
    if (me != null) {
      final d = spawn.point.distanceTo(me);
      if (d > 1800) {
        m.setMinZoom(14.5);
      } else if (d > 900) {
        m.setMinZoom(13.5);
      }
    }
    _sized.add((m, Size(base, base), false));
    return m;
  }

  NMarker _harvest(AppController c, HarvestSpot h) {
    const base = 42.0; // 30 → 42 (몬스터와 같은 비율)
    final m = NMarker(
      id: 'harvest_${h.id}',
      position: _ll(h.point),
      icon: NOverlayImage.fromAssetImage(h.info.mapAsset),
      size: const Size(base, base),
      caption: _dots(c.harvestCharges(h), 1),
    )..setOnTapListener((_) {
        if (mounted) showHarvestSheet(context, c, h);
      });
    _sized.add((m, const Size(base, base), true));
    return m;
  }

  NOverlayCaption _dots(int n, double scale) => NOverlayCaption(
        text: '●' * n,
        textSize: 12 * scale,
        color: AppColors.goldBright,
        haloColor: const Color(0xFF0B0D26),
      );

  /// 지금 줌에 맞춰 몬스터·채집 아이콘 크기를 바꾼다
  Future<void> _resize() async {
    final map = _map;
    if (map == null || _sized.isEmpty) return;
    double zoom;
    try {
      zoom = (await map.getCameraPosition()).zoom;
    } catch (_) {
      return;
    }
    final s = scaleAt(zoom);
    if ((s - _scale).abs() < 0.04) return;
    _scale = s;
    final c = widget.controller;
    for (final (m, base, harvest) in _sized) {
      try {
        m.setSize(Size(base.width * s, base.height * s));
        if (harvest) {
          final id = m.info.id.substring('harvest_'.length);
          final spot = c.harvestSpots.where((h) => h.id == id).firstOrNull;
          if (spot != null) m.setCaption(_dots(c.harvestCharges(spot), s));
        }
      } catch (_) {
        // 지도에서 이미 빠진 아이콘
      }
    }
  }

  // ───────────── 가려진 몬스터 표시 (11-11 #43)

  List<_EdgeMark> _edges = const [];
  Size _size = Size.zero;

  /// 화면 밖이나 위 패널·아래 카드 뒤에 있는 가까운 몬스터를 찾는다
  Future<void> _findHidden() async {
    final map = _map;
    final c = widget.controller;
    final from = c.lastFix?.point;
    if (map == null || from == null || _size == Size.zero) return;
    final near = [
      for (final s in c.todaySpawns)
        if (s.point.distanceTo(from) <= 1500) s,
    ]..sort((a, b) =>
        a.point.distanceTo(from).compareTo(b.point.distanceTo(from)));
    final safe = Rect.fromLTRB(
        24, widget.safeTop + 22, _size.width - 24, _size.height - widget.safeBottom - 22);
    if (safe.height < 60) return;
    final marks = <_EdgeMark>[];
    try {
      for (final s in near.take(20)) {
        final pt = await map.latLngToScreenLocation(_ll(s.point));
        final p = Offset(pt.x, pt.y);
        if (safe.contains(p)) continue;
        final at = Offset(p.dx.clamp(safe.left, safe.right),
            p.dy.clamp(safe.top, safe.bottom));
        final dir = p - at;
        marks.add(_EdgeMark(s, at, dir.direction));
        if (marks.length >= 5) break;
      }
    } catch (_) {
      return;
    }
    if (mounted) setState(() => _edges = marks);
  }

  Future<void> _focus(FieldSpawn s) async {
    final map = _map;
    if (map == null) return;
    await map.updateCamera(NCameraUpdate.scrollAndZoomTo(target: _ll(s.point)));
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.controller.lastFix?.point ??
        widget.controller.fallbackCenter ??
        widget.controller.area.bounds.center;
    return LayoutBuilder(builder: (context, box) {
      _size = box.biggest;
      return Stack(children: [
        Positioned.fill(
          child: NaverMap(
            options: NaverMapViewOptions(
              initialCameraPosition:
                  NCameraPosition(target: _ll(center), zoom: 15),
              locationButtonEnable: true,
              // 11-11 #77: 내 위치 버튼·NAVER 로고·축척이 위아래 띠·카드에
              // 가려지지 않게, 가려지는 높이만큼 지도 여백을 둔다
              contentPadding: EdgeInsets.only(
                  top: widget.safeTop, bottom: widget.safeBottom),
            ),
            onMapTapped: (_, __) => widget.onUserMove?.call(),
            onMapReady: (map) {
              _map = map;
              _drawnSpawns = -1;
              _redraw().then((_) => _focusRequested());
            },
            // 지도를 움직이는 동안에는 가장자리 표시를 숨긴다 (11-11: 화면에 붙어
            // 따라다니는 몬스터처럼 보였다). 멈추면 다시 찾는다.
            onCameraChange: (reason, _) {
              if (_edges.isNotEmpty && mounted) setState(() => _edges = const []);
              if (reason == NCameraUpdateReason.gesture) widget.onUserMove?.call();
            },
            onCameraIdle: () async {
              await _resize();
              await _findHidden();
            },
          ),
        ),
        for (final e in _edges)
          Positioned(
            left: e.at.dx - 22,
            top: e.at.dy - 22,
            child: _EdgeChip(mark: e, onTap: () => _focus(e.spawn)),
          ),
      ]);
    });
  }
}

/// 가려진 몬스터 하나: 그 몬스터 쪽 가장자리에 둔다
class _EdgeMark {
  const _EdgeMark(this.spawn, this.at, this.angle);
  final FieldSpawn spawn;
  final Offset at;

  /// 몬스터가 있는 쪽 (라디안)
  final double angle;
}

class _EdgeChip extends StatelessWidget {
  const _EdgeChip({required this.mark, required this.onTap});

  final _EdgeMark mark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = mark.spawn.modifiers.isEmpty
        ? AppColors.gold
        : modGradeColor(mark.spawn.grade);
    // 지도 위 몬스터와 헷갈리지 않게: 작고 반투명한 원 + 큰 방향 화살표
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: 0.85,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(alignment: Alignment.center, children: [
            Transform.rotate(
              angle: mark.angle,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.play_arrow_rounded, size: 22, color: color),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xCC0B0D26),
                border: Border.all(color: color, width: 1.2),
              ),
              child: ClipOval(
                  child: MonsterPicture(monster: mark.spawn.monster, size: 22)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 지도 없이 볼 때: 정령을 보낼 수 있는 몬스터 목록
class _ExpeditionList extends StatelessWidget {
  const _ExpeditionList({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final actives = c.activeExpeditions;
    if (actives.isNotEmpty && (!c.farewellDone || c.idlePets.isEmpty)) {
      return Column(children: [
        for (final ex in actives) ...[
          ExpeditionCard(controller: c, ex: ex),
          const SizedBox(height: 6),
        ],
      ]);
    }
    // 가까운 몬스터부터 (거리는 MP로만 막는다, 11-10)
    final from = c.lastFix?.point;
    final reachable = [...c.todaySpawns];
    if (from != null) {
      reachable.sort((a, b) =>
          a.point.distanceTo(from).compareTo(b.point.distanceTo(from)));
    }
    return OrnatePanel(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KText('${c.farewellDone ? '펫' : '정령'} 원정 · MP ${c.mp} / ${c.mpMax}',
                style: AppText.title(17)),
            const SizedBox(height: 4),
            Text(
              reachable.isEmpty
                  ? '근처에 남은 몬스터가 없어요.'
                  : '근처 몬스터 ${reachable.length}마리 · 가까운 곳부터 보여 드려요. '
                      '100m마다 MP ${RuleConstants.expeditionMpPer100m}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            for (final s in reachable.take(5))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MonsterPicture(monster: s.monster, size: 40),
                title: Text(s.name,
                    style: TextStyle(color: modGradeColor(s.grade))),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.gold),
                onTap: () => showSpawnSheet(context, c, s),
              ),
            // 채집 자리 (11-11 #56): 가까운 3곳
            for (final h in (c.harvestSpots.toList()
                  ..sort((a, b) => a.point
                      .distanceTo(c.lastPoint ?? a.point)
                      .compareTo(b.point.distanceTo(c.lastPoint ?? b.point))))
                .take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MaterialIcon(h.info.base, size: 36),
                title: Text(h.info.name,
                    style: const TextStyle(color: AppColors.text)),
                subtitle: Text(
                    '남은 횟수 ${c.harvestCharges(h)} · '
                    '${c.lastPoint == null ? '' : '${h.point.distanceTo(c.lastPoint!).round()}m'}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.gold),
                onTap: () => showHarvestSheet(context, c, h),
              ),
          ],
        ),
      ),
    );
  }
}
