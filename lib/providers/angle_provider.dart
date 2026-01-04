import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/angle_report.dart';
import '../services/udp_report_listener.dart';

class TagLatest {
  final AngleReport report;
  final int lastSeenMs; // local time

  const TagLatest({required this.report, required this.lastSeenMs});
}

class AngleState {
  final bool running;
  final String? error;

  /// deviceId -> (tagId -> latest)
  final Map<String, Map<String, TagLatest>> latest;

  const AngleState({
    required this.running,
    required this.latest,
    this.error,
  });

  static const empty = AngleState(running: false, latest: {});
}

final angleControllerProvider =
StateNotifierProvider<AngleController, AngleState>((ref) {
  final c = AngleController(ref);
  ref.onDispose(() => c.dispose());
  return c;
});

class AngleController extends StateNotifier<AngleState> {
  AngleController(this.ref) : super(AngleState.empty);

  final Ref ref;
  final _listener = UdpReportListener(port: 40200);
  StreamSubscription<AngleReport>? _sub;

  Future<void> start() async {
    if (state.running) return;
    try {
      await _listener.start();
      _sub = _listener.stream.listen(_onReport);
      state = AngleState(running: true, latest: state.latest, error: null);
    } catch (e) {
      state = AngleState(running: false, latest: state.latest, error: e.toString());
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _listener.stop();
    state = AngleState(running: false, latest: state.latest, error: null);
  }

  void clear() {
    state = AngleState(running: state.running, latest: {}, error: null);
  }

  void _onReport(AngleReport r) {
    final now = DateTime.now().millisecondsSinceEpoch;

    final latest = Map<String, Map<String, TagLatest>>.from(state.latest);
    final perDev = Map<String, TagLatest>.from(latest[r.deviceId] ?? {});
    perDev[r.tagId] = TagLatest(report: r, lastSeenMs: now);
    latest[r.deviceId] = perDev;

    state = AngleState(running: state.running, latest: latest, error: null);
  }

  List<TagLatest> getLatestForDevice(String deviceId) {
    final perDev = state.latest[deviceId];
    if (perDev == null) return const [];
    final list = perDev.values.toList();
    list.sort((a, b) => b.lastSeenMs.compareTo(a.lastSeenMs));
    return list;
  }

  Future<void> dispose() async {
    await stop();
    await _listener.dispose();
  }
}
