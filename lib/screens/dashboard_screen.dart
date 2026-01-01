import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/summary_bar.dart';
import '../widgets/task_card.dart';
import '../widgets/device_list.dart';
import '../widgets/floorplan_view.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('LocationX Manager')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SummaryBar(),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 1100;

                  if (isNarrow) {
                    // ✅ 좁은 화면: 세로 배치(확정 버튼 보이게)
                    return Column(
                      children: const [
                        SizedBox(height: 420, child: TaskCard()),
                        SizedBox(height: 12),
                        SizedBox(height: 360, child: DeviceList()),
                        SizedBox(height: 12),
                        Expanded(child: FloorplanView()),
                      ],
                    );
                  }

                  // ✅ 넓은 화면: 기존대로 좌우 배치
                  return Row(
                    children: const [
                      SizedBox(
                        width: 380,
                        child: Column(
                          children: [
                            Expanded(flex: 5, child: TaskCard()),
                            SizedBox(height: 12),
                            Expanded(flex: 5, child: DeviceList()),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(child: FloorplanView()),
                    ],
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
