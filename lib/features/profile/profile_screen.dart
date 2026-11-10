import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/format.dart';
import '../../core/models/pet_state.dart';
import '../../core/models/player_state.dart';
import '../../core/rules/rules.dart';
import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/spirit_art.dart';
import '../pets/pet_art.dart';
import '../pets/pet_screen.dart';
import '../codex/codex_screen.dart' show titleIcon;
import '../records/records_screen.dart';

/// 지금은 직업이 없다 (각성 기능에서 정하기로 미룸)
const String kNoJobLabel = '견습 각성자';

/// 프로필 카드: 그림·이름·레벨·직업·정령·대표 칭호.
/// 나중에 친구·거래에서 다른 사람에게 보여 줄 카드로 그대로 쓴다 (지금은 나만 봄).
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.name,
    required this.level,
    required this.look,
    required this.spiritKind,
    required this.spiritName,
    this.title,
    this.job = kNoJobLabel,
    this.onEditName,
    this.pet,
  });

  /// 정령이 떠난 뒤 데리고 다니는 펫 (그때 [spiritName] 은 처음 함께한 정령)
  final Pet? pet;

  /// 이름 옆 연필 (없으면 연필을 그리지 않는다. 다른 사람 카드에서는 null)
  final VoidCallback? onEditName;

  final String name;
  final int level;
  final HeroLook look;
  final SpiritKind spiritKind;
  final String spiritName;
  final String? title;
  final String job;

  @override
  Widget build(BuildContext context) {
    return OrnatePanel(
      highlight: true,
      child: Row(children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.goldBright, width: 2),
            color: const Color(0xFF1A1D4A),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(portraitAsset(look),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.person_rounded, size: 56)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Lv.$level', style: AppText.level(18)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(name,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.title(20, color: AppColors.text)),
                ),
                if (onEditName != null)
                  IconButton(
                    onPressed: onEditName,
                    tooltip: '이름 바꾸기',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    icon: const Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.goldBright),
                  ),
              ]),
              const SizedBox(height: 2),
              Text(title ?? '새내기 각성자',
                  style: const TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              Text('직업 · $job',
                  style:
                      const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 4),
              if (pet != null) ...[
                Row(children: [
                  PetArt.of(pet!, size: 26),
                  const SizedBox(width: 4),
                  Flexible(
                    child: KText('함께하는 펫 · ${pet!.name}',
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 12)),
                  ),
                ]),
                Row(children: [
                  Opacity(
                      opacity: 0.7,
                      child: SpiritArt(kind: spiritKind, size: 22)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: KText('처음 함께한 정령 · $spiritName',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11.5)),
                  ),
                ]),
              ] else
              Row(children: [
                SpiritArt(kind: spiritKind, size: 26),
                const SizedBox(width: 4),
                Flexible(
                  child: KText('함께하는 정령 · $spiritName',
                      style: const TextStyle(
                          color: AppColors.text, fontSize: 12)),
                ),
                const SizedBox(width: 3),
                const Tooltip(
                  message: '정령 이름은 바꿀 수 없어요',
                  child: Icon(Icons.lock_rounded,
                      size: 13, color: AppColors.textMuted),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

String portraitAsset(HeroLook look) => look == HeroLook.female
    ? 'assets/images/portrait_female.png'
    : 'assets/images/portrait_male.png';

/// 왼쪽 위 프로필 버튼: 얼굴 동그라미 + Lv.
class ProfileButton extends StatelessWidget {
  const ProfileButton(
      {super.key, required this.look, required this.level, this.onTap});

  final HeroLook look;
  final int level;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '프로필',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 52,
          child: Stack(alignment: Alignment.topCenter, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A1D4A),
                border: Border.all(color: AppColors.goldBright, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      blurRadius: 8),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(portraitAsset(look),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.person_rounded,
                      color: AppColors.goldBright)),
            ),
            Positioned(
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0D26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gold, width: 1),
                ),
                child: Text('Lv.$level',
                    style: AppText.level(10.5, color: AppColors.goldBright)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// 오른쪽 위 설정 톱니바퀴
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xCC1A1D4A),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.8)),
      ),
      child: IconButton(
        onPressed: onTap,
        tooltip: '설정',
        icon: const Icon(Icons.settings_rounded, color: AppColors.goldBright),
      ),
    );
  }
}

