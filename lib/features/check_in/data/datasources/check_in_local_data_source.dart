import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../domain/check_in_models.dart';

class CheckInLocalDataSource {
  final SharedPreferences preferences;
  final String userId;
  CheckInLocalDataSource(this.preferences, this.userId);
  String _key(String suffix) =>
      'raceday_staff_ci_${Uri.encodeComponent(userId)}_$suffix';

  List<Json>? read(String suffix) {
    final raw = preferences.getString(_key(suffix));
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String suffix, List<Json> data) async {
    if (!await preferences.setString(_key(suffix), jsonEncode(data))) {
      throw AppException(
        'Không thể lưu dữ liệu trên máy. Vui lòng kiểm tra bộ nhớ.',
      );
    }
  }

  List<PendingCheckIn> get pending =>
      (read('queue') ?? []).map(PendingCheckIn.new).toList();
  Future<void> savePending(List<PendingCheckIn> items) =>
      write('queue', items.map((e) => e.data).toList());
}
