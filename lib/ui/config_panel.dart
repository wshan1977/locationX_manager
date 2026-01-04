import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/config_provider.dart';
import '../providers/devices_provider.dart';

class ConfigPanel extends ConsumerStatefulWidget {
  const ConfigPanel({super.key});

  @override
  ConsumerState<ConfigPanel> createState() => _ConfigPanelState();
}

class _ConfigPanelState extends ConsumerState<ConfigPanel> {
  // Advanced JSON editor용
  final TextEditingController _aodJsonCtrl = TextEditingController();
  String? _jsonError;

  void _syncJsonEditor(Map<String, dynamic> aod) {
    _aodJsonCtrl.text = const JsonEncoder.withIndent("  ").convert(aod);
    _jsonError = null;
  }

  bool _applyJsonToCfg() {
    final st = ref.read(configControllerProvider);
    final cfg = st.cfg;
    if (cfg == null) return false;

    try {
      final parsed = jsonDecode(_aodJsonCtrl.text);
      if (parsed is! Map<String, dynamic>) {
        setState(() => _jsonError = "AoD JSON은 객체(Map) 형태여야 합니다.");
        return false;
      }
      cfg.raw["aod"] = parsed;
      ref.read(configControllerProvider.notifier).markDirty();
      setState(() => _jsonError = null);
      return true;
    } catch (e) {
      setState(() => _jsonError = "JSON 파싱 오류: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = ref.watch(selectedDeviceIdProvider);
    final st = ref.watch(configControllerProvider);
    final ctrl = ref.read(configControllerProvider.notifier);

    final cfg = st.cfg;

    // cfg가 새로 로드되면 JSON editor도 동기화
    if (cfg != null && _aodJsonCtrl.text.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "장비 설정 (/api/v1/config)",
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OutlinedButton(
                onPressed: (sel == null || st.loading || st.saving)
                    ? null
                    : () async {
                  await ctrl.loadForSelected();
                  final ns = ref.read(configControllerProvider);
                  if (ns.cfg != null) {
                    _syncJsonEditor(Map<String, dynamic>.from(ns.cfg!.aod));
                  }
                },
                child: Text(st.loading ? "Loading..." : "Load"),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: (sel == null || cfg == null || st.saving)
                    ? null
                    : () async {
                  // Save 전에 JSON editor 적용을 선택적으로 강제 (원하면 항상 적용)
                  if (_aodJsonCtrl.text.trim().isNotEmpty) {
                    _applyJsonToCfg();
                  }
                  await ctrl.save();
                },
                child: Text(st.saving ? "Saving..." : "Save"),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(sel == null ? "장비를 선택하세요." : "선택 장비: $sel  |  dirty=${st.dirty}"),
          if (st.error != null) ...[
            const SizedBox(height: 8),
            Text(st.error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),

          if (cfg == null)
            Expanded(
              child: Center(
                child: Text(sel == null ? "장비 선택 후 Load를 누르세요." : "Load를 눌러 현재 설정을 가져오세요."),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  _sectionTitle(context, "Install (Location)"),
                  _textField(
                    label: "floorId",
                    initial: cfg.floorId,
                    onChanged: (v) {
                      cfg.floorId = v;
                      ctrl.markDirty();
                    },
                  ),
                  _intField(
                    label: "anchorId",
                    initial: cfg.anchorId,
                    onChanged: (v) {
                      cfg.anchorId = v;
                      ctrl.markDirty();
                    },
                  ),
                  _doubleRow3(
                    label: "pos (x,y,z)",
                    x: cfg.x,
                    y: cfg.y,
                    z: cfg.z,
                    onChanged: (nx, ny, nz) {
                      cfg.x = nx;
                      cfg.y = ny;
                      cfg.z = nz;
                      ctrl.markDirty();
                    },
                  ),
                  _doubleField(
                    label: "yawDeg",
                    initial: cfg.yawDeg,
                    onChanged: (v) {
                      cfg.yawDeg = v;
                      ctrl.markDirty();
                    },
                  ),
                  _textField(
                    label: "floorplanId",
                    initial: cfg.floorplanId,
                    onChanged: (v) {
                      cfg.floorplanId = v;
                      ctrl.markDirty();
                    },
                  ),

                  const SizedBox(height: 12),
                  _sectionTitle(context, "Report"),
                  _intField(
                    label: "rateHz",
                    initial: cfg.rateHz,
                    onChanged: (v) {
                      cfg.rateHz = v.clamp(1, 100);
                      ctrl.markDirty();
                    },
                  ),
                  _textField(
                    label: "dst.host",
                    initial: cfg.dstHost,
                    onChanged: (v) {
                      cfg.dstHost = v;
                      ctrl.markDirty();
                    },
                  ),
                  _intField(
                    label: "dst.port",
                    initial: cfg.dstPort,
                    onChanged: (v) {
                      cfg.dstPort = v;
                      ctrl.markDirty();
                    },
                  ),

                  const SizedBox(height: 14),
                  _sectionTitle(context, "AoD / AoX"),

                  // ✅ Basic
                  ExpansionTile(
                    initiallyExpanded: true,
                    title: const Text("Basic (현장용)"),
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("angleFiltering"),
                        value: cfg.angleFiltering,
                        onChanged: (v) {
                          cfg.angleFiltering = v;
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      _doubleField(
                        label: "angleFilteringWeight (0~1)",
                        initial: cfg.angleFilteringWeight,
                        onChanged: (v) {
                          cfg.angleFilteringWeight = v.clamp(0.0, 1.0);
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      _intField(
                        label: "cteSamplingInterval",
                        initial: (cfg.aod["cteSamplingInterval"] ?? 3) as int,
                        onChanged: (v) {
                          cfg.aod["cteSamplingInterval"] = v.clamp(1, 20);
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      _intField(
                        label: "cteLength",
                        initial: cfg.cteLength,
                        onChanged: (v) {
                          cfg.cteLength = v.clamp(1, 160);
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      _intField(
                        label: "slotDuration",
                        initial: cfg.slotDuration,
                        onChanged: (v) {
                          cfg.slotDuration = v.clamp(1, 4);
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      _doubleRow2(
                        label: "elevationMask[0] (min,max)",
                        minV: _maskMin(cfg.aod),
                        maxV: _maskMax(cfg.aod),
                        onChanged: (mn, mx) {
                          final list = (cfg.aod["elevationMask"] as List?) ?? [];
                          if (list.isEmpty) {
                            cfg.aod["elevationMask"] = [
                              {"min": mn, "max": mx}
                            ];
                          } else {
                            final m = Map<String, dynamic>.from(list.first as Map);
                            m["min"] = mn;
                            m["max"] = mx;
                            cfg.aod["elevationMask"] = [m, ...list.skip(1)];
                          }
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),

                  // ✅ Advanced
                  ExpansionTile(
                    initiallyExpanded: false,
                    title: const Text("Advanced (엔지니어용)"),
                    children: [
                      _textField(
                        label: "aoxMode",
                        initial: (cfg.aod["aoxMode"] ?? "SL_RTL_AOX_MODE_REAL_TIME_BASIC") as String,
                        onChanged: (v) {
                          cfg.aod["aoxMode"] = v;
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      _textField(
                        label: "antennaMode",
                        initial: (cfg.aod["antennaMode"] ?? "SL_RTL_AOX_ARRAY_TYPE_4x4_URA") as String,
                        onChanged: (v) {
                          cfg.aod["antennaMode"] = v;
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      _textField(
                        label: "cteMode",
                        initial: (cfg.aod["cteMode"] ?? "CONNLESS") as String,
                        onChanged: (v) {
                          cfg.aod["cteMode"] = v;
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      _intField(
                        label: "angleCorrectionTimeout",
                        initial: (cfg.aod["angleCorrectionTimeout"] ?? 5) as int,
                        onChanged: (v) {
                          cfg.aod["angleCorrectionTimeout"] = v.clamp(0, 60);
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),
                      _intField(
                        label: "angleCorrectionDelay",
                        initial: (cfg.aod["angleCorrectionDelay"] ?? 3) as int,
                        onChanged: (v) {
                          cfg.aod["angleCorrectionDelay"] = v.clamp(0, 60);
                          ctrl.markDirty();
                          _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                        },
                      ),

                      const SizedBox(height: 8),
                      _sectionTitle(context, "AoD JSON Editor (전체)"),
                      TextField(
                        controller: _aodJsonCtrl,
                        minLines: 10,
                        maxLines: 18,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          hintText: "AoD 전체 JSON을 편집하세요 (Map 형태).",
                          errorText: _jsonError,
                        ),
                        onChanged: (_) {
                          // 입력 중에는 dirty 표시만
                          ctrl.markDirty();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              _syncJsonEditor(Map<String, dynamic>.from(cfg.aod));
                            },
                            child: const Text("Reset JSON from current"),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              _applyJsonToCfg();
                            },
                            child: const Text("Apply JSON"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
        ]),
      ),
    );
  }

  double _maskMin(Map<String, dynamic> aod) {
    final m = (aod["elevationMask"] as List?)?.isNotEmpty == true ? (aod["elevationMask"] as List).first : null;
    if (m is Map) return (m["min"] as num?)?.toDouble() ?? 0.0;
    return 0.0;
  }

  double _maskMax(Map<String, dynamic> aod) {
    final m = (aod["elevationMask"] as List?)?.isNotEmpty == true ? (aod["elevationMask"] as List).first : null;
    if (m is Map) return (m["max"] as num?)?.toDouble() ?? 10.0;
    return 10.0;
  }

  Widget _sectionTitle(BuildContext context, String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _textField({required String label, required String initial, required ValueChanged<String> onChanged}) {
    final c = TextEditingController(text: initial);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }

  Widget _intField({required String label, required int initial, required ValueChanged<int> onChanged}) {
    final c = TextEditingController(text: initial.toString());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: TextInputType.number,
        onChanged: (s) => onChanged(int.tryParse(s) ?? initial),
      ),
    );
  }

  Widget _doubleField({required String label, required double initial, required ValueChanged<double> onChanged}) {
    final c = TextEditingController(text: initial.toStringAsFixed(3));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (s) => onChanged(double.tryParse(s) ?? initial),
      ),
    );
  }

  Widget _doubleRow3({
    required String label,
    required double x,
    required double y,
    required double z,
    required void Function(double, double, double) onChanged,
  }) {
    final cx = TextEditingController(text: x.toStringAsFixed(3));
    final cy = TextEditingController(text: y.toStringAsFixed(3));
    final cz = TextEditingController(text: z.toStringAsFixed(3));

    double vx = x, vy = y, vz = z;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: cx,
                  decoration: const InputDecoration(labelText: "x", border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (s) { vx = double.tryParse(s) ?? vx; onChanged(vx, vy, vz); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: cy,
                  decoration: const InputDecoration(labelText: "y", border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (s) { vy = double.tryParse(s) ?? vy; onChanged(vx, vy, vz); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: cz,
                  decoration: const InputDecoration(labelText: "z", border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (s) { vz = double.tryParse(s) ?? vz; onChanged(vx, vy, vz); },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _doubleRow2({
    required String label,
    required double minV,
    required double maxV,
    required void Function(double, double) onChanged,
  }) {
    final cmin = TextEditingController(text: minV.toStringAsFixed(2));
    final cmax = TextEditingController(text: maxV.toStringAsFixed(2));
    double vmin = minV, vmax = maxV;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: cmin,
                  decoration: const InputDecoration(labelText: "min", border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (s) { vmin = double.tryParse(s) ?? vmin; onChanged(vmin, vmax); },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: cmax,
                  decoration: const InputDecoration(labelText: "max", border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (s) { vmax = double.tryParse(s) ?? vmax; onChanged(vmin, vmax); },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
