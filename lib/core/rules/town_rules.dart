import '../models/daily_record.dart';
import 'board_rules.dart';
import 'lens_rules.dart';
import 'materials.dart';
import 'rule_constants.dart';

/// 잡화상 물건 (이름은 저장된 기록과 맞아야 하므로 바꾸지 않는다)
enum ShopItem {
  /// 여분의 열쇠: 오늘 던전 열쇠 +1 (주 1개)
  spareKey,

  /// 정령 물약: 오늘 던전에서 '정령의 일격'이 빨리 충전된다 (하루 1개)
  bulssiPotion,

  /// 마법 돋보기: 지금 있는 곳 주변 안개를 걷는다 (하루 1개)
  magicLens,

  /// 작은 회복 물약: HP 20% (1등급)
  healSmall,

  /// 회복 물약: HP 40% (2등급, Lv.3)
  heal,

  /// 작은 마나 물약: MP 20% (1등급)
  manaSmall,

  /// 마나 물약: MP 40% (2등급, Lv.3)
  mana,

  /// 원정 나침반: 쓰면 다음 정령 원정의 이동 시간이 절반 (하루 1개, 11-10)
  expeditionCompass,

  /// 성장의 향 (예전 이름 정화의 향): 피운 날은 필드 몬스터 경험치 1.5배 (하루 1개, 11-10)
  purifyIncense,

  /// 철 조각: 무기 재료 (하루 5개, 11-10)
  ironShard,

  /// 나뭇가지: 지팡이 재료 (하루 5개, 11-10)
  twig,

  /// 약초: 회복 물약 재료 (하루 5개, 11-11)
  herb,

  /// 마법 돋보기 「감정」: 카메라로 비춘 사람의 이세계 종족을 감정한다 (11-11 #60, 하루 3개).
  /// 예전 [magicLens](안개 걷기)와는 다른 물건이다.
  raceLens,
}

enum ShopLimit { perDay, perWeek }

class ShopItemInfo {
  const ShopItemInfo({
    required this.item,
    required this.name,
    required this.description,
    required this.price,
    required this.limit,
    required this.icon,
    this.perLimit = 1,
    this.minLevel = 1,
    this.hpRatio = 0,
    this.mpRatio = 0,
    this.material,
  });

  final ShopItem item;
  final String name;
  final String description;

  /// 금화 가격 (11-10부터. 예전에 결정으로 산 기록은 [legacyPrice] 마석)
  final int price;

  /// 예전 정화 결정 가격 = 지금 마석으로 쓴 것으로 계산한다
  int get legacyPrice => price ~/ RuleConstants.goldPriceMultiplier;

  /// 사면 가방이 아니라 재료로 들어가는 물건
  final MaterialId? material;
  final ShopLimit limit;

  /// 기간([limit]) 안에 살 수 있는 개수
  final int perLimit;

  /// 이 레벨부터 살 수 있다
  final int minLevel;

  /// 사자마자 마셔서 채우는 HP · MP (최대치에 대한 비율)
  final double hpRatio;
  final double mpRatio;

  /// assets/images/<icon>.png (icon_ 으로 시작하지 않는 그림도 있다)
  final String icon;

  String get limitLabel =>
      '${limit == ShopLimit.perDay ? '하루' : '일주일'} $perLimit개';
}

/// 살 수 있는지 판정 결과
enum PurchaseCheck {
  ok,
  /// 금화가 모자란다
  notEnoughCrystals,
  limitReached,
  needsLocation,
  levelTooLow,

  /// 가방 칸이 가득 (11-11 #48)
  bagFull,
}

/// 가방에서 꺼내 쓸 수 있는지
enum UseCheck {
  ok,

  /// 가방에 없다
  none,

  /// HP·MP가 이미 가득
  alreadyFull,

  /// 정령 물약·성장의 향을 오늘 이미 썼다, 원정 나침반을 써 두었다
  alreadyActive,
}

/// 앱 안 시설 규칙: 마석·금화(돈), 재료, 잡화상, 여관.
///
/// 산 물건, 얻고 쓴 것, 휴식은 하루 기록([DailyRecord])에 남기고,
/// 잔액은 기록에서 매번 다시 계산한다.
///
/// 11-10 마석·금화: 예전 정화 결정은 같은 수의 마석이 되고(규칙 그대로 계산),
/// 금화는 0에서 시작한다. 마석 1개는 잡화상에서 금화 10으로 판다.
class TownRules {
  TownRules._();

