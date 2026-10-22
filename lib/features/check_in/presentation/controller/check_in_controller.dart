import 'package:flutter/foundation.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/check_in_input.dart';
import '../../domain/check_in_models.dart';
import '../../domain/check_in_repository.dart';

class CheckInController extends ChangeNotifier {
  final CheckInRepository repository;
  CheckInController(this.repository);
  List<StaffAssignment> assignments = [];
  List<CheckInEntry> entries = [];
  List<PendingCheckIn> pending = [];
  StaffAssignment? selected;
  CheckInResult? lastResult;
  String? error;
  bool busy = false;
  bool offline = false;
  bool initialized = false;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refresh() async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final loaded = await repository.assignments();
      if (_disposed) return;
      assignments = loaded.value;
      offline = loaded.offline;
      final selectedId = selected?.eventId;
      if (selectedId != null) {
        final matches = assignments.where((a) => a.eventId == selectedId);
        selected = matches.isEmpty ? null : matches.first;
        if (selected == null) {
          entries = [];
          lastResult = null;
          error = 'Bạn không còn được phân công tại giải này.';
        }
      }
      if (!offline) {
        offline = !await repository.synchronize(
          assignments.map((a) => a.eventId).toSet(),
        );
      }
      if (selected != null) await _loadEntries();
    } catch (e) {
      error = e.toString();
      // Do not keep an operable event context after authorization/load failures.
      if (e is! NetworkException) {
        selected = null;
        entries = [];
      }
    } finally {
      if (!_disposed) {
        pending = await repository.pending();
        final last = lastResult;
        if (last != null &&
            last.pendingSync &&
            !pending.any(
              (p) =>
                  p.eventId == last.eventId &&
                  p.registrationId == last.registrationId,
            )) {
          final matches = entries.where(
            (e) => e.registrationId == last.registrationId && e.checkedIn,
          );
          if (matches.isNotEmpty) {
            lastResult = CheckInResult({
              ...matches.first.data,
              'eventId': last.eventId,
              'alreadyCheckedIn': false,
            });
          }
        }
        initialized = true;
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(StaffAssignment assignment) async {
    if (busy || _disposed) return;
    selected = assignment;
    entries = [];
    lastResult = null;
    error = null;
    busy = true;
    notifyListeners();
    try {
      await _loadEntries();
      pending = await repository.pending();
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _loadEntries() async {
    final loaded = await repository.entries(selected!.eventId);
    if (_disposed) return;
    entries = loaded.value;
    offline = offline || loaded.offline;
  }

  Future<CheckInResult?> submit(String value, {required bool fromQr}) async {
    if (busy || selected == null || _disposed) return null;
    busy = true;
    error = null;
    lastResult = null;
    notifyListeners();
    try {
      final eventId = selected!.eventId;
      final input = fromQr
          ? CheckInInput.qr(eventId, value)
          : CheckInInput.manual(eventId, value);
      final result = await repository.checkIn(input);
      if (_disposed) return null;
      lastResult = result;
      offline = result.fromCache;
      pending = await repository.pending();
      if (!result.pendingSync) {
        // Reflect the committed result even if refreshing the full list fails later.
        final updated = CheckInEntry({...result.data, 'checkedIn': true});
        entries = [
          updated,
          ...entries.where((e) => e.registrationId != result.registrationId),
        ];
      }
      return result;
    } catch (e) {
      error = e.toString();
      return null;
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
