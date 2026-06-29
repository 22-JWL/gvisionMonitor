import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/api/events_api.dart';
import '../../core/models/event.dart';
import '../../core/ws/ws_client.dart';

class EventsProvider extends ChangeNotifier {
  final WsClient _ws;

  final List<GvisionEvent> _events = [];
  bool loading = true;
  String? errorMessage;
  int? _activeLogType; // null = 전체

  StreamSubscription<WsMessage>? _sub;

  EventsProvider(this._ws) {
    _init();
  }

  List<GvisionEvent> get events => List.unmodifiable(_events);
  int? get activeLogType => _activeLogType;

  Future<void> _init() async {
    await _fetch();

    _sub = _ws.stream.listen((msg) {
      if (msg.type == WsMessageType.newEvent ||
          msg.type == WsMessageType.alert) {
        final event = GvisionEvent.fromJson(msg.data);
        // 현재 필터와 맞으면 맨 앞에 삽입
        if (_activeLogType == null || event.logType == _activeLogType) {
          _events.insert(0, event);
          if (_events.length > 200) _events.removeLast();
          notifyListeners();
        }
      }
    });
  }

  Future<void> _fetch({int? logType}) async {
    loading = true;
    notifyListeners();
    try {
      final List<GvisionEvent> events;

      if (logType != null) {
        // 특정 탭: 해당 타입만 조회
        events = await EventsApi.fetchRecent(limit: 100, logType: logType);
      } else {
        // 전체 탭: 타입별로 따로 불러와서 합침
        final results = await Future.wait([
          EventsApi.fetchRecent(limit: 50, logType: 2), // 검사
          EventsApi.fetchRecent(limit: 30, logType: 1), // 시스템
          EventsApi.fetchRecent(limit: 20, logType: 4), // LOT
          EventsApi.fetchRecent(limit: 20, logType: 5), // Recipe
        ]);
        events = results.expand((e) => e).toList()
          ..sort((a, b) => b.time.compareTo(a.time));
      }

      _events
        ..clear()
        ..addAll(events);
      errorMessage = null;
    } catch (_) {
      errorMessage = '이벤트를 불러오지 못했습니다. 서버 연결을 확인하세요.';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> filterBy(int? logType) async {
    _activeLogType = logType;
    await _fetch(logType: logType);
  }

  Future<void> refresh() => _fetch(logType: _activeLogType);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
