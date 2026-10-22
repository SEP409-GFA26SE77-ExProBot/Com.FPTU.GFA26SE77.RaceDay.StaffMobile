import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:staff_mobile/core/errors/app_exceptions.dart';
import 'package:staff_mobile/core/network/api_client.dart';
import 'package:staff_mobile/features/authentication/data/datasources/auth_local_data_source.dart';
import 'package:staff_mobile/features/authentication/data/datasources/auth_remote_data_source.dart';
import 'package:staff_mobile/features/authentication/data/models/user_model.dart';
import 'package:staff_mobile/features/check_in/data/datasources/check_in_local_data_source.dart';
import 'package:staff_mobile/features/check_in/data/datasources/check_in_remote_data_source.dart';
import 'package:staff_mobile/features/check_in/data/repositories/check_in_repository_impl.dart';
import 'package:staff_mobile/features/check_in/domain/check_in_input.dart';
import 'package:staff_mobile/features/check_in/presentation/controller/check_in_controller.dart';

const eventId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const assignment = {
  'eventId': eventId,
  'eventName': 'RaceDay Marathon',
  'role': 'volunteer',
  'status': 'active',
  'stationLabel': 'Quầy check-in',
  'eventDate': '2026-11-01',
};
const runner = {
  'registrationId': 'registration-1',
  'bibNumber': '000123',
  'fullName': 'Nguyễn An',
  'status': 'confirmed',
  'checkedIn': false,
  'checkedInAtUtc': null,
  'distanceLabel': 'Road · 10 KM',
  'distanceKm': 10,
};
const qr =
    '{"user_id":"runner-1","bib":"000123","event_id":"$eventId","distance":"10 KM"}';
final serverResult = {
  ...runner,
  'eventId': eventId,
  'checkedInAtUtc': '2026-10-22T02:30:00Z',
  'alreadyCheckedIn': false,
};

String jwt({int? expiry, String role = 'Volunteer'}) {
  final body = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': 'volunteer-1',
        'preferred_username': 'vol1',
        'http://schemas.microsoft.com/ws/2008/06/identity/claims/role': role,
        'exp':
            expiry ??
            DateTime.now()
                    .add(const Duration(hours: 1))
                    .millisecondsSinceEpoch ~/
                1000,
      }),
    ),
  );
  return 'e30.$body.signature';
}

