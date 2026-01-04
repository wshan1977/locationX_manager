import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/device.dart';

class UdpDiscoveryService {
  final int discoverPort;
  final Duration timeout;

  const UdpDiscoveryService({
    this.discoverPort = 40010,
    this.timeout = const Duration(seconds: 2),
  });

  /// 브로드캐스트 DISCOVER 전송 후, timeout 동안 DISCOVER_RESPONSE들을 모아서 반환
  Future<List<Device>> discover({String appName = 'LocationX-Manager'}) async {
    RawDatagramSocket? socket;
    final Map<String, Device> unique = {}; // fromAddr 기준 중복 제거

    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0, // OS가 임시 포트 할당
        reuseAddress: true,
        reusePort: true,
      );

      socket.broadcastEnabled = true;

      // 수신 이벤트 처리
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final dg = socket!.receive();
        if (dg == null) return;

        final fromAddr = dg.address.address;

        Map<String, dynamic>? msg;
        try {
          final s = utf8.decode(dg.data);
          final decoded = jsonDecode(s);
          if (decoded is Map<String, dynamic>) {
            msg = decoded;
          } else if (decoded is Map) {
            msg = decoded.cast<String, dynamic>();
          }
        } catch (_) {
          return;
        }

        if (msg == null) return;
        if (msg!['type'] != 'DISCOVER_RESPONSE') return;

        final d = Device.fromDiscoverResponse(msg!, fromAddr: fromAddr);
        // fromAddr를 키로 중복 제거 (원하면 device로 바꿔도 됨)
        unique[fromAddr] = d;
      });

      // Discover 전송
      final discoverMsg = {
        'type': 'DISCOVER',
        'app': appName,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      final payload = utf8.encode(jsonEncode(discoverMsg));

      // 255.255.255.255 브로드캐스트
      socket.send(payload, InternetAddress('255.255.255.255'), discoverPort);

      // timeout 동안 대기 후 종료
      await Future.delayed(timeout);

      final list = unique.values.toList();
      // 보기 좋게 정렬 (device명 기준)
      list.sort((a, b) => a.deviceId.compareTo(b.deviceId));
      return list;
    } finally {
      socket?.close();
    }
  }
}
