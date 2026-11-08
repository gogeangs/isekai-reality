import '../models/daily_record.dart';
import 'rule_constants.dart';

/// 잡화상 물건
enum ShopItem {
  /// 여분의 열쇠: 오늘 던전 열쇠 +1 (주 1개)
  spareKey,

  /// 불씨 물약: 오늘 던전에서 '불씨의 일격'이 빨리 충전된다 (하루 1개)
  bulssiPotion,

  /// 마법 돋보기: 지금 있는 곳 주변 안개를 걷는다 (하루 1개)
  magicLens,
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
  });

  final ShopItem item;
  final String name;
  final String description;

  /// 정화 결정 가격
  final int price;
  final ShopLimit limit;

  /// assets/images/icon_<icon>.png
  final String icon;

  String get limitLabel => limit == ShopLimit.perDay ? '하루 1개' : '일주일 1개';
}

/// 살 수 있는지 판정 결과
enum PurchaseCheck { ok, notEnoughCrystals, limitReached, needsLocation }

/// 앱 안 시설 규칙: 정화 결정(돈), 잡화상, 여관.
///
/// 산 물건과 체크인은 하루 기록([DailyRecord])에 남기고,
/// 결정 잔액은 기록에서 매번 다시 계산한다.
class TownRules {
  TownRules._();

  static const List<ShopItemInfo> items = [
    ShopItemInfo(
      item: ShopItem.spareKey,
      name: '여분의 열쇠',
      description: '오늘 던전 열쇠가 하나 늘어나요.',
      price: 15,
      limit: ShopLimit.perWeek,
      icon: 'key',
    ),
    ShopItemInfo(
      item: ShopItem.bulssiPotion,
      name: '불씨 물약',
      description: '오늘 던전에서 불씨의 일격이 더 빨리 충전돼요.',
      price: 5,
      limit: ShopLimit.perDay,
      icon: 'spirit',
    ),
    ShopItemInfo(
      item: ShopItem.magicLens,
      name: '마법 돋보기',
      description: '지금 있는 곳 주변 150m의 안개를 걷어요.',
      price: 6,
      limit: ShopLimit.perDay,
      icon: 'sun',
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

  /// 지금 가진 정화 결정
  static int crystals(List<DailyRecord> history) {
    var c = 0;
    for (final r in history) {
      c += crystalsEarnedOn(r) - crystalsSpentOn(r);
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

  static PurchaseCheck canBuy(
    List<DailyRecord> history,
    ShopItem item, {
    bool hasLocation = true,
  }) {
    if (boughtInLimit(history, item) >= 1) return PurchaseCheck.limitReached;
    if (crystals(history) < info(item).price) {
      return PurchaseCheck.notEnoughCrystals;
    }
    if (item == ShopItem.magicLens && !hasLocation) {
      return PurchaseCheck.needsLocation;
    }
    return PurchaseCheck.ok;
  }

  /// 그날 산 여분의 열쇠 수 (열쇠 계산에 더한다)
  static int spareKeysOn(DailyRecord r) => boughtOn(r, ShopItem.spareKey);

  /// 그날 불씨 물약을 마셨는지
  static bool potionActive(DailyRecord? r) =>
      r != null && boughtOn(r, ShopItem.bulssiPotion) > 0;

  // ───────────────────────── 여관

  /// 지금 체크인할 수 있는 시간인지 (18시 ~ 22시 59분)
  static bool innOpen(DateTime now) =>
      now.hour >= RuleConstants.innOpenHour &&
      now.hour < RuleConstants.innCloseHour;

  /// 어젯밤 여관에서 쉬고 오늘 7시간 이상 잤으면 보너스
  static int innRestExp({required bool restedLastNight, int? sleepMinutes}) =>
      restedLastNight &&
              (sleepMinutes ?? 0) >= RuleConstants.sleepGoodMinutes
          ? RuleConstants.innRestExp
          : 0;
}
