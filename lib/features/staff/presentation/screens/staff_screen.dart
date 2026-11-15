import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/status_panel.dart';
import '../../../../shared/widgets/workspace_scaffold.dart';
import '../../../authentication/data/repositories/auth_repository_impl.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/presentation/screens/login_screen.dart';
import '../../../check_in/data/datasources/check_in_local_data_source.dart';
import '../../../check_in/data/datasources/check_in_remote_data_source.dart';
import '../../../check_in/data/repositories/check_in_repository_impl.dart';
import '../../../check_in/domain/check_in_repository.dart';
import '../../../check_in/presentation/controller/check_in_controller.dart';
import '../../../check_in/presentation/screens/check_in_screen.dart';

class StaffScreen extends StatefulWidget {
  final UserEntity user;
  final CheckInRepository? repository;

  const StaffScreen({super.key, required this.user, this.repository});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> with WidgetsBindingObserver {
  CheckInController? _controller;
  Timer? _timer;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final repository =
          widget.repository ??
          CheckInRepositoryImpl(
            remote: CheckInRemoteDataSource(),
            local: CheckInLocalDataSource(
              await SharedPreferences.getInstance(),
              widget.user.id!,
            ),
          );
      if (!mounted) return;
      final controller = CheckInController(repository);
      setState(() => _controller = controller);
      await controller.refresh();
      if (!mounted) return;
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed &&
            controller.pending.isNotEmpty) {
          controller.refresh();
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _startupError =
              'Không thể khởi tạo dữ liệu. Vui lòng đăng nhập lại.',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _controller?.refresh();
  }

  Future<void> _logout() async {
    if (_controller?.busy ?? false) return;
    final count = _controller?.pending.length ?? 0;
    if (count > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Còn lượt chờ đồng bộ'),
          content: Text(
            '$count lượt vẫn được giữ trên máy và chỉ đồng bộ khi đăng nhập lại đúng tài khoản này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ở lại'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đăng xuất'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    _timer?.cancel();
    await AuthRepositoryImpl().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountName = widget.user.fullName ?? widget.user.username;
    final controller = _controller;
    if (controller == null) {
      return WorkspaceScaffold(
        title: 'Staff',
        accountName: accountName,
        positioningToken: widget.user.token,
        onLogout: _logout,
        body: Center(
          child: _startupError == null
              ? const CircularProgressIndicator()
              : Text(_startupError!),
        ),
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final selected = controller.selected;
        return WorkspaceScaffold(
          title: 'Staff',
          accountName: accountName,
          positioningToken: widget.user.token,
          assignments: controller.assignments,
          selectedEventId: selected?.eventId,
          onRefresh: controller.busy ? null : controller.refresh,
          onSelect: controller.busy ? null : controller.select,
          onLogout: controller.busy ? null : _logout,
          drawerNotices: [
            if (controller.pending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: StatusPanel(
                  message:
                      '${controller.pending.length} lượt chưa được máy chủ xác nhận. Tự đồng bộ khi kết nối lại.',
                  icon: Icons.cloud_upload_outlined,
                  action: TextButton(
                    onPressed: controller.busy ? null : controller.refresh,
                    child: const Text('Đồng bộ ngay'),
                  ),
                ),
              ),
            for (final pending in controller.pending)
              if (pending.error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: StatusPanel(
                    color: AppColors.error,
                    message:
                        'BIB ${pending.bib} · ${pending.fullName}\n${pending.error}',
                  ),
                ),
          ],
          body: selected == null
              ? ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Text(
                      'Check-in runner',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (controller.busy)
                      const LinearProgressIndicator()
                    else if (_startupError != null || controller.error != null)
                      StatusPanel(
                        message: _startupError ?? controller.error!,
                        color: AppColors.error,
                      )
                    else
                      const StatusPanel(
                        message:
                            'Chưa có phân công Staff. Liên hệ ban tổ chức để được phân công check-in.',
                        icon: Icons.assignment_ind_outlined,
                      ),
                  ],
                )
              : CheckInScreen(
                  key: ValueKey(selected.eventId),
                  controller: controller,
                ),
        );
      },
    );
  }
}
