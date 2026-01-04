import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/devices_provider.dart';
import '../providers/floorplan_provider.dart';

class FloorplanPanel extends ConsumerWidget {
  const FloorplanPanel({
    super.key,
    this.mapWidthM = 20.0,
    this.mapHeightM = 10.0,
  });

  final double mapWidthM;
  final double mapHeightM;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temp = ref.watch(tempPosProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("평면도(데모)", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text("클릭하면 임시 좌표가 찍힙니다. (가로 ${mapWidthM}m × 세로 ${mapHeightM}m)"),
            const SizedBox(height: 12),

            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) {
                      final w = c.maxWidth;
                      final h = c.maxHeight;
                      final px = d.localPosition.dx.clamp(0, w);
                      final py = d.localPosition.dy.clamp(0, h);

                      final x = (px / w) * mapWidthM;
                      final y = (py / h) * mapHeightM;

                      ref.read(tempPosProvider.notifier).state = TempPos(x, y);
                    },
                    child: CustomPaint(
                      painter: _GridPainter(),
                      child: Stack(
                        children: [
                          if (temp != null)
                            Positioned(
                              left: (temp.x / mapWidthM) * c.maxWidth - 6,
                              top: (temp.y / mapHeightM) * c.maxHeight - 6,
                              child: _Pin(),
                            ),
                          if (temp != null)
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.black12),
                                ),
                                child: Text("임시 좌표: x=${temp.x.toStringAsFixed(2)}m, y=${temp.y.toStringAsFixed(2)}m"),
                              ),
                            ),
                        ],
                      ),
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

class _Pin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary,
        boxShadow: const [BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Colors.black26)],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 테두리
    paint.color = Colors.black12;
    canvas.drawRect(Offset.zero & size, paint);

    // 그리드
    paint.color = Colors.black12.withOpacity(0.6);
    const step = 40.0;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
