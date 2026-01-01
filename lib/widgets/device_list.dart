import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_providers.dart';
import '../models/device.dart';

class DeviceList extends ConsumerStatefulWidget {
  const DeviceList({super.key});

  @override
  ConsumerState<DeviceList> createState() => _DeviceListState();
}

class _DeviceListState extends ConsumerState<DeviceList> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final notifier = ref.read(devicesProvider.notifier);
    final selectedId = ref.watch(selectedDeviceIdProvider);

    final filtered = devices.where((d) {
      if (query.isEmpty) return true;
      return d.id.toLowerCase().contains(query.toLowerCase()) || d.ip.contains(query);
    }).toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    String statusLabel(DeviceStatus s) {
      switch (s) {
        case DeviceStatus.onlineConfigured:
          return 'CONFIG';
        case DeviceStatus.onlineUnconfigured:
          return 'UNCONF';
        case DeviceStatus.offline:
          return 'OFFLINE';
        case DeviceStatus.error:
          return 'ERROR';
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('장비 목록(관리자)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            TextField(
              decoration: const InputDecoration(
                hintText: 'ID 또는 IP 검색',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => query = v),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = filtered[i];
                  return ListTile(
                    dense: true,
                    selected: d.id == selectedId,
                    title: Text('${d.id}  (${d.ip})'),
                    subtitle: Text(statusLabel(d.status)),
                    onTap: () {
                      ref.read(selectedDeviceIdProvider.notifier).state = d.id;
                      ref.read(tempFloorPosProvider.notifier).state = null;
                    },
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: 'Identify',
                          onPressed: () {
                            notifier.identify(d.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${d.id} Identify 요청')),
                            );
                          },
                          icon: const Icon(Icons.wifi_tethering),
                        ),
                        IconButton(
                          tooltip: '위치 재설정(큐로 되돌리기)',
                          onPressed: (d.status == DeviceStatus.onlineConfigured)
                              ? () {
                            notifier.setUnconfigured(d.id);
                            // 재설정했으면 그 장비를 선택 상태로 유지
                            ref.read(selectedDeviceIdProvider.notifier).state = d.id;
                            ref.read(tempFloorPosProvider.notifier).state = null;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${d.id} 위치 재설정 → 작업 큐로 이동')),
                            );
                          }
                              : null,
                          icon: const Icon(Icons.undo),
                        ),
                      ],
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
