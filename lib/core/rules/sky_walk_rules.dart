import 'dart:math' as math;

import 'highland_rules.dart';
import 'materials.dart';

/// 묶음 83 #389: 하이랜드 쿼터뷰 구름 걷기.
///
/// 오를 때마다 새 판(씨앗)을 섞고, 한 번 오른 동안은 같은 판. 3층(아래 정원 → 무너진 회랑 → 꼭대기 제단).
/// 밝힌 칸과 맞닿은(상하좌우) 구름만 바람 1로 걷는다. 빈 칸 금빛 숫자 = 둘레 8칸에 숨은 유물 조각 수.
/// 숫자(바람 · 칸 수 · 거리)는 개발이 정한 처음 값, 시험하며 맞춘다.
enum SkyCell { empty, crystal, stone, spring, soldier, shard, stair, altar }

class SkyFloorInfo {
  const SkyFloorInfo({
    required this.floor,
    required this.name,
    required this.size,
    required this.wind,
    required this.crystals,
    required this.stones,
    required this.springs,
    required this.soldiers,
    required this.goalMin,
    required this.goalMax,
  });

  /// 1 · 2 · 3
  final int floor;
  final String name;

  /// 가로세로 칸 (둥글게 깎음)
  final int size;

  /// 이 층에 오를 때 더하는 바람
  final int wind;
  final int crystals;
  final int stones;
  final int springs;
  final int soldiers;

  /// 계단(제단)까지 입구에서 걸음 수
  final int goalMin;
  final int goalMax;

  bool get top => floor == SkyWalkRules.floorCount;
}

class SkyWalkRules {
  SkyWalkRules._();

  static const int floorCount = 3;

  static const List<SkyFloorInfo> floors = [
    SkyFloorInfo(
        floor: 1, name: '아래 정원', size: 9, wind: 18, crystals: 4, stones: 2,
        springs: 2, soldiers: 2, goalMin: 7, goalMax: 9),
    SkyFloorInfo(
        floor: 2, name: '무너진 회랑', size: 7, wind: 14, crystals: 4, stones: 2,
        springs: 1, soldiers: 3, goalMin: 5, goalMax: 7),
    SkyFloorInfo(
        floor: 3, name: '꼭대기 제단', size: 5, wind: 10, crystals: 3, stones: 2,
        springs: 1, soldiers: 4, goalMin: 4, goalMax: 99),
  ];

  static SkyFloorInfo floor(int f) => floors[(f - 1).clamp(0, floorCount - 1)];

  /// 칸 하나 걷는 바람 · 바람 샘
  static const int windPerCell = 1;
  static const int springWind = 3;

  /// 특별한 칸은 입구에서 이만큼 떨어진 곳에 (꼭대기 층은 칸이 모자라 재료만 2칸까지)
  static const int clearance = 3;
  static const int lootFallback = 2;

  /// 2층 장식 기둥 (빈 칸에)
  static const int columnsMin = 5;
  static const int columnsMax = 7;

  /// 석상 병사를 이기면 하늘 돌 조각 (지금 그대로)
  static int get soldierStoneMin => HighlandRules.soldierStoneMin;
  static int get soldierStoneMax => HighlandRules.soldierStoneMax;

  static MaterialId crystalOf(Isle i) => HighlandRules.info(i).crystal;

  static String tile(Isle i, int floor) =>
      'assets/images/tile_sky_${i.name}_${floor.clamp(1, 3)}.webp';
  static const String cloudA = 'assets/images/cloud_sky_a.webp';
  static const String cloudB = 'assets/images/cloud_sky_b.webp';
  static const String under = 'assets/images/sky_island_under.webp';
  static const String shardArt = 'assets/images/item_skyRelicShard.webp';
  static const String altarArt = 'assets/images/sky_altar.webp';
  static const String springArt = 'assets/images/sky_windSpring.webp';
  static const String columnArt = 'assets/images/sky_column_broken.webp';
  static const String stairArt = 'assets/images/sky_stair.webp';

  static int hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}

/// 한 층의 판 (씨앗이 같으면 같은 판)
class SkyBoard {
  SkyBoard._({
    required this.info,
    required this.cells,
    required this.entrance,
    required this.dist,
    required this.goal,
    required this.shard,
    required this.columns,
  });

  final SkyFloorInfo info;

  /// 칸 (y * n + x). 섬 밖이면 null
  final List<SkyCell?> cells;
  final int entrance;

  /// 입구에서 걸음 수 (섬 밖은 -1)
  final List<int> dist;

  /// 계단 · 제단 칸
  final int goal;

  /// 유물 조각 칸
  final int shard;

  /// 장식 기둥 칸 (2층)
  final Set<int> columns;

  int get n => info.size;
  int get floor => info.floor;
  int get count => cells.where((c) => c != null).length;

  int xOf(int i) => i % n;
  int yOf(int i) => i ~/ n;
  bool inside(int i) => i >= 0 && i < cells.length && cells[i] != null;
  SkyCell? at(int i) => i >= 0 && i < cells.length ? cells[i] : null;