/// 프로필 화면 (11-10 #24): 정보(카드·대표 칭호·장비·이름) | 기록
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final c = widget.controller;
    return Scaffold(
      backgroundColor: const Color(0xFF0F1233),
      body: NightBackground(
        header: true,
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final p = c.player;
            final equipped = c.equippedTitle;
            return Padding(
              padding: EdgeInsets.fromLTRB(14, top + 6, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OrnateTopBar(
                    title: '프로필',
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 8),
                  ProfileCard(
                    name: c.profile.name,
                    level: p.level.level,
                    look: c.profile.look,
                    spiritKind: c.profile.spiritKind,
                    spiritName: c.firstSpiritName,
                    pet: c.companionPet,
                    title: equipped == null
                        ? null
                        : TitleRules.info(equipped).name,
                    onEditName: () => _rename(context, c),
                  ),
                  const SizedBox(height: 10),
                  _Tabs(
                    labels: const ['정보', '기록'],
                    index: _tab,
                    onTap: (i) => setState(() => _tab = i),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _tab == 0
                        ? _InfoTab(controller: c, player: p, equipped: equipped)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (c.receivedLetters.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: FrameButton(
                                    label:
                                        '${c.firstSpiritName}의 편지 ${c.receivedLetters.length}통',
                                    icon: Icons.mail_rounded,
                                    height: 42,
                                    onPressed: () => _showLetters(context, c),
                                  ),
                                ),
                              Expanded(
                                  child: RecordsScreen(
                                      player: p, embedded: true)),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab(
      {required this.controller, required this.player, this.equipped});

  final AppController controller;
  final PlayerState player;
  final TitleId? equipped;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (c.farewellDone) ...[
          FrameButton(
            label: '내 펫 ${c.pets.pets.length}마리',
            icon: Icons.pets_rounded,
            height: 44,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PetScreen(controller: c))),
          ),
          const SizedBox(height: 10),
        ],
        _Section(title: '칭호', children: [
          KText('얻은 칭호를 누르면 대표 칭호로 걸어요. '
              '${player.titles.length} / ${TitleRules.all.length}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          const SizedBox(height: 6),
          for (final t in TitleRules.all)
            _TitleRow(
              info: t,
              earned: player.titles.contains(t.id),
              equipped: t.id == equipped,
              onTap: player.titles.contains(t.id)
                  ? () => c.setEquippedTitle(t.id)
                  : null,
            ),
        ]),
      ],
    );
  }
}

/// 칭호 한 줄: 얻은 칭호는 이름, 얻지 못한 칭호는 흐리게 + 얻는 방법
class _TitleRow extends StatelessWidget {
  const _TitleRow({
    required this.info,
    required this.earned,
    required this.equipped,
    this.onTap,
  });

  final TitleInfo info;
  final bool earned;
  final bool equipped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: earned ? 1 : 0.55,
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
            decoration: BoxDecoration(
              color: equipped ? const Color(0x55E8B04A) : const Color(0x66101333),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: equipped
                      ? AppColors.goldBright
                      : AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              SizedBox(
                width: 38,
                height: 38,
                child: Image.asset('assets/images/title_${info.id.name}.png',
                    errorBuilder: (_, __, ___) => Icon(titleIcon(info.id),
                        color: earned
                            ? AppColors.goldBright
                            : AppColors.textMuted)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(earned ? info.name : '???',
                        style: AppText.title(15,
                            color: earned ? AppColors.text : AppColors.textMuted)),
                    KText(earned ? info.hint : '얻는 방법: ${info.hint}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11.5)),
                  ],
                ),
              ),
              if (equipped)
                const Text('대표',
                    style: TextStyle(
                        color: AppColors.goldBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

/// 이름 바꾸기 (첫 1회 무료 / 금화)
Future<void> _rename(BuildContext context, AppController c) async {
  final cost = c.renameCost;
  final name = await askText(context,
      title: cost == 0 ? '이름 바꾸기 (처음 한 번은 무료)' : '이름 바꾸기 (금화 $cost)',
      initial: c.profile.name,
      maxLength: 10);
  if (name == null || !context.mounted) return;
  if (name.trim().isEmpty || name.trim() == c.profile.name) return;
  final ok = await c.renameHero(name);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? '${josa(name.trim(), '으로/로')} 바꿨어요.'
          : '금화가 모자라요. (금화 $cost)')));
}

/// 짧은 글 입력 창 (이름 바꾸기)
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String initial,
  required int maxLength,
}) {
  final text = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.night,
      title: Text(title, style: const TextStyle(color: AppColors.goldBright)),
      content: TextField(
        controller: text,
        autofocus: true,
        maxLength: maxLength,
        style: const TextStyle(color: AppColors.text),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('그만두기'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(text.text),
          child: const Text('저장'),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OrnatePanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.title(17)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.labels, required this.index, required this.onTap});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xCC12153A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.55)),
        ),
        child: Row(children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  decoration: i == index
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFFB98330), Color(0xFF6E4B1A)],
                          ),
                          border: Border.all(color: AppColors.goldBright),
                        )
                      : null,
                  child: Text(labels[i],
                      style: TextStyle(
                          color: i == index
                              ? const Color(0xFFFFF3C8)
                              : AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ]),
      );
}

/// 떠난 정령이 보낸 편지 모아 보기 (11-11 #37)
Future<void> _showLetters(BuildContext context, AppController c) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.night,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheet).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            children: [
              Text('${c.firstSpiritName}의 편지', style: AppText.title(20)),
              const SizedBox(height: 10),
              for (final l in c.receivedLetters.reversed) ...[
                OrnatePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.title,
                          style: AppText.title(16, color: AppColors.goldBright)),
                      const SizedBox(height: 6),
                      KText(l.body,
                          style: const TextStyle(
                              color: AppColors.text, height: 1.45)),
                      const SizedBox(height: 6),
                      KText('선물: ${l.giftLabel}',
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
