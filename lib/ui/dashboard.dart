import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device.dart';
import '../providers/devices_provider.dart';
import 'config_panel.dart';

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});

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

    /// ✅ 이제 selectedDeviceIdProvider에는 "IP"가 들어간다고 가정
    final selectedIp = ref.watch(selectedDeviceIdProvider);

    /// ✅ 선택 장비 찾기도 IP 기준으로
    final sel = st.devices.where((d) => d.ip == selectedIp).toList();
    final device = sel.isEmpty ? null : sel.first;

    final total = st.devices.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text("LocationX Windows (Setup)"),
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
            // ============================
            // LEFT: Device list
            // ============================
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
                            label: Text(
                              st.discovering ? "Discovering..." : "Discover (UDP)",
                            ),
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

                            /// ✅ selected 판단도 IP 기준
                            final selected = d.ip == selectedIp;

                            /// ✅ mac 표시(있으면)
                            final macLabel = (d.mac == null || d.mac!.isEmpty) ? "N/A" : d.mac!;

                            return ListTile(
                              key: ValueKey(d.ip), // ✅ 리스트 재사용 꼬임 방지
                              selected: selected,
                              title: Text(
                                d.hostname,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text("IP: ${d.ip}   |   MAC: $macLabel   |   FW: ${d.fw}"),
                              trailing: _ledIcon(d),

                              /// ✅ 탭했을 때 저장도 IP로!
                              onTap: () => ref
                                  .read(selectedDeviceIdProvider.notifier)
                                  .state = d.ip,
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

            // ============================
            // RIGHT: Config Panel only
            // ============================
            Expanded(
              child: Column(
                children: [
                  // Selected device summary + Identify
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
                                  "선택 장비",
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                Text("Hostname: ${device.hostname}"),
                                Text("IP: ${device.ip}"),
                                Text("MAC: ${(device.mac == null || device.mac!.isEmpty) ? "N/A" : device.mac!}"),
                                Text("FW: ${device.fw}"),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 220,
                            child: FilledButton(
                              onPressed: (st.busy || device == null)
                                  ? null
                                  : () => ctrl.identify(device.ip), // ✅ Identify도 IP로!
                              child: Text(
                                st.busy ? "처리중..." : "Identify (LED 점멸)",
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Config Panel
                  const Expanded(
                    child: ConfigPanel(),
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
