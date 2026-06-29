import '../models/event.dart';
import 'api_client.dart';

class EventsApi {
  static Future<List<GvisionEvent>> fetchRecent({
    int limit = 50,
    int? logType,
  }) async {
    final q = logType != null ? '?limit=$limit&logType=$logType' : '?limit=$limit';
    final data = await ApiClient.get('/api/events$q');
    final list = data['events'] as List<dynamic>? ?? [];
    return list.map((e) => GvisionEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> fetchContext(int id,
      {int before = 5, int after = 5}) async {
    return ApiClient.get('/api/events/$id/context?before=$before&after=$after');
  }
}
