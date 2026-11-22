part of '../app_controller.dart';

/// 묶음 81 #378: 가방 화면 — 새로 얻은 것(주황 점, 한 번 보면 사라짐) · 최근 얻은 차례 · 정렬(마지막 것 기억)
enum BagSort {
  recent('최근 얻은 순'),
  grade('등급 높은 순'),
  kind('종류 순');

  const BagSort(this.label);
  final String label;
}

extension BagViewOps on AppController {
  Map<String, int> get _bagCounts => {
        for (final e in ((_bagView?['counts'] as Map?) ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      };

  Map<String, int> get _bagOrder => {
        for (final e in ((_bagView?['order'] as Map?) ?? const {}).entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      };

  Set<String> get _bagNew => {
        for (final k in (_bagView?['new'] as List?) ?? const []) '$k',
      };

  /// 정렬 (마지막 고른 것)
  BagSort get bagSort {
    final n = _bagView?['sort'];
    return n is int && n >= 0 && n < BagSort.values.length ? BagSort.values[n] : BagSort.recent;
  }

  Future<void> setBagSort(BagSort s) async {
    _bagView = {...?_bagView, 'sort': s.index};
    await store.saveJson('bagView', _bagView!);
    _notify();
  }

  /// 새로 얻은 것인지 (주황 점)
  bool bagIsNew(String key) => _bagNew.contains(key);

  /// 최근 얻은 차례 (클수록 최근, 모르면 0)
  int bagOrderOf(String key) => _bagOrder[key] ?? 0;

  /// 가방을 볼 때: 늘어난 것은 새것 · 최근 차례를 앞으로. 처음엔 지금 든 것을 기억만
  void noteBagContents(Map<String, int> counts) {
    final first = _bagView == null || _bagView!['counts'] == null;
    final old = _bagCounts;
    final order = _bagOrder;
    final fresh = _bagNew;
    var seq = order.values.fold<int>(0, (m, v) => v > m ? v : m);
    var changed = first;
    for (final e in counts.entries) {
      final before = old[e.key] ?? 0;
      if (!first && e.value > before) {
        order[e.key] = ++seq;
        fresh.add(e.key);
        changed = true;
      }
    }
    if (counts.length != old.length || counts.entries.any((e) => old[e.key] != e.value)) changed = true;
    // 없어진 것은 잊는다
    order.removeWhere((k, _) => !counts.containsKey(k));
    fresh.removeWhere((k) => !counts.containsKey(k));
    if (!changed) return;
    _bagView = {
      ...?_bagView,
      'counts': counts,
      'order': order,
      'new': fresh.toList(),
    };
    unawaited(store.saveJson('bagView', _bagView!));
  }

  /// 한 번 보면 새것 표시가 사라진다
  Future<void> markBagSeen(String key) async {
    final fresh = _bagNew;
    if (!fresh.remove(key)) return;
    _bagView = {...?_bagView, 'new': fresh.toList()};
    await store.saveJson('bagView', _bagView!);
    _notify();
  }
}

/// 묶음 81 #377: 가방 장비가 같은 부위에 입은 것보다 좋은지
extension EquipMarkOps on AppController {
  /// 그 부위가 비어 있으면 [CompareMark.fresh] · 같으면 null
  CompareMark? equipMark(EquipItem item) {
    final worn = armory.wornIn(item.slot);
    if (worn == null) return CompareMark.fresh;
    if (worn.uid == item.uid) return null;
    return EquipmentRules.markOf(EquipmentRules.compareItems(item, worn));
  }
}
