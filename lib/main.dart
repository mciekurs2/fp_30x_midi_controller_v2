import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'router.dart';
import 'ui/core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: Fp30xMidiControllerApp()));
}

class Fp30xMidiControllerApp extends StatelessWidget {
  const Fp30xMidiControllerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: router,
    theme: appTheme(),
    builder: withTextScale,
  );
}
