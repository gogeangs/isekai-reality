import 'dart:async';

import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 앱 안 알림 (11-11 #85): 화면 위쪽에서 내려왔다 올라가는 작은 금테 띠.
/// 아래 메뉴·버튼을 가리지 않고, 겹치면 차례로 보여 준다. 누르면 [onTap].
///
/// 앱 맨 바깥(MaterialApp.builder)에 [TopNoticeHost] 가 있으면 그 위에 띄우고,
/// 없으면(테스트처럼 화면 하나만 띄웠을 때) 기본 띠로 대신한다.
void showTopNotice(BuildContext context, String text,
    {VoidCallback? onTap, IconData? icon, Duration? duration}) {
  final host = TopNoticeHost._state;
  if (host != null && host.mounted) {
    host._add(_Notice(text, onTap, icon, duration ?? _durationFor(text)));
    return;
  }
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));
}

Duration _durationFor(String text) =>
    Duration(milliseconds: (2200 + text.length * 45).clamp(2600, 5500));

class _Notice {
  _Notice(this.text, this.onTap, this.icon, this.duration);
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
    // 같은 글이 이미 줄에 있으면 또 넣지 않는다
    if (_now?.text == n.text || _queue.any((q) => q.text == n.text)) return;
    _queue.add(n);
    if (_now == null) _next();
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
                    onVerticalDragEnd: (_) => _hide(),
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
                        Icon(n.icon ?? Icons.auto_awesome_rounded,
                            size: 18, color: AppColors.goldBright),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(n.text,
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 13.5,
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
