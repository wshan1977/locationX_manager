class DeviceConfig {
  Map<String, dynamic> raw; // 서버 JSON을 그대로 들고 다니며 수정

  DeviceConfig(this.raw);

  Map<String, dynamic> get install => (raw["install"] as Map<String, dynamic>? ?? {});
  Map<String, dynamic> get aod => (raw["aod"] as Map<String, dynamic>? ?? {});
  Map<String, dynamic> get report => (raw["report"] as Map<String, dynamic>? ?? {});

  // 편의 getter/setter (필요한 만큼만)
  String get floorId => (install["floorId"] ?? "1F") as String;
  set floorId(String v) => install["floorId"] = v;

  int get anchorId => (install["anchorId"] ?? 1) as int;
  set anchorId(int v) => install["anchorId"] = v;

  Map<String, dynamic> get pos => (install["pos"] as Map<String, dynamic>? ?? {"x": 0.0, "y": 0.0, "z": 2.7});
  double get x => (pos["x"] as num?)?.toDouble() ?? 0.0;
  double get y => (pos["y"] as num?)?.toDouble() ?? 0.0;
  double get z => (pos["z"] as num?)?.toDouble() ?? 2.7;

  set x(double v) => pos["x"] = v;
  set y(double v) => pos["y"] = v;
  set z(double v) => pos["z"] = v;

  double get yawDeg => (install["yawDeg"] as num?)?.toDouble() ?? 0.0;
  set yawDeg(double v) => install["yawDeg"] = v;

  String get floorplanId => (install["floorplanId"] ?? "fp1") as String;
  set floorplanId(String v) => install["floorplanId"] = v;

  // AoD 주요 값
  bool get angleFiltering => (aod["angleFiltering"] ?? true) as bool;
  set angleFiltering(bool v) => aod["angleFiltering"] = v;

  double get angleFilteringWeight => (aod["angleFilteringWeight"] as num?)?.toDouble() ?? 0.6;
  set angleFilteringWeight(double v) => aod["angleFilteringWeight"] = v;

  int get cteLength => (aod["cteLength"] ?? 20) as int;
  set cteLength(int v) => aod["cteLength"] = v;

  int get slotDuration => (aod["slotDuration"] ?? 1) as int;
  set slotDuration(int v) => aod["slotDuration"] = v;

  // Report
  int get rateHz => (report["rateHz"] ?? 10) as int;
  set rateHz(int v) => report["rateHz"] = v;

  Map<String, dynamic> get dst => (report["dst"] as Map<String, dynamic>? ?? {"host": "127.0.0.1", "port": 40200});
  String get dstHost => (dst["host"] ?? "127.0.0.1") as String;
  int get dstPort => (dst["port"] ?? 40200) as int;
  set dstHost(String v) => dst["host"] = v;
  set dstPort(int v) => dst["port"] = v;

  Map<String, dynamic> toPutBody() {
    // 시뮬레이터 set_config()가 aod/report/install만 반영하므로 그 구조로 전송
    return {
      "install": install,
      "aod": aod,
      "report": report,
    };
  }
}
