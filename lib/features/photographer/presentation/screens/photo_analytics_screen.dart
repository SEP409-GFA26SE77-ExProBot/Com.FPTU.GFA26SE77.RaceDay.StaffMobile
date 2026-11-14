import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../shared/widgets/status_panel.dart';
import '../../../../shared/widgets/workspace_scaffold.dart';
import '../../../authentication/data/repositories/auth_repository_impl.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/presentation/screens/login_screen.dart';
import '../../../check_in/domain/check_in_models.dart';
import '../../data/datasources/photo_analytics_remote_data_source.dart';
import '../../domain/photo_analytics.dart';

class PhotoAnalyticsScreen extends StatefulWidget {
  final UserEntity user;
  final PhotoAnalyticsRemoteDataSource remote;

  const PhotoAnalyticsScreen({
    super.key,
    required this.user,
    required this.remote,
  });

  @override
  State<PhotoAnalyticsScreen> createState() => _PhotoAnalyticsScreenState();
}

class _PhotoAnalyticsScreenState extends State<PhotoAnalyticsScreen> {
  List<StaffAssignment> _assignments = [];
  StaffAssignment? _selected;
  PhotoAnalytics? _stats;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({StaffAssignment? selection}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _stats = null;
      if (selection != null) _selected = selection;
    });
    try {
      if (selection == null) {
        final assignments = await widget.remote.assignments();
        if (!mounted) return;
        final selectedId = _selected?.eventId;
        setState(() {
          _assignments = assignments;
          _selected = assignments.isEmpty
              ? null
              : assignments.firstWhere(
                  (assignment) => assignment.eventId == selectedId,
                  orElse: () => assignments.first,
                );
        });
      }
      final eventId = _selected?.eventId;
      if (eventId != null) _stats = await widget.remote.load(eventId);
    } catch (error) {
      _error = error is AppException
          ? error.message
          : 'Không tải được thống kê ảnh.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await AuthRepositoryImpl().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final selected = _selected;
    return WorkspaceScaffold(
      title: 'Photographer',
      accountName: widget.user.fullName ?? widget.user.username,
      positioningToken: widget.user.token,
      assignments: _assignments,
      selectedEventId: selected?.eventId,
      onRefresh: _loading ? null : _load,
      onSelect: _loading ? null : (assignment) => _load(selection: assignment),
      onLogout: _logout,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Thống kê ảnh',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Text(
              selected.eventName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const LinearProgressIndicator()
          else if (_error != null)
            StatusPanel(
              message: _error!,
              color: AppColors.error,
              icon: Icons.error_outline,
              action: TextButton(
                onPressed: _load,
                child: const Text('Thử lại'),
              ),
            )
          else if (selected == null)
            const StatusPanel(
              message:
                  'Chưa có phân công Photographer. Liên hệ ban tổ chức để được phân công chụp ảnh.',
              icon: Icons.photo_camera_outlined,
            )
          else if (stats != null) ...[
            _StatsCard(
              title: 'Ảnh của giải',
              rows: [
                ('Tổng số ảnh', '${stats.total}'),
                for (final bucket in PhotoBucket.values)
                  (bucket.label, '${stats.count(bucket)}'),
              ],
            ),
            const SizedBox(height: 12),
            _StatsCard(
              title: 'Chất lượng OCR (ước lượng)',
              rows: [
                ('Số ảnh đã xử lý', '${stats.processed}'),
                for (final bucket in [
                  PhotoBucket.matched,
                  PhotoBucket.review,
                  PhotoBucket.discarded,
                ])
                  (
                    bucket.label,
                    '${stats.ocrRate(bucket).toStringAsFixed(1)}%',
                  ),
                (
                  'Độ chính xác ước tính',
                  '${stats.estimatedPrecision.toStringAsFixed(1)}%',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _StatsCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  const SizedBox(width: 12),
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
