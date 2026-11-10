import '../../core/geo/geo.dart';
import '../../core/rules/exploration_rules.dart';
import 'ansan_area.dart';

/// 탐험 지역: 대한민국 전체 (11-10, 안산 거점 테스트에서 넓힘).
///
/// - 장소(미궁 입구·정령의 물가)는 두지 않는다. 필드 몬스터만 내 둘레에 나온다.
///   안산 장소 자료는 [AnsanArea] 에 남겨 두고, 장소를 다시 넣을 때 쓴다.
/// - 제외 구역: 이름을 아는 추모 공간은 여기, 전국 학교·병원·묘지는
///   assets/data/exclusions.json ([ExclusionIndex]).
class KoreaArea {
  KoreaArea._();

  static const ExploreArea area = ExploreArea(
    id: 'korea',
    name: '대한민국',
    // 제주·울릉도까지 덮는 넉넉한 사각형
    bounds: GeoBounds(
      south: 33.0,
      west: 124.5,
      north: 38.7,
      east: 131.0,
    ),
    places: [],
    exclusionZones: AnsanArea.exclusions,
  );
}
