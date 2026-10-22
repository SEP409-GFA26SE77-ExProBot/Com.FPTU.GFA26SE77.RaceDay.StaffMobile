import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_mobile/core/theme/app_theme.dart';
import 'package:staff_mobile/features/authentication/presentation/screens/login_screen.dart';
import 'package:staff_mobile/features/check_in/domain/check_in_input.dart';
import 'package:staff_mobile/features/check_in/domain/check_in_models.dart';
import 'package:staff_mobile/features/check_in/domain/check_in_repository.dart';
import 'package:staff_mobile/features/check_in/presentation/controller/check_in_controller.dart';
import 'package:staff_mobile/features/check_in/presentation/screens/check_in_screen.dart';

class FakeRepository implements CheckInRepository {
  bool duplicate = false;
  @override
  Future<Loaded<List<StaffAssignment>>> assignments() async => Loaded([
    StaffAssignment({
      'eventId': 'event-1',
      'eventName': 'RaceDay Marathon',
      'role': 'volunteer',
      'status': 'active',
      'stationLabel': 'Quầy 1',
    }),
  ]);
  @override
  Future<Loaded<List<CheckInEntry>>> entries(String eventId) async => Loaded([
    CheckInEntry({
      'registrationId': 'r1',
      'bibNumber': '000123',
      'fullName': 'Nguyễn An',
      'status': 'confirmed',
      'checkedIn': false,
      'distanceLabel': '10 KM',
    }),
  ]);
  @override
  Future<CheckInResult> checkIn(CheckInInput input) async => CheckInResult({
    'registrationId': 'r1',
    'eventId': input.eventId,
    'bibNumber': input.bib,
    'fullName': 'Nguyễn An',
    'status': 'confirmed',
    'alreadyCheckedIn': duplicate,
    'checkedInAtUtc': '2026-10-22T02:30:00Z',
    'distanceLabel': '10 KM',
  });
  @override
  Future<List<PendingCheckIn>> pending() async => [];
  @override
  Future<bool> synchronize(Set<String> activeEventIds) async => true;
}

void main() {
  testWidgets('Login starts empty and validates missing credentials', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const LoginScreen()),
    );
    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields.every((f) => f.controller!.text.isEmpty), true);
    await tester.tap(find.text('Đăng nhập'));
    await tester.pump();
    expect(
      find.text('Vui lòng nhập tên đăng nhập hoặc email.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Narrow screen manual check-in shows runner and duplicate result',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeRepository();
      final controller = CheckInController(repository);
      await controller.refresh();
      await controller.select(controller.assignments.single);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: CheckInScreen(controller: controller),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Số BIB'),
        '000123',
      );
      await tester.tap(find.text('Check-in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check-in thành công'), findsOneWidget);
      expect(find.textContaining('BIB 000123 · Nguyễn An'), findsOneWidget);
      repository.duplicate = true;
      await tester.enterText(
        find.widgetWithText(TextField, 'Số BIB'),
        '000123',
      );
      await tester.ensureVisible(find.text('Check-in'));
      await tester.tap(find.text('Check-in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Đã check-in trước đó'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
