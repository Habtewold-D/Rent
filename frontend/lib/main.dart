import 'package:flutter/material.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/auth/register_page.dart';
import 'core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'presentation/viewmodels/auth_view_model.dart';
import 'data/repositories/auth_repository_impl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RentApp());
}

// Global route observer for RouteAware pages (e.g., to auto-refresh on return)
final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class RentApp extends StatelessWidget {
  const RentApp({super.key});

  @override
  Widget build(BuildContext context) {
    final navKey = GlobalKey<NavigatorState>();
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel(AuthRepositoryImpl()),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Rent',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        navigatorKey: navKey,
        initialRoute: '/',
        routes: {
          '/': (context) => const LoginPage(),
        },
        onGenerateInitialRoutes: (String initialRouteName) {
          // Guarantee at least one route on the stack
          return [
            MaterialPageRoute(builder: (_) => const LoginPage()),
          ];
        },
        onGenerateRoute: (settings) {
          // Fallback: if an unknown route or empty state occurs, go to LoginPage
          return MaterialPageRoute(builder: (_) => const LoginPage());
        },
        navigatorObservers: [routeObserver],
      ),
    );
  }
}
