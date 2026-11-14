import 'package:flutter/material.dart';
import '../../features/check_in/domain/check_in_models.dart';
import '../../features/positioning/presentation/position_tracking.dart';
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
    _tracking = PositionTracking(
      widget.positioningToken,
      onAlert: (message) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(message)));
      },
    );
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
              ListTile(
                title: Text(widget.title),
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
                                  : 'Chia sẻ vị trí khi đang mở ứng dụng.'),
                  ),
                  value: _tracking.enabled,
                  onChanged:
                      widget.selectedEventId == null || _tracking.requesting
                      ? null
                      : (enabled) =>
                            enabled ? _tracking.start() : _tracking.stop(),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    if (widget.assignments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                        child: Text(
                          'Chọn giải',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
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
    body: widget.body,
  );
}