  Iterable<int> neighbors4(int i) sync* {
    final x = xOf(i), y = yOf(i);
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
      final j = ny * n + nx;
      if (cells[j] != null) yield j;
    }
  }

  Iterable<int> neighbors8(int i) sync* {
    final x = xOf(i), y = yOf(i);
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
        final j = ny * n + nx;
        if (cells[j] != null) yield j;
      }
    }
  }

  /// 걷을 수 있는 칸: 아직 구름 · 밝힌 칸과 상하좌우로 맞닿음
  bool canReveal(int i, Set<int> opened) =>
      inside(i) && !opened.contains(i) && neighbors4(i).any(opened.contains);

  /// 빈 칸 숫자: 둘레 8칸에 아직 숨은 유물 조각 수
  int hint(int i, Set<int> opened) =>
      neighbors8(i).where((j) => cells[j] == SkyCell.shard && !opened.contains(j)).length;

  /// 섬 모양 (둥글게): 1층 9×9 65칸 · 2층 7×7 37칸 · 3층 5×5 21칸
  static bool _shape(int size, int dx, int dy) {
    final r = dx * dx + dy * dy;
    return switch (size) {
      9 => r <= 20 && !(dx * dy > 0 && r == 20),
      7 => r <= 10,
      _ => r <= 5,
    };
  }

  static SkyBoard generate(int seed, int floor) {
    final info = SkyWalkRules.floor(floor);
    final n = info.size;
    final c = n ~/ 2;
    final cells = List<SkyCell?>.filled(n * n, null);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (_shape(n, x - c, y - c)) cells[y * n + x] = SkyCell.empty;
      }
    }
    // 입구: 맨 앞(쿼터뷰 아래 끝 · x + y 가장 큼), 같으면 가운데 줄에 가까운 칸
    var entrance = -1;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] == null) continue;
      if (entrance < 0) {
        entrance = i;
        continue;
      }
      final x = i % n, y = i ~/ n, ex = entrance % n, ey = entrance ~/ n;
      final s = x + y, es = ex + ey;
      if (s > es || (s == es && ((x - y).abs() < (ex - ey).abs() || ((x - y).abs() == (ex - ey).abs() && x > ex)))) {
        entrance = i;
      }
    }
    // 걸음 수
    final dist = List<int>.filled(n * n, -1);
    dist[entrance] = 0;
    final q = [entrance];
    for (var k = 0; k < q.length; k++) {
      final i = q[k];
      final x = i % n, y = i ~/ n;
      for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= n || ny >= n) continue;
        final j = ny * n + nx;
        if (cells[j] == null || dist[j] >= 0) continue;
        dist[j] = dist[i] + 1;
        q.add(j);
      }
    }
    final rng = math.Random(SkyWalkRules.hash('sky|$seed|$floor'));
    List<int> pick(bool Function(int) ok) {
      final l = [for (var i = 0; i < cells.length; i++) if (cells[i] != null && ok(i)) i];
      l.shuffle(rng);
      return l;
    }

    // 계단 · 제단
    var goals = pick((i) => dist[i] >= info.goalMin && dist[i] <= info.goalMax);
    if (goals.isEmpty) goals = pick((i) => dist[i] >= SkyWalkRules.clearance);
    final goal = goals.first;
    cells[goal] = info.top ? SkyCell.altar : SkyCell.stair;

    // 특별한 칸 (병사 · 조각 · 샘 먼저, 재료는 남은 자리)
    final far = pick((i) => i != goal && dist[i] >= SkyWalkRules.clearance);
    final near = pick((i) => dist[i] >= SkyWalkRules.lootFallback && dist[i] < SkyWalkRules.clearance);
    final want = [
      SkyCell.shard,
      for (var k = 0; k < info.soldiers; k++) SkyCell.soldier,
      for (var k = 0; k < info.springs; k++) SkyCell.spring,
      for (var k = 0; k < info.crystals; k++) SkyCell.crystal,
      for (var k = 0; k < info.stones; k++) SkyCell.stone,
    ];
    var shard = -1;
    for (final w in want) {
      final loot = w == SkyCell.crystal || w == SkyCell.stone;
      final int at;
      if (far.isNotEmpty) {
        at = far.removeAt(0);
      } else if (loot && near.isNotEmpty) {
        at = near.removeAt(0);
      } else {
        continue;
      }
      cells[at] = w;
      if (w == SkyCell.shard) shard = at;
    }

    // 2층 장식 기둥 (빈 칸, 입구 제외)
    final columns = <int>{};
    if (floor == 2) {
      final k = SkyWalkRules.columnsMin +
          rng.nextInt(SkyWalkRules.columnsMax - SkyWalkRules.columnsMin + 1);
      for (final i in pick((i) => cells[i] == SkyCell.empty && i != entrance)) {
        if (columns.length >= k) break;
        columns.add(i);
      }
    }
    return SkyBoard._(
      info: info,
      cells: cells,
      entrance: entrance,
      dist: dist,
      goal: goal,
      shard: shard,
      columns: columns,
    );
  }
}
