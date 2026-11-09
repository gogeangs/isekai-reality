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
    this.weatherEnabled = true,
    this.equippedTitle,
  });

  final String name;
  final HeroLook look;
  final int stepGoal;

  /// 정령 동료 이름 (플레이어가 바꿀 수 있음)
  final String spiritName;

  /// 정령 종류 (예전 저장본은 불의 정령)
  final SpiritKind spiritKind;

  /// 플레이어가 마지막으로 확인한 레벨. 이보다 오르면 레벨업 연출을 보여 준다.
  final int? lastSeenLevel;

  /// 대략 위치로 날씨를 조회해 불씨 색을 바꿀지 (선택 동의)
  final bool weatherEnabled;

  /// 플레이어가 고른 대표 칭호 ([TitleId] 이름). 없으면 자동.
  final String? equippedTitle;

  PlayerProfile copyWith({
    String? name,
    HeroLook? look,
    int? stepGoal,
    String? spiritName,
    SpiritKind? spiritKind,
    int? lastSeenLevel,
    bool? weatherEnabled,
    String? equippedTitle,
  }) =>
      PlayerProfile(
        name: name ?? this.name,
        look: look ?? this.look,
        stepGoal: stepGoal ?? this.stepGoal,
        spiritName: spiritName ?? this.spiritName,
        spiritKind: spiritKind ?? this.spiritKind,
        lastSeenLevel: lastSeenLevel ?? this.lastSeenLevel,
        weatherEnabled: weatherEnabled ?? this.weatherEnabled,
        equippedTitle: equippedTitle ?? this.equippedTitle,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'look': look.name,
        'stepGoal': stepGoal,
        'spiritName': spiritName,
        'spiritKind': spiritKind.name,
        'lastSeenLevel': lastSeenLevel,
        'weatherEnabled': weatherEnabled,
        'equippedTitle': equippedTitle,
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
        weatherEnabled: json['weatherEnabled'] as bool? ?? true,
        equippedTitle: json['equippedTitle'] as String?,
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

  /// 모든 기록·프로필·탐험 기록을 지운다 (데이터 동의 철회)
  Future<void> clearAll();
}

/// 테스트·예시용 메모리 저장소
class InMemoryRecordStore implements RecordStore {
  InMemoryRecordStore({PlayerProfile? profile, List<DailyRecord>? history})
      : _profile = profile,
        _records = {for (final r in history ?? <DailyRecord>[]) r.dayKey: r};

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

  @override
  Future<void> clearAll() async {
    _profile = null;
    _records.clear();
    _cells.clear();
    _vitals = const Vitals();
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
    return Vitals.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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
    return PlayerProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    await (await _prefs).setString(_profileKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<List<DailyRecord>> loadHistory() async {
    final raw = (await _prefs).getString(_historyKey);
    if (raw == null) return [];
    final list = (jsonDecode(raw) as List)
        .map((e) => DailyRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
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
  Future<void> clearAll() async {
    final prefs = await _prefs;
    for (final key in prefs.getKeys().toList()) {
      if (key == _profileKey ||
          key == _historyKey ||
          key == _vitalsKey ||
          key.startsWith('cells.')) {
        await prefs.remove(key);
      }
    }
  }
}
