import 'dart:async';

import 'package:flutter/material.dart';

import 'core/format.dart';
import 'core/models/vitals.dart' show Expedition;
import 'app_controller.dart';
import 'data/ads/rewarded_ads.dart';
import 'data/notify/notifier.dart';
import 'core/rules/rules.dart';
import 'features/awakening/awakening_screen.dart';
import 'features/battle/dungeon_screen.dart';
import 'features/bulssi/bulssi_mood.dart';
import 'features/codex/codex_screen.dart';
import 'features/drive/drive_overlay.dart';
import 'features/mail/mail_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/village/village_screen.dart';
import 'features/town/bag_tab.dart';
import 'features/settings/settings_screen.dart';
import 'features/level_up/level_up_dialog.dart';
import 'features/map/expedition_result.dart';
import 'features/map/map_screen.dart';
import 'features/tutorial/targets.dart';
import 'features/tutorial/tutorial_layer.dart';
import 'features/pets/farewell_screen.dart';
import 'features/pets/pet_screen.dart';
import 'features/smithy/equip_picker.dart';
import 'features/village/board_screen.dart';
import 'features/status/stat_screen.dart';
import 'features/status/status_screen.dart';
import 'features/town/inn_screen.dart';
import 'theme/app_colors.dart';
import 'theme/ornaments.dart';
import 'theme/top_notice.dart';
import 'features/profile/title_celebration.dart';
import 'features/tutorial/feature_tour.dart';
import 'features/bulssi/bulssi_bubble.dart' show spiritTabVisits;

part 'shell/home_popups.dart';
part 'shell/nav_bar.dart';

