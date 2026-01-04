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

  Future<void> _confirmResetAll(BuildContext context, VoidCallback onYes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('모두 되돌리기'),
          content: const Text(
            '모든 장비를 “미설정(작업 큐)” 상태로 되돌리고\n'
                '평면도 위치(핀)도 모두 삭제합니다.\n\n'
                '진행할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('되돌리기'),
            ),
          ],
        );
      },
    );

    if (ok == true) onYes();
  }

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

    final unconfCount =
        devices.where((d) => d.status == DeviceStatus.onlineUnconfigured).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ 상단 헤더 + 전체 되돌리기 버튼
            Row(
              children: [
                Text('장비 목록(관리자)', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    _confirmResetAll(context, () {
                      notifier.resetAllToUnconfigured();

                      // 선택/임시 핀도 같이 초기화(혼란 방지)
                      ref.read(selectedDeviceIdProvider.notifier).state = null;
                      ref.read(tempFloorPosProvider.notifier).state = null;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('전체 되돌리기 완료 (미설정: ${unconfCount} → ${devices.length})')),
                      );
                    });
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('모두 되돌리기'),
                ),
              ],
            ),
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
