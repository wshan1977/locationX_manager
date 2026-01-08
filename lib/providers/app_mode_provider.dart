import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppMode { installer, engineer }

final appModeProvider = StateProvider<AppMode>((ref) => AppMode.installer);
