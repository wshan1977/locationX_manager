import 'dart:convert';
import 'package:http/http.dart' as http;

class SimulatorApi {
  final String baseHost;
  final int basePort;

  SimulatorApi({this.baseHost = "127.0.0.1", this.basePort = 8081});

  Uri _u(String path, {Map<String, String>? q}) {
    return Uri.http("$baseHost:$basePort", path, q);
  }

  Future<Map<String, dynamic>> getStatus(String deviceId) async {
    final uri = _u("/api/v1/status", q: {"deviceId": deviceId});
    final r = await http.get(uri);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("GET /status failed: ${r.statusCode} ${r.body}");
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConfig(String deviceId) async {
    final uri = _u("/api/v1/config", q: {"deviceId": deviceId});
    final r = await http.get(uri);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("GET /config failed: ${r.statusCode} ${r.body}");
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setConfig(String deviceId, Map<String, dynamic> body) async {
    final uri = _u("/api/v1/config", q: {"deviceId": deviceId});
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

  Future<void> identify(String deviceId, {int durationSec = 8, String color = "cyan"}) async {
    final uri = _u("/api/v1/identify", q: {"deviceId": deviceId});
    final r = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"mode": "blink", "color": color, "durationSec": durationSec}),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("POST /identify failed: ${r.statusCode} ${r.body}");
    }
  }

  Future<void> setPosition({
    required String deviceId,
    required String floorId,
    required int anchorId,
    required double x,
    required double y,
    required double z,
    double yawDeg = 0.0,
    String floorplanId = "fp1",
  }) async {
    final uri = _u("/api/v1/install/position", q: {"deviceId": deviceId});
    final r = await http.put(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "floorId": floorId,
        "anchorId": anchorId,
        "pos": {"x": x, "y": y, "z": z},
        "yawDeg": yawDeg,
        "floorplanId": floorplanId,
      }),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("PUT /install/position failed: ${r.statusCode} ${r.body}");
    }
  }

  Future<void> resetAll() async {
    final uri = _u("/api/v1/admin/reset_all");
    final r = await http.post(uri);
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("POST /admin/reset_all failed: ${r.statusCode} ${r.body}");
    }
  }
}
