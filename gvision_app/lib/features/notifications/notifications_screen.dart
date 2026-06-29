import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notification_history.dart';
import '../../shared/widgets/ws_indicator.dart';
import '../../core/ws/ws_client.dart';
import '../events/event_context_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _typeColors = {
    1:  Color(0xFF42A5F5), // 시스템
    2:  Color(0xFF66BB6A), // 검사
    4:  Color(0xFFFFCA28), // LOT
    5:  Color(0xFFAB47BC), // Recipe
    99: Color(0xFFEF5350), // 수율 경고
  };

  @override
  Widget build(BuildContext context) {
    final history = context.watch<NotificationHistory>();
    final records = history.records;

    return Scaffold(
      appBar: AppBar(
        title: const Text('알림 이력'),
        actions: [
          const WsIndicator(),
          if (records.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: const Text('전체 삭제'),
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
              onPressed: () => _confirmClear(context, history),
            ),
        ],
      ),
      body: records.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 48, color: Colors.white24),
                  SizedBox(height: 12),
                  Text('수신한 알림이 없습니다.',
                      style: TextStyle(color: Colors.white38)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (ctx, i) => _NotifTile(record: records[i]),
            ),
    );
  }

  void _confirmClear(BuildContext context, NotificationHistory history) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('알림 이력 삭제'),
        content: const Text('모든 알림 이력을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              history.clear();
              Navigator.pop(context);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationRecord record;
  const _NotifTile({required this.record});

  static const _typeColors = {
    1:  Color(0xFF42A5F5),
    2:  Color(0xFF66BB6A),
    4:  Color(0xFFFFCA28),
    5:  Color(0xFFAB47BC),
    99: Color(0xFFEF5350),
  };

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[record.logType] ?? Colors.white38;
    final isYieldAlert = record.logType == 99;
    final canNavigate = record.eventId != null;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canNavigate
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EventContextScreen(eventId: record.eventId!),
                  ),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이콘
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isYieldAlert
                      ? Icons.trending_down
                      : _iconFor(record.logType),
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            record.logTypeLabel,
                            style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(record.time),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white38),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      record.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      record.body,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canNavigate) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right,
                    size: 18, color: Colors.white38),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(int logType) => switch (logType) {
    1  => Icons.settings_applications,
    2  => Icons.analytics,
    4  => Icons.history,
    5  => Icons.tune,
    99 => Icons.trending_down,
    _  => Icons.notifications,
  };

  String _formatTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')} '
        '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }
}
