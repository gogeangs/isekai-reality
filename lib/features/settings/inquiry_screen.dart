import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_config.dart';
import '../../app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/ornaments.dart';
import '../../theme/top_notice.dart';

/// 설정 → 문의 (묶음 56 #248). 로그인하지 않아도 보낼 수 있고, 답은 게임 안 우편으로 와요.
/// 함께 보내는 것: 계정 번호(로그인 전엔 앱 설치 번호) · 앱 버전 · 휴대폰 기종. 비밀번호 · 위치는 보내지 않음
class InquiryScreen extends StatefulWidget {
  const InquiryScreen({super.key, required this.controller, this.picker, this.model});

  final AppController controller;

  /// 시험용: 사진 고르기 · 휴대폰 기종
  final Future<Uint8List?> Function()? picker;
  final String? model;

  static Future<void> open(BuildContext context, AppController c) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => InquiryScreen(controller: c)));

  static const kinds = [
    ('bug', '오류'),
    ('record', '기록 · 계정'),
    ('trade', '거래'),
    ('party', '파티 · 길드'),
    ('report', '신고'),
    ('appeal', '제재 이의 제기'),
    ('etc', '기타'),
  ];

  @override
  State<InquiryScreen> createState() => _InquiryScreenState();
}

class _InquiryScreenState extends State<InquiryScreen> {
  AppController get c => widget.controller;
  String? _kind;
  final _text = TextEditingController();
  final _email = TextEditingController();
  Uint8List? _photo;
  bool _sending = false;
  String _code = '';
  String _model = '';

  @override
  void initState() {
    super.initState();
    c.accountCode().then((v) {
      if (mounted) setState(() => _code = v);
    });
    _loadModel();
  }

  Future<void> _loadModel() async {
    var m = widget.model;
    if (m == null) {
      try {
        final d = DeviceInfoPlugin();
        if (Platform.isIOS) {
          final i = await d.iosInfo;
          m = '${i.utsname.machine} · iOS ${i.systemVersion}';
        } else if (Platform.isAndroid) {
          final a = await d.androidInfo;
          m = '${a.manufacturer} ${a.model} · Android ${a.version.release}';
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _model = m ?? Platform.operatingSystem);
  }

  @override
  void dispose() {
    _text.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    Uint8List? bytes;
    if (widget.picker != null) {
      bytes = await widget.picker!();
    } else {
      try {
        final x = await ImagePicker()
            .pickImage(source: ImageSource.gallery, maxWidth: 1280, maxHeight: 1280, imageQuality: 70);
        bytes = await x?.readAsBytes();
      } catch (_) {}
    }
    if (bytes == null || !mounted) return;
    if (bytes.length > 500000) {
      showTopNotice(context, '사진이 너무 커요. 다른 사진을 골라 주세요', icon: Icons.info_outline_rounded);
      return;
    }
    setState(() => _photo = bytes);
  }

  bool get _ready => _kind != null && _text.text.trim().length >= 2 && !_sending;

  Future<void> _send() async {
    if (!_ready) return;
    setState(() => _sending = true);
    final r = await c.sendInquiry(
      kind: _kind!,
      text: _text.text,
      photo: _photo,
      email: _email.text,
      model: _model,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    switch (r) {
      case InquirySend.ok:
        showTopNotice(context, '문의를 보냈어요. 답은 게임 안 우편으로 보내 드려요',
            icon: Icons.mark_email_read_rounded);
        Navigator.of(context).pop();
      case InquirySend.tooMany:
        showTopNotice(context, '문의는 하루 3건까지 보낼 수 있어요', icon: Icons.info_outline_rounded);
      case InquirySend.offline:
        showTopNotice(context, '보내지 못했어요. 인터넷을 확인하고 다시 보내 주세요',
            icon: Icons.wifi_off_rounded);
      case InquirySend.bad:
        showTopNotice(context, '보내지 못했어요. 내용을 확인해 주세요', icon: Icons.info_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      key: const Key('inquiryScreen'),
      backgroundColor: AppColors.deepNight,
      body: NightBackground(
        header: true,
        child: ListView(
          padding: EdgeInsets.fromLTRB(14, top + 6, 14, 28),
          children: [
            OrnateTopBar(title: '문의', onBack: () => Navigator.of(context).maybePop()),
            const SizedBox(height: 10),
            OrnatePanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('어떤 문의인가요?', style: AppText.title(16)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final (k, name) in InquiryScreen.kinds)
                    ChoiceChip(
                      key: Key('inquiryKind_$k'),
                      label: Text(name),
                      selected: _kind == k,
                      onSelected: (_) => setState(() => _kind = k),
                    ),
                ]),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('inquiryText'),
                  controller: _text,
                  maxLines: 7,
                  maxLength: 2000,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(color: AppColors.text, height: 1.4),
                  decoration: const InputDecoration(
                    hintText: '무슨 일이 있었는지 적어 주세요',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  if (_photo != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(_photo!,
                          key: const Key('inquiryPhoto'),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                              width: 56, height: 56, child: Icon(Icons.image_rounded, color: AppColors.textMuted))),
                    ),
                    TextButton(
                        onPressed: () => setState(() => _photo = null),
                        child: const Text('사진 빼기')),
                  ] else
                    TextButton.icon(
                      key: const Key('inquiryPick'),
                      onPressed: _pick,
                      icon: const Icon(Icons.add_photo_alternate_rounded),
                      label: const Text('화면 사진 한 장 (선택)'),
                    ),
                ]),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('inquiryEmail'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.text),
                  decoration: const InputDecoration(
                    labelText: '답받을 이메일 (선택)',
                    helperText: '기록을 잃어버린 경우처럼 앱 밖에서 답을 받아야 할 때만 적어 주세요',
                    helperMaxLines: 2,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            OrnatePanel(
              key: const Key('inquiryAuto'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('함께 보내는 것', style: AppText.title(14, color: AppColors.goldBright)),
                const SizedBox(height: 4),
                _info(c.cloud.signedIn ? '계정 번호' : '앱 설치 번호', _code),
                _info('앱 버전', appVersionLabel),
                _info('휴대폰 기종', _model),
                const SizedBox(height: 4),
                const KText('비밀번호와 위치는 보내지 않아요. 답은 영업일 3일 안에 게임 안 우편 「문의에 답이 왔어요」로 와요.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 12),
            GoldButton(
              key: const Key('inquirySend'),
              label: _sending ? '보내는 중…' : '보내기',
              height: 50,
              fontSize: 19,
              onPressed: _ready ? _send : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          SizedBox(width: 92, child: Text(k, style: const TextStyle(color: AppColors.textMuted, fontSize: 13))),
          Expanded(child: Text(v, style: const TextStyle(color: AppColors.text, fontSize: 13))),
        ]),
      );
}
