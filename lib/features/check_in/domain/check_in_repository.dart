import 'check_in_input.dart';
import 'check_in_models.dart';

abstract class CheckInRepository {
  Future<Loaded<List<StaffAssignment>>> assignments();
  Future<Loaded<List<CheckInEntry>>> entries(String eventId);
  Future<CheckInResult> checkIn(CheckInInput input);
  Future<List<PendingCheckIn>> pending();
  Future<bool> synchronize(Set<String> activeEventIds);
}
