import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_providers.dart';

class TaskCard extends ConsumerWidget {
  const TaskCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTaskProvider);
    final queue = ref.watch(unconfiguredQueueProvider);
    final notifier = ref.read(devicesProvider.notifier);

    if (current == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              '모든 작업 완료 🎉',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('작업 큐', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('남은 미설정: ${queue.length}대'),
            const Divider(height: 24),

            Text('현재 작업', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('ID: ${current.id}', style: Theme.of(context).textTheme.titleMedium),
            Text('IP: ${current.ip}'),
            const SizedBox(height: 16),

            FilledButton(
              onPressed: () {
                notifier.identify(current.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${current.id} Identify 요청(LED 점멸)')),
                );
              },
              child: const Text('Identify (LED 점멸)'),
            ),
            const SizedBox(height: 12),

            Text(
              '오른쪽 평면도에서 위치를 클릭한 뒤 “확정”을 누르세요.',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            const SizedBox(height: 16),
            Text(
              '다음 예정: ${queue.skip(1).take(3).map((d) => d.id).join(", ")}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
