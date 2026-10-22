import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'features/authentication/data/datasources/auth_local_data_source.dart';
import 'features/authentication/presentation/screens/login_screen.dart';
import 'features/authentication/presentation/screens/splash_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();
bool _handlingExpiredSession = false;

Future<void> _sessionExpired() async {
  if (_handlingExpiredSession) return;
  _handlingExpiredSession = true;
  try {
    await AuthLocalDataSourceImpl().clearUserSession();
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    messengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
      ),
    );
  } finally {
    _handlingExpiredSession = false;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  ApiClient.onSessionExpired = _sessionExpired;
  runApp(const StaffMobileApp());
}

class StaffMobileApp extends StatelessWidget {
  const StaffMobileApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigatorKey,
    scaffoldMessengerKey: messengerKey,
    title: 'RaceDay Staff',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: const SplashScreen(),
  );
}
