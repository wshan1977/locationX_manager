class AngleReport {
  final String deviceId;
  final String tagId;
  final double azimuthDeg;
  final double elevationDeg;
  final int rssi;
  final int tsMs;

  const AngleReport({
    required this.deviceId,
    required this.tagId,
    required this.azimuthDeg,
    required this.elevationDeg,
    required this.rssi,
    required this.tsMs,
  });

  factory AngleReport.fromJson(Map<String, dynamic> j) {
    return AngleReport(
      deviceId: (j["deviceId"] ?? "") as String,
      tagId: (j["tagId"] ?? "") as String,
      azimuthDeg: (j["azimuthDeg"] as num?)?.toDouble() ?? 0.0,
      elevationDeg: (j["elevationDeg"] as num?)?.toDouble() ?? 0.0,
      rssi: (j["rssi"] as num?)?.toInt() ?? -999,
      tsMs: (j["tsMs"] as num?)?.toInt() ?? 0,
    );
  }
}
