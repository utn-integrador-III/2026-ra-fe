import 'package:flutter/material.dart';

import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/home/screens/home_screen.dart';
import 'features/navigation/screens/navigation_screen.dart';
import 'features/settings/screens/settings_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppRoutes.appTitle,
      theme: AppTheme.theme,
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.navigation: (_) => const NavigationScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
      },
    );
  }
}