class IsekaiRealityApp extends StatelessWidget {
  const IsekaiRealityApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '이세계가 현실이라면?',
      debugShowCheckedModeBanner: false,
      // 화면을 옮기면 키보드 닫기 (11-11 #73)
      navigatorObservers: [KeyboardCloser(), TourObserver()],
      navigatorKey: tourBridge.navKey,
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
      // 묶음 16 #132: 휴대폰 글자 크기 설정은 1.3배까지만 따른다
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(minScaleFactor: 1, maxScaleFactor: 1.3)),
        child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => BulssiScope(
          mood: controller.bulssiMood,
          spiritName: controller.companionName,
          kind: controller.profile.spiritKind,
          petSpecies: controller.companionPet?.species,
          petAdult: controller.companionPet?.adult ?? false,
          // 차량 속도 이동 확인 (11-11 #61): 모든 화면 위를 가린다
          // 앱 안 알림은 모두 위쪽 금테 띠로 (11-11 #85)
          child: TopNoticeHost(
            // 묶음 20 #160: 내비게이터 바깥 띠·안내·덮개도 글자 밑줄 없이
            child: Material(
            type: MaterialType.transparency,
            child: Stack(children: [
            Positioned.fill(
                child: NotificationListener<ScrollEndNotification>(
                    // 묶음 19 #4-2: 굴린 뒤 안내가 밝힐 자리를 다시 찾는다
                    onNotification: (_) {
                      tourBridge.poke();
                      return false;
                    },
                    child: TapOutsideToHideKeyboard(
                        child: child ?? const SizedBox()))),
            // 묶음 19 #4-2: Lv.3~6 기능 안내 (밀어 올린 화면 위까지)
            Positioned.fill(child: FeatureTourLayer(controller: controller)),
            if (controller.passengerMode)
              Positioned(
                top: MediaQuery.paddingOf(context).top + 52,
                left: 0,
                right: 0,
                child: const Center(child: PassengerBadge()),
              ),
            if (controller.driveBlocked)
              Positioned.fill(child: DriveOverlay(controller: controller)),
          ]),
          ),
          ),
        ),
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
  // 묶음 16 #126: 아래 메뉴 상태 · 가방 · 지도(가운데) · 마을 · 도감, 켜면 지도
  static const tStatus = 0, tBag = 1, tMap = 2, tVillage = 3, tCodex = 4;
  int _tab = tMap;

  // #130 빨간 점: 탭을 열면 사라지고, 새로 생기면 다시
  int _seenPoints = 0;
  int _seenRewards = 0;

  void _openTab(int i) {
    final c = widget.controller;
    if (i == tStatus) _seenPoints = c.unspentPoints;
    if (i == tVillage) _seenRewards = c.questRewardsReady;
    if (_tab != i) spiritTabVisits.value++;
    _tab = i;
    tourBridge.tab = i;
  }
  bool _levelUpShowing = false;

  /// 묶음 16 #131: 창은 한 번에 하나. 순서 레벨업 → 칭호 → 원정 → 편지(그 밖)
  bool get _popupBusy =>
      _levelUpShowing ||
      _titleShowing ||
      _noticeShowing ||
      _petNewsShowing ||
      _walkShowing ||
      _farewellShowing;

  /// 창 하나를 닫은 뒤 다음 차례 창을 볼 수 있게 다시 그린다
  void _kick() {
    if (mounted) setState(() {});
  }

  /// 앞 순서의 창이 기다리고 있으면 true ([rank] 0 레벨업, 1 칭호, 2 원정, 3 편지)
  bool _ahead(int rank) {
    final c = widget.controller;
    if (rank > 0 && c.pendingLevelUp != null) return true;
    if (rank > 1 && c.newTitle != null) return true;
    if (rank > 2 &&
        _tab != tMap &&
        c.finishedExpeditions.isNotEmpty) {
      return true;
    }
    return false;
  }

  Timer? _tick;
  bool _noticeShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    tourBridge.openTab = (i) {
      if (mounted) setState(() => _openTab(i));
    };
    tourBridge.tab = _tab;
    // 묶음 19 6-2: 알림을 눌러 들어오면 그 화면으로
    final n = widget.controller.notifier;
    if (n != null) {
      _tapSub = n.taps.listen(_openFromNotice);
      n.takeLaunchId().then((id) {
        if (id != null) _openFromNotice(id);
      });
    }
    // 묶음 15 #103: 보상형 광고 (광고가 켜진 빌드만). 맞춤형은 허용한 사람만
    if (RewardedAds.enabled) {
      widget.controller.watchAd = (placement) async {
        final personal = await _adConsent();
        return RewardedAds.instance.show(personalized: personal);
      };
    }
    // 여관 휴식·정령 원정은 시간이 지나면 끝난다. 30초마다 확인한다.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      final c = widget.controller;
      if (c.ready && !c.needsAwakening) c.refreshVitals();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tapSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _farewellShowing = false;

  bool _petNewsShowing = false;

  /// 이번에 앱을 켠 동안 부화 창을 이미 띄운 알 (닫으면 가방에서 다시 연다)
  final _promptedEggs = <String>{};

  bool _walkShowing = false;
  DateTime? _shownFind;
  DateTime? _shownMerchant;

  bool _titleShowing = false;
  bool _petCodexNoticed = false;

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
            backgroundColor: AppColors.deepNight,
            body: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/images/splash.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox()),
              if (controller.startError == null)
                const Align(
                  alignment: Alignment(0, 0.15),
                  child: CircularProgressIndicator(color: AppColors.gold),
                )
              else
                // 묶음 16 #124: 무한 로딩 대신 다시 시도 (기록은 지우지 않는다)
                Align(
                  alignment: const Alignment(0, 0.3),
                  child: Container(
                    key: const Key('startRetry'),
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xE6151838),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.gold, width: 1.2),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('잠깐 길을 잃었어요',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      const Text('기록은 그대로 있어요. 다시 시도해 주세요.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 16),
                      FilledButton(
                        key: const Key('startRetryButton'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: const Color(0xFF1A1405)),
                        onPressed: controller.init,
                        child: const Text('다시 시도',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ]),
                  ),
                ),
            ]),
          );
        }
        if (!controller.needsAwakening) _maybeShowTitle();
        _maybeShowBagFull();
        if (controller.ageBlocked) {
          return const Scaffold(
              body: NightBackground(child: AgeBlockedView()));
        }
        if (controller.needsAwakening) {
          _tab = tMap; // 기록을 지운 뒤 다시 시작하면 지도부터
          return AwakeningScreen(
            onTooYoung: controller.blockForAge,
            now: () => controller.now,
            onAwaken: (name, look, spirit, spiritName) =>
                controller.awaken(
                    name: name,
                    look: look,
                    spirit: spirit,
                    spiritName: spiritName),
          );
        }
        _maybeShowLevelUp();
        _maybeShowFarewell();
        _maybeShowNotices();
        _maybeShowPetNews();
        _maybeShowWalkNews();
        tourBridge.paused = _popupBusy;
        _maybeShowHpTip();
        void push(Widget page) => Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => page));
        // 하단 메뉴 상태 · 가방 · 지도 · 마을 · 도감 (묶음 16 #126)
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
            equippedTitle: controller.equippedTitle,
            onOpenInn: () => push(InnScreen(controller: controller)),
            look: controller.profile.look,
            season: SeasonRules.of(controller.now),
          ),
          NightBackground(header: true, child: BagTab(controller: controller)),
          MapScreen(
              controller: controller,
              onOpenBag: () => setState(() => _openTab(tBag)),
              onOpenDungeon: () => push(DungeonScreen(controller: controller)),
              onShowExpeditionResults: () async {
                if (_noticeShowing) return;
                _noticeShowing = true;
                await _showExpeditionResults(controller.finishedExpeditions);
                _noticeShowing = false;
                _kick();
              }),
          NightBackground(
              header: true, child: VillageScreen(controller: controller)),
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
              petsSeen: controller.pets.seen,
              petsOpen: controller.petCodexOpen,
              petsNew: controller.petCodexNew,
              onPetsTab: controller.markPetCodexSeen,
              onOpenPets: controller.farewellDone
                  ? () => push(PetScreen(controller: controller))
                  : null,
            ),
          ),
        ];

        final topInset = MediaQuery.paddingOf(context).top;
        final scaffold = Scaffold(
          body: Stack(children: [
            Positioned.fill(child: IndexedStack(index: _tab, children: pages)),
            // 묶음 16 #133: 지도 위 공통 위쪽 띠는 비치게 (상태 탭은 그대로)
            if (_tab == tMap)
              Positioned(
                key: const Key('topStrip'),
                left: 0,
                right: 0,
                top: 0,
                // 묶음 20 #158: 정령 배지까지 덮는 공통 위쪽 띠
                height: topInset + 116,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xB30B0D26), Color(0x000B0D26)],
                      ),
                    ),
                  ),
                ),
              ),
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
            // 우편 (11-11 #65): 새 우편이 있으면 빨간 점
            Positioned(
              top: topInset + 6,
              right: 66,
              child: MailButton(
                hasNew: controller.hasNewMail,
                onTap: () => push(MailScreen(controller: controller)),
              ),
            ),
            Positioned(
              top: topInset + 6,
              right: 12,
              child: SettingsButton(
                onTap: () => push(Scaffold(
                  backgroundColor: AppColors.deepNight,
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
          backgroundColor: AppColors.deepNight,
          bottomNavigationBar: OrnateNavBar(
            index: _tab,
            dots: {
              if (_tab != tStatus &&
                  controller.unspentPoints > 0 &&
                  controller.unspentPoints != _seenPoints)
                tStatus,
              if (_tab != tVillage &&
                  controller.questRewardsReady > 0 &&
                  controller.questRewardsReady != _seenRewards)
                tVillage,
            },
            onTap: (i) {
              hideKeyboard(); // 탭을 옮기면 키보드 닫기 (11-11 #73)
              setState(() => _openTab(i));
            },
          ),
        );
        if (!controller.inTutorial) return scaffold;
        // 묶음 18 #150·#148: 튜토리얼은 아래 메뉴까지 덮는 한 겹에서 (누를 곳 하나만)
        return Stack(children: [
          Positioned.fill(child: scaffold),
          Positioned.fill(
            child: Material(
             type: MaterialType.transparency,
             child: TutorialLayer(
              controller: controller,
              tab: _tab,
              openTab: (i) => setState(() => _openTab(i)),
              showResults: _showResultsNow,
             ),
            ),
          ),
        ]);
      },
    );
  }

  StreamSubscription<int>? _tapSub;

  /// 나눈 파일(shell/home_popups.dart)에서 다시 그릴 때
  void _set(VoidCallback f) => setState(f);
}
