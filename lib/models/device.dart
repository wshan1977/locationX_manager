enum LedState {
  off,
  on,
  blink,
}

class Device {
  final String hostname;
  final String ip;
  final String fw;

  /// Discover에서 오는 고유 식별자 (예: ble-pd-4C5BB3CA792E)
  /// 없을 수도 있으니 nullable로 둠
  final String? mac;

  /// UI 표시용 LED 상태
  final LedState ledState;

  /// ledState==blink 일 때 아이콘 ON/OFF 토글에 사용
  final bool blinkPhase;

  const Device({
    required this.hostname,
    required this.ip,
    required this.fw,
    this.mac,
    this.ledState = LedState.off,
    this.blinkPhase = true,
  });

  /// ✅ 앱 내부에서 사용하는 “고유 ID”
  /// - mac이 있으면 mac
  /// - 없으면 ip (hostname은 중복될 수 있어서 제외)
  String get deviceId {
    final m = (mac ?? '').trim();
    if (m.isNotEmpty && m != 'MAC_ERR') return m;
    return ip;
  }

  /// ✅ 기존 코드 호환: d.id 로 쓰던 곳을 깨지 않기 위한 alias
  String get id => deviceId;

  Device copyWith({
    String? hostname,
    String? ip,
    String? fw,
    String? mac,
    LedState? ledState,
    bool? blinkPhase,
  }) {
    return Device(
      hostname: hostname ?? this.hostname,
      ip: ip ?? this.ip,
      fw: fw ?? this.fw,
      mac: mac ?? this.mac,
      ledState: ledState ?? this.ledState,
      blinkPhase: blinkPhase ?? this.blinkPhase,
    );
  }

  /// UDP DISCOVER_RESPONSE 파싱
  /// - hostname: msg['hostname'] 또는 msg['device']
  /// - ip: msg['ip'] 없으면 sender 주소(fromAddr)
  /// - fw: msg['ver'] 없으면 'unknown'
  /// - mac: msg['mac'] 없으면 null (혹은 'MAC_ERR'면 null 처리)
  factory Device.fromDiscoverResponse(
      Map<String, dynamic> msg, {
        required String fromAddr,
      }) {
    final rawMac = (msg['mac'] ?? '').toString().trim();
    final mac = (rawMac.isEmpty || rawMac == 'MAC_ERR') ? null : rawMac;

    return Device(
      hostname: (msg['hostname'] ?? msg['device'] ?? 'UNKNOWN').toString(),
      ip: (msg['ip'] ?? fromAddr).toString(),
      fw: (msg['ver'] ?? 'unknown').toString(),
      mac: mac,
      ledState: LedState.off,
      blinkPhase: true,
    );
  }
}
