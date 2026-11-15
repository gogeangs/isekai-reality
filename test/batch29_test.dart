import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/geo/geo.dart';
import 'package:isekai_reality/core/models/daily_record.dart';
import 'package:isekai_reality/core/models/pet_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/pets/farewell_screen.dart';

void main() {
  final t0 = DateTime(2026, 11, 15, 10);

  Future<AppController> start(InMemoryRecordStore store) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  InMemoryRecordStore account(int level,
          {PetState? pets, int hunts = 0, HeroLook look = HeroLook.male}) =>
      InMemoryRecordStore(
        profile: PlayerProfile(
            name: '하루',
            spiritName: '불씨',
            spiritKind: SpiritKind.water,
            look: look,
            lastSeenLevel: 99),
        history: [
          DailyRecord(
            date: DateTime(2026, 11, 1),
            huntCounts: {if (hunts > 0) 'slime': hunts},
          ),
          DailyRecord(
            date: DateTime(2026, 11, 14),
            gains: {'exp': LevelRules.totalExpToReach(level)},
          ),
        ],
        json: {
          'tutorial': {'step': TutorialStep.done.index},
          if (pets != null) 'pets': pets.toJson(),
        },
      );

  group('#183 기력', () {
    test('최대치 = 60 + 펫 보너스, 지능은 빠짐', () {
      final base = Stats.all(10);
      expect(StatRules.maxMp(base), 60);
      expect(StatRules.maxMp(base.withValue(StatKind.intellect, 40)), 60);
      expect(StatRules.intellectCraftBonus(base), 0);
      expect(StatRules.intellectCraftBonus(base.withValue(StatKind.intellect, 15)),
          greaterThan(0));
    });

    test('기존 계정: 기력은 그대로, 새 최대치를 넘으면 최대치까지만', () async {
      final store = account(5);
      await store.saveVitals(const Vitals(mp: 75));
      final c = await start(store);
      expect(c.mpMax, 60);
      expect(c.mp, 60);
      final low = account(5);
      await low.saveVitals(const Vitals(mp: 33));
      expect((await start(low)).mp, lessThanOrEqualTo(60));
    });

    test('원정에 쓰는 힘은 「기력」 (정령·펫·원정 MP 문구 없음)', () {
      final bad = <String>[];
      final quoted = RegExp(r"'[^'\n]*'");
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final line in f.readAsLinesSync()) {
          final t = line.trimLeft();
          if (t.startsWith('//')) continue;
          for (final m in quoted.allMatches(line)) {
            final s = m.group(0)!;
            // 묶음 30: 새 MP(직업 스킬)·마나 물약이 생겼다. 원정에 쓰는 힘은 계속 「기력」
            if (s.contains('정령 MP') || s.contains('펫 MP') || s.contains('원정 MP')) {
              bad.add('${f.path}: $s');
            }
          }
        }
      }
      expect(bad, isEmpty);
    });
  });

  group('#182 이별 컷신·첫 펫', () {
    test('컷신 대사·그림: 성별·정령에 맞춤, 6줄(장면 5개)', () {
      final m = FarewellScreen.linesFor(
          hero: '하루', spirit: '물방울', look: HeroLook.male, kind: SpiritKind.water);
      expect(m, hasLength(6));
      expect(m[0].image, 'assets/images/farewell_01_gate.webp');
      expect(m[0].line, '여기야. 내가 처음 떨어졌던 곳.');
      expect(m[2].speaker, '하루');
      expect(m[2].hero, isTrue);
      expect(m[2].line, '…같이 가면 안 돼?');
      expect(m[3].image, 'assets/images/farewell_03_smile_water.webp');
      expect(m[4].line, '고마웠어, 하루. 내 빛을 조금 남겨 둘게.');
      expect(m[5].speaker, isNull);
      final f = FarewellScreen.linesFor(
          hero: '하루', spirit: '새싹', look: HeroLook.female, kind: SpiritKind.plant);
      expect(f[0].image, 'assets/images/farewell_01_gate_female.webp');
      expect(f[1].image, 'assets/images/farewell_02_lookup_female.webp');
      expect(f[3].image, 'assets/images/farewell_03_smile_leaf.webp');
      expect(f[4].image, 'assets/images/farewell_04_light.webp');
      expect(f[5].image, 'assets/images/farewell_05_eyes_female.webp');
      for (final l in [...m, ...f]) {
        expect(File(l.image).existsSync(), isTrue, reason: l.image);
      }
    });

    test('첫 펫 종류: 속성 점수에 맞춤, 없거나 다른 속성이면 호문쿨루스', () {
      expect(PetRules.firstPetFor(Element.wind), PetSpecies.crow);
      expect(PetRules.firstPetFor(Element.dark), PetSpecies.blackCat);
      expect(PetRules.firstPetFor(Element.poison), PetSpecies.toad);
      expect(PetRules.firstPetFor(Element.light), PetSpecies.owl);
      expect(PetRules.firstPetFor(Element.fire), PetSpecies.lizard);
      for (final e in [
        null, Element.water, Element.earth, Element.ice, Element.thunder,
        Element.metal,
      ]) {
        expect(PetRules.firstPetFor(e), PetSpecies.homunculus);
      }
    });

    test('새로 Lv.11: 첫 펫이 동행·말하는 쪽, 알은 이때 보임, 도중에 끄면 다시', () async {
      final store = account(11,
          hunts: 40,
          pets: const PetState(
              eggs: [PetEgg(id: 'e1')], firstEggFound: true, nextId: 2));
      final c = await start(store);
      expect(c.farewellPending, isTrue);
      expect(c.farewellDone, isFalse);
      // 컷신 도중 앱을 끄면 저장된 게 없어 다시 처음부터
      final again = await start(store);
      expect(again.farewellPending, isTrue);

      final pet = await again.completeFarewell('');
      expect(pet.species, PetSpecies.homunculus);
      expect(pet.name, '호문쿨루스');
      expect(again.firstPet?.uid, pet.uid);
      expect(again.companionPet?.uid, pet.uid);
      expect(again.voicePet?.uid, pet.uid);
      expect(again.companionName, '호문쿨루스');
      expect(again.masteryVoice, '호문쿨루스');
      expect(again.farewellDone, isTrue);
      expect(again.farewellPending, isFalse);
      expect(again.pets.eggs, hasLength(1));
      expect(again.firstSpiritName, '불씨');
      expect(again.profile.spiritName, '불씨'); // 정령 저장 값은 그대로
      final mem = again.spiritMemory!;
      expect(mem.met, DateTime(2026, 11, 1));
      expect(mem.days, 15);
      expect(mem.monsters, 40);
      // 한 번만
      final third = await start(store);
      expect(third.farewellPending, isFalse);
      expect(await third.releasePet(pet.uid), isFalse); // 첫 펫은 돌려보낼 수 없다
    });

    test('예전 이별을 본 Lv.11 이상: 한 번 컷신 + 첫 펫 하나 더, 동행은 새 첫 펫',
        () async {
      final born = DateTime(2026, 11, 5);
      final store = account(13,
          pets: PetState(
            farewellAt: born,
            firstSpiritName: '불씨',
            firstSpiritKind: 'water',
            pets: [
              Pet(uid: 'pet1', species: PetSpecies.owl, name: '부엉', bornAt: born),
            ],
            companion: 'pet1',
            nextId: 2,
            letters: const ['lv10'],
          ));
      final c = await start(store);
      expect(c.farewellPending, isTrue);
      expect(c.firstPet, isNull);
      final pet = await c.completeFarewell('빛나');
      expect(c.pets.pets, hasLength(2));
      expect(c.companionPet?.uid, pet.uid);
      expect(c.companionName, '빛나');
      expect(c.pets.farewellAt, born); // 이별 날은 그대로
      expect(c.pets.letters, contains('lv10'));
      expect(c.firstSpiritName, '불씨');
      expect((await start(store)).farewellPending, isFalse);
    });

    test('정령술 대사: 첫 펫용 문구 (떠난 정령 이름·조사)', () {
      expect(MasteryRules.stageLine(Mastery.spirit, MasteryStage.familiar, departed: '불씨'),
          '원정 나가는 게 점점 익숙해져! 나도 잘할 수 있어.');
      expect(MasteryRules.stageLine(Mastery.spirit, MasteryStage.skilled, departed: '불씨'),
          '말 안 해도 어디로 갈지 알 것 같아. 불씨가 가르쳐 준 길이야!');
      expect(MasteryRules.stageLine(Mastery.spirit, MasteryStage.skilled, departed: '물방울'),
          '말 안 해도 어디로 갈지 알 것 같아. 물방울이 가르쳐 준 길이야!');
      expect(MasteryRules.stageLine(Mastery.spirit, MasteryStage.expert, departed: '불씨'),
          '나랑 손발이 척척 맞네. 원정이 훨씬 수월해졌어!');
      expect(MasteryRules.stageLine(Mastery.spirit, MasteryStage.master, departed: '불씨'),
          '우린 이제 마음이 하나야. 불씨도 기뻐할 거야!');
      expect(MasteryRules.leanLine(Mastery.spirit, departed: '불씨'),
          '나를 자주 믿고 보내 줘서 고마워. 불씨 몫까지 열심히 할게!');
      // 정령이 말할 때는 그대로
      expect(MasteryRules.stageLine(Mastery.spirit, MasteryStage.familiar),
          '원정 보내는 손발이 조금씩 맞아 가!');
      expect(MasteryRules.stageLine(Mastery.smith, MasteryStage.familiar, departed: '불씨'),
          MasteryRules.stageLine(Mastery.smith, MasteryStage.familiar));
    });
  });

  group('#181 확인 답', () {
    test('젤리 안내: 가까운 슬라임을 고른다 (없으면 안내 슬라임)', () async {
      final c = await start(account(7));
      await c.handleFix(const LocationFix(point: GeoPoint(37.3219, 126.8309)));
      final id = c.nearestSlimeId();
      expect(id, isNotNull);
      c.guideSpotId = id;
      expect(c.guideMapTarget?.id, id);
      final spawn = c.todaySpawns.firstWhere((s) => s.id == id);
      expect(spawn.monster, MonsterId.slime);
    });
  });
}
