import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 보상형 광고 (묶음 15 #103, AdMob). 끝까지 본 경우에만 보상.
///
/// - 빌드에 ADS_ON=1 일 때만 켠다. 광고 단위 ID 는 저장소 변수에서 넣고,
///   없으면 Google 시험 광고 ID 를 쓴다(시험 빌드는 언제나 시험 광고).
/// - 맞춤형 광고는 사용자가 허용한 경우에만. 아니면 비맞춤 광고를 요청한다.
/// - 유럽 등 동의가 필요한 지역은 Google 동의 창(UMP)을 먼저 띄운다.
class RewardedAds {
  RewardedAds._();

  static final RewardedAds instance = RewardedAds._();

  static const bool enabled = String.fromEnvironment('ADS_ON') == '1';

  static const _androidUnit = String.fromEnvironment('ADMOB_REWARDED_ANDROID',
      defaultValue: 'ca-app-pub-3940256099942544/5224354917');
  static const _iosUnit = String.fromEnvironment('ADMOB_REWARDED_IOS',
      defaultValue: 'ca-app-pub-3940256099942544/1712485313');

  static String get unitId => Platform.isIOS ? _iosUnit : _androidUnit;

  /// 아이폰이면 애플 추적 허용 창(ATT)을 띄운다. 허용이면 true,
  /// 거부·제한이면 false, 아이폰이 아니면 null (안드로이드는 앱 안 선택으로)
  static Future<bool?> requestTracking() async {
    if (!Platform.isIOS) return null;
    try {
      var s = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (s == TrackingStatus.notDetermined) {
        s = await AppTrackingTransparency.requestTrackingAuthorization();
      }
      return s == TrackingStatus.authorized;
    } catch (_) {
      return false;
    }
  }

  Future<void>? _ready;

  Future<void> _init() => _ready ??= () async {
        final c = Completer<void>();
        ConsentInformation.instance.requestConsentInfoUpdate(
          ConsentRequestParameters(),
          () async {
            await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
            if (!c.isCompleted) c.complete();
          },
          (_) {
            if (!c.isCompleted) c.complete();
          },
        );
        await c.future.timeout(const Duration(seconds: 10), onTimeout: () {});
        await MobileAds.instance.initialize();
      }();

  /// 광고를 불러와 보여 준다. 보상을 받았으면 true.
  Future<bool> show({required bool personalized}) async {
    if (!enabled) return false;
    try {
      await _init();
    } catch (_) {
      _ready = null;
      return false;
    }
    final done = Completer<bool>();
    RewardedAd.load(
      adUnitId: unitId,
      request: AdRequest(nonPersonalizedAds: !personalized),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          var earned = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              if (!done.isCompleted) done.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (a, _) {
              a.dispose();
              if (!done.isCompleted) done.complete(false);
            },
          );
          ad.show(onUserEarnedReward: (_, __) => earned = true);
        },
        onAdFailedToLoad: (_) {
          if (!done.isCompleted) done.complete(false);
        },
      ),
    );
    return done.future
        .timeout(const Duration(minutes: 3), onTimeout: () => false);
  }
}
