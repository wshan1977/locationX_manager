import 'package:flutter/material.dart';

class ResizableRow3 extends StatefulWidget {
  final Widget left;
  final Widget middle;
  final Widget right;

  final double initialMiddleWidth;
  final double initialRightWidth;

  final double minMiddleWidth;
  final double maxMiddleWidth;

  final double minRightWidth;
  final double maxRightWidth;

  const ResizableRow3({
    super.key,
    required this.left,
    required this.middle,
    required this.right,
    this.initialMiddleWidth = 420,
    this.initialRightWidth = 460,
    this.minMiddleWidth = 320,
    this.maxMiddleWidth = 900,
    this.minRightWidth = 340,
    this.maxRightWidth = 1000,
  });

  @override
  State<ResizableRow3> createState() => _ResizableRow3State();
}

class _ResizableRow3State extends State<ResizableRow3> {
  late double _midW;
  late double _rightW;

  @override
  void initState() {
    super.initState();
    _midW = widget.initialMiddleWidth;
    _rightW = widget.initialRightWidth;
  }

  Widget _divider({required VoidCallback onDragStart, required ValueChanged<double> onDragUpdate}) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => onDragStart(),
        onHorizontalDragUpdate: (d) => onDragUpdate(d.delta.dx),
        child: Container(
          width: 10,
          alignment: Alignment.center,
          child: Container(
            width: 2,
            height: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // 전체 폭에서 좌/중/우 + divider 2개(각 10px) 고려
      final totalW = c.maxWidth;
      const divW = 10.0;
      final available = totalW - divW * 2;

      // clamp
      final midW = _midW.clamp(widget.minMiddleWidth, widget.maxMiddleWidth);
      final rightW = _rightW.clamp(widget.minRightWidth, widget.maxRightWidth);

      // left는 나머지
      final leftW = (available - midW - rightW);

      // 화면이 너무 좁으면 right/mid를 줄여서 leftW가 최소 200은 되게
      double finalMidW = midW;
      double finalRightW = rightW;
      double finalLeftW = leftW;

      if (finalLeftW < 200) {
        final deficit = 200 - finalLeftW;
        // 우측부터 줄이고, 부족하면 중간도 줄임
        final reduceRight = deficit.clamp(0, finalRightW - widget.minRightWidth);
        finalRightW -= reduceRight;
        finalLeftW += reduceRight;

        final remain = 200 - finalLeftW;
        if (remain > 0) {
          final reduceMid = remain.clamp(0, finalMidW - widget.minMiddleWidth);
          finalMidW -= reduceMid;
          finalLeftW += reduceMid;
        }
      }

      return Row(
        children: [
          SizedBox(width: finalLeftW, child: widget.left),

          _divider(
            onDragStart: () {},
            onDragUpdate: (dx) {
              setState(() {
                _midW = (_midW - dx).clamp(widget.minMiddleWidth, widget.maxMiddleWidth);
              });
            },
          ),

          SizedBox(width: finalMidW, child: widget.middle),

          _divider(
            onDragStart: () {},
            onDragUpdate: (dx) {
              setState(() {
                _rightW = (_rightW + dx).clamp(widget.minRightWidth, widget.maxRightWidth);
              });
            },
          ),

          SizedBox(width: finalRightW, child: widget.right),
        ],
      );
    });
  }
}
