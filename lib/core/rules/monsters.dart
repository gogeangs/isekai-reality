/// 고잔동 몬스터 6종 (기획 '몬스터 정화' 후보).
///
/// 몬스터는 악당이 아니라 잿빛에 물든 존재다. 쓰러뜨리면 '정화'되어
/// 원래 모습으로 돌아간다.
enum MonsterId {
  ashSlime,
  labyrinthBat,
  roughWaterSpirit,
  shadowButterfly,
  lostStoneSpirit,
  labyrinthWarden,
}

class MonsterInfo {
  const MonsterInfo({
    required this.id,
    required this.name,
    required this.purifiedName,
    required this.habitat,
    required this.purifiedLine,
    this.isBoss = false,
  });

  final MonsterId id;

  /// 잿빛에 물든 이름
  final String name;

  /// 정화된 뒤 이름 (도감에 이 이름으로 남는다)
  final String purifiedName;

  /// 나오는 곳 (설명용)
  final String habitat;

  /// 정화했을 때 불씨 대사
  final String purifiedLine;
  final bool isBoss;

  /// 그림 파일. 없으면 화면에서 아이콘으로 대신 그린다.
  String get asset => 'assets/images/monster_${id.name}.png';

  /// 정화된 모습 그림
  String get purifiedAsset => 'assets/images/monster_${id.name}_purified.png';
}

class Monsters {
  Monsters._();

  static const List<MonsterInfo> all = [
    MonsterInfo(
      id: MonsterId.ashSlime,
      name: '잿빛 슬라임',
      purifiedName: '이슬 슬라임',
      habitat: '어디서나',
      purifiedLine: '말랑말랑 투명해졌다! 원래는 아침 이슬이었구나.',
    ),
    MonsterInfo(
      id: MonsterId.labyrinthBat,
      name: '미궁 박쥐',
      purifiedName: '별빛 박쥐',
      habitat: '미궁 입구 (중앙역·고잔역)',
      purifiedLine: '날개에 별빛이 돌아왔어. 이제 길을 비춰 줄 거야.',
    ),
    MonsterInfo(
      id: MonsterId.roughWaterSpirit,
      name: '거칠어진 물방울 정령',
      purifiedName: '맑은 물방울 정령',
      habitat: '정령의 호수 (호수공원)',
      purifiedLine: '물결이 잔잔해졌어. 호수가 고맙대!',
    ),
    MonsterInfo(
      id: MonsterId.shadowButterfly,
      name: '그림자 나비',
      purifiedName: '노을 나비',
      habitat: '음유시인의 극장 (밤)',
      purifiedLine: '노을빛 날개다… 노래에 맞춰 춤추던 아이였나 봐.',
    ),
    MonsterInfo(
      id: MonsterId.lostStoneSpirit,
      name: '길 잃은 돌정령',
      purifiedName: '길 찾은 돌정령',
      habitat: '공원·광장',
      purifiedLine: '집으로 가는 길이 생각났대. 데굴데굴 굴러가네!',
    ),
    MonsterInfo(
      id: MonsterId.labyrinthWarden,
      name: '미궁 문지기',
      purifiedName: '미궁 수호자',
      habitat: '던전 마지막 층',
      purifiedLine: '문지기가 원래 모습을 찾았어! 이제 미궁을 지켜 줄 거야.',
      isBoss: true,
    ),
  ];

  static MonsterInfo info(MonsterId id) => all.firstWhere((m) => m.id == id);

  static MonsterId? byName(String name) {
    for (final id in MonsterId.values) {
      if (id.name == name) return id;
    }
    return null;
  }
}
