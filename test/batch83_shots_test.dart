// 묶음 83 (build/screenshots/b83_*) — 큰 iPhone · SE

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/highland_state.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/features/battle/battle_view.dart' show BattleView;
import 'package:isekai_reality/features/highland/highland_screen.dart';
import 'package:isekai_reality/features/highland/sky_turn_view.dart';
import 'package:isekai_reality/theme/top_notice.dart';

import 'batch50_test.dart' as b50;
import 'batch83_test.dart' as t83;

final _root = GlobalKey();

Future<void> _loadFonts() async {
  for (final family in ['Roboto', 'FlutterTest']) {
    final korean = FontLoader(family);
    for (final f in ['NanumGothic-Regular', 'NanumGothic-Bold', 'NanumGothic-ExtraBold']) {
      korean.addFont(File('test/fonts/$f.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await korean.load();
  }
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      final image = element.widget as Image;
      await precacheImage(image.image, element, onError: (_, __) {});
    }
  });
  await tester.pump();
  for (var i = 0; i < 2; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
  }
  final boundary = tester.renderObject(find.byKey(_root)) as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File('build/screenshots/b83_$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}

const _devices = [
  ('SE', Size(750, 1334), 2.0, 40.0, 0.0),
  ('큰iPhone', Size(1290, 2796), 3.0, 177.0, 102.0),
];

void _device(WidgetTester tester, (String, Size, double, double, double) d) {
  tester.view.physicalSize = d.$2;
  tester.view.devicePixelRatio = d.$3;
  tester.view.padding = FakeViewPadding(top: d.$4, bottom: d.$5);
  tester.view.viewPadding = FakeViewPadding(top: d.$4, bottom: d.$5);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _page(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(RepaintBoundary(
    key: _root,
    child: MaterialApp(
        key: UniqueKey(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Roboto'),
        builder: (context, child) => TopNoticeHost(child: child!),
        home: home),
  ));
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, String key, [int settle = 4]) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await _settle(tester, settle);
}

/// 판 위 칸을 누름 (마름모 가운데)
Future<void> _tapCell(WidgetTester tester, int i) async {
  final r = tester.getRect(find.byKey(Key('skyTile_$i')));
  await tester.tapAt(r.topCenter + Offset(0, r.height / 3));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

/// 섬 하나에 [climb] 상태로 (없으면 아직 안 오름)
Future<AppController> _island(WidgetTester tester, Isle isle, {SkyClimb Function(String slot)? climb, Map<String, int> mats = const {'skyFeather': 2}, bool guide = true}) async {
  late AppController c;
  await tester.runAsync(() async {
    final slot = t83.slotNowAm();
    c = await t83.onIsland(isle: isle, mats: mats, climb: climb?.call(slot), guideSeen: guide);
  });
  return c;
}

/// [floor] 층 · 입구에서 [extra] 칸까지 밝힌 판
SkyClimb _at(String slot, int floor, {int seed = 21, int wind = 12, int shards = 0, List<int> Function(SkyBoard)? open, int? hero}) {
  final b = SkyBoard.generate(seed, floor);
  final o = {b.entrance, ...?open?.call(b)}.toList();
  return SkyClimb(slot: slot, seed: seed, floor: floor, wind: wind, opened: o, hero: hero ?? o.last, shards: shards);
}

/// 입구에서 [to] 까지 가장 짧은 길 (입구 포함 안 함)
List<int> _path(SkyBoard b, int to, {Set<int> from = const {}}) {
  final start = from.isEmpty ? {b.entrance} : from;
  final prev = <int, int>{};
  final q = [...start];
  final seen = {...start};
  for (var k = 0; k < q.length; k++) {
    for (final j in b.neighbors4(q[k])) {
      if (seen.add(j)) {
        prev[j] = q[k];
        q.add(j);
      }
    }
  }
  final out = <int>[];
  var s = to;
  while (!start.contains(s)) {
    out.add(s);
    s = prev[s]!;
  }
  return out.reversed.toList();
}

SkyTurn _turnOf(WidgetTester tester) => tester.widget<SkyTurnView>(find.byType(SkyTurnView)).turn;

void main() {
  setUpAll(_loadFonts);

  for (final d in _devices) {
    final n = d.$1;

    testWidgets('b83 $n: 1 섬 다섯 1층 첫 화면 · 첫 안내', (tester) async {
      _device(tester, d);
      for (final isle in Isle.values) {
        final c = await _island(tester, isle, guide: false);
        await _page(tester, HighlandScreen(key: ObjectKey('h$n${isle.name}'), controller: c));
        if (isle == Isle.wind) await _shot(tester, '${n}_00_입구');
        await _tap(tester, 'skyClimb');
        await _shot(tester, '${n}_01_${isle.name}_1층_첫화면${isle == Isle.wind ? '_첫안내' : ''}');
        if (isle == Isle.wind) {
          // 첫 걷기 → 계단 기둥 안내
          final b = c.skyBoard!;
          await _tapCell(tester, b.neighbors4(b.entrance).first);
          await _settle(tester, 4);
          await _shot(tester, '${n}_02_계단기둥_안내');
        }
        await _done(tester);
      }
    });

    testWidgets('b83 $n: 2 바람 섬 1 · 2 · 3층 · 숫자 · 기둥 · 계단 · 샘 · 끌어 보기', (tester) async {
      _device(tester, d);
      for (final f in [2, 3]) {
        final c = await _island(tester, Isle.wind, climb: (s) => _at(s, f, wind: 20));
        await _page(tester, HighlandScreen(key: ObjectKey('f$n$f'), controller: c));
        await _shot(tester, '${n}_03_바람섬_$f층_첫화면');
        await _done(tester);
      }
      // 숫자: 조각 옆 빈 칸까지 밝힘
      {
        const seed = 21;
        final b = SkyBoard.generate(seed, 1);
        final near = b.neighbors8(b.shard).firstWhere((i) => b.at(i) == SkyCell.empty);
        final c = await _island(tester, Isle.wind,
            climb: (s) => _at(s, 1, seed: seed, open: (b) => _path(b, near), wind: 10));
        await _page(tester, HighlandScreen(key: ObjectKey('num$n'), controller: c));
        await _shot(tester, '${n}_04_숫자힌트');
        // 끌어서 둘러보기
        final view = tester.getRect(find.byKey(const Key('skyNews'))).topCenter - const Offset(0, 160);
        await tester.dragFrom(view, const Offset(-140, 90));
        await _settle(tester, 3);
        await _shot(tester, '${n}_05_끌어서_둘러보기');
        await _done(tester);
      }
      // 계단 찾음 (바람 0 이어도 위층으로) → 올라가는 연출
      {
        final c = await _island(tester, Isle.wind, climb: (s) => _at(s, 1, wind: 0, open: (b) => _path(b, b.goal)));
        await _page(tester, HighlandScreen(key: ObjectKey('stair$n'), controller: c));
        await _shot(tester, '${n}_06_계단_찾음_바람0');
        await tester.tap(find.byKey(const Key('skyUp')));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 110));
        }
        await _shot(tester, '${n}_07_위층으로_연출');
        await _settle(tester, 10);
        await _shot(tester, '${n}_08_2층_도착');
        await _done(tester);
      }
      // 2층 기둥 장식 (기둥 칸을 여럿 밝힘)
      {
        final c = await _island(tester, Isle.wind, climb: (s) {
          final b = SkyBoard.generate(21, 2);
          final path = <int>{b.entrance};
          for (final col in b.columns) {
            path.addAll(_path(b, col, from: path));
          }
          return SkyClimb(slot: s, seed: 21, floor: 2, wind: 9, opened: path.toList(), hero: b.columns.first);
        });
        await _page(tester, HighlandScreen(key: ObjectKey('col$n'), controller: c));
        await _shot(tester, '${n}_09_2층_부서진기둥');
        await _done(tester);
      }
      // 바람 샘 밝힘
      {
        final b = SkyBoard.generate(21, 1);
        final spring = [for (var i = 0; i < b.cells.length; i++) if (b.at(i) == SkyCell.spring) i].first;
        final path = _path(b, spring);
        final c = await _island(tester, Isle.wind, climb: (s) => _at(s, 1, open: (_) => path.sublist(0, path.length - 1), wind: 8));
        await _page(tester, HighlandScreen(key: ObjectKey('spr$n'), controller: c));
        await _tapCell(tester, spring);
        await tester.pump(const Duration(milliseconds: 300));
        await _shot(tester, '${n}_10_바람샘');
        await _done(tester);
      }
    });

    testWidgets('b83 $n: 3 석상 병사 · 제단 · 끝', (tester) async {
      _device(tester, d);
      // 석상 병사: 밝히면 바로 싸움 → 이긴 뒤 HP
      {
        final b = SkyBoard.generate(21, 1);
        final soldier = [for (var i = 0; i < b.cells.length; i++) if (b.at(i) == SkyCell.soldier) i].first;
        final path = _path(b, soldier);
        final c = await _island(tester, Isle.ice, climb: (s) => _at(s, 1, open: (_) => path.sublist(0, path.length - 1), wind: 10));
        await _page(tester, HighlandScreen(key: ObjectKey('sol$n'), controller: c));
        await _tapCell(tester, soldier);
        await _settle(tester, 6);
        for (var i = 0; i < 3; i++) {
          await tester.pump(const Duration(milliseconds: 950));
        }
        await _shot(tester, '${n}_11_석상병사_싸움');
        await _done(tester);
        await tester.runAsync(() async {
          final bt = c.startSoldierBattle()!;
          bt.playerHp = (bt.playerMaxHp * 0.55).round();
          b50.win(bt);
          await c.finishSoldierBattle(bt);
        });
        await _page(tester, HighlandScreen(key: ObjectKey('sol2$n'), controller: c));
        await _shot(tester, '${n}_12_석상병사_이긴뒤_HP');
        await _done(tester);
      }
      // 꼭대기 제단: 조각 1 / 3 · 3 / 3
      for (final k in [1, 3]) {
        final c = await _island(tester, Isle.wind, climb: (s) => _at(s, 3, shards: k, wind: 4, open: (b) => _path(b, b.goal)));
        await _page(tester, HighlandScreen(key: ObjectKey('alt$n$k'), controller: c));
        await _shot(tester, '${n}_13_제단_조각${k}_3${k == 3 ? '_수호자깨우기' : ''}');
        await _done(tester);
      }
      // 끝: 내려가기 · 바람 · HP · 섬이 떠남
      {
        final c = await _island(tester, Isle.light, climb: (s) => _at(s, 1, open: (b) => b.neighbors4(b.entrance).toList()));
        await _page(tester, HighlandScreen(key: ObjectKey('l$n'), controller: c));
        await _tap(tester, 'skyLeave');
        await _shot(tester, '${n}_14_내려가기_묻기');
        await _tap(tester, 'skyLeaveYes', 6);
        await _shot(tester, '${n}_15_끝_내려가기');
        await _done(tester);
      }
      {
        final b = SkyBoard.generate(21, 1);
        final empty = b.neighbors4(b.entrance).firstWhere((i) => b.at(i) == SkyCell.empty);
        final c = await _island(tester, Isle.thunder, climb: (s) => SkyClimb(slot: s, seed: 21, wind: 1, opened: [b.entrance], hero: b.entrance, crystals: 2, stones: 1));
        await _page(tester, HighlandScreen(key: ObjectKey('w$n'), controller: c));
        await _tapCell(tester, empty);
        await _settle(tester, 8);
        await _shot(tester, '${n}_16_끝_바람다함');
        await _done(tester);
      }
      {
        final b2 = SkyBoard.generate(21, 2);
        final soldier = [for (var i = 0; i < b2.cells.length; i++) if (b2.at(i) == SkyCell.soldier) i].first;
        final c = await _island(tester, Isle.water, climb: (s) {
          final path = _path(b2, soldier);
          return SkyClimb(slot: s, seed: 21, floor: 2, wind: 5, opened: [b2.entrance, ...path], hero: soldier, soldier: soldier, crystals: 1, stones: 2);
        });
        await _page(tester, HighlandScreen(key: ObjectKey('hp$n'), controller: c));
        // 화면이 띄운 싸움을 지게 함
        final battle = tester.widget<BattleView>(find.byType(BattleView)).battle;
        battle.playerHp = 1;
        for (var i = 0; i < 14; i++) {
          await tester.pump(const Duration(milliseconds: 950));
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        }
        await _settle(tester, 6);
        await _shot(tester, '${n}_17_끝_HP다함');
        await _done(tester);
      }
      {
        final c = await _island(tester, Isle.ice, climb: (s) => _at(s, 1, open: (b) => b.neighbors4(b.entrance).toList()));
        await _page(tester, HighlandScreen(key: ObjectKey('g$n'), controller: c));
        b50.now = b50.am.add(const Duration(minutes: 95));
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await _settle(tester, 4);
        await _shot(tester, '${n}_18_끝_섬이떠남');
        await _done(tester);
      }
    });

    testWidgets('b83 $n: 4 수호자 턴제 × 섬 다섯', (tester) async {
      _device(tester, d);
      for (final isle in Isle.values) {
        final nm = isle.name;
        final c = await _island(tester, isle, climb: (s) => _at(s, 3, shards: 3, wind: 2, open: (b) => _path(b, b.goal)));
        await _page(tester, HighlandScreen(key: ObjectKey('t$n$nm'), controller: c, turnStep: const Duration(milliseconds: 60)));
        await _tap(tester, 'skyWake');
        await _shot(tester, '${n}_20_${nm}_첫화면');
        final t = _turnOf(tester);
        if (isle == Isle.light) t.foeHp = t.foeMax * 2 ~/ 5;
        // 큰 기술 예고까지
        for (var k = 0; k < 12 && !t.bigNext && !t.isOver; k++) {
          await _tap(tester, 'skyCmd_guard', 6);
        }
        await _shot(tester, '${n}_21_${nm}_큰기술_예고_초록힌트');
        final hint = t.hinted;
        final cmd = hint.isNotEmpty ? hint.first : SkyCmd.guard;
        await tester.tap(find.byKey(Key('skyCmd_${cmd.name}')));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        await _shot(tester, '${n}_22_${nm}_발동');
        await _settle(tester, 8);
        if (isle == Isle.wind) {
          // 지는 화면
          t.hp = 1;
          await _tap(tester, 'skyCmd_strike', 10);
          await _settle(tester, 10);
          await _shot(tester, '${n}_24_${nm}_짐');
        } else {
          t.foeHp = 1;
          await _tap(tester, 'skyCmd_strike', 10);
          await _settle(tester, 12);
          await _shot(tester, '${n}_23_${nm}_이김');
        }
        await _done(tester);
      }
    });
  }
}
