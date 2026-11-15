import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:staff_mobile/core/constants/app_colors.dart';
import 'package:staff_mobile/core/theme/app_theme.dart';
import 'package:staff_mobile/features/authentication/domain/entities/user_entity.dart';
import 'package:staff_mobile/features/authentication/presentation/screens/login_screen.dart';
import 'package:staff_mobile/features/check_in/domain/check_in_input.dart';
import 'package:staff_mobile/features/check_in/domain/check_in_models.dart';
import 'package:staff_mobile/features/check_in/domain/check_in_repository.dart';
import 'package:staff_mobile/features/check_in/presentation/controller/check_in_controller.dart';
import 'package:staff_mobile/features/check_in/presentation/screens/check_in_screen.dart';
import 'package:staff_mobile/features/staff/presentation/screens/staff_screen.dart';
import 'package:staff_mobile/shared/widgets/status_panel.dart';

class FakeRepository implements CheckInRepository {
  bool duplicate = false;
  @override
  Future<Loaded<List<StaffAssignment>>> assignments() async => Loaded([
    StaffAssignment({
      'eventId': 'event-1',
      'eventName': 'RaceDay Marathon',
      'role': 'race-staff',
      'status': 'active',
      'stationLabel': 'Quầy 1',
    }),
    StaffAssignment({
      'eventId': 'event-2',
      'eventName': 'RaceDay Trail',
      'role': 'race-staff',
      'status': 'active',
    }),
    StaffAssignment({
      'eventId': 'event-3',
      'eventName': 'Photographer only',
      'role': 'photographer',
      'status': 'active',
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
    'Staff opens check-in directly and changes events in the drawer',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StaffScreen(
            user: const UserEntity(
              username: 'staff',
              role: 'Race-staff',
              token: 'demo-token',
            ),
            repository: FakeRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RaceDay Marathon'), findsOneWidget);
      expect(find.text('Quét QR vé runner'), findsOneWidget);
      expect(find.text('Thống kê ảnh'), findsNothing);
      expect(find.text('Giải được phân công'), findsNothing);

      await tester.tap(find.byTooltip('Mở menu RaceDay'));
      await tester.pumpAndSettle();
      expect(find.text('Staff'), findsOneWidget);
      expect(find.text('Photographer only'), findsNothing);
      await tester.tap(find.text('RaceDay Trail'));
      await tester.pumpAndSettle();
      expect(find.text('RaceDay Trail'), findsOneWidget);
      expect(find.text('RaceDay Marathon'), findsNothing);

      await tester.tap(find.byTooltip('Làm mới'));
      await tester.pumpAndSettle();
      expect(find.text('RaceDay Trail'), findsOneWidget);
    },
  );

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
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: CheckInScreen(controller: controller)),
        ),
      );
      expect(find.text('Nhân sự giải chạy · Quầy 1'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Số BIB'),
        '000123',
      );
      await tester.tap(find.text('Check-in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check-in thành công'), findsOneWidget);
      expect(
        tester.widget<StatusPanel>(find.byType(StatusPanel)).color,
        AppColors.success,
      );
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
      expect(
        tester.widget<StatusPanel>(find.byType(StatusPanel)).color,
        AppColors.error,
      );
      expect(
        tester.widget<StatusPanel>(find.byType(StatusPanel)).icon,
        Icons.error_outline,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
