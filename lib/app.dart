import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'data/storage/record_store.dart';
import 'features/awakening/awakening_screen.dart';
import 'features/battle/dungeon_screen.dart';
import 'features/level_up/level_up_dialog.dart';
import 'features/map/map_screen.dart';
import 'features/status/status_screen.dart';
import 'theme/app_colors.dart';

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
        builder: (_) => LevelUpDialog(from: pending.from, to: pending.to),
      );
      await widget.controller.acknowledgeLevelUp();
      _levelUpShowing = false;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// 앱으로 돌아올 때마다 걸음·수면을 다시 읽는다
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
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }
        if (controller.needsAwakening) {
          return AwakeningScreen(
            onAwaken: (name, look) =>
                controller.awaken(name: name, look: look),
          );
        }
        _maybeShowLevelUp();
        final pages = <Widget>[
          StatusScreen(
            player: controller.player,
            onLogStudy: controller.logStudy,
            onOpenDungeon: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DungeonScreen(controller: controller),
              ),
            ),
            heroAsset: controller.profile.look == HeroLook.female
                ? 'assets/images/hero_female.png'
                : 'assets/images/hero_male.png',
          ),
          MapScreen(controller: controller),
          const _ComingSoon(label: '기록'),
          const _ComingSoon(label: '칭호'),
          const _ComingSoon(label: '설정'),
        ];

        return Scaffold(
          body: IndexedStack(index: _tab, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: AppColors.night,
            indicatorColor: AppColors.gold.withValues(alpha: 0.25),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.person_rounded), label: '상태'),
              NavigationDestination(icon: Icon(Icons.map_rounded), label: '지도'),
              NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: '기록'),
              NavigationDestination(icon: Icon(Icons.military_tech_rounded), label: '칭호'),
              NavigationDestination(icon: Icon(Icons.settings_rounded), label: '설정'),
            ],
          ),
        );
      },
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('$label 화면은 다음 작업에서 만들어요',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 16)),
    );
  }
}
