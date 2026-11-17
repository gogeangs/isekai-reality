part of '../app_controller.dart';

/// 우편 (묶음 21: [AppController] 에서 나눔. 상태 칸은 본체에 있다)
extension MailOps on AppController {

  MailState get mail => _mail;

  Future<void> _saveMail(MailState m) async {
    _mail = m;
    await store.saveJson(AppController._mailKey, m.toJson());
    _notify();
  }

  /// 새 우편이 있는지 (읽지 않았거나 받을 선물이 있으면 빨간 점)
  bool get hasNewMail => _mail.mails.any((m) => !m.read || m.hasGifts);

  /// 선물 탭: 받을 선물이 남은 우편 (사라질 날이 가까운 것부터)
  List<MailItem> get giftMails => [
        for (final m in _mail.mails)
          if (m.hasGifts) m,
      ]..sort((a, b) => (a.expiresAt ?? DateTime(9999))
          .compareTo(b.expiresAt ?? DateTime(9999)));

  /// 우편함 한 목록 (11-11 #100): 선물과 편지를 함께, 새것부터
  List<MailItem> get allMails => [..._mail.mails]
    ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  /// 편지·공지 (새것부터)
  List<MailItem> get letterMails => [
        for (final m in _mail.mails)
          if (m.kind != MailKind.reward) m,
      ]..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  /// 우편을 보낸다 (같은 id는 한 번만)
  Future<bool> _sendMail(MailItem m) async {
    if (_mail.sent.contains(m.id)) return false;
    await _saveMail(_mail.copyWith(
      mails: [m, ..._mail.mails],
      sent: [..._mail.sent, m.id],
    ));
    return true;
  }

  Future<void> readMail(String id) async {
    if (!_mail.mails.any((m) => m.id == id && !m.read)) return;
    await _saveMail(_mail.copyWith(mails: [
      for (final m in _mail.mails) m.id == id ? m.copyWith(read: true) : m,
    ]));
  }

  /// 우편 선물을 받는다. 받은 것 글을 돌려준다 (못 받으면 null).
  /// 금화·마석·경험치는 늘 받는다. 묶음 47 #240: 가방에 들어가지 않는 것은
  /// 금화로 바꾸지 않고 우편에 그대로 남겨 둔다 (자리가 나면 다시 받기)
  Future<String?> claimMail(String id) =>
      _serial(() async {
    final i = _mail.mails.indexWhere((m) => m.id == id);
    if (i < 0 || !_mail.mails[i].hasGifts) return null;
    final m = _mail.mails[i];
    final r = await _applyGiftsSplit(m.gifts);
    // 장비: 칸이 있는 만큼
    final eqLeft = <EquipItem>[];
    var a = _armory;
    for (final e in m.equips) {
      if (bagFree > 0) {
        a = a.copyWith(items: [...a.items, e]);
        await _saveArmory(a);
        r.got.add(EquipmentRules.info(e.base).name);
      } else {
        eqLeft.add(e);
      }
    }
    final done = r.left.isEmpty && eqLeft.isEmpty;
    // 11-11 #100: 받은 뒤에도 편지는 계속 보관한다 (보상 우편도 편지처럼)
    await _saveMail(_mail.copyWith(mails: [
      for (final x in _mail.mails)
        if (x.id != id)
          x
        else if (done)
          x.copyWith(claimed: true, read: true, gifts: m.gifts, equips: m.equips)
        else
          x.copyWith(read: true, gifts: r.left, equips: eqLeft),
    ]));
    if (!done) r.got.add('(가방이 가득해 ${r.left.length + eqLeft.length}가지는 우편에 남겨 뒀어요)');
    return r.got.join(', ');
  });

  /// 선물을 준다 (우편·마을 사람 부탁 · 훈련장). 받은 것 글 목록을 돌려준다.
  /// 금화·마석·경험치는 늘 받는다. 묶음 47 #240: 가방에 남는 자리가 없으면
  /// [over] 대로 — 의뢰·이야기 보상은 우편함([BagOver.mail]), 그 밖은 「가방이 가득 찼어요」 창
  Future<List<String>> _applyGifts(Map<String, int> gifts,
      {BagOver over = BagOver.mail, String? title}) async {
    final r = await _applyGiftsSplit(gifts);
    if (r.left.isNotEmpty) {
      await _bagOverflowTo(r.left, over: over, title: title);
      r.got.add(over == BagOver.mail
          ? '(가방이 가득해 ${r.left.length}가지는 우편함에)'
          : '(가방이 가득해 ${r.left.length}가지는 받지 못했어요)');
    }
    return r.got;
  }

