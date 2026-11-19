import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../pets/pet_art.dart';
import '../tutorial/feature_tour.dart' show HoleSpotlight, rectOfKey, tourBridge, GoldButtonLite, FeatureTourLayer;

/// 묶음 70 #292: 「세계」 방에서 글을 보냈을 때 (안내가 다음 단계로)
final ValueNotifier<int> chatHelloTick = ValueNotifier<int>(0);

/// 묶음 70 #291: 친구 화면 안내 (Lv.8 장면 뒤, 로그인했으면)
final ValueNotifier<bool> friendTourOn = ValueNotifier<bool>(false);

/// 「세계」 안내 단계 (첫 펫이 말함). 정령과 이별 → 이름 → 쉼터 안내 뒤, 상태 화면에 들어오면 한 번.
/// ① 말풍선 버튼 → ② 「세계」 방 → ③ 「안녕하세요!」 (진짜로 보냄) → ④ 친구 초대 · 1:1 → ⑤ 우편 「첫 인사」(서버)
class ChatTourLayer extends StatefulWidget {
  const ChatTourLayer({super.key, required this.controller, this.onLogin});

  final AppController controller;

  /// 로그인 안 했을 때 「로그인」 (껍데기가 로그인 창을 띄움)
  final Future<void> Function()? onLogin;

  @override
  State<ChatTourLayer> createState() => _ChatTourLayerState();
}

class _ChatTourLayerState extends State<ChatTourLayer> {
  AppController get c => widget.controller;

  /// 상태 화면에 들어와 안내를 시작했는지
  bool _started = false;
  bool _sent = false;
  bool _askedLogin = false;

  @override
  void initState() {
    super.initState();
    tourBridge.addListener(_poke);
    chatHelloTick.addListener(_hello);
  }

  @override
  void dispose() {
    tourBridge.removeListener(_poke);
    chatHelloTick.removeListener(_hello);
    super.dispose();
  }

  void _poke() {
    if (mounted) setState(() {});
  }

  void _hello() {
    if (_started) setState(() => _sent = true);
  }

  Future<void> _finish() async {
    setState(() {
      _started = false;
      _sent = false;
    });
    await c.markChatTour();
  }