  /// 잡화상에 보이는 물건. 마법 돋보기는 안개를 없애며 뺐다 (11-10, 그 자리에 넣을 물건은 따로 정함).
  /// 예전에 산 기록의 값은 [info] 로 계속 계산한다.
  static List<ShopItemInfo> get items =>
      [for (final i in _allItems) if (!retired.contains(i.item)) i];

  static const Set<ShopItem> retired = {ShopItem.magicLens};

  static const List<ShopItemInfo> _allItems = [
    ShopItemInfo(
      item: ShopItem.healSmall,
      name: '작은 회복 물약',
      description: '가방에 넣어 두고, 마시면 HP가 20% 차요.',
      price: 10,
      limit: ShopLimit.perDay,
      perLimit: 3,
      hpRatio: 0.2,
      icon: 'potion_heal_1',
    ),
    ShopItemInfo(
      item: ShopItem.heal,
      name: '회복 물약',
      description: '가방에 넣어 두고, 마시면 HP가 40% 차요.',
      price: 30,
      limit: ShopLimit.perDay,
      perLimit: 3,
      minLevel: 3,
      hpRatio: 0.4,
      icon: 'potion_heal_2',
    ),
    ShopItemInfo(
      item: ShopItem.manaSmall,
      name: '작은 마나 물약',
      description: '가방에 넣어 두고, 마시면 정령 MP가 20% 차요.',
      price: 10,
      limit: ShopLimit.perDay,
      perLimit: 3,
      mpRatio: 0.2,
      icon: 'potion_mana_1',
    ),
    ShopItemInfo(
      item: ShopItem.mana,
      name: '마나 물약',
      description: '가방에 넣어 두고, 마시면 정령 MP가 40% 차요.',
      price: 30,
      limit: ShopLimit.perDay,
      perLimit: 3,
      minLevel: 3,
      mpRatio: 0.4,
      icon: 'potion_mana_2',
    ),
    ShopItemInfo(
      item: ShopItem.spareKey,
      name: '여분의 열쇠',
      description: '오늘 던전 열쇠가 하나 늘어나요.',
      price: 150,
      limit: ShopLimit.perWeek,
      icon: 'icon_key',
    ),
    ShopItemInfo(
      item: ShopItem.bulssiPotion,
      name: '정령 물약',
      description: '가방에 넣어 두고, 마신 날은 던전에서 정령의 일격이 빨리 차요.',
      price: 50,
      limit: ShopLimit.perDay,
      icon: 'potion_spirit_fire',
    ),
    ShopItemInfo(
      item: ShopItem.expeditionCompass,
      name: '원정 나침반',
      description: '가방에 넣어 두고, 쓰면 다음 정령 원정의 이동 시간이 절반이 돼요.',
      price: 50,
      limit: ShopLimit.perDay,
      icon: 'icon_expedition', // 지도 원정 아이콘과 같은 나침반 그림
    ),
    ShopItemInfo(
      item: ShopItem.purifyIncense,
      name: '성장의 향',
      description: '가방에 넣어 두고, 피운 날은 필드 몬스터 경험치가 1.5배예요.',
      price: 60,
      limit: ShopLimit.perDay,
      icon: 'item_incense',
    ),
    ShopItemInfo(
      item: ShopItem.ironShard,
      name: '철 조각',
      description: '대장간에서 무기를 만들 때 써요.',
      price: 20,
      limit: ShopLimit.perDay,
      perLimit: 5,
      icon: 'mat_ironShard',
      material: MaterialId.ironShard,
    ),
    ShopItemInfo(
      item: ShopItem.twig,
      name: '나뭇가지',
      description: '대장간에서 지팡이를 만들 때 써요.',
      price: 10,
      limit: ShopLimit.perDay,
      perLimit: 5,
      icon: 'mat_twig',
      material: MaterialId.twig,
    ),
    ShopItemInfo(
      item: ShopItem.herb,
      name: '약초',
      description: '회복 물약 재료예요. 물약 만들기는 곧 열려요.',
      price: 15,
      limit: ShopLimit.perDay,
      perLimit: 5,
      icon: 'mat_herb',
      material: MaterialId.herb,
    ),
    ShopItemInfo(
      item: ShopItem.raceLens,
      name: '마법 돋보기',
      description: '가방에 넣어 두고, 카메라로 비추면 그 사람의 이세계 종족을 감정해요.',
      price: LensRules.price,
      limit: ShopLimit.perDay,
      perLimit: LensRules.perDay,
      icon: 'icon_lens',
    ),
    ShopItemInfo(
      item: ShopItem.magicLens,
      name: '마법 돋보기',
      description: '지금 있는 곳 주변 150m의 안개를 걷어요.',
      price: 60,
      limit: ShopLimit.perDay,
      icon: 'icon_lens',
    ),
  ];

