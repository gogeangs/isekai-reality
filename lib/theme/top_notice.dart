import 'dart:async';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 앱 안 알림 (11-11 #85): 화면 위쪽에서 내려왔다 올라가는 작은 금테 띠.
/// 아래 메뉴·버튼을 가리지 않는다(띠 밖은 그대로 눌림). 누르면 [onTap] 후 닫히고,
/// 위로 밀어도 닫힌다.
///
/// 묶음 41 확인 답: 새 알림이 오면 앞 알림을 바로 바꿔 띄운다(쌓이지 않게).
/// 다만 앱을 열 때·레벨업 뒤 소식(칭호·숙련 스킬 등)은 [showTopNoticeQueued] 로
/// 띄워 차례를 지킨다(바뀐 소식은 그 뒤에 다시 나온다).
///
/// 앱 맨 바깥(MaterialApp.builder)에 [TopNoticeHost] 가 있으면 그 위에 띄우고,
/// 없으면(테스트처럼 화면 하나만 띄웠을 때) 기본 띠로 대신한다.
void showTopNotice(BuildContext context, String text,
    {VoidCallback? onTap,
    IconData? icon,
    Duration? duration,
    String? image,
    bool queued = false}) {
  final host = TopNoticeHost._state;
  if (host != null && host.mounted) {
    host._add(_Notice(text, onTap, icon, duration ?? _durationFor(text),
        image: image, queued: queued));
    return;
  }
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}

/// 차례를 지키는 소식 알림 (앱을 열 때·레벨업 뒤 칭호·숙련 스킬 등)
void showTopNoticeQueued(BuildContext context, String text,
        {VoidCallback? onTap, IconData? icon, Duration? duration, String? image}) =>
    showTopNotice(context, text,
        onTap: onTap,
        icon: icon,
        duration: duration,
        image: image,
        queued: true);

Duration _durationFor(String text) =>
    Duration(milliseconds: (2200 + text.length * 45).clamp(2600, 5500));

class _Notice {
  _Notice(this.text, this.onTap, this.icon, this.duration,
      {this.image, this.queued = false});

  /// 소식 알림: 앞 알림을 바꾸지 않고 차례를 기다린다
  final bool queued;

  /// 묶음 35: 아이콘 대신 작은 그림 (예: 직업 문장)
  final String? image;
  final String text;
  final VoidCallback? onTap;
  final IconData? icon;
  final Duration duration;
}

class TopNoticeHost extends StatefulWidget {
  const TopNoticeHost({super.key, required this.child});

  final Widget child;

  static _TopNoticeHostState? _state;

  @override
  State<TopNoticeHost> createState() => _TopNoticeHostState();
}

class _TopNoticeHostState extends State<TopNoticeHost> {
  final _queue = <_Notice>[];
  _Notice? _now;
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    TopNoticeHost._state = this;
  }

  @override
  void dispose() {
    if (TopNoticeHost._state == this) TopNoticeHost._state = null;
    _timer?.cancel();
    super.dispose();
  }

  void _add(_Notice n) {
    // 같은 글이 이미 떠 있으면 시간만 새로
    if (_now?.text == n.text && _shown) {
      _timer?.cancel();
      _timer = Timer(n.duration, _hide);
      return;
    }
    if (_queue.any((q) => q.text == n.text)) return;
    if (n.queued) {
      _queue.add(n);
      if (_now == null) _next();
      return;
    }
    // 묶음 41: 새 알림은 앞 알림을 바로 바꿔 띄운다. 앞의 것이 소식이면 뒤로 다시 미룸
    final cur = _now;
    if (cur != null && cur.queued) _queue.insert(0, cur);
    _queue.removeWhere((q) => !q.queued);
    _timer?.cancel();
    setState(() {
      _now = n;
      _shown = true;
    });
    _timer = Timer(n.duration, _hide);
  }

  void _next() {
    _timer?.cancel();
    if (_queue.isEmpty) {
      setState(() => _now = null);
      return;
    }
    setState(() {
      _now = _queue.removeAt(0);
      _shown = false;
    });
    // 한 프레임 뒤 내려오게
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
    _timer = Timer(_now!.duration, _hide);
  }

  void _hide() {
    if (!mounted) return;
    setState(() => _shown = false);
    _timer = Timer(const Duration(milliseconds: 280), _next);
  }

  @override
  Widget build(BuildContext context) {
    final n = _now;
    final top = MediaQuery.paddingOf(context).top;
    return Stack(children: [
      Positioned.fill(child: widget.child),
      if (n != null)
        Positioned(
          top: top + 6,
          left: 14,
          right: 14,
          child: AnimatedSlide(
            offset: _shown ? Offset.zero : const Offset(0, -1.6),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _shown ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: Center(
                child: Material(
                  type: MaterialType.transparency,
                  child: GestureDetector(
                    key: const Key('topNotice'),
                    onTap: () {
                      final tap = n.onTap;
                      _hide();
                      tap?.call();
                    },
                    // 위로 밀면 바로 닫힘
                    onVerticalDragEnd: (d) {
                      if ((d.primaryVelocity ?? 0) <= 0) _hide();
                    },
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
                      decoration: BoxDecoration(
                        color: const Color(0xF2141638),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gold, width: 1.2),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x88000000),
                              blurRadius: 12,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (n.image != null)
                          Image.asset(n.image!,
                              width: 28,
                              height: 28,
                              errorBuilder: (_, __, ___) => Icon(
                                  n.icon ?? Icons.auto_awesome_rounded,
                                  size: 18,
                                  color: AppColors.goldBright))
                        else
                          Icon(n.icon ?? Icons.auto_awesome_rounded,
                              size: 18, color: AppColors.goldBright),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(n.text,
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 14,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600)),
                        ),
                        if (n.onTap != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppColors.goldBright),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}
