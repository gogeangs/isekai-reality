part of '../board_screen.dart';

/// 이 화면에서 사라지는 연출을 이미 보여 준 쪽지 (앱을 켜 둔 동안)
final Set<String> _vanished = {};

/// 한 줄에 쪽지 2개 (묶음 37 #206 · 묶음 39 #218): 두 칸 폭·간격이 같고 게시판 안에만.
/// 같은 줄 쪽지는 실제로 그려 본 높이 중 높은 쪽에 맞추고([EqualHeightRow]),
/// 다음 줄은 그 아래 핀 높이 + 여유만큼 띄워 어떤 쪽지도 다른 쪽지를 덮지 않는다
class NoteGrid extends StatelessWidget {
  const NoteGrid({super.key, required this.children});

  final List<Widget> children;

  static const double gap = 10;

  /// 줄 사이 (쪽지 위아래 여백 14 + 이것 = 핀이 튀어나온 높이 17 + 여유)
  static const double rowGap = 14;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 묶음 78 #309: 한 줄에 넓은 카드 하나
          for (final (i, c) in children.indexed)
            Padding(padding: EdgeInsets.only(top: i == 0 ? 0 : 4), child: c),
        ],
      );
}

/// 쪽지 이름: 단어 중간에서 끊지 않는다. 한 줄에 조금 넘치면 글씨를 줄이고,
/// 많이 넘치면 단어 단위로 두 줄. 실제 글 폭(종이 안쪽)과 기기 글자 크기로 잰다 (묶음 39 #218)
class NoteTitle extends StatelessWidget {
  const NoteTitle(this.title, {super.key, this.size = 14});

  final String title;
  final double size;

  /// 이보다 작게는 줄이지 않는다 (그때는 두 줄)
  static const double minSize = 11.5;

  /// 칸 폭 [cell] 에서 쓸 글씨 크기와 줄 수 (칸 양옆 2 + 보이는 종이 안쪽 여백)
  static (double, int) fit(String title, double cell, TextScaler scaler,
          {double size = 14, Locale? locale}) =>
      fitIn(title, cell - 4 - ParchmentNote.smallSide * 2, scaler,
          size: size, locale: locale);

  /// 글 폭 [avail] 안에서 쓸 글씨 크기와 줄 수
  static (double, int) fitIn(String title, double avail, TextScaler scaler,
      {double size = 14, Locale? locale}) {
    final tp = TextPainter(
      text: TextSpan(text: keepAll(title), style: noteTitle(size)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      locale: locale,
      maxLines: 1,
    )..layout();
    final full = tp.width;
    tp.dispose();
    // 기기 글꼴 폭이 조금 달라도 넘치지 않게 4% 여유
    final room = avail * 0.96;
    if (full <= room) return (size, 1);
    final s = (size * room / full * 10).floorToDouble() / 10;
    if (s >= minSize) return (s, 1);
    return (size, 2);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final (s, _) = fitIn(title, box.maxWidth, MediaQuery.textScalerOf(context),
            size: size, locale: Localizations.maybeLocaleOf(context));
        // 말줄임 없이, 혹시 기기 글꼴이 더 넓어도 종이 밖으로 나가지 않고 단어 단위로 줄바꿈
        return Text(keepAll(title),
            key: const Key('noteTitle'),
            softWrap: true,
            overflow: TextOverflow.visible,
            style: noteTitle(s));
      });
}

/// 작은 쪽지 (이름 + 짧은 진행). [glow] 면 금빛으로 빛나고 「받기!」 리본
class SmallNote extends StatelessWidget {
  const SmallNote({
    super.key,
    required this.title,
    required this.seed,
    this.ratio,
    this.progress,
    this.glow = false,
    this.sealed = false,
    this.sealIn = false,
    this.edge,
    this.done = false,
    this.onTap,
    this.npc,
    this.ribbon,
    this.icon,
    this.reward,
    this.button,
    this.onButton,
    this.buttonGold = false,
  });

  /// 묶음 78 #309: 넓은 카드의 아이콘 · 보상 칩 · 버튼
  final Widget? icon;
  final String? reward;
  final String? button;
  final VoidCallback? onButton;
  final bool buttonGold;

  /// 묶음 69 #286: 쪽지 오른쪽 위 리본 (「새 부탁」)
  final String? ribbon;

  /// 묶음 45 #231: 마을 사람 쪽지면 그 사람 얼굴을 작게
  final Npc? npc;

  final String title;
  final int seed;
  final double? ratio;
  final String? progress;
  final bool glow;
  final bool sealed;
  final bool sealIn;
  final Color? edge;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: QuestCard(
          title: title,
          seed: seed,
          icon: icon ?? (npc != null ? NpcFace(key: Key('noteFace_${npc!.name}'), npc: npc!, size: 44) : null),
          ratio: ratio,
          progress: progress,
          reward: reward,
          button: button ?? (glow ? '받기' : null),
          onButton: onButton ?? onTap,
          buttonGold: buttonGold || glow,
          glow: glow,
          done: done,
          sealed: sealed,
          sealIn: sealIn,
          edge: edge,
          ribbon: ribbon,
        ),
      );
}

/// 끝낸 쪽지: 「완료」 인장이 찍히고 떼어지듯 사라진다 (한 번)
class VanishingNote extends StatefulWidget {
  const VanishingNote({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<VanishingNote> createState() => _VanishingNoteState();
}

class _VanishingNoteState extends State<VanishingNote>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..forward().whenComplete(() {
      _vanished.add(widget.id);
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_vanished.contains(widget.id)) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _a,
      builder: (_, child) {
        // 앞 절반: 인장 · 뒤 절반: 위로 살짝 떼어지며 흐려짐
        final t = ((_a.value - 0.5) / 0.5).clamp(0.0, 1.0);
        final e = Curves.easeIn.transform(t);
        return Opacity(
          opacity: 1 - e,
          child: Transform.translate(
            offset: Offset(0, -18 * e),
            child: Transform.rotate(angle: -0.08 * e, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 이름판 바로 아래 작은 한 줄 설명 (묶음 37 #206). 묶음 38 #215: 나무판 위에서도 또렷하게
/// 작은 어두운 반투명 띠 위에 밝은 글씨. 넘치면 글씨를 줄여서라도 한 줄
class _BoardNote extends StatelessWidget {
  const _BoardNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 5, 2, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(9, 3, 9, 4),
          decoration: BoxDecoration(
            color: const Color(0xC21A0F06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text,
                maxLines: 1,
                style: const TextStyle(
                    color: Color(0xFFF6E7C4),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

/// 오늘의 의뢰 보너스 금빛 띠 (묶음 39 #216): 설명 띠와 같은 모양·높이, 색만 금빛.
/// 다 끝내면 조금 더 밝게 빛난다
class _BonusBand extends StatelessWidget {
  const _BonusBand({super.key, required this.text, required this.done});

  final String text;
  final bool done;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 5, 2, 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(7, 2, 9, 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: done
                ? const [Color(0xFFF7D978), Color(0xFFD9A441)]
                : const [Color(0xE6D9B060), Color(0xE6B8862E)]),
            borderRadius: BorderRadius.circular(8),
            boxShadow: done
                ? [
                    BoxShadow(
                        color: AppColors.goldBright.withValues(alpha: 0.6),
                        blurRadius: 10),
                  ]
                : null,
          ),
          child: Row(children: [
            const GameIcon('medal', size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(text,
                    maxLines: 1,
                    style: const TextStyle(
                        color: Color(0xFF3A2614),
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ),
      );
}
