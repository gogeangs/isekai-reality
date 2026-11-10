import '../rules/element_rules.dart';
import '../rules/equipment_rules.dart';

/// 만든 장비 하나
class EquipItem {
  const EquipItem({
    required this.uid,
    required this.base,
    required this.grade,
    this.enhance = 0,
    this.durability = EquipmentRules.maxDurability,
    this.extras = const {},
    this.materialsUsed = const {},
    this.enhanceManaSpent = 0,
    this.appearance,
    this.element,
    this.elementLevel = 0,
  });

  /// 속성 강화 단계 (11-11 #74, 0~3). 숫자는 숨기고 아이콘 빛으로만 보인다.
  final int elementLevel;

  /// 속성 (11-11 #63). 무기는 공격 속성, 나머지는 방어(저항) 속성. 없으면 무속성.
  final Element? element;

  /// 장비마다 다른 id
  final String uid;
  final EquipBase base;
  final EquipGrade grade;

  /// 강화 단계 (+0 ~ +10)
  final int enhance;

  /// 내구도 (0 ~ 100). 0이면 능력이 절반.
  final int durability;

  /// 추가 능력 (스탯 키 → 값)
  final Map<String, int> extras;

  /// 만들 때 넣은 재료 (분해할 때 절반을 돌려준다)
  final Map<String, int> materialsUsed;

  /// 강화에 쓴 마석 (분해할 때 절반을 돌려준다)
  final int enhanceManaSpent;

  /// 입은 모습 (2차: 캐릭터에 보이기. 지금은 비워 둔다)
  final String? appearance;

  EquipBaseInfo get info => EquipmentRules.info(base);
  EquipSlot get slot => info.slot;

  /// '철 단검 +3'
  String get name => enhance > 0 ? '${info.name} +$enhance' : info.name;

  EquipItem copyWith({
    int? enhance,
    int? durability,
    int? enhanceManaSpent,
    Element? element,
    int? elementLevel,
    bool clearElement = false,
  }) =>
      EquipItem(
        uid: uid,
        base: base,
        grade: grade,
        enhance: enhance ?? this.enhance,
        durability: durability ?? this.durability,
        extras: extras,
        materialsUsed: materialsUsed,
        enhanceManaSpent: enhanceManaSpent ?? this.enhanceManaSpent,
        appearance: appearance,
        element: clearElement ? null : (element ?? this.element),
        elementLevel: clearElement ? 0 : (elementLevel ?? this.elementLevel),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'base': base.name,
        'grade': grade.name,
        'enhance': enhance,
        'durability': durability,
        'extras': extras,
        'materialsUsed': materialsUsed,
        'enhanceManaSpent': enhanceManaSpent,
        'appearance': appearance,
        if (element != null) 'element': element!.name,
        if (elementLevel > 0) 'elementLevel': elementLevel,
      };

  static EquipItem? fromJson(Map<String, dynamic> j) {
    final base = EquipmentRules.baseByName(j['base'] as String? ?? '');
    if (base == null) return null;
    Map<String, int> counts(Object? raw) => {
          for (final e in ((raw as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        };
    return EquipItem(
      uid: j['uid'] as String,
      base: base,
      grade: EquipGrade.values.firstWhere((g) => g.name == j['grade'],
          orElse: () => EquipGrade.white),
      enhance: (j['enhance'] as num?)?.toInt() ?? 0,
      durability:
          (j['durability'] as num?)?.toInt() ?? EquipmentRules.maxDurability,
      extras: counts(j['extras']),
      materialsUsed: counts(j['materialsUsed']),
      enhanceManaSpent: (j['enhanceManaSpent'] as num?)?.toInt() ?? 0,
      appearance: j['appearance'] as String?,
      element: ElementRules.parse(j['element'] as String?),
      elementLevel: (j['elementLevel'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 가진 장비와 입은 장비 (11-10 #27)
class Armory {
  const Armory({
    this.items = const [],
    this.equipped = const {},
    this.crafts = 0,
    this.nextId = 1,
  });

  final List<EquipItem> items;

  /// 부위 → 입은 장비 uid
  final Map<EquipSlot, String> equipped;

  /// 지금까지 만든 수 (제작 숙련도)
  final int crafts;
  final int nextId;

  EquipItem? byUid(String uid) {
    for (final i in items) {
      if (i.uid == uid) return i;
    }
    return null;
  }

  EquipItem? wornIn(EquipSlot slot) {
    final uid = equipped[slot];
    return uid == null ? null : byUid(uid);
  }

  List<EquipItem> get worn => [
        for (final s in EquipSlot.values)
          if (wornIn(s) case final item?) item,
      ];

  bool isWorn(EquipItem item) => equipped[item.slot] == item.uid;

  Armory copyWith({
    List<EquipItem>? items,
    Map<EquipSlot, String>? equipped,
    int? crafts,
    int? nextId,
  }) =>
      Armory(
        items: items ?? this.items,
        equipped: equipped ?? this.equipped,
        crafts: crafts ?? this.crafts,
        nextId: nextId ?? this.nextId,
      );

  /// 장비 하나를 바꾼다
  Armory replace(EquipItem item) => copyWith(items: [
        for (final i in items) i.uid == item.uid ? item : i,
      ]);

  Map<String, dynamic> toJson() => {
        'items': [for (final i in items) i.toJson()],
        'equipped': {for (final e in equipped.entries) e.key.name: e.value},
        'crafts': crafts,
        'nextId': nextId,
      };

  factory Armory.fromJson(Map<String, dynamic> j) => Armory(
        items: [
          for (final raw in (j['items'] as List?) ?? const [])
            if (EquipItem.fromJson(Map<String, dynamic>.from(raw as Map))
                case final item?)
              item,
        ],
        equipped: {
          for (final e in ((j['equipped'] as Map?) ?? const {}).entries)
            for (final s in EquipSlot.values)
              if (s.name == e.key) s: e.value as String,
        },
        crafts: (j['crafts'] as num?)?.toInt() ?? 0,
        nextId: (j['nextId'] as num?)?.toInt() ?? 1,
      );
}
