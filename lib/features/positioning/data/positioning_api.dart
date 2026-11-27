import 'dart:convert';
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';

/// An incident report a staff member sends to the organizer.
class StaffReportDraft {
  /// One of Weather, CourseHazard, Medical, Security, Logistics, Other.
  final String incidentType;
  final String description;
  final Position? position;
  final Uint8List? photo;
  final String photoName;

  const StaffReportDraft({
    required this.incidentType,
    required this.description,
    this.position,
    this.photo,
    this.photoName = 'su-co.jpg',
  });
}

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

  /// Checks in with the organizer's rotating QR. Throws [AppException] with
  /// the server message when the code is wrong or expired.
  Future<void> checkIn(String eventId, String code) => _api.post(
    ApiEndpoints.positioning(eventId, 'check-in'),
    token: token,
    body: {'code': code},
  );

  /// Sends an incident report to the organizer, with an optional photo.
  Future<void> submitReport(String eventId, StaffReportDraft draft) {
    final position = draft.position;
    final photo = draft.photo;
    return _api.postMultipart(
      ApiEndpoints.positioning(eventId, 'reports'),
      token: token,
      fields: {
        'incidentType': draft.incidentType,
        'description': draft.description,
        if (position != null) ...{
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
          'accuracyMeters': position.accuracy.toString(),
        },
      },
      files: [
        if (photo != null)
          http.MultipartFile.fromBytes(
            'photo',
            photo,
            filename: draft.photoName,
            contentType: _imageType(draft.photoName),
          ),
      ],
    );
  }

  static MediaType _imageType(String name) =>
      switch (name.split('.').last.toLowerCase()) {
        'png' => MediaType('image', 'png'),
        'webp' => MediaType('image', 'webp'),
        'heic' => MediaType('image', 'heic'),
        'heif' => MediaType('image', 'heif'),
        _ => MediaType('image', 'jpeg'),
      };

  Future<void> checkOut(String eventId) =>
      _api.delete(ApiEndpoints.positioning(eventId, 'check-in'), token: token);

  /// Out-of-zone alerts. The server only sends this user's own alerts.
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
            eventId.toLowerCase()) {
          yield 'Bạn đang ở ngoài vùng hoạt động được phân công.';
        }
      } else if (line.isEmpty) {
        event = null;
      }
    }
  }
}
