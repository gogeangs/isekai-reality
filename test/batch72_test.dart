// 묶음 72: #304 하늘길 · #305 가득 찬 가방 · 수리 재료 「아무 약초」 · #303 위쪽 버튼 그림 · 새 그림 연결

import 'package:flutter/material.dart' hide Element;
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/alchemy/alchemy_screen.dart';
import 'package:isekai_reality/features/chat/chat_screens.dart';
import 'package:isekai_reality/features/profile/profile_screen.dart';

import 'batch52_test.dart' as b52;
import 'batch56_test.dart' as b56;
import 'batch70_test.dart' as b70;
import 'support/smithy_seed.dart';
import 'support/village_seed.dart';

/// 가방이 꼭 가득 찬 계정 (재료 한 칸씩 + 입은 장비 셋 · 안 입은 둘)
Future<AppController> fullBag() async {
  var c = await startVillage(12, more: {'armory': seededArmory()});
  final cap = c.bagCapacity;
  final used = c.bagUsed;
  final fill = [
    for (final m in MaterialId.values)
      if (m != MaterialId.ironShard && m != MaterialId.ironIngot && !Materials.isHerb(m)) m,
  ].take(cap - used - 1);
  c = await startVillage(12, more: {'armory': seededArmory()}, gains: {
    for (final m in fill) m.name: 1,
    MaterialId.ironShard.name: 6,
    'gold': 1000,
  });
  return c;
}

void main() {
  setUp(() => b56.now = b52.t0);

  group('#305 가득 찬 가방', () {
    test('꼭 가득 참 (시험 준비)', () async {
      final c = await fullBag();
      expect(c.bagUsed, c.bagCapacity);
    });

    test('장비 벗기: 가득하면 벗지 않음 (칸을 넘기지 않음)', () async {
      final c = await fullBag();
      expect(await c.unequip(EquipSlot.weapon), isFalse);
      expect(c.bagUsed, lessThanOrEqualTo(c.bagCapacity));
      expect(c.armory.equipped[EquipSlot.weapon], 'w');
    });

    test('재료 가공: 만든 재료가 새 칸이면 가방 대신 「가방이 가득 찼어요」로', () async {
      final c = await fullBag();
      final r = ProcessRules.all.firstWhere((x) => x.id == 'ingot');
      expect(await c.process(r), isTrue);
      expect(c.bagUsed, lessThanOrEqualTo(c.bagCapacity));
      expect(c.player.materialExact(MaterialId.ironIngot), 0);
    });

    test('필드 사냥 · 같은 칸에 쌓이는 것은 들어감 · 새 칸은 넘기지 않음', () async {
      final c = await fullBag();
      final spawn = c.todaySpawns.first;
      final b = c.startFieldBattle(spawn)!..runToEnd();
      await c.finishFieldBattle(spawn, b);
      // 정령이 떠나기 전 처음 알(4%)은 숨은 채로 들어온다 (묶음 75 #327) → 그 칸은 빼고 본다
      expect(c.bagUsed - c.pets.eggs.length, lessThanOrEqualTo(c.bagCapacity));
    });

    test('칸이 줄어 넘친 까닭: 어제 큰 짐 보따리 → 「늘어났던 칸이 끝나서」', () async {
      final y = DateTime(2026, 11, 15);
      final c = await startVillage(12, more: {
        'jobs': {
          'marks': {'bigPackDay': int.parse(DailyRecord_key(y))},
        },
      });
      expect(c.bigPackEnded, isTrue);
    });
  });

  test('#304 하늘길: 가운데가 직선 거리의 10% 안팎 비켜남 · 늘 같은 쪽', () {
    const a = (37.50, 127.00), b = (37.51, 127.01);
    final p = Expedition.skyArc(a, b);
    expect(p, hasLength(17));
    final mid = p[8];
    final dLat = (b.$1 - a.$1), dLng = (b.$2 - a.$2) * 0.8;
    final len = (dLat * dLat + dLng * dLng);
    final ox = (mid.$1 - (a.$1 + b.$1) / 2), oy = (mid.$2 - (a.$2 + b.$2) / 2) * 0.8;
    final off = (ox * ox + oy * oy);
    expect(off / len, closeTo(0.01, 0.004), reason: '10% (제곱 0.01)');
    expect(Expedition.skyArc(a, b)[8], mid);
  });

  test('대장간 채집 도구 수리 재료: 낫은 「아무 약초」', () {
    expect(Materials.needName(HarvestRules.repairMaterial(HarvestTool.sickle)), '아무 약초');
  });

  testWidgets('#303 위쪽 버튼 그림: 친구 · 대화 · 설정', (tester) async {
    for (final (lv, asset) in [(9, 'icon_friends'), (11, 'icon_chat')]) {
      late AppController c;
      await tester.runAsync(() async {
        c = (await b70.chatAt(lv)).$1;
        await c.refreshChat();
      });
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: ChatButton(key: UniqueKey(), controller: c)))));
      await tester.pump();
      expect(
          find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/$asset.webp'),
          findsOneWidget,
          reason: 'Lv.$lv');
      await tester.pumpWidget(const SizedBox());
    }
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: SettingsButton()))));
    expect(
        find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/icon_settings.webp'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
  });

  testWidgets('연금술: 큰 가마솥 그림 + 흰 물 그림(코드 색)', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    late AppController c;
    await tester.runAsync(() async => c = await startVillage(12));
    await tester.pumpWidget(MaterialApp(home: AlchemyScreen(controller: c)));
    await tester.pump();
    final art = tester.widget<Image>(find.byKey(const Key('cauldronArt')));
    expect((art.image as AssetImage).assetName, 'assets/images/alchemy_cauldron.webp');
    final brew = tester.widget<Image>(find.byKey(const Key('cauldronLiquid')));
    expect((brew.image as AssetImage).assetName, 'assets/images/alchemy_brew.webp');
  });
}

// ignore: non_constant_identifier_names
String DailyRecord_key(DateTime d) => '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
