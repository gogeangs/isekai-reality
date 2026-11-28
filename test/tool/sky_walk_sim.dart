// 개발용 시뮬레이션 (flutter test test/tool/sky_walk_sim.dart). CI 대상 아님.
import 'package:isekai_reality/core/rules/rules.dart';

List<int> path(SkyBoard b, Set<int> opened, int target) {
  final prev = <int, int>{};
  final q = [...opened];
  final seen = {...opened};
  for (var k = 0; k < q.length; k++) {
    for (final j in b.neighbors4(q[k])) {
      if (seen.add(j)) {
        prev[j] = q[k];
        q.add(j);
      }
    }
  }
  final out = <int>[];
  var s = target;
  while (!opened.contains(s)) {
    out.add(s);
    s = prev[s]!;
  }
  return out.reversed.toList();
}

void main() {
  run(hidden: true);
}

void run({required bool hidden, List<int> extra = const [0, 0, 0]}) {
  const n = 2000;
  var guardian = 0, floorsSum = 0, shardsSum = 0, crystalsSum = 0, stonesSum = 0, soldiersSum = 0;
  final windLeft = [0, 0, 0], arrived = [0, 0, 0], short = [0, 0, 0];
  for (var seed = 0; seed < n; seed++) {
    var wind = 0, shards = 0, floor = 1;
    var ok = true;
    for (; floor <= 3 && ok; floor++) {
      final b = SkyBoard.generate(seed, floor);
      wind += b.info.wind + extra[floor - 1];
      final opened = {b.entrance};
      var shardFound = false;
      void reveal(int i) {
        opened.add(i);
        wind--;
        switch (b.at(i)) {
          case SkyCell.spring: wind += 3;
          case SkyCell.crystal: crystalsSum++;
          case SkyCell.stone: stonesSum++;
          case SkyCell.soldier: soldiersSum++; stonesSum += 1; // 평균 1.5 → 아래서 반 더함
          case SkyCell.shard: shardFound = true; shards++;
          default:
        }
      }
      while (true) {
        if (wind <= 0) break;
        if (hidden) {
          // 묶음 85 #417: 계단이 보이지 않음 — 찾을 때까지 먼 쪽 구름 (조각 숫자가 보이면 그쪽 먼저, 바람 넉넉할 때)
          if (opened.contains(b.goal) && shardFound) break;
          if (opened.contains(b.goal) && wind <= 2) break;
          final frontier = [for (var i = 0; i < b.cells.length; i++) if (b.canReveal(i, opened)) i];
          if (frontier.isEmpty) break;
          final hot = <int>{};
          if (!shardFound && wind > 6) {
            for (final o in opened) {
              if (b.at(o) == SkyCell.empty && b.hint(o, opened) > 0) {
                for (final j in b.neighbors8(o)) {
                  if (!opened.contains(j)) hot.add(j);
                }
              }
            }
          }
          final hf = frontier.where(hot.contains).toList();
          if (hf.isNotEmpty) {
            reveal(hf.first);
            continue;
          }
          if (opened.contains(b.goal)) {
            // 계단 찾음 · 조각만 더 찾기
            frontier.sort((p, q) => b.dist[q] - b.dist[p]);
            reveal(frontier.first);
            continue;
          }
          frontier.sort((p, q) => b.dist[q] - b.dist[p]);
          final top = frontier.where((f) => b.dist[f] == b.dist[frontier.first]).toList();
          reveal(top[(seed + opened.length) % top.length]);
          continue;
        }
        final toGoal = path(b, opened, b.goal);
        if (toGoal.isEmpty && shardFound) break;
        if (toGoal.isNotEmpty && (shardFound || wind <= toGoal.length)) {
          reveal(toGoal.first);
          continue;
        }
        // 조각 찾기: 숫자 칸 둘레 → 아니면 기둥 쪽으로 넓게
        final frontier = [for (var i = 0; i < b.cells.length; i++) if (b.canReveal(i, opened)) i];
        final hot = <int>{};
        for (final o in opened) {
          if (b.at(o) == SkyCell.empty && b.hint(o, opened) > 0) {
            for (final j in b.neighbors8(o)) {
              if (!opened.contains(j)) hot.add(j);
            }
          }
        }
        int? pick;
        for (final f in frontier) {
          if (hot.contains(f)) pick = f;
        }
        if (pick == null && hot.isNotEmpty) {
          final p = path(b, opened, hot.first);
          pick = p.first;
        }
        // 아직 숫자로 못 본 칸을 가장 많이 덮는 구름
        final covered = <int>{};
        for (final o in opened) {
          if (b.at(o) == SkyCell.empty) covered.addAll(b.neighbors8(o));
          covered.add(o);
        }
        int gain(int f) => [f, ...b.neighbors8(f)].where((j) => !covered.contains(j)).length;
        pick ??= (frontier..sort((p, q) => gain(q) - gain(p))).first;
        reveal(pick);
      }
      if (!opened.contains(b.goal)) { ok = false; short[floor - 1]++; floorsSum += floor; break; }
      arrived[floor - 1]++;
      windLeft[floor - 1] += wind;
    }
    if (ok) { floorsSum += 3; if (shards >= 3) guardian++; }
    shardsSum += shards;
  }
  stonesSum += soldiersSum ~/ 2;
  String f(num x) => (x / n).toStringAsFixed(2);
  // ignore: avoid_print
  print('${hidden ? '숨김' : '보임'}${extra[0] > 0 ? ' 바람+$extra' : ''} 수호자까지 ${(guardian * 100 / n).round()}% · 평균 층 ${f(floorsSum)} · 조각 ${f(shardsSum)} · 결정 ${f(crystalsSum)} · 하늘 돌 ${f(stonesSum)} (병사 ${f(soldiersSum)})');
  for (var i = 0; i < 3; i++) {
    // ignore: avoid_print
    print('${i + 1}층: 계단 닿음 ${(arrived[i] * 100 / n).round()}% · 닿았을 때 남은 바람 ${arrived[i] == 0 ? '-' : (windLeft[i] / arrived[i]).toStringAsFixed(1)} · 바람 모자람 ${short[i]}');
  }
}
