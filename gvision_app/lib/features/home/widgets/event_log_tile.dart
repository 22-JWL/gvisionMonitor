import 'package:flutter/material.dart';
import '../../../core/models/event.dart';
import '../../../shared/theme.dart';

class EventLogTile extends StatelessWidget {
  final GvisionEvent event;
  final VoidCallback? onTap;

  const EventLogTile({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.logTypeColor(event.logType);
    final time = _formatTime(event.time);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타입 컬러 바
            Container(width: 3, height: 36, color: color,
                margin: const EdgeInsets.only(right: 10)),
            // 타입 배지
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                event.logTypeLabel,
                style: TextStyle(fontSize: 10, color: color,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            // 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.description,
                    style: const TextStyle(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white38)),
                ],
              ),
            ),
            if (event.isAlert)
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: Color(0xFFE53935)),
          ],
        ),
      ),
    );
  }

  String _formatTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      final local = dt.toLocal();
      return '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')} '
          '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}:'
          '${local.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length > 16 ? raw.substring(0, 16) : raw;
    }
  }
}
