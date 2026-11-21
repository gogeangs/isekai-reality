part of '../board_screen.dart';

/// 쪽지 모양 탭 한 칸 (고른 칸은 금빛), 아래 작은 글 · 받을 것이 있으면 빨간 점
class _BoardTabChip extends StatelessWidget {
  const _BoardTabChip({
    super.key,
    required this.label,
    required this.sub,
    required this.selected,
    required this.dot,
    required this.onTap,
    this.count = 0,
  });

  final String label;
  final String sub;
  final bool selected;
  final bool dot;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            // 묶음 71: 칸 폭을 가득 (큰 화면에서 쪽지가 작아 보이지 않게)
            width: double.infinity,
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected
                    ? const [Color(0xFFFFE7A3), Color(0xFFE2B354)]
                    : const [Color(0xFFEBDDBE), Color(0xFFCDB991)],
              ),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                  color: selected ? const Color(0xFFFFF2C4) : const Color(0xFF8C6A42),
                  width: selected ? 1.6 : 1),
              boxShadow: [
                BoxShadow(
                    color: selected ? const Color(0x88F2C14E) : const Color(0x66000000),
                    blurRadius: selected ? 8 : 4,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    maxLines: 1,
                    style: TextStyle(
                        color: selected ? const Color(0xFF3A230C) : kInk,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(sub,
                    maxLines: 1,
                    style: const TextStyle(color: kInkSoft, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          if (count > 0)
            Positioned(
              right: -4,
              top: -6,
              child: Container(
                key: const Key('boardTabCount'),
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
                child: Text('$count',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, height: 1.1)),
              ),
            )
          else if (dot)
            Positioned(
              right: -2,
              top: -3,
              child: Container(
                key: const Key('boardTabDot'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
              ),
            ),
        ]),
      );
}

/// 묶음 70 #301: 탭 위 긴급 띠 「긴급 · ○○ · 오늘 자정까지」 — 누르면 쪽지 창 (다 하면 받기)
class _UrgentBand extends StatelessWidget {
  const _UrgentBand({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final u = c.urgent!;
    final b = c.board;
    final ready = b.urgentAccepted && c.urgentProgress >= u.quest.target;
    return GestureDetector(
      key: const Key('urgentBand'),
      onTap: ready
          ? () async {
              await c.claimUrgent();
              if (context.mounted) showTopNotice(context, '긴급 의뢰 완료!');
            }
          : () => _showUrgentDetail(context, c),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: ready
              ? const [Color(0xFFE2B354), Color(0xFFB8862B)]
              : const [Color(0xFF9E2A22), Color(0xFF6E1A15)]),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: ready ? const Color(0xFFFFF2C4) : const Color(0xFFE5826F)),
        ),
        child: Row(children: [
          Icon(ready ? Icons.redeem_rounded : Icons.priority_high_rounded,
              size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              ready
                  ? '긴급 · ${u.quest.title} · 받기!'
                  : '긴급 · ${u.quest.title} · 오늘 자정까지',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
          if (b.urgentAccepted && !ready)
            Text('${comma(c.urgentProgress)}/${comma(u.quest.target)}',
                style: const TextStyle(color: Color(0xFFFFD9CF), fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// 자식 크기가 정해지면 알려 준다 (그린 뒤)
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter r) =>
      r.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size != _last) {
      _last = size;
      final s = size;
      WidgetsBinding.instance.addPostFrameCallback((_) => onSize(s));
    }
  }
}
