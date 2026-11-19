// 묶음 44 #225: 마을 공사 중 건물 시험용 계정 (레벨로 기능이 열리는 새 계정)

import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

final vt0 = DateTime(2026, 11, 16, 10);

Future<AppController> startVillage(int level,
    {Map<String, dynamic>? village,
    bool farewell = false,
    Map<String, dynamic>? more,
    Map<String, int> gains = const {},
    DateTime Function()? clock}) async {
  final c = AppController(
    store: InMemoryRecordStore(
      profile: const PlayerProfile(
          name: '하루',
          spiritName: '불씨',
          spiritKind: SpiritKind.water,
          lastSeenLevel: 99),
      history: [
        DailyRecord(
          date: DateTime(2026, 11, 15),
          gains: {'exp': LevelRules.totalExpToReach(level), ...gains},
        ),
      ],
      json: {
        'tutorial': {'step': TutorialStep.done.index},
        'gates': {
          'legacy': false,
          'v28': true,
          'seen': [for (final f in Feature.values) f.name],
        },
        if (farewell)
          'pets': PetState(
            pets: [
              Pet(
                  uid: 'p1',
                  species: PetSpecies.owl,
                  name: '부엉',
                  bornAt: DateTime(2026, 11, 1)),
            ],
            companion: 'p1',
            firstPet: 'p1',
            firstSpiritName: '불씨',
            farewellAt: DateTime(2026, 11, 2),
          ).toJson(),
        if (village != null) 'village': village,
        ...?more,
      },
    ),
    health: FakeHealthSource(stepsByDay: const {}),
    clock: clock ?? () => vt0,
  )..mailSources = const [];
  await c.init();
  return c;
}
