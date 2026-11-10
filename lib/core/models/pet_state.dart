import '../rules/element_rules.dart';
import '../rules/pet_rules.dart';

/// 펫 알 (가방 한 칸). 품으면 [incubatedAt] 부터 12시간 뒤 부화.
class PetEgg {
  const PetEgg(
      {required this.id, this.source = '', this.incubatedAt, this.element});

  /// 알을 얻을 때의 주 속성 (11-11 #63): 그 속성 펫이 잘 태어난다
  final String? element;

  final String id;

  /// 어디서 얻었는지 ('field', 'dungeon', 'board', 'gift', 'letter')
  final String source;
  final DateTime? incubatedAt;

  PetEgg incubate(DateTime at) =>
      PetEgg(id: id, source: source, incubatedAt: at, element: element);

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source,
        if (incubatedAt != null) 'incubatedAt': incubatedAt!.toIso8601String(),
        if (element != null) 'element': element,
      };

  factory PetEgg.fromJson(Map<String, dynamic> j) => PetEgg(
        id: j['id'] as String,
        source: j['source'] as String? ?? '',
        incubatedAt: j['incubatedAt'] == null
            ? null
            : DateTime.tryParse(j['incubatedAt'] as String),
        element: j['element'] as String?,
      );
}

/// 함께 사는 펫 하나
class Pet {
  const Pet({
    required this.uid,
    required this.species,
    required this.name,
    this.exp = 0,
    this.bond = 0,
    required this.bornAt,
    this.evoElement,
  });

  /// 진화 갈래 속성 (11-11 #63, 구조만. 진화 상세는 나중에 채운다)
  final String? evoElement;

  /// 펫 속성: 종류의 기본 속성
  Element? get element => PetRules.info(species).element;

  final String uid;
  final PetSpecies species;
  final String name;
  final int exp;

  /// 친밀도 0~100
  final int bond;
  final DateTime bornAt;

  int get level => PetRules.levelFor(exp);
  bool get adult => level >= PetRules.adultLevel;
  PetSpeciesInfo get info => PetRules.info(species);

  Pet copyWith({String? name, int? exp, int? bond}) => Pet(
        uid: uid,
        species: species,
        name: name ?? this.name,
        exp: exp ?? this.exp,
        bond: bond ?? this.bond,
        bornAt: bornAt,
        evoElement: evoElement,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'species': species.name,
        'name': name,
        'exp': exp,
        'bond': bond,
        'bornAt': bornAt.toIso8601String(),
        if (evoElement != null) 'evoElement': evoElement,
      };

  static Pet? fromJson(Map<String, dynamic> j) {
    final s = PetRules.byName(j['species'] as String? ?? '');
    if (s == null) return null;
    return Pet(
      uid: j['uid'] as String,
      species: s,
      name: j['name'] as String? ?? PetRules.info(s).name,
      exp: (j['exp'] as num?)?.toInt() ?? 0,
      bond: (j['bond'] as num?)?.toInt() ?? 0,
      bornAt: DateTime.tryParse(j['bornAt'] as String? ?? '') ?? DateTime(2026),
      evoElement: j['evoElement'] as String?,
    );
  }
}

/// 정령 이별 · 알 · 펫 · 편지 (11-11 #37·#38). 따로 저장한다 ('pets').
class PetState {
  const PetState({
    this.eggs = const [],
    this.pets = const [],
    this.companion,
    this.farewellAt,
    this.firstSpiritName,
    this.firstSpiritKind,
    this.firstEggFound = false,
    this.letters = const [],
    this.skippedLetters = const [],
    this.recipeNotes = 0,
    this.boardEggWeeks = const [],
    this.nextId = 1,
    this.stepsDay,
    this.stepsCounted = 0,
    this.seenSpecies = const [],
  });

  /// 한 번이라도 함께한 펫 종류 (도감 펫 탭)
  final List<String> seenSpecies;

  Set<PetSpecies> get seen => {
        for (final n in seenSpecies)
          if (PetRules.byName(n) case final s?) s,
        for (final p in pets) p.species,
      };

  /// 동행 펫 걸음 경험치를 센 날과 그날 센 걸음
  final String? stepsDay;
  final int stepsCounted;

  final List<PetEgg> eggs;
  final List<Pet> pets;

  /// 데리고 다니는 펫 uid
  final String? companion;

  /// 정령과 헤어진 때 (null 이면 아직 정령과 함께)
  final DateTime? farewellAt;

  /// 처음 함께한 정령 (이별 때 남긴다)
  final String? firstSpiritName;
  final String? firstSpiritKind;

  /// Lv.11 전 알을 이미 얻었는지
  final bool firstEggFound;

  /// 받은 편지 id (받은 순서)
  final List<String> letters;

