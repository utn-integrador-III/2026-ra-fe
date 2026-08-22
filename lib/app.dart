import 'package:flutter/material.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'pages/navigation_screen.dart';
import 'pages/settings_screen.dart';
import 'features/auth/screens/auth_tabs_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/search/screens/search_screen.dart';
import 'features/history/screens/navigation_history_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppRoutes.appTitle,
      theme: AppTheme.theme,
      initialRoute: AppRoutes.register,
      routes: {
        AppRoutes.register: (_) => const AuthTabsScreen(initialIndex: 0),
        AppRoutes.login:    (_) => const AuthTabsScreen(initialIndex: 1),
        AppRoutes.home:     (_) => const ProfileScreen(),
        AppRoutes.navigation: (_) => const NavigationScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.search: (_) => const SearchScreen(),
        AppRoutes.navigationHistory: (_) => const NavigationHistoryScreen(),
      },
    );
  }
}