http.Response response(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late AuthLocalDataSourceImpl session;
  late CheckInLocalDataSource local;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    session = AuthLocalDataSourceImpl();
    await session.saveUser(
      UserModel(
        id: 'volunteer-1',
        username: 'vol1',
        role: 'Volunteer',
        token: jwt(),
      ),
    );
    local = CheckInLocalDataSource(prefs, 'volunteer-1');
    ApiClient.onSessionExpired = null;
  });
  tearDown(() => ApiClient.onSessionExpired = null);

  CheckInRepositoryImpl repository(
    FutureOr<http.Response> Function(http.Request) handler,
  ) => CheckInRepositoryImpl(
    local: local,
    remote: CheckInRemoteDataSource(
      session: session,
      client: ApiClient(
        client: MockClient((request) async => handler(request)),
      ),
    ),
  );

  Future<void> seed() async {
    await local.write('assignments', [assignment]);
    await local.write('list_$eventId', [runner]);
  }

  test(
    'Volunteer login uses IAM payload and restores a valid session',
    () async {
      final remote = AuthRemoteDataSourceImpl(
        client: ApiClient(
          client: MockClient((request) async {
            expect(request.url.path, '/api/v1/iam/auth/login');
            expect(jsonDecode(request.body), {
              'username': 'vol1',
              'password': 'password123',
            });
            return response({'accessToken': jwt()});
          }),
        ),
      );
      final user = await remote.login(' vol1 ', 'password123');
      expect(user.role, 'Volunteer');
      expect(user.username, 'vol1');
      await session.saveUser(user);
      expect((await session.getSavedUser())!.id, 'volunteer-1');
    },
  );

  test(
    'Expired session is cleared and never makes an authenticated call',
    () async {
      await session.saveUser(
        UserModel(username: 'vol1', role: 'Volunteer', token: jwt(expiry: 1)),
      );
      var calls = 0;
      var expired = 0;
      ApiClient.onSessionExpired = () => expired++;
      final repo = repository((_) {
        calls++;
        return response([]);
      });
      await expectLater(repo.assignments(), throwsA(isA<AuthException>()));
      expect(calls, 0);
      expect(expired, 1);
      expect(await session.getSavedUser(), isNull);
    },
  );

  test(
    'Assigned events, roster and QR POST match UserWeb and backend contracts',
    () async {
      final requests = <http.Request>[];
      final repo = repository((request) {
        requests.add(request);
        expect(request.headers['Authorization'], startsWith('Bearer '));
        switch (request.url.path) {
          case '/api/v1/event/staff/me':
            return response([
              assignment,
              {...assignment, 'eventId': 'inactive', 'status': 'invited'},
            ]);
          case '/api/v1/event/check-ins':
            expect(request.url.queryParameters, {'eventId': eventId});
            return response([runner]);
          case '/api/v1/event/check-in':
            expect(request.method, 'POST');
            expect(jsonDecode(request.body), {
              'eventId': eventId,
              'qrPayload': qr,
            });
            return response(serverResult);
          default:
            fail('Unexpected endpoint: ${request.url}');
        }
      });
      expect((await repo.assignments()).value.single.eventId, eventId);
      expect((await repo.entries(eventId)).value.single.bibNumber, '000123');
      final result = await repo.checkIn(CheckInInput.qr(eventId, qr));
      expect(result.fullName, 'Nguyễn An');
      expect(result.pendingSync, false);
      expect(local.read('list_$eventId')!.single['checkedIn'], true);
      expect(requests.length, 3);
    },
  );

  test('Manual and numeric QR preserve BIB leading zeroes', () {
    expect(CheckInInput.manual(eventId, ' 000123 ').toJson(), {
      'eventId': eventId,
      'bib': '000123',
    });
    expect(CheckInInput.qr(eventId, '000123').toJson(), {
      'eventId': eventId,
      'bib': '000123',
    });
  });

  test(
    'Wrong-event, payment, malformed and empty QR are rejected before POST',
    () {
      for (final raw in [
        qr.replaceAll(eventId, 'another-event'),
        '[object Object]',
        '[]',
        'https://payment.example/123',
        '{"amount":100}',
        '',
        '{"bib":123}',
      ]) {
        expect(
          () => CheckInInput.qr(eventId, raw),
          throwsA(isA<AppException>()),
        );
      }
      expect(
        () => CheckInInput.manual(eventId, ' '),
        throwsA(isA<AppException>()),
      );
    },
  );

  test('Server duplicate result retains first check-in timestamp', () async {
    final repo = repository(
      (_) => response({...serverResult, 'alreadyCheckedIn': true}),
    );
    final result = await repo.checkIn(CheckInInput.qr(eventId, qr));
    expect(result.alreadyCheckedIn, true);
    expect(result.checkedInAt, DateTime.parse('2026-10-22T02:30:00Z'));
  });

  test(
    'Offline queue is durable, deduplicated and isolated by staff account',
    () async {
      await seed();
      final repo = repository((_) => throw http.ClientException('offline'));
      expect((await repo.assignments()).offline, true);
      expect((await repo.entries(eventId)).offline, true);
      final first = await repo.checkIn(CheckInInput.qr(eventId, qr));
      final second = await repo.checkIn(CheckInInput.qr(eventId, qr));
      expect(first.pendingSync, true);
      expect(first.checkedIn, false);
      expect(second.alreadyCheckedIn, true);
      expect((await repo.pending()).length, 1);
      expect(local.read('list_$eventId')!.single['checkedIn'], false);
      expect(CheckInLocalDataSource(prefs, 'volunteer-1').pending.length, 1);
      expect(CheckInLocalDataSource(prefs, 'volunteer-2').pending, isEmpty);
    },
  );

  test(
    'Offline unknown runner / missing cache / user-only QR cannot be checked in',
    () async {
      final repo = repository((_) => throw http.ClientException('offline'));
      await expectLater(
        repo.checkIn(CheckInInput.qr(eventId, qr)),
        throwsA(isA<AppException>()),
      );
      await seed();
      await expectLater(
        repo.checkIn(CheckInInput.manual(eventId, '999')),
        throwsA(isA<AppException>()),
      );
      await expectLater(
        repo.checkIn(CheckInInput.qr(eventId, '{"user_id":"runner-1"}')),
        throwsA(isA<AppException>()),
      );
      expect(await repo.pending(), isEmpty);
    },
  );

  test(
    'HTTP errors and malformed success responses never become offline success',
    () async {
      await seed();
      for (final code in [400, 401, 403, 500]) {
        final repo = repository((_) => response({'message': 'Denied'}, code));
        await expectLater(
          repo.checkIn(CheckInInput.qr(eventId, qr)),
          throwsA(isA<AppException>()),
        );
        expect(await repo.pending(), isEmpty);
      }
      final invalid = repository((_) => http.Response('not-json', 200));
      await expectLater(
        invalid.checkIn(CheckInInput.qr(eventId, qr)),
        throwsA(isA<AppException>()),
      );
      expect(await invalid.pending(), isEmpty);
    },
  );

  test(
    'Sync resends original QR and clears only server-acknowledged entries',
    () async {
      await seed();
      await repository(
        (_) => throw http.ClientException('offline'),
      ).checkIn(CheckInInput.qr(eventId, qr));
      final denied = repository((request) {
        expect(jsonDecode(request.body), {'eventId': eventId, 'qrPayload': qr});
        return response({'message': 'Runner no longer confirmed'}, 400);
      });
      expect(await denied.synchronize({eventId}), true);
      expect(
        (await denied.pending()).single.error,
        'Runner no longer confirmed',
      );
      final restored = repository(
        (_) => response({...serverResult, 'alreadyCheckedIn': true}),
      );
      await restored.synchronize({eventId});
      expect(await restored.pending(), isEmpty);
      expect(
        local.read('list_$eventId')!.single['checkedInAtUtc'],
        '2026-10-22T02:30:00Z',
      );
    },
  );

  test(
    'Revoked assignments and network failures keep queue without false confirmation',
    () async {
      await seed();
      final offline = repository((_) => throw http.ClientException('offline'));
      await offline.checkIn(CheckInInput.qr(eventId, qr));
      expect(await offline.synchronize({eventId}), false);
      expect((await offline.pending()).length, 1);
      var calls = 0;
      final repo = repository((_) {
        calls++;
        return response(serverResult);
      });
      await repo.synchronize({});
      expect(calls, 0);
      expect((await repo.pending()).single.error, contains('Active'));
    },
  );

  test(
    'Controller suppresses concurrent submits and can be disposed during a request',
    () async {
      final completion = Completer<http.Response>();
      var posts = 0;
      final repo = repository((request) {
        if (request.url.path.endsWith('/staff/me')) {
          return response([assignment]);
        }
        if (request.url.path.endsWith('/check-ins')) return response([runner]);
        posts++;
        return completion.future;
      });
      final controller = CheckInController(repo);
      await controller.refresh();
      await controller.select(controller.assignments.single);
      final first = controller.submit(qr, fromQr: true);
      expect(await controller.submit(qr, fromQr: true), isNull);
      await Future<void>.delayed(Duration.zero);
      expect(posts, 1);
      controller.dispose();
      completion.complete(response(serverResult));
      await first;
    },
  );

  test('Refreshing a revoked assignment disables the selected event', () async {
    var assigned = true;
    final repo = repository(
      (request) => request.url.path.endsWith('/staff/me')
          ? response(assigned ? [assignment] : [])
          : response([runner]),
    );
    final controller = CheckInController(repo);
    await controller.refresh();
    await controller.select(controller.assignments.single);
    assigned = false;
    await controller.refresh();
    expect(controller.selected, isNull);
    expect(controller.entries, isEmpty);
    expect(await controller.submit(qr, fromQr: true), isNull);
    controller.dispose();
  });
}
