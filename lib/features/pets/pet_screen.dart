import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/pet_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../town/material_view.dart';
import 'pet_art.dart';
import '../battle/element_view.dart';
import '../../theme/top_notice.dart';

/// 펫 목록 (11-11 #38): 데리고 다니기, 먹이 주기, 이름 바꾸기, 자연으로 돌려보내기
class PetScreen extends StatelessWidget {
  const PetScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final c = controller;
            final pets = c.pets.pets;
            return ListView(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
              children: [
                OrnateTopBar(
                    title: '펫', onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 8),
                OrnatePanel(
                  child: KText(
                    '펫 ${pets.length} / ${PetRules.maxPets} · '
                    '공용 MP ${c.mp} / ${c.mpMax} (시간당 +${c.mpRegenPerHour})'
                    '${c.pets.eggs.isEmpty ? '' : ' · 가방에 알 ${c.pets.eggs.length}개'}',
                    style: const TextStyle(color: AppColors.text, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 10),
                if (pets.isEmpty)
                  const KText('Lv.11이 되면 첫 펫이 태어나요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted)),
                for (final p in pets) ...[
                  _PetCard(controller: c, pet: p),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PetCard extends StatelessWidget {
  const _PetCard({required this.controller, required this.pet});

  final AppController controller;
  final Pet pet;

  Future<void> _rename(BuildContext context) async {
    final text = TextEditingController(text: pet.name);
    final name = await showDialog<String>(
      context: context,
      builder: (d) => GameAlert(
        title: const Text('이름 바꾸기'),
        content: TextField(controller: text, maxLength: 8, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d), child: const Text('그만둘래요')),
          TextButton(
              onPressed: () => Navigator.pop(d, text.text),
              child: const Text('바꾸기')),
        ],
      ),
    );
    text.dispose();
    if (name != null) await controller.renamePet(pet.uid, name);
  }

  Future<void> _release(BuildContext context) async {
    final c = controller;
    Future<bool> ask(String title, String body, String yes) async =>
        await showDialog<bool>(
          context: context,
          builder: (d) => GameAlert(
            title: Text(title),
            content: KText(body),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('그만둘래요')),
              TextButton(
                  onPressed: () => Navigator.pop(d, true), child: Text(yes)),
            ],
          ),
        ) ==
        true;
    final mana = PetRules.releaseMana(pet.level);
    final fav = Materials.info(pet.info.favorite).name;
    if (!await ask(
        '자연으로 돌려보내기',
        '${josa(pet.name, '을/를')} 자연으로 돌려보낼까요? '
            '마석 $mana개와 $fav ${PetRules.releaseMaterials}개를 남기고 떠나요.',
        '돌려보내기')) {
      return;
    }
    if (!context.mounted) return;
    if (!await ask('정말 보낼까요?',
        '돌려보낸 펫은 다시 돌아오지 않아요. 레벨과 친밀도도 사라져요.', '보내기')) {
      return;
    }
    final ok = await c.releasePet(pet.uid);
    if (!context.mounted) return;
    showTopNotice(context, ok
          ? '${josa(pet.name, '이/가')} 자연으로 돌아갔어요. 마석 +$mana, $fav +${PetRules.releaseMaterials}'
          : '지금은 돌려보낼 수 없어요 (마지막 한 마리이거나 원정 중이에요).');
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = pet.info;
    final companion = c.companionPet?.uid == pet.uid;
    final away = c.isAway(pet.uid);
    final maxed = pet.level >= PetRules.maxLevel;
    final into = PetRules.expInto(pet.exp);
    final need = PetRules.expToNext(pet.level);
    return OrnatePanel(
      highlight: companion,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            PetArt.of(pet, size: 72),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    ElementIcon(pet.element, size: 18),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(pet.name,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.title(19, color: AppColors.text)),
                    ),
                    IconButton(
                      tooltip: '이름 바꾸기',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _rename(context),
                      icon: const Icon(Icons.edit_rounded,
                          size: 16, color: AppColors.goldBright),
                    ),
                  ]),
                  Text(
                      '${info.name} · Lv.${pet.level} · ${pet.adult ? '성체' : '아기'}'
                      '${companion ? ' · 동행' : ''}${away ? ' · 원정 중' : ''}',
                      style: const TextStyle(
                          color: AppColors.goldBright, fontSize: 12)),
                  const SizedBox(height: 4),
                  GlowBar(
                      ratio: maxed ? 1 : (into / need).clamp(0.0, 1.0),
                      colors: BarColors.exp,
                      height: 6),
                  const SizedBox(height: 2),
                  Text(
                      maxed
                          ? '최고 레벨'
                          : '경험치 $into / $need · 친밀도 ${pet.bond}${pet.bond >= PetRules.maxBond ? ' (단짝)' : ''}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),
          KText(
              '원정 특기 · ${pet.adult ? info.specialAdult : info.special}\n'
              '던전 스킬 · ${info.skillName}: ${pet.adult ? info.skillTextAdult : info.skillText}'
              '${pet.adult ? '' : '\nLv.${PetRules.adultLevel}에 성체가 돼요.'}',
              style: const TextStyle(color: AppColors.text, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            if (!companion)
              Expanded(
                child: FrameButton(
                  label: '데리고 다니기',
                  height: 40,
                  onPressed: () => c.setCompanion(pet.uid),
                ),
              ),
            if (!companion) const SizedBox(width: 6),
            Expanded(
              child: FrameButton(
                label: '먹이 주기',
                height: 40,
                onPressed: () => _showFeed(context, c, pet),
              ),
            ),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: c.pets.pets.length > 1 && !away
                  ? () => _release(context)
                  : null,
              child: const Text('자연으로 돌려보내기',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// 먹이 주기: 펫 간식, 가방의 재료 (일반 +3, 귀한 +15)
Future<void> _showFeed(BuildContext context, AppController c, Pet pet) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => ListenableBuilder(
        listenable: c,
        builder: (sheet, _) {
          final mats = c.player.materials.entries.toList()
            ..sort((a, b) => a.key.index.compareTo(b.key.index));
          final snacks = c.bagCount(ShopItem.bulssiPotion);
          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheet).height * 0.75),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                children: [
                  Text('${pet.name}에게 먹이 주기', style: AppText.title(19)),
                  const SizedBox(height: 4),
                  const KText(
                      '펫 간식 경험치 +40·친밀도 +5, 귀한 재료 +15, 보통 재료 +3 (친밀도 +1)',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.cookie_rounded,
                        color: AppColors.goldBright),
                    title: Text('펫 간식 × $snacks',
                        style: const TextStyle(color: AppColors.text)),
                    trailing: TextButton(
                      onPressed:
                          snacks > 0 ? () => c.feedSnack(pet.uid) : null,
                      child: const Text('주기'),
                    ),
                  ),
                  for (final e in mats)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: MaterialIcon(e.key, size: 34),
                      title: Text('${Materials.info(e.key).name} × ${e.value}',
                          style: const TextStyle(color: AppColors.text)),
                      subtitle: Text(
                          Materials.info(e.key).rare
                              ? '경험치 +${PetRules.expRareFood}'
                              : '경험치 +${PetRules.expCommonFood}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => c.feedMaterial(pet.uid, e.key),
                        child: const Text('주기'),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
