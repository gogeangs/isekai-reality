import '../../core/geo/geo.dart';
import '../../core/rules/exploration_rules.dart';

/// 페이즈 1 테스트 지역: 경기도 안산시 단원구 고잔동 일대.
///
/// ⚠️ 좌표는 공개 자료로 찾은 대략적인 값이다. 실제 휴대폰에서 지도를 띄워
/// 위치를 확인한 뒤 고쳐야 한다. (docs/gojan_places.md 참고)
///
/// 카페(여관)·편의점(잡화상)은 아직 넣지 않았다. 직접 골라 아래 목록에 추가한다.
class GojanArea {
  GojanArea._();

  static const ExploreArea area = ExploreArea(
    id: 'ansan_gojan',
    name: '고잔동',
    // 고잔역 서쪽 ~ 중앙역 동쪽, 호수공원 남쪽 ~ 고잔역 북쪽
    bounds: GeoBounds(
      south: 37.2975,
      west: 126.8170,
      north: 37.3245,
      east: 126.8440,
    ),
    places: [
      GamePlace(
        id: 'gate_jungang',
        name: '중앙 미궁 입구',
        realName: '안산 중앙역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.31596, 126.83864), // 출처: 역 문서 좌표
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'gate_gojan',
        name: '작은 미궁 입구',
        realName: '고잔역',
        kind: PlaceKind.labyrinthGate,
        point: GeoPoint(37.3168, 126.8230), // 추정값: 중앙역에서 서쪽 1.4km
        visitRadiusM: 120,
      ),
      GamePlace(
        id: 'lake_ansan',
        name: '정령의 호수',
        realName: '안산호수공원',
        kind: PlaceKind.spiritLake,
        point: GeoPoint(37.30062, 126.82355), // 출처: 관광 정보 좌표
        visitRadiusM: 250,
      ),
      // 안산문화예술의전당(음유시인의 극장)은 화랑유원지와 붙어 있어 보류.
      // 결정 후 아래 주석을 풀거나 지운다.
      // GamePlace(
      //   id: 'theater_arts',
      //   name: '음유시인의 극장',
      //   realName: '안산문화예술의전당',
      //   kind: PlaceKind.bardTheater,
      //   point: GeoPoint(37.32128, 126.82228),
      // ),
    ],
    exclusionZones: [
      // 세월호 추모 공간: 화랑유원지와 4·16 생명안전공원 일대 (초지동).
      // 경계를 정확히 모르므로 넉넉하게 잡는다. 실제 경계 확인 후 조정.
      ExclusionZone(
        name: '화랑유원지 · 4·16 생명안전공원 일대',
        center: GeoPoint(37.3240, 126.8150),
        radiusM: 700,
      ),
    ],
  );
}
