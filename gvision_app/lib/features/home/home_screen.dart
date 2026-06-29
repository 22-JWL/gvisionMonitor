import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../inspection/inspection_provider.dart';
import '../../core/ws/ws_client.dart';
import 'home_provider.dart';
import 'widgets/status_banner.dart';
import 'widgets/event_log_tile.dart';
import 'widgets/yield_gauge_card.dart';
import '../events/event_context_screen.dart';
import '../../shared/widgets/dashboard_card.dart';
import '../../shared/widgets/ws_indicator.dart';
import '../../core/models/event.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HomeProvider>();
    final ws = context.watch<WsClient>();
    final p = context.watch<InspectionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('GVision Monitor'),
        actions: [
          const WsIndicator(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: provider.refresh,
          ),
        ],
      ),
      body: provider.loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    '데이터 조회 중...',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            )
          : Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (ws.state == WsState.disconnected)
              _connectionWarning(context),
            if (provider.gvisionOffline)
              _machineOfflineBanner(context),
            if (provider.errorMessage != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade900,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, size: 16, color: Colors.white70),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        provider.errorMessage!,
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ),
                    TextButton(
                      onPressed: provider.refresh,
                      child: const Text(
                        '재시도',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: StatusBanner(status: provider.status),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: YieldGaugeCard(
                    yieldRate: p.yieldRate,
                    total: p.total,
                    good: p.good,
                    reject: p.reject,
                    noDevice: p.noDevice,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _homeContextPanel(p, ws),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: _eventPanel(context, provider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectionWarning(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.red.shade900,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.wifi_off, size: 16, color: Colors.white70),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '서버 연결 안 됨 — 설정에서 IP를 확인하세요',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      );

  Widget _machineOfflineBanner(BuildContext context) => Container(
        width: double.infinity,
        color: const Color(0xFF6D1E00),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: const Row(
          children: [
            Icon(Icons.power_off, size: 20, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '장비 오프라인',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'GVision 장비와의 연결이 끊겼습니다. 장비 전원 및 네트워크 상태를 확인하세요.',
                    style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _homeContextPanel(InspectionProvider p, WsClient ws) {
    final yieldColor = p.yieldRate >= 99
        ? const Color(0xFF43A047)
        : p.yieldRate >= 95
        ? Colors.orange
        : const Color(0xFFE53935);

    final statusText = ws.state == WsState.connected
        ? '실시간 연결 정상'
        : ws.state == WsState.connecting
        ? '서버 연결 중'
        : '서버 연결 끊김';

    final message = p.yieldRate >= 99
        ? '현재 검사 수율이 안정적입니다.'
        : p.yieldRate >= 95
        ? '수율이 주의 구간입니다. 최근 이벤트와 검사 타입별 NG율을 확인하세요.'
        : '수율이 위험 구간입니다. Inspection 분석에서 이상 Shot 주변 컨텍스트를 확인하세요.';

    return DashboardCard(
      title: '현장 요약',
      description: '현재 장비 연결 상태와 검사 품질 상태를 요약합니다.',
      icon: Icons.dashboard_customize,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _contextRow('서버 상태', statusText, Colors.white70),
          _contextRow('현재 수율', '${p.yieldRate.toStringAsFixed(1)}%', yieldColor),
          _contextRow('총 검사', '${p.total}', Colors.white70),
          _contextRow('REJECT', '${p.reject}', const Color(0xFFE53935)),
          _contextRow('NO DEVICE', '${p.noDevice}', Colors.grey),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: yieldColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: yieldColor.withOpacity(0.35)),
            ),
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: yieldColor, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventPanel(BuildContext context, HomeProvider provider) {
    final groupedItems = <dynamic>[];

    List<GvisionEvent> currentInspectionGroup = [];

    for (final e in provider.recentEvents) {
      if (e.logType == 2) {
        currentInspectionGroup.add(e);
        continue;
      }

      // 검사 이벤트 묶음 flush
      if (currentInspectionGroup.isNotEmpty) {
        groupedItems.add(List.of(currentInspectionGroup));
        currentInspectionGroup.clear();
      }

      groupedItems.add(e);
    }

    // 마지막 검사 묶음 flush
    if (currentInspectionGroup.isNotEmpty) {
      groupedItems.add(List.of(currentInspectionGroup));
    }

    final visibleItems = groupedItems.take(15).toList();

    final hasEvents = visibleItems.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(Icons.list_alt, size: 18, color: Color(0xFF90CAF9)),
                SizedBox(width: 8),
                Text(
                  '최근 이벤트 로그',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
    '최근 이벤트를 시간순으로 표시하고, 연속된 검사 이벤트는 하나의 묶음으로 접어서 보여줍니다.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),

          Expanded(
            child: !hasEvents
                ? const Center(
              child: Text(
                '이벤트 없음',
                style: TextStyle(color: Colors.white38),
              ),
            )
                : ListView(
              children: visibleItems.map((item) {
                // 검사 이벤트 그룹
                if (item is List<GvisionEvent>) {
                  return ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16),
                    childrenPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.analytics_outlined,
                      size: 18,
                      color: Color(0xFF42A5F5),
                    ),
                    title: Text(
                      '검사 이벤트 ${item.length}건',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      item.first.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white54,
                      ),
                    ),
                    children: item.map((e) {
                      return EventLogTile(
                        event: e,
                        onTap: e.isAlert
                            ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EventContextScreen(eventId: e.id),
                          ),
                        )
                            : null,
                      );
                    }).toList(),
                  );
                }

                // 일반 이벤트
                final e = item as GvisionEvent;

                return EventLogTile(
                  event: e,
                  onTap: e.isAlert
                      ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          EventContextScreen(eventId: e.id),
                    ),
                  )
                      : null,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