  /// 선물을 주고, 가방에 들어가지 못한 것([left])을 돌려준다
  Future<({List<String> got, Map<String, int> left})> _applyGiftsSplit(
      Map<String, int> gifts) async {
    final got = <String>[];
    var gold = 0, mana = 0, exp = 0, notes = 0;
    var tools = false;
    var foot = 0, recruit = 0;
    final bag = <String, int>{};
    gifts.forEach((k, v) {
      if (k == Wallet.gold) {
        gold += v;
      } else if (k == Wallet.manaStone) {
        mana += v;
      } else if (k == Wallet.exp) {
        exp += v;
      } else if (k == 'note') {
        notes += v;
      } else if (k == 'tools') {
        tools = true;
      } else if (k == 'footTicket') {
        foot += v;
      } else if (k == 'recruit') {
        recruit += v;
      } else if (_bagKey(k)) {
        bag[k] = (bag[k] ?? 0) + v;
      }
    });
    final s = _splitBag(bag);
    await _giveBag(s.fit);
    if (gold > 0 || mana > 0 || exp > 0) {
      final today = await _todayRecord();
      await _save(today.copyWith(
        gains: DailyRecord.addCounts(today.gains, {
          if (gold > 0) Wallet.gold: gold,
          if (mana > 0) Wallet.manaStone: mana,
          if (exp > 0) Wallet.exp: exp,
        }),
      ));
    }
    if (notes > 0) {
      await _savePets(_pets.copyWith(recipeNotes: _pets.recipeNotes + notes));
    }
    if (gold > 0) got.add('금화 $gold');
    if (mana > 0) got.add('마석 $mana');
    if (exp > 0) got.add('경험치 $exp');
    for (final e in s.fit.entries) {
      got.add('${_giftName(e.key)} ${e.value}');
    }
    if (tools) {
      await makeFirstTools(); // 이미 있으면 그대로
      got.add('채집 도구 한 벌');
    }
    if (notes > 0) got.add('레시피 쪽지 $notes');
    // 묶음 56: 발자국 표 · 모집권 (문의 답 · 파티 보상)
    if (foot > 0) {
      await _savePartyLocal(_partyLocal.copyWith(tickets: _partyLocal.tickets + foot));
      got.add('발자국 표 $foot');
    }
    if (recruit > 0) {
      _act3 = _act3.copyWith(tickets: _act3.tickets + recruit);
      await _saveAct3();
      got.add('모집권 $recruit');
    }
    return (got: got, left: s.rest);
  }

  /// 선물 키 → 이름
  String _giftName(String k) {
    if (k == 'egg') return '알';
    if (k.startsWith('alc:')) return potionName(k.substring(4));
    if (k.startsWith('item:')) {
      final it = _shopItemNamed(k.substring(5));
      return it == null ? k : itemName(it);
    }
    final m = Materials.byName(k);
    return m == null ? k : Materials.info(m).name;
  }

  /// 모두 받기
  Future<int> claimAllMail() =>
      _serial(() async {
    var n = 0;
    for (final m in giftMails) {
      if (await claimMail(m.id) != null) n++;
    }
    return n;
  });

