/// 묶음 68 #275 대화 · 친구 (로그인한 사람만). 판정은 서버(chat.js)가 기준이고, 앱은 같은 숫자로 먼저 안내만 한다.
class ChatRules {
  ChatRules._();

  static const int maxLen = 100;
  /// 묶음 70 #292: 「세계」 · 친구 1:1 (읽기 · 쓰기)
  static const int serverLevel = 11;

  /// 묶음 70 #291: 친구 (목록 · 신청 · 초대 링크 · 코드 · 초대 보상)
  static const int friendLevel = 8;

  /// 초대받은 친구가 이 레벨이 되면 둘 다 우편
  static const int inviteLevel = 5;
  static const int inviteMax = 5;
  static const int inviteTitleN = 3;

  static const String worldTitle = '세계 · 모든 각성자';
  static const Duration gap = Duration(seconds: 10);
  static const int maxFriends = 50;

  /// 대화방이 열려 있을 때 새 줄을 묻는 간격 · 입구 빨간 점을 묻는 간격
  static const Duration roomPoll = Duration(seconds: 4);
  static const Duration badgePoll = Duration(seconds: 60);

  /// 빠른 말 (공통)
  static const List<String> quick = ['안녕하세요!', '고마워요!', '같이 사냥해요', '잠깐 걷고 올게요', '좋아요!', '수고했어요'];

  /// 빠른 말 (공성전 — 길드 · 연맹 방에서만)
  static List<String> siegeQuick(String? rallyName) => [
        if (rallyName != null) '$rallyName에 집결!',
        '망치 써 주세요',
        '성벽 보수 부탁해요',
        '마지막 6시간, 힘내요!',
      ];

  static const Map<String, String> reasons = {
    'abuse': '욕설',
    'bully': '괴롭힘',
    'sexual': '음란',
    'ad': '광고',
    'privacy': '개인정보 요구',
    'etc': '기타',
  };

  /// 처음 대화방에 들어갈 때 대화 예절
  static const List<String> etiquette = [
    '욕설 · 놀림 · 괴롭히는 말은 하지 않아요.',
    '전화번호 · 주소 · 학교 · 메신저 아이디 같은 개인정보는 묻지도 알려 주지도 않아요. (자동으로 가려져요)',
    '밖에서 만나자는 말에는 응하지 말고, 바로 신고해 주세요.',
    '불편한 말을 보면 말풍선을 길게 눌러 「신고」하거나 「차단」해요. 운영자가 확인해요.',
  ];

  static String errorText(String? code) => switch (code) {
        'login_required' => '대화는 로그인한 뒤에 할 수 있어요',
        'offline' => '대화를 불러오지 못했어요. 인터넷을 확인해 주세요',
        'empty' => '할 말을 적어 주세요',
        'too_long' => '한 번에 $maxLen자까지 쓸 수 있어요',
        'too_fast' => '조금 천천히! 10초에 한 번 말할 수 있어요',
        'rest' => '같은 말을 여러 번 했어요. 1분 쉬었다가 다시 말해 주세요',
        'level' => '세계는 Lv.$serverLevel부터 함께할 수 있어요',
        'friend_level' => '친구는 Lv.$friendLevel부터 사귈 수 있어요',
        'muted' => '지금은 대화할 수 없어요',
        'rules_first' => '대화 예절을 먼저 읽어 주세요',
        'no_room' => '이 대화방에 들어갈 수 없어요',
        'restricted' => '지금은 함께하는 기능을 쓸 수 없어요',
        'app_check' => '앱을 최신으로 바꾼 뒤 다시 해 주세요',
        'no_user' => '그 친구 코드를 찾지 못했어요',
        'self' => '내 친구 코드예요',
        'already' => '이미 친구예요',
        'blocked' => '친구 신청을 보낼 수 없어요',
        'full' => '친구는 $maxFriends명까지예요',
        'no_request' => '친구 신청이 없어요',
        'bad_reason' => '신고 사유를 골라 주세요',
        _ => '잠시 뒤 다시 해 주세요',
      };

  /// 「○일 ○시까지 대화할 수 없어요」 ([until] 이 -1 이면 영구)
  static String mutedLine(int until) {
    if (until < 0) return '대화할 수 없어요 (운영정책)';
    final t = DateTime.fromMillisecondsSinceEpoch(until);
    return '${t.month}월 ${t.day}일 ${t.hour}시까지 대화할 수 없어요';
  }

  /// 최근 접속: 「오늘」 · 「어제」 · 「○일 전」
  static String seenText(int lastSeen, DateTime now) {
    if (lastSeen <= 0) return '';
    final t = DateTime.fromMillisecondsSinceEpoch(lastSeen);
    final d = DateTime(now.year, now.month, now.day).difference(DateTime(t.year, t.month, t.day)).inDays;
    return d <= 0 ? '오늘' : d == 1 ? '어제' : '$d일 전';
  }

  // ───────────── 친구 초대 링크 (파티 링크와 같은 Universal Links)

  static const linkHost = 'api-ujbfnvvalq-du.a.run.app';
  static String friendLink(String code) => 'https://$linkHost/join/f/$code';
  static String friendInviteText(String name, String code) =>
      '아르카에서 친구 해요! ${friendLink(code)} 를 누르거나, 말풍선 → 친구 → 「친구 코드로 신청」에 $code 를 넣어 주세요. — $name';

  static String? friendCodeFromLink(Uri u) {
    final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
    String? c;
    if (u.scheme == 'arca' && u.host == 'join' && segs.length == 2 && segs.first == 'f') c = segs[1];
    if (segs.length == 3 && segs[0] == 'join' && segs[1] == 'f' && (u.host == linkHost || u.scheme == 'arca')) c = segs[2];
    c = c?.toUpperCase();
    return c != null && RegExp(r'^[A-Z0-9]{8}$').hasMatch(c) ? c : null;
  }

  /// 1:1 에서 보내는 파티 초대 줄 (링크는 가려지므로 코드만)
  static String partyInviteLine(String name, String code) => '파티 「$name」에 초대할게요! 초대 코드 $code';
  static final RegExp partyInvite = RegExp(r'초대 코드 ([A-Z2-9]{6})$');
}
