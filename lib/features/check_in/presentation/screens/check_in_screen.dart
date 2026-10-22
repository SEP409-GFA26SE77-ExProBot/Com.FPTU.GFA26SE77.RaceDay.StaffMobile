import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/status_panel.dart';
import '../../domain/check_in_models.dart';
import '../controller/check_in_controller.dart';
import 'qr_scanner_screen.dart';

enum EntryFilter { all, checkedIn, waiting, pending }

class CheckInScreen extends StatefulWidget {
  final CheckInController controller;
  const CheckInScreen({super.key, required this.controller});
  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _bib = TextEditingController();
  final _search = TextEditingController();
  EntryFilter _filter = EntryFilter.all;
  bool _scanning = false;
  CheckInController get c => widget.controller;

  @override
  void dispose() {
    _bib.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final assignment = c.selected;
    if (assignment == null || c.busy || _scanning) return;
    setState(() => _scanning = true);
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(eventName: assignment.eventName),
      ),
    );
    if (!mounted) return;
    // A camera permission dialog can trigger a concurrent resume refresh.
    while (c.busy && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    if (raw != null && c.selected?.eventId == assignment.eventId) {
      await c.submit(raw, fromQr: true);
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _manual() async {
    FocusScope.of(context).unfocus();
    final result = await c.submit(_bib.text, fromQr: false);
    if (mounted && result != null) _bib.clear();
  }

  String _time(DateTime? date) => date == null
      ? '—'
      : DateFormat('HH:mm · dd/MM/yyyy').format(date.toLocal());

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final assignment = c.selected;
      final pending = c.pending
          .where((p) => p.eventId == assignment?.eventId)
          .toList();
      final byId = {for (final p in pending) p.registrationId: p};
      final confirmed = c.entries.where((e) => e.checkedIn).length;
      final query = _search.text.trim().toLowerCase();
      final entries = c.entries.where((row) {
        final queued = byId[row.registrationId];
        final matchesFilter = switch (_filter) {
          EntryFilter.all => true,
          EntryFilter.checkedIn => row.checkedIn,
          EntryFilter.waiting => !row.checkedIn && queued == null,
          EntryFilter.pending => queued != null,
        };
        return matchesFilter &&
            ('${row.fullName} ${row.bibNumber}'.toLowerCase().contains(query));
      }).toList();
      final enabled = assignment != null && !c.busy && !_scanning;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Check-in runner'),
          actions: [
            IconButton(
              tooltip: 'Làm mới và đồng bộ',
              onPressed: c.busy ? null : c.refresh,
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: c.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                assignment?.eventName ?? 'Phân công không còn khả dụng',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (assignment != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${assignment.roleLabel} · ${assignment.stationLabel ?? 'Chưa gán quầy / trạm'}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _stat(
                      'Đã xác nhận',
                      '$confirmed',
                      AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _stat(
                      'Chưa check-in',
                      '${c.entries.where((e) => !e.checkedIn && !byId.containsKey(e.registrationId)).length}',
                      AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _stat(
                      'Chờ đồng bộ',
                      '${pending.length}',
                      AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (c.busy)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: LinearProgressIndicator(),
                ),
              if (c.offline)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: StatusPanel(
                    message:
                        'Mất kết nối. Chỉ đối chiếu được runner trong danh sách đã tải; lượt mới sẽ chờ máy chủ xác nhận.',
                    icon: Icons.wifi_off,
                  ),
                ),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: StatusPanel(
                    message: c.error!,
                    color: AppColors.error,
                    icon: Icons.error_outline,
                  ),
                ),
              if (c.lastResult != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _result(c.lastResult!),
                ),
              SizedBox(
                height: 64,
                child: FilledButton.icon(
                  onPressed: enabled ? _scan : null,
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text(
                    'Quét QR vé runner',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hoặc nhập BIB khi QR không đọc được.',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bib,
                      enabled: enabled,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _manual(),
                      decoration: const InputDecoration(
                        labelText: 'Số BIB',
                        hintText: 'Ví dụ: 000123',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: enabled ? _manual : null,
                      child: const Text('Check-in'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Danh sách runner (${c.entries.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Tìm theo tên hoặc BIB',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final filter in EntryFilter.values)
                    ChoiceChip(
                      label: Text(switch (filter) {
                        EntryFilter.all => 'Tất cả',
                        EntryFilter.checkedIn => 'Đã check-in',
                        EntryFilter.waiting => 'Chưa check-in',
                        EntryFilter.pending => 'Chờ đồng bộ',
                      }),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (!c.busy && entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Không có runner phù hợp.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ...entries.map((row) => _entry(row, byId[row.registrationId])),
            ],
          ),
        ),
      );
    },
  );

  Widget _stat(String title, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    ),
  );

  Widget _result(CheckInResult result) => StatusPanel(
    color: result.pendingSync ? AppColors.primary : AppColors.success,
    icon: result.pendingSync
        ? Icons.cloud_upload_outlined
        : Icons.check_circle_outline,
    message:
        '${result.pendingSync
            ? (result.alreadyCheckedIn ? 'Đã lưu trước đó · chờ đồng bộ' : 'Đã lưu trên máy · chờ đồng bộ')
            : result.alreadyCheckedIn
            ? 'Đã check-in trước đó'
            : 'Check-in thành công'}\n'
        'BIB ${result.bibNumber} · ${result.fullName}\n'
        '${result.distanceLabel}\n${_time(result.checkedInAt)}',
  );

  Widget _entry(CheckInEntry row, PendingCheckIn? pending) {
    final color = pending?.error != null
        ? AppColors.error
        : row.checkedIn
        ? AppColors.success
        : pending != null
        ? AppColors.primary
        : AppColors.textMuted;
    final label = pending?.error != null
        ? 'Đồng bộ bị từ chối'
        : row.checkedIn
        ? 'Đã check-in'
        : pending != null
        ? 'Chờ đồng bộ'
        : 'Chưa check-in';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BIB ${row.bibNumber}',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              row.fullName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              row.distanceLabel,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
            if (row.checkedInAt != null)
              Text(
                _time(row.checkedInAt),
                style: const TextStyle(fontSize: 12),
              ),
            if (pending?.error != null)
              Text(
                pending!.error!,
                style: const TextStyle(color: AppColors.error),
              ),
          ],
        ),
      ),
    );
  }
}
