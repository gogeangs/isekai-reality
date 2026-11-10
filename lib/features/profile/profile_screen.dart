import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/player_state.dart';
import '../../core/rules/rules.dart';
import '../../data/storage/record_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../bulssi/spirit_art.dart';
import '../records/records_screen.dart';

/// 장비 칸 (11-10 #27, 장비는 다음 묶음)
const equipSlots = ['무기', '머리', '몸', '장갑', '신발', '장신구'];

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
  });

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
              Row(children: [
                SpiritArt(kind: spiritKind, size: 26),
                const SizedBox(width: 4),
                Text('함께하는 정령 · $spiritName',
                    style: const TextStyle(
                        color: AppColors.text, fontSize: 12)),
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
                    spiritName: c.profile.spiritName,
                    title: equipped == null
                        ? null
                        : TitleRules.info(equipped).name,
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
                        : RecordsScreen(player: p, embedded: true),
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
    final earned = [
      for (final t in TitleRules.all)
        if (player.titles.contains(t.id)) t,
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _Section(title: '대표 칭호', children: [
          if (earned.isEmpty)
            const Text('아직 얻은 칭호가 없어요. 도감에서 얻는 방법을 볼 수 있어요.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13))
          else
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in earned)
                ChoiceChip(
                  label: Text(t.name),
                  selected: t.id == equipped,
                  onSelected: (_) => c.setEquippedTitle(t.id),
                  selectedColor: AppColors.gold,
                  backgroundColor: const Color(0xFF1A1D4A),
                  labelStyle: TextStyle(
                      color: t.id == equipped
                          ? const Color(0xFF3A2208)
                          : AppColors.text,
                      fontWeight: FontWeight.w700),
                  side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.6)),
                ),
            ]),
        ]),
        _Section(title: '장비', children: [
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.3,
            children: [
              for (final slot in equipSlots)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0x66101333),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(slot,
                        style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Text('비어 있음',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ]),
                ),
            ],
          ),
        ]),
        _Section(title: '이름', children: [
          _Row(
            label: '내 이름',
            value: c.profile.name,
            onTap: () async {
              final name = await askText(context,
                  title: '이름 바꾸기', initial: c.profile.name, maxLength: 10);
              if (name != null) await c.renameHero(name);
            },
          ),
          _Row(
            label: '정령 이름 (${c.profile.spiritKind.elementName})',
            value: c.profile.spiritName,
            onTap: () async {
              final name = await askText(context,
                  title: '정령 이름 바꾸기',
                  initial: c.profile.spiritName,
                  maxLength: 8);
              if (name != null) await c.renameSpirit(name);
            },
          ),
        ]),
      ],
    );
  }
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(color: AppColors.text))),
            Text(value, style: const TextStyle(color: AppColors.textMuted)),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ]),
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
