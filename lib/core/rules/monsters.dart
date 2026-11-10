/// 몬스터 (11-10 '정화' → '사냥'으로 바꿈).
///
/// 몬스터는 사냥하면 쓰러지고 사라진다. 정화된 모습·이름은 쓰지 않는다.
/// 정령은 각성자의 동료 전용이라 정령계 몬스터(물방울 정령·돌정령)는 뺐다.
/// 예전 기록을 읽으려고 id 는 남겨 두고 [MonsterInfo.retired] 로 숨긴다.
enum MonsterId {
  ashSlime,
  labyrinthBat,
  roughWaterSpirit,
  shadowButterfly,
  lostStoneSpirit,
  labyrinthWarden,
  giantRat,
}

class MonsterInfo {
  const MonsterInfo({
    required this.id,
    required this.name,
    required this.habitat,
    required this.huntLine,
    this.isBoss = false,
    this.retired = false,
  });

  final MonsterId id;
  final String name;

  /// 나오는 곳 (설명용)
  final String habitat;

  /// 사냥했을 때 정령 대사
  final String huntLine;
  final bool isBoss;

  /// 더 나오지 않는 몬스터 (예전 기록에만 남음, 도감에서 숨김)
  final bool retired;

  /// 그림 파일. 없으면 화면에서 아이콘으로 대신 그린다.
  String get asset => 'assets/images/monster_${id.name}.png';
}

class Monsters {
  Monsters._();

  /// 지금 나오는 몬스터 (도감 순서)
  static List<MonsterInfo> get all =>
      [for (final m in _all) if (!m.retired) m];

  static const List<MonsterInfo> _all = [
    MonsterInfo(
      id: MonsterId.ashSlime,
      name: '슬라임',
      habitat: '어디서나',
      huntLine: '슬라임을 잡았어! 말랑한 젤리가 남았네.',
    ),
    MonsterInfo(
      id: MonsterId.giantRat,
      name: '큰쥐',
      habitat: '어디서나',
      huntLine: '큰쥐를 잡았어! 가죽은 장비 만들 때 쓸 수 있어.',
    ),
    MonsterInfo(
      id: MonsterId.labyrinthBat,
      name: '미궁 박쥐',
      habitat: '던전',
      huntLine: '박쥐를 쫓아냈어! 날개를 하나 주웠어.',
    ),
    MonsterInfo(
      id: MonsterId.shadowButterfly,
      name: '그림자 나비',
      habitat: '밤 (오후 7시 ~ 새벽 5시) 어디서나',
      huntLine: '그림자 나비를 잡았어! 반짝이는 가루가 떨어졌어.',
    ),
    MonsterInfo(
      id: MonsterId.labyrinthWarden,
      name: '미궁 문지기',
      habitat: '던전 마지막 층',
      huntLine: '문지기를 쓰러뜨렸어! 던전을 끝까지 돌파했어!',
      isBoss: true,
    ),
    MonsterInfo(
      id: MonsterId.roughWaterSpirit,
      name: '물방울 정령',
      habitat: '(더 나오지 않음)',
      huntLine: '',
      retired: true,
    ),
    MonsterInfo(
      id: MonsterId.lostStoneSpirit,
      name: '돌정령',
      habitat: '(더 나오지 않음)',
      huntLine: '',
      retired: true,
    ),
  ];

  static MonsterInfo info(MonsterId id) => _all.firstWhere((m) => m.id == id);

  static MonsterId? byName(String name) {
    for (final id in MonsterId.values) {
      if (id.name == name) return id;
    }
    return null;
  }
}
