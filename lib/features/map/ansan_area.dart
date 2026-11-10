import '../../core/geo/geo.dart';
import '../../core/rules/exploration_rules.dart';

/// 탐험 지역: 경기도 안산시 시내 (상록구·단원구 육지, 대부도 제외). 2026-11-09 고잔동에서 넓힘.
///
/// 역 좌표는 위키백과 역 문서, 공원 좌표는 관광 정보 주소 지점 (docs/ansan_places.md).
/// 지역 경계는 바깥 장소에 여유를 더한 추정값이라 공식 경계와 조금 다를 수 있다.
/// 여관·잡화상은 실제 가게에 두지 않고 앱 안 시설로 둔다 (2026-11-09 결정).
/// 음유시인의 극장은 제외 구역 옆이라 넣지 않는다 (2026-11-09 결정).
class AnsanArea {
  AnsanArea._();

  /// 이름을 아는 제외 구역 (전국 지역에서도 쓴다)
  static const List<ExclusionZone> exclusions = [
      // 세월호 추모 공간: 화랑유원지와 4·16 생명안전공원 일대 (초지동).
      // 경계를 정확히 모르므로 넉넉하게 잡는다. 실제 경계 확인 후 조정.
      ExclusionZone(
        name: '화랑유원지 · 4·16 생명안전공원 일대',
        center: GeoPoint(37.3240, 126.8150),
        radiusM: 700,
      ),
  ];

  /// 안산 시내 가운데 (예시·테스트에서 위치 대신 쓰는 자리)
  static const GeoPoint center = GeoPoint(37.3165, 126.8275);

  static const ExploreArea area = ExploreArea(
    id: 'ansan',
    name: '안산시',
    bounds: GeoBounds(
      south: 37.262,
      west: 126.735,
      north: 37.372,
      east: 126.920,
    ),
    places: [
      // ── 미궁 입구 (지하철역) — 던전 보상 1.5배
      GamePlace(
        id: 'gate_banwol',
        name: '반월 미궁 입구',
        realName: '반월역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.31213, 126.90353),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_sangnoksu',
        name: '상록수 미궁 입구',
        realName: '상록수역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.30271, 126.86641),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_sari',
        name: '사리 미궁 입구',
        realName: '사리역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.29090, 126.85720),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_handae',
        name: '한대앞 미궁 입구',
        realName: '한대앞역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.30977, 126.85358),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_jungang',
        name: '중앙 미궁 입구',
        realName: '중앙역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.31596, 126.83864),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_gojan',
        name: '고잔 미궁 입구',
        realName: '고잔역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.31682, 126.82313),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_choji',
        name: '초지 미궁 입구',
        realName: '초지역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.32057, 126.80592),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_ansan',
        name: '안산 미궁 입구',
        realName: '안산역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.32709, 126.78845),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_singil',
        name: '신길온천 미궁 입구',
        realName: '신길온천역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.33818, 126.76575),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_wonsi',
        name: '원시 미궁 입구',
        realName: '원시역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.30260, 126.78680),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_siu',
        name: '시우 미궁 입구',
        realName: '시우역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.31310, 126.79560),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_seonbu',
        name: '선부 미궁 입구',
        realName: '선부역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.33436, 126.80992),
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_dalmi',
        name: '달미 미궁 입구',
        realName: '달미역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.34889, 126.80917),
        visitRadiusM: 120,
      ),

      // ── 정령의 호수 (호수·습지·공원)
      GamePlace(
        id: 'lake_ansan',
        name: '정령의 호수',
        realName: '안산호수공원',
        kind: PlaceKind.spiritLake,
        point: GeoPoint(37.30062, 126.82355),
        visitRadiusM: 250,
      ),
      GamePlace(
        id: 'lake_reed',
        name: '갈대 정령의 습지',
        realName: '안산갈대습지공원',
        kind: PlaceKind.spiritLake,
        point: GeoPoint(37.27433, 126.84099),
        visitRadiusM: 300,
      ),
      GamePlace(
        id: 'lake_seongho',
        name: '작은 정령의 샘',
        realName: '성호공원',
        kind: PlaceKind.spiritLake,
        point: GeoPoint(37.31403, 126.86104),
        visitRadiusM: 180,
      ),
      GamePlace(
        id: 'lake_nojeok',
        name: '폭포 정령의 언덕',
        realName: '노적봉공원',
        kind: PlaceKind.spiritLake,
        point: GeoPoint(37.31646, 126.85506),
        visitRadiusM: 180,
      ),
    ],
    exclusionZones: exclusions,
  );
}
