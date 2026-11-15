import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';

class PositioningApi {
  final String token;
  final ApiClient _api;

  PositioningApi(this.token) : _api = ApiClient();

  Future<String?> report(String eventId, Position position) async {
    final result = await _api.post(
      ApiEndpoints.positioning(eventId, 'positions'),
      token: token,
      body: {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracyMeters': position.accuracy,
        'capturedAtUtc': position.timestamp.toUtc().toIso8601String(),
      },
    );
    return result is Map ? result['zoneStatus'] as String? : null;
  }

  Stream<String> alerts(String eventId, http.Client client) async* {
    final request =
        http.Request(
            'GET',
            Uri.parse(ApiEndpoints.positioning(eventId, 'alerts')),
          )
          ..headers.addAll({
            'Authorization': 'Bearer $token',
            'Accept': 'text/event-stream',
          });
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode == 401) {
      ApiClient.onSessionExpired?.call();
    }
    if (response.statusCode != 200) {
      throw AppException(
        'Không kết nối được cảnh báo vị trí.',
        response.statusCode,
      );
    }

    String? event;
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:') && event == 'outside') {
        final alert = jsonDecode(line.substring(5)) as Map<String, dynamic>;
        if (alert['eventId']?.toString().toLowerCase() ==
                eventId.toLowerCase() &&
            alert['staffName'] is String) {
          yield '${alert['staffName']} đã rời vùng hoạt động.';
        }
      } else if (line.isEmpty) {
        event = null;
      }
    }
  }
}
