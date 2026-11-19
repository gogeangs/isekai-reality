import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/models/vitals.dart';
import 'package:isekai_reality/core/rules/rules.dart';
import 'package:isekai_reality/data/health/health_source.dart';
import 'package:isekai_reality/data/location/location_source.dart';
import 'package:isekai_reality/data/storage/record_store.dart';
import 'package:isekai_reality/features/battle/hero_rig.dart';
import 'package:isekai_reality/features/map/korea_area.dart';

void main() {
  group('#102 레벨 업 회복', () {
    test('HP·MP 가득, 채우기 전 값을 돌려준다', () async {
      final store =
          InMemoryRecordStore(profile: const PlayerProfile(name: '하루'));
      await store.saveVitals(const Vitals(hp: 5, mp: 1));
      final now = DateTime(2026, 11, 12, 10);
      final c = AppController(
        area: KoreaArea.area,
        store: store,
        health: FakeHealthSource(stepsByDay: const {}),
        location: FakeLocationSource(),
        clock: () => now,
      )..mailSources = const [];
      await c.init();
      expect(c.hp, lessThan(c.maxHp));
      final before = await c.levelUpHeal();
      expect(before.hp, 5);
      expect(c.hp, c.maxHp);
      expect(c.mp, c.mpMax);
      expect(c.tired, isFalse);
    });
  });

  group('A3 장소에 맞는 속성', () {
    test('장소별 속성 묶음, 마을은 고르게', () {
      expect(FieldMonsterRules.landElements(LandKind.water),
          {Element.water, Element.ice});
      expect(FieldMonsterRules.landElements(LandKind.city),
          contains(Element.thunder));
      expect(FieldMonsterRules.landElements(LandKind.village), isEmpty);
      expect(FieldMonsterRules.landElements(null), isEmpty);
    });

    test('장소·약점 가중은 곱하지 않는다', () {
      int count(Set<Element> fav, Set<Element> land) {
        var n = 0;
        for (var i = 0; i < 400; i++) {
          final m = FieldMonsterRules.pickCommon(i / 400, (i * 37 % 400) / 400,
              favored: fav, landFavored: land);
          if (Monsters.info(m).element == Element.water) n++;
        }
        return n;
      }

      final base = count(const {}, const {});
      final land = count(const {}, const {Element.water});
      final both = count(const {Element.water}, const {Element.water});
      final fav = count(const {Element.water}, const {});
      expect(land, greaterThanOrEqualTo(base));
      expect(both, fav > land ? fav : land);
    });
  });

  group('A4 계절', () {
    test('국내 계절', () {
      expect(SeasonRules.of(DateTime(2026, 3, 1)), Season.spring);
      expect(SeasonRules.of(DateTime(2026, 8, 31)), Season.summer);
      expect(SeasonRules.of(DateTime(2026, 11, 12)), Season.autumn);
      expect(SeasonRules.of(DateTime(2027, 2, 1)), Season.winter);
      expect(SeasonRules.of(DateTime(2026, 12, 1)), Season.winter);
    });
  });

  group('무기 종류 (묶음 73: 부위 애니메이션은 통 그림으로)', () {
    test('장비 → 무기 종류 (보스 무기는 가까운 종류, 무기 아니면 맨손)', () {
      expect(weaponKindOf(EquipBase.dagger), WeaponKind.dagger);
      expect(weaponKindOf(EquipBase.hornDagger), WeaponKind.dagger);
      expect(weaponKindOf(EquipBase.staff), WeaponKind.staff);
      expect(weaponKindOf(EquipBase.groveWeapon), WeaponKind.axe);
      expect(weaponKindOf(EquipBase.stormWeapon), WeaponKind.spear);
      expect(weaponKindOf(EquipBase.wardenWeapon), WeaponKind.sword);
      expect(weaponKindOf(EquipBase.armor), isNull);
      expect(weaponKindOf(null), isNull);
    });
  });
}
