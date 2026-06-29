import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_history.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static int _id = 0;

  static void Function(int eventId)? onAlertTapped;

  // 채널 — critical: 수율 경고·장비 오류, normal: LOT·Recipe 이벤트
  static const _criticalChannel = AndroidNotificationChannel(
    'gvision_critical',
    'GVision 긴급 알림',
    description: '수율 급락, 장비 오류 등 즉각 대응이 필요한 알림',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const _normalChannel = AndroidNotificationChannel(
    'gvision_normal',
    'GVision 일반 알림',
    description: 'LOT, Recipe 이벤트 등 일반 알림',
    importance: Importance.defaultImportance,
    playSound: false,
  );

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null) {
          final eventId = int.tryParse(payload);
          if (eventId != null) onAlertTapped?.call(eventId);
        }
      },
    );

    // 채널 등록 (Android 8+)
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_criticalChannel);
    await androidPlugin?.createNotificationChannel(_normalChannel);
  }

  // 이벤트 알림 (logType에 따라 채널 자동 선택)
  static Future<void> showAlert({
    required String title,
    required String body,
    required int logType,
    int? eventId,
  }) async {
    final isCritical = logType == 1; // 시스템 이벤트 → critical
    await _show(
      title: title,
      body: body,
      channelId: isCritical ? _criticalChannel.id : _normalChannel.id,
      eventId: eventId,
      logType: logType,
    );
  }

  // 수율 임계값 경고 — 항상 critical 채널
  static Future<void> showYieldAlert({
    required double yieldRate,
    required double threshold,
  }) async {
    final title = '수율 경고';
    final body =
        '현재 수율 ${yieldRate.toStringAsFixed(1)}%이 기준치 ${threshold.toStringAsFixed(0)}% 미만으로 떨어졌습니다.';

    await _show(
      title: title,
      body: body,
      channelId: _criticalChannel.id,
      logType: 99, // 수율 경고 전용 타입
    );
  }

  static Future<void> _show({
    required String title,
    required String body,
    required String channelId,
    required int logType,
    int? eventId,
  }) async {
    // 알림 이력에 저장 (플랫폼 무관)
    await NotificationHistory.instance.add(NotificationRecord(
      title: title,
      body: body,
      logType: logType,
      eventId: eventId,
      time: DateTime.now(),
    ));

    // Android가 아닌 플랫폼은 콘솔 출력으로 대체
    if (!defaultTargetPlatform.isAndroid) {
      debugPrint('[Notification] $title: $body');
    } else {
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == _criticalChannel.id
              ? _criticalChannel.name
              : _normalChannel.name,
          importance: channelId == _criticalChannel.id
              ? Importance.max
              : Importance.defaultImportance,
          priority: channelId == _criticalChannel.id
              ? Priority.high
              : Priority.defaultPriority,
        ),
      );
      await _plugin.show(
        _id++,
        title,
        body,
        details,
        payload: eventId?.toString(),
      );
    }

  }
}

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
