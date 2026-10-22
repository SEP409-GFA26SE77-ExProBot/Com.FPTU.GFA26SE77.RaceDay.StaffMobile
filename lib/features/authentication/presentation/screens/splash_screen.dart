import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../home/presentation/screens/home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final user = await AuthRepositoryImpl().getSavedUser();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            user == null ? const LoginScreen() : HomeScreen(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandLogo(iconSize: 36, fontSize: 32),
          SizedBox(height: 24),
          Text('RaceDay Staff · Đồng hành cùng runner'),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    ),
  );
}
