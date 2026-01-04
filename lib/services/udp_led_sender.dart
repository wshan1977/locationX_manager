import 'dart:convert';
import 'dart:io';

class UdpLedSender {
  const UdpLedSender();

  Future<void> send({
    required String ip,
    int port = 40002,
    required Map<String, dynamic> payload,
  }) async {
    final data = utf8.encode(jsonEncode(payload));
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );

    socket.send(data, InternetAddress(ip), port);
    socket.close();
  }

  /// LED 점멸
  Future<void> blink({
    required String ip,
    int port = 40002,
    String color = 'magenta',
    double hz = 3.0,
    int durationSec = 8,
  }) {
    return send(
      ip: ip,
      port: port,
      payload: {
        'type': 'LED_BLINK',
        'color': color,
        'hz': hz,
        'durationSec': durationSec,
      },
    );
  }

  /// LED 고정 ON
  Future<void> setOn({
    required String ip,
    int port = 40002,
    String color = 'blue',
  }) {
    return send(
      ip: ip,
      port: port,
      payload: {
        'type': 'LED_SET',
        'color': color,
        'on': true,
      },
    );
  }

  /// LED OFF
  Future<void> off({
    required String ip,
    int port = 40002,
  }) {
    return send(
      ip: ip,
      port: port,
      payload: {
        'type': 'LED_OFF',
      },
    );
  }
}
