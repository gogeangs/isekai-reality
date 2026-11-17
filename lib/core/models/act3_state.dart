import 'armory.dart';

/// 3막 동료 하나 (묶음 52 #243). 이야기 동료는 [story] 이름, 이름 없는 동료는 종족·직업·능력치
class AllyData {
  const AllyData({
    required this.id,
    this.story,
    this.race,
    this.job,
    this.name = '',
    this.stats = const [12, 12, 12, 12],
    this.traits = const [],
    this.level = 1,
    this.exp = 0,
    this.joinLevel = 1,
    this.gear = const [],
    this.skills = const [0],
    this.slot = 0,
  });

  /// 'lian' · 'garen' · 'a3' (이름 없는 동료)
  final String id;

  /// 이야기 동료 이름 (StoryAlly), 이름 없는 동료면 null
  final String? story;

  /// 이름 없는 동료의 종족 · 직업 (AllyRace · AllyJob 이름)
  final String? race;
  final String? job;
  final String name;

  /// 힘 · 체력 · 민첩 · 지능
  final List<int> stats;

  /// 특성 id
  final List<String> traits;

  /// 동료 레벨 (내 레벨을 넘지 못함) · 경험치 · 합류할 때 레벨 (스킬 포인트 셈)
  final int level;
  final int exp;
  final int joinLevel;

  /// 입은 장비 (가방에서 옮겨 옴, 동료가 입은 건 나는 못 입음)
  final List<EquipItem> gear;

  /// 연 스킬 칸 (0~3) · 전투 버튼에 끼운 칸
  final List<int> skills;
  final int slot;

  bool get isStory => story != null;

  AllyData copyWith({
    String? name,
    int? level,
    int? exp,
    List<EquipItem>? gear,
    List<int>? skills,
    int? slot,
  }) =>
      AllyData(
        id: id,
        story: story,
        race: race,
        job: job,
        name: name ?? this.name,
        stats: stats,
        traits: traits,
        level: level ?? this.level,
        exp: exp ?? this.exp,
        joinLevel: joinLevel,
        gear: gear ?? this.gear,
        skills: skills ?? this.skills,
        slot: slot ?? this.slot,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (story != null) 'story': story,
        if (race != null) 'race': race,
        if (job != null) 'job': job,
        if (name.isNotEmpty) 'name': name,
        'stats': stats,
        if (traits.isNotEmpty) 'traits': traits,
        'level': level,
        if (exp > 0) 'exp': exp,
        'join': joinLevel,
        if (gear.isNotEmpty) 'gear': [for (final g in gear) g.toJson()],
        'skills': skills,
        if (slot != 0) 'slot': slot,
      };

  static AllyData? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String) return null;
    final st = [for (final x in (raw['stats'] as List?) ?? const []) if (x is num) x.toInt()];
    return AllyData(
      id: raw['id'] as String,
      story: raw['story'] as String?,
      race: raw['race'] as String?,
      job: raw['job'] as String?,
      name: (raw['name'] as String?) ?? '',
      stats: st.length == 4 ? st : const [12, 12, 12, 12],
      traits: [for (final t in (raw['traits'] as List?) ?? const []) '$t'],
      level: ((raw['level'] as num?) ?? 1).toInt(),
      exp: ((raw['exp'] as num?) ?? 0).toInt(),
      joinLevel: ((raw['join'] as num?) ?? 1).toInt(),
      gear: [
        for (final g in (raw['gear'] as List?) ?? const [])
          if (g is Map)
            if (EquipItem.fromJson(Map<String, dynamic>.from(g)) case final it?) it,
      ],
      skills: [
        for (final x in (raw['skills'] as List?) ?? const [0])
          if (x is num && x >= 0 && x < 4) x.toInt(),
      ],
      slot: ((raw['slot'] as num?) ?? 0).toInt().clamp(0, 3),
    );
  }
}

/// 3막 기록 (묶음 52 #243). 따로 저장한다 ('act3'). 예전 기록엔 없으니 없으면 처음부터 (#124)
class Act3State {
  const Act3State({
    this.opened = false,
    this.sceneSeen = false,
    this.walkDay,
    this.walkSteps = 0,
    this.roadSteps = 0,
    this.energy = Act3Defaults.energy,
    this.energyRem = 0,
    this.tickets = 0,
    this.ticketDay,
    this.ticketSteps = 0,
    this.ticketGot = 0,
    this.adDay,
    this.allies = const [],
    this.party = const [],
    this.nextId = 1,
    this.region = 0,
    this.firstFight = false,
    this.wins = 0,
    this.flags = const {},
    this.quests = const {},
    this.prog = const {},
    this.floorBest = 0,
    this.floorNow = 1,
    this.choice,
    this.lunch = 0,
    this.innDay,
    this.found = const {},
  });

