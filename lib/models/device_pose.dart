class DevicePose {
  final double x;
  final double y;
  final double z;

  const DevicePose({
    required this.x,
    required this.y,
    required this.z,
  });

  DevicePose copyWith({double? x, double? y, double? z}) {
    return DevicePose(
      x: x ?? this.x,
      y: y ?? this.y,
      z: z ?? this.z,
    );
  }

  Map<String, dynamic> toJson() => {"x": x, "y": y, "z": z};

  factory DevicePose.fromJson(Map<String, dynamic> json) => DevicePose(
    x: (json["x"] as num).toDouble(),
    y: (json["y"] as num).toDouble(),
    z: (json["z"] as num).toDouble(),
  );
}
