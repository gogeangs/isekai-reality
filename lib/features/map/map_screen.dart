import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/geo/geo.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../battle/battle_view.dart';
import '../battle/field_battle_screen.dart';
import '../bulssi/bulssi_bubble.dart';
import 'map_config.dart';

/// 고잔동 지도: 장소 아이콘 · 잿빛 안개 · 밝힌 비율 · 내 위치
class MapScreen extends StatelessWidget {
  const MapScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final area = controller.area;
    final gauge = controller.player.gauge;
    final spawn = controller.nearbySpawn;
    return Stack(
      children: [
        Positioned.fill(
          child: naverMapEnabled
              ? _NaverMapLayer(controller: controller)
              : _ExploreSummary(controller: controller),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: MediaQuery.paddingOf(context).top + 8,
          child: _TopPanel(
            areaName: area.name,
            ratio: controller.revealedRatio,
            keys: gauge.keysAvailable,
          ),
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
              onPurify: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      FieldBattleScreen(controller: controller, spawn: spawn),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────────────────────────── 위쪽 패널

class _TopPanel extends StatelessWidget {
  const _TopPanel({
    required this.areaName,
    required this.ratio,
    required this.keys,
  });

  final String areaName;
  final double ratio;
  final int keys;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(children: [
        Text(areaName,
            style: const TextStyle(
                color: AppColors.goldBright,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${(ratio * 100).floor()}% 밝힘',
                  style: const TextStyle(color: AppColors.text, fontSize: 13)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 6,
                  color: AppColors.gold,
                  backgroundColor: AppColors.track,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Icon(Icons.vpn_key_rounded, color: AppColors.gold, size: 20),
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
            BulssiBubble(line: _discoveryLine(place.kind), size: 56),
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
        PlaceKind.inn => '따뜻한 여관이네. 잠깐 쉬어 갈까?',
        PlaceKind.generalStore => '잡화상이다! 이세계 물건도 팔면 좋을 텐데.',
        PlaceKind.spiritLake => '물의 정령들이 반짝이고 있어. 비 오는 날엔 더 많아진대!',
        PlaceKind.bardTheater => '음유시인의 노래가 들려. 기분이 좋아지는걸?',
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
                const Text('멈춰 선 다음 정화해 주세요',
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
            child: const Text('정화하기'),
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
    return Container(
      color: AppColors.night,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.paddingOf(context).top + 90, 16, 24),
        children: [
          const BulssiBubble(
              line: '지도를 열려면 네이버 지도 키가 필요해. 그동안은 탐험 기록을 보여 줄게!'),
          const SizedBox(height: 16),
          Text(
            '밝힌 칸 ${comma(controller.revealedCells.length)} / '
            '${comma(controller.area.totalCells)}',
            style: const TextStyle(color: AppColors.text, fontSize: 15),
          ),
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
          for (final place in controller.area.places)
            ListTile(
              leading: Icon(
                visited.contains(place.id)
                    ? Icons.check_circle_rounded
                    : Icons.help_outline_rounded,
                color: visited.contains(place.id)
                    ? AppColors.gold
                    : AppColors.textMuted,
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
  int _drawnCells = -1;
  int _drawnSpawns = -1;
  String? _drawnFix;

  static NLatLng _ll(GeoPoint p) => NLatLng(p.lat, p.lng);

  @override
  void didUpdateWidget(covariant _NaverMapLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _redraw();
  }

  /// 안개·장소·내 위치를 다시 그린다 (바뀐 게 있을 때만)
  Future<void> _redraw() async {
    final map = _map;
    if (map == null) return;
    final c = widget.controller;
    final fix = c.lastFix;
    final fixKey = fix == null
        ? null
        : '${fix.point.lat.toStringAsFixed(5)},${fix.point.lng.toStringAsFixed(5)}';
    final spawns = c.todaySpawns;
    if (_drawnCells == c.revealedCells.length &&
        _drawnSpawns == spawns.length &&
        _drawnFix == fixKey) {
      return;
    }
    _drawnCells = c.revealedCells.length;
    _drawnSpawns = spawns.length;
    _drawnFix = fixKey;

    final area = c.area;
    final b = area.bounds;
    final visited = c.everVisitedPlaceIds;

    final overlays = <NAddableOverlay>{
      // 잿빛 안개: 지역 전체를 덮고, 밝힌 칸은 구멍으로 뚫는다
      NPolygonOverlay(
        id: 'fog',
        coords: [
          NLatLng(b.south, b.west),
          NLatLng(b.south, b.east),
          NLatLng(b.north, b.east),
          NLatLng(b.north, b.west),
          NLatLng(b.south, b.west),
        ],
        holes: [
          for (final cell in c.revealedCells)
            [
              ...area.cellCorners(cell).map(_ll),
              _ll(area.cellCorners(cell).first),
            ],
        ],
        color: const Color(0xFFB8B2C8).withValues(alpha: 0.55),
        outlineColor: const Color(0x00000000),
        outlineWidth: 0,
      ),
      for (final place in area.places)
        NMarker(
          id: 'place_${place.id}',
          position: _ll(place.point),
          caption: NOverlayCaption(
            text: visited.contains(place.id) ? place.name : '???',
          ),
        ),
      for (final spawn in spawns)
        NMarker(
          id: 'monster_${spawn.id}',
          position: _ll(spawn.point),
          caption: NOverlayCaption(text: spawn.info.name),
          iconTintColor: const Color(0xFF9C93B8),
        ),
      if (fix != null)
        NMarker(
          id: 'player',
          position: _ll(fix.point),
          caption: NOverlayCaption(text: c.profile.name),
        ),
    };

    await map.clearOverlays();
    await map.addOverlayAll(overlays);
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.controller.lastFix?.point ??
        widget.controller.area.bounds.center;
    return NaverMap(
      options: NaverMapViewOptions(
        initialCameraPosition: NCameraPosition(target: _ll(center), zoom: 15),
        locationButtonEnable: true,
      ),
      onMapReady: (map) {
        _map = map;
        _drawnCells = -1;
        _redraw();
      },
    );
  }
}