  /// 묶음 53 지역 1: 이야기 표시 ('volk' ② · 'letter' ③ · 'lamp' ⑤ · 'fur' 은빛 털 · 'den' 굴 열림 ·
  /// 'denBoss' 숨은 보스 · 'dungeon' 던전 처음 끝냄 · 'dew' 빛 이슬 · 'met:volk' 주민 만남 · 'stall' 노점 커짐 · 'spear' 지역 무기)
  final Set<String> flags;

  /// 서브 퀘스트: 1 받음 · 2 끝냄 (SideQuest 이름)
  final Map<String, int> quests;

  /// 서브 퀘스트 진행 수
  final Map<String, int> prog;

  /// 지하 요새: 끝낸 가장 깊은 층 · 다음에 들어갈 층
  final int floorBest;
  final int floorNow;

  /// 큰 고르기 「테오의 편지」: 'marta' · 'garen'
  final String? choice;

  /// 마르타의 도시락 개수
  final int lunch;

  /// 천막 여관에서 여정 기력을 받은 날
  final String? innDay;

  /// 한 번이라도 얻은 이름 있는 장비 (모음)
  final Set<String> found;

  bool has(String f) => flags.contains(f);

  final bool opened;

  /// 처음 다리를 건너는 장면을 봤는지
  final bool sceneSeen;

  /// 걸음을 센 날 · 그날 센 걸음 (3막이 열린 뒤 걸음만)
  final String? walkDay;
  final int walkSteps;

  /// 다음 지역 길에 쌓인 걸음 (기다리는 동안 걸은 걸음도 모아 둠)
  final int roadSteps;

  /// 여정 기력 · 1,000보가 덜 찬 걸음
  final int energy;
  final int energyRem;

  /// 모집권 · 걸음으로 받은 날 · 그날 센 걸음 · 그날 받은 장 수 · 광고로 받은 날
  final int tickets;
  final String? ticketDay;
  final int ticketSteps;
  final int ticketGot;
  final String? adDay;

  final List<AllyData> allies;

  /// 데려가는 동료 (2명까지, 동료 id)
  final List<String> party;
  final int nextId;

  /// 지금 지역 (Region 순서)
  final int region;

  /// 메인 ① 잿빛 들판 첫 싸움을 끝냈는지 · 이긴 판 수
  final bool firstFight;
  final int wins;

  AllyData? ally(String id) {
    for (final a in allies) {
      if (a.id == id) return a;
    }
    return null;
  }

  Act3State copyWith({
    bool? opened,
    bool? sceneSeen,
    String? walkDay,
    int? walkSteps,
    int? roadSteps,
    int? energy,
    int? energyRem,
    int? tickets,
    String? ticketDay,
    int? ticketSteps,
    int? ticketGot,
    String? adDay,
    List<AllyData>? allies,
    List<String>? party,
    int? nextId,
    int? region,
    bool? firstFight,
    int? wins,
    Set<String>? flags,
    Map<String, int>? quests,
    Map<String, int>? prog,
    int? floorBest,
    int? floorNow,
    String? choice,
    int? lunch,
    String? innDay,
    Set<String>? found,
  }) =>
      Act3State(
        opened: opened ?? this.opened,
        sceneSeen: sceneSeen ?? this.sceneSeen,
        walkDay: walkDay ?? this.walkDay,
        walkSteps: walkSteps ?? this.walkSteps,
        roadSteps: roadSteps ?? this.roadSteps,
        energy: energy ?? this.energy,
        energyRem: energyRem ?? this.energyRem,
        tickets: tickets ?? this.tickets,
        ticketDay: ticketDay ?? this.ticketDay,
        ticketSteps: ticketSteps ?? this.ticketSteps,
        ticketGot: ticketGot ?? this.ticketGot,
        adDay: adDay ?? this.adDay,
        allies: allies ?? this.allies,
        party: party ?? this.party,
        nextId: nextId ?? this.nextId,
        region: region ?? this.region,
        firstFight: firstFight ?? this.firstFight,
        wins: wins ?? this.wins,
        flags: flags ?? this.flags,
        quests: quests ?? this.quests,
        prog: prog ?? this.prog,
        floorBest: floorBest ?? this.floorBest,
        floorNow: floorNow ?? this.floorNow,
        choice: choice ?? this.choice,
        lunch: lunch ?? this.lunch,
        innDay: innDay ?? this.innDay,
        found: found ?? this.found,
      );

