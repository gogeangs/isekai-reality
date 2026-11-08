import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/geo/geo.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
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
    if (_drawnCells == c.revealedCells.length && _drawnFix == fixKey) return;
    _drawnCells = c.revealedCells.length;
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
