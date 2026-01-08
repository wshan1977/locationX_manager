import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/device_pose.dart';
import '../../providers/devices_provider.dart';
import '../../providers/device_pose_provider.dart';

class DevicePoseTab extends ConsumerStatefulWidget {
  const DevicePoseTab({super.key});

  @override
  ConsumerState<DevicePoseTab> createState() => _DevicePoseTabState();
}

class _DevicePoseTabState extends ConsumerState<DevicePoseTab> {
  final _x = TextEditingController();
  final _y = TextEditingController();
  final _z = TextEditingController();

  @override
  void dispose() {
    _x.dispose();
    _y.dispose();
    _z.dispose();
    super.dispose();
  }

  void _loadFromPose(DevicePose? pose) {
    // 이미 입력 중이면 덮어쓰기 싫을 수 있어서, 값이 비어있을 때만 채우는 방식
    if ((_x.text.isEmpty && _y.text.isEmpty && _z.text.isEmpty) && pose != null) {
      _x.text = pose.x.toString();
      _y.text = pose.y.toString();
      _z.text = pose.z.toString();
    }
  }

  double? _parse(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    final selectedIp = ref.watch(selectedDeviceIdProvider);
    final pose = ref.watch(selectedDevicePoseProvider);

    _loadFromPose(pose);

    if (selectedIp == null) {
      return const Center(child: Text('먼저 왼쪽에서 장비를 선택하세요.'));
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('좌표 설정', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('선택된 장비 IP: $selectedIp'),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _x,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'X', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _y,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Y', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _z,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(labelText: 'Z', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () {
                  final x = _parse(_x.text);
                  final y = _parse(_y.text);
                  final z = _parse(_z.text);

                  if (x == null || y == null || z == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('X/Y/Z를 모두 숫자로 입력하세요.')),
                    );
                    return;
                  }

                  ref.read(devicePoseMapProvider.notifier).setPose(
                    selectedIp,
                    DevicePose(x: x, y: y, z: z),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('저장 완료: $selectedIp → ($x, $y, $z)')),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('저장'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(devicePoseMapProvider.notifier).removePose(selectedIp);
                  _x.clear();
                  _y.clear();
                  _z.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('삭제 완료: $selectedIp')),
                  );
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('삭제'),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),

          Text(
            '현재 저장된 값',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(pose == null ? '없음' : '(${pose.x}, ${pose.y}, ${pose.z})'),
        ],
      ),
    );
  }
}
