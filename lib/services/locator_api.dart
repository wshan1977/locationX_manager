import 'dart:convert';
import 'package:http/http.dart' as http;

class LocatorApi {
  Uri _u(String ip, int port, String path, {Map<String, String>? q}) {
    return Uri.http("$ip:$port", path, q);
  }

  Future<Map<String, dynamic>> getStatus({
    required String ip,
    int port = 8080,
    required String deviceId,
  }) async {
    final uri = _u(ip, port, "/api/v1/status", q: {"deviceId": deviceId});
    final r = await http.get(uri);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("GET /status failed: ${r.statusCode} ${r.body}");
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConfig({
    required String ip,
    int port = 8080,
    required String deviceId,
  }) async {
    final uri = _u(ip, port, "/api/v1/config", q: {"deviceId": deviceId});
    final r = await http.get(uri);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("GET /config failed: ${r.statusCode} ${r.body}");
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setConfig({
    required String ip,
    int port = 8080,
    required String deviceId,
    required Map<String, dynamic> body,
  }) async {
    final uri = _u(ip, port, "/api/v1/config", q: {"deviceId": deviceId});
    final r = await http.put(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("PUT /config failed: ${r.statusCode} ${r.body}");
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
