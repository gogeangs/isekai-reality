/// 우편 규칙 (11-11 #65, 제안서 4 확정)
class MailRules {
  MailRules._();

  /// 보상 우편 보관 기간
  static const Duration rewardKeep = Duration(days: 30);

  /// 마을 사람 (이름 확정)
  static const String hart = '하르트'; // 의뢰 게시판 주인
  static const String mina = '미나'; // 잡화상
  static const String dorgun = '도르군'; // 대장장이
  static const String eliel = '엘리엘'; // 연금술사
  static const String operator = '여명의 탑 운영실';

  /// 남은 날 (0이면 오늘 사라진다)
  static int daysLeft(DateTime expiresAt, DateTime now) {
    final d = expiresAt.difference(now);
    return d.isNegative ? 0 : d.inDays;
  }
}

/// 마을 사람 편지 하나 (조건이 되면 한 번 보낸다)
class NpcLetter {
  const NpcLetter(this.id, this.from, this.title, this.body, {this.gifts = const {}});

  final String id;
  final String from;
  final String title;
  final String body;
  final Map<String, int> gifts;

  /// 의뢰 감사 (수시·긴급 의뢰를 끝낸 수)
  static const errandThanks = <int, NpcLetter>{
    10: NpcLetter('npc_errand10', MailRules.hart, '의뢰 열 건, 고맙네',
        '게시판에 붙은 의뢰를 벌써 열 건이나 해냈군. 마을 사람들이 자네 이야기를 하더라고. '
            '작지만 물약 하나 넣어 보내네.',
        gifts: {'item:healSmall': 2}),
    30: NpcLetter('npc_errand30', MailRules.hart, '든든한 각성자에게',
        '서른 건째야. 이제 게시판 앞에 자네 이름을 적어 둘까 싶네. 앞으로도 잘 부탁하네.'),
    50: NpcLetter('npc_errand50', MailRules.hart, '마을의 자랑',
        '쉰 건! 이 마을에서 자네만큼 의뢰를 끝낸 사람은 없을 거야. 다음 의뢰도 기다리겠네.'),
    100: NpcLetter('npc_errand100', MailRules.hart, '백 번째 의뢰',
        '백 건이라니, 믿기지 않는군. 마을이 모은 작은 감사의 마음이야. 받아 주게.',
        gifts: {'manaStone': 10}),
  };

  static const minaThanks = NpcLetter('npc_mina10', MailRules.mina, '단골 손님께',
      '잡화상에 열 번이나 들러 줘서 고마워요! 요즘 물약이 잘 팔려서 기뻐요. 또 와요!');

  static const minaRumor = NpcLetter('npc_mina_lv3', MailRules.mina, '소문 하나',
      '이제 Lv.3이 되었다면서요? 우리 가게에서 더 좋은 회복 물약과 마나 물약을 살 수 있어요.');

  static const dorgunFirst = NpcLetter('npc_dorgun1', MailRules.dorgun, '첫 장비 축하하네',
      '자네가 처음 만든 장비를 봤네. 손이 제법이더군. 쇠붙이 몇 개 넣어 보내니 다음에도 써 보게.',
      gifts: {'ironShard': 3});

  static const elielFirst = NpcLetter('npc_eliel1', MailRules.eliel, '가마솥이 따뜻하네요',
      '처음으로 물약을 끓였다고 들었어요. 순서를 잘 맞추면 「완벽한 조제」가 나온답니다. 비밀이에요.');

  static const hartUrgent = NpcLetter('npc_hart_urgent', MailRules.hart, '긴급 의뢰 소문',
      '가끔 게시판에 긴급 의뢰가 붙는다네. 몇 시간 안에 끝내면 열쇠나 귀한 재료를 주지. 눈여겨보게.');
}
