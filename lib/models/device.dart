enum DeviceStatus { onlineUnconfigured, onlineConfigured, offline, error }

class Device {
  final String id;
  final String ip;
  final DeviceStatus status;

  // 평면도 정규화 좌표 (0.0~1.0)
  final double? fx;
  final double? fy;

  const Device({
    required this.id,
    required this.ip,
    required this.status,
    this.fx,
    this.fy,
  });

  Device copyWith({
    String? id,
    String? ip,
    DeviceStatus? status,
    double? fx,
    double? fy,
    bool clearPos = false,
  }) {
    return Device(
      id: id ?? this.id,
      ip: ip ?? this.ip,
      status: status ?? this.status,
      fx: clearPos ? null : (fx ?? this.fx),
      fy: clearPos ? null : (fy ?? this.fy),
    );
  }
}
