part of '../app_controller.dart';

/// 묶음 65 (2/2) #252 많이 걸은 날: 발자국 경험치 · 열쇠 조각 · 걸음 상자.
/// 혼자 하는 보상이라 서버 확인은 없고, 하루 기록(걸음 · counters)에서 다시 계산한다.
extension WalkRewardOps on AppController {
  static const _footSeen = 'walkSeen:foot';
  static const _shardSeen = 'walkSeen:shard';

  /// 정령(이별 뒤엔 첫 펫) 한 줄: 조각이 열쇠가 된 날 · 발자국이 새로 찍힌 날 한 번씩
  String? get walkTalk {
    final today = player.today;
    if (today == null) return null;
    final g = player.gauge;
    final foot = WalkRewardRules.steps2500(today.steps, today.date);
    final shardSeen = today.counters[_shardSeen] ?? 0;
    final footSeen = today.counters[_footSeen] ?? 0;
    String? line;
    if (g.shardKeysToday > shardSeen) {
      line = '조각 두 개가 맞물려 열쇠가 됐어요';
    } else if (foot > footSeen) {
      line = '오늘 더 걸은 만큼 단단해졌어요';
    }
    if (line != null) {
      _walkLine = line;
      _walkLineAt = _clock();
      Future.microtask(() => _markWalkSeen(foot, g.shardKeysToday));
    }
    final at = _walkLineAt;
    if (at != null && _clock().difference(at) < const Duration(minutes: 1)) return _walkLine;
    return null;
  }

  Future<void> _markWalkSeen(int foot, int shardKeys) async {
    final today = await _todayRecord();
    await _save(today.copyWith(
        counters: {...today.counters, _footSeen: foot, _shardSeen: shardKeys}));
  }

  /// 아직 안 연 걸음 상자 (그날 · 다음 날까지 남음): (그날, 단계)
  List<(DateTime, int)> get stepChests {
    final h = _history;
    if (h.isEmpty) return const [];
    final today = h.last;
    final opened = <String>{
      for (final r in h.length > 2 ? h.sublist(h.length - 2) : h)
        for (final k in r.counters.keys)
          if (k.startsWith('stepChest@')) k,
    };
    final out = <(DateTime, int)>[];
    for (final r in h.length > 2 ? h.sublist(h.length - 2) : h) {
      final gap = DateTime(today.date.year, today.date.month, today.date.day)
          .difference(DateTime(r.date.year, r.date.month, r.date.day))
          .inDays;
      if (gap > 1) continue;
      for (final t in WalkRewardRules.chestsOn(r.steps, r.date)) {
        if (!opened.contains(WalkRewardRules.openedKey(r.date, t))) out.add((r.date, t));
      }
    }
    return out;
  }

  /// 걸음 상자 모두 열기 → 받은 것 이름 (숫자 없이)
  Future<({List<String> got, int best})?> openStepChests() => _serial(() async {
        final chests = stepChests;
        if (chests.isEmpty) return null;
        final gifts = <String, int>{};
        var best = 0;
        for (final (_, t) in chests) {
          if (t > best) best = t;
          final (lo, hi) = WalkRewardRules.chestGold[t];
          gifts[Wallet.gold] = (gifts[Wallet.gold] ?? 0) + lo + _random.nextInt(hi - lo + 1);
          for (var i = 0; i < WalkRewardRules.chestMats[t]; i++) {
            final m = _chestMaterial();
            gifts[m.name] = (gifts[m.name] ?? 0) + 1;
          }
          if (_random.nextDouble() < WalkRewardRules.chestItemChance[t]) {
            final item = switch (_random.nextInt(3)) {
              0 => ShopItem.magicLens,
              1 => player.level.level >= 3 ? ShopItem.heal : ShopItem.healSmall,
              _ => player.level.level >= 3 ? ShopItem.mana : ShopItem.manaSmall,
            };
            gifts['item:${item.name}'] = (gifts['item:${item.name}'] ?? 0) + 1;
          }
        }
        final today = await _todayRecord();
        await _save(today.copyWith(counters: {
          ...today.counters,
          for (final (d, t) in chests) WalkRewardRules.openedKey(d, t): 1,
        }));
        final got = await _applyGifts(gifts, over: BagOver.mail, title: '걸음 상자');
        // 상자 숫자는 숨김: 이름만
        final names = [
          for (final g in got)
            if (g.startsWith('(')) g else g.replaceFirst(RegExp(r'\s\d+$'), ''),
        ];
        _notify();
        return (got: names, best: best);
      });

  /// 그 지역 재료: 3막 지역에 있으면 그 지역 몬스터 재료, 아니면 근처 필드 몬스터 재료
  MaterialId _chestMaterial() {
    final region = act3Open ? regionNow : null;
    final MonsterId m = region != null && region.normals.isNotEmpty
        ? region.normals[_random.nextInt(region.normals.length)]
        : FieldMonsterRules.pickCommon(_random.nextDouble(), _random.nextDouble());
    final d = LootRules.dropsOf(m);
    var common = d.common[_random.nextInt(d.common.length)];
    if (player.level.level <= 5) common = LootRules.earlyCommon[common] ?? common;
    return common;
  }
}
