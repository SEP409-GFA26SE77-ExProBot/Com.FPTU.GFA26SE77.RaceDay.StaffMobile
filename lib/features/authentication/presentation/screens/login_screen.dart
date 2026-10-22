import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../controller/auth_controller.dart';
import '../../../home/presentation/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _controller = AuthController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  Future<void> _login() async {
    if (_controller.isLoading) return;
    FocusScope.of(context).unfocus();
    if (await _controller.login(_username.text, _password.text) && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(user: _controller.currentUser!),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandLogo(iconSize: 28, fontSize: 26),
                    const SizedBox(height: 40),
                    const Text(
                      'Sẵn sàng đón runner',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Đăng nhập tài khoản được ban tổ chức phân công để check-in tại giải.',
                      style: TextStyle(color: AppColors.textMuted, height: 1.5),
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: _username,
                      enabled: !_controller.isLoading,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tên đăng nhập hoặc email',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      enabled: !_controller.isLoading,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    if (_controller.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          _controller.errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: 'Đăng nhập',
                      onPressed: _login,
                      isLoading: _controller.isLoading,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Chưa có tài khoản hoặc quên mật khẩu? Liên hệ ban tổ chức để được hỗ trợ.',
                      style: TextStyle(color: AppColors.textMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
