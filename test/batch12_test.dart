import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/models/lens_state.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';

void main() {
  group('#93 전투 자동 마시기', () {
    Foe foe() =>
        const Foe(monster: MonsterId.ashSlime, maxHp: 100000, attack: 100);

    test('전투 중에 기준을 바꿀 수 있고, 자동으로 마시면 표시가 선다', () {
      final b = Battle(
        playerMaxHp: 1000,
        playerAttack: 1,
        floors: [foe()],
        rng: Random(1),
        startHp: 290,
        potions: const [
          BattlePotion(
              key: 'shop:healSmall',
              name: '작은 회복 물약',
              count: 10,
              hpRatio: 0.2),
        ],
      );
      b.tick();
      expect(b.potionsDrunk, 0); // 꺼져 있다
      b.autoHp = 50;
      var healed = false;
      for (var i = 0; i < 5 && !b.isOver; i++) {
        b.tick();
        healed = healed || b.autoHealed;
      }
      expect(healed, isTrue);
      expect(b.potionsDrunk, greaterThan(0));
    });
  });

  group('#90·#92 원정 길', () {
    final start = DateTime(2026, 11, 8, 12);
    Expedition ex({List<(double, double)> route = const []}) => Expedition(
          spawnId: 's',
          monster: 'ashSlime',
          lat: 37.01,
          lng: 127.01,
          fromLat: 37.0,
          fromLng: 127.0,
          distanceM: 1500,
          mpCost: 1,
          startedAt: start,
          arriveAt: start.add(const Duration(minutes: 10)),
          returnAt: start.add(const Duration(minutes: 20)),
          route: route,
        );

    test('길 끝은 언제나 목표 몬스터 자리', () {
      final e = ex(route: const [(37.0, 127.0), (37.005, 127.004)]);
      expect(e.path.last, (37.01, 127.01));
    });

    test('갈 때는 지금 자리 → 몬스터, 돌아올 때는 지금 자리 → 나', () {
      final e = ex();
      final mid = start.add(const Duration(minutes: 5));
      final go = e.remainingAt(mid);
      expect(go.first.$1, closeTo(37.005, 1e-6));
      expect(go.last, (37.01, 127.01));
      final back = e.remainingAt(start.add(const Duration(minutes: 15)));
      expect(back.first.$1, closeTo(37.005, 1e-6));
      expect(back.last.$1, closeTo(37.0, 1e-9)); // 내 쪽을 가리킨다
    });
  });

  group('#89 원정 말풍선', () {
    test('펫 성격 대사가 섞이고, 빈 말은 없다', () {
      final rng = Random(3);
      final lines = {
        for (var i = 0; i < 200; i++)
          ExpeditionTalkRules.line(
              rng: rng,
              going: true,
              progress: 0.5,
              minutesLeft: 12,
              monster: '슬라임',
              hour: 14,
              species: PetSpecies.toad),
      };
      expect(lines.every((l) => l.isNotEmpty), isTrue);
      expect(lines.any((l) => l.contains('개굴')), isTrue);
      expect(lines.any((l) => l.contains('날씨')), isFalse); // 날씨 기능은 뺐다
    });

    test('1~2분에 한 번', () {
      final rng = Random(1);
      for (var i = 0; i < 50; i++) {
        final g = ExpeditionTalkRules.nextGap(rng).inSeconds;
        expect(g, inInclusiveRange(60, 120));
      }
    });

    test('속성 색', () {
      expect(ExpeditionTalkRules.colorKey(null), 'gold');
      expect(ExpeditionTalkRules.colorKey(Element.water), 'sky');
      expect(ExpeditionTalkRules.colorKey(Element.fire), 'orange');
      expect(ExpeditionTalkRules.colorKey(Element.dark), 'purple');
    });
  });

  group('#97 감정 앨범', () {
    test('앨범 전 감정 기록은 종족마다 한 장씩 옮긴다', () {
      final s = LensState.fromJson({
        'seen': ['elf', 'starChild'],
        'counts': {'elf': 3, 'starChild': 1},
      });
      expect(s.album.length, 2);
      expect(s.album.first.firsts, ['elf']);
      expect(s.album.first.at, isNull);
      // 다시 저장·읽어도 그대로
      final again = LensState.fromJson(s.toJson());
      expect(again.album.map((p) => p.id), s.album.map((p) => p.id));
    });

    test('사진 파일을 붙여도 기록이 남는다', () {
      final p = AlbumPhoto(
          id: 'p1', races: const ['elf'], at: DateTime(2026, 11, 8));
      final j = p.withFile('p1.png').toJson();
      final back = AlbumPhoto.fromJson(j);
      expect(back.file, 'p1.png');
      expect(back.races, ['elf']);
    });
  });
}