  static ShopItemInfo info(ShopItem item) =>
      _allItems.firstWhere((i) => i.item == item);

  static ShopItem? _parse(String name) {
    for (final i in ShopItem.values) {
      if (i.name == name) return i;
    }
    return null;
  }

  // ───────────────────────── 마석 · 금화 · 재료

  /// 그날 규칙으로 얻은 마석 (예전 정화 결정과 같은 계산)
  static int crystalsEarnedOn(DailyRecord r) {
    var c = 0;
    for (final run in r.dungeonRuns) {
      c += run.cleared
          ? RuleConstants.crystalsPerDungeonClear
          : RuleConstants.crystalsPerDungeonFail;
    }
    // 11-11 #69: 5마리 뒤로는 마석이 줄어든다
    final field = RuleConstants.fieldUnits(r.fieldMonstersPurified);
    return c + (field * RuleConstants.crystalsPerFieldMonster).floor();
  }

  /// 그날 예전 결정 가격으로 산 것 (지금은 마석으로 쓴 것으로 센다)
  static int crystalsSpentOn(DailyRecord r) {
    var c = 0;
    for (final name in r.shopPurchases) {
      final item = _parse(name);
      if (item != null) c += info(item).legacyPrice;
    }
    return c;
  }

  /// 그날 금화로 산 것
  static int goldSpentOnShop(DailyRecord r) {
    var c = 0;
    for (final name in r.goldPurchases) {
      final item = _parse(name);
      if (item != null) c += info(item).price;
    }
    return c;
  }

  /// 그날 얻은 마석 (규칙 몫 + 추가로 얻은 것)
  static int manaStonesEarnedOn(DailyRecord r) =>
      crystalsEarnedOn(r) +
      (r.gains[Wallet.manaStone] ?? 0) -
      (r.counters[tiredManaKey] ?? 0);

  /// 지친 상태로 덜 받은 마석·경험치 (11-11 #75, 숨김)
  static const tiredManaKey = 'tiredMana';
  static const tiredExpKey = 'tiredExp';

  /// 지금 가진 마석
  static int manaStones(List<DailyRecord> history) {
    var c = 0;
    final streaks = restStreaks(history);
    for (var i = 0; i < history.length; i++) {
      final r = history[i];
      c += manaStonesEarnedOn(r) -
          crystalsSpentOn(r) -
          (r.spends[Wallet.manaStone] ?? 0);
      if (r.rested) c += restStreakReward(streaks[i]).$2;
    }
    return c < 0 ? 0 : c;
  }

  /// 예전 이름 (마석과 같다)
  static int crystals(List<DailyRecord> history) => manaStones(history);

  /// 지금 가진 금화 (주간 의뢰 보상 포함)
  static int gold(List<DailyRecord> history) {
    var g = 0;
    for (var i = 0; i < history.length; i++) {
      final r = history[i];
      g += (r.gains[Wallet.gold] ?? 0) -
          goldSpentOnShop(r) -
          (r.spends[Wallet.gold] ?? 0) +
          BoardRules.weeklyCompletedOn(history, i) * BoardRules.weeklyGold;
    }
    return g < 0 ? 0 : g;
  }

