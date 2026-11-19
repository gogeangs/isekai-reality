import 'dart:async';

import 'package:flutter/material.dart' hide Element;
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../data/storage/record_store.dart' show HeroLook;
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import '../act5/erbard_screens.dart' show siegeLine;
import '../tutorial/feature_tour.dart' show TourScreenMark;
import '../profile/profile_screen.dart' show PortraitFace;
import 'chat_tour.dart';

/// 묶음 68 #275: 상태 화면 위 우편 버튼 옆 말풍선 (안 읽은 수 빨간 점). 로그인했을 때만
class ChatButton extends StatefulWidget {
  const ChatButton({super.key, required this.controller});
  final AppController controller;

  @override
  State<ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends State<ChatButton> {
  Timer? _t;
  bool _opening = false;
  AppController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _poll());
    _t = Timer.periodic(ChatRules.badgePoll, (_) => _poll());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    if (!mounted || !c.chatOpen) return;
    // 묶음 70 #291: 초대 링크로 들어왔으면 초대한 사람과 바로 친구
    final inviter = await c.claimInvite();
    if (inviter != null && mounted) {
      showTopNotice(context, '$inviter님과 친구가 됐어요', icon: Icons.people_rounded);
    }
    if (!mounted || !c.friendsOpen) return;
    await c.refreshChat(onNew: (line) {
      if (mounted && TickerMode.valuesOf(context).enabled) {
        showTopNotice(context, line, icon: Icons.chat_bubble_rounded, onTap: () => openChat(context, c));
      }
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (!c.chatOpen) return const SizedBox.shrink();
          // 묶음 70 #291: 초대 링크로 열렸으면 바로 친구 (레벨과 상관없이)
          if (c.pendingFriendCode != null && !_opening) {
            _opening = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await _poll();
              _opening = false;
            });
          }
          // 묶음 70: 친구는 Lv.8부터 (사람 모양) · 「세계」 말풍선은 Lv.11부터
          if (!c.friendsOpen) return const SizedBox.shrink();
          final world = c.worldOpen;
          final n = world ? (c.chatMe?.unread ?? 0) : (c.chatMe?.requests.length ?? 0);
          return GestureDetector(
            key: Key(world ? 'chatButton' : 'friendButton'),
            onTap: () => openChat(context, c, tab: world ? 0 : 1),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xCC14163A),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                // 묶음 72 #303: 우편 버튼처럼 그림 26 (없으면 글꼴 아이콘)
                child: Center(
                  child: Image.asset('assets/images/${world ? 'icon_chat' : 'icon_friends'}.webp',
                      width: 26,
                      height: 26,
                      errorBuilder: (_, __, ___) => Icon(world ? Icons.chat_bubble_rounded : Icons.people_alt_rounded,
                          color: AppColors.goldBright, size: 22)),
                ),
              ),
              if (n > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    key: const Key('chatUnread'),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(9)),
                    child: Text(n > 99 ? '99+' : '$n',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          );
        },
      );
}

/// 대화 입구 (말풍선 · 길드 회관 · 전황판)
Future<void> openChat(BuildContext context, AppController c, {String? room, int tab = 0}) async {
  if (!c.chatOpen) {
    showTopNotice(context, ChatRules.errorText('login_required'), icon: Icons.info_outline_rounded);
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatHubScreen(controller: c, tab: tab)));
  if (room != null && context.mounted) await openRoom(context, c, room);
}

/// 방 들어가기 (처음이면 대화 예절부터)
Future<void> openRoom(BuildContext context, AppController c, String room, {String? name}) async {
  if (c.chatMe == null) await c.refreshChat();
  if (!context.mounted) return;
  if (!(c.chatMe?.rulesSeen ?? false)) {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => EtiquetteScreen(controller: c)));
    if (ok != true || !context.mounted) return;
  }
  final info = c.chatMe?.room(room);
  await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChatRoomScreen(controller: c, room: room, name: name ?? info?.name ?? '대화', kind: info?.kind ?? _kindOf(room))));
}

String _kindOf(String room) => room == 'server'
    ? 'server'
    : room.startsWith('g_')
        ? 'guild'
        : room.startsWith('a_')
            ? 'alliance'
            : 'friend';

