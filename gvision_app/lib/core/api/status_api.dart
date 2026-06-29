import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device_status.dart';
import 'api_client.dart';

class StatusApi {
  static Future<DeviceStatus> fetchStatus() async {
    try {
      // 장비 모드, recipe, lot을 병렬 요청
      final results = await Future.wait([
        http.get(Uri.parse('${ApiClient.baseUrl}/api/status/mode'))
            .timeout(const Duration(seconds: 5)),
        http.get(Uri.parse('${ApiClient.baseUrl}/api/status/recipe'))
            .timeout(const Duration(seconds: 5)),
        http.get(Uri.parse('${ApiClient.baseUrl}/api/status/lot'))
            .timeout(const Duration(seconds: 5)),
      ]);

      String csv(http.Response r) {
        final lines = utf8.decode(r.bodyBytes).trim().split('\n');
        return lines.length > 1 ? lines[1].trim() : '';
      }

      final modeCode = int.tryParse(csv(results[0])) ?? 0;
      final recipe = csv(results[1]);
      final lot = csv(results[2]);

      final modeStr = modeCode == 1
          ? 'Run'
          : modeCode == 2
              ? 'SetUp'
              : 'OFFLINE';

      return DeviceStatus(
        runningMode: modeStr,
        recipeName: recipe,
        lotNo: lot,
      );
    } catch (_) {
      return DeviceStatus.offline();
    }
  }
}
