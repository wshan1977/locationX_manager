import 'package:flutter_riverpod/flutter_riverpod.dart';

class TempPos {
  final double x;
  final double y;

  const TempPos(this.x, this.y);
}

final tempPosProvider = StateProvider<TempPos?>((ref) => null);
