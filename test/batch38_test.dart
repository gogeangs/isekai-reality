import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/lens/snap_lens.dart';
import 'package:isekai_reality/features/town/inn_screen.dart';
import 'package:isekai_reality/features/village/board_parchment.dart';
import 'package:isekai_reality/features/village/board_screen.dart';
import 'package:isekai_reality/features/village/village_screen.dart';

void main() {
  final t0 = DateTime(2026, 11, 16, 10);

  Future<AppController> start(InMemoryRecordStore store) async {
    final c = AppController(
      store: store,
      health: FakeHealthSource(stepsByDay: const {}),
      clock: () => t0,
    )..mailSources = const [];
    await c.init();
    return c;
  }

  group('#211 마을 3×3', () {
    test('건물 8채는 3×3 묶음 안 서로 다른 칸, 가운데(우물)는 비움', () {
      const cl = VillageScreen.cluster;
      final cells = <String>{};
      // 묶음 43: 훈련장은 오른쪽 공터 (3×3 밖)
      for (final f in VillageScreen.facilities
          .where((f) =>
              f.facility != Facility.training &&
              f.facility != Facility.garden &&
              f.facility != Facility.tavern &&
              f.facility != Facility.guildhall)) {
        final sp = f.spot;
        expect(sp.x - sp.w / 2, greaterThanOrEqualTo(cl.left - 1), reason: f.name);
        expect(sp.x + sp.w / 2, lessThanOrEqualTo(cl.right + 1), reason: f.name);
        expect(sp.y, lessThanOrEqualTo(cl.bottom), reason: f.name);
        cells.add('${sp.x}|${sp.y}');
      }
      expect(cells.length, 8);
      expect(cells, isNot(contains('770.0|642.0')));
    });
  });

  group('#213 시설 마을 사람 안내', () {
    test('처음엔 첫 줄 → 그 뒤 막 대사와 기본 안내를 번갈아 · 상황 안내가 먼저', () async {
      final c = await start(
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루')));
      const g = VillageRules.shopGuide;
      expect(c.takeNpcLine(Npc.mina, guide: g), VillageRules.npc(Npc.mina).first);
      final a = c.takeNpcLine(Npc.mina, guide: g);
      final b = c.takeNpcLine(Npc.mina, guide: g);
      final a2 = c.takeNpcLine(Npc.mina, guide: g);
      expect(VillageRules.linesFor(Npc.mina, c.villageAct), contains(a));
      expect(b, g);
      expect(VillageRules.linesFor(Npc.mina, c.villageAct), contains(a2));
      expect(a2, isNot(a));
      expect(
          c.takeNpcLine(Npc.mina, guide: g, situation: '상황'), '상황');
    });

    test('여관 상황 안내: 가득 · 쉬는 중 · 오늘 이미 쉼 · 없음', () {
      expect(InnScreen.innSituation(resting: true, restedToday: false, full: true),
          VillageRules.innFull);
      expect(InnScreen.innSituation(resting: true, restedToday: false),
          VillageRules.innResting);
      expect(InnScreen.innSituation(resting: false, restedToday: true),
          VillageRules.innRested);
      expect(InnScreen.innSituation(resting: false, restedToday: false), isNull);
    });

    test('탭 안내 문구', () {
      expect(VillageRules.smithyGuide(1), contains('부서지지'));
      expect(VillageRules.smithyGuide(2), contains('분해'));
      expect(VillageRules.alchemyGuide(2), contains('상위 재료'));
    });
  });

  group('#215 게시판 쪽지', () {
    test('줄 사이는 핀이 튀어나온 높이 + 6 이상, 좌우 여백은 보이는 종이 기준', () {
      // 쪽지 위아래 여백(위 10 · 아래 4) + 줄 사이
      expect(4 + NoteGrid.rowGap + 10, greaterThanOrEqualTo(ParchmentNote.pinRise + 6));
      expect(ParchmentNote.smallSide, inInclusiveRange(22, 24));
    });

    testWidgets('긴 이름은 말줄임 없이', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: NoteGrid(children: [
                SmallNote(title: '필드 몬스터 15마리 잡기', seed: 1, progress: '1 / 15마리'),
                SmallNote(title: '이번 주 2만 보 걷기', seed: 2, progress: '1 / 2'),
              ]),
            ),
          ),
        ),
      ));
      await tester.pump();
      for (final t in tester.widgetList<Text>(find.byKey(const Key('noteTitle')))) {
        expect(t.overflow, isNot(TextOverflow.ellipsis));
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('묶음 37 확인 답: 섞인 종족 렌즈 사진', () {
    test('이름판엔 렌즈 종족 이름만, 렌즈 종족이 없으면 모두', () {
      expect(SnapLens.lensRaces(const [Race.elf, Race.dwarf]), [Race.elf]);
      expect(SnapLens.lensRaces(const [Race.dwarf, Race.elf, Race.elf]), [Race.elf]);
      expect(SnapLens.lensRaces(const [Race.dwarf, Race.fairy]),
          [Race.dwarf, Race.fairy]);
    });
  });
}
