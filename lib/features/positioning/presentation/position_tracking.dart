import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/errors/app_exceptions.dart';
import '../data/positioning_api.dart';

class PositionTracking extends ChangeNotifier {
  final PositioningApi _api;
  final ValueChanged<String> onAlert;

  PositionTracking(String token, {required this.onAlert})
    : _api = PositioningApi(token);

  static const _interval = Duration(seconds: 5);
  Timer? _reportTimer;
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
    if (foreground) {
      _connectAlerts();
      if (enabled) _scheduleReports();
    } else {
      _generation++;
      requesting = false;
      _reportTimer?.cancel();
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
      _scheduleReports();
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

  void stop({String? message}) {
    _generation++;
    _reportTimer?.cancel();
    enabled = false;
    requesting = false;
    status = message;
    notifyListeners();
  }

  void _scheduleReports() {
    _reportTimer?.cancel();
    unawaited(_report());
    _reportTimer = Timer.periodic(_interval, (_) => unawaited(_report()));
  }

  Future<void> _report() async {
    final eventId = _eventId;
    if (!enabled || !_foreground || _sending || eventId == null) return;
    final generation = _generation;
    _sending = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
            ? AndroidSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: _interval,
                forceLocationManager: true,
              )
            : const LocationSettings(
                accuracy: LocationAccuracy.high,
                timeLimit: _interval,
              ),
      );
      if (generation != _generation) return;
      final zone = await _api.report(eventId, position);
      if (generation != _generation) return;
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
    } on PermissionDeniedException {
      if (generation != _generation) return;
      stop(message: 'Cấp quyền vị trí trong cài đặt để dùng Check-in.');
    } catch (_) {
      if (generation == _generation) {
        status = 'Chưa lấy được vị trí GPS. Đang thử lại.';
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
        .listen(onAlert, onError: reconnect, onDone: reconnect);
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
    status = null;
    _reportTimer?.cancel();
    _cancelAlerts();
    super.dispose();
  }
}
