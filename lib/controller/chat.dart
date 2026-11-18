part of '../app_controller.dart';

/// 묶음 68 #275: 대화 한 줄
class ChatLine {
  const ChatLine({required this.id, this.uid, this.name = '', this.title = '', this.level = 0, required this.text, this.kind = 'user', required this.at});

  factory ChatLine.fromJson(Map<String, dynamic> j) => ChatLine(
        id: '${j['id']}',
        uid: j['uid'] as String?,
        name: '${j['name'] ?? ''}',
        title: '${j['title'] ?? ''}',
        level: (j['level'] as num?)?.toInt() ?? 0,
        text: '${j['text'] ?? ''}',
        kind: '${j['kind'] ?? 'user'}',
        at: (j['at'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String? uid;
  final String name, title;
  final int level;
  final String text;

  /// 'user' · 'sys'(길드 소식)
  final String kind;
  final int at;

  bool get system => kind == 'sys';
}

/// 친구 · 친구 신청 한 사람
class ChatPerson {
  const ChatPerson({required this.uid, required this.name, this.level = 1, this.title = '', this.look = '', this.guild = '', this.steps, this.lastSeen = 0, this.room});

  factory ChatPerson.fromJson(Map<String, dynamic> j) => ChatPerson(
        uid: '${j['uid']}',
        name: '${j['name'] ?? '각성자'}',
        level: (j['level'] as num?)?.toInt() ?? 1,
        title: '${j['title'] ?? ''}',
        look: '${j['look'] ?? ''}',
        guild: '${j['guild'] ?? ''}',
        steps: (j['steps'] as num?)?.toInt(),
        lastSeen: (j['lastSeen'] as num?)?.toInt() ?? 0,
        room: j['room'] as String?,
      );

  final String uid, name, title, look, guild;
  final int level;

  /// 오늘 걸음 (그 사람이 「걸음 보여 주기」를 껐으면 null)
  final int? steps;
  final int lastSeen;
  final String? room;
}

class ChatRoomInfo {
  const ChatRoomInfo({required this.room, required this.kind, required this.name, this.unread = 0, this.last});
  final String room;

  /// 'guild' · 'alliance' · 'server' · 'friend'
  final String kind;
  final String name;
  final int unread;
  final ChatLine? last;
}

class ChatMe {
  const ChatMe({
    this.uid = '',
    this.friendCode = '',
    this.showSteps = true,
    this.push = const {'dm': true, 'mention': true, 'staff': true},
    this.rulesSeen = false,
    this.mutedUntil,
    this.level = 1,
    this.friends = const [],
    this.requests = const [],
    this.blocked = const [],
    this.rooms = const [],
  });

  factory ChatMe.fromJson(Map<String, dynamic> j) => ChatMe(
        uid: '${j['uid'] ?? ''}',
        friendCode: '${j['friendCode'] ?? ''}',
        showSteps: j['showSteps'] != false,
        push: {for (final e in ((j['push'] as Map?) ?? const {}).entries) '${e.key}': e.value == true},
        rulesSeen: j['rulesSeen'] == true,
        mutedUntil: (j['mutedUntil'] as num?)?.toInt(),
        level: (j['level'] as num?)?.toInt() ?? 1,
        friends: [for (final x in (j['friends'] as List?) ?? const []) if (x is Map) ChatPerson.fromJson(Map<String, dynamic>.from(x))],
        requests: [for (final x in (j['requests'] as List?) ?? const []) if (x is Map) ChatPerson.fromJson(Map<String, dynamic>.from(x))],
        blocked: [
          for (final x in (j['blocked'] as List?) ?? const [])
            if (x is Map) (uid: '${x['uid']}', name: '${x['name'] ?? '각성자'}'),
        ],
        rooms: [
          for (final x in (j['rooms'] as List?) ?? const [])
            if (x is Map)
              ChatRoomInfo(
                room: '${x['room']}',
                kind: '${x['kind']}',
                name: '${x['name'] ?? ''}',
                unread: (x['unread'] as num?)?.toInt() ?? 0,
                last: x['last'] is Map ? ChatLine.fromJson({'id': '', ...Map<String, dynamic>.from(x['last'] as Map)}) : null,
              ),
        ],
      );

  final String uid;
  final String friendCode;
  final bool showSteps;
  final Map<String, bool> push;
  final bool rulesSeen;

  /// 대화 금지 끝 시각(ms) · -1 영구 · null 없음
  final int? mutedUntil;
  final int level;
  final List<ChatPerson> friends;
  final List<ChatPerson> requests;
  final List<({String uid, String name})> blocked;
  final List<ChatRoomInfo> rooms;

  int get unread => rooms.fold(0, (t, r) => t + r.unread) + requests.length;
  ChatRoomInfo? room(String id) => rooms.where((r) => r.room == id).firstOrNull;
  ChatRoomInfo? get guildRoom => rooms.where((r) => r.kind == 'guild').firstOrNull;
}

extension ChatOps on AppController {
  ChatMe? get chatMe => _chatMe;
  String? get chatError => _chatError;
  bool get chatOpen => _cloud.signedIn && arcaApi != null && cloudAuth != null;
  List<ChatLine> chatLines(String room) => _chatLines[room] ?? const [];
  bool chatMore(String room) => _chatMoreRooms.contains(room);

  Future<Map<String, dynamic>?> _chatCall(String path, [Map<String, dynamic> body = const {}]) async {
    final api = arcaApi, a = cloudAuth;
    if (api == null || a == null || !_cloud.signedIn) {
      _chatError = 'login_required';
      return null;
    }
    try {
      final token = await a.idToken();
      if (token == null) throw const ArcaApiError('login_required');
      final j = await api.post(path, {
        ...body,
        'me': {
          'name': _profile.name,
          'level': player.level.level,
          'title': equippedTitle == null ? '' : TitleRules.info(equippedTitle!).name,
          'look': _profile.look.name,
          ...await _socialSteps(),
          'device': await deviceId(),
        },
      }, token: token);
      _chatError = null;
      return j;
    } on ArcaApiError catch (e) {
      _chatError = e.code;
      return null;
    } catch (_) {
      _chatError = 'offline';
      return null;
    }
  }

  /// 내 대화 · 친구 · 방 목록 (안 읽은 수). 새로 온 1:1 · 내 이름이 불린 줄은 [onNew] 로 알림
  Future<bool> refreshChat({void Function(String line)? onNew}) async {
    final j = await _chatCall('/chat/me');
    if (j == null) {
      _notify();
      return false;
    }
    final before = _chatMe;
    _chatMe = ChatMe.fromJson(j);
    if (before != null && onNew != null) {
      for (final r in _chatMe!.rooms) {
        final old = before.room(r.room);
        final l = r.last;
        if (l == null || l.kind == 'sys' || r.unread <= (old?.unread ?? 0) || r.room == _chatOpenRoom) continue;
        final mention = r.kind == 'guild' && l.text.contains('@${_profile.name}');
        if ((r.kind == 'friend' && (_chatMe!.push['dm'] ?? true)) || (mention && (_chatMe!.push['mention'] ?? true))) {
          onNew('${l.name}: ${l.text}');
        }
      }
    }
    _notify();
    return true;
  }

  /// 지금 보고 있는 방 (그 방 새 줄은 알림을 띄우지 않음)
  set chatOpenRoom(String? room) => _chatOpenRoom = room;

  /// 방 읽기: 처음 · 새 줄(after) · 더 불러오기(before)
  Future<bool> readChat(String room, {bool older = false}) async {
    final cur = _chatLines[room] ?? const <ChatLine>[];
    final j = await _chatCall('/chat/read', {
      'room': room,
      if (!older && cur.isNotEmpty) 'after': cur.last.at,
      if (older && cur.isNotEmpty) 'before': cur.first.at,
    });
    if (j == null) {
      _notify();
      return false;
    }
    final got = [for (final x in (j['lines'] as List?) ?? const []) if (x is Map) ChatLine.fromJson(Map<String, dynamic>.from(x))];
    final seen = {for (final l in cur) l.id};
    final fresh = [for (final l in got) if (!seen.contains(l.id)) l];
    _chatLines[room] = older ? [...fresh, ...cur] : [...cur, ...fresh];
    if (older || cur.isEmpty) {
      j['more'] == true ? _chatMoreRooms.add(room) : _chatMoreRooms.remove(room);
    }
    // 읽었으니 빨간 점 줄이기
    final me = _chatMe;
    if (me != null) {
      _chatMe = ChatMe(
        uid: me.uid,
        friendCode: me.friendCode,
        showSteps: me.showSteps,
        push: me.push,
        rulesSeen: me.rulesSeen,
        mutedUntil: me.mutedUntil,
        level: me.level,
        friends: me.friends,
        requests: me.requests,
        blocked: me.blocked,
        rooms: [
          for (final r in me.rooms) r.room == room ? ChatRoomInfo(room: r.room, kind: r.kind, name: r.name, last: r.last) : r,
        ],
      );
    }
    _notify();
    return true;
  }

  Future<bool> sendChat(String room, String text) async {
    final j = await _chatCall('/chat/send', {'room': room, 'text': text});
    if (j == null) {
      _notify();
      return false;
    }
    await readChat(room);
    return true;
  }

  Future<bool> seeChatRules() async {
    final ok = await _chatCall('/chat/rules') != null;
    if (ok) await refreshChat();
    return ok;
  }

  Future<bool> chatSettings({bool? showSteps, Map<String, bool>? push}) async {
    final ok = await _chatCall('/chat/settings', {if (showSteps != null) 'showSteps': showSteps, if (push != null) 'push': push}) != null;
    if (ok) await refreshChat();
    return ok;
  }

  Future<bool> _chatDo(String path, Map<String, dynamic> body) async {
    final ok = await _chatCall(path, body) != null;
    await refreshChat();
    return ok;
  }

  /// 친구 신청: 친구 코드 또는 그 사람 계정(대화방 · 파티 · 길드에서 이름을 눌러)
  Future<bool> addFriend({String? code, String? uid}) =>
      _chatDo('/chat/friend/add', {if (code != null) 'code': code.trim().toUpperCase(), if (uid != null) 'to': uid});
  Future<bool> acceptFriend(String from) => _chatDo('/chat/friend/accept', {'from': from});
  Future<bool> declineFriend(String from) => _chatDo('/chat/friend/decline', {'from': from});
  Future<bool> removeFriend(String uid) => _chatDo('/chat/friend/remove', {'to': uid});

  Future<bool> blockUser(String uid) async {
    final ok = await _chatDo('/chat/block', {'to': uid});
    if (ok) {
      for (final k in [..._chatLines.keys]) {
        _chatLines[k] = [for (final l in _chatLines[k]!) if (l.uid != uid) l];
      }
      _notify();
    }
    return ok;
  }

  Future<bool> unblockUser(String uid) => _chatDo('/chat/unblock', {'to': uid});

  Future<bool> reportChat(String room, String id, String reason) async =>
      await _chatCall('/chat/report', {'room': room, 'id': id, 'reason': reason}) != null;

  /// 1:1 에서 파티 초대 (지금 파티 코드를 한 줄로)
  Future<bool> inviteFriendToParty(String room) async {
    final p = party;
    if (p == null || p.id == null || p.code.isEmpty) return false;
    return sendChat(room, ChatRules.partyInviteLine(p.name, p.code));
  }

  /// 친구 초대 링크로 앱이 열렸을 때
  String? get pendingFriendCode => _pendingFriendCode;
  String? takeFriendCode() {
    final c = _pendingFriendCode;
    _pendingFriendCode = null;
    return c;
  }
}
