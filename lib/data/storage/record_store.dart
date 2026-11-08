import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/daily_record.dart';
import '../../core/rules/rule_constants.dart';

enum HeroLook { male, female }

/// 각성할 때 정한 정보와 설정
class PlayerProfile {
  const PlayerProfile({
    required this.name,
    this.look = HeroLook.male,
    this.stepGoal = RuleConstants.defaultStepGoal,
    this.spiritName = '불씨',
    this.lastSeenLevel,
  });

  final String name;
  final HeroLook look;
  final int stepGoal;

  /// 정령 동료 이름 (플레이어가 바꿀 수 있음)
  final String spiritName;

  /// 플레이어가 마지막으로 확인한 레벨. 이보다 오르면 레벨업 연출을 보여 준다.
  final int? lastSeenLevel;

  PlayerProfile copyWith({
    String? name,
    HeroLook? look,
    int? stepGoal,
    String? spiritName,
    int? lastSeenLevel,
  }) =>
      PlayerProfile(
        name: name ?? this.name,
        look: look ?? this.look,
        stepGoal: stepGoal ?? this.stepGoal,
        spiritName: spiritName ?? this.spiritName,
        lastSeenLevel: lastSeenLevel ?? this.lastSeenLevel,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'look': look.name,
        'stepGoal': stepGoal,
        'spiritName': spiritName,
        'lastSeenLevel': lastSeenLevel,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        name: json['name'] as String? ?? '각성자',
        look: (json['look'] as String?) == 'female'
            ? HeroLook.female
            : HeroLook.male,
        stepGoal: json['stepGoal'] as int? ?? RuleConstants.defaultStepGoal,
        spiritName: json['spiritName'] as String? ?? '불씨',
        lastSeenLevel: json['lastSeenLevel'] as int?,
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
}

/// shared_preferences 에 JSON 으로 저장한다 (페이즈 1 규모에 충분).
class SharedPrefsRecordStore implements RecordStore {
  static const _profileKey = 'profile.v1';
  static const _historyKey = 'history.v1';

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
}
