import 'dart:async';

import 'package:flutter/material.dart';

import 'core/format.dart';
import 'app_controller.dart';
import 'core/rules/rules.dart';
import 'features/awakening/awakening_screen.dart';
import 'features/battle/dungeon_screen.dart';
import 'features/bulssi/bulssi_mood.dart';
import 'features/codex/codex_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/village/village_screen.dart';
import 'features/town/bag_tab.dart';
import 'features/settings/settings_screen.dart';
import 'features/level_up/level_up_dialog.dart';
import 'features/map/map_screen.dart';
import 'features/smithy/equip_picker.dart';
import 'features/status/stat_screen.dart';
import 'features/status/status_screen.dart';
import 'features/town/inn_screen.dart';
import 'theme/app_colors.dart';
import 'theme/ornaments.dart';

class IsekaiRealityApp extends StatelessWidget {
  const IsekaiRealityApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '이세계가 현실이라면?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.night,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.gold,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // 정령 종류·이름·빛 색은 모든 화면(밀어 올린 화면 포함)에서 같아야 해서
      // 내비게이터 바깥에서 한 번 감싼다
      builder: (context, child) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => BulssiScope(
          mood: controller.bulssiMood,
          spiritName: controller.profile.spiritName,
          kind: controller.profile.spiritKind,
          child: child ?? const SizedBox(),
        ),
      ),
      home: HomeShell(controller: controller),
    );
  }
}

/// 하단 메뉴 5개: 상태 · 지도 · 기록 · 칭호 · 설정
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  bool _levelUpShowing = false;

  /// 확인하지 않은 레벨업이 있으면 화면이 그려진 뒤 연출을 띄운다
  void _maybeShowLevelUp() {
    final pending = widget.controller.pendingLevelUp;
    if (pending == null || _levelUpShowing) return;
    _levelUpShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => LevelUpDialog(
          from: pending.from,
          to: pending.to,
          title: widget.controller.equippedTitle == null
              ? null
              : TitleRules.info(widget.controller.equippedTitle!).name,
        ),
      );
      await widget.controller.acknowledgeLevelUp();
      _levelUpShowing = false;
    });
  }

  Timer? _tick;
  bool _noticeShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 여관 휴식·정령 원정은 시간이 지나면 끝난다. 30초마다 확인한다.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      final c = widget.controller;
      if (c.ready && !c.needsAwakening) c.refreshVitals();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 휴식이 끝났거나 정령이 돌아왔으면 한 번 알려 준다
  void _maybeShowNotices() {
    final c = widget.controller;
    if (_noticeShowing || _levelUpShowing) return;
    final ex = c.expedition;
    final String? title;
    final String? body;
    if (c.justRested) {
      title = '푹 쉬었어요';
      body = 'HP와 정령 MP가 가득 찼어요. 오늘 휴식 보너스 경험치 '
          '+${RuleConstants.restBonusExp}!';
    } else if (ex != null && ex.finished) {
      final id = Monsters.byName(ex.monster);
      final name = id == null ? '몬스터' : Monsters.info(id).name;
      title = ex.cleared! ? '원정 성공!' : '원정에서 돌아왔어요';
      body = ex.cleared!
          ? '${josa(c.profile.spiritName, '이/가')} ${josa(name, '을/를')} 사냥했어요.'
              '${c.lastExpeditionExp > 0 ? ' 경험치 +${c.lastExpeditionExp}' : ''}'
          : '${josa(name, '이/가')} 너무 강했어요. MP만 쓰고 무사히 돌아왔어요.';
    } else {
      return;
    }
    _noticeShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.night,
          title: Text(title!, style: AppText.title(20)),
          content: Text(body!,
              style: const TextStyle(color: AppColors.text, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('좋아요'),
            ),
          ],
        ),
      );
      if (c.justRested) {
        c.clearJustRested();
      } else {
        await c.acknowledgeExpedition();
      }
      _noticeShowing = false;
    });
  }

  bool _titleShowing = false;

  /// 칭호를 새로 얻으면 알림. 누르면 프로필 칭호 목록으로 (11-11 #41)
  void _maybeShowTitle() {
    final c = widget.controller;
    final t = c.newTitle;
    if (t == null || _titleShowing || _levelUpShowing) return;
    _titleShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final name = TitleRules.info(t).name;
      final eul = josa(name, '을/를').substring(name.length);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('새 칭호 「$name」$eul 얻었어요!'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: '보기',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ProfileScreen(controller: c))),
        ),
      ));
      await c.acknowledgeTitles();
      _titleShowing = false;
    });
  }

  /// 가방이 가득 차 새 재료를 금화로 바꿨을 때 (11-11 #48)
  void _maybeShowBagFull() {
    final c = widget.controller;
    if (c.pendingBagOverflow <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final g = c.takeBagOverflow();
      if (g <= 0) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('가방이 가득 찼어요. 새로 얻은 재료는 금화 ${comma(g)}으로 바꿨어요.'),
        duration: const Duration(seconds: 4),
      ));
    });
  }

  /// 앱으로 돌아올 때마다 걸음을 다시 읽는다
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.controller.ready) {
      widget.controller.sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.ready) {
          // 시작 화면 (불러오는 동안)
          return Scaffold(
            backgroundColor: const Color(0xFF0F1233),
            body: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/images/splash.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),
              const Align(
                alignment: Alignment(0, 0.15),
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            ]),
          );
        }
        if (!controller.needsAwakening) _maybeShowTitle();
        _maybeShowBagFull();
        if (controller.needsAwakening) {
          _tab = 0; // 기록을 지운 뒤 다시 시작하면 상태창부터
          return AwakeningScreen(
            onAwaken: (name, look, weather, spirit, spiritName) =>
                controller.awaken(
                    name: name,
                    look: look,
                    weatherEnabled: weather,
                    spirit: spirit,
                    spiritName: spiritName),
          );
        }
        _maybeShowLevelUp();
        _maybeShowNotices();
        void push(Widget page) => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
        // 11-10 #25: 하단 메뉴 상태 · 지도 · 마을 · 가방 · 도감
        final pages = <Widget>[
          StatusScreen(
            player: controller.player,
            hp: controller.hp,
            mp: controller.mp,
            maxHp: controller.maxHp,
            mpMax: controller.mpMax,
            stats: controller.shownStats,
            unspentPoints: controller.unspentPoints,
            onOpenStats: () => push(StatScreen(controller: controller)),
            lifeLine: controller.statusLifeLine,
            armory: controller.armory,
            onSlot: (slot) => showEquipPicker(context, controller, slot),
            restLeft: controller.resting ? controller.restLeft : null,
            spiritAway: _spiritAway(controller),
            onOpenDungeon: () => push(DungeonScreen(controller: controller)),
            equippedTitle: controller.equippedTitle,
            onOpenInn: () => push(InnScreen(controller: controller)),
            look: controller.profile.look,
          ),
          MapScreen(controller: controller),
          NightBackground(
              header: true, child: VillageScreen(controller: controller)),
          NightBackground(header: true, child: BagTab(controller: controller)),
          NightBackground(
            header: true,
            child: CodexScreen(
              // 더 나오지 않는 정령계 몬스터는 도감에서 숨긴다
              purifiedMonsters: {
                for (final m in controller.purifiedEver)
                  if (!Monsters.info(m).retired) m,
              },
              huntCounts: controller.huntTotals,
              modHunts: controller.modHuntTotals,
            ),
          ),
        ];

        final topInset = MediaQuery.paddingOf(context).top;
        return Scaffold(
          body: Stack(children: [
            Positioned.fill(child: IndexedStack(index: _tab, children: pages)),
            // 위쪽 메뉴 (모든 탭 같은 자리): 왼쪽 프로필, 오른쪽 설정
            Positioned(
              top: topInset + 6,
              left: 12,
              child: ProfileButton(
                look: controller.profile.look,
                level: controller.player.level.level,
                onTap: () => push(ProfileScreen(controller: controller)),
              ),
            ),
            Positioned(
              top: topInset + 8,
              right: 12,
              child: SettingsButton(
                onTap: () => push(Scaffold(
                  backgroundColor: const Color(0xFF0F1233),
                  body: NightBackground(
                    header: true,
                    child: Builder(
                      builder: (ctx) => SettingsScreen(
                        controller: controller,
                        onBack: () => Navigator.of(ctx).maybePop(),
                      ),
                    ),
                  ),
                )),
              ),
            ),
          ]),
          backgroundColor: const Color(0xFF0F1233),
          bottomNavigationBar: OrnateNavBar(
            index: _tab,
            onTap: (i) => setState(() => _tab = i),
          ),
        );
      },
    );
  }
}

