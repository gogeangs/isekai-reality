import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/daily_record.dart';
import '../../core/models/vitals.dart';
import '../../core/rules/rule_constants.dart';

enum HeroLook { male, female }

/// 함께하는 정령의 종류 (각성할 때 고르고 바꿀 수 없다. 이름은 바꿀 수 있다)
enum SpiritKind { fire, water, plant }

extension SpiritKindInfo on SpiritKind {
  /// 이름 칸에 미리 넣어 두는 이름
  String get defaultName => switch (this) {
        SpiritKind.fire => '불씨',
        SpiritKind.water => '이슬',
        SpiritKind.plant => '잎새',
      };

  String get elementName => switch (this) {
        SpiritKind.fire => '불의 정령',
        SpiritKind.water => '물의 정령',
        SpiritKind.plant => '식물의 정령',
      };

  static SpiritKind parse(String? name) => switch (name) {
        'water' => SpiritKind.water,
        'plant' => SpiritKind.plant,
        _ => SpiritKind.fire,
      };
}

/// 각성할 때 정한 정보와 설정
class PlayerProfile {
  const PlayerProfile({
    required this.name,
    this.look = HeroLook.male,
    this.stepGoal = RuleConstants.defaultStepGoal,
    this.spiritName = '불씨',
    this.spiritKind = SpiritKind.fire,
    this.lastSeenLevel,
    this.equippedTitle,
    this.renames = 0,
    this.avatar = 'hero',
    this.avatarHinted = false,
  });

  /// 묶음 75 #335: 프로필 사진 ('hero' · 'pet:<uid>' · 'npc:marta' · 'ally:lian' · 'title:<id>')
  final String avatar;

  /// 「프로필 사진을 바꿀 수 있어!」 를 말했는지
  final bool avatarHinted;

  final String name;
  final HeroLook look;
  final int stepGoal;

  /// 정령 동료 이름 (플레이어가 바꿀 수 있음)
  final String spiritName;

  /// 정령 종류 (예전 저장본은 불의 정령)
  final SpiritKind spiritKind;

  /// 플레이어가 마지막으로 확인한 레벨. 이보다 오르면 레벨업 연출을 보여 준다.
  final int? lastSeenLevel;


  /// 플레이어가 고른 대표 칭호 ([TitleId] 이름). 없으면 자동.
  final String? equippedTitle;

  /// 내 이름을 바꾼 횟수 (11-11 #53: 처음 1번 무료, 그다음 금화)
  final int renames;

  PlayerProfile copyWith({
    String? name,
    HeroLook? look,
    int? stepGoal,
    String? spiritName,
    SpiritKind? spiritKind,
    int? lastSeenLevel,
    String? equippedTitle,
    int? renames,
    String? avatar,
    bool? avatarHinted,
  }) =>
      PlayerProfile(
        name: name ?? this.name,
        look: look ?? this.look,
        stepGoal: stepGoal ?? this.stepGoal,
        spiritName: spiritName ?? this.spiritName,
        spiritKind: spiritKind ?? this.spiritKind,
        lastSeenLevel: lastSeenLevel ?? this.lastSeenLevel,
        equippedTitle: equippedTitle ?? this.equippedTitle,
        renames: renames ?? this.renames,
        avatar: avatar ?? this.avatar,
        avatarHinted: avatarHinted ?? this.avatarHinted,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'look': look.name,
        'stepGoal': stepGoal,
        'spiritName': spiritName,
        'spiritKind': spiritKind.name,
        'lastSeenLevel': lastSeenLevel,
        'equippedTitle': equippedTitle,
        'renames': renames,
        'avatar': avatar,
        if (avatarHinted) 'avatarHinted': true,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        name: json['name'] as String? ?? '각성자',
        look: (json['look'] as String?) == 'female'
            ? HeroLook.female
            : HeroLook.male,
        stepGoal: json['stepGoal'] as int? ?? RuleConstants.defaultStepGoal,
        spiritName: json['spiritName'] as String? ?? '불씨',
        spiritKind: SpiritKindInfo.parse(json['spiritKind'] as String?),
        lastSeenLevel: json['lastSeenLevel'] as int?,
        equippedTitle: json['equippedTitle'] as String?,
        renames: json['renames'] as int? ?? 0,
        avatar: json['avatar'] as String? ?? 'hero',
        avatarHinted: json['avatarHinted'] as bool? ?? false,
      );
}

