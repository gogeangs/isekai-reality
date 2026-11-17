import 'dart:io' show Platform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_config.dart';

enum LoginProvider { apple, google }

/// 로그인한 사람
class CloudUser {
  const CloudUser({required this.uid, required this.provider, this.label});

  final String uid;
  final LoginProvider provider;

  /// 화면에 보일 이름 (이메일 또는 「Apple 계정」)
  final String? label;
}

/// 로그인 결과
enum LoginStatus { ok, cancelled, failed, unavailable }

/// 묶음 55 #245: 로그인 (Apple · Google). 테스트는 [FakeCloudAuth]
abstract class CloudAuth {
  CloudUser? get current;

  /// 이 휴대폰에서 쓸 수 있는 로그인
  List<LoginProvider> get providers;

  Future<(LoginStatus, CloudUser?)> signIn(LoginProvider p);
  Future<void> signOut();

  /// 서버에 보낼 신분증 (만료되면 새로)
  Future<String?> idToken();

  /// 계정 삭제를 요청할 때 (Apple 은 로그인 연결을 끊음)
  Future<void> revoke();
}

/// Firebase 로그인
class FirebaseCloudAuth implements CloudAuth {
  FirebaseCloudAuth._();

  static FirebaseCloudAuth? _instance;
  static bool _googleReady = false;

  /// 설정값이 있으면 Firebase 를 켠다. 없거나 실패하면 null (로그인 「준비 중」)
  static Future<FirebaseCloudAuth?> start() async {
    if (!CloudConfig.configured) return null;
    if (_instance != null) return _instance;
    try {
      final ios = Platform.isIOS;
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: ios ? CloudConfig.apiKeyIos : CloudConfig.apiKeyAndroid,
          appId: ios ? CloudConfig.appIdIos : CloudConfig.appIdAndroid,
          messagingSenderId: CloudConfig.senderId,
          projectId: CloudConfig.projectId,
          storageBucket: CloudConfig.storageBucket.isEmpty ? null : CloudConfig.storageBucket,
          iosClientId: CloudConfig.iosClientId.isEmpty ? null : CloudConfig.iosClientId,
          iosBundleId: ios ? 'kr.itso.isekaiReality' : null,
        ),
      );
      return _instance = FirebaseCloudAuth._();
    } catch (e) {
      debugPrint('Firebase 시작 실패: $e');
      return null;
    }
  }

  FirebaseAuth get _auth => FirebaseAuth.instance;

  static CloudUser? _toUser(User? u) {
    if (u == null) return null;
    final apple = u.providerData.any((p) => p.providerId == 'apple.com');
    return CloudUser(
      uid: u.uid,
      provider: apple ? LoginProvider.apple : LoginProvider.google,
      label: u.email ?? (apple ? 'Apple 계정' : 'Google 계정'),
    );
  }

  @override
  CloudUser? get current => _toUser(_auth.currentUser);

  @override
  List<LoginProvider> get providers => [
        // Apple 은 iPhone 에서만 (Android 는 Apple 서비스 ID 설정이 더 필요)
        if (Platform.isIOS) LoginProvider.apple,
        LoginProvider.google,
      ];

  Future<void> _initGoogle() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS && CloudConfig.iosClientId.isNotEmpty
          ? CloudConfig.iosClientId
          : null,
      serverClientId: CloudConfig.webClientId.isEmpty ? null : CloudConfig.webClientId,
    );
    _googleReady = true;
  }

  @override
  Future<(LoginStatus, CloudUser?)> signIn(LoginProvider p) async {
    try {
      final UserCredential cred;
      if (p == LoginProvider.apple) {
        final apple = AppleAuthProvider()..addScope('email');
        cred = await _auth.signInWithProvider(apple);
      } else {
        await _initGoogle();
        final account = await GoogleSignIn.instance.authenticate();
        final token = account.authentication.idToken;
        if (token == null) return (LoginStatus.failed, null);
        cred = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: token));
      }
      return (LoginStatus.ok, _toUser(cred.user));
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return (LoginStatus.cancelled, null);
      debugPrint('구글 로그인 실패: ${e.code}');
      return (LoginStatus.failed, null);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled' || e.code == 'web-context-canceled' || e.code == 'user-cancelled') {
        return (LoginStatus.cancelled, null);
      }
      debugPrint('로그인 실패: ${e.code}');
      return (LoginStatus.failed, null);
    } catch (e) {
      debugPrint('로그인 실패: $e');
      return (LoginStatus.failed, null);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  @override
  Future<String?> idToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> revoke() async {
    final u = _auth.currentUser;
    if (u == null) return;
    // Apple 정책: 계정을 지울 때 Apple 로그인 연결도 끊는다 (다시 확인 창이 한 번 뜸)
    if (u.providerData.any((p) => p.providerId == 'apple.com')) {
      try {
        final r = await u.reauthenticateWithProvider(AppleAuthProvider());
        final code = r.additionalUserInfo?.authorizationCode;
        if (code != null) await _auth.revokeTokenWithAuthorizationCode(code);
      } catch (e) {
        debugPrint('Apple 연결 끊기 실패: $e');
      }
    }
  }
}

/// 테스트 · 설정값이 없는 빌드용
class FakeCloudAuth implements CloudAuth {
  FakeCloudAuth({this.uid = 'u1', this.provider = LoginProvider.google, this.result = LoginStatus.ok});

  final String uid;
  final LoginProvider provider;
  LoginStatus result;
  CloudUser? _user;
  int revoked = 0;

  @override
  CloudUser? get current => _user;

  @override
  List<LoginProvider> get providers => const [LoginProvider.apple, LoginProvider.google];

  @override
  Future<(LoginStatus, CloudUser?)> signIn(LoginProvider p) async {
    if (result != LoginStatus.ok) return (result, null);
    _user = CloudUser(uid: uid, provider: p, label: 'tester@example.com');
    return (LoginStatus.ok, _user);
  }

  @override
  Future<void> signOut() async => _user = null;

  @override
  Future<String?> idToken() async => _user == null ? null : 'token';

  @override
  Future<void> revoke() async => revoked++;
}
