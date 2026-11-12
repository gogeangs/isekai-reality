import 'package:flutter/material.dart';

import '../../core/rules/level_rules.dart';
import '../../core/rules/stat_rules.dart';
import '../status/stat_icon.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/bulssi_bubble.dart';
import '../bulssi/spirit_art.dart';

/// 레벨업 연출 (목업 확정본 기준). [from] → [to] 로 여러 레벨이 한 번에 오를 수도 있다.
class LevelUpDialog extends StatelessWidget {
  const LevelUpDialog(
      {super.key,
      required this.from,
      required this.to,
      this.title,
      this.healedFrom});

  final int from;
  final int to;

  /// 레벨 업으로 채우기 전 HP·MP (묶음 14 #102). 있으면 막대가 가득 차오른다.
  final ({int hp, int maxHp, int mp, int mpMax})? healedFrom;

  /// 대표 칭호 (월계관 배지 리본에 쓴다)
  final String? title;

  /// 불씨 대사 36~39
  /// 묶음 16 #140: Lv.11까지 레벨마다 이야기 단서 한 줄
  static const clues = {
    2: '방금 그 슬라임, 원래 이 동네엔 없던 아이야. 어딘가 문이 열린 것 같아.',
    3: '네가 걸을 때마다 잿빛 안개가 조금씩 걷혀. 우연은 아닐 거야.',
    4: '게시판 구석에 오래된 글씨가 있었어. 「두 세계가 겹치는 날」… 무슨 뜻일까?',
    5: '꽃잎에서 이세계 냄새가 나. 두 세계의 경계가 점점 얇아지고 있어.',
    6: '사람들 속에도 이세계의 빛이 숨어 있대. 너도 그중 하나일지 몰라.',
    7: '던전 깊은 곳에서 누군가 부르는 소리가 들렸어. 나만 들은 걸까?',
    8: '요즘 꿈에 커다란 문이 나와. 문 너머엔 빛나는 숲이 있었어.',
    9: '각성자는 너 혼자가 아니래. 다른 동네에도 빛이 하나둘 켜지고 있어.',
    10: 'Lv.10이야! 이제 진짜 각성자다운걸? 그런데 왜 이렇게 마음이 두근거릴까.',
    11: '이제 알 것 같아. 나에게도 해야 할 일이 있어… 조금만 더 함께 걷자.',
  };

  String get _line {
    if (clues[to] case final c?) return c;
    if (from < 10 && to >= 10) return 'Lv.10이야! 이제 진짜 각성자다운걸?';
    // #102: HP·MP가 가득 찼다는 대사
    if (healedFrom != null) {
      const healed = [
        '레벨 업! 힘이 가득 차올랐어.',
        '레벨 업! 몸도 마음도 개운해졌지?',
        '레벨 업! 지친 것도 싹 날아갔어.',
      ];
      return healed[to % healed.length];
    }
    const lines = [
      '레벨 업! 네 불꽃이 한층 더 밝아졌어.',
      '이세계 어딘가가 조금 더 환해졌을 거야.',
      '또 성장했네! 매일매일 강해지고 있어.',
    ];
    return lines[to % lines.length];
  }

  @override
  Widget build(BuildContext context) {
    // 묶음 16 #127: 한 화면에 다 보이게. 장식은 작게, 확인 버튼은 아래 고정,
    // 길어지면 가운데만 스크롤
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ArtBanner(
              asset: 'assets/images/banner_levelup.webp',
              width: 160,
              aspect: 520 / 489,
              text: 'LEVEL UP',
              textOffset: 0.08,
              fontSize: 22,
            ),
            Flexible(
              child: OrnatePanel(
                highlight: true,
                ornament: true,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(children: [
                          _TitleRibbon(title: title ?? '새내기 각성자'),
                          const SizedBox(height: 4),
                          Text('Lv.$from  →  Lv.$to',
                              key: const Key('levelUpArrow'),
                              style: AppText.level(22)),
                          const SizedBox(height: 10),
                          ChipBadge(
                              text:
                                  '다음 레벨까지 ${LevelRules.expRequiredFor(to)}',
                              icon: Icons.auto_awesome_rounded),
                          const SizedBox(height: 8),
                          // 받은 스탯 포인트 + 다섯 스탯 메달
                          Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                for (final k in StatKind.values)
                                  StatIcon(k, size: 24),
                                const SizedBox(width: 2),
                                Text(
                                    '스탯 포인트 +${(to - from) * StatRules.pointsPerLevel}',
                                    style: const TextStyle(
                                        color: AppColors.goldBright,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700)),
                              ]),
                          // Lv.2가 되는 순간 스탯 분배가 열린다
                          if (from < 2 && to >= 2) ...[
                            const SizedBox(height: 8),
                            const ChipBadge(
                                key: Key('statUnlocked'),
                                text: '스탯 분배가 열렸어요',
                                icon: Icons.lock_open_rounded),
                          ],
                          if (healedFrom case final h?) ...[
                            const SizedBox(height: 10),
                            _RefillBars(from: h),
                          ],
                          const SizedBox(height: 10),
                          BulssiBubble(line: _line, mood: SpiritMood.cheer),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GoldButton(
                      key: const Key('levelUpOk'),
                      label: '계속',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 칭호 리본 (예전 월계관 명판에서 Lv 판은 빼고 리본만 작게)
class _TitleRibbon extends StatelessWidget {
  const _TitleRibbon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 52,
      child: Stack(alignment: Alignment.center, children: [
        Image.asset('assets/images/ui_ribbon.webp',
            width: 160,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox()),
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Title',
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.goldInk,
              )),
        ),
      ]),
    );
  }
}

/// 작은 장식 줄: ✦ ─── ✦
class LaurelRow extends StatelessWidget {
  const LaurelRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Diamond(size: 6),
        SizedBox(width: 8),
        Icon(Icons.auto_awesome_rounded, color: AppColors.goldBright, size: 18),
        SizedBox(width: 8),
        Diamond(size: 6),
      ]),
    );
  }
}

/// HP·MP 막대가 가득 차오르는 짧은 연출 (#102)
class _RefillBars extends StatelessWidget {
  const _RefillBars({required this.from});

  final ({int hp, int maxHp, int mp, int mpMax}) from;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final hp0 = from.maxHp == 0 ? 1.0 : from.hp / from.maxHp;
    final mp0 = from.mpMax == 0 ? 1.0 : from.mp / from.mpMax;
    return Column(key: const Key('levelUpRefill'), children: [
      const Text('HP·MP가 가득 찼어요',
          style: TextStyle(
              color: AppColors.goldBright, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: still ? 1 : 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => Column(children: [
          Row(children: [
            const SizedBox(
                width: 34,
                child: Text('HP',
                    style: TextStyle(color: AppColors.text, fontSize: 12))),
            Expanded(
                child: GlowBar(
                    ratio: hp0 + (1 - hp0) * t, colors: BarColors.hp, height: 8)),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            const SizedBox(
                width: 34,
                child: Text('MP',
                    style: TextStyle(color: AppColors.text, fontSize: 12))),
            Expanded(
                child: GlowBar(
                    ratio: mp0 + (1 - mp0) * t,
                    colors: BarColors.mana,
                    height: 8)),
          ]),
        ]),
      ),
    ]);
  }
}
