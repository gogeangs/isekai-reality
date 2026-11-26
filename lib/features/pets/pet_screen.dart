import '../village/shelter_screen.dart';
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
class PetScreen extends StatefulWidget {
  const PetScreen({super.key, required this.controller, this.focus});

  final AppController controller;

  /// 묶음 75 #328: 이 펫 자세히 (그 카드로 굴리고 금테)
  final String? focus;

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> {
  AppController get controller => widget.controller;
  final _focusKey = GlobalKey(debugLabel: 'petFocus');

  @override
  void initState() {
    super.initState();
    if (widget.focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _focusKey.currentContext;
        if (ctx != null && mounted) Scrollable.ensureVisible(ctx, alignment: 0.1);
      });
    }
  }

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
                    '기력 ${c.mp} / ${c.mpMax} (시간당 +${c.mpRegenPerHour.round()})'
                    '${c.bagEggs.isEmpty ? '' : ' · 가방에 알 ${c.bagEggs.length}개'}',
                    style: const TextStyle(color: AppColors.text, fontSize: 14),
                  ),
                ),
                // 묶음 35: 알은 펫 쉼터 둥지에서도 (부화 규칙은 그대로)
                if (c.shelterOpen && c.bagEggs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  FrameButton(
                    key: const Key('petToShelter'),
                    label: '펫 쉼터에서 알 보기',
                    height: 42,
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => ShelterScreen(controller: c))),
                  ),
                ],
                const SizedBox(height: 10),
                if (pets.isEmpty)
                  const KText('Lv.11이 되면 첫 펫이 태어나요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted)),
                for (final p in pets) ...[
                  if (p.uid == widget.focus)
                    Container(
                      key: _focusKey,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Color(0x88FFD86B), blurRadius: 12)],
                      ),
                      child: _PetCard(controller: c, pet: p),
                    )
                  else
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
    if (name == null) return;
    final ok = await controller.renamePet(pet.uid, name);
    // 묶음 51: 마을 사람 이름은 펫 이름으로 쓸 수 없다
    if (!ok && name.trim().isNotEmpty && context.mounted) {
      showTopNotice(context, NameRules.banned(name) ? NameRules.bannedMessage : '마을 사람 이름은 쓸 수 없어요',
          icon: Icons.info_outline_rounded);
    }
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
    // 묶음 85 #409: 보낼 수 없으면 까닭만
    if (c.releaseBlock(pet.uid) case final why?) {
      showTopNotice(context, why, icon: Icons.info_outline_rounded);
      return;
    }
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
    if (!await ask(
        '정말 보낼까요?',
        c.isFirstPet(pet.uid)
            ? '${josa(pet.name, '은/는')} 정령이 남긴 첫 친구예요. 보내면 이야기에서 말하는 펫이 데리고 다니는 펫으로 바뀌어요. 정말 보낼까요?'
            : '돌려보낸 펫은 다시 돌아오지 않아요. 레벨과 친밀도도 사라져요.',
        '보내기')) {
      return;
    }
    final ok = await c.releasePet(pet.uid);
    if (!context.mounted) return;
    showTopNotice(context, ok
          ? '${josa(pet.name, '이/가')} 자연으로 돌아갔어요. 마석 +$mana, $fav +${PetRules.releaseMaterials}'
          : c.releaseBlock(pet.uid) ?? '지금은 보낼 수 없어요');
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final info = pet.info;
    final companion = c.companionPet?.uid == pet.uid;
    final away = c.isAway(pet.uid);
    // 묶음 43 #228: 훈련장에 맡긴 펫
    final train = c.petTrainingLeft(pet.uid);
    final trainText = train == null
        ? ''
        : ' · 훈련 중 · ${train.inHours > 0 ? '${train.inHours}시간 ' : ''}${train.inMinutes % 60 + (train.inHours == 0 && train.inMinutes == 0 ? 1 : 0)}분 남음';
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
                      '${info.name}${petGradeTag(info.grade)} · Lv.${pet.level} · ${pet.adult ? '성체' : '아기'}'
                      '${companion ? ' · 동행' : ''}${away ? ' · 원정 중' : ''}$trainText',
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
              '${info.walk == null ? '' : '\n함께 걸을 때 · ${info.walk}'}'
              '${pet.adult ? '' : '\nLv.${PetRules.adultLevel}에 성체가 돼요. 자라면 더 좋아져요.'}'
              '${pet.hero && !pet.awake ? '\n단짝이 되면 각성 모습을 보여 줘요.' : ''}',
              style: const TextStyle(color: AppColors.text, fontSize: 12)),
          // 묶음 70 #294: 나는 펫
          if (info.flies)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(key: const Key('petFlies'), children: [
                Image.asset('assets/images/flag_emb_wing.webp', width: 16, height: 16),
                const SizedBox(width: 4),
                const KText('원정은 하늘을 날아 곧장 가요',
                    style: TextStyle(color: Color(0xFF9BD7FF), fontSize: 12)),
              ]),
            ),
          // 묶음 32 #191: 기운 공명
          if (c.petResonant(pet))
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: KText('나와 같은 기운이에요',
                  key: Key('petResonant'),
                  style: TextStyle(color: AppColors.goldBright, fontSize: 12)),
            ),
          const SizedBox(height: 8),
          Row(children: [
            if (!companion)
              Expanded(
                child: FrameButton(
                  label: '데리고 다니기',
                  height: 40,
                  onPressed:
                      train != null ? null : () => c.setCompanion(pet.uid),
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
              key: Key('petRelease_${pet.uid}'),
              onPressed: () => _release(context),
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
                  // 묶음 73 #314: 줄마다 아이콘 칸 44 고정 · 「주기」는 금빛 알약 버튼 (0개면 흐린 회색)
                  _FeedRow(
                    key: const Key('feedSnack'),
                    // 묶음 76 #317: 가방과 같은 그림
                    icon: Image.asset('assets/images/item_pet_snack.webp',
                        key: const Key('feedSnackArt'),
                        width: 40,
                        height: 40,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.cookie_rounded, color: AppColors.goldBright, size: 30)),
                    title: '펫 간식 × $snacks',
                    onFeed: snacks > 0 ? () => c.feedSnack(pet.uid) : null,
                  ),
                  for (final e in mats)
                    _FeedRow(
                      key: Key('feed_${e.key.name}'),
                      icon: MaterialIcon(e.key, size: 34),
                      title: '${Materials.info(e.key).name} × ${e.value}',
                      sub: Materials.info(e.key).rare
                          ? '경험치 +${PetRules.expRareFood}'
                          : '경험치 +${PetRules.expCommonFood}',
                      onFeed: e.value > 0 ? () => c.feedMaterial(pet.uid, e.key) : null,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );

/// 먹이 한 줄: 아이콘 칸(44) · 이름 · 「주기」 금빛 알약 버튼
class _FeedRow extends StatelessWidget {
  const _FeedRow({super.key, required this.icon, required this.title, this.sub, this.onFeed});

  final Widget icon;
  final String title;
  final String? sub;
  final VoidCallback? onFeed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          SizedBox(width: 44, height: 44, child: Center(child: icon)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(color: AppColors.text, fontSize: 15)),
              if (sub != null)
                Text(sub!, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: GoldButton(
              key: const Key('feedGive'),
              label: '주기',
              height: 40,
              fontSize: 15,
              onPressed: onFeed,
            ),
          ),
        ]),
      );
}