/// 하루 기록과 프로필을 기기에 저장한다. 건강 데이터는 기기 밖으로 나가지 않는다.
abstract class RecordStore {
  Future<PlayerProfile?> loadProfile();
  Future<void> saveProfile(PlayerProfile profile);

  /// 날짜순으로 정렬된 전체 기록
  Future<List<DailyRecord>> loadHistory();

  /// 같은 날짜의 기록이 있으면 바꾸고, 없으면 추가한다
  Future<void> upsert(DailyRecord record);

  /// 지역별로 안개를 걷어 낸 칸 id
  Future<Set<String>> loadRevealedCells(String areaId);
  Future<void> saveRevealedCells(String areaId, Set<String> cells);

  /// HP · 정령 MP · 휴식 · 원정 (없으면 처음 상태)
  Future<Vitals> loadVitals();
  Future<void> saveVitals(Vitals vitals);

  /// 그 밖의 게임 상태 (의뢰 게시판, 장비 등). 없으면 null.
  Future<Map<String, dynamic>?> loadJson(String key);
  Future<void> saveJson(String key, Map<String, dynamic> value);

  /// 모든 기록·프로필·탐험 기록을 지운다 (데이터 동의 철회)
  Future<void> clearAll();

  /// 묶음 55 #245: 기록 전체 (백업용). 값은 문자열 또는 문자열 목록.
  /// 로그인 · 서버 시간 같은 이 휴대폰만의 값([loadSide])은 들어가지 않는다
  Future<Map<String, Object>> exportAll();

  /// 기록 전체를 [data] 로 바꾼다 (복원). 이 휴대폰만의 값은 그대로
  Future<void> importAll(Map<String, Object> data);

  /// 이 휴대폰만의 값 (로그인 상태 · 서버 시간 차이). 백업 · 「모두 지우기」에 안 들어감
  Future<String?> loadSide(String key);
  Future<void> saveSide(String key, String? value);
}

/// 백업 스냅숏 키 (SharedPreferences 와 같은 이름을 쓴다)
class SnapshotKeys {
  SnapshotKeys._();
  static const profile = 'profile.v1';
  static const history = 'history.v1';
  static const vitals = 'vitals.v1';
  static const cells = 'cells.';
  static const json = 'json.';

  static bool isRecord(String key) =>
      key == profile ||
      key == history ||
      key == vitals ||
      key.startsWith(cells) ||
      key.startsWith(json);
}

/// 테스트·예시용 메모리 저장소
class InMemoryRecordStore implements RecordStore {
  InMemoryRecordStore(
      {PlayerProfile? profile,
      List<DailyRecord>? history,
      Map<String, Map<String, dynamic>>? json})
      : _profile = profile,
        _records = {for (final r in history ?? <DailyRecord>[]) r.dayKey: r},
        _json = {...?json};

  PlayerProfile? _profile;
  final Map<String, DailyRecord> _records;

  @override
  Future<PlayerProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(PlayerProfile profile) async => _profile = profile;

  @override
  Future<List<DailyRecord>> loadHistory() async =>
      (_records.values.toList()..sort((a, b) => a.date.compareTo(b.date)));

  @override
  Future<void> upsert(DailyRecord record) async =>
      _records[record.dayKey] = record;

  final Map<String, Set<String>> _cells = {};

  @override
  Future<Set<String>> loadRevealedCells(String areaId) async =>
      {...?_cells[areaId]};

  @override
  Future<void> saveRevealedCells(String areaId, Set<String> cells) async =>
      _cells[areaId] = {...cells};

  Vitals _vitals = const Vitals();

  @override
  Future<Vitals> loadVitals() async => _vitals;

  @override
  Future<void> saveVitals(Vitals vitals) async => _vitals = vitals;

  final Map<String, Map<String, dynamic>> _json;

  @override
  Future<Map<String, dynamic>?> loadJson(String key) async => _json[key];

  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async =>
      _json[key] = value;

  @override
  Future<void> clearAll() async {
    _profile = null;
    _records.clear();
    _cells.clear();
    _json.clear();
    _vitals = const Vitals();
  }

  final Map<String, String> _side = {};

  @override
  Future<String?> loadSide(String key) async => _side[key];

  @override
  Future<void> saveSide(String key, String? value) async {
    if (value == null) {
      _side.remove(key);
    } else {
      _side[key] = value;
    }
  }

