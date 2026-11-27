import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../features/check_in/domain/check_in_models.dart';
import '../../features/positioning/presentation/position_tracking.dart';
import '../../features/positioning/presentation/staff_check_in_scan_screen.dart';
import '../../features/positioning/presentation/staff_report_screen.dart';
import 'brand_logo.dart';

class WorkspaceScaffold extends StatefulWidget {
  final String title;
  final String accountName;
  final String positioningToken;
  final List<StaffAssignment> assignments;
  final String? selectedEventId;
  final ValueChanged<StaffAssignment>? onSelect;
  final VoidCallback? onRefresh;
  final VoidCallback? onLogout;
  final List<Widget> drawerNotices;
  final Widget body;

  const WorkspaceScaffold({
    super.key,
    required this.title,
    required this.accountName,
    required this.positioningToken,
    required this.body,
    required this.onLogout,
    this.assignments = const [],
    this.selectedEventId,
    this.onSelect,
    this.onRefresh,
    this.drawerNotices = const [],
  });

  @override
  State<WorkspaceScaffold> createState() => _WorkspaceScaffoldState();
}

class _WorkspaceScaffoldState extends State<WorkspaceScaffold>
    with WidgetsBindingObserver {
  late final PositionTracking _tracking;

  @override
  void initState() {
    super.initState();
    _tracking = PositionTracking(widget.positioningToken);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null) _tracking.lifecycle(lifecycle);
    _tracking.selectEvent(widget.selectedEventId);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(WorkspaceScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tracking.selectEvent(widget.selectedEventId);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      _tracking.lifecycle(state);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tracking.dispose();
    super.dispose();
  }

  StaffAssignment? get _selected => widget.assignments
      .where((assignment) => assignment.eventId == widget.selectedEventId)
      .firstOrNull;

  static String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    return date == null ? value : DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _eventHeader(BuildContext context) {
    final selected = _selected;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: AppColors.primaryLight,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            selected?.eventName ?? 'Chưa chọn giải',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (selected?.eventDate case final String date) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _formatDate(date),
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Persistent red banner while the server says this user is outside the
  /// assigned zone. It cannot be dismissed; it goes away on the next "inside".
  Widget _outsideZoneToast() => ListenableBuilder(
    listenable: _tracking,
    builder: (context, _) => !_tracking.outsideZone
        ? const SizedBox.shrink()
        : SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: AppColors.error,
                elevation: 6,
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bạn đang ở ngoài vùng hoạt động được phân công. '
                          'Hãy quay lại vùng của mình.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
  );

  /// Turning Check-in on opens the QR scanner; GPS starts only after the
  /// organizer's code is accepted.
  Future<void> _toggleCheckIn(bool enabled) async {
    if (!enabled) {
      _tracking.checkOut();
      return;
    }
    final eventId = widget.selectedEventId;
    if (eventId == null) return;
    final eventName = widget.assignments
        .where((assignment) => assignment.eventId == eventId)
        .map((assignment) => assignment.eventName)
        .firstOrNull;
    final checkedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffCheckInScanScreen(
          eventName: eventName ?? 'Check-in nhân sự',
          onCode: _tracking.checkIn,
        ),
      ),
    );
    if (checkedIn != true || !mounted) return;
    if (widget.selectedEventId != eventId) return;
    await _tracking.start();
  }

  Future<void> _openReport() async {
    if (widget.selectedEventId == null) return;
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StaffReportScreen(
          eventName: _selected?.eventName ?? 'Báo cáo sự cố',
          onSubmit: _tracking.submitReport,
        ),
      ),
    );
    if (sent != true || !mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(content: Text('Đã gửi báo cáo tới Ban tổ chức.')),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 8,
      title: Builder(
        builder: (context) => Tooltip(
          message: 'Mở menu RaceDay',
          child: TextButton(
            onPressed: Scaffold.of(context).openDrawer,
            child: const BrandLogo(),
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: widget.onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    drawer: Drawer(
      child: SafeArea(
        child: Builder(
          builder: (context) => Column(
            children: [
              _eventHeader(context),
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: Text(_selected?.roleLabel ?? widget.title),
                subtitle: Text(widget.accountName),
              ),
              ListenableBuilder(
                listenable: _tracking,
                builder: (context, _) => SwitchListTile(
                  secondary: const Icon(Icons.my_location),
                  title: const Text('Check-in'),
                  subtitle: Text(
                    widget.selectedEventId == null
                        ? 'Chọn giải để gửi vị trí.'
                        : _tracking.status ??
                              (_tracking.requesting
                                  ? 'Đang xin quyền vị trí…'
                                  : _tracking.enabled
                                  ? 'Đang lấy vị trí GPS…'
                                  : 'Quét QR của BTC để check-in và chia sẻ vị trí.'),
                  ),
                  value: _tracking.enabled,
                  onChanged:
                      widget.selectedEventId == null || _tracking.requesting
                      ? null
                      : (enabled) => _toggleCheckIn(enabled),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.report_outlined),
                title: const Text('Báo cáo'),
                subtitle: const Text('Gửi sự cố tới Ban tổ chức.'),
                enabled: widget.selectedEventId != null,
                onTap: () {
                  Scaffold.of(context).closeDrawer();
                  _openReport();
                },
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    for (final assignment in widget.assignments)
                      ListTile(
                        leading: const Icon(Icons.event_outlined),
                        title: Text(assignment.eventName),
                        subtitle: assignment.eventDate == null
                            ? null
                            : Text(assignment.eventDate!),
                        selected: assignment.eventId == widget.selectedEventId,
                        onTap: widget.onSelect == null
                            ? null
                            : () {
                                Scaffold.of(context).closeDrawer();
                                if (assignment.eventId !=
                                    widget.selectedEventId) {
                                  widget.onSelect!(assignment);
                                }
                              },
                      ),
                    ...widget.drawerNotices,
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Đăng xuất'),
                onTap: widget.onLogout == null
                    ? null
                    : () {
                        Scaffold.of(context).closeDrawer();
                        widget.onLogout!();
                      },
              ),
            ],
          ),
        ),
      ),
    ),
    body: Stack(
      children: [
        Positioned.fill(child: widget.body),
        Positioned(top: 0, left: 0, right: 0, child: _outsideZoneToast()),
      ],
    ),
  );
}
