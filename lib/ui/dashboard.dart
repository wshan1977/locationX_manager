import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/devices_provider.dart';
import '../providers/angle_provider.dart';
import '../providers/floorplan_provider.dart';
import '../models/device.dart';

import 'floorplan_panel.dart';
import 'config_panel.dart';
import 'resizable_row.dart';

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});

  String _fmtAgo(int lastSeenMs) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final d = now - lastSeenMs;
    if (d < 1000) return "${d}ms";
    if (d < 60 * 1000) return "${(d / 1000).toStringAsFixed(1)}s";
    return "${(d / 60000).toStringAsFixed(1)}m";
  }

  Widget _ledIcon(Device d) {
    // BLINK일 때는 blinkPhase로 아이콘을 숨겼다 보였다 함(깜박임)
    if (d.ledState == LedState.blink) {
      if (!d.blinkPhase) return const SizedBox(width: 24);
      return const Icon(Icons.circle, color: Colors.orange);
    }
    if (d.ledState == LedState.on) {
      return const Icon(Icons.circle, color: Colors.green);
    }
    return const Icon(Icons.circle_outlined, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(devicesControllerProvider);
    final ctrl = ref.read(devicesControllerProvider.notifier);

    final selectedId = ref.watch(selectedDeviceIdProvider);
    final temp = ref.watch(tempPosProvider);

    final angleState = ref.watch(angleControllerProvider);
    final angleCtrl = ref.read(angleControllerProvider.notifier);

    final sel = st.devices.where((d) => d.deviceId == selectedId).toList();
    final device = sel.isEmpty ? null : sel.first;

    final total = st.devices.length;

    final angleList =
    (device == null) ? const [] : angleCtrl.getLatestForDevice(device.deviceId);

    Widget anglePanel() {
      return SizedBox(
        width: double.infinity,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "실시간 Angle(UDP 40200)",
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Tooltip(
                      message: "Start",
                      child: IconButton(
                        onPressed: angleState.running ? null : () => angleCtrl.start(),
                        icon: const Icon(Icons.play_arrow),
                      ),
                    ),
                    Tooltip(
                      message: "Stop",
                      child: IconButton(
                        onPressed: angleState.running ? () => angleCtrl.stop() : null,
                        icon: const Icon(Icons.stop),
                      ),
                    ),
                    Tooltip(
                      message: "Clear",
                      child: IconButton(
                        onPressed: () => angleCtrl.clear(),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (angleState.error != null)
                  Text(angleState.error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 6),
                Text(
                  device == null
                      ? "장비를 선택하면 해당 장비의 태그 각도만 표시됩니다."
                      : "선택 장비: ${device.deviceId} | tags: ${angleList.length}",
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                Expanded(
                  child: device == null
                      ? const Center(child: Text("좌측에서 장비를 선택하세요."))
                      : angleList.isEmpty
                      ? Center(
                    child: Text(angleState.running
                        ? "수신 대기중..."
                        : "Start를 눌러 수신을 시작하세요."),
                  )
                      : ListView.separated(
                    itemCount: angleList.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final t = angleList[i];
                      final r = t.report;
                      return ListTile(
                        dense: true,
                        title: Text(r.tagId),
                        subtitle: Text(
                          "az=${r.azimuthDeg.toStringAsFixed(1)}°, "
                              "el=${r.elevationDeg.toStringAsFixed(1)}°, "
                              "rssi=${r.rssi}dBm  |  last=${_fmtAgo(t.lastSeenMs)}",
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("LocationX Windows (UDP Real Devices)"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text("Devices: $total")),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // LEFT: Device list
            SizedBox(
              width: 420,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: (st.discovering || st.busy)
                                ? null
                                : () => ctrl.discover(),
                            icon: const Icon(Icons.radar),
                            label: Text(st.discovering ? "Discovering..." : "Discover (UDP)"),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: st.devices.isEmpty ? null : () => ctrl.clearDevices(),
                            child: const Text("Clear"),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (st.error != null)
                        Text(st.error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),

                      Expanded(
                        child: st.devices.isEmpty
                            ? const Center(
                          child: Text(
                            "Discover를 누르면 같은 LAN의 LocationX 장비가 UDP로 응답합니다.\n"
                                "표시: hostname / ip / fw / led",
                            textAlign: TextAlign.center,
                          ),
                        )
                            : ListView.separated(
                          itemCount: st.devices.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final d = st.devices[i];
                            final selected = d.deviceId == selectedId;

                            return ListTile(
                              selected: selected,
                              title: Text(
                                d.hostname,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text("IP: ${d.ip}   |   FW: ${d.fw}"),
                              trailing: _ledIcon(d),
                              onTap: () => ref.read(selectedDeviceIdProvider.notifier).state = d.deviceId,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // RIGHT
            Expanded(
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: device == null
                          ? const Text("왼쪽에서 장비를 선택하세요.")
                          : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "현재 선택",
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text("Hostname: ${device.hostname}"),
                                Text("IP: ${device.ip}"),
                                Text("FW: ${device.fw}"),
                                const SizedBox(height: 8),
                                Text(
                                  temp == null
                                      ? "평면도에서 위치를 클릭하세요."
                                      : "선택 좌표: x=${temp.x.toStringAsFixed(2)}m, y=${temp.y.toStringAsFixed(2)}m",
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              SizedBox(
                                width: 220,
                                child: FilledButton(
                                  onPressed: (device == null || st.busy)
                                      ? null
                                      : () => ctrl.identify(device.deviceId),
                                  child: Text(st.busy ? "처리중..." : "Identify (LED 점멸)"),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: 220,
                                child: OutlinedButton(
                                  onPressed: device == null
                                      ? null
                                      : () => ctrl.updateLedState(device.deviceId, LedState.off),
                                  child: const Text("LED Off (UI)"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: ResizableRow3(
                      initialMiddleWidth: 420,
                      initialRightWidth: 460,
                      minMiddleWidth: 320,
                      minRightWidth: 360,
                      left: const FloorplanPanel(),
                      middle: anglePanel(),
                      right: const ConfigPanel(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
