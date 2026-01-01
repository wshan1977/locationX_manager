import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_providers.dart';
import '../providers/floorplan_providers.dart';

class FloorplanView extends ConsumerWidget {
  const FloorplanView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    final notifier = ref.read(devicesProvider.notifier);

    final current = ref.watch(currentTaskProvider);
    final selectedId = ref.watch(selectedDeviceIdProvider);
    final temp = ref.watch(tempFloorPosProvider);

    final floorplans = ref.watch(floorplansProvider);
    final selectedFloorplan = ref.watch(selectedFloorplanProvider);

    // 선택 장비 우선, 없으면 현재 작업
    final effectiveId = selectedId ?? current?.id;
    final effective = (effectiveId == null)
        ? null
        : devices.where((d) => d.id == effectiveId).firstOrNull;

    return Card(
      child: Column(
        children: [
          // 상단 바: 도면 선택 + 확정 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: selectedFloorplan.id,
                  items: [
                    for (final fp in floorplans)
                      DropdownMenuItem(
                        value: fp.id,
                        child: Text(fp.name),
                      ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    ref.read(selectedFloorplanIdProvider.notifier).state = v;
                    // 도면 바꾸면 임시 핀은 지우는 게 안전
                    ref.read(tempFloorPosProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 12),
                Text(
                  effective == null ? '선택된 장비 없음' : '선택: ${effective.id}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: (effective == null || temp == null)
                      ? null
                      : () {
                    // 임시 좌표 확정 → 저장 + 작업완료 처리
                    notifier.setDeviceFloorPos(effective.id, temp.dx, temp.dy);
                    notifier.setConfigured(effective.id);
                    ref.read(tempFloorPosProvider.notifier).state = null;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${effective.id} 위치 확정 완료')),
                    );
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('확정'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;

                Offset toPixel(double fx, double fy) => Offset(fx * w, fy * h);

                return GestureDetector(
                  onTapDown: (effective == null)
                      ? null
                      : (d) {
                    final local = d.localPosition;
                    final fx = (local.dx / w).clamp(0.0, 1.0);
                    final fy = (local.dy / h).clamp(0.0, 1.0);
                    ref.read(tempFloorPosProvider.notifier).state = Offset(fx, fy);
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          selectedFloorplan.assetPath,
                          fit: BoxFit.cover,
                        ),
                      ),

                      // 저장된 핀
                      for (final d in devices)
                        if (d.fx != null && d.fy != null)
                          _Pin(
                            pos: toPixel(d.fx!, d.fy!),
                            label: d.id,
                            emphasized: effective != null && d.id == effective.id,
                          ),

                      // 임시 핀
                      if (effective != null && temp != null)
                        _TempPin(pos: toPixel(temp.dx, temp.dy)),
                    ],
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              effective == null
                  ? '왼쪽 목록에서 장비를 선택하거나, 작업 큐의 현재 장비를 처리하세요.'
                  : '평면도 클릭 → 임시 핀 → 상단 “확정”을 누르면 위치 저장 + 작업 완료됩니다.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TempPin extends StatelessWidget {
  final Offset pos;
  const _TempPin({required this.pos});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: pos.dx - 10,
      top: pos.dy - 10,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border.all(width: 2),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final Offset pos;
  final String label;
  final bool emphasized;

  const _Pin({
    required this.pos,
    required this.label,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: pos.dx - 12,
      top: pos.dy - 12,
      child: Column(
        children: [
          Container(
            width: emphasized ? 26 : 22,
            height: emphasized ? 26 : 22,
            decoration: BoxDecoration(
              border: Border.all(width: emphasized ? 3 : 2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
