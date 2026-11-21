part of '../app.dart';

/// 홈 화면 위에 차례로 뜨는 창·띠 (묶음 21: app.dart 에서 나눔).
/// 순서는 #131: 레벨업 → 칭호 → 원정 → 편지(그 밖). 튜토리얼 중에는 모아 둔다.
extension _ShellPopups on _HomeShellState {
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
      // #102 레벨 업하면 HP·기력 가득 (창과 함께 한 번)
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
      // 묶음 57: 「기록 지키기」 — 정령이 로그인을 권함 (로그인 → 백업 동의)
      final ask = widget.controller.loginAskFor(pending.from, pending.to);
      if (ask != null && mounted) {
        await widget.controller.markLoginAsked(ask);
        if (mounted) await _keepRecord(ask);
      }
      // 묶음 70 #291: Lv.8 친구 장면 (로그인 안 했으면 「기록 지키기」와 함께)
      if (mounted &&
          pending.from < ChatRules.friendLevel &&
          pending.to >= ChatRules.friendLevel &&
          !widget.controller.friendSceneSeen) {
        await widget.controller.markFriendScene();
        if (mounted) await _friendScene();
      }
      _levelUpShowing = false;
      _kick();
    });
  }

  /// 묶음 70 #291: Lv.8 친구 장면 — 정령 한마디 → (로그인 안 했으면) 기록 지키기 → 친구 화면 안내
  Future<void> _friendScene() async {
    final c = widget.controller;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xF2050614), // 묶음 72: 뒤 화면 글자가 비치지 않게
      builder: (d) => SpiritLineAlert(
        key: const Key('friendScene'),
        spiritName: c.firstSpiritName,
        line: '요즘 걷는 길이 좀 심심하지 않아? 함께 걸을 친구가 있으면 더 멀리 갈 수 있을 거야!',
        actions: [(const Key('friendSceneOk'), '응!', () => Navigator.pop(d))],
      ),
    );
    if (!mounted) return;
    if (!c.chatOpen) {
      if (!c.cloudAvailable) return;
      await _keepRecord(8, line: '친구를 사귀려면 기록을 지켜 둬야 해!');
      if (!mounted || !c.chatOpen) return;
    }
    friendTourOn.value = true;
    await openChat(context, c, tab: 1);
    friendTourOn.value = false;
  }

  Future<void> _keepRecord(int level, {String? line}) async {
    final c = widget.controller;
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: line != null ? const Color(0xF2050614) : null,
      builder: (d) => line != null
          // 묶음 71: Lv.8 친구 장면에 이어서는 정령 얼굴 + 말풍선
          ? SpiritLineAlert(
              key: const Key('keepRecord'),
              spiritName: c.firstSpiritName,
              line: line,
              actions: [
                (
                  const Key('keepRecordLogin'),
                  '로그인',
                  () => Navigator.pop(d, true)
                ),
                (
                  const Key('keepRecordLater'),
                  '나중에',
                  () => Navigator.pop(d, false)
                ),
              ],
            )
          : GameAlert(
              key: const Key('keepRecord'),
              title: Text('${c.firstSpiritName} · 기록 지키기'),
              content: KText(
                  line ??
                      (level >= 8
                          ? '아직 우리 기록이 이 휴대폰에만 있어. 휴대폰을 바꾸거나 앱을 지우면 사라져. 지금 지켜 둘래?'
                          : '여기까지 잘 왔어! 로그인해 두면 휴대폰을 바꾸거나 앱을 다시 깔아도 이 기록 그대로 이어서 할 수 있어.'),
                  style: const TextStyle(color: AppColors.text, height: 1.45)),
              actions: [
                TextButton(
                    key: const Key('keepRecordLogin'),
                    onPressed: () => Navigator.pop(d, true),
                    child: const Text('로그인')),
                TextButton(
                    key: const Key('keepRecordLater'),
                    onPressed: () => Navigator.pop(d, false),
                    child: const Text('나중에')),
              ],
            ),
    );
    if (yes != true || !mounted) return;
    final p = await showModalBottomSheet<LoginProvider>(
      context: context,
      backgroundColor: AppColors.deepNight,
      builder: (s) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in c.loginProviders) ...[
                  LoginButton(
                      provider: p, onPressed: () => Navigator.pop(s, p)),
                  const SizedBox(height: 8),
                ],
              ]),
        ),
      ),
    );
    if (p != null && mounted) await signInFlow(context, c, p);
  }

  /// 휴식이 끝났거나 정령이 돌아왔으면 한 번 알려 준다
  void _maybeShowNotices() {
    final c = widget.controller;
    if (_popupBusy || _ahead(2)) return;
    final done = c.finishedExpeditions;
    // 묶음 20 #160: 튜토리얼 중에는 튜토리얼 원정 결과만 (나머지는 끝난 뒤)
    if (c.inTutorial &&
        !done.any((e) => AppController.isTutorialSpawn(e.spawnId))) {
      return;
    }
    // 지도에서는 원정 띠가 반짝이고, 눌러야 결과 카드를 연다 (11-11 #78)
    // 튜토리얼 원정은 지도에 있어도 바로 결과 카드 (#151)
    final onMap = _tab == _HomeShellState.tMap &&
        !done.any((e) => AppController.isTutorialSpawn(e.spawnId));
    if (!c.justRested && (done.isEmpty || onMap)) return;
    _noticeShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (c.justRested) {
        // 가벼운 알림은 위쪽 띠로만 (#131)
        showTopNoticeQueued(context,
            c.jobsOpen ? '푹 쉬었어요 · HP · MP · 기력이 가득 찼어요' : '푹 쉬었어요 · HP · 기력이 가득 찼어요');
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

  /// Lv.11: 정령의 이별 컷신과 첫 펫 (묶음 29 #182). 레벨업 창 바로 다음,
  /// 칭호·원정·편지 같은 다른 창은 그 뒤로.
  void _maybeShowFarewell() {
    final c = widget.controller;
    if (!c.farewellPending ||
        _popupBusy ||
        c.pendingLevelUp != null ||
        c.holdNotices ||
        c.inTutorial) {
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

  /// Lv.15 직업 각성 (묶음 30 #55): 레벨업 창(·이별 컷신) 바로 다음
  void _maybeShowJobAwaken() {
    final c = widget.controller;
    if (!c.jobAwakenPending ||
        _popupBusy ||
        c.pendingLevelUp != null ||
        c.holdNotices) {
      return;
    }
    _jobShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => JobAwakenScreen(controller: c)));
      _jobShowing = false;
      _kick();
    });
  }

  /// 묶음 34: 결말을 보다 앱을 껐으면 다음에 켤 때 다시 · 결말 뒤 Lv.21이 되면 한 줄
  void _maybeShowAct2() {
    final c = widget.controller;
    if (_popupBusy ||
        c.pendingLevelUp != null ||
        c.holdNotices ||
        c.inTutorial) {
      return;
    }
    if (c.endingPending) {
      _endingShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => EndingScreen(controller: c)));
        _endingShowing = false;
        _kick();
      });
      return;
    }
    if (c.bridgePending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !c.bridgePending) return;
        unawaited(c.markBridgeShown());
        showTopNoticeQueued(context, Act2Rules.bridgeLine,
            icon: Icons.auto_awesome);
      });
      return;
    }
    // 묶음 50 #146: 처음 하늘에 섬이 뜨면 짧은 장면 한 번 (예전 Lv.17 이상도)
    if (c.highlandScenePending) {
      _endingShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => HighlandSceneScreen(controller: c)));
        _endingShowing = false;
        _kick();
      });
      return;
    }
    // 묶음 59 #246: 4막 장면 (조건이 맞으면 한 번씩)
    final a4 = c.pendingAct4Scene ?? c.pendingAct5Scene;
    if (a4 != null) {
      final act = c.pendingAct4Scene != null ? 4 : 5;
      _endingShowing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if ((act == 4 ? c.pendingAct4Scene : c.pendingAct5Scene)?.id == a4.id) {
          await Navigator.of(context).push(MaterialPageRoute<void>(
              fullscreenDialog: true,
              builder: (_) =>
                  Act4SceneScreen(controller: c, scene: a4, act: act)));
        }
        _endingShowing = false;
        _kick();
      });
    }
  }

  /// 새 직업 · 견습을 뗌 · 순례자가 찾은 물건 (위쪽 띠)
  void _maybeShowJobNews() {
    final c = widget.controller;
    if (_popupBusy || _ahead(3) || c.holdNotices) return;
    // 묶음 61: 가짜 위치 띠 (한 번)
    if (c.takeMockBanner()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showTopNoticeQueued(context, FairOps.mockLine,
              icon: Icons.location_off_rounded);
        }
      });
    }
    final find = c.takeJobFind();
    final note = c.hasJobNotice ? c.takeJobNotice() : null;
    // 묶음 35: 새 직업 띠엔 직업 문장
    final art = note == null ? null : c.jobNoticeArt;
    if (note == null && !find) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (note != null) {
        showTopNoticeQueued(context, note,
            icon: Icons.workspace_premium_rounded, image: art);
      }
      if (find) showTopNoticeQueued(context, '길에서 숨은 물건을 찾았어요!');
    });
  }

  /// 알을 주웠을 때 · 정령 편지가 왔을 때 · 품은 알이 다 됐을 때
  void _maybeShowPetNews() {
    final c = widget.controller;
    if (_popupBusy || _ahead(3) || c.inTutorial) return;
    final letter = c.pendingLetter;
    var ready = c.farewellDone ? c.readyEgg : null;
    if (ready != null && _promptedEggs.contains(ready.id)) ready = null;
    // 묶음 43 #228: 펫 훈련이 끝나면 위쪽 띠 한 번
    final trained = c.takePetTrainedNotice();
    if (trained != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showTopNoticeQueued(context, '${josa(trained, '이/가')} 훈련을 마쳤어요');
        }
      });
    }
    // 묶음 45 #231·#232: 마을 사람 작은 부탁 · 특별한 부탁 다음 단계 (위쪽 띠 한 번)
    final stage = c.takeRelicStageNotice();
    final small = c.takeSmallNotice();
    if (stage != null || small != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (stage != null) {
          showTopNoticeQueued(
              context, '${VillageRules.npc(stage.$1).name} · 「${stage.$2}」');
        }
        if (small != null) {
          showTopNoticeQueued(context,
              '${josa(VillageRules.npc(small).name, '이/가')} 작은 부탁이 있대요');
        }
      });
    }
    // 묶음 75 #327: 전투 결과 창이 보여 준 알은 건너뜀 (홈 화면이 맨 위일 때만)
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    final eggMailed = c.takeEggMailed();
    if (eggMailed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showTopNoticeQueued(context, '가방이 가득해서 알을 우편함에 넣어 뒀어요', icon: Icons.mail_rounded);
        }
      });
    }
    final egg = onTop && c.takeNewEgg();
    final newest = c.newestEgg;
    if (egg) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (!c.farewellDone || newest == null) {
          showTopNoticeQueued(context, '반짝이는 신비한 알을 주웠어요. 가방에 넣어 둘게요.');
          return;
        }
        // 전투 밖(주간 의뢰 · 우편): 알 그림 작은 창 「알을 얻었어요!」
        _petNewsShowing = true;
        await showEggGotDialog(context, c, newest.grade);
        _petNewsShowing = false;
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
              KText(
                  '${letter.body}\n\n함께 온 선물: ${letter.giftLabel}\n'
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

  /// 걸음 주머니 · 길가의 발견 · 떠돌이 상인 (11-11 #59)
  /// 묶음 57: 초대 링크로 열렸으면 「파티에 들어갈까요?」
  void _maybeShowInvite() {
    final c = widget.controller;
    if (!_popupBusy && !c.inTutorial && c.pendingGuildInvite != null) {
      return _guildInvite();
    }
    if (_popupBusy || c.inTutorial || c.pendingInvite == null) return;
    final code = c.takeInvite()!;
    _walkShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final yes = await showDialog<bool>(
        context: context,
        builder: (d) => GameAlert(
          key: const Key('inviteJoin'),
          title: Text('파티에 들어갈까요?', style: AppText.title(19)),
          content: KText(
              c.cloud.signedIn
                  ? '초대 코드 $code 파티에 들어가요.'
                  : '초대 코드 $code 파티에 들어가려면 로그인이 필요해요. 주점 파티 탭으로 갈게요.',
              style: const TextStyle(color: AppColors.text)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: const Text('나중에')),
            TextButton(
                key: const Key('inviteJoinYes'),
                onPressed: () => Navigator.pop(d, true),
                child: const Text('들어가기')),
          ],
        ),
      );
      if (yes == true && mounted) {
        if (c.cloud.signedIn &&
            c.party == null &&
            await c.joinParty(code) &&
            mounted) {
          showTopNoticeQueued(context, '파티에 들어갔어요!');
        }
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => TavernScreen(
                  controller: c, partyTab: true, inviteCode: code)));
        }
      }
      _walkShowing = false;
      _kick();
    });
  }

  /// 묶음 60: 길드 초대 링크로 열렸으면 「길드에 들어갈까요?」
  void _guildInvite() {
    final c = widget.controller;
    final code = c.takeGuildInvite()!;
    _walkShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final open = c.canJoinGuildByCode;
      final yes = await showDialog<bool>(
        context: context,
        builder: (d) => GameAlert(
          key: const Key('guildInviteJoin'),
          title: Text('길드에 들어갈까요?', style: AppText.title(19)),
          content: KText(
              !open
                  ? '초대 코드 $code 길드는 4막 2장 「빈 터」 장면 뒤에 들어갈 수 있어요.'
                  : c.cloud.signedIn
                      ? '초대 코드 $code 길드에 들어가요.'
                      : '초대 코드 $code 길드에 들어가려면 로그인이 필요해요. 길드 회관으로 갈게요.',
              style: const TextStyle(color: AppColors.text)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(d, false),
                child: Text(open ? '나중에' : '확인')),
            if (open)
              TextButton(
                  key: const Key('guildInviteYes'),
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('들어가기')),
          ],
        ),
      );
      if (yes == true && mounted) {
        if (c.cloud.signedIn &&
            !(c.guild?.inGuild ?? false) &&
            await c.joinGuild(code: code) &&
            mounted) {
          showTopNoticeQueued(context, '길드에 들어갔어요!');
        }
        if (mounted) {
          await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) =>
                  GuildHallScreen(controller: c, inviteCode: code)));
        }
      }
      _walkShowing = false;
      _kick();
    });
  }

  void _maybeShowWalkNews() {
    final c = widget.controller;
    if (_popupBusy || _ahead(3) || c.inTutorial) return;
    if (c.takeNewPouch()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTopNoticeQueued(context, '걷다가 주운 것들을 걸음 주머니에 담았어요. 가방에서 열어 보세요!');
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
            showTopNoticeQueued(context, gatherLine(r));
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
        showTopNoticeQueued(context, '새 도감이 열렸어요',
            icon: Icons.menu_book_rounded,
            onTap: () => _set(() => _openTab(_HomeShellState.tCodex)));
      });
    }
    // 묶음 70 #293: 처음 발견하면 위쪽 띠 「도감에 새로 올랐어요 · ○○」
    final news = c.codexToAnnounce;
    if (news.isNotEmpty && !_codexNoticing) {
      _codexNoticing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await c.markCodexAnnounced();
        for (final n in news) {
          if (!mounted) break;
          showTopNoticeQueued(context, '도감에 새로 올랐어요 · $n',
              icon: Icons.menu_book_rounded,
              onTap: () => _set(() => _openTab(_HomeShellState.tCodex)));
        }
        _codexNoticing = false;
      });
    }
    // 떠돌이 상인 (11-11 #84): 창을 저절로 띄우지 않고 위쪽 띠만.
    // 누르면 지도로 가서 상인 자리를 보여 준다.
    if (merchant != null && merchant != _shownMerchant) {
      _shownMerchant = merchant;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showTopNoticeQueued(context, '떠돌이 상인이 왔어요 · ${c.merchantMinutesLeft}분',
            icon: Icons.storefront_rounded, onTap: () {
          final at = c.merchantPoint;
          if (at == null) return;
          _set(() => _openTab(_HomeShellState.tMap));
          c.requestMapFocus(at);
        });
      });
    }
  }

  /// 처음 HP가 절반 아래로 내려가면 회복 팁 한 번 (묶음 16 #141). 위쪽 띠로만
  void _maybeShowHpTip() {
    final c = widget.controller;
    if (c.holdNotices || !c.takeHpTip()) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showTopNoticeQueued(context, 'HP가 절반 아래야. 여관에서 쉬거나 물약을 마셔 봐!',
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
      // 묶음 27 #176: 예전 기록 시작 값으로 얻은 숙련도 칭호도 조용히 띠로
      if (c.titleIsQuiet(t)) {
        showTopNoticeQueued(context, '새 칭호 「${TitleRules.info(t).name}」',
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

  /// 묶음 47 #240: 가방이 가득 찼을 때.
  /// 의뢰·이야기 보상 · 알 · 장비를 우편함에 맡겼으면 위쪽 띠로 알리고,
  /// 들어가지 못한 재료·물건이 새로 생겼으면 「가방이 가득 찼어요」 창을 띄운다
  /// (홈 화면이 맨 위일 때, 다른 창이 끝난 뒤. 튜토리얼 중에는 모아 둔다)
  void _maybeShowBagFull() {
    final c = widget.controller;
    if (c.pendingBagMailed > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || c.takeBagMailed() <= 0) return;
        showTopNoticeQueued(context, '가방이 가득 차서 우편함에 맡겨 뒀어요. 자리를 만든 뒤 받아 가세요.',
            icon: Icons.mail_rounded);
      });
    }
    if (!c.bagHoldNew ||
        _popupBusy ||
        _ahead(3) ||
        c.holdNotices ||
        c.inTutorial ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _bagHoldShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !c.bagHoldNew) {
        _bagHoldShowing = false;
        return;
      }
      await showBagHoldSheet(context, c,
          onOpenBag: () => _set(() => _openTab(_HomeShellState.tBag)));
      _bagHoldShowing = false;
      _kick();
    });
  }

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
        _set(() => _openTab(_HomeShellState.tMap));
        await c.refreshVitals();
        if (mounted && c.finishedExpeditions.isNotEmpty) {
          await _showResultsNow();
        }
      case NotifyTarget.status:
        _set(() => _openTab(_HomeShellState.tStatus));
      case NotifyTarget.bag:
        _set(() => _openTab(_HomeShellState.tBag));
      case NotifyTarget.mail:
        push(MailScreen(controller: c));
      case NotifyTarget.board:
        _set(() => _openTab(_HomeShellState.tVillage));
        push(BoardScreen(controller: c));
      case NotifyTarget.map:
        _set(() => _openTab(_HomeShellState.tMap));
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