  Act3State flag(String f) => copyWith(flags: {...flags, f});

  Act3State replaceAlly(AllyData a) =>
      copyWith(allies: [for (final x in allies) x.id == a.id ? a : x]);

  Map<String, dynamic> toJson() => {
        'v': 1,
        if (opened) 'opened': true,
        if (sceneSeen) 'scene': true,
        if (walkDay != null) 'walkDay': walkDay,
        if (walkSteps > 0) 'walkSteps': walkSteps,
        if (roadSteps > 0) 'road': roadSteps,
        'energy': energy,
        if (energyRem > 0) 'energyRem': energyRem,
        if (tickets > 0) 'tickets': tickets,
        if (ticketDay != null) 'ticketDay': ticketDay,
        if (ticketSteps > 0) 'ticketSteps': ticketSteps,
        if (ticketGot > 0) 'ticketGot': ticketGot,
        if (adDay != null) 'adDay': adDay,
        'allies': [for (final a in allies) a.toJson()],
        'party': party,
        'nextId': nextId,
        if (region > 0) 'region': region,
        if (firstFight) 'firstFight': true,
        if (wins > 0) 'wins': wins,
        if (flags.isNotEmpty) 'flags': flags.toList(),
        if (quests.isNotEmpty) 'quests': quests,
        if (prog.isNotEmpty) 'prog': prog,
        if (floorBest > 0) 'floorBest': floorBest,
        if (floorNow != 1) 'floorNow': floorNow,
        if (choice != null) 'choice': choice,
        if (lunch > 0) 'lunch': lunch,
        if (innDay != null) 'innDay': innDay,
        if (found.isNotEmpty) 'found': found.toList(),
      };

  static Act3State fromJson(Map<String, dynamic> j) => Act3State(
        opened: j['opened'] == true,
        sceneSeen: j['scene'] == true,
        walkDay: j['walkDay'] as String?,
        walkSteps: ((j['walkSteps'] as num?) ?? 0).toInt(),
        roadSteps: ((j['road'] as num?) ?? 0).toInt(),
        energy: ((j['energy'] as num?) ?? Act3Defaults.energy).toInt(),
        energyRem: ((j['energyRem'] as num?) ?? 0).toInt(),
        tickets: ((j['tickets'] as num?) ?? 0).toInt(),
        ticketDay: j['ticketDay'] as String?,
        ticketSteps: ((j['ticketSteps'] as num?) ?? 0).toInt(),
        ticketGot: ((j['ticketGot'] as num?) ?? 0).toInt(),
        adDay: j['adDay'] as String?,
        allies: [
          for (final a in (j['allies'] as List?) ?? const [])
            if (AllyData.fromJson(a) case final x?) x,
        ],
        party: [for (final p in (j['party'] as List?) ?? const []) '$p'],
        nextId: ((j['nextId'] as num?) ?? 1).toInt(),
        region: ((j['region'] as num?) ?? 0).toInt(),
        firstFight: j['firstFight'] == true,
        wins: ((j['wins'] as num?) ?? 0).toInt(),
        flags: {for (final f in (j['flags'] as List?) ?? const []) '$f'},
        quests: _ints(j['quests']),
        prog: _ints(j['prog']),
        floorBest: ((j['floorBest'] as num?) ?? 0).toInt(),
        floorNow: ((j['floorNow'] as num?) ?? 1).toInt().clamp(1, 5),
        choice: j['choice'] as String?,
        lunch: ((j['lunch'] as num?) ?? 0).toInt(),
        innDay: j['innDay'] as String?,
        found: {for (final f in (j['found'] as List?) ?? const []) '$f'},
      );

  static Map<String, int> _ints(Object? raw) => {
        if (raw is Map)
          for (final e in raw.entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt(),
      };
}

/// 처음 값 (규칙 파일과 같은 수, 모델이 규칙을 가져오지 않게 따로 둠)
class Act3Defaults {
  Act3Defaults._();
  static const int energy = 100;
}
