import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/api_client.dart';

enum WsMessageType { status, newEvent, alert, gvisionOffline, unknown }

enum WsState { connecting, connected, disconnected }

class WsMessage {
  final WsMessageType type;
  final Map<String, dynamic> data;

  const WsMessage({required this.type, required this.data});

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    final t = json['type'] as String? ?? '';
    final type = switch (t) {
      'STATUS' => WsMessageType.status,
      'NEW_EVENT' => WsMessageType.newEvent,
      'ALERT' => WsMessageType.alert,
      'GVISION_OFFLINE' => WsMessageType.gvisionOffline,
      _ => WsMessageType.unknown,
    };
    return WsMessage(
      type: type,
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}

class WsClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _disposed = false;

  WsState _state = WsState.disconnected;
  WsState get state => _state;

  final _controller = StreamController<WsMessage>.broadcast();
  Stream<WsMessage> get stream => _controller.stream;

  void connect() {
    _disposed = false;
    _tryConnect();
  }

  void _tryConnect() {
    if (_disposed) return;
    _setState(WsState.connecting);

    try {
      // 기존 로컬 WebSocket 주소
      final uri = Uri.parse('ws://${ApiClient.host}:${ApiClient.port}/ws');

      // ngrok WebSocket 주소
      // final uri = Uri.parse('wss://disparate-difficult-kudos.ngrok-free.dev/ws');

      debugPrint('[WS] 연결 시도: $uri');
      _channel = WebSocketChannel.connect(uri);

      // ready 완료 후 connected 상태로 전환
      _channel!.ready.then((_) {
        debugPrint('[WS] 연결 성공');
        _setState(WsState.connected);
      }).catchError((e) {
        debugPrint('[WS] 연결 실패: $e');
        _scheduleReconnect();
      });

      _channel!.stream.listen(
        (raw) {
          try {
            final json = jsonDecode(raw as String) as Map<String, dynamic>;
            _controller.add(WsMessage.fromJson(json));
          } catch (_) {}
        },
        onDone: () {
          debugPrint('[WS] 연결 종료');
          _scheduleReconnect();
        },
        onError: (e) {
          debugPrint('[WS] 에러: $e');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[WS] 예외: $e');
      _scheduleReconnect();
    }
  }

  void _setState(WsState s) {
    _state = s;
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _setState(WsState.disconnected);
    _reconnectTimer?.cancel();
    debugPrint('[WS] 5초 후 재연결...');
    _reconnectTimer = Timer(const Duration(seconds: 5), _tryConnect);
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller.close();
    super.dispose();
  }
}
