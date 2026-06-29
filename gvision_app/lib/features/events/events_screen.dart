import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/event.dart';
import '../../shared/theme.dart';
import 'events_provider.dart';
import 'event_context_screen.dart';
import '../../shared/widgets/dashboard_card.dart';
import '../../shared/widgets/ws_indicator.dart';
import '../../core/ws/ws_client.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _filters = [null, 1, 2, 4, 5];
  final _labels = ['전체', '시스템', '검사', 'LOT', 'Recipe'];

  GvisionEvent? _selectedEvent;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _filters.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EventsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('이벤트 분석'),
        actions: [
          const WsIndicator(),
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: provider.refresh),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: _labels.map((l) => Tab(text: l)).toList(),
          onTap: (i) {
            setState(() => _selectedEvent = null);
            provider.filterBy(_filters[i]);
          },
        ),
      ),
      body: Column(
        children: [
          if (provider.errorMessage != null)
            Material(
              color: Colors.red.shade900,
              child: Padding(
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
            ),
          Expanded(
            child: provider.loading
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
                : provider.events.isEmpty
                ? const Center(
                    child: Text(
                      '이벤트 없음',
                      style: TextStyle(color: Colors.white38),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _eventListPanel(provider),
                      ),
                      Container(width: 1, color: Colors.white12),
                      Expanded(
                        flex: 4,
                        child: _eventDetailPanel(context),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _eventListPanel(EventsProvider provider) {
    final isAllTab = provider.activeLogType == null;
    final listItems = isAllTab ? _buildGroupedItems(provider.events) : null;

    return Card(
      margin: const EdgeInsets.all(12),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(Icons.notifications, size: 18, color: Color(0xFF90CAF9)),
                SizedBox(width: 8),
                Text(
                  '이벤트 목록',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '장비, 검사, LOT, Recipe 이벤트를 시간순으로 확인합니다.',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          Expanded(
            child: isAllTab
                ? ListView.separated(
                    itemCount: listItems!.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final item = listItems[i];
                      if (item is List<GvisionEvent>) {
                        return _buildInspectionGroup(ctx, item);
                      }
                      return _buildTile(ctx, item as GvisionEvent);
                    },
                  )
                : ListView.separated(
                    itemCount: provider.events.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) => _buildTile(ctx, provider.events[i]),
                  ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _buildGroupedItems(List<GvisionEvent> events) {
    final grouped = <dynamic>[];
    List<GvisionEvent> currentGroup = [];

    for (final e in events) {
      if (e.logType == 2) {
        currentGroup.add(e);
        continue;
      }
      if (currentGroup.isNotEmpty) {
        grouped.add(List<GvisionEvent>.of(currentGroup));
        currentGroup.clear();
      }
      grouped.add(e);
    }
    if (currentGroup.isNotEmpty) {
      grouped.add(List<GvisionEvent>.of(currentGroup));
    }
    return grouped;
  }

  Widget _buildInspectionGroup(BuildContext ctx, List<GvisionEvent> group) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: EdgeInsets.zero,
      leading: const Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF42A5F5)),
      title: Text(
        '검사 이벤트 ${group.length}건',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        _formatTime(group.first.time),
        style: const TextStyle(fontSize: 11, color: Colors.white54),
      ),
      children: [
        const Divider(height: 1),
        ...group.map((e) => _buildTile(ctx, e)),
      ],
    );
  }

  Widget _buildTile(BuildContext ctx, GvisionEvent event) {
    final color = AppTheme.logTypeColor(event.logType);
    final selected = _selectedEvent?.id == event.id;

    return InkWell(
      onTap: () {
        setState(() => _selectedEvent = event);
      },
      child: Container(
        color: selected ? color.withOpacity(0.12) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 44,
              color: color,
              margin: const EdgeInsets.only(right: 10),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event.logTypeLabel,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatTime(event.time),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.chevron_right,
              size: 18,
              color: selected ? color : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length > 13 ? raw.substring(0, 13) : raw;
    }
  }
  Widget _eventDetailPanel(BuildContext context) {
    final event = _selectedEvent;

    if (event == null) {
      return const Card(
        margin: EdgeInsets.all(12),
        child: Center(
          child: Text(
            '이벤트를 선택하면 상세 컨텍스트가 표시됩니다.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final color = AppTheme.logTypeColor(event.logType);

    return DashboardCard(
      title: '이벤트 상세 컨텍스트',
      description: '선택한 이벤트의 의미와 현장 확인 포인트를 제공합니다.',
      icon: Icons.manage_search,
      margin: const EdgeInsets.all(12),
      child: Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            event.logTypeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(event.time),
                          style: const TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      event.description,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _contextBox(
                      title: '현장 확인 포인트',
                      body: _eventGuide(event),
                      color: color,
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (event.isAlert)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('상세 컨텍스트 열기'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventContextScreen(eventId: event.id),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contextBox({
    required String title,
    required String body,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  String _eventGuide(GvisionEvent event) {
    switch (event.logType) {
      case 2:
        return '검사 이벤트입니다. Inspection 분석 탭에서 같은 시간대의 수율, REJECT 분포, 검사 타입별 NG율을 함께 확인하세요.';
      case 4:
        return 'LOT 관련 이벤트입니다. Lot 이력에서 해당 Lot의 수율과 불량 분포를 확인하세요.';
      case 5:
        return 'Recipe 관련 이벤트입니다. Recipe 변경 직후 수율이나 NG율 변화가 있었는지 확인하세요.';
      case 1:
        return '시스템 이벤트입니다. 서버 연결 상태, 장비 상태, 최근 이벤트 연속 발생 여부를 확인하세요.';
      default:
        return '이벤트 발생 시점 전후의 검사 결과와 장비 상태를 함께 확인하세요.';
    }
  }
}
