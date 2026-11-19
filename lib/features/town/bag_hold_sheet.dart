import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import 'bag_sheet.dart';
import 'material_view.dart';
import '../pets/pet_art.dart';

/// 묶음 47 #240: 「가방이 가득 찼어요」 창.
/// 가방에 들어가지 못한 것마다 「버리기」 · 「바로 판매하기」, 여러 개면 「모두 판매」 · 「모두 버리기」,
/// 「가방 열기」를 누르면 정리한 뒤 가방 탭에서 「다시 받기」. [onOpenBag] 이 없으면 닫기만.
Future<void> showBagHoldSheet(BuildContext context, AppController c,
    {VoidCallback? onOpenBag}) {
  c.seenBagHold();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.night,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheet) => BagHoldSheet(
      controller: c,
      onOpenBag: onOpenBag == null
          ? null
          : () {
              Navigator.of(sheet).pop();
              onOpenBag();
            },
    ),
  );
}

class BagHoldSheet extends StatelessWidget {
  const BagHoldSheet({super.key, required this.controller, this.onOpenBag});

  final AppController controller;
  final VoidCallback? onOpenBag;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final list = c.bagHoldList;
        if (list.isEmpty) {
          // 다 정리하면 저절로 닫는다
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
          return const SizedBox(height: 120);
        }
        final total = list.fold<int>(0, (t, e) => t + e.price * e.count);
        final maxH = MediaQuery.sizeOf(context).height * 0.8;
        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                key: const Key('bagHoldSheet'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const GameIcon('bag', size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('가방이 가득 찼어요', style: AppText.title(20))),
                    Text('${c.bagUsed} / ${c.bagCapacity}칸',
                        style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  const KText('새로 얻은 것이 가방에 들어가지 못했어요. 하나씩 고르거나, 가방을 정리한 뒤 다시 받아요.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final e in list) _HoldRow(controller: c, entry: e),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (list.length > 1) ...[
                    Row(children: [
                      Expanded(
                        child: _SmallButton(
                          key: const Key('bagHoldSellAll'),
                          label: '모두 판매 · 금화 ${comma(total)}',
                          icon: Icons.sell_rounded,
                          onTap: () async {
                            final g = await c.sellAllHold();
                            if (context.mounted) {
                              showTopNotice(context, '모두 팔았어요. 금화 +${comma(g)}');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SmallButton(
                          key: const Key('bagHoldDropAll'),
                          label: '모두 버리기',
                          icon: Icons.delete_outline_rounded,
                          danger: true,
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (d) => GameAlert(
                                title: const Text('모두 버릴까요?'),
                                content: const KText('버린 것은 되찾을 수 없어요.'),
                                actions: [
                                  TextButton(
                                      key: const Key('bagHoldKeep'),
                                      onPressed: () => Navigator.of(d).pop(false),
                                      child: const Text('그대로 두기')),
                                  TextButton(
                                      key: const Key('bagHoldDropAllYes'),
                                      onPressed: () => Navigator.of(d).pop(true),
                                      child: const Text('모두 버리기')),
                                ],
                              ),
                            );
                            if (ok == true) await c.discardAllHold();
                          },
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),
                  ],
                  if (onOpenBag != null)
                    GoldButton(
                      key: const Key('bagHoldOpenBag'),
                      label: '가방 열기',
                      height: 50,
                      fontSize: 18,
                      onPressed: onOpenBag,
                    )
                  else
                    FrameButton(
                      key: const Key('bagHoldClose'),
                      label: '닫기',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  const SizedBox(height: 4),
                  const KText('그냥 닫아도 사라지지 않아요. 가방 탭 「다시 받기」에서 받을 수 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HoldRow extends StatelessWidget {
  const _HoldRow({required this.controller, required this.entry});

  final AppController controller;
  final BagHoldEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final e = entry;
    final icon = switch (e) {
      BagHoldEntry(:final egg?) => EggArt(size: 40, grade: egg),
      BagHoldEntry(:final material?) => MaterialIcon(material, size: 40),
      BagHoldEntry(:final item?) => Image.asset(bagIconAsset(c, item),
          width: 40,
          height: 40,
          errorBuilder: (_, __, ___) => const GameIcon('bag', size: 36)),
      _ => const GameIcon('bag', size: 36),
    };
    return Container(
      key: Key('bagHold_${e.key}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.slotBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(children: [
        SizedBox(width: 40, height: 40, child: icon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${e.name} ×${e.count}',
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text('1개 금화 ${comma(e.price)}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        _SmallButton(
          key: Key('bagHoldDrop_${e.key}'),
          label: '버리기',
          danger: true,
          onTap: () async {
            // 묶음 75 #327: 알은 버리기 전에 한 번 더
            if (e.egg != null) {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => GameAlert(
                  title: const Text('알 버리기'),
                  content: KText('${e.name} ${e.count}개를 버릴까요? 버린 알은 되찾을 수 없어요'),
                  actions: [
                    TextButton(
                        key: const Key('holdEggNo'), onPressed: () => Navigator.pop(d, false), child: const Text('그만둘래요')),
                    TextButton(
                        key: const Key('holdEggYes'), onPressed: () => Navigator.pop(d, true), child: const Text('버리기')),
                  ],
                ),
              );
              if (ok != true) return;
            }
            await c.discardHold(e.key);
          },
        ),
        const SizedBox(width: 6),
        _SmallButton(
          key: Key('bagHoldSell_${e.key}'),
          label: '바로 판매',
          sub: '금화 ${comma(e.price * e.count)}',
          gold: true,
          onTap: () async {
            final g = await c.sellHold(e.key);
            if (context.mounted && g > 0) {
              showTopNotice(context, '${e.name} ${e.count}개를 팔았어요. 금화 +${comma(g)}');
            }
          },
        ),
      ]),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(
      {super.key,
      required this.label,
      required this.onTap,
      this.sub,
      this.icon,
      this.danger = false,
      this.gold = false});

  final String label;
  final String? sub;
  final IconData? icon;
  final VoidCallback onTap;
  final bool danger;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final edge = danger
        ? const Color(0xFFC0473C)
        : gold
            ? AppColors.goldBright
            : AppColors.gold;
    final ink = danger ? const Color(0xFFF0A79C) : AppColors.text;
    return Material(
      color: gold ? const Color(0xFF3A2E0E) : const Color(0xFF1B1E4C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: edge, width: 1.3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 17, color: ink),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: gold ? AppColors.goldBright : ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      if (sub != null)
                        Text(sub!,
                            maxLines: 1,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                    ]),
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}
