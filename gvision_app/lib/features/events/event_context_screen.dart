import 'package:flutter/material.dart';
import '../../core/api/events_api.dart';
import '../../core/models/event.dart';
import '../../shared/theme.dart';

class EventContextScreen extends StatefulWidget {
  final int eventId;
  const EventContextScreen({super.key, required this.eventId});

  @override
  State<EventContextScreen> createState() => _EventContextScreenState();
}

class _EventContextScreenState extends State<EventContextScreen> {
  Map<String, dynamic>? _context;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await EventsApi.fetchContext(widget.eventId);
      setState(() {
        _context = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이벤트 맥락')),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('데이터 조회 중...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 40, color: Colors.white24),
                      SizedBox(height: 12),
                      Text('데이터를 불러오지 못했습니다.', style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final data = _context!;
    final target = data['target'] as Map<String, dynamic>?;
    final contextList = data['context'] as List<dynamic>? ?? [];

    if (target == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 40, color: Colors.white24),
            SizedBox(height: 12),
            Text('이벤트 정보를 찾을 수 없습니다.', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    // 기준 이벤트 제외한 주변 이벤트
    final targetId = target['Id'] as int?;
    final surroundingEvents = contextList
        .map((e) => GvisionEvent.fromJson(e as Map<String, dynamic>))
        .where((e) => e.id != targetId)
        .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildTargetCard(GvisionEvent.fromJson(target)),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '전후 이벤트 맥락 (±5분)',
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        if (surroundingEvents.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_busy, size: 36, color: Colors.white24),
                  SizedBox(height: 10),
                  Text(
                    '전후 5분 이내 다른 이벤트가 없습니다.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          ...surroundingEvents.map((e) => _buildContextTile(e, false)),
      ],
    );
  }

  Widget _buildTargetCard(GvisionEvent event) {
    final color = AppTheme.logTypeColor(event.logType);
    return Card(
      color: color.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 20),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(event.logTypeLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(_formatTime(event.time),
                    style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              event.description,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            if (event.camera != null) ...[
              const SizedBox(height: 6),
              Text('Camera: ${event.camera}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContextTile(GvisionEvent event, bool isTarget) {
    final color = AppTheme.logTypeColor(event.logType);
    return Container(
      decoration: isTarget
          ? BoxDecoration(color: color.withValues(alpha: 0.08))
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 2, height: 32, color: color,
                margin: const EdgeInsets.only(right: 10, top: 2)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(event.logTypeLabel,
                          style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text(_formatTime(event.time),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(event.description,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
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
          '${dt.minute.toString().padLeft(2, '0')}:'
          '${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }
}
