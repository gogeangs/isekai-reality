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

  /// 확인하지 않은 레벨업이 있으면 화면이 그려진 뒤 연출을 띄운다
  void _maybeShowLevelUp() {
    final pending = widget.controller.pendingLevelUp;
    // 묶음 14 B6: 전투·던전 결과 화면을 닫은 뒤에 띄운다 (결과 글자와 겹치지 않게)
    if (pending == null || _popupBusy || widget.controller.holdNotices) {
      return;
    }
    _levelUpShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      // #102 레벨 업하면 HP·MP 가득 (창과 함께 한 번)
      final before = await widget.controller.levelUpHeal();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0xD9000000),
        builder: (_) => LevelUpDialog(
          from: pending.from,
          to: pending.to,
          healedFrom: before,
          title: widget.controller.equippedTitle == null
              ? null
              : TitleRules.info(widget.controller.equippedTitle!).name,
        ),
      );
      await widget.controller.acknowledgeLevelUp();
      _levelUpShowing = false;
      _kick();
    });
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

  /// 휴식이 끝났거나 정령이 돌아왔으면 한 번 알려 준다
  void _maybeShowNotices() {
    final c = widget.controller;
    if (_popupBusy || _ahead(2)) return;
    final done = c.finishedExpeditions;
    // 지도에서는 원정 띠가 반짝이고, 눌러야 결과 카드를 연다 (11-11 #78)
    // 튜토리얼 원정은 지도에 있어도 바로 결과 카드 (#151)
    final onMap = _tab == tMap &&
        !done.any((e) => AppController.isTutorialSpawn(e.spawnId));
    if (!c.justRested && (done.isEmpty || onMap)) return;
    _noticeShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (c.justRested) {
        // 가벼운 알림은 위쪽 띠로만 (#131)
        showTopNotice(context,
            '푹 쉬었어요 · HP·MP 가득, 휴식 보너스 경험치 +${RuleConstants.restBonusExp}');
        c.clearJustRested();
      } else {
        await _showExpeditionResults(done);
      }
      _noticeShowing = false;
      _kick();
    });
  }

  /// 처음 광고를 볼 때 한 번 (묶음 16): 이슬이 짧게 이유를 말하고, 아이폰은 애플 추적 허용 창.
  /// 거부하면 맞춤이 아닌 광고. 설정에서 바꿀 수 있다
  Future<bool> _adConsent() async {
    final c = widget.controller;
    final known = c.adPersonal;
    if (known != null || !mounted) return known ?? false;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (d) => GameAlert(
        key: const Key('adConsent'),
        title: Text(c.firstSpiritName),
        content: KText(
            ios
                ? '광고를 끝까지 보면 보상을 받을 수 있어! 곧 뜨는 창에서 허용하면 '
                    '관심 있는 광고가 나오고, 허용하지 않아도 보상은 똑같아.'
                : '광고를 끝까지 보면 보상을 받을 수 있어! 관심 있는 광고를 볼래? '
                    '허용하지 않아도 보상은 똑같아.',
            style: const TextStyle(color: AppColors.text)),
        actions: ios
            ? [
                TextButton(
                    key: const Key('adConsentYes'),
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('알겠어')),
              ]
            : [
                TextButton(
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('허용 안 함')),
                TextButton(
                    key: const Key('adConsentYes'),
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('허용')),
              ],
      ),
    );
    var personal = yes ?? false;
    if (ios) personal = await RewardedAds.requestTracking() ?? false;
    await c.setAdPersonal(personal);
    return personal;
  }

  /// 원정 결과 금테 카드 (11-11 #51). 여러 마리가 함께 돌아오면 차례로
  Future<void> _showExpeditionResults(List<Expedition> done) async {
    final c = widget.controller;
    for (final ex in done) {
      if (!mounted) break;
      await showExpeditionResult(context, ex, ex.petName ?? c.firstSpiritName,
          controller: c,
          more: done.length > 1
              ? '${done.indexOf(ex) + 1} / ${done.length}'
              : null);
      await c.acknowledgeExpedition(ex);
    }
  }

  bool _farewellShowing = false;

  /// Lv.11: 정령의 이별과 첫 펫 (11-11 #37). 레벨업·알림이 끝난 뒤에.
  void _maybeShowFarewell() {
    final c = widget.controller;
    if (!c.farewellPending || _popupBusy || _ahead(3)) {
      return;
    }
    _farewellShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => FarewellScreen(controller: c)));
      _farewellShowing = false;
      _kick();
    });
  }

  bool _petNewsShowing = false;

  /// 이번에 앱을 켠 동안 부화 창을 이미 띄운 알 (닫으면 가방에서 다시 연다)
  final _promptedEggs = <String>{};

  /// 알을 주웠을 때 · 정령 편지가 왔을 때 · 품은 알이 다 됐을 때
  void _maybeShowPetNews() {
    final c = widget.controller;
    if (_popupBusy || _ahead(3)) return;
    final letter = c.pendingLetter;
    var ready = c.farewellDone ? c.readyEgg : null;
    if (ready != null && _promptedEggs.contains(ready.id)) ready = null;
    final egg = c.takeNewEgg();
    if (egg) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTopNotice(context, c.farewellDone
              ? '펫 알을 주웠어요! 가방에서 품을 수 있어요.'
              : '반짝이는 신비한 알을 주웠어요. 가방에 넣어 둘게요.');
      });
    }
    if (letter == null && ready == null) return;
    _petNewsShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (letter != null) {
        c.takeNewLetter();
        await showDialog<void>(
          context: context,
          builder: (d) => GameAlert(
            title: Text('${c.firstSpiritName}의 편지 · ${letter.title}',
                style: AppText.title(19)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              // 정령의 편지 그림 (없으면 글만)
              Image.asset('assets/images/letter_spirit.webp',
                  height: 120,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              KText('${letter.body}\n\n함께 온 선물: ${letter.giftLabel}\n'
                  '선물은 우편함에서 받아요. 편지는 우편함 「편지」에 남아요.',
                  style: const TextStyle(color: AppColors.text, height: 1.45)),
            ]),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d), child: const Text('나중에')),
              TextButton(
                  onPressed: () {
                    Navigator.pop(d);
                    Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => MailScreen(controller: c)));
                  },
                  child: const Text('우편함 열기')),
            ],
          ),
        );
      } else if (ready != null) {
        _promptedEggs.add(ready.id);
        await showHatchSheet(context, c, ready);
      }
      _petNewsShowing = false;
      _kick();
    });
  }

  bool _walkShowing = false;
  DateTime? _shownFind;
  DateTime? _shownMerchant;

  /// 걸음 주머니 · 길가의 발견 · 떠돌이 상인 (11-11 #59)
  void _maybeShowWalkNews() {
    final c = widget.controller;
    if (_popupBusy || _ahead(3)) return;
    if (c.takeNewPouch()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTopNotice(context, '걷다가 주운 것들을 걸음 주머니에 담았어요. 가방에서 열어 보세요!');
      });
    }
    final find = c.findOpen ? c.gather.findUntil : null;
    final merchant = c.merchantHere ? c.gather.merchantUntil : null;
    if (find != null && find != _shownFind) {
      _shownFind = find;
      _walkShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final open = await showDialog<bool>(
          context: context,
          builder: (d) => GameAlert(
            title: Text('길가에서 반짝이는 것을 발견했어!', style: AppText.title(19)),
            content: const KText('30분 안에 열어 보면 받을 수 있어요.',
                style: TextStyle(color: AppColors.text)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('나중에')),
              TextButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('열어 보기')),
            ],
          ),
        );
        if (open == true) {
          final r = await c.openFind();
          if (mounted && r != null) {
            showTopNotice(context, gatherLine(r));
          }
        }
        _walkShowing = false;
        _kick();
      });
      return;
    }
    // 첫 알을 받으면 도감 펫 탭이 열린다 (11-11 #96)
    if (c.petCodexToAnnounce && !_petCodexNoticed && !c.quietTitles) {
      _petCodexNoticed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        c.markPetCodexAnnounced();
        showTopNotice(context, '새 도감이 열렸어요', icon: Icons.menu_book_rounded,
            onTap: () => setState(() => _openTab(tCodex)));
      });
    }
    // 떠돌이 상인 (11-11 #84): 창을 저절로 띄우지 않고 위쪽 띠만.
    // 누르면 지도로 가서 상인 자리를 보여 준다.
    if (merchant != null && merchant != _shownMerchant) {
      _shownMerchant = merchant;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTopNotice(
            context, '떠돌이 상인이 왔어요 · ${c.merchantMinutesLeft}분',
            icon: Icons.storefront_rounded, onTap: () {
          final at = c.merchantPoint;
          if (at == null) return;
          setState(() => _openTab(tMap));
          c.requestMapFocus(at);
        });
      });
    }
  }

  bool _titleShowing = false;
  bool _petCodexNoticed = false;

  /// 처음 HP가 절반 아래로 내려가면 회복 팁 한 번 (묶음 16 #141). 위쪽 띠로만
  void _maybeShowHpTip() {
    final c = widget.controller;
    if (c.holdNotices || !c.takeHpTip()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showTopNotice(context, 'HP가 절반 아래야. 여관에서 쉬거나 물약을 마셔 봐!',
          icon: Icons.favorite_rounded);
    });
  }



  /// 칭호를 새로 얻으면 화면 가운데 축하 연출 (11-11 #85).
  /// 전투 중에는 전투 결과를 닫은 뒤에, 여러 개면 하나씩 차례로.
  void _maybeShowTitle() {
    final c = widget.controller;
    final t = c.newTitle;
    if (t == null || _popupBusy || _ahead(1) || c.holdNotices) return;
    _titleShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _titleShowing = false;
        _kick();
        return;
      }
      if (c.quietTitles) {
        showTopNotice(context, '새 칭호 「${TitleRules.info(t).name}」',
            icon: Icons.military_tech_rounded);
      } else {
        await showTitleCelebration(context, c, t);
      }
      await c.acknowledgeTitle(t);
      _titleShowing = false;
      _kick();
      if (mounted) _maybeShowTitle();
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
      showTopNotice(context, '가방이 가득 찼어요. 새로 얻은 재료는 금화로 바꿨어요. 금화 +${comma(g)}');
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
                height: topInset + 62,
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

  /// 알림 하나를 눌렀을 때: 원정 → 지도 결과 카드, 휴식 → 상태, 알 → 가방,
  /// 편지 → 우편함, 의뢰 → 마을 의뢰 게시판, 그 밖 → 지도
  Future<void> _openFromNotice(int id) async {
    final c = widget.controller;
    // 시작 화면(불러오는 중)이면 다 켜진 뒤에
    for (var i = 0; i < 40 && !c.ready && mounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted || !c.ready || c.needsAwakening) return;
    void push(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    Navigator.of(context).popUntil((r) => r.isFirst);
    switch (NotifyId.targetOf(id)) {
      case NotifyTarget.expedition:
        setState(() => _openTab(tMap));
        await c.refreshVitals();
        if (mounted && c.finishedExpeditions.isNotEmpty) await _showResultsNow();
      case NotifyTarget.status:
        setState(() => _openTab(tStatus));
      case NotifyTarget.bag:
        setState(() => _openTab(tBag));
      case NotifyTarget.mail:
        push(MailScreen(controller: c));
      case NotifyTarget.board:
        setState(() => _openTab(tVillage));
        push(BoardScreen(controller: c));
      case NotifyTarget.map:
        setState(() => _openTab(tMap));
    }
  }

  /// 돌아온 원정 결과 카드 (지도 띠·튜토리얼에서)
  Future<void> _showResultsNow() async {
    if (_noticeShowing) return;
    _noticeShowing = true;
    await _showExpeditionResults(widget.controller.finishedExpeditions);
    _noticeShowing = false;
    _kick();
  }
}