String _roomTitle(ChatRoomInfo r) => switch (r.kind) {
      'guild' => '길드 · ${r.name}',
      'alliance' => '연맹 · ${r.name}',
      'server' => ChatRules.worldTitle,
      _ => r.name,
    };

IconData _roomIcon(String kind) => switch (kind) {
      'guild' => Icons.shield_rounded,
      'alliance' => Icons.handshake_rounded,
      'server' => Icons.public_rounded,
      _ => Icons.person_rounded,
    };

/// 길드원 · 파티원 이름을 눌러 「친구 신청」
Future<void> askFriend(BuildContext context, AppController c, String uid, String name) async {
  if (c.chatMe?.friends.any((f) => f.uid == uid) ?? false) {
    showTopNotice(context, '$name님과 이미 친구예요', icon: Icons.people_rounded);
    return;
  }
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.night,
    builder: (s) => SafeArea(
      child: Padding(
        key: const Key('askFriendSheet'),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(name, style: AppText.title(18)),
          const SizedBox(height: 10),
          GoldButton(key: const Key('askFriendOk'), label: '친구 신청', height: 44, onPressed: () => Navigator.pop(s, true)),
        ]),
      ),
    ),
  );
  if (ok == true && context.mounted) await sendFriendAsk(context, c, uid, name);
}

Future<void> sendFriendAsk(BuildContext context, AppController c, String uid, String name) async {
  final ok = await c.addFriend(uid: uid);
  if (!context.mounted) return;
  showTopNotice(context, ok ? '$name님에게 친구 신청을 보냈어요' : ChatRules.errorText(c.chatError),
      icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);
}

const _sheetText = TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700);

// ───────────── 대화 예절

class EtiquetteScreen extends StatefulWidget {
  const EtiquetteScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<EtiquetteScreen> createState() => _EtiquetteScreenState();
}

class _EtiquetteScreenState extends State<EtiquetteScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      key: const Key('chatEtiquette'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListView(padding: EdgeInsets.fromLTRB(16, pad.top + 10, 16, pad.bottom + 20), children: [
          OrnateTopBar(title: '대화 예절', onBack: () => Navigator.of(context).pop(false)),
          const SizedBox(height: 10),
          OrnatePanel(
            ornament: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('함께 걷는 친구들과 기분 좋게 이야기해요', style: AppText.title(17)),
              const SizedBox(height: 10),
              for (final (i, l) in ChatRules.etiquette.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i + 1}', style: AppText.title(16, color: AppColors.goldBright)),
                    const SizedBox(width: 8),
                    Expanded(child: KText(l, style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.45))),
                  ]),
                ),
              const SizedBox(height: 4),
              const KText('규칙을 지키지 않으면 운영자가 대화를 막을 수 있어요 (1일 · 7일 · 영구).',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12.5, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 14),
          GoldButton(
            key: const Key('etiquetteOk'),
            label: '알겠어요',
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    final ok = await widget.controller.seeChatRules();
                    if (!context.mounted) return;
                    setState(() => _busy = false);
                    if (ok) {
                      Navigator.of(context).pop(true);
                    } else {
                      showTopNotice(context, ChatRules.errorText(widget.controller.chatError));
                    }
                  },
          ),
        ]),
      ),
    );
  }
}

// ───────────── 대화 · 친구 한눈에

class ChatHubScreen extends StatefulWidget {
  const ChatHubScreen({super.key, required this.controller, this.tab = 0});
  final AppController controller;
  final int tab;

  @override
  State<ChatHubScreen> createState() => _ChatHubScreenState();
}

