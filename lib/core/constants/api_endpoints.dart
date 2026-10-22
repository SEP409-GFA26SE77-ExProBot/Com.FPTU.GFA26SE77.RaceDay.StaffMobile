import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiEndpoints {
  static String get baseUrl {
    const override = String.fromEnvironment('API_URL');
    final configured = override.isNotEmpty
        ? override
        : dotenv.isInitialized
        ? dotenv.env['API_URL'] ?? ''
        : '';
    if (configured.trim().isNotEmpty) {
      return configured.trim().replaceFirst(RegExp(r'/+$'), '');
    }
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:5080'
        : 'http://localhost:5080';
  }

  static String get login => '$baseUrl/api/v1/iam/auth/login';
  static String get assignments => '$baseUrl/api/v1/event/staff/me';
  static String get checkIn => '$baseUrl/api/v1/event/check-in';
  static String checkIns(String eventId) => Uri.parse(
    '$baseUrl/api/v1/event/check-ins',
  ).replace(queryParameters: {'eventId': eventId}).toString();
}
