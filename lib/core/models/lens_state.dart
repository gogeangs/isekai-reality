/// 감정 앨범의 사진 한 장 (11-11 #97). 사진 파일은 휴대폰 안(앱 폴더)에만 둔다.
class AlbumPhoto {
  const AlbumPhoto({
    required this.id,
    required this.races,
    this.at,
    this.file,
    this.firsts = const [],
  });

  final String id;

  /// 감정된 종족 ([Race] 이름)
  final List<String> races;

  /// 찍은 때 (예전 감정 기록에서 옮긴 것은 null)
  final DateTime? at;

  /// 앱 폴더 안 사진 파일 이름 (사진이 없으면 null: 종족 그림으로 대신 보여 준다)
  final String? file;

  /// 이 사진에서 처음 만난 종족 (「처음 만난 종족!」)
  final List<String> firsts;

  AlbumPhoto withFile(String? f) =>
      AlbumPhoto(id: id, races: races, at: at, file: f, firsts: firsts);

  Map<String, dynamic> toJson() => {
        'id': id,
        'races': races,
        if (at != null) 'at': at!.toIso8601String(),
        if (file != null) 'file': file,
        if (firsts.isNotEmpty) 'firsts': firsts,
      };

  factory AlbumPhoto.fromJson(Map<String, dynamic> j) => AlbumPhoto(
        id: j['id'] as String,
        races: [for (final s in (j['races'] as List?) ?? const []) s as String],
        at: DateTime.tryParse('${j['at'] ?? ''}'),
        file: j['file'] as String?,
        firsts: [for (final s in (j['firsts'] as List?) ?? const []) s as String],
      );
}

/// 마법 돋보기 감정 기록 (11-11 #60). 따로 저장한다 ('lens').
/// 11-11 #97: 감정할 때마다 앨범에 사진 한 장 (사진은 휴대폰 안에만).
class LensState {
  const LensState({
    this.seen = const [],
    this.counts = const {},
    this.day,
    this.rewardedToday = 0,
    this.album = const [],
    this.freeDay,
  });

  /// 오늘 무료 감정을 쓴 날 ('yyyy-mm-dd', 묶음 19 #154). 예전 기록엔 없음
  final String? freeDay;

  /// 감정 앨범 (찍은 차례대로)
  final List<AlbumPhoto> album;

  /// 한 번이라도 감정된 종족 (도감 「종족」)
  final List<String> seen;

  /// 종족별 감정된 횟수
  final Map<String, int> counts;

  /// [rewardedToday] 를 센 날 ('yyyy-mm-dd')
  final String? day;

  /// 오늘 보상을 받은 감정 횟수
  final int rewardedToday;

  LensState copyWith({
    List<String>? seen,
    Map<String, int>? counts,
    String? day,
    int? rewardedToday,
    List<AlbumPhoto>? album,
    String? freeDay,
  }) =>
      LensState(
        seen: seen ?? this.seen,
        counts: counts ?? this.counts,
        day: day ?? this.day,
        rewardedToday: rewardedToday ?? this.rewardedToday,
        album: album ?? this.album,
        freeDay: freeDay ?? this.freeDay,
      );

  Map<String, dynamic> toJson() => {
        'seen': seen,
        'counts': counts,
        'day': day,
        'rewardedToday': rewardedToday,
        'album': [for (final p in album) p.toJson()],
        if (freeDay != null) 'freeDay': freeDay,
      };

  factory LensState.fromJson(Map<String, dynamic> j) {
    final seen = [for (final s in (j['seen'] as List?) ?? const []) s as String];
    final album = j['album'] is List
        ? [
            for (final e in j['album'] as List)
              AlbumPhoto.fromJson(Map<String, dynamic>.from(e as Map)),
          ]
        // 앨범 전에 감정한 기록: 종족마다 한 장씩 앨범으로 옮긴다 (잃지 않게)
        : [
            for (final r in seen)
              AlbumPhoto(id: 'old_$r', races: [r], firsts: [r]),
          ];
    return LensState(
        seen: seen,
        album: album,
        counts: {
          for (final e in ((j['counts'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        day: j['day'] as String?,
        rewardedToday: (j['rewardedToday'] as num?)?.toInt() ?? 0,
        freeDay: j['freeDay'] as String?,
      );
  }
}