  @override
  Future<Map<String, Object>> exportAll() async => {
        if (_profile != null) SnapshotKeys.profile: jsonEncode(_profile!.toJson()),
        SnapshotKeys.history:
            jsonEncode([for (final r in await loadHistory()) r.toJson()]),
        SnapshotKeys.vitals: jsonEncode(_vitals.toJson()),
        for (final e in _cells.entries)
          '${SnapshotKeys.cells}${e.key}.v1': e.value.toList(),
        for (final e in _json.entries) '${SnapshotKeys.json}${e.key}': jsonEncode(e.value),
      };

  @override
  Future<void> importAll(Map<String, Object> data) async {
    await clearAll();
    for (final e in data.entries) {
      final k = e.key, v = e.value;
      if (k == SnapshotKeys.profile && v is String) {
        _profile = PlayerProfile.fromJson(Map<String, dynamic>.from(jsonDecode(v) as Map));
      } else if (k == SnapshotKeys.history && v is String) {
        for (final r in jsonDecode(v) as List) {
          final d = DailyRecord.fromJson(Map<String, dynamic>.from(r as Map));
          _records[d.dayKey] = d;
        }
      } else if (k == SnapshotKeys.vitals && v is String) {
        _vitals = Vitals.fromJson(Map<String, dynamic>.from(jsonDecode(v) as Map));
      } else if (k.startsWith(SnapshotKeys.cells) && v is List) {
        final area = k.substring(SnapshotKeys.cells.length).replaceAll(RegExp(r'\.v1$'), '');
        _cells[area] = {for (final c in v) '$c'};
      } else if (k.startsWith(SnapshotKeys.json) && v is String) {
        _json[k.substring(SnapshotKeys.json.length)] =
            Map<String, dynamic>.from(jsonDecode(v) as Map);
      }
    }
  }
}

/// shared_preferences 에 JSON 으로 저장한다 (페이즈 1 규모에 충분).
class SharedPrefsRecordStore implements RecordStore {
  static const _profileKey = 'profile.v1';
  static const _historyKey = 'history.v1';
  static const _vitalsKey = 'vitals.v1';

  @override
  Future<Vitals> loadVitals() async {
    final raw = (await _prefs).getString(_vitalsKey);
    if (raw == null) return const Vitals();
    try {
      return Vitals.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      // 묶음 16 #124: 못 읽으면 원본은 따로 남기고 처음 상태로 (앱은 켜진다)
      await _keepBroken(_vitalsKey, raw);
      return const Vitals();
    }
  }

  /// 읽지 못한 원본을 지우지 않고 따로 둔다 (같은 키에 쌓지 않고 마지막 것만)
  Future<void> _keepBroken(String key, String raw) async {
    try {
      await (await _prefs).setString('$key.broken', raw);
    } catch (_) {}
  }

