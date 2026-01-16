import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Pi의 locationx_discover_agent.py(UDP :40010)가 처리하는 설정 프로토콜
///
/// - MQTT 설정
///   - 요청: {"type":"MQTT_SET","broker_host":"...","broker_port":1883}
///   - 응답: {"type":"MQTT_SET_RESPONSE","ok":true/false, ... }
///
/// - Reboot
///   - 요청: {"type":"REBOOT","delay_sec":2,"reason":"ui"}
///   - 응답: {"type":"REBOOT_RESPONSE","ok":true/false, ... }
///
/// - AOA 서비스 재시작
///   - 요청: {"type":"SERVICE_RESTART","service":"aoa-antenna.service"}
///   - 응답: {"type":"SERVICE_RESTART_RESPONSE","ok":true/false, ... }
class UdpMqttConfigService {
  final int port;
  final Duration timeout;

  const UdpMqttConfigService({
    this.port = 40010,
    this.timeout = const Duration(seconds: 2),
  });

  Future<Map<String, dynamic>> _sendAndWait({
    required String targetIp,
    required Map<String, dynamic> req,
    required String expectType,
  }) async {
    RawDatagramSocket? socket;
    final completer = Completer<Map<String, dynamic>>();

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: true,
      );

      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket!.receive();
        if (dg == null) return;

        // 타겟 IP에서 온 응답만 처리(브로드캐스트 혼선 방지)
        if (dg.address.address != targetIp) return;

        try {
          final decoded = jsonDecode(utf8.decode(dg.data));
          if (decoded is! Map) return;
          final msg = decoded.cast<String, dynamic>();
          if (msg['type'] != expectType) return;
          if (!completer.isCompleted) completer.complete(msg);
        } catch (_) {
          // ignore
        }
      });

      socket.send(utf8.encode(jsonEncode(req)), InternetAddress(targetIp), port);

      return await completer.future.timeout(timeout, onTimeout: () {
        return {
          'type': expectType,
          'ok': false,
          'error': 'timeout',
        };
      });
    } finally {
      socket?.close();
    }
  }

  Future<Map<String, dynamic>> setMqtt({
    required String targetIp,
    required String brokerHost,
    required int brokerPort,
    String appName = 'LocationX-Manager',
  }) async {
    final req = {
      'type': 'MQTT_SET',
      'app': appName,
      'broker_host': brokerHost,
      'broker_port': brokerPort,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    final resp = await _sendAndWait(
      targetIp: targetIp,
      req: req,
      expectType: 'MQTT_SET_RESPONSE',
    );

    if (resp['error'] == 'timeout') {
      return {
        ...resp,
        'broker_host': brokerHost,
        'broker_port': brokerPort,
      };
    }
    return resp;
  }

  Future<Map<String, dynamic>> reboot({
    required String targetIp,
    int delaySec = 2,
    String reason = 'ui',
    String appName = 'LocationX-Manager',
  }) async {
    final req = {
      'type': 'REBOOT',
      'app': appName,
      'delay_sec': delaySec,
      'reason': reason,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    final resp = await _sendAndWait(
      targetIp: targetIp,
      req: req,
      expectType: 'REBOOT_RESPONSE',
    );

    if (resp['error'] == 'timeout') {
      return {
        ...resp,
        'delay_sec': delaySec,
        'reason': reason,
      };
    }
    return resp;
  }

  Future<Map<String, dynamic>> restartService({
    required String targetIp,
    String serviceName = 'aoa-antenna.service',
    String appName = 'LocationX-Manager',
  }) async {
    final req = {
      'type': 'SERVICE_RESTART',
      'app': appName,
      'service': serviceName,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    final resp = await _sendAndWait(
      targetIp: targetIp,
      req: req,
      expectType: 'SERVICE_RESTART_RESPONSE',
    );

    if (resp['error'] == 'timeout') {
      return {
        ...resp,
        'service': serviceName,
      };
    }
    return resp;
  }
}
