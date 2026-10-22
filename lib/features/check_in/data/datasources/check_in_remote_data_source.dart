import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/app_exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../authentication/data/datasources/auth_local_data_source.dart';
import '../../domain/check_in_models.dart';

class CheckInRemoteDataSource {
  final ApiClient client;
  final AuthLocalDataSource session;
  CheckInRemoteDataSource({ApiClient? client, AuthLocalDataSource? session})
    : client = client ?? ApiClient(),
      session = session ?? AuthLocalDataSourceImpl();

  Future<String> _token() async {
    final user = await session.getSavedUser();
    if (user == null) {
      ApiClient.onSessionExpired?.call();
      throw AuthException(
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
        401,
      );
    }
    return user.token;
  }

  Future<List<StaffAssignment>> assignments() async {
    final data = await client.get(
      ApiEndpoints.assignments,
      token: await _token(),
    );
    return (data as List)
        .map((e) => StaffAssignment(Json.from(e as Map)))
        .where((e) => e.status.toLowerCase() == 'active')
        .toList();
  }

  Future<List<CheckInEntry>> entries(String eventId) async {
    final data = await client.get(
      ApiEndpoints.checkIns(eventId),
      token: await _token(),
    );
    return (data as List)
        .map((e) => CheckInEntry(Json.from(e as Map)))
        .toList();
  }

  Future<CheckInResult> checkIn(Json body) async {
    final data = await client.post(
      ApiEndpoints.checkIn,
      token: await _token(),
      body: body,
    );
    return CheckInResult(Json.from(data as Map));
  }
}
