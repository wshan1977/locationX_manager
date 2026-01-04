import 'dart:convert';
import 'package:http/http.dart' as http;

class LocatorApi {
  Future<void> identify({
    required String ip,
    int port = 8080,
    required String deviceId,
    int durationSec = 8,
    String color = "cyan",
  }) async {
    final uri = Uri.parse("http://$ip:$port/api/v1/identify?deviceId=$deviceId");
    final r = await http.post(uri, headers: {"Content-Type": "application/json"}, body: jsonEncode({
      "mode": "blink",
      "color": color,
      "durationSec": durationSec,
    }));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("identify failed: ${r.statusCode} ${r.body}");
    }
  }

  Future<void> setPosition({
    required String ip,
    int port = 8080,
    required String deviceId,
    required String floorId,
    required int anchorId,
    required double x,
    required double y,
    required double z,
    double yawDeg = 0.0,
    String floorplanId = "fp1",
  }) async {
    final uri = Uri.parse("http://$ip:$port/api/v1/install/position?deviceId=$deviceId");
    final r = await http.put(uri, headers: {"Content-Type": "application/json"}, body: jsonEncode({
      "floorId": floorId,
      "anchorId": anchorId,
      "pos": {"x": x, "y": y, "z": z},
      "yawDeg": yawDeg,
      "floorplanId": floorplanId,
    }));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception("setPosition failed: ${r.statusCode} ${r.body}");
    }
  }
}