  /// 지금 보여 줄 (밝힐 곳, 말, 버튼). null 이면 아무것도
  (Rect?, String, (String, VoidCallback)?)? _step() {
    final top = tourBridge.top;
    if (!_started) {
      if (top != 'home' || tourBridge.tab != FeatureTourLayer.tStatus || tourBridge.paused) return null;
      if (c.holdNotices || !c.ready) return null;
      _started = true;
    }
    if (!c.chatOpen) {
      if (top != 'home') return null;
      return (
        null,
        '다른 각성자들과 이야기하려면 기록을 지켜 둬야 해!',
        _askedLogin
            ? ('나중에', _finish)
            : ('로그인', () async {
                setState(() => _askedLogin = true);
                await widget.onLogin?.call();
                if (mounted && !c.chatOpen) await _finish();
              }),
      );
    }
    if (_sent) {
      if (top == 'chatRoom') {
        return (null, '잘했어! 친구와는 따로 이야기할 수도 있어.', ('좋아', () => Navigator.of(context).maybePop()));
      }
      if (top == 'chatHub') {
        return (rectOfKey(const Key('chatTab_1'))?.inflate(4), '친구 탭에서 친구를 초대하거나, 친구와 1:1로 이야기해 봐!', ('알겠어', _finish));
      }
      return null;
    }
    switch (top) {
      case 'home':
        if (tourBridge.tab != FeatureTourLayer.tStatus) return null;
        return (rectOfKey(const Key('chatButton'))?.inflate(4), '정령은 떠났지만, 너 혼자가 아니야. 이 세계엔 같이 걷는 각성자들이 있어!', null);
      case 'chatHub':
        return (
          rectOfKey(const Key('chatRoom_server_server'))?.inflate(4),
          '온 세계 각성자들이 모이는 곳이야. 먼저 인사해 볼까?',
          null
        );
      case 'chatRoom':
        return (rectOfKey(const Key('chatQuick_0'))?.inflate(4), '「안녕하세요!」를 눌러 인사해 봐!', null);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (!c.chatTourPending) return const SizedBox.shrink();
          final s = _step();
          if (s == null) return const SizedBox.shrink();
          final (hole, line, button) = s;
          // 그리는 사이 자리가 바뀌면 한 번 더
          if (hole == null && button == null) WidgetsBinding.instance.addPostFrameCallback((_) => _poke());
          final size = MediaQuery.sizeOf(context);
          final pad = MediaQuery.paddingOf(context);
          final up = hole != null && hole.center.dy > size.height * 0.55;
          final pet = c.chatTourPet;
          return Material(
            key: const Key('chatTour'),
            type: MaterialType.transparency,
            child: Stack(fit: StackFit.expand, children: [
              if (hole != null) HoleSpotlight(hole: hole, round: false),
              Positioned(
                left: 14,
                right: 14,
                top: up ? pad.top + 96 : null,
                bottom: up ? null : (hole != null && hole.bottom > size.height - pad.bottom - 160 ? size.height - hole.top + 16 : pad.bottom + 96),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  IgnorePointer(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (pet != null) PetArt.of(pet, size: 58),
                      const SizedBox(width: 6),
                      Expanded(
                        child: CodeBubble(
                          side: BubbleSide.left,
                          at: 18,
                          padding: const EdgeInsets.fromLTRB(12, 8, 14, 9),
                          child: KText(line,
                              key: const Key('chatTourLine'),
                              style: const TextStyle(
                                  color: Color(0xFF3A2614), fontSize: 14, height: 1.4, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ),
                  if (button != null) ...[
                    const SizedBox(height: 8),
                    GoldButtonLite(key: const Key('chatTourButton'), label: button.$1, onPressed: button.$2),
                  ],
                ]),
              ),
              Positioned(
                right: 10,
                top: pad.top + 56,
                child: TextButton(
                  key: const Key('chatTourSkip'),
                  onPressed: _finish,
                  child: const Text('건너뛰기', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ),
            ]),
          );
        },
      );
}

/// 친구 화면 안내 한 칸 (Lv.8 장면 뒤): 친구 코드 판을 밝히고 한마디
class FriendTourOverlay extends StatefulWidget {
  const FriendTourOverlay({super.key});

  @override
  State<FriendTourOverlay> createState() => _FriendTourOverlayState();
}

class _FriendTourOverlayState extends State<FriendTourOverlay> {
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: friendTourOn,
        builder: (context, on, _) {
          if (!on) return const SizedBox.shrink();
          final hole = rectOfKey(const Key('friendCodePanel'));
          if (hole == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {});
            });
          }
          final pad = MediaQuery.paddingOf(context);
          return Material(
            key: const Key('friendTour'),
            type: MaterialType.transparency,
            child: Stack(fit: StackFit.expand, children: [
              if (hole != null) HoleSpotlight(hole: hole.inflate(4)),
              Positioned(
                left: 14,
                right: 14,
                bottom: pad.bottom + 60,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  IgnorePointer(
                    child: CodeBubble(
                      side: BubbleSide.left,
                      at: 18,
                      padding: const EdgeInsets.fromLTRB(12, 8, 14, 9),
                      child: KText(
                          '여기가 친구 화면이야! 초대 링크를 보내거나 친구 코드를 나눠 봐. '
                          '초대한 친구가 자라면 둘 다 선물을 받아.',
                          key: const Key('friendTourLine'),
                          style: const TextStyle(
                              color: Color(0xFF3A2614), fontSize: 14, height: 1.4, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GoldButtonLite(
                      key: const Key('friendTourOk'), label: '알겠어', onPressed: () => friendTourOn.value = false),
                ]),
              ),
            ]),
          );
        },
      );
}