class _ChatHubScreenState extends State<ChatHubScreen> {
  AppController get c => widget.controller;
  late int _tab = widget.tab;
  final _code = TextEditingController();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await c.refreshChat();
      final f = c.takeFriendCode();
      if (f != null && mounted) {
        setState(() {
          _tab = 1;
          _code.text = f;
        });
      }
    });
    _t = Timer.periodic(const Duration(seconds: 15), (_) => c.refreshChat());
  }

  @override
  void dispose() {
    _t?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _say(String t, {bool ok = true}) => showTopNotice(context, t, icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final world = c.worldOpen;
    if (!world) _tab = 1;
    return TourScreenMark(name: 'chatHub', child: Scaffold(
      key: const Key('chatHub'),
      backgroundColor: AppColors.deepNight,
      body: Stack(children: [Positioned.fill(child: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final me = c.chatMe;
            return ListView(padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24), children: [
              OrnateTopBar(
                title: world ? '대화' : '친구',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(height: 8),
              Row(children: [
                for (final (i, t) in ['대화방', '친구${(me?.requests.length ?? 0) > 0 ? ' · 신청 ${me!.requests.length}' : ''}'].indexed)
                  if (world || i == 1)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        key: Key('chatTab_$i'),
                        label: SizedBox(width: double.infinity, child: Text(t, textAlign: TextAlign.center)),
                        selected: _tab == i,
                        onSelected: (_) => setState(() => _tab = i),
                      ),
                    ),
                  ),
                IconButton(
                  key: const Key('chatSettings'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChatSettingsScreen(controller: c))),
                  icon: Image.asset('assets/images/icon_settings.webp',
                      width: 26,
                      height: 26,
                      errorBuilder: (_, __, ___) => const Icon(Icons.settings_rounded, color: AppColors.goldBright)),
                ),
              ]),
              const SizedBox(height: 8),
              if (me == null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                      child: c.chatError == null
                          ? const CircularProgressIndicator(color: AppColors.gold)
                          : Text(ChatRules.errorText(c.chatError), style: const TextStyle(color: AppColors.textMuted))),
                )
              else if (_tab == 0)
                ..._rooms(me)
              else
                ..._friends(me),
            ]);
          },
        ),
      )),
        // 묶음 70 #291: Lv.8 친구 장면 뒤 친구 화면 안내
        const Positioned.fill(child: FriendTourOverlay()),
      ]),
    ));
  }

  List<Widget> _rooms(ChatMe me) => [
        for (final r in me.rooms)
          GestureDetector(
            key: Key('chatRoom_${r.kind}_${r.room}'),
            onTap: () => openRoom(context, c, r.room, name: r.kind == 'friend' ? r.name : _roomTitle(r)),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: const Color(0xCC14163A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withValues(alpha: r.unread > 0 ? 0.8 : 0.35)),
              ),
              child: Row(children: [
                Icon(_roomIcon(r.kind), color: AppColors.goldBright, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_roomTitle(r), style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                    if (r.last != null)
                      Text(r.last!.system ? r.last!.text : '${r.last!.name}: ${r.last!.text}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
                  ]),
                ),
                if (r.unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFE5484D), borderRadius: BorderRadius.circular(10)),
                    child: Text('${r.unread}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
          ),
        if (me.rooms.length <= 1)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: KText('길드에 들어가거나 친구를 맺으면 대화방이 늘어나요.', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ),
      ];

  List<Widget> _friends(ChatMe me) => [
        OrnatePanel(
          key: const Key('friendCodePanel'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // 묶음 70 #291: 초대한 친구 · 보상 받음
            Text('초대한 친구 ${me.invited.clamp(0, me.inviteMax)}/${me.inviteMax} · 보상 받음 ${me.invitePaid}',
                key: const Key('inviteStat'),
                style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Row(children: [
              Text('내 친구 코드', style: AppText.title(15)),
              const Spacer(),
              Text(me.friendCode, key: const Key('myFriendCode'), style: AppText.title(18, color: AppColors.goldBright)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(
                child: FrameButton(
                  key: const Key('friendInviteCopy'),
                  label: '초대 링크 복사',
                  height: 38,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: ChatRules.friendInviteText(c.profile.name, me.friendCode)));
                    if (mounted) _say('초대 글을 복사했어요. 메신저에 붙여 보내 주세요');
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('friendCodeInput'),
                  controller: _code,
                  maxLength: 8,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(color: AppColors.text, letterSpacing: 2),
                  decoration: const InputDecoration(counterText: '', hintText: '친구 코드 8자리', isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const Key('friendAdd'),
                style: gameButtonStyle(gold: true),
                onPressed: () async {
                  final ok = await c.addFriend(code: _code.text);
                  if (!mounted) return;
                  if (ok) _code.clear();
                  ok ? _say('친구 신청을 보냈어요') : _say(ChatRules.errorText(c.chatError), ok: false);
                },
                child: const Text('친구 코드로 신청'),
              ),
            ]),
          ]),
        ),
        if (me.requests.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('받은 친구 신청', style: AppText.title(15)),
          for (final p in me.requests)
            _PersonRow(
              key: Key('friendReq_${p.uid}'),
              p: p,
              now: c.now,
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                TextButton(
                  key: Key('friendAccept_${p.uid}'),
                  style: gameButtonStyle(gold: true).copyWith(minimumSize: const WidgetStatePropertyAll(Size(56, 32))),
                  onPressed: () async {
                    final ok = await c.acceptFriend(p.uid);
                    if (mounted) ok ? _say('${p.name}님과 친구가 됐어요') : _say(ChatRules.errorText(c.chatError), ok: false);
                  },
                  child: const Text('수락'),
                ),
                TextButton(
                  key: Key('friendDecline_${p.uid}'),
                  onPressed: () => c.declineFriend(p.uid),
                  child: const Text('거절', style: TextStyle(color: AppColors.textMuted)),
                ),
              ]),
            ),
        ],
        const SizedBox(height: 10),
        Text('친구 ${me.friends.length} / ${ChatRules.maxFriends}', style: AppText.title(15)),
        if (me.friends.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: KText('아직 친구가 없어요. 친구 코드를 나누거나, 대화방 · 파티 · 길드에서 이름을 눌러 신청해 보세요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ),
        for (final p in me.friends)
          _PersonRow(
            key: Key('friend_${p.uid}'),
            p: p,
            now: c.now,
            onTap: () => _friendSheet(p),
            trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ),
      ];

  Future<void> _friendSheet(ChatPerson p) async {
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.night,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(p.name, style: AppText.title(17))),
          ListTile(key: const Key('friendDm'), leading: const Icon(Icons.chat_rounded, color: AppColors.goldBright), title: Text('1:1 대화', style: _sheetText), onTap: () => Navigator.pop(s, 'dm')),
          if (c.party?.id != null)
            ListTile(key: const Key('friendParty'), leading: const Icon(Icons.groups_rounded, color: AppColors.goldBright), title: Text('파티 초대 보내기', style: _sheetText), onTap: () => Navigator.pop(s, 'party')),
          ListTile(key: const Key('friendRemove'), leading: const Icon(Icons.person_remove_rounded, color: AppColors.textMuted), title: Text('친구 끊기', style: _sheetText), onTap: () => Navigator.pop(s, 'remove')),
          ListTile(key: const Key('friendBlock'), leading: const Icon(Icons.block_rounded, color: Color(0xFFFF8A80)), title: Text('차단', style: _sheetText), onTap: () => Navigator.pop(s, 'block')),
        ]),
      ),
    );
    if (!mounted || act == null || p.room == null) return;
    switch (act) {
      case 'dm':
        await openRoom(context, c, p.room!, name: p.name);
      case 'party':
        final ok = await c.inviteFriendToParty(p.room!);
        if (mounted) ok ? _say('${p.name}님에게 파티 초대를 보냈어요') : _say(ChatRules.errorText(c.chatError), ok: false);
      case 'remove':
        await c.removeFriend(p.uid);
      case 'block':
        await c.blockUser(p.uid);
        if (mounted) _say('${p.name}님을 차단했어요. 설정에서 풀 수 있어요');
    }
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({super.key, required this.p, required this.now, this.trailing, this.onTap});
  final ChatPerson p;
  final DateTime now;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: BoxDecoration(
            color: const Color(0xAA12142E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            ClipOval(
              child: SizedBox(
                  width: 40,
                  height: 40,
                  child: PortraitFace(
                      look: p.look == 'female' ? HeroLook.female : HeroLook.male,
                      fallback: const Icon(Icons.person_rounded, size: 36))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.name} · Lv.${p.level}', style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
                Text(
                    [
                      if (p.title.isNotEmpty) p.title,
                      if (p.guild.isNotEmpty) p.guild,
                      if (p.steps != null) '오늘 ${comma(p.steps!)}보',
                      if (p.lastSeen > 0) ChatRules.seenText(p.lastSeen, now),
                    ].join(' · '),
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
            if (trailing != null) trailing!,
          ]),
        ),
      );
}

