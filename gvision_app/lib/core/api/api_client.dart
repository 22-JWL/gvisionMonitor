import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // ===============================
  // 기존 로컬 서버 설정
  // ===============================
  static const _defaultHost = '192.168.0.35';
  static const _defaultPort = 4000;

  // ===============================
  // ngrok 서버 설정
  // ===============================
  // static const _defaultHost = 'disparate-difficult-kudos.ngrok-free.dev';
  // static const _defaultPort = 0; // ngrok는 포트 번호 사용 안 함

  static const _prefKeyHost = 'server_host';
  static const _prefKeyPort = 'server_port';

  static String _host = _defaultHost;
  static int _port = _defaultPort;

  // ===============================
  // 기존 baseUrl
  // ===============================
  static String get baseUrl => 'http://$_host:$_port';

  // ===============================
  // ngrok 대응 baseUrl
  // ===============================
  // static String get baseUrl {
  //   if (_host.contains('ngrok-free.dev')) {
  //     return 'https://$_host';
  //   }
  //   return 'http://$_host:$_port';
  // }
  //
  // static Map<String, String> get headers => {
  //   'ngrok-skip-browser-warning': '1',
  //   'Content-Type': 'application/json',
  // };

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString(_prefKeyHost) ?? _defaultHost;
    _port = prefs.getInt(_prefKeyPort) ?? _defaultPort;
  }

  static Future<void> saveSettings(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyHost, host);
    await prefs.setInt(_prefKeyPort, port);
    _host = host;
    _port = port;
  }

  static String get host => _host;
  static int get port => _port;

  static Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$baseUrl$path');

    final res = await http.get(uri).timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      return json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    }

    throw Exception('HTTP ${res.statusCode}: $path');
  }

  static Future<List<dynamic>> getList(String path) async {
    final uri = Uri.parse('$baseUrl$path');

    // 기존 요청
    final res = await http.get(uri).timeout(const Duration(seconds: 5));

    // ngrok 대응 요청
    // final res = await http
    //     .get(uri, headers: headers)
    //     .timeout(const Duration(seconds: 5));

    if (res.statusCode == 200) {
      return json.decode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    }

    throw Exception('HTTP ${res.statusCode}: $path');
  }
}