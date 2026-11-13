import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../core/models/lens_state.dart';
import '../../core/rules/rules.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';
import 'album_files.dart';
import 'consent_note.dart';
import 'lens_output.dart';
import 'photo_frame.dart';
import '../tutorial/feature_tour.dart';

/// 감정 앨범 (11-11 #97): 감정할 때마다 사진 한 장이 쌓인다.
/// 위에는 「사진 N장」만. 아직 못 찾은 종족은 이름·개수·실루엣 모두 숨긴다.
/// 맨 끝 빈 액자 「다음 사진을 찍어 봐요」를 누르면 돋보기 카메라로.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key, required this.controller, this.onShootNext});

  final AppController controller;

  /// 빈 액자를 눌렀을 때 (돋보기 카메라)
  final VoidCallback? onShootNext;

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  /// 종족별로 모아 보기 (null = 모두)
  String? _race;

  AppController get c => widget.controller;

  static String dateLabel(DateTime? at) =>
      at == null ? '예전 감정' : '${at.year}.${at.month}.${at.day}';

  static String raceNames(List<String> races) => [
        for (final n in {...races})
          if (LensRules.parse(n) case final r?) LensRules.info(r).name,
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return TourScreenMark(name: 'album', child: Scaffold(
      backgroundColor: AppColors.abyss,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final all = c.album.reversed.toList(); // 새 사진부터
            // 필터는 이미 찍은 종족만
            final races = <String>[
              for (final r in Race.values)
                if (all.any((p) => p.races.contains(r.name))) r.name,
            ];
            final shown = _race == null
                ? all
                : [for (final p in all) if (p.races.contains(_race)) p];
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 24),
              children: [
                OrnateTopBar(
                    title: '감정 앨범',
                    onBack: () => Navigator.of(context).maybePop()),
                const SizedBox(height: 8),
                Text('사진 ${all.length}장',
                    key: const Key('albumCount'),
                    textAlign: TextAlign.center,
                    style: AppText.title(19, color: AppColors.goldBright)),
                const SizedBox(height: 4),
                const Text('사진은 이 휴대폰 안에만 있어요. 앱을 지우면 사라질 수 있어요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                if (races.length > 1) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final r in [null, ...races])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(r == null ? '모두' : raceNames([r])),
                            selected: _race == r,
                            onSelected: (_) => setState(() => _race = r),
                            selectedColor: AppColors.gold,
                            backgroundColor: AppColors.chipBg,
                            labelStyle: TextStyle(
                                color: _race == r
                                    ? AppColors.night
                                    : AppColors.text,
                                fontWeight: FontWeight.w700),
                            showCheckmark: false,
                          ),
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                  children: [
                    for (final p in shown)
                      _PhotoTile(
                          key: Key('album_${p.id}'),
                          photo: p,
                          onTap: () => _open(p)),
                    _EmptyFrame(onTap: () {
                      Navigator.of(context).maybePop();
                      widget.onShootNext?.call();
                    }),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    ));
  }

  Future<void> _open(AlbumPhoto p) => Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => _PhotoView(controller: c, photo: p)));
}

/// 사진 그림 (파일이 없으면 종족 장식으로 대신)
class _PhotoImage extends StatefulWidget {
  const _PhotoImage({required this.photo, this.fit = BoxFit.cover});

  final AlbumPhoto photo;
  final BoxFit fit;

  @override
  State<_PhotoImage> createState() => _PhotoImageState();
}

class _PhotoImageState extends State<_PhotoImage> {
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    final f = widget.photo.file;
    if (f != null) _bytes = AlbumFiles.reader(f);
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _RaceArt(races: widget.photo.races);
    if (_bytes == null) return fallback;
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (_, snap) {
        final b = snap.data;
        if (b == null) return fallback;
        return Image.memory(b, fit: widget.fit, gaplessPlayback: true);
      },
    );
  }
}

/// 사진 파일이 없는 감정 (예전 기록·저장 실패): 종족 장식 그림
class _RaceArt extends StatelessWidget {
  const _RaceArt({required this.races});

  final List<String> races;