  @override
  Future<void> saveVitals(Vitals vitals) async {
    await (await _prefs).setString(_vitalsKey, jsonEncode(vitals.toJson()));
  }

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<PlayerProfile?> loadProfile() async {
    final raw = (await _prefs).getString(_profileKey);
    if (raw == null) return null;
    try {
      return PlayerProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } catch (_) {
      // 프로필은 처음부터 다시 만들지 않는다: 원본을 남기고 「다시 시도」 화면으로
      await _keepBroken(_profileKey, raw);
      rethrow;
    }
  }

  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    await (await _prefs).setString(_profileKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<List<DailyRecord>> loadHistory() async {
    final raw = (await _prefs).getString(_historyKey);
    if (raw == null) return [];
    List<dynamic> items;
    try {
      items = jsonDecode(raw) as List;
    } catch (_) {
      await _keepBroken(_historyKey, raw);
      return [];
    }
    // 하루치 기록 하나가 틀려도 나머지 날은 지킨다. 틀린 것은 따로 남긴다
    final list = <DailyRecord>[];
    final broken = <dynamic>[];
    for (final e in items) {
      try {
        list.add(DailyRecord.fromJson(Map<String, dynamic>.from(e as Map)));
      } catch (_) {
        broken.add(e);
      }
    }
    if (broken.isNotEmpty) {
      final prefs = await _prefs;
      final old = prefs.getString('$_historyKey.broken');
      var kept = <dynamic>[];
      try {
        if (old != null) kept = jsonDecode(old) as List;
      } catch (_) {}
      try {
        await prefs.setString(
            '$_historyKey.broken', jsonEncode([...kept, ...broken]));
      } catch (_) {}
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  @override
  Future<void> upsert(DailyRecord record) async {
    final history = await loadHistory();
    final index = history.indexWhere((r) => r.dayKey == record.dayKey);
    if (index >= 0) {
      history[index] = record;
    } else {
      history
        ..add(record)
        ..sort((a, b) => a.date.compareTo(b.date));
    }
    await (await _prefs).setString(
      _historyKey,
      jsonEncode(history.map((r) => r.toJson()).toList()),
    );
  }

  String _cellsKey(String areaId) => 'cells.$areaId.v1';

  @override
  Future<Set<String>> loadRevealedCells(String areaId) async =>
      ((await _prefs).getStringList(_cellsKey(areaId)) ?? const <String>[])
          .toSet();

  @override
  Future<void> saveRevealedCells(String areaId, Set<String> cells) async {
    await (await _prefs).setStringList(_cellsKey(areaId), cells.toList());
  }

  @override
  Future<Map<String, dynamic>?> loadJson(String key) async {
    final raw = (await _prefs).getString('json.$key');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      await _keepBroken('json.$key', raw);
      rethrow;
    }
  }

  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    await (await _prefs).setString('json.$key', jsonEncode(value));
  }

  @override
  Future<void> clearAll() async {
    final prefs = await _prefs;
    for (final key in prefs.getKeys().toList()) {
      if (SnapshotKeys.isRecord(key)) {
        await prefs.remove(key);
      }
    }
  }

  @override
  Future<String?> loadSide(String key) async => (await _prefs).getString('side.$key');

  @override
  Future<void> saveSide(String key, String? value) async {
    final prefs = await _prefs;
    if (value == null) {
      await prefs.remove('side.$key');
    } else {
      await prefs.setString('side.$key', value);
    }
  }

  @override
  Future<Map<String, Object>> exportAll() async {
    final prefs = await _prefs;
    await prefs.reload();
    final out = <String, Object>{};
    for (final key in prefs.getKeys()) {
      if (!SnapshotKeys.isRecord(key)) continue;
      final v = prefs.get(key);
      if (v is String) {
        out[key] = v;
      } else if (v is List) {
        out[key] = [for (final x in v) '$x'];
      }
    }
    return out;
  }

  @override
  Future<void> importAll(Map<String, Object> data) async {
    final prefs = await _prefs;
    await clearAll();
    for (final e in data.entries) {
      if (!SnapshotKeys.isRecord(e.key)) continue;
      final v = e.value;
      if (v is String) {
        await prefs.setString(e.key, v);
      } else if (v is List) {
        await prefs.setStringList(e.key, [for (final x in v) '$x']);
      }
    }
  }
}

/// 묶음 55 #245: 서버 기록으로 바꾼 뒤 예전 컨트롤러가 더는 쓰지 못하게 막는 저장소
class RetirableStore implements RecordStore {
  RetirableStore(this.inner);

  final RecordStore inner;

  /// true 면 쓰기를 모두 무시한다 (읽기는 그대로)
  bool retired = false;

  @override
  Future<PlayerProfile?> loadProfile() => inner.loadProfile();
  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    if (!retired) await inner.saveProfile(profile);
  }

  @override
  Future<List<DailyRecord>> loadHistory() => inner.loadHistory();
  @override
  Future<void> upsert(DailyRecord record) async {
    if (!retired) await inner.upsert(record);
  }

  @override
  Future<Set<String>> loadRevealedCells(String areaId) => inner.loadRevealedCells(areaId);
  @override
  Future<void> saveRevealedCells(String areaId, Set<String> cells) async {
    if (!retired) await inner.saveRevealedCells(areaId, cells);
  }

  @override
  Future<Vitals> loadVitals() => inner.loadVitals();
  @override
  Future<void> saveVitals(Vitals vitals) async {
    if (!retired) await inner.saveVitals(vitals);
  }

  @override
  Future<Map<String, dynamic>?> loadJson(String key) => inner.loadJson(key);
  @override
  Future<void> saveJson(String key, Map<String, dynamic> value) async {
    if (!retired) await inner.saveJson(key, value);
  }

  @override
  Future<void> clearAll() async {
    if (!retired) await inner.clearAll();
  }

  @override
  Future<Map<String, Object>> exportAll() => inner.exportAll();
  @override
  Future<void> importAll(Map<String, Object> data) async {
    if (!retired) await inner.importAll(data);
  }

  @override
  Future<String?> loadSide(String key) => inner.loadSide(key);
  @override
  Future<void> saveSide(String key, String? value) async {
    if (!retired) await inner.saveSide(key, value);
  }
}
