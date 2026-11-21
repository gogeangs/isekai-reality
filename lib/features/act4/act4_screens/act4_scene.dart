part of '../act4_screens.dart';

/// 4막 장면을 차례로 본다 (볼 장면이 없을 때까지)
Future<void> showAct4Pending(BuildContext context, AppController c) async {
  var guard = 0;
  while (context.mounted && guard++ < 8) {
    final s4 = c.pendingAct4Scene;
    final s = s4 ?? c.pendingAct5Scene;
    if (s == null) return;
    final act = s4 != null ? 4 : 5;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true, builder: (_) => Act4SceneScreen(controller: c, scene: s, act: act)));
    if (!(act == 4 ? c.act4.has(s.id) : c.act5.has(s.id))) return;
  }
}

/// 4막 「길드 창설」 장면 한 개 (묶음 59 #246)
class Act4SceneScreen extends StatefulWidget {
  const Act4SceneScreen({super.key, required this.controller, required this.scene, this.act = 4});

  final AppController controller;
  final Act4Scene scene;

  /// 묶음 60: 5막 장면도 같은 화면 (본 기록은 5막 쪽에)
  final int act;

  @override
  State<Act4SceneScreen> createState() => _Act4SceneScreenState();
}

class _Act4SceneScreenState extends State<Act4SceneScreen> {
  AppController get c => widget.controller;
  int _i = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    c.holdNoticesWhile(true);
  }

  @override
  void dispose() {
    c.holdNoticesWhile(false);
    super.dispose();
  }

  Future<void> _next() async {
    if (_i < widget.scene.lines.length - 1) {
      setState(() => _i++);
      return;
    }
    if (_done) return;
    _done = true;
    final s = widget.scene;
    if (widget.act == 5) {
      await c.markAct5Scene(s);
      if (!mounted) return;
      if (s.id == 'e1c') showTopNotice(context, '에르바르드 대륙 지도가 열렸어요 · 2,000보마다 공성권을 모아요', icon: Icons.map_rounded);
      if (s.id == 'e2a') {
        showTopNotice(
            context,
            c.erbardGuild && c.erbard.myEstates.isNotEmpty
                ? '수비대 배치가 열렸어요 · 우리 길드 깃발이 에르바르드에 꽂혔어요'
                : '수비대 배치가 열렸어요',
            icon: Icons.flag_rounded);
      }
      if (s.id == 'e2b') showTopNotice(context, '개척 보상 · 등불 인장 ${ErbardRules.pioneerSeals} · 금화 ${ErbardRules.pioneerGold}', icon: Icons.explore_rounded);
      if (s.id == 'e3b') showTopNotice(context, '칭호 「에르바르드의 개척자」 · ${ErbardRules.erbardTeaser}', icon: Icons.flag_rounded);
      Navigator.of(context).pop();
      return;
    }
    await c.markAct4Scene(s);
    if (!mounted) return;
    if (s.giveCharter) {
      showTopNotice(context, '리안에게 「길드 창설 증서」를 받았어요', icon: Icons.description_rounded);
    }
    if (c.act4Done && s.id == 'c5c') {
      showTopNotice(context, '칭호 「등불의 맹세」 · ${GuildRules.act5Teaser}', icon: Icons.flag_rounded);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scene;
    final (who, line) = s.lines[_i];
    final sp = speakerOf(c, who);
    return PopScope(
      canPop: _done,
      child: Scaffold(
        key: Key('act${widget.act}Scene_${s.id}'),
        backgroundColor: AppColors.deepNight,
        body: Stack(children: [
          Positioned.fill(
            child: IllustratedScene(
              key: ValueKey('act${widget.act}${s.id}$_i'),
              image: s.image,
              speaker: sp.name,
              tailX: 0.5,
              line: line,
              lineKey: 'act${widget.act}-${s.id}-$_i',
              onNext: _next,
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            left: 14,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xAA000000), borderRadius: BorderRadius.circular(10)),
                child: Text('${widget.act}막 · ${s.place}',
                    style: const TextStyle(color: AppColors.goldBright, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