/// 상태창에 보여 줄 원정 한 줄 (원정 중이 아니면 null)
String? _spiritAway(AppController c) {
  final ex = c.expedition;
  if (ex == null || ex.finished) return null;
  final left = ex.returnAt.difference(c.now);
  final m = left.inMinutes < 1 ? 1 : left.inMinutes;
  return '${c.companionName} 원정 중 · $m분 뒤 돌아와요';
}

/// 하단 메뉴: 금테 막대, 고른 메뉴는 금색 상자 (목업 구도)
class OrnateNavBar extends StatelessWidget {
  const OrnateNavBar(
      {super.key,
      required this.index,
      required this.onTap,
      this.dots = const {},
      this.dimmed = const {}});

  final int index;
  final ValueChanged<int> onTap;

  /// 빨간 점을 찍을 메뉴 (묶음 16 #130)
  final Set<int> dots;

  /// 튜토리얼 동안 흐리게 막아 둔 메뉴 (묶음 16 #125)
  final Set<int> dimmed;

  /// 가운데 지도 메뉴 자리
  static const mapIndex = 2;

  /// (그림, 이름). 마을·가방 전용 메뉴 그림(nav_village, nav_bag)이 오기 전에는
  /// 여관·가방 아이콘으로 대신한다.
  static const items = [
    ('nav_status', '상태'),
    ('nav_bag', '가방'),
    ('nav_map', '지도'),
    ('nav_village', '마을'),
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
        color: AppColors.deepNight,
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
                    // 가운데 지도는 조금 넓고 그림도 조금 크게
                    flex: i == mapIndex ? 6 : 5,
                    child: KeyedSubtree(
                     key: tutorialNavKeys[i],
                     child: Semantics(
                      selected: i == index,
                      button: true,
                      child: Opacity(
                       opacity: dimmed.contains(i) ? 0.3 : 1,
                       child: InkWell(
                        key: Key('nav_$i'),
                        onTap: dimmed.contains(i) ? null : () => onTap(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: i == mapIndex ? 58 : 54,
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
                              Stack(clipBehavior: Clip.none, children: [
                                Opacity(
                                  opacity: i == index || i == mapIndex ? 1 : 0.7,
                                  child: Image.asset(
                                      'assets/images/${items[i].$1}.webp',
                                      width: i == mapIndex ? 36 : 30,
                                      height: i == mapIndex ? 36 : 30,
                                      errorBuilder: (_, __, ___) => Image.asset(
                                          'assets/images/${_fallback[items[i].$1] ?? 'icon_quest'}.webp',
                                          width: 30,
                                          height: 30,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.circle_outlined,
                                                  color: AppColors.text))),
                                ),
                                if (dots.contains(i))
                                  Positioned(
                                    key: Key('navDot_$i'),
                                    right: -3,
                                    top: -2,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE53935),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 1.2),
                                      ),
                                    ),
                                  ),
                              ]),
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

