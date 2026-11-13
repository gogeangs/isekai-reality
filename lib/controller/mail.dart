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
  /// 가방이 가득하면 넘치는 물건은 금화로, 금화·마석·경험치는 늘 받는다.
  Future<String?> claimMail(String id) async {
    final i = _mail.mails.indexWhere((m) => m.id == id);
    if (i < 0 || !_mail.mails[i].hasGifts) return null;
    final m = _mail.mails[i];
    final got = <String>[];
    var gold = 0, mana = 0, exp = 0, notes = 0, eggs = 0;
    final mats = <MaterialId, int>{};
    final items = <ShopItem, int>{};
    m.gifts.forEach((k, v) {
      if (k == Wallet.gold) {
        gold += v;
      } else if (k == Wallet.manaStone) {
        mana += v;
      } else if (k == Wallet.exp) {
        exp += v;
      } else if (k == 'note') {
        notes += v;
      } else if (k == 'egg') {
        eggs += v;
      } else if (k.startsWith('item:')) {
        for (final it in ShopItem.values) {
          if (it.name == k.substring(5)) items[it] = (items[it] ?? 0) + v;
        }
      } else if (Materials.byName(k) case final mat?) {
        mats[mat] = (mats[mat] ?? 0) + v;
      }
    });
    // 물건: 칸이 없으면 금화로
    final today = await _todayRecord();
    final counters = <String, int>{};
    var itemGold = 0;
    for (final e in items.entries) {
      var have = bagCount(e.key);
      for (var n = 0; n < e.value; n++) {
        if (_roomFor(have)) {
          counters[TownRules.giftKey(e.key)] = (counters[TownRules.giftKey(e.key)] ?? 0) + 1;
          have++;
        } else {
          itemGold += BagRules.itemPrice(e.key);
        }
      }
      got.add('${itemName(e.key)} ${e.value}');
    }
    if (counters.isNotEmpty || exp > 0) {
      await _save(today.copyWith(
        counters: DailyRecord.addCounts(today.counters, counters),
        gains: exp > 0 ? DailyRecord.addCounts(today.gains, {Wallet.exp: exp}) : null,
      ));
    }
    if (gold + itemGold > 0 || mana > 0 || mats.isNotEmpty) {
      await _grant(gold + itemGold, mana, mats);
    }
    if (notes > 0 || eggs > 0) {
      final p = _pets;
      await _savePets(p.copyWith(
        recipeNotes: p.recipeNotes + notes,
        eggs: [
          ...p.eggs,
          for (var n = 0; n < eggs; n++)
            PetEgg(id: 'egg${p.nextId + n}', source: 'mail', element: mainElement?.name),
        ],
        nextId: p.nextId + eggs,
        firstEggFound: p.firstEggFound || eggs > 0,
      ));
    }
    if (gold > 0) got.add('금화 $gold');
    if (mana > 0) got.add('마석 $mana');
    if (exp > 0) got.add('경험치 $exp');
    for (final e in mats.entries) {
      got.add('${Materials.info(e.key).name} ${e.value}');
    }
    if (notes > 0) got.add('레시피 쪽지 $notes');
    if (eggs > 0) got.add('알 $eggs');
    if (itemGold > 0) got.add('(가방이 가득해 금화 $itemGold로)');
    // 11-11 #100: 받은 뒤에도 편지는 계속 보관한다 (보상 우편도 편지처럼)
    await _saveMail(_mail.copyWith(mails: [
      for (final x in _mail.mails)
        if (x.id != id) x else x.copyWith(claimed: true, read: true),
    ]));
    return got.join(', ');
  }

  /// 모두 받기
  Future<int> claimAllMail() async {
    var n = 0;
    for (final m in giftMails) {
      if (await claimMail(m.id) != null) n++;
    }
    return n;
  }

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
