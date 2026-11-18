import 'dart:async';

import 'features/act4/act4_screens.dart' show Act4SceneScreen, GuildHallScreen;
import 'package:flutter/material.dart';

import 'core/format.dart';
import 'core/models/vitals.dart' show Expedition;
import 'app_controller.dart';
import 'data/ads/rewarded_ads.dart';
import 'data/notify/notifier.dart';
import 'core/rules/rules.dart';
import 'features/notice/notice_screen.dart';
import 'features/legal/consent_screen.dart';
import 'features/awakening/awakening_screen.dart';
import 'features/battle/dungeon_screen.dart';
import 'features/bulssi/bulssi_mood.dart';
import 'features/codex/codex_screen.dart';
import 'features/drive/drive_overlay.dart';
import 'features/chat/chat_screens.dart';
import 'features/mail/mail_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/village/village_screen.dart';
import 'features/village/tavern_screen.dart' show TavernScreen;
import 'features/village/npc_request.dart';
import 'features/village/training_screen.dart' show TrainingStatusRow;
import 'features/town/bag_hold_sheet.dart';
import 'features/town/bag_tab.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/account_section.dart' show LoginButton, loadRecordFlow, signInFlow;
import 'data/cloud/cloud_auth.dart' show LoginProvider;
import 'features/level_up/level_up_dialog.dart';
import 'features/map/expedition_result.dart';
import 'features/map/map_screen.dart';
import 'features/tutorial/targets.dart';
import 'features/tutorial/tutorial_layer.dart';
import 'features/pets/farewell_screen.dart';
import 'features/act2/ash_battle_screen.dart' show EndingScreen;
import 'features/highland/highland_screen.dart' show HighlandSceneScreen;
import 'features/jobs/guild_screen.dart';
import 'features/jobs/job_skill_bar.dart';
import 'features/jobs/skill_screen.dart';
import 'features/alchemy/convert_panel.dart' show LockedJobPanel;
import 'features/pets/pet_screen.dart';
import 'features/smithy/equip_picker.dart';
import 'features/village/board_screen.dart';
import 'features/status/stat_screen.dart';
import 'features/status/step_chest_row.dart';
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
          petSpecies: controller.voicePet?.species,
          petAdult: controller.voicePet?.adult ?? false,
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
  int _seenSkillPoints = 0;

  void _openTab(int i) {
    final c = widget.controller;
    if (i == tStatus) {
      _seenPoints = c.unspentPoints;
      _seenSkillPoints = c.skillPointsLeft;
    }
    if (i == tVillage) _seenRewards = c.questRewardsReady;
    if (_tab != i) spiritTabVisits.value++;
    // 묶음 51: 마을 탭에 들어올 때마다 한 번 「방문」
    if (i == tVillage && _tab != i) villageVisits.value++;
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
      _farewellShowing ||
      _jobShowing ||
      _endingShowing ||
      _bagHoldShowing;

  /// 창 하나를 닫은 뒤 다음 차례 창을 볼 수 있게 다시 그린다
  void _kick() {
    if (mounted) setState(() {});
  }

  /// 앞 순서의 창이 기다리고 있으면 true ([rank] 0 레벨업, 1 칭호, 2 원정, 3 편지)
  bool _ahead(int rank) {
    final c = widget.controller;
    if (rank > 0 && c.pendingLevelUp != null) return true;
    // 묶음 29 #182: 이별 컷신은 레벨업 창 바로 다음. 다른 창은 그 뒤로 모아 둔다
    if (rank > 0 && c.farewellPending && !c.inTutorial) return true;
    // 묶음 30 #55: Lv.15 직업 각성도 레벨업 창(·이별 컷신) 바로 다음
    if (rank > 0 && c.jobAwakenPending) return true;
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
    // 묶음 55 #245: 10분마다 조용히 백업 (로그인했을 때만, 바뀐 게 없으면 안 올림)
    _backupTick = Timer.periodic(const Duration(minutes: 10), (_) {
      widget.controller.autoBackup();
      // 묶음 56: 파티 소식 · 문의 답 우편도 같은 때에
      _serverNews();
    });
    // 처음 켤 때 한 번 (불러오기가 끝난 뒤)
    _newsTimer = Timer(const Duration(seconds: 3), _serverNews);
  }

  Timer? _backupTick;
  Timer? _newsTimer;

  /// 묶음 56: 문의 답 우편 · 파티 소식 (인터넷이 없으면 조용히 넘어감)
  Future<void> _serverNews() async {
    final c = widget.controller;
    if (!mounted || !c.ready || c.needsAwakening) return;
    await c.checkLegalNotices();
    await c.refreshBannedWords();
    await c.checkInquiryInbox();
    await c.refreshParty();
    // 묶음 59: 공지 · 내 제재 상태 · 길드 소식
    await c.refreshNotices();
    await c.refreshMyStatus();
    await c.refreshGuild();
    // 묶음 60: 5막 에르바르드 (공성전 결과 · 3장)
    await c.refreshErbard();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _backupTick?.cancel();
    _newsTimer?.cancel();
    _tapSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool _farewellShowing = false;
  bool _jobShowing = false;
  bool _endingShowing = false;

  bool _petNewsShowing = false;

  /// 이번에 앱을 켠 동안 부화 창을 이미 띄운 알 (닫으면 가방에서 다시 연다)
  final _promptedEggs = <String>{};

  bool _walkShowing = false;
  DateTime? _shownFind;
  DateTime? _shownMerchant;

  bool _titleShowing = false;
  bool _bagHoldShowing = false; // 묶음 47 #240
  bool _petCodexNoticed = false;

  /// 앱으로 돌아올 때마다 걸음을 다시 읽는다
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.controller.ready) {
      widget.controller.sync();
      widget.controller.refreshServerTime();
      _serverNews();
    }
    // 묶음 55 #245: 앱을 닫을 때(뒤로 갈 때) 조용히 백업
    if (state == AppLifecycleState.paused) widget.controller.autoBackup();
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
        // 묶음 57: 기존 각성자 · 바뀐 문서 동의 (처음 각성은 각성 화면 안에서)
        if (!controller.needsAwakening && !controller.ageBlocked && controller.consentNeeded.isNotEmpty) {
          return ConsentScreen(controller: controller);
        }
        if (controller.ageBlocked) {
          return const Scaffold(
              body: NightBackground(child: AgeBlockedView()));
        }
        if (controller.needsAwakening) {
          _tab = tMap; // 기록을 지운 뒤 다시 시작하면 지도부터
          return AwakeningScreen(
            onTooYoung: controller.blockForAge,
            onConsent: () => controller.agreeLegal(LegalRules.needed(controller.consent.agreed, controller.now)),
            now: () => controller.now,
            onLoadRecord: controller.cloudAvailable ? (ctx) => loadRecordFlow(ctx, controller) : null,
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
        _maybeShowJobAwaken();
        _maybeShowAct2();
        _maybeShowJobNews();
        _maybeShowNotices();
        _maybeShowPetNews();
        _maybeShowWalkNews();
        _maybeShowInvite();
        tourBridge.paused = _popupBusy ||
            (controller.farewellPending && !controller.inTutorial) ||
            controller.jobAwakenPending;
        // 묶음 30: 직업 각성 뒤 숨겨 둔 직업 칸(#178 스위치)을 다시 보인다
        LockedJobPanel.jobsVisible = controller.jobsOpen;
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
            jobMpBar: controller.jobsOpen
                ? JobMpBar(controller: controller)
                : null,
            stats: controller.shownStats,
            unspentPoints: controller.unspentPoints,
            onOpenStats: () => push(StatScreen(controller: controller)),
            // 묶음 31 #198: 스킬 페이지 (첫 숙련된 또는 Lv.15 각성 뒤)
            onOpenSkills: controller.skillPageOpen
                ? () => push(SkillScreen(controller: controller))
                : null,
            skillDot: controller.skillPointsLeft > 0,
            // 묶음 25 #166: 원정 중이면 원정 대사 먼저 (HP 30% 아래만 그보다 앞)
            lifeLine: (controller.maxHp > 0 &&
                        controller.hp / controller.maxHp < 0.3
                    ? null
                    : controller.expeditionTalk ?? controller.masteryTalk ?? controller.walkTalk) ??
                controller.statusLifeLine,
            armory: controller.armory,
            onSlot: (slot) => showEquipPicker(context, controller, slot),
            restLeft: controller.resting ? controller.restLeft : null,
            spiritAway: _spiritAway(controller),
            equippedTitle: controller.equippedTitle,
            onOpenInn: () => push(InnScreen(controller: controller)),
            look: controller.profile.look,
            season: SeasonRules.of(controller.now),
            now: controller.now,
            requestPanel: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 묶음 43 #228: 오늘 하루 훈련 전이면 은은한 점 한 줄
                TrainingStatusRow(controller: controller),
                // 묶음 65 #252: 걸음 상자
                StepChestRow(controller: controller),
                NpcRequestPanel(controller: controller),
              ],
            ),
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
          // 묶음 38 #211: 마을 그림이 화면 전체 (위쪽 탑 그림 띠·카드 테두리 없음)
          VillageScreen(controller: controller, visits: villageVisits),
          NightBackground(
            header: true,
            child: CodexScreen(
              // 더 나오지 않는 정령계 몬스터는 도감에서 숨긴다 (하늘 슬라임은 보임, #168)
              purifiedMonsters: {
                for (final m in controller.purifiedEver)
                  if (Monsters.inCodex(m) || FieldMonsterRules.isTierMonster(m)) m,
              },
              highlandOpen: controller.highlandOpen,
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
            // 묶음 57: 약관이 곧 바뀌면 위쪽 배너
            if (controller.legalBanner != null)
              Positioned(
                top: topInset + 62,
                left: 12,
                right: 12,
                child: LegalChangeBanner(controller: controller),
              ),
            // 묶음 59: 운영 공지 띠 (약관 띠가 없을 때)
            if (controller.legalBanner == null && controller.noticeBanner != null)
              Positioned(
                top: topInset + 62,
                left: 12,
                right: 12,
                child: NoticeBanner(controller: controller),
              ),
            // 묶음 68 #275: 우편 옆 말풍선 (안 읽은 수 빨간 점 · 로그인했을 때만)
            Positioned(
              top: topInset + 6,
              right: 120,
              child: ChatButton(controller: controller),
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
          // 묶음 38 #211: 마을 탭은 그림이 아래 탭 막대 뒤까지 깔린다
          extendBody: _tab == tVillage,
          bottomNavigationBar: OrnateNavBar(
            overlay: _tab == tVillage,
            index: _tab,
            dots: {
              if (_tab != tStatus &&
                  ((controller.unspentPoints > 0 &&
                          controller.unspentPoints != _seenPoints) ||
                      (controller.skillPointsLeft > 0 &&
                          controller.skillPointsLeft != _seenSkillPoints)))
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
