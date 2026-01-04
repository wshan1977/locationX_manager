enum LedState {
  off,
  on,
  blink,
}

class Device {
  final String hostname;
  final String ip;
  final String fw;

  /// UI 표시용 LED 상태
  final LedState ledState;

  /// ledState==blink 일 때 아이콘 ON/OFF 토글에 사용
  final bool blinkPhase;

  const Device({
    required this.hostname,
    required this.ip,
    required this.fw,
    this.ledState = LedState.off,
    this.blinkPhase = true,
  });

  /// Dashboard 호환
  String get deviceId => hostname;

  Device copyWith({
    String? hostname,
    String? ip,
    String? fw,
    LedState? ledState,
    bool? blinkPhase,
  }) {
    return Device(
      hostname: hostname ?? this.hostname,
      ip: ip ?? this.ip,
      fw: fw ?? this.fw,
      ledState: ledState ?? this.ledState,
      blinkPhase: blinkPhase ?? this.blinkPhase,
    );
  }

  /// UDP DISCOVER_RESPONSE 파싱
  /// - hostname: msg['hostname'] 또는 msg['device']
  /// - ip: msg['ip'] 없으면 sender 주소(fromAddr)
  /// - fw: msg['ver'] 없으면 'unknown'
  factory Device.fromDiscoverResponse(
      Map<String, dynamic> msg, {
        required String fromAddr,
      }) {
    return Device(
      hostname: (msg['hostname'] ?? msg['device'] ?? 'UNKNOWN').toString(),
      ip: (msg['ip'] ?? fromAddr).toString(),
      fw: (msg['ver'] ?? 'unknown').toString(),
      ledState: LedState.off,
      blinkPhase: true,
    );
  }
}
