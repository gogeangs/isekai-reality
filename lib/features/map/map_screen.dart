import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../app_controller.dart';
import '../../core/geo/geo.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../battle/battle_view.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart';
import 'expedition_sheet.dart';
import 'map_config.dart';

/// 지도: 내 둘레의 필드 몬스터 · 정령 · 내 위치 (11-10 전국, 안개 없음)
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final gauge = controller.player.gauge;
    final spawn = controller.nearbySpawn;
    final ex = controller.expedition;
    final away = ex != null && !ex.finished;
    return Stack(
      children: [
        Positioned.fill(
          child: naverMapEnabled
              ? _NaverMapLayer(controller: controller)
              : _ExploreSummary(controller: controller),
        ),
        Positioned(
          // 위쪽 프로필·설정 버튼 아래
          left: 16,
          right: 16,
          top: MediaQuery.paddingOf(context).top + 60,
          child: _TopPanel(
            purifiedToday: controller.player.today?.fieldMonstersPurified ?? 0,
            keys: gauge.keysAvailable,
          ),
        ),
        if (away)
          Positioned(
            left: 16,
            right: 16,
            bottom: controller.lastDiscovery != null || spawn != null ? 150 : 24,
            child: ExpeditionCard(controller: controller, ex: ex),
          ),
        if (controller.lastDiscovery != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _DiscoveryCard(
              place: controller.lastDiscovery!,
              onClose: controller.clearDiscovery,
            ),
          )
        else if (spawn != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: _MonsterCard(
              spawn: spawn,
              onPurify: () => showSpawnSheet(context, controller, spawn),
            ),
          ),
      ],
    );
  }
}

/// 장소 종류별 지도 표시 그림
String placeIconAsset(PlaceKind kind) => switch (kind) {
      PlaceKind.labyrinthGate => 'assets/images/map_gate.png',
      PlaceKind.spiritLake => 'assets/images/map_lake.png',
    };

// ───────────────────────────────────────────── 위쪽 패널

class _TopPanel extends StatelessWidget {
  const _TopPanel({
    required this.purifiedToday,
    required this.keys,
  });

  /// 오늘 정화한 필드 몬스터 (경험치는 하루 5마리까지)
  final int purifiedToday;
  final int keys;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Text('내 주변', style: AppText.title(19)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '오늘 사냥 $purifiedToday / '
                  '${RuleConstants.maxFieldMonstersPerDay}마리',
                  style: const TextStyle(color: AppColors.text, fontSize: 13)),
              const SizedBox(height: 4),
              GlowBar(
                  ratio: (purifiedToday / RuleConstants.maxFieldMonstersPerDay)
                      .clamp(0, 1)
                      .toDouble(),
                  colors: BarColors.exp,
                  height: 7),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const GameIcon('key', size: 26),
        const SizedBox(width: 4),
        Text('$keys',
            style: const TextStyle(color: AppColors.text, fontSize: 16)),
      ]),
    );
  }
}

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
            Text('새 장소 발견! · ${place.name}',
                style: const TextStyle(
                    color: AppColors.goldBright,
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('현실: ${place.realName} · 경험치 +${RuleConstants.newPlaceExp}',
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
                Text('${info.name}이(가) 나타났어!',
                    style: const TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const Text('멈춰 선 다음 사냥해 주세요',
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
            Text(
              '현재 위치 ${fix.point.lat.toStringAsFixed(4)}, '
              '${fix.point.lng.toStringAsFixed(4)}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          Text(
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
  const _NaverMapLayer({required this.controller});

  final AppController controller;

  @override
  State<_NaverMapLayer> createState() => _NaverMapLayerState();
}

class _NaverMapLayerState extends State<_NaverMapLayer> {
  NaverMapController? _map;
  int _drawnSpawns = -1;
  String? _drawnFix;
  String? _drawnSpirit;

  static NLatLng _ll(GeoPoint p) => NLatLng(p.lat, p.lng);

  @override
  void didUpdateWidget(covariant _NaverMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _redraw();
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
    final ex = c.expedition;
    final away = ex != null && !ex.finished;
    final spiritPos = away ? ex.positionAt(c.now) : null;
    final spiritKey = spiritPos == null
        ? null
        : '${spiritPos.$1.toStringAsFixed(4)},${spiritPos.$2.toStringAsFixed(4)}';
    if (_drawnSpawns == spawns.length &&
        _drawnFix == fixKey &&
        _drawnSpirit == spiritKey) {
      return;
    }
    _drawnSpawns = spawns.length;
    _drawnFix = fixKey;
    _drawnSpirit = spiritKey;

    final area = c.area;
    final visited = c.everVisitedPlaceIds;

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
      // 시내 전체에 몬스터가 많아 이름은 빼고 그림만. 누르면 직접 정화·정령 보내기
      for (final spawn in spawns)
        NMarker(
          id: 'monster_${spawn.id}',
          position: _ll(spawn.point),
          icon: const NOverlayImage.fromAssetImage(
              'assets/images/map_monster.png'),
          size: const Size(40, 40),
        )..setOnTapListener((_) {
            if (mounted) showSpawnSheet(context, c, spawn);
          }),
      if (spiritPos != null)
        NMarker(
          id: 'spirit',
          position: NLatLng(spiritPos.$1, spiritPos.$2),
          icon: NOverlayImage.fromAssetImage(spiritAsset(c.profile.spiritKind)),
          size: const Size(42, 46),
          caption: NOverlayCaption(text: c.profile.spiritName),
        ),
      if (fix != null)
        NMarker(
          id: 'player',
          position: _ll(fix.point),
          icon: const NOverlayImage.fromAssetImage(
              'assets/images/map_player.png'),
          size: const Size(48, 48),
          caption: NOverlayCaption(text: c.profile.name),
        ),
    };

    await map.clearOverlays();
    await map.addOverlayAll(overlays);
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.controller.lastFix?.point ??
        widget.controller.fallbackCenter ??
        widget.controller.area.bounds.center;
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(target: _ll(center), zoom: 15),
        locationButtonEnable: true,
      ),
      onMapReady: (map) {
        _map = map;
        _drawnSpawns = -1;
        _redraw();
      },
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
    final ex = c.expedition;
    if (ex != null && !ex.finished) {
      return ExpeditionCard(controller: c, ex: ex);
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
            Text('정령 원정 · MP ${c.mp} / ${RuleConstants.mpMax}',
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
                title: Text(s.info.name,
                    style: const TextStyle(color: AppColors.text)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.gold),
                onTap: () => showSpawnSheet(context, c, s),
              ),
          ],
        ),
      ),
    );
  }
}
