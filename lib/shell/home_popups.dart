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

  /// Lv.11: 정령의 이별과 첫 펫 (11-11 #37). 레벨업·알림이 끝난 뒤에.
  void _maybeShowFarewell() {
    final c = widget.controller;
    if (!c.farewellPending || _popupBusy || _ahead(3) || c.inTutorial) {
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

  /// 알을 주웠을 때 · 정령 편지가 왔을 때 · 품은 알이 다 됐을 때
  void _maybeShowPetNews() {
    final c = widget.controller;
    if (_popupBusy || _ahead(3) || c.inTutorial) return;
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

  /// 걸음 주머니 · 길가의 발견 · 떠돌이 상인 (11-11 #59)
  void _maybeShowWalkNews() {
    final c = widget.controller;
    if (_popupBusy || _ahead(3) || c.inTutorial) return;
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
            onTap: () => _set(() => _openTab(_HomeShellState.tCodex)));
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
        if (mounted && c.finishedExpeditions.isNotEmpty) await _showResultsNow();
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