  /// 지금 가진 재료 (0개는 빼고)
  static Map<MaterialId, int> materials(List<DailyRecord> history) {
    final m = <MaterialId, int>{};
    void add(String key, int n) {
      final id = Materials.byName(key);
      if (id != null) m[id] = (m[id] ?? 0) + n;
    }

    for (final r in history) {
      r.gains.forEach(add);
      r.spends.forEach((k, v) => add(k, -v));
      for (final name in r.goldPurchases) {
        final item = _parse(name);
        final mat = item == null ? null : info(item).material;
        if (mat != null) m[mat] = (m[mat] ?? 0) + 1;
      }
    }
    m.removeWhere((_, n) => n <= 0);
    return m;
  }

  /// 마석 [n] 개를 팔 수 있는지
  static bool canSell(List<DailyRecord> history, int n) =>
      n > 0 && manaStones(history) >= n;

  // ───────────────────────── 잡화상

  /// 그날 산 개수 (예전 결정으로 산 것 + 금화로 산 것)
  static int boughtOn(DailyRecord r, ShopItem item) =>
      r.shopPurchases.where((p) => p == item.name).length +
      r.goldPurchases.where((p) => p == item.name).length;

  /// 월요일에 시작하는 그 주의 첫날
  static DateTime weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// 오늘(마지막 기록)이 속한 주 또는 오늘 하루 동안 산 개수
  static int boughtInLimit(List<DailyRecord> history, ShopItem item) {
    if (history.isEmpty) return 0;
    final today = history.last;
    if (info(item).limit == ShopLimit.perDay) return boughtOn(today, item);
    final start = weekStart(today.date);
    return history
        .where((r) => !r.date.isBefore(start))
        .fold(0, (sum, r) => sum + boughtOn(r, item));
  }

  // ───────────────────────── 가방 (2026-11-10)

  /// 사면 가방에 들어가는 물건 (나머지는 사자마자 쓴다)
  static const Set<ShopItem> bagItems = {
    ShopItem.healSmall,
    ShopItem.heal,
    ShopItem.manaSmall,
    ShopItem.mana,
    ShopItem.bulssiPotion,
    ShopItem.expeditionCompass,
    ShopItem.purifyIncense,
    ShopItem.raceLens,
  };

  static int usedOn(DailyRecord r, ShopItem item) =>
      r.itemsUsed.where((p) => p == item.name).length;

  /// 버리거나 판 개수를 적는 counters 키 (11-11 #48)
  static String dropKey(ShopItem item) => 'drop:${item.name}';

  /// 선물로 받은 개수를 적는 counters 키 (정령 편지 등)
  static String giftKey(ShopItem item) => 'gift:${item.name}';

  /// 가방에 남은 개수 (산 것 − 쓴 것 − 버리거나 판 것)
  static int bagCount(List<DailyRecord> history, ShopItem item) {
    var n = 0;
    for (final r in history) {
      n += boughtOn(r, item) +
          (r.counters[giftKey(item)] ?? 0) -
          usedOn(r, item) -
          (r.counters[dropKey(item)] ?? 0);
    }
    return n < 0 ? 0 : n;
  }

  /// 가방에서 꺼내 쓸 수 있는지. [hpFull]·[mpFull] 은 지금 HP·MP가 가득인지.
  static UseCheck canUse(
    List<DailyRecord> history,
    ShopItem item, {
    bool hpFull = false,
    bool mpFull = false,
    bool compassReady = false,
  }) {
    if (bagCount(history, item) <= 0) return UseCheck.none;
    final i = info(item);
    if (i.hpRatio > 0 && hpFull) return UseCheck.alreadyFull;
    if (i.mpRatio > 0 && mpFull) return UseCheck.alreadyFull;
    if (item == ShopItem.bulssiPotion && potionActive(history.lastOrNull)) {
      return UseCheck.alreadyActive;
    }
    if (item == ShopItem.purifyIncense && incenseActive(history.lastOrNull)) {
      return UseCheck.alreadyActive;
    }
    if (item == ShopItem.expeditionCompass && compassReady) {
      return UseCheck.alreadyActive;
    }
    return UseCheck.ok;
  }

