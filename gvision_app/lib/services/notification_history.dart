import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationRecord {
  final String title;
  final String body;
  final int logType;
  final int? eventId;
  final DateTime time;

  const NotificationRecord({
    required this.title,
    required this.body,
    required this.logType,
    this.eventId,
    required this.time,
  });

  String get logTypeLabel => switch (logType) {
    1 => '시스템',
    2 => '검사',
    4 => 'LOT',
    5 => 'Recipe',
    99 => '수율 경고',
    _ => '기타',
  };

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'logType': logType,
    'eventId': eventId,
    'time': time.toIso8601String(),
  };

  factory NotificationRecord.fromJson(Map<String, dynamic> json) =>
      NotificationRecord(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        logType: json['logType'] as int? ?? 0,
        eventId: json['eventId'] as int?,
        time: DateTime.tryParse(json['time'] as String? ?? '') ?? DateTime.now(),
      );
}

class NotificationHistory extends ChangeNotifier {
  static final instance = NotificationHistory._();
  NotificationHistory._();

  static const _key        = 'notif_history';
  static const _maxRecords = 50;

  final List<NotificationRecord> _records = [];
  List<NotificationRecord> get records => List.unmodifiable(_records);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _records.addAll(
        list.map((e) => NotificationRecord.fromJson(e as Map<String, dynamic>)),
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> add(NotificationRecord record) async {
    _records.insert(0, record);
    if (_records.length > _maxRecords) _records.removeLast();
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _records.clear();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_records.map((r) => r.toJson()).toList()),
    );
  }
}
