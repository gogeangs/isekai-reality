import 'dart:math';

import 'materials.dart';

/// 마법 돋보기 「감정」으로 드러나는 종족 (11-11 #60). 이름은 저장되므로 바꾸지 않는다.
enum Race { elf, dwarf, fairy, dragonkin, catfolk, foxfolk, mermaid, starChild }

class RaceInfo {
  const RaceInfo(this.id, this.name, this.line, this.material, this.color);

  final Race id;
  final String name;

  /// 감정 결과 한 줄
  final String line;

  /// 감정 보상으로 나오는 재료
  final MaterialId material;

  /// 이름표·장식 색 (ARGB)
  final int color;

  /// 필터 장식 그림 (없으면 그려서 보여 준다)
  String get asset => 'assets/images/filter_${id.name}.png';
}

/// 마법 돋보기 규칙
class LensRules {
  LensRules._();

  /// 잡화상 값과 하루 개수
  static const int price = 40;
  static const int perDay = 3;

  /// 종족을 처음 감정하면 앨범에 「처음 만난 종족!」으로 남고 경험치
  static const int firstExp = 20;

  /// 보상을 받는 감정 횟수 (하루)
  static const int rewardedPerDay = 3;
  static const double materialChance = 0.30;
  static const double noteChance = 0.05;

  /// 감정 연출 시간
  static const Duration appraiseTime = Duration(milliseconds: 2200);

  /// 한 사진에서 감정하는 얼굴 수
  static const int maxFaces = 5;

  static const List<RaceInfo> all = [
    RaceInfo(Race.elf, '엘프', '숲의 숨결이 느껴져요. 오래 사는 숲의 종족!',
        MaterialId.herb, 0xFF7FD48B),
    RaceInfo(Race.dwarf, '드워프', '불과 쇠를 다루는 손. 산속 대장장이의 피!',
        MaterialId.ironShard, 0xFFC98A4B),
    RaceInfo(Race.fairy, '요정', '반짝이는 가루가 흩날려요. 꽃 사이를 나는 요정!',
        MaterialId.butterflyDust, 0xFFF3A6E0),
    RaceInfo(Race.dragonkin, '용인', '눈동자에 불꽃이 일렁여요. 용의 피를 이은 자!',
        MaterialId.fireJelly, 0xFFE05A47),
    RaceInfo(Race.catfolk, '고양이 수인', '나른하지만 날렵해요. 밤을 걷는 고양이 수인!',
        MaterialId.sleepPowder, 0xFFF0C46A),
    RaceInfo(Race.foxfolk, '여우 수인', '영리한 눈빛. 꼬리 아홉을 꿈꾸는 여우 수인!',
        MaterialId.glossyFur, 0xFFF08A3C),
    RaceInfo(Race.mermaid, '인어', '파도 소리가 들려요. 깊은 바다의 노래꾼!',
        MaterialId.waterJelly, 0xFF5CC8E0),
    RaceInfo(Race.starChild, '별의 아이', '아주 드문 빛! 여명의 탑이 기다린 별의 아이!',
        MaterialId.lightJelly, 0xFFFFE27A),
  ];

  static RaceInfo info(Race r) => all.firstWhere((i) => i.id == r);

  static Race? parse(String name) {
    for (final r in Race.values) {
      if (r.name == name) return r;
    }
    return null;
  }

  /// 얼굴마다 종족을 고른다. 별의 아이는 드물다 (다른 종족의 절반).
  static Race roll(Random rng) {
    const weights = {
      Race.elf: 2,
      Race.dwarf: 2,
      Race.fairy: 2,
      Race.dragonkin: 2,
      Race.catfolk: 2,
      Race.foxfolk: 2,
      Race.mermaid: 2,
      Race.starChild: 1,
    };
    final total = weights.values.fold(0, (a, b) => a + b);
    var x = rng.nextInt(total);
    for (final e in weights.entries) {
      if (x < e.value) return e.key;
      x -= e.value;
    }
    return Race.elf;
  }

  /// [faces] 명을 감정한다. 한 사진 안에서는 되도록 서로 다른 종족.
  static List<Race> rollFaces(Random rng, int faces) {
    final out = <Race>[];
    for (var i = 0; i < faces; i++) {
      var r = roll(rng);
      for (var t = 0; t < 4 && out.contains(r); t++) {
        r = roll(rng);
      }
      out.add(r);
    }
    return out;
  }
}