  /// 이별 전에 이미 지나간 편지 (보내지 않는다)
  final List<String> skippedLetters;

  /// 아직 읽지 않은 레시피 쪽지 (연금술 공방이 열리면 쓴다)
  final int recipeNotes;

  /// 주간 의뢰 알을 받은 주 (월요일 'yyyy-mm-dd')
  final List<String> boardEggWeeks;
  final int nextId;

  bool get farewellDone => farewellAt != null;

  Pet? get companionPet {
    for (final p in pets) {
      if (p.uid == companion) return p;
    }
    return pets.isEmpty ? null : pets.first;
  }

  Pet? byUid(String uid) {
    for (final p in pets) {
      if (p.uid == uid) return p;
    }
    return null;
  }

  PetState copyWith({
    List<PetEgg>? eggs,
    List<Pet>? pets,
    String? companion,
    DateTime? farewellAt,
    String? firstSpiritName,
    String? firstSpiritKind,
    bool? firstEggFound,
    List<String>? letters,
    List<String>? skippedLetters,
    int? recipeNotes,
    List<String>? boardEggWeeks,
    int? nextId,
    String? stepsDay,
    int? stepsCounted,
    List<String>? seenSpecies,
  }) =>
      PetState(
        eggs: eggs ?? this.eggs,
        pets: pets ?? this.pets,
        companion: companion ?? this.companion,
        farewellAt: farewellAt ?? this.farewellAt,
        firstSpiritName: firstSpiritName ?? this.firstSpiritName,
        firstSpiritKind: firstSpiritKind ?? this.firstSpiritKind,
        firstEggFound: firstEggFound ?? this.firstEggFound,
        letters: letters ?? this.letters,
        skippedLetters: skippedLetters ?? this.skippedLetters,
        recipeNotes: recipeNotes ?? this.recipeNotes,
        boardEggWeeks: boardEggWeeks ?? this.boardEggWeeks,
        nextId: nextId ?? this.nextId,
        stepsDay: stepsDay ?? this.stepsDay,
        stepsCounted: stepsCounted ?? this.stepsCounted,
        seenSpecies: seenSpecies ??
            {
              ...this.seenSpecies,
              for (final p in pets ?? this.pets) p.species.name,
            }.toList(),
      );

  /// 펫 하나를 바꾼다
  PetState replace(Pet pet) =>
      copyWith(pets: [for (final p in pets) p.uid == pet.uid ? pet : p]);

  Map<String, dynamic> toJson() => {
        'eggs': [for (final e in eggs) e.toJson()],
        'pets': [for (final p in pets) p.toJson()],
        if (companion != null) 'companion': companion,
        if (farewellAt != null) 'farewellAt': farewellAt!.toIso8601String(),
        if (firstSpiritName != null) 'firstSpiritName': firstSpiritName,
        if (firstSpiritKind != null) 'firstSpiritKind': firstSpiritKind,
        'firstEggFound': firstEggFound,
        'letters': letters,
        'skippedLetters': skippedLetters,
        'recipeNotes': recipeNotes,
        'boardEggWeeks': boardEggWeeks,
        'nextId': nextId,
        if (stepsDay != null) 'stepsDay': stepsDay,
        'stepsCounted': stepsCounted,
        'seenSpecies': [for (final s in seen) s.name],
      };

  factory PetState.fromJson(Map<String, dynamic> j) {
    List<String> strings(Object? v) =>
        [for (final s in (v as List?) ?? const []) s as String];
    return PetState(
      eggs: [
        for (final e in (j['eggs'] as List?) ?? const [])
          PetEgg.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      pets: [
        for (final p in (j['pets'] as List?) ?? const [])
          if (Pet.fromJson(Map<String, dynamic>.from(p as Map)) case final pet?)
            pet,
      ],
      companion: j['companion'] as String?,
      farewellAt: j['farewellAt'] == null
          ? null
          : DateTime.tryParse(j['farewellAt'] as String),
      firstSpiritName: j['firstSpiritName'] as String?,
      firstSpiritKind: j['firstSpiritKind'] as String?,
      firstEggFound: j['firstEggFound'] as bool? ?? false,
      letters: strings(j['letters']),
      skippedLetters: strings(j['skippedLetters']),
      recipeNotes: (j['recipeNotes'] as num?)?.toInt() ?? 0,
      boardEggWeeks: strings(j['boardEggWeeks']),
      nextId: (j['nextId'] as num?)?.toInt() ?? 1,
      stepsDay: j['stepsDay'] as String?,
      stepsCounted: (j['stepsCounted'] as num?)?.toInt() ?? 0,
      seenSpecies: strings(j['seenSpecies']),
    );
  }
}