// ───────────── 대화방

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key, required this.controller, required this.room, required this.name, required this.kind});
  final AppController controller;
  final String room, name, kind;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  AppController get c => widget.controller;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _t;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    c.chatOpenRoom = widget.room;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _t = Timer.periodic(ChatRules.roomPoll, (_) => c.readChat(widget.room));
  }

  Future<void> _load() async {
    // 공성전 줄(남은 시간 · 집결 영지)을 알려고
    if ((widget.kind == 'guild' || widget.kind == 'alliance') && c.act5Open) unawaited(c.refreshErbard());
    await c.readChat(widget.room);
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });

  @override
  void dispose() {
    _t?.cancel();
    c.chatOpenRoom = null;
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _say(String t, {bool ok = true}) => showTopNotice(context, t, icon: ok ? Icons.check_circle_rounded : Icons.info_outline_rounded);

  Future<void> _send(String text) async {
    if (_sending || text.trim().isEmpty) return;
    setState(() => _sending = true);
    final ok = await c.sendChat(widget.room, text.trim());
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _input.clear();
      _toBottom();
      if (widget.kind == 'server') chatHelloTick.value++;
    } else {
      _say(ChatRules.errorText(c.chatError), ok: false);
    }
  }

  Future<void> _lineSheet(ChatLine l) async {
    if (l.system || l.uid == null || l.uid == c.chatMe?.uid) return;
    final friend = c.chatMe?.friends.any((f) => f.uid == l.uid) ?? false;
    final act = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.night,
      builder: (s) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(l.name, style: AppText.title(16)), subtitle: Text(l.text, maxLines: 2, style: const TextStyle(color: AppColors.textMuted))),
          if (!friend && widget.kind != 'friend')
            ListTile(key: const Key('lineFriend'), leading: const Icon(Icons.person_add_rounded, color: AppColors.goldBright), title: Text('친구 신청', style: _sheetText), onTap: () => Navigator.pop(s, 'friend')),
          ListTile(key: const Key('lineReport'), leading: const Icon(Icons.flag_rounded, color: Color(0xFFFFB74D)), title: Text('신고', style: _sheetText), onTap: () => Navigator.pop(s, 'report')),
          ListTile(key: const Key('lineBlock'), leading: const Icon(Icons.block_rounded, color: Color(0xFFFF8A80)), title: Text('차단', style: _sheetText), onTap: () => Navigator.pop(s, 'block')),
        ]),
      ),
    );
    if (!mounted || act == null || l.uid == null) return;
    switch (act) {
      case 'friend':
        final ok = await c.addFriend(uid: l.uid);
        if (mounted) ok ? _say('${l.name}님에게 친구 신청을 보냈어요') : _say(ChatRules.errorText(c.chatError), ok: false);
      case 'block':
        await c.blockUser(l.uid!);
        if (mounted) _say('${l.name}님을 차단했어요. 이제 글이 보이지 않아요');
      case 'report':
        final reason = await showReportSheet(context);
        if (reason == null || !mounted) return;
        final ok = await c.reportChat(widget.room, l.id, reason);
        if (mounted) ok ? _say('신고했어요. 운영자가 확인할게요') : _say(ChatRules.errorText(c.chatError), ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return TourScreenMark(name: 'chatRoom', child: Scaffold(
      key: Key('chatRoom_${widget.room}'),
      backgroundColor: AppColors.deepNight,
      resizeToAvoidBottomInset: true,
      body: NightBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final lines = c.chatLines(widget.room);
            final me = c.chatMe;
            final siege = c.erbard.active && (widget.kind == 'guild' || widget.kind == 'alliance');
            final rally = c.erbard.rally == null ? null : ErbardRules.estate(c.erbard.rally!.estate)?.name;
            return Column(children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, 0),
                child: OrnateTopBar(title: widget.name, onBack: () => Navigator.of(context).maybePop()),
              ),
              // 공성전 중: 남은 시간 · 집결 영지 고정
              if (siege)
                Container(
                  key: const Key('chatSiegePin'),
                  margin: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x55E5484D),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF8A65)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.flag_rounded, color: Color(0xFFFF8A65), size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          '${siegeLine(c.erbard, c.now)}${rally != null ? ' · 집결 $rally' : ''}',
                          style: const TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: lines.length + (c.chatMore(widget.room) ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (c.chatMore(widget.room)) {
                      if (i == 0) {
                        return TextButton(
                          key: const Key('chatOlder'),
                          onPressed: () => c.readChat(widget.room, older: true),
                          child: const Text('이전 대화 더 보기'),
                        );
                      }
                      i -= 1;
                    }
                    final l = lines[i];
                    return _Bubble(
                      key: Key('chatLine_${l.id}'),
                      l: l,
                      mine: l.uid != null && l.uid == me?.uid,
                      onLong: () => _lineSheet(l),
                      onJoin: widget.kind == 'friend' && c.party?.id == null
                          ? (code) async {
                              final ok = await c.joinParty(code);
                              if (!mounted) return;
                              _say(ok ? '파티에 들어갔어요!' : PartyRules.errorText(c.partyError ?? ''), ok: ok);
                            }
                          : null,
                    );
                  },
                ),
              ),
              _bottom(me, pad),
            ]);
          },
        ),
      ),
    ));
  }

  Widget _bottom(ChatMe? me, EdgeInsets pad) {
    final muted = me?.mutedUntil;
    if (muted != null) {
      return Container(
        key: const Key('chatMuted'),
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 14, 16, pad.bottom + 14),
        color: const Color(0xEE0B0D26),
        child: Text(ChatRules.mutedLine(muted), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.w700)),
      );
    }
    if (widget.kind == 'server' && (me?.level ?? 1) < ChatRules.serverLevel) {
      return Container(
        key: const Key('chatLevelLock'),
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, 14, 16, pad.bottom + 14),
        color: const Color(0xEE0B0D26),
        child: Text(ChatRules.errorText('level'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
      );
    }
    final siege = c.erbard.active && (widget.kind == 'guild' || widget.kind == 'alliance');
    final rally = c.erbard.rally == null ? null : ErbardRules.estate(c.erbard.rally!.estate)?.name;
    final quick = [if (siege) ...ChatRules.siegeQuick(rally), ...ChatRules.quick];
    return Container(
      color: const Color(0xEE0B0D26),
      padding: EdgeInsets.fromLTRB(10, 6, 10, pad.bottom + 8),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 34,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final (i, q) in quick.indexed)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  key: Key('chatQuick_$i'),
                  backgroundColor: siege && i < ChatRules.siegeQuick(rally).length ? const Color(0xFF4A2230) : const Color(0xFF26295A),
                  side: BorderSide(color: siege && i < ChatRules.siegeQuick(rally).length ? const Color(0xFFFF8A65) : AppColors.gold.withValues(alpha: 0.5)),
                  label: Text(q, style: TextStyle(fontSize: 12.5, color: siege && i < ChatRules.siegeQuick(rally).length ? const Color(0xFFFFCCBC) : AppColors.text)),
                  onPressed: _sending ? null : () => _send(q),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('chatInput'),
              controller: _input,
              maxLength: ChatRules.maxLen,
              minLines: 1,
              maxLines: 3,
              style: const TextStyle(color: AppColors.text),
              decoration: const InputDecoration(counterText: '', hintText: '할 말 (100자까지)', isDense: true),
              onSubmitted: _send,
            ),
          ),
          IconButton(
            key: const Key('chatSend'),
            onPressed: _sending ? null : () => _send(_input.text),
            icon: const Icon(Icons.send_rounded, color: AppColors.goldBright),
          ),
        ]),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.l, required this.mine, required this.onLong, this.onJoin});
  final ChatLine l;
  final bool mine;
  final VoidCallback onLong;
  final void Function(String code)? onJoin;

  @override
  Widget build(BuildContext context) {
    if (l.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: const Color(0x55E9C46A), borderRadius: BorderRadius.circular(10)),
            child: KText(l.text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.goldBright, fontSize: 12)),
          ),
        ),
      );
    }
    final invite = ChatRules.partyInvite.firstMatch(l.text)?.group(1);
    final t = DateTime.fromMillisecondsSinceEpoch(l.at);
    final time = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: mine ? null : onLong,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          if (!mine)
            Text('${l.name}${l.title.isNotEmpty ? ' · ${l.title}' : ''} · Lv.${l.level}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w700)),
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (mine) Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
            if (mine) const SizedBox(width: 4),
            Flexible(
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: mine ? const Color(0xFFE9C46A) : const Color(0xFF26295A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(l.text, style: TextStyle(color: mine ? const Color(0xFF241A08) : AppColors.text, fontSize: 14)),
                  if (!mine && invite != null && onJoin != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: TextButton(
                        key: Key('chatJoinParty_${l.id}'),
                        style: gameButtonStyle(gold: true).copyWith(minimumSize: const WidgetStatePropertyAll(Size(80, 30))),
                        onPressed: () => onJoin!(invite),
                        child: const Text('파티 들어가기'),
                      ),
                    ),
                ]),
              ),
            ),
            if (!mine) const SizedBox(width: 4),
            if (!mine) Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}

