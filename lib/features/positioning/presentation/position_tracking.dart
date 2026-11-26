import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_exceptions.dart';
import '../data/positioning_api.dart';

class PositionTracking extends ChangeNotifier {
  final PositioningApi _api;

  PositionTracking(String token) : _api = PositioningApi(token);

  static const _interval = Duration(seconds: 5);
  static const _minGap = Duration(milliseconds: 4500);
  StreamSubscription<Position>? _positionSubscription;
  DateTime? _lastSent;
  Timer? _alertRetry;
  http.Client? _alertClient;
  StreamSubscription<String>? _alertSubscription;
  String? _eventId;
  bool _foreground = true;
  bool _sending = false;
  int _generation = 0;
  bool enabled = false;
  bool requesting = false;
  String? status;

  /// True from the first "outside" report or alert until the server reports
  /// "inside" again. Drives the red banner on the main screen.
  bool outsideZone = false;

  void selectEvent(String? eventId) {
    if (_eventId == eventId) return;
    stop();
    _cancelAlerts();
    _eventId = eventId;
    _connectAlerts();
  }

  void lifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) return;
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    // GPS keeps running in the background through the location foreground
    // service; only the alert stream pauses while the app is not visible.
    if (foreground) {
      _connectAlerts();
    } else {
      if (requesting) {
        _generation++;
        requesting = false;
      }
      _cancelAlerts();
    }
    notifyListeners();
  }

  Future<void> start() async {
    if (requesting || enabled || !_foreground || _eventId == null) return;
    final generation = ++_generation;
    requesting = true;
    status = null;
    notifyListeners();
    try {
      if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
        throw AppException('Bật dịch vụ vị trí để dùng Check-in.');
      }
      if (!kIsWeb) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied &&
            generation == _generation) {
          permission = await Geolocator.requestPermission();
        }
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          throw AppException(
            'Cấp quyền vị trí trong cài đặt để dùng Check-in.',
          );
        }
      }
      if (generation != _generation) return;
      enabled = true;
      _startPositionStream();
    } catch (error) {
      if (generation == _generation) {
        status = error is AppException
            ? error.message
            : 'Không thể mở dịch vụ vị trí.';
      }
    } finally {
      if (generation == _generation) {
        requesting = false;
        notifyListeners();
      }
    }
  }

  String? get eventId => _eventId;

  /// Sends the scanned organizer QR. Throws [AppException] when it is wrong.
  Future<void> checkIn(String code) async {
    final eventId = _eventId;
    if (eventId == null) throw AppException('Chọn giải trước khi check-in.');
    await _api.checkIn(eventId, code);
  }

  /// Turns Check-in off: stops GPS and ends the check-in on the server.
  void checkOut() {
    final eventId = _eventId;
    stop();
    if (eventId != null) {
      unawaited(_api.checkOut(eventId).catchError((Object _) {}));
    }
  }

  void stop({String? message}) {
    _generation++;
    _cancelPositionStream();
    enabled = false;
    requesting = false;
    outsideZone = false;
    status = message;
    notifyListeners();
  }

  LocationSettings _locationSettings() {
    if (kIsWeb) return const LocationSettings(accuracy: LocationAccuracy.high);
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: _interval,
        forceLocationManager: true,
        // Starts geolocator's foreground service so Android keeps the app
        // alive and sending GPS while the screen is off or the app is hidden.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'RaceDay Staff',
          notificationText: 'Đang gửi vị trí GPS cho Check-in.',
          enableWakeLock: true,
          setOngoing: true,
        ),
      ),
      TargetPlatform.iOS || TargetPlatform.macOS => AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      ),
      _ => const LocationSettings(accuracy: LocationAccuracy.high),
    };
  }

  void _startPositionStream() {
    _cancelPositionStream();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen((position) => unawaited(_report(position)), onError: _onGpsError);
  }

  void _cancelPositionStream() {
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    _lastSent = null;
  }

  void _onGpsError(Object error) {
    if (!enabled) return;
    if (error is PermissionDeniedException) {
      stop(message: 'Cấp quyền vị trí trong cài đặt để dùng Check-in.');
      return;
    }
    status = error is LocationServiceDisabledException
        ? 'Bật dịch vụ vị trí để dùng Check-in.'
        : 'Chưa lấy được vị trí GPS. Đang thử lại.';
    notifyListeners();
  }

  Future<void> _report(Position position) async {
    final eventId = _eventId;
    final now = DateTime.now();
    if (!enabled || _sending || eventId == null) return;
    final lastSent = _lastSent;
    if (lastSent != null && now.difference(lastSent) < _minGap) return;
    final generation = _generation;
    _sending = true;
    _lastSent = now;
    try {
      final zone = await _api.report(eventId, position);
      if (generation != _generation) return;
      // "uncertain" (GPS accuracy straddles the edge) keeps the last state so
      // the banner does not flicker at the zone boundary.
      if (zone == 'outside') {
        outsideZone = true;
      } else if (zone != 'uncertain') {
        outsideZone = false;
      }
      status = switch (zone) {
        'outside' => 'Đang ở ngoài vùng hoạt động.',
        'unconfigured' => 'Đang gửi GPS. Phân công chưa có vùng hoạt động.',
        'uncertain' => 'Đang gửi GPS. Chưa đủ chính xác để xác định vùng.',
        _ => 'Đang gửi GPS mỗi 5 giây.',
      };
    } on AppException catch (error) {
      if (generation != _generation) return;
      if (error.statusCode == 401 || error.statusCode == 403) {
        stop(message: error.message);
      } else {
        status = error.message;
      }
    } catch (_) {
      if (generation == _generation) {
        status = 'Chưa gửi được vị trí. Đang thử lại.';
      }
    } finally {
      _sending = false;
      if (generation == _generation) notifyListeners();
    }
  }

  void _connectAlerts() {
    final eventId = _eventId;
    if (!_foreground || eventId == null || _alertClient != null) return;
    final client = http.Client();
    _alertClient = client;
    void reconnect([Object? error]) {
      if (_alertClient != client) return;
      _cancelAlerts();
      if (error is AppException &&
          (error.statusCode == 401 ||
              error.statusCode == 403 ||
              error.statusCode == 404)) {
        return;
      }
      _alertRetry = Timer(const Duration(seconds: 2), _connectAlerts);
    }

    _alertSubscription = _api
        .alerts(eventId, client)
        .listen(
          (_) {
            if (!enabled) return;
            outsideZone = true;
            notifyListeners();
          },
          onError: reconnect,
          onDone: reconnect,
        );
  }

  void _cancelAlerts() {
    _alertRetry?.cancel();
    _alertClient?.close();
    _alertClient = null;
    unawaited(_alertSubscription?.cancel());
    _alertSubscription = null;
  }

  @override
  void dispose() {
    _generation++;
    enabled = false;
    outsideZone = false;
    status = null;
    _cancelPositionStream();
    _cancelAlerts();
    super.dispose();
  }
}
