import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 휴대폰 알림 (정령 원정이 돌아올 때, 여관 휴식이 끝날 때).
/// 게임 규칙은 알림이 없어도 똑같이 돌아간다.
abstract class Notifier {
  /// [at] 에 알림을 하나 예약한다. 같은 [id] 는 바꿔치기한다.
  Future<void> schedule(int id, DateTime at, String title, String body);

  Future<void> cancel(int id);
}

/// 알림 id
class NotifyId {
  NotifyId._();
  static const int expedition = 1;
  static const int rest = 2;
  static const int hatch = 3;
  static const int find = 4;
  static const int merchant = 5;
}

/// 테스트용: 예약한 알림을 기억만 한다
class FakeNotifier implements Notifier {
  final Map<int, (DateTime, String, String)> scheduled = {};

  @override
  Future<void> schedule(int id, DateTime at, String title, String body) async {
    scheduled[id] = (at, title, body);
  }

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

/// 실제 휴대폰 알림 (flutter_local_notifications).
/// 처음 예약할 때 알림 권한을 묻는다.
class DeviceNotifier implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _asked = false;

  static const _channel = AndroidNotificationDetails(
    'arca_spirit',
    '정령 소식',
    channelDescription: '정령 원정이 돌아오거나 여관 휴식이 끝나면 알려 줘요.',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));
    _ready = true;
  }

  Future<void> _askOnce() async {
    if (_asked) return;
    _asked = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: false, sound: true);
  }

  @override
  Future<void> schedule(int id, DateTime at, String title, String body) async {
    try {
      await _init();
      await _askOnce();
      if (!at.isAfter(DateTime.now())) return;
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at.toUtc(), tz.UTC),
        const NotificationDetails(
          android: _channel,
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // 알림이 안 돼도 게임은 그대로
    }
  }

  @override
  Future<void> cancel(int id) async {
    try {
      await _init();
      await _plugin.cancel(id);
    } catch (_) {}
  }
}
