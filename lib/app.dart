import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'features/awakening/awakening_screen.dart';
import 'data/weather/weather_source.dart';
import 'features/battle/dungeon_screen.dart';
import 'features/bulssi/bulssi_mood.dart';
import 'features/codex/codex_screen.dart';
import 'features/records/records_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/level_up/level_up_dialog.dart';
import 'features/map/map_screen.dart';
import 'features/status/status_screen.dart';
import 'features/town/inn_screen.dart';
import 'features/town/shop_screen.dart';
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
        if (controller.needsAwakening) {
          _tab = 0; // 기록을 지운 뒤 다시 시작하면 상태창부터
          return AwakeningScreen(
            onAwaken: (name, look, weather) => controller.awaken(
                name: name, look: look, weatherEnabled: weather),
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
            equippedTitle: controller.equippedTitle,
            onOpenInn: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => InnScreen(controller: controller),
              ),
            ),
            onOpenShop: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShopScreen(controller: controller),
              ),
            ),
            look: controller.profile.look,
            weatherLabel: controller.weatherLabel,
            weatherIcon: _weatherIcon(controller),
          ),
          MapScreen(controller: controller),
          NightBackground(header: true, child: RecordsScreen(player: controller.player)),
          NightBackground(
            header: true,
            child: CodexScreen(
              player: controller.player,
              purifiedMonsters: controller.purifiedEver,
              equipped: controller.equippedTitle,
              onEquip: controller.setEquippedTitle,
            ),
          ),
          NightBackground(header: true, child: SettingsScreen(controller: controller)),
        ];

        return Scaffold(
          body: BulssiScope(
            mood: controller.bulssiMood,
            spiritName: controller.profile.spiritName,
            child: IndexedStack(index: _tab, children: pages),
          ),
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

/// 하단 메뉴: 금테 막대, 고른 메뉴는 금색 상자 (목업 구도)
class OrnateNavBar extends StatelessWidget {
  const OrnateNavBar({super.key, required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const items = [
    ('status', '상태'),
    ('map', '지도'),
    ('records', '기록'),
    ('codex', '도감'),
    ('settings', '설정'),
  ];

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
                                    'assets/images/nav_${items[i].$1}.png',
                                    width: 30,
                                    height: 30,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.circle_outlined,
                                        color: AppColors.text)),
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

IconData _weatherIcon(AppController controller) {
  if (controller.bulssiMood == BulssiMood.night) return Icons.nightlight_round;
  return switch (controller.weather?.kind) {
    WeatherKind.rain => Icons.umbrella_rounded,
    WeatherKind.snow => Icons.ac_unit_rounded,
    WeatherKind.cloudy => Icons.cloud_rounded,
    _ => Icons.wb_sunny_rounded,
  };
}
