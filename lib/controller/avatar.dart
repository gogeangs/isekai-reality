part of '../app_controller.dart';

/// 묶음 75 #335: 프로필 사진 고르기 (1단계 · 게임 속 그림에서)
enum AvatarTab {
  hero('주인공'),
  pet('펫'),
  npc('마을 사람'),
  ally('동료'),
  title('배지');

  const AvatarTab(this.label);
  final String label;
}

/// 고를 수 있는 사진 하나: 저장 열쇠 · 그림 이름(assets/images/<face>.webp) · 이름
class AvatarChoice {
  const AvatarChoice(this.key, this.face, this.label);
  final String key, face, label;
}

/// 공개 얼굴 그림 이름 (남이 보낸 값도 이 모양만 쓴다)
final RegExp kFaceStem = RegExp(r'^[a-zA-Z0-9_]{1,48}$');

String _stemOf(String asset) => asset.split('/').last.replaceAll('.webp', '');

extension AvatarOps on AppController {
  String get avatarKey => _profile.avatar;

  List<AvatarChoice> avatarChoices(AvatarTab t) => switch (t) {
        AvatarTab.hero => [
            AvatarChoice(
                'hero', 'portrait_${_profile.look.name}', _profile.name),
          ],
        AvatarTab.pet => [
            for (final p in _pets.pets)
              AvatarChoice(
                  'pet:${p.uid}',
                  _stemOf(p.info.asset(adult: p.adult, awake: p.awake)),
                  p.name),
          ],
        AvatarTab.npc => [
            for (final n in Npc.values)
              if (favorStage(n) == FavorStage.best)
                AvatarChoice(
                    'npc:${n.name}', 'npc_${n.name}', VillageRules.npc(n).name),
          ],
        AvatarTab.ally => [
            for (final a in allies)
              if (a.story case final s?)
                if (StoryAlly.values.where((x) => x.name == s).firstOrNull
                    case final id?)
                  AvatarChoice('ally:$s', _stemOf(Act3Rules.story(id).face),
                      Act3Rules.story(id).name),
          ],
        AvatarTab.title => [
            for (final id in titlesNewestFirst)
              if (kTitleArt.contains(TitleRules.asset(id)))
                AvatarChoice('title:${id.name}', TitleRules.asset(id),
                    TitleRules.info(id).name),
          ],
      };

  /// 지금 프로필 사진 그림 이름. 모르는 열쇠 · 그림 없음 · 떠나보낸 펫이면 주인공 얼굴
  String get avatarFace {
    final k = _profile.avatar;
    if (k != 'hero') {
      final tab = switch (k.split(':').first) {
        'pet' => AvatarTab.pet,
        'npc' => AvatarTab.npc,
        'ally' => AvatarTab.ally,
        'title' => AvatarTab.title,
        _ => null,
      };
      if (tab != null) {
        for (final x in avatarChoices(tab)) {
          if (x.key == k) return x.face;
        }
      }
    }
    return 'portrait_${_profile.look.name}';
  }

  Future<void> setAvatar(String key) =>
      updateProfile(_profile.copyWith(avatar: key));

  /// 고를 사진이 둘 이상이면 처음 한 번 정령 한마디
  bool get _avatarHintDue {
    if (_profile.avatarHinted) return false;
    var n = 0;
    for (final t in AvatarTab.values) {
      n += avatarChoices(t).length;
      if (n > 1) return true;
    }
    return false;
  }

  static const String avatarHintLine = '프로필 사진을 바꿀 수 있어! 얼굴을 눌러 봐.';
}
