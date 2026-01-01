import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_providers.dart';

class SummaryBar extends ConsumerWidget {
  const SummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(summaryProvider);
    final count = ref.watch(deviceCountProvider);
    final notifier = ref.read(devicesProvider.notifier);

    Chip chip(String label, int value) => Chip(label: Text('$label: $value'));

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip('총', s.total),
        chip('온라인', s.online),
        chip('미설정', s.unconfigured),
        chip('오프라인', s.offline),
        chip('에러', s.error),

        const SizedBox(width: 16),

        // ✅ 장비 수 조절 UI
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('장비 수'),
            const SizedBox(width: 6),
            SizedBox(
              width: 90,
              child: TextFormField(
                initialValue: count.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (v) {
                  final n = int.tryParse(v);
                  if (n == null) return;
                  if (n <= 0 || n > 500) return;

                  ref.read(deviceCountProvider.notifier).state = n;
                  notifier.resetWithCount(n);

                  // 선택/임시 핀도 초기화(안전)
                  ref.read(selectedDeviceIdProvider.notifier).state = null;
                  ref.read(tempFloorPosProvider.notifier).state = null;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('장비 수를 $n대로 변경했습니다 (데이터 리셋)')),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