  @override
  Widget build(BuildContext context) {
    final r = races.isEmpty ? null : LensRules.parse(races.first);
    final info = r == null ? null : LensRules.info(r);
    final color = Color(info?.color ?? 0xFFF5D06A);
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [
          color.withValues(alpha: 0.35),
          const Color(0xFF141638),
        ]),
      ),
      alignment: Alignment.center,
      child: info == null
          ? const Icon(Icons.photo_rounded, color: AppColors.textMuted)
          : Image.asset(info.asset,
              width: 90,
              height: 90,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.auto_awesome_rounded, size: 46, color: color)),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({super.key, required this.photo, required this.onTap});

  final AlbumPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.slotBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: photo.firsts.isNotEmpty
                  ? AppColors.goldBright
                  : AppColors.gold.withValues(alpha: 0.5),
              width: photo.firsts.isNotEmpty ? 2 : 1),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _PhotoImage(photo: photo)),
              if (photo.firsts.isNotEmpty)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('처음 만난 종족!',
                        style: TextStyle(
                            color: AppColors.night,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(_AlbumScreenState.raceNames(photo.races),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          Text(_AlbumScreenState.dateLabel(photo.at),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ),
    );
  }
}

/// 맨 끝 빈 액자
class _EmptyFrame extends StatelessWidget {
  const _EmptyFrame({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('albumNext'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF10132F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_a_photo_rounded,
              size: 34, color: AppColors.gold.withValues(alpha: 0.7)),
          const SizedBox(height: 8),
          const KText('다음 사진을 찍어 봐요',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
      ),
    );
  }
}

/// 크게 보기 · 저장 · 공유 · 앨범에서 지우기
class _PhotoView extends StatefulWidget {
  const _PhotoView({required this.controller, required this.photo});

  final AppController controller;
  final AlbumPhoto photo;

  @override
  State<_PhotoView> createState() => _PhotoViewState();
}

class _PhotoViewState extends State<_PhotoView> {
  bool _busy = false;

  AlbumPhoto get p => widget.photo;

  Future<Uint8List?> _bytes() async =>
      p.file == null ? null : AlbumFiles.reader(p.file!);

  Future<void> _save() async {
    final b = await _bytes();
    if (!mounted) return;
    if (b == null) {
      showTopNotice(context, '이 기록에는 사진이 없어요.');
      return;
    }
    if (!await confirmOthersConsent(context, share: false) || !mounted) return;
    setState(() => _busy = true);
    final err = await LensOutput.saver(b);
    if (!mounted) return;
    setState(() => _busy = false);
    showTopNotice(context, err ?? '사진 앨범에 저장했어요!');
  }

  Future<void> _share(BuildContext button) async {
    final b = await _bytes();
    if (!mounted) return;
    if (b == null) {
      showTopNotice(context, '이 기록에는 사진이 없어요.');
      return;
    }
    if (!await confirmOthersConsent(context, share: true) || !mounted) return;
    if (!button.mounted) return;
    final box = button.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => _busy = true);
    try {
      final races = [
        for (final n in p.races)
          if (LensRules.parse(n) case final r?) r,
      ];
      await LensOutput.sharer(
          b,
          '마법 돋보기로 감정해 보니 ${PhotoFrame.raceLine(races)}! #이세계가현실이라면',
          origin);
    } catch (_) {
      if (mounted) showTopNotice(context, '공유하지 못했어요.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => GameAlert(
        title: const Text('앨범에서 지우기'),
        content: const KText('이 사진을 앨범에서 지울까요? 지운 사진은 되돌릴 수 없어요. '
            '감정한 종족 기록은 그대로 남아요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('그만둘래요')),
          TextButton(
              key: const Key('albumDeleteOk'),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('지우기')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final file = await widget.controller.deleteAlbumPhoto(p.id);
    if (file != null) await AlbumFiles.deleter(file);
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.abyss,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OrnateTopBar(
                  title: _AlbumScreenState.raceNames(p.races),
                  onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 4),
              Text(_AlbumScreenState.dateLabel(p.at),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _PhotoImage(photo: p, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: GoldButton(
                      label: '저장',
                      height: 46,
                      onPressed: _busy ? null : _save),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Builder(
                    builder: (b) => FrameButton(
                        label: '공유',
                        height: 46,
                        onPressed: _busy ? null : () => _share(b)),
                  ),
                ),
              ]),
              TextButton(
                key: const Key('albumDelete'),
                onPressed: _busy ? null : _delete,
                child: const Text('앨범에서 지우기',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
