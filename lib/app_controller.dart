import 'package:flutter/foundation.dart';

import 'core/models/daily_record.dart';
import 'core/models/player_state.dart';
import 'core/rules/rules.dart';
import 'data/health/health_source.dart';
import 'data/storage/record_store.dart';
import 'features/status/demo_data.dart';

/// 저장소 · 건강 앱 · 화면을 잇는 앱의 중심.
///
/// 앱을 열 때마다 [sync] 로 오늘(과 어제 마감) 걸음·수면을 건강 앱에서 읽어
/// 하루 기록에 반영하고 저장한다. 게임 안에서 생긴 기록(던전, 공부 등)은 그대로 둔다.
class AppController extends ChangeNotifier {
  AppController({
    required this.store,
    required this.health,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// 건강 앱 없이 2주치 예시 기록으로 화면을 보는 모드
  factory AppController.demo({DateTime Function()? clock}) {
    final now = (clock ?? DateTime.now)();
    return AppController(
      store: InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루', stepGoal: 8000),
        history: DemoData.twoWeeks(today: now),
      ),
      health: FakeHealthSource(granted: false),
      clock: clock,
    );
  }

  final RecordStore store;
  final HealthSource health;
  final DateTime Function() _clock;

  PlayerProfile _profile = const PlayerProfile(name: '각성자');
  List<DailyRecord> _history = [];
  bool _ready = false;
  bool _healthGranted = false;

  bool get ready => _ready;
  bool get healthGranted => _healthGranted;
  PlayerProfile get profile => _profile;
  List<DailyRecord> get history => List.unmodifiable(_history);

  PlayerState get player =>
      PlayerState.fromHistory(name: _profile.name, history: _history);

  Future<void> init() async {
    _profile = await store.loadProfile() ?? _profile;
    _healthGranted = await health.requestPermission();
    await sync();
    _ready = true;
    notifyListeners();
  }

  Future<void> sync() async {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    _history = await store.loadHistory();

    // 어제 기록이 있으면 하루 전체 걸음으로 마감한다 (밤에 앱을 안 열었을 때 대비)
    final y = _find(yesterday);
    if (_healthGranted && y != null) {
      final closed = await _withHealth(y, yesterday, today);
      await store.upsert(_withQuests(closed));
    }

    var todayRecord =
        _find(today) ?? DailyRecord(date: today, stepGoal: _profile.stepGoal);
    if (_healthGranted) {
      todayRecord = await _withHealth(todayRecord, today, now);
    }
    await store.upsert(_withQuests(todayRecord.copyWith(openedApp: true)));

    _history = await store.loadHistory();
    notifyListeners();
  }

  /// '공부 기록' 버튼
  Future<void> logStudy(int minutes) async {
    final today = _history.isEmpty ? null : _history.last;
    if (today == null || minutes <= 0) return;
    final updated = today.copyWith(studyMinutes: today.studyMinutes + minutes);
    await store.upsert(_withQuests(updated));
    _history = await store.loadHistory();
    notifyListeners();
  }

  Future<void> updateProfile(PlayerProfile profile) async {
    _profile = profile;
    await store.saveProfile(profile);
    notifyListeners();
  }

  DailyRecord? _find(DateTime day) {
    final key = DailyRecord.dayKeyOf(day);
    for (final r in _history) {
      if (r.dayKey == key) return r;
    }
    return null;
  }

  DailyRecord _withQuests(DailyRecord r) =>
      r.copyWith(questsCompleted: QuestRules.completedCount(r));

  Future<DailyRecord> _withHealth(
    DailyRecord record,
    DateTime dayStart,
    DateTime end,
  ) async {
    final steps = await health.stepsBetween(dayStart, end);
    final eightPm =
        DateTime(dayStart.year, dayStart.month, dayStart.day, 20);
    final after8 =
        end.isAfter(eightPm) ? await health.stepsBetween(eightPm, end) : 0;
    final sleep = await health.sleepMinutesForNightBefore(dayStart);
    return record.copyWith(
      steps: steps,
      stepsAfter8pm: after8,
      sleepMinutes: sleep,
    );
  }
}
