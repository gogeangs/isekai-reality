// 묶음 40: 대장간 시험용 기록 (입은 장비·닳은 장비·속성·재료)

import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/armory.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';

final t0 = DateTime(2026, 11, 16, 10);

/// 입은 단검(불 속성·닳음) · 모자 · 갑옷(닳음) + 가방 장화(많이 닳음) · 장갑
Map<String, dynamic> seededArmory() => const Armory(
      items: [
        EquipItem(
            uid: 'w',
            base: EquipBase.dagger,
            grade: EquipGrade.green,
            enhance: 2,
            durability: 40,
            element: Element.fire,
            elementLevel: 1),
        EquipItem(uid: 'h', base: EquipBase.cap, grade: EquipGrade.white),
        EquipItem(
            uid: 'b',
            base: EquipBase.armor,
            grade: EquipGrade.white,
            durability: 70),
        EquipItem(
            uid: 'f',
            base: EquipBase.boots,
            grade: EquipGrade.blue,
            durability: 20),
        EquipItem(uid: 'g', base: EquipBase.gloves, grade: EquipGrade.white),
      ],
      equipped: {
        EquipSlot.weapon: 'w',
        EquipSlot.head: 'h',
        EquipSlot.body: 'b',
      },
      crafts: 5,
      nextId: 10,
    ).toJson();

Future<AppController> startSmithy(
    {int gold = 5000,
    int stones = 1,
    Map<String, int> mats = const {
      'ratHide': 4,
      'ironShard': 3,
      'twig': 2,
      'slimeJelly': 1,
      'glossyFur': 2,
      'glowWaterCore': 1,
    }}) async {
  final c = AppController(
    store: InMemoryRecordStore(
      profile: const PlayerProfile(name: '하루', lastSeenLevel: 99),
      history: [
        DailyRecord(
            date: DateTime(2026, 11, 15),
            gains: {Wallet.gold: gold, Wallet.manaStone: stones, ...mats}),
      ],
      json: {
        'armory': seededArmory(),
        'harvest': {'granted': true},
      },
    ),
    health: FakeHealthSource(stepsByDay: const {}),
    clock: () => t0,
  )..mailSources = const [];
  await c.init();
  return c;
}

