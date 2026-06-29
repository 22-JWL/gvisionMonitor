import 'api_client.dart';

class InspectionsApi {
  /// KST 문자열
  static String _kstStr(DateTime dt) {
    final kst = dt.toLocal();
    return '${kst.year.toString().padLeft(4, '0')}-'
        '${kst.month.toString().padLeft(2, '0')}-'
        '${kst.day.toString().padLeft(2, '0')} '
        '${kst.hour.toString().padLeft(2, '0')}:'
        '${kst.minute.toString().padLeft(2, '0')}:'
        '${kst.second.toString().padLeft(2, '0')}';
  }

  /// 기본: 오늘
  static (String, String) _todayRange() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return (_kstStr(todayStart), _kstStr(now));
  }

  /// 🔥 수정: optional from/to 추가
  static Future<List<Map<String, dynamic>>> fetchYieldSeries({
    DateTime? from,
    DateTime? to,
  }) async {
    final range = (from != null && to != null)
        ? (_kstStr(from), _kstStr(to))
        : _todayRange();

    final data = await ApiClient.get(
        '/api/inspections/yield?from=${Uri.encodeComponent(range.$1)}&to=${Uri.encodeComponent(range.$2)}');

    final list = data['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  /// 🔥 수정: optional from/to 추가
  static Future<List<dynamic>> fetchSeries({
    DateTime? from,
    DateTime? to,
  }) async {
    final range = (from != null && to != null)
        ? (_kstStr(from), _kstStr(to))
        : _todayRange();

    final data = await ApiClient.get(
        '/api/inspections/series?from=${Uri.encodeComponent(range.$1)}&to=${Uri.encodeComponent(range.$2)}');

    return data['data'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> fetchErrors({required int lotId}) async {
    final data =
        await ApiClient.get('/api/inspections/errors?lotId=$lotId');
    return data['data'] as List<dynamic>? ?? [];
  }

  static Future<List<Map<String, dynamic>>> fetchDurationSeries({
    DateTime? from,
    DateTime? to,
  }) async {
    final range = (from != null && to != null)
        ? (_kstStr(from), _kstStr(to))
        : _todayRange();

    final data = await ApiClient.get(
        '/api/inspections/duration?from=${Uri.encodeComponent(range.$1)}&to=${Uri.encodeComponent(range.$2)}');
    final list = data['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  static Future<List<Map<String, dynamic>>> fetchHeatmap(int lotId) async {
    final data =
        await ApiClient.get('/api/inspections/heatmap?lotId=$lotId');
    final list = data['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }
}