  static PurchaseCheck canBuy(
    List<DailyRecord> history,
    ShopItem item, {
    bool hasLocation = true,
    int level = 99,
    bool bagRoom = true,
  }) {
    final i = info(item);
    if (level < i.minLevel) return PurchaseCheck.levelTooLow;
    if (boughtInLimit(history, item) >= i.perLimit) {
      return PurchaseCheck.limitReached;
    }
    if (gold(history) < i.price) return PurchaseCheck.notEnoughCrystals;
    if (item == ShopItem.magicLens && !hasLocation) {
      return PurchaseCheck.needsLocation;
    }
    if ((bagItems.contains(item) || i.material != null) && !bagRoom) {
      return PurchaseCheck.bagFull;
    }
    return PurchaseCheck.ok;
  }

  /// 그날 산 여분의 열쇠 수 (열쇠 계산에 더한다)
  static int spareKeysOn(DailyRecord r) =>
      boughtOn(r, ShopItem.spareKey) + (r.counters['bonusKeys'] ?? 0);

  /// 걸음 물약으로 더 찬 던전 게이지 걸음 (11-11 #74)
  static int gaugeBonusOn(DailyRecord r) => r.counters['gaugeBonus'] ?? 0;

  /// 그날 정령 물약을 마셨는지 (가방에서 꺼내 마신 날)
  static bool potionActive(DailyRecord? r) =>
      r != null && usedOn(r, ShopItem.bulssiPotion) > 0;

  /// 그날 성장의 향을 피웠는지 (필드 몬스터 경험치 1.5배)
  static bool incenseActive(DailyRecord? r) =>
      r != null && usedOn(r, ShopItem.purifyIncense) > 0;

  // ───────────────────────── 여관

  /// 체크인하고 [RuleConstants.restHours] 시간이 지났는지
  static bool restDone(DateTime startedAt, DateTime now) =>
      !now.isBefore(startedAt.add(const Duration(hours: RuleConstants.restHours)));

  /// 휴식이 끝나기까지 남은 시간 (끝났으면 0)
  static Duration restLeft(DateTime startedAt, DateTime now) {
    final left = startedAt
        .add(const Duration(hours: RuleConstants.restHours))
        .difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  /// 기록마다 그날까지의 연속 휴식 일수 (쉬지 않은 날은 0).
  /// 날짜가 하루라도 비면 다시 1부터 센다.
  static List<int> restStreaks(List<DailyRecord> history) {
    final out = <int>[];
    var streak = 0;
    DateTime? prev;
    for (final r in history) {
      final continuous = prev != null && _daysBetween(prev, r.date) == 1;
      if (r.rested) {
        streak = continuous && streak > 0 ? streak + 1 : 1;
      } else {
        streak = 0;
      }
      out.add(streak);
      prev = r.date;
    }
    return out;
  }

  /// 오늘까지 이어진 연속 휴식 일수. 오늘 아직 안 쉬었으면 어제까지의 연속.
  static int currentRestStreak(List<DailyRecord> history) {
    if (history.isEmpty) return 0;
    final s = restStreaks(history);
    if (history.last.rested) return s.last;
    if (history.length >= 2 &&
        _daysBetween(history[history.length - 2].date, history.last.date) ==
            1) {
      return s[s.length - 2];
    }
    return 0;
  }

  /// 연속 [streak] 일째에 받는 (경험치, 마석). 해당 없으면 (0, 0).
  static (int, int) restStreakReward(int streak) {
    for (final (days, exp, crystals) in RuleConstants.restStreakRewards) {
      if (streak == days) return (exp, crystals);
    }
    final last = RuleConstants.restStreakRewards.last;
    if (streak > last.$1 &&
        (streak - last.$1) % RuleConstants.restStreakRepeatEvery == 0) {
      return (last.$2, last.$3);
    }
    return (0, 0);
  }

  /// 다음 연속 보너스까지 남은 날과 그 보상
  static ({int daysLeft, int exp, int crystals}) nextRestReward(int streak) {
    for (var d = streak + 1; d < streak + 30; d++) {
      final r = restStreakReward(d);
      if (r.$1 > 0) return (daysLeft: d - streak, exp: r.$1, crystals: r.$2);
    }
    return (daysLeft: 0, exp: 0, crystals: 0);
  }

  static int _daysBetween(DateTime a, DateTime b) =>
      DateTime(b.year, b.month, b.day)
          .difference(DateTime(a.year, a.month, a.day))
          .inDays;
}
