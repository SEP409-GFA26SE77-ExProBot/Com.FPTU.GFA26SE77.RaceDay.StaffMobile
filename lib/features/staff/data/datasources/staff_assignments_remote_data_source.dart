import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../check_in/domain/check_in_models.dart';

class StaffAssignmentsRemoteDataSource {
  final ApiClient client;
  const StaffAssignmentsRemoteDataSource(this.client);

  Future<List<StaffAssignment>> load(String token) async {
    final data = await client.get(ApiEndpoints.assignments, token: token);
    return (data as List)
        .map((row) => StaffAssignment(Json.from(row as Map)))
        .where((assignment) => assignment.status.toLowerCase() == 'active')
        .toList();
  }
}
