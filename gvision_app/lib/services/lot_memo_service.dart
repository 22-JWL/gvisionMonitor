import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LotMemo {
  final String comment;
  final DateTime managedAt; // 교대 기준 시간
  final DateTime savedAt;   // 실제 저장 시각

  const LotMemo({
    required this.comment,
    required this.managedAt,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
    'comment': comment,
    'managedAt': managedAt.toIso8601String(),
    'savedAt': savedAt.toIso8601String(),
  };

  factory LotMemo.fromJson(Map<String, dynamic> json) => LotMemo(
    comment: json['comment'] as String? ?? '',
    managedAt: DateTime.tryParse(json['managedAt'] as String? ?? '') ??
        DateTime.now(),
    savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

class LotMemoService {
  LotMemoService._();

  static String _key(int lotId) => 'lot_memo_$lotId';

  static Future<LotMemo?> load(int lotId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(lotId));
    if (raw == null) return null;
    try {
      return LotMemo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int lotId, LotMemo memo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(lotId), jsonEncode(memo.toJson()));
  }

  static Future<void> delete(int lotId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(lotId));
  }

  // 여러 Lot의 메모 존재 여부를 한 번에 확인
  static Future<Set<int>> loadExistingIds(List<int> lotIds) async {
    final prefs = await SharedPreferences.getInstance();
    return lotIds
        .where((id) => prefs.containsKey(_key(id)))
        .toSet();
  }
}
