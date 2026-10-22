import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/brand_logo.dart';
import '../../../../shared/widgets/status_panel.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/data/repositories/auth_repository_impl.dart';
import '../../../authentication/presentation/screens/login_screen.dart';
import '../../../check_in/data/datasources/check_in_local_data_source.dart';
import '../../../check_in/data/datasources/check_in_remote_data_source.dart';
import '../../../check_in/data/repositories/check_in_repository_impl.dart';
import '../../../check_in/domain/check_in_repository.dart';
import '../../../check_in/presentation/controller/check_in_controller.dart';
import '../../../check_in/presentation/screens/check_in_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserEntity user;
  final CheckInRepository? repository;
  const HomeScreen({super.key, required this.user, this.repository});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
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
      if (confirmed != true) return;
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
    final controller = _controller;
    if (controller == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('RaceDay Staff'),
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'Đăng xuất',
            ),
          ],
        ),
        body: Center(
          child: _startupError == null
              ? const CircularProgressIndicator()
              : Text(_startupError!),
        ),
      );
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const BrandLogo(),
          actions: [
            IconButton(
              tooltip: 'Làm mới phân công',
              onPressed: controller.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: controller.busy ? null : _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Xin chào, ${widget.user.fullName ?? widget.user.username}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              const Text(
                'Giải được phân công',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Chọn giải để đón runner và check-in vé QR.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              if (controller.busy) const LinearProgressIndicator(),
              if (controller.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StatusPanel(
                    message: controller.error!,
                    color: AppColors.error,
                  ),
                ),
              if (controller.offline)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: StatusPanel(
                    message:
                        'Mất kết nối máy chủ. Đang dùng phân công và danh sách đã lưu.',
                    icon: Icons.wifi_off,
                  ),
                ),
              if (controller.pending.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
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
              ...controller.pending
                  .where((p) => p.error != null)
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StatusPanel(
                        color: AppColors.error,
                        message: 'BIB ${p.bib} · ${p.fullName}\n${p.error}',
                      ),
                    ),
                  ),
              if (controller.initialized &&
                  !controller.busy &&
                  controller.assignments.isEmpty)
                const StatusPanel(
                  message:
                      'Chưa có giải được phân công. Nhờ ban tổ chức thêm tài khoản vào nhân sự của giải và kích hoạt trạng thái Active.',
                  icon: Icons.assignment_ind_outlined,
                  color: AppColors.textMuted,
                ),
              ...controller.assignments.map(
                (assignment) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: controller.busy
                          ? null
                          : () {
                              controller.select(assignment);
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CheckInScreen(controller: controller),
                                ),
                              );
                            },
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.event_available,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    assignment.eventName,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              assignment.roleLabel,
                              style: const TextStyle(color: AppColors.primary),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              assignment.stationLabel ?? 'Chưa gán quầy / trạm',
                            ),
                            if (assignment.eventDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(assignment.eventDate!),
                              ),
                            const SizedBox(height: 16),
                            const Text(
                              'Mở check-in →',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
