import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/armory.dart' show EquipItem;
import '../../theme/app_colors.dart';
import '../../theme/top_notice.dart';

/// 묶음 82 #393: 「바로 입기」 작은 금테 버튼 (잿빛 틈 유품 · 대장간 만들기 · 왕의 장비).
/// 누르면 입고 「입었어요 ✓」(흐리게, 다시 못 누름). 이미 입고 있으면 처음부터 「입었어요 ✓」.
/// 못 입으면 이유를 위쪽 알림 한 줄로.
class EquipNowButton extends StatefulWidget {
  const EquipNowButton({super.key, required this.controller, required this.item, this.onEquipped});

  final AppController controller;
  final EquipItem item;
  final VoidCallback? onEquipped;

  @override
  State<EquipNowButton> createState() => _EquipNowButtonState();
}

class _EquipNowButtonState extends State<EquipNowButton> {
  bool _busy = false;

  bool get _worn => widget.controller.armory.isWorn(widget.item);

  Future<void> _tap() async {
    if (_busy || _worn) return;
    setState(() => _busy = true);
    final why = await widget.controller.tryEquip(widget.item.uid);
    if (!mounted) return;
    setState(() => _busy = false);
    if (why != null) {
      showTopNotice(context, why);
      return;
    }
    widget.onEquipped?.call();
  }

  @override
  Widget build(BuildContext context) {
    final worn = _worn;
    return Opacity(
      opacity: worn ? 0.55 : 1,
      child: GestureDetector(
        key: Key(worn ? 'equipNowDone' : 'equipNow'),
        behavior: HitTestBehavior.opaque,
        onTap: worn ? null : _tap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: worn
                ? null
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF3A3170), Color(0xFF241F52)],
                  ),
            color: worn ? const Color(0xFF1C1A3A) : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: worn ? AppColors.textMuted : AppColors.goldBright, width: 1.4),
          ),
          child: Text(worn ? '입었어요 ✓' : '바로 입기',
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                  color: worn ? AppColors.textMuted : AppColors.goldBright,
                  fontSize: 14,
                  fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }
}
