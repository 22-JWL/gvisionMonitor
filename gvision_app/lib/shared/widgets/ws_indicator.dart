import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/ws/ws_client.dart';

class WsIndicator extends StatelessWidget {
  const WsIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WsClient>().state;
    final (icon, color, tooltip) = switch (state) {
      WsState.connected    => (Icons.wifi,      Colors.greenAccent, '실시간 연결됨'),
      WsState.connecting   => (Icons.wifi_find, Colors.orange,      '연결 중...'),
      WsState.disconnected => (Icons.wifi_off,  Colors.red,         '연결 끊김'),
    };
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
