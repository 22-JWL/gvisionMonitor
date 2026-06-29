import '../models/lot.dart';
import 'api_client.dart';

class LotsApi {
  static Future<List<Lot>> fetchLots({int limit = 20}) async {
    final data = await ApiClient.get('/api/lots?limit=$limit');
    final list = data['lots'] as List<dynamic>? ?? [];
    return list.map((e) => Lot.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<LotStats> fetchStats(int lotId) async {
    final data = await ApiClient.get('/api/lots/$lotId/stats');
    return LotStats.fromJson(data);
  }
}
