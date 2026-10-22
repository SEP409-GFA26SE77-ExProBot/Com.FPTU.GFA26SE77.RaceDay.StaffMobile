import '../../../../core/errors/app_exceptions.dart';
import '../../domain/check_in_input.dart';
import '../../domain/check_in_models.dart';
import '../../domain/check_in_repository.dart';
import '../datasources/check_in_local_data_source.dart';
import '../datasources/check_in_remote_data_source.dart';

class CheckInRepositoryImpl implements CheckInRepository {
  final CheckInRemoteDataSource remote;
  final CheckInLocalDataSource local;
  CheckInRepositoryImpl({required this.remote, required this.local});

  @override
  Future<Loaded<List<StaffAssignment>>> assignments() async {
    try {
      final rows = await remote.assignments();
      await local.write('assignments', rows.map((e) => e.data).toList());
      return Loaded(rows);
    } on NetworkException {
      final cached = local.read('assignments');
      if (cached == null) rethrow;
      return Loaded(cached.map(StaffAssignment.new).toList(), offline: true);
    }
  }

  @override
  Future<Loaded<List<CheckInEntry>>> entries(String eventId) async {
    try {
      final rows = await remote.entries(eventId);
      await local.write('list_$eventId', rows.map((e) => e.data).toList());
      return Loaded(rows);
    } on NetworkException {
      final cached = local.read('list_$eventId');
      if (cached == null) rethrow;
      return Loaded(cached.map(CheckInEntry.new).toList(), offline: true);
    }
  }

  @override
  Future<CheckInResult> checkIn(CheckInInput input) async {
    try {
      final result = await remote.checkIn(input.toJson());
      await _recordResult(result);
      return result;
    } on NetworkException {
      return _queueOffline(input);
    }
  }

  Future<void> _recordResult(CheckInResult result) async {
    final key = 'list_${result.eventId}';
    final rows = local.read(key);
    if (rows != null) {
      final next = rows
          .map(
            (row) => row['registrationId'] == result.registrationId
                ? {...row, ...result.data, 'checkedIn': true}
                : row,
          )
          .toList();
      if (!next.any((e) => e['registrationId'] == result.registrationId)) {
        next.add({...result.data, 'checkedIn': true});
      }
      await local.write(key, next);
    }
    await local.savePending(
      local.pending
          .where(
            (p) =>
                p.eventId != result.eventId ||
                p.registrationId != result.registrationId,
          )
          .toList(),
    );
  }

  Future<CheckInResult> _queueOffline(CheckInInput input) async {
    final active = (local.read('assignments') ?? []).any(
      (a) => a['eventId'] == input.eventId && a['status'] == 'active',
    );
    if (!active) throw AppException('Chưa có phân công được lưu cho giải này.');
    final bib = input.offlineBib;
    if (bib == null) {
      throw AppException(
        'Mất mạng: QR cần có BIB để đối chiếu danh sách đã tải.',
      );
    }
    final rows = (local.read('list_${input.eventId}') ?? []).map(
      CheckInEntry.new,
    );
    final matches = rows.where(
      (r) => r.bibNumber.toLowerCase() == bib.toLowerCase(),
    );
    if (matches.isEmpty) {
      throw AppException(
        'Mất mạng: BIB $bib không có trong danh sách đã tải. Kết nối mạng để xác thực.',
      );
    }
    final row = matches.first;
    if (row.status != 'confirmed') {
      throw AppException('Chỉ runner đã được duyệt mới được check-in.');
    }
    final queue = local.pending;
    final existing = queue.where(
      (p) =>
          p.eventId == input.eventId && p.registrationId == row.registrationId,
    );
    if (existing.isNotEmpty && existing.first.error != null) {
      throw AppException(
        'Lượt check-in này bị máy chủ từ chối: ${existing.first.error}',
      );
    }
    final already = row.checkedIn || existing.isNotEmpty;
    final at =
        row.checkedInAt?.toUtc().toIso8601String() ??
        (existing.isNotEmpty
            ? existing.first.data['createdAtUtc']
            : DateTime.now().toUtc().toIso8601String());
    if (!already) {
      queue.add(
        PendingCheckIn({
          'eventId': input.eventId,
          'registrationId': row.registrationId,
          'bib': row.bibNumber,
          'fullName': row.fullName,
          'createdAtUtc': at,
          if (input.qrPayload != null) 'qrPayload': input.qrPayload,
        }),
      );
      await local.savePending(queue);
    }
    return CheckInResult({
      ...row.data,
      'eventId': input.eventId,
      'checkedInAtUtc': at,
      'alreadyCheckedIn': already,
      'status': row.checkedIn ? 'confirmed' : 'pending_sync',
      'fromCache': true,
    });
  }

  @override
  Future<List<PendingCheckIn>> pending() async => local.pending;

  @override
  Future<bool> synchronize(Set<String> activeEventIds) async {
    for (final item in List<PendingCheckIn>.from(local.pending)) {
      if (!activeEventIds.contains(item.eventId)) {
        await _markFailure(
          item,
          'Phân công không còn Active. Liên hệ ban tổ chức.',
        );
        continue;
      }
      try {
        // Keep original QR when replaying, so event validation is preserved.
        final result = await remote.checkIn(item.request);
        await _recordResult(result);
      } on NetworkException {
        return false;
      } on AuthException {
        rethrow;
      } on AppException catch (e) {
        await _markFailure(item, e.message);
      }
    }
    return true;
  }

  Future<void> _markFailure(PendingCheckIn item, String message) =>
      local.savePending(
        local.pending
            .map(
              (p) =>
                  p.eventId == item.eventId &&
                      p.registrationId == item.registrationId
                  ? PendingCheckIn({...p.data, 'error': message})
                  : p,
            )
            .toList(),
      );
}
