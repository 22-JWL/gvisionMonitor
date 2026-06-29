import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/models/device_status.dart';
import '../../core/models/event.dart';
import '../../core/api/events_api.dart';
import '../../core/ws/ws_client.dart';
import '../../services/notification_service.dart';
import '../../services/notification_settings.dart';

class HomeProvider extends ChangeNotifier {
  final WsClient _ws;

  DeviceStatus _status = DeviceStatus.offline();
  final List<GvisionEvent> _recentEvents = [];
  bool _loading = true;
  StreamSubscription<WsMessage>? _sub;

  DeviceStatus get status => _status;
  List<GvisionEvent> get recentEvents => List.unmodifiable(_recentEvents);
  bool get loading => _loading;
  String? errorMessage;
  bool gvisionOffline = false;

  HomeProvider(this._ws) {
    _init();
  }

  Future<void> _init() async {
    await _loadEvents();
    _sub = _ws.stream.listen(_onMessage);
    _loading = false;
    notifyListeners();
  }

  Future<void> _loadEvents() async {
    try {
      // 타입별로 따로 불러와서 합침 (검사 이벤트가 최근을 전부 차지하는 문제 방지)
      final results = await Future.wait([
        EventsApi.fetchRecent(limit: 30, logType: 2), // 검사
        EventsApi.fetchRecent(limit: 10, logType: 1), // 시스템
        EventsApi.fetchRecent(limit: 10, logType: 4), // LOT
        EventsApi.fetchRecent(limit: 10, logType: 5), // Recipe
      ]);

      final combined = results.expand((e) => e).toList()
        ..sort((a, b) => b.time.compareTo(a.time));

      _recentEvents
        ..clear()
        ..addAll(combined);
      errorMessage = null;
    } catch (_) {
      errorMessage = '이벤트 데이터를 불러오지 못했습니다. 서버 연결을 확인하세요.';
    }
  }

  void _onMessage(WsMessage msg) {
    switch (msg.type) {
      case WsMessageType.status:
        _status = DeviceStatus.fromJson(msg.data);
        // GVISION_OFFLINE 명시 메시지가 온 뒤에만 true가 되고,
        // 여기서는 정상 모드 확인 시에만 해제한다.
        if (!_status.isOffline) gvisionOffline = false;
        notifyListeners();

      case WsMessageType.gvisionOffline:
        _status = DeviceStatus.offline();
        gvisionOffline = true;
        notifyListeners();

      case WsMessageType.alert:
      case WsMessageType.newEvent:
        final event = GvisionEvent.fromJson(msg.data);
        _recentEvents.insert(0, event);
        if (_recentEvents.length > 100) _recentEvents.removeLast();
        notifyListeners();

        // 알림 설정에 따라 조건부 발송
        if (NotificationSettings.shouldNotify(event.logType)) {
          NotificationService.showAlert(
            title: '[${event.logTypeLabel}] 이벤트 발생',
            body: event.description,
            logType: event.logType,
            eventId: event.id,
          );
        }

      case WsMessageType.unknown:
        break;
    }
  }

  Future<void> refresh() async {
    await _loadEvents();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
