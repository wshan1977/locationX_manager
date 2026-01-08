import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/devices_provider.dart';
import '../models/device.dart';

class DeviceList extends ConsumerStatefulWidget {
  const DeviceList({super.key});

  @override
  ConsumerState<DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends ConsumerState<DeviceList> {
  String query = '';

  void _log(String msg) {
    // release에서도 너무 많이 찍히면 부담이니 kDebugMode에서만
    if (kDebugMode) debugPrint('[DeviceList] $msg');
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(devicesControllerProvider);
    final notifier = ref.read(devicesControllerProvider);

    // ✅ 선택 키 (현재는 IP로 쓰는 전제)
    final selectedIp = ref.watch(selectedDeviceIdProvider);

    final devices = ctrl.devices;

    final filtered = devices.where((d) {
      if (query.isEmpty) return true;
      final q = query.toLowerCase();

      return d.hostname.toLowerCase().contains(q) ||
          d.ip.toLowerCase().contains(q) ||
          (d.mac ?? '').toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.ip.compareTo(b.ip));

    // ✅ build마다 한 번: 현재 선택 상태/목록 개수
    _log('BUILD: devices=${devices.length}, filtered=${filtered.length}, selectedIp=$selectedIp');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('장비 목록(관리자)',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    _log('Discover 버튼 클릭');
                    await notifier.discoverUdp();
                    _log('Discover 완료: devices=${ctrl.devices.length}');
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Discover (UDP)'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    _log('Clear 버튼 클릭');
                    notifier.clearDevices();
                    ref.read(selectedDeviceIdProvider.notifier).state = null;
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            TextField(
              decoration: const InputDecoration(
                hintText: 'Hostname / IP / MAC 검색',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) {
                setState(() => query = v);
                _log('검색 변경: query="$v"');
              },
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = filtered[i];
                  final macLabel =
                  (d.mac == null || d.mac!.isEmpty) ? 'N/A' : d.mac!;
                  final isSelected = d.ip == selectedIp;

                  // ✅ 각 타일이 build될 때도 핵심 정보 로그
                  _log('TILE build #$i: host=${d.hostname}, ip=${d.ip}, mac=$macLabel, '
                      'fw=${d.fw}, selected=$isSelected');

                  return ListTile(
                    // ✅ 키도 IP로 고정
                    key: ValueKey(d.ip),
                    dense: true,
                    selected: isSelected,
                    title: Text('${d.hostname}  (${d.ip})'),
                    subtitle: Text('MAC: $macLabel  •  FW: ${d.fw}'),
                    onTap: () {
                      // ✅ 탭 로그: 누른 항목 전체 정보 + 선택값 변경 전/후
                      final before = ref.read(selectedDeviceIdProvider);
                      _log('TAP #$i: BEFORE selectedIp=$before');
                      _log('TAP #$i: CLICK host=${d.hostname}, ip=${d.ip}, mac=$macLabel, fw=${d.fw}');

                      ref.read(selectedDeviceIdProvider.notifier).state = d.ip;

                      final after = ref.read(selectedDeviceIdProvider);
                      _log('TAP #$i: AFTER selectedIp=$after');

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(milliseconds: 800),
                          content: Text('선택: ${d.hostname} / ${d.ip} / $macLabel'),
                        ),
                      );
                    },
                    trailing: IconButton(
                      tooltip: 'Identify (LED 점멸)',
                      onPressed: () {
                        _log('IDENTIFY 클릭: ip=${d.ip}, host=${d.hostname}, mac=$macLabel');
                        notifier.identify(d.ip);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(milliseconds: 800),
                            content: Text('Identify: ${d.hostname} (${d.ip})'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.wifi_tethering),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