  /// 우편 보내기·정리 (앱을 열 때·화면을 볼 때)
  Future<void> _checkMail() async {
    final now = _clock();
    // 30일 지나도록 받지 않은 물건이 든 편지는 사라진다 (받은 편지는 계속 보관)
    bool gone(MailItem m) =>
        m.hasGifts && m.expiresAt != null && now.isAfter(m.expiresAt!);
    if (_mail.mails.any(gone)) {
      await _saveMail(_mail.copyWith(mails: [
        for (final m in _mail.mails)
          if (!gone(m)) m,
      ]));
    }
    // 운영 우편 (공지·보상)
    for (final src in mailSources) {
      for (final m in await src.fetch(now)) {
        await _sendMail(m);
      }
    }
    await _checkNpcLetters();
    // 묶음 22: 도구가 없는 기존 사용자에게 채집 도구 한 벌 (한 번만)
    if (_legacyGates && !_harvest.granted && !gotGift(Gift.firstTools)) {
      await _sendMail(MailItem(
        id: 'toolsGift',
        kind: MailKind.letter,
        from: MailRules.hart,
        title: '채집 도구 한 벌',
        body: '이제 채집에는 도구가 있어야 해요. 낫·곡괭이·도끼·낚싯대·붓을 한 벌 보내요. '
            '받으면 바로 꽃과 버섯을 딸 수 있어요.',
        gifts: const {'tools': 1},
        sentAt: now,
      ));
    }
  }

  Future<void> _npc(NpcLetter l) => _sendMail(MailItem(
        id: l.id,
        kind: MailKind.letter,
        from: l.from,
        title: l.title,
        body: l.body,
        gifts: l.gifts,
        sentAt: _clock(),
      ));

  Future<void> _checkNpcLetters() async {
    var errands = 0, shopping = 0;
    for (final r in _history) {
      errands += (r.counters['errandDone'] ?? 0) + (r.counters['urgentDone'] ?? 0);
      shopping += r.goldPurchases.length;
    }
    for (final e in NpcLetter.errandThanks.entries) {
      if (errands >= e.key) await _npc(e.value);
    }
    if (shopping >= 10) await _npc(NpcLetter.minaThanks);
    if (player.level.level >= 3) await _npc(NpcLetter.minaRumor);
    if (_armory.crafts >= 1) await _npc(NpcLetter.dorgunFirst);
    if (_alc.discovered.isNotEmpty) await _npc(NpcLetter.elielFirst);
    if (urgent != null) await _npc(NpcLetter.hartUrgent);
  }

  /// 어제까지 다 하고 못 받은 수시·긴급 의뢰 보상을 우편으로 (날이 바뀔 때)
  Future<void> _mailExpiredBoard() async {
    final old = _board;
    final todayKey = DailyRecord.dayKeyOf(_clock());
    if (old.day.isEmpty || old.day == todayKey) return;
    DailyRecord? rec;
    for (final r in _history) {
      if (r.dayKey == old.day) rec = r;
    }
    if (rec != null) {
      for (var i = 0; i < old.slots.length; i++) {
        final s = old.slots[i];
        final t = BoardRules.template(s.templateId);
        if (t == null || !s.accepted) continue;
        if (BoardRules.progress(t, rec, s.baseline) < t.target) continue;
        await _sendMail(MailItem(
          id: 'board_${old.day}_$i',
          kind: MailKind.reward,
          from: MailRules.hart,
          title: '받지 못한 의뢰 보상: ${t.title}',
          body: '기한이 끝나 우편으로 보내네. 다음엔 게시판에서 바로 받아 가게.',
          gifts: {
            if (t.gold > 0) Wallet.gold: t.gold,
            if (t.manaStones > 0) Wallet.manaStone: t.manaStones,
            for (final e in t.materials.entries) e.key.name: e.value,
          },
          sentAt: _clock(),
          expiresAt: _clock().add(MailRules.rewardKeep),
        ));
      }
      final day = DateTime.tryParse(old.day);
      final u = day == null ? null : BoardRules.urgentFor(day.add(const Duration(hours: 23)));
      if (u != null &&
          old.urgentAccepted &&
          !old.urgentDone &&
          BoardRules.progress(u.quest, rec, old.urgentBaseline) >= u.quest.target) {
        await _sendMail(MailItem(
          id: 'urgent_${old.day}',
          kind: MailKind.reward,
          from: MailRules.hart,
          title: '받지 못한 긴급 의뢰 보상',
          body: '긴급 의뢰를 끝내 놓고 보상을 잊었더군. 우편으로 보내네.',
          gifts: {
            if (u.quest.gold > 0) Wallet.gold: u.quest.gold,
            if (u.prize == UrgentPrize.rareMaterial) u.rare.name: 1,
          },
          sentAt: _clock(),
          expiresAt: _clock().add(MailRules.rewardKeep),
        ));
      }
    }
    await _saveBoard(board);
  }
}
