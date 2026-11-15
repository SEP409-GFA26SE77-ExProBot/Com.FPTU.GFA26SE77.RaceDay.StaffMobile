import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../check_in/domain/check_in_models.dart';
import '../../../staff/data/datasources/staff_assignments_remote_data_source.dart';
import '../../domain/photo_analytics.dart';

class PhotoAnalyticsRemoteDataSource {
  final ApiClient client;
  final String token;

  PhotoAnalyticsRemoteDataSource({required this.token, ApiClient? client})
    : client = client ?? ApiClient();

  Future<List<StaffAssignment>> assignments() async {
    final assignments = await StaffAssignmentsRemoteDataSource(
      client,
    ).load(token);
    return assignments
        .where((assignment) => assignment.role == 'photographer')
        .toList();
  }

  Future<PhotoAnalytics> load(String eventId) async {
    final totals = await Future.wait(
      PhotoBucket.values.map((bucket) async {
        final data = await client.get(
          ApiEndpoints.photographerPhotos(eventId, bucket.name),
          token: token,
        );
        final total = data is Map ? data['total'] : null;
        if (total is! int || total < 0) {
          throw AppException('Phản hồi thống kê ảnh không hợp lệ.');
        }
        return MapEntry(bucket, total);
      }),
    );
    return PhotoAnalytics(Map.fromEntries(totals));
  }
}