/// 상태창에 보여 줄 원정 한 줄 (원정 중이 아니면 null)
String? _spiritAway(AppController c) {
  final ex = c.expedition;
  if (ex == null || ex.finished) return null;
  final left = ex.returnAt.difference(c.now);
  final m = left.inMinutes < 1 ? 1 : left.inMinutes;
  return '정령 원정 중 · $m분 뒤 돌아와요';
}

/// 하단 메뉴: 금테 막대, 고른 메뉴는 금색 상자 (목업 구도)
class OrnateNavBar extends StatelessWidget {
  const OrnateNavBar({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  /// (그림, 이름). 마을·가방 전용 메뉴 그림(nav_village, nav_bag)이 오기 전에는
  /// 여관·가방 아이콘으로 대신한다.
  static const items = [
    ('nav_status', '상태'),
    ('nav_map', '지도'),
    ('nav_village', '마을'),
    ('nav_bag', '가방'),
    ('nav_codex', '도감'),
  ];

  static const _fallback = {
    'nav_village': 'map_inn',
    'nav_bag': 'icon_bag',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F1233),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
          child: OrnatePanel(
            art: false,
            padding: const EdgeInsets.all(4),
            radius: 18,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == index,
                      button: true,
                      child: InkWell(
                        onTap: () => onTap(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 54,
                          decoration: i == index
                              ? BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0xFFB98330),
                                      Color(0xFF6E4B1A)
                                    ],
                                  ),
                                  border: Border.all(
                                      color: AppColors.goldBright, width: 1.2),
                                  boxShadow: [
                                    BoxShadow(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.45),
                                        blurRadius: 10),
                                  ],
                                )
                              : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Opacity(
                                opacity: i == index ? 1 : 0.7,
                                child: Image.asset(
                                    'assets/images/${items[i].$1}.png',
                                    width: 30,
                                    height: 30,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                        'assets/images/${_fallback[items[i].$1] ?? 'icon_quest'}.png',
                                        width: 30,
                                        height: 30,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.circle_outlined,
                                                color: AppColors.text))),
                              ),
                              const SizedBox(height: 2),
                              Text(items[i].$2,
                                  style: TextStyle(
                                    color: i == index
                                        ? AppColors.goldBright
                                        : AppColors.textMuted,
                                    fontSize: 12,
                                    fontWeight: i == index
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

