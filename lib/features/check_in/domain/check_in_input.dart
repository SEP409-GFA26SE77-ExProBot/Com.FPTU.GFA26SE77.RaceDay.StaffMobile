import 'dart:convert';
import '../../../core/errors/app_exceptions.dart';
import 'check_in_models.dart';

class CheckInInput {
  final String eventId;
  final String? bib;
  final String? qrPayload;
  const CheckInInput._(this.eventId, {this.bib, this.qrPayload});

  factory CheckInInput.manual(String eventId, String value) {
    final bib = value.trim();
    if (bib.isEmpty) throw AppException('Vui lòng nhập số BIB.');
    return CheckInInput._(eventId, bib: bib);
  }

  factory CheckInInput.qr(String eventId, String value) {
    final raw = value.trim();
    // UserWeb also accepts a QR containing only a numeric BIB.
    if (RegExp(r'^\d{1,8}$').hasMatch(raw)) {
      return CheckInInput.manual(eventId, raw);
    }
    Json payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Json) throw const FormatException();
      payload = decoded;
    } catch (_) {
      throw AppException(
        'QR không hợp lệ. Hãy quét QR vé RaceDay hoặc nhập BIB.',
      );
    }
    final qrEvent = payload['event_id'] ?? payload['eventId'];
    if (qrEvent != null &&
        qrEvent.toString().toLowerCase() != eventId.toLowerCase()) {
      throw AppException('QR không thuộc giải đang check-in.');
    }
    final bib = payload['bib'];
    final userId = payload['user_id'];
    if ((bib is! String || bib.trim().isEmpty) &&
        (userId is! String || userId.trim().isEmpty)) {
      throw AppException(
        'QR thiếu số BIB / user_id. Vui lòng mở vé trên RunnerMobile.',
      );
    }
    // Preserve the complete QR; sending bib as well would bypass the BE event check.
    return CheckInInput._(eventId, qrPayload: raw);
  }

  String? get offlineBib {
    if (bib != null) return bib;
    final value = (jsonDecode(qrPayload!) as Json)['bib'];
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  Json toJson() => {
    'eventId': eventId,
    if (bib != null) 'bib': bib,
    if (qrPayload != null) 'qrPayload': qrPayload,
  };
}
