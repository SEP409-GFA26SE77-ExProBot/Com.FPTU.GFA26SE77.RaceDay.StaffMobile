import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/errors/app_exceptions.dart';

/// Scans the organizer's rotating check-in QR. Pops `true` once the server
/// accepts the code; a wrong code shows an error and scanning continues.
class StaffCheckInScanScreen extends StatefulWidget {
  final String eventName;
  final Future<void> Function(String code) onCode;

  const StaffCheckInScanScreen({
    super.key,
    required this.eventName,
    required this.onCode,
  });

  @override
  State<StaffCheckInScanScreen> createState() => _StaffCheckInScanScreenState();
}

class _StaffCheckInScanScreenState extends State<StaffCheckInScanScreen> {
  static const _retryDelay = Duration(seconds: 2);
  bool _verifying = false;
  bool _done = false;
  String? _error;
  String? _lastRejected;
  DateTime? _lastRejectedAt;
  int _attempt = 0;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_verifying || _done || !mounted) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (barcode.format == BarcodeFormat.qrCode &&
          value != null &&
          value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;
    // The camera keeps reporting the same code; don't resend a rejected one at once.
    final rejectedAt = _lastRejectedAt;
    if (raw == _lastRejected &&
        rejectedAt != null &&
        DateTime.now().difference(rejectedAt) < _retryDelay) {
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await widget.onCode(raw);
      if (!mounted) return;
      _done = true;
      Navigator.of(context).pop(true);
    } on AppException catch (error) {
      _reject(raw, error.message);
    } catch (_) {
      _reject(raw, 'Không check-in được. Vui lòng thử lại.');
    }
  }

  void _reject(String raw, String message) {
    if (!mounted) return;
    _lastRejected = raw;
    _lastRejectedAt = DateTime.now();
    setState(() {
      _verifying = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Quét QR check-in')),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.eventName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  key: ValueKey(_attempt),
                  onDetect: (capture) => unawaited(_onDetect(capture)),
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.no_photography_outlined,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            error.errorCode ==
                                    MobileScannerErrorCode.permissionDenied
                                ? 'Chưa được cấp quyền camera. Cho phép camera trong cài đặt ứng dụng rồi thử lại.'
                                : 'Không mở được camera. Thử lại camera.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(() => _attempt++),
                            child: const Text('Thử lại camera'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _error == null
                            ? Colors.white70
                            : Colors.redAccent,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                if (_verifying)
                  const CircularProgressIndicator(color: Colors.white),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _error == null
                ? Text(
                    _verifying
                        ? 'Đang kiểm tra mã…'
                        : 'Quét mã QR check-in trên màn hình của BTC.\nMã đổi mỗi 60 giây.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, height: 1.6),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
