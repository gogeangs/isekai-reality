// 묶음 42 #226: 마을 사람 부탁 시험용 기록 (레벨 · 재료 · 만난 마을 사람 · 친해지기 점수)

import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

import 'smithy_seed.dart';

/// [npc]: 'npc' 저장 칸 (없으면 예전 기록처럼 시작 점수를 어림잡음)
Future<AppController> startNpc({
  int level = 1,
  int gold = 1000,
  int stones = 30,
  Map<String, int> mats = const {
    'ratHide': 4,
    'glossyFur': 1,
    'slimeJelly': 2,
    'springPetal': 2,
    'shadeMushroom': 1,
    'essence': 1,
  },
  Map<String, dynamic>? npc,
  List<DailyRecord> more = const [],
  Map<String, int> todaySteps = const {},
  DateTime Function()? clock,
}) async {
  final c = AppController(
    store: InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
      history: [
        DailyRecord(date: DateTime(2026, 11, 15), gains: {
          Wallet.gold: gold,
          Wallet.manaStone: stones,
          Wallet.exp: LevelRules.totalExpToReach(level),
          ...mats,
        }),
        ...more,
      ],
      json: {
        'armory': seededArmory(),
        'harvest': {'granted': true},
        'village': {
          'seen': [
            'intro',
            for (final n in Npc.values) 'met:${n.name}',
          ],
        },
        if (npc != null) 'npc': npc,
      },
    ),
    health: FakeHealthSource(stepsByDay: todaySteps),
    clock: clock ?? () => t0,
  )..mailSources = const [];
  await c.init();
  return c;
}
