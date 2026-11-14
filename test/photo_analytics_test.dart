import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:staff_mobile/core/network/api_client.dart';
import 'package:staff_mobile/features/authentication/domain/entities/user_entity.dart';
import 'package:staff_mobile/features/authentication/presentation/screens/signed_in_screen.dart';
import 'package:staff_mobile/features/photographer/data/datasources/photo_analytics_remote_data_source.dart';
import 'package:staff_mobile/features/photographer/presentation/screens/photo_analytics_screen.dart';
import 'package:staff_mobile/features/staff/presentation/screens/staff_screen.dart';

const photographer = UserEntity(
  username: 'photo',
  role: ' Photographer ',
  token: 'demo-token',
);

void main() {
  test('Opens the workspace for the signed-in account role', () {
    expect(signedInScreen(photographer), isA<PhotoAnalyticsScreen>());
    expect(
      signedInScreen(
        const UserEntity(
          username: 'staff',
          role: 'Race-staff',
          token: 'demo-token',
        ),
      ),
      isA<StaffScreen>(),
    );
  });

  testWidgets('Loads event analytics and retries a failed request', (
    tester,
  ) async {
    const totals = {
      'pending': 4,
      'queue': 3,
      'matched': 8,
      'ready': 3,
      'published': 5,
      'review': 1,
      'discarded': 1,
    };
    final requests = <http.Request>[];
    var shouldFail = true;
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/staff/me')) {
        return http.Response(
          jsonEncode([
            {
              'eventId': 'staff-event',
              'eventName': 'Staff only',
              'role': 'race-staff',
              'status': 'active',
            },
            {
              'eventId': 'event-1',
              'eventName': 'RaceDay Marathon',
              'role': 'photographer',
              'status': 'active',
            },
            {
              'eventId': 'event-2',
              'eventName': 'RaceDay Trail',
              'role': 'photographer',
              'status': 'active',
            },
            {
              'eventId': 'inactive-event',
              'eventName': 'Inactive event',
              'role': 'photographer',
              'status': 'invited',
            },
          ]),
          200,
        );
      }
      final bucket = request.url.pathSegments.last;
      if (shouldFail && bucket == 'published') {
        return http.Response('', 503);
      }
      return http.Response(jsonEncode({'total': totals[bucket]}), 200);
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: PhotoAnalyticsScreen(
          user: photographer,
          remote: PhotoAnalyticsRemoteDataSource(
            token: 'demo-token',
            client: ApiClient(client: client),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.text('Tổng số ảnh'), findsNothing);

    shouldFail = false;
    requests.clear();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(8));
    expect(
      requests.map((request) => request.url.path),
      unorderedEquals([
        '/api/v1/event/staff/me',
        ...totals.keys.map(
          (bucket) =>
              '/api/v1/photo/photographer/events/event-1/photos/$bucket',
        ),
      ]),
    );
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer demo-token');
      if (!request.url.path.endsWith('/staff/me')) {
        expect(request.url.queryParameters, {'page': '1', 'pageSize': '1'});
      }
    }
    expect(find.text('RaceDay Marathon'), findsOneWidget);
    expect(find.text('Tổng số ảnh'), findsOneWidget);
    expect(find.text('Quét QR vé runner'), findsNothing);
    expect(find.text('14'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Độ chính xác ước tính'), 180);
    expect(find.text('80.0%'), findsOneWidget);
    expect(find.text('88.9%'), findsOneWidget);

    requests.clear();
    await tester.tap(find.byTooltip('Mở menu RaceDay'));
    await tester.pumpAndSettle();
    expect(find.text('Staff only'), findsNothing);
    expect(find.text('Inactive event'), findsNothing);
    await tester.tap(find.text('RaceDay Trail'));
    await tester.pumpAndSettle();
    expect(requests, hasLength(7));
    expect(
      requests.every((request) => request.url.path.contains('/event-2/')),
      isTrue,
    );

    requests.clear();
    await tester.tap(find.byTooltip('Làm mới'));
    await tester.pumpAndSettle();
    expect(requests.first.url.path, '/api/v1/event/staff/me');
    expect(
      requests
          .skip(1)
          .every((request) => request.url.path.contains('/event-2/')),
      isTrue,
    );
  });
}
