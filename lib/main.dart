import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui/dashboard.dart';

void main() {
  runApp(const ProviderScope(child: App()));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true);

    ThemeData makeTheme(Brightness brightness) {
      final cs = ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F7DFF),
        brightness: brightness,
      );
      return base.copyWith(
        brightness: brightness,
        colorScheme: cs,
        scaffoldBackgroundColor: cs.surface,
        visualDensity: VisualDensity.standard,
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: cs.surfaceContainerHighest.withOpacity(0.55),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.4)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.outlineVariant.withOpacity(0.35)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: cs.primary.withOpacity(0.75), width: 1.4),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        dividerTheme: DividerThemeData(color: cs.outlineVariant.withOpacity(0.35), thickness: 1),
      );
    }

    return MaterialApp(
      title: "LocationX Windows",
      debugShowCheckedModeBanner: false,
      theme: makeTheme(Brightness.light),
      darkTheme: makeTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const Dashboard(),
    );
  }
}
