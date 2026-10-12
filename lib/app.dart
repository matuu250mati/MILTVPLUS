import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';

class MiltvPlusApp extends StatelessWidget {
  const MiltvPlusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MILTV PLUS',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AppShell(),
      );
}