/// 신고 사유 고르기
Future<String?> showReportSheet(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      builder: (s) => SafeArea(
        child: SingleChildScrollView(child: Column(key: const Key('reportSheet'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 6), child: Text('어떤 점이 불편했나요?', style: AppText.title(17))),
          for (final e in ChatRules.reasons.entries)
            ListTile(key: Key('reason_${e.key}'), dense: true, title: Text(e.value, style: _sheetText), onTap: () => Navigator.pop(s, e.key)),
          const SizedBox(height: 8),
        ])),
      ),
    );

// ───────────── 설정: 걸음 보여 주기 · 알림 · 차단 목록

class ChatSettingsScreen extends StatelessWidget {
  const ChatSettingsScreen({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final c = controller;
    return Scaffold(
      key: const Key('chatSettingsScreen'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final me = c.chatMe;
            if (me == null) return const SizedBox.shrink();
            Widget sw(String k, String label, bool v, ValueChanged<bool> on) =>
                SwitchListTile(key: Key(k), value: v, onChanged: on, title: Text(label, style: const TextStyle(color: AppColors.text, fontSize: 14)), activeThumbColor: AppColors.gold);
            return ListView(padding: EdgeInsets.fromLTRB(14, pad.top + 6, 14, pad.bottom + 24), children: [
              OrnateTopBar(title: '대화 설정', onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 8),
              OrnatePanel(
                child: Column(children: [
                  sw('setSteps', '친구에게 오늘 걸음 보여 주기', me.showSteps, (v) => c.chatSettings(showSteps: v)),
                  sw('setDm', '1:1 대화 알림', me.push['dm'] ?? true, (v) => c.chatSettings(push: {'dm': v})),
                  sw('setMention', '길드 대화에서 내 이름(@이름)이 불리면 알림', me.push['mention'] ?? true, (v) => c.chatSettings(push: {'mention': v})),
                  sw('setStaff', '공성전 중 길드장 · 부길드장 글 알림', me.push['staff'] ?? true, (v) => c.chatSettings(push: {'staff': v})),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: KText('밤 22시 ~ 아침 8시에는 알림을 보내지 않아요. 서버 · 연맹 대화방은 알림이 없어요.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Text('차단한 사람', style: AppText.title(15)),
              if (me.blocked.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 6), child: Text('차단한 사람이 없어요', style: TextStyle(color: AppColors.textMuted))),
              for (final b in me.blocked)
                ListTile(
                  key: Key('blocked_${b.uid}'),
                  title: Text(b.name, style: _sheetText),
                  trailing: TextButton(key: Key('unblock_${b.uid}'), onPressed: () => c.unblockUser(b.uid), child: const Text('풀기', style: TextStyle(color: AppColors.goldBright, fontWeight: FontWeight.w800))),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
