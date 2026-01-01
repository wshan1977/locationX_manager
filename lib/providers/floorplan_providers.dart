import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/floorplan.dart';

final floorplansProvider = Provider<List<Floorplan>>((ref) {
  return const [
    Floorplan(id: 'fp1', name: '1F 도면', assetPath: 'assets/floorplan_1.png'),
    Floorplan(id: 'fp2', name: '2F 도면', assetPath: 'assets/floorplan_2.png'),
  ];
});

final selectedFloorplanIdProvider = StateProvider<String>((ref) => 'fp1');

final selectedFloorplanProvider = Provider<Floorplan>((ref) {
  final list = ref.watch(floorplansProvider);
  final id = ref.watch(selectedFloorplanIdProvider);
  return list.firstWhere((e) => e.id == id);
});
