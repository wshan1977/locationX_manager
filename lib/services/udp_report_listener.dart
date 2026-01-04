import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/angle_report.dart';

class UdpReportListener {
  final int port;
  RawDatagramSocket? _socket;
  StreamSubscription? _sub;

  final _controller = StreamController<AngleReport>.broadcast();
  Stream<AngleReport> get stream => _controller.stream;

  UdpReportListener({this.port = 40200});

  bool get isRunning => _socket != null;

  Future<void> start() async {
    if (_socket != null) return;

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    _socket = socket;

    _sub = socket.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = socket.receive();
      if (dg == null) return;

      try {
        final s = utf8.decode(dg.data);
        final j = jsonDecode(s) as Map<String, dynamic>;
        if (j["type"] != "REPORT_ANGLE") return;

        final rep = AngleReport.fromJson(j);
        if (rep.deviceId.isEmpty || rep.tagId.isEmpty) return;

        _controller.add(rep);
      } catch (_) {
        // ignore
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _socket?.close();
    _socket = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}
