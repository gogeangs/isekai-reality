import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/lens_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/lens/photo_frame.dart';
import 'package:isekai_reality/features/lens/race_stickers.dart';
import 'package:isekai_reality/features/village/board_screen.dart';

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

  group('#210 돋보기 하루 무료 5번', () {
    test('하루 무료 5번 · 감정 보상 5번', () {
      expect(LensRules.freePerDay, 5);
      expect(LensRules.rewardedPerDay, 5);
    });

    test('무료 5번을 쓰면 가방 돋보기, 셈은 다시 열어도 남는다', () async {
      final store = InMemoryRecordStore(
          profile: const PlayerProfile(name: '하루'));
      final c = await start(store);
      expect(c.lensFreeLeft, 5);
      for (var i = 0; i < 3; i++) {
        expect(await c.appraise(const [Race.elf]), isNotNull);
      }
      expect(c.lensFreeLeft, 2);
      final again = await start(store);
      expect(again.lensFreeLeft, 2);
      for (var i = 0; i < 2; i++) {
        expect(await again.appraise(const [Race.elf]), isNotNull);
      }
      expect(again.lensFreeToday, isFalse);
      expect(again.canAppraise, isFalse); // 가방 돋보기 없음
      expect(await again.appraise(const [Race.elf]), isNull);
    });

    test('예전 기록: 오늘 이미 무료를 쓴 사람은 남은 4번', () async {
      final c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {
          'lens': const LensState(
                  seen: ['elf'], day: '2026-11-16', rewardedToday: 1,
                  freeDay: '2026-11-16')
              .toJson(),
        },
      ));
      expect(c.lensFreeLeft, 4);
      expect(c.lensRewardsLeft, 4);
    });

    test('예전 기록: 어제 무료를 쓴 사람은 오늘 5번', () async {
      final c = await start(InMemoryRecordStore(
        profile: const PlayerProfile(name: '하루'),
        json: {
          'lens': const LensState(freeDay: '2026-11-15', freeUsed: 5).toJson(),
        },
      ));
      expect(c.lensFreeLeft, 5);
    });
  });

  group('#207 #208 #209 감정 사진', () {
    test('2D 종족 장식은 그리지 않는다', () {
      expect(raceStickersOn, isFalse);
    });

    test('아래 띠 세 줄은 금테 안 이름판에', () {
      expect(PhotoFrame.plateTop, greaterThan(1250));
      expect(PhotoFrame.plateTop + 106 + 20, lessThan(1392));
    });
  });

  group('#206 의뢰 게시판 쪽지', () {
    test('짧은 이름은 그대로 한 줄, 조금 긴 이름은 글씨를 줄여 한 줄, 아주 길면 두 줄',
        () {
      const scaler = TextScaler.noScaling;
      final short = NoteTitle.fit('슬라임 3마리', 400, scaler);
      expect(short, (14.0, 1));
      final mid = NoteTitle.fit('이번 주 2만 보 걷기', 172, scaler);
      if (mid.$2 == 1) {
        expect(mid.$1, lessThanOrEqualTo(14));
        expect(mid.$1, greaterThanOrEqualTo(NoteTitle.minSize));
      } else {
        expect(mid, (14.0, 2));
      }
      final long = NoteTitle.fit('잿빛 슬라임을 잡고 정령의 호수에 들르기', 172, scaler);
      expect(long, (14.0, 2));
    });

    testWidgets('두 칸 쪽지: 같은 폭, 같은 줄은 같은 높이, 줄끼리 겹치지 않음', skip: true, // 묶음 78 #309: 한 줄 넓은 카드로 바뀜
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: NoteGrid(children: [
                for (final (i, t) in [
                  '슬라임 3마리',
                  '이번 주 2만 보 걷기',
                  '잿빛 슬라임을 잡고 정령의 호수에 들르기',
                ].indexed)
                  SmallNote(
                      key: Key('n$i'),
                      title: t,
                      seed: i,
                      ratio: 0.5,
                      progress: '1 / 2'),
              ]),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final a = tester.getRect(find.byKey(const Key('n0')));
      final b = tester.getRect(find.byKey(const Key('n1')));
      final c = tester.getRect(find.byKey(const Key('n2')));
      expect(a.width, closeTo(b.width, 0.5));
      expect(a.height, closeTo(b.height, 0.5));
      expect(a.top, closeTo(b.top, 0.5));
      expect(c.top, greaterThanOrEqualTo(a.bottom));
      // 게시판(320) 밖으로 나가지 않음
      final grid = tester.getRect(find.byType(NoteGrid));
      for (final r in [a, b, c]) {
        expect(r.left, greaterThanOrEqualTo(grid.left - 0.5));
        expect(r.right, lessThanOrEqualTo(grid.right + 0.5));
      }
      expect(tester.takeException(), isNull);
    });
  });
}
