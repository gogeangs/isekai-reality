import '../models/daily_record.dart';
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
  });

  final ShopItem item;
  final String name;
  final String description;

  /// 정화 결정 가격
  final int price;
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
  notEnoughCrystals,
  limitReached,
  needsLocation,
  levelTooLow,
  alreadyFull,
}

/// 앱 안 시설 규칙: 정화 결정(돈), 잡화상, 여관.
///
/// 산 물건과 휴식은 하루 기록([DailyRecord])에 남기고,
/// 결정 잔액은 기록에서 매번 다시 계산한다.
class TownRules {
  TownRules._();

  static const List<ShopItemInfo> items = [
    ShopItemInfo(
      item: ShopItem.healSmall,
      name: '작은 회복 물약',
      description: '마시면 HP가 20% 차요.',
      price: 1,
      limit: ShopLimit.perDay,
      perLimit: 3,
      hpRatio: 0.2,
      icon: 'potion_heal_1',
    ),
    ShopItemInfo(
      item: ShopItem.heal,
      name: '회복 물약',
      description: '마시면 HP가 40% 차요.',
      price: 3,
      limit: ShopLimit.perDay,
      perLimit: 3,
      minLevel: 3,
      hpRatio: 0.4,
      icon: 'potion_heal_2',
    ),
    ShopItemInfo(
      item: ShopItem.manaSmall,
      name: '작은 마나 물약',
      description: '정령의 MP가 20% 차요.',
      price: 1,
      limit: ShopLimit.perDay,
      perLimit: 3,
      mpRatio: 0.2,
      icon: 'potion_mana_1',
    ),
    ShopItemInfo(
      item: ShopItem.mana,
      name: '마나 물약',
      description: '정령의 MP가 40% 차요.',
      price: 3,
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
      price: 15,
      limit: ShopLimit.perWeek,
      icon: 'icon_key',
    ),
    ShopItemInfo(
      item: ShopItem.bulssiPotion,
      name: '정령 물약',
      description: '오늘 던전에서 정령의 일격이 더 빨리 충전돼요.',
      price: 5,
      limit: ShopLimit.perDay,
      icon: 'potion_spirit_fire',
    ),
    ShopItemInfo(
      item: ShopItem.magicLens,
      name: '마법 돋보기',
      description: '지금 있는 곳 주변 150m의 안개를 걷어요.',
      price: 6,
      limit: ShopLimit.perDay,
      icon: 'icon_lens',
    ),
  ];

  static ShopItemInfo info(ShopItem item) =>
      items.firstWhere((i) => i.item == item);

  static ShopItem? _parse(String name) {
    for (final i in ShopItem.values) {
      if (i.name == name) return i;
    }
    return null;
  }

  // ───────────────────────── 정화 결정

  static int crystalsEarnedOn(DailyRecord r) {
    var c = 0;
    for (final run in r.dungeonRuns) {
      c += run.cleared
          ? RuleConstants.crystalsPerDungeonClear
          : RuleConstants.crystalsPerDungeonFail;
    }
    final field = r.fieldMonstersPurified > RuleConstants.maxFieldMonstersPerDay
        ? RuleConstants.maxFieldMonstersPerDay
        : r.fieldMonstersPurified;
    return c + field * RuleConstants.crystalsPerFieldMonster;
  }

  static int crystalsSpentOn(DailyRecord r) {
    var c = 0;
    for (final name in r.shopPurchases) {
      final item = _parse(name);
      if (item != null) c += info(item).price;
    }
    return c;
  }

  /// 지금 가진 정화 결정 (연속 휴식 보너스 결정 포함)
  static int crystals(List<DailyRecord> history) {
    var c = 0;
    final streaks = restStreaks(history);
    for (var i = 0; i < history.length; i++) {
      final r = history[i];
      c += crystalsEarnedOn(r) - crystalsSpentOn(r);
      if (r.rested) c += restStreakReward(streaks[i]).$2;
    }
    return c < 0 ? 0 : c;
  }

  // ───────────────────────── 잡화상

  static int boughtOn(DailyRecord r, ShopItem item) =>
      r.shopPurchases.where((p) => p == item.name).length;

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

  /// [hpFull]·[mpFull] 은 지금 HP·MP가 가득인지 (가득이면 물약을 살 수 없다)
  static PurchaseCheck canBuy(
    List<DailyRecord> history,
    ShopItem item, {
    bool hasLocation = true,
    int level = 99,
    bool hpFull = false,
    bool mpFull = false,
  }) {
    final i = info(item);
    if (level < i.minLevel) return PurchaseCheck.levelTooLow;
    if (boughtInLimit(history, item) >= i.perLimit) {
      return PurchaseCheck.limitReached;
    }
    if (crystals(history) < i.price) return PurchaseCheck.notEnoughCrystals;
    if (item == ShopItem.magicLens && !hasLocation) {
      return PurchaseCheck.needsLocation;
    }
    if (i.hpRatio > 0 && hpFull) return PurchaseCheck.alreadyFull;
    if (i.mpRatio > 0 && mpFull) return PurchaseCheck.alreadyFull;
    return PurchaseCheck.ok;
  }

  /// 그날 산 여분의 열쇠 수 (열쇠 계산에 더한다)
  static int spareKeysOn(DailyRecord r) => boughtOn(r, ShopItem.spareKey);

  /// 그날 정령 물약을 마셨는지
  static bool potionActive(DailyRecord? r) =>
      r != null && boughtOn(r, ShopItem.bulssiPotion) > 0;

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

  /// 연속 [streak] 일째에 받는 (경험치, 정화 결정). 해당 없으면 (0, 0).
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
