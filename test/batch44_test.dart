// 묶음 44 #225: 안 열린 마을 건물을 「짓고 있는 모습」으로 · 완공 연출

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/village/village_screen.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'support/village_seed.dart';

void main() {
  test('공사 단계: 3레벨 이상 전 터 닦기 · 2레벨 전 뼈대 · 바로 전 거의 완성', () {
    // 연금술 공방 Lv.7
    expect(VillageRules.buildStage(4, 7), 1);
    expect(VillageRules.buildStage(5, 7), 2);
    expect(VillageRules.buildStage(6, 7), 3);
    // 대장간 Lv.3: 앞 단계가 모자라면 있는 단계부터 (Lv.1 뼈대 → Lv.2 거의 완성)
    expect(VillageRules.buildStage(1, 3), 2);
    expect(VillageRules.buildStage(2, 3), 3);
    // 의뢰 게시판 Lv.4
    expect(VillageRules.buildStage(1, 4), 1);
    // 펫 쉼터 Lv.11 · 길드 Lv.15
    expect(VillageRules.buildStage(10, 11), 3);
    expect(VillageRules.buildStage(13, 15), 2);
    expect(VillageRules.builtLine('연금술 공방'), '연금술 공방이 다 지어졌어!');
    expect(VillageRules.builtLine('길드'), '길드가 다 지어졌어!');
  });

  test('레벨마다 안 열린 건물의 단계', () async {
    final c = await startVillage(6, village: {'seen': ['intro']});
    expect(c.buildStage('smithy'), isNull); // 열림
    expect(c.buildStage('board'), isNull);
    expect(c.buildStage('alchemy'), 3);
    expect(c.buildStage('shelter'), 1);
    expect(c.buildStage('guild'), 1);
    expect(c.buildStage('inn'), isNull);
  });

  test('예전 기록: 이미 열린 건물은 완공 그림 그대로, 연출 없음', () async {
    final c = await startVillage(8, village: {'seen': ['intro']});
    expect(c.builtPending, isEmpty);
    expect(c.villageMoment, isNull);
  });

  testWidgets('열린 뒤 처음 마을: 공사 그림 → 완공 그림 + 반짝 + 한마디, 한 번만', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(7, village: {
          'seen': ['intro', 'v44', 'built:smithy', 'built:board'],
        }));
    expect(c.builtPending, ['alchemy']);
    expect(c.villageMoment, '연금술 공방이 다 지어졌어!');
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!),
        home: Scaffold(body: VillageScreen(controller: c))));
    await tester.pump();
    expect(find.byKey(const Key('builtReveal_alchemy')), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 2));
    expect(c.builtPending, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: VillageScreen(controller: c))));
    await tester.pump();
    expect(find.byKey(const Key('builtReveal_alchemy')), findsNothing);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('Lv.1 마을: 공사 그림 · 🔨 이름표 · 누르면 짓는 중', (tester) async {
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(1, village: {'seen': ['intro']}));
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => TopNoticeHost(child: child!),
        home: Scaffold(body: VillageScreen(controller: c))));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('build2_smithy')), findsOneWidget);
    expect(find.byKey(const Key('build1_board')), findsOneWidget);
    expect(find.byKey(const Key('build1_alchemy')), findsOneWidget);
    Text sub(String n) => tester.widget<Text>(find.byKey(Key('tagSub_$n')));
    expect(sub('smithy').data, 'Lv.3 완공');
    expect(sub('shelter').data, '첫 펫과 함께\n완공');
    await tester.tap(find.byKey(const Key('locked_smithy')));
    await tester.pump();
    expect(find.text('짓는 중이에요 · Lv.3에 완공!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });
}
