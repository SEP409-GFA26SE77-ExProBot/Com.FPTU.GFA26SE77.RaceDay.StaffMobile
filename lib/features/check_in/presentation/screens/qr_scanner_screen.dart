import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  final String eventName;
  const QrScannerScreen({super.key, required this.eventName});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _returned = false;
  int _attempt = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(title: const Text('Quét QR vé runner')),
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
                // The widget owns its controller and handles app lifecycle automatically.
                MobileScanner(
                  key: ValueKey(_attempt),
                  onDetect: (capture) {
                    if (_returned || !mounted) return;
                    for (final barcode in capture.barcodes) {
                      final raw = barcode.rawValue?.trim();
                      if (barcode.format == BarcodeFormat.qrCode &&
                          raw != null &&
                          raw.isNotEmpty) {
                        _returned = true;
                        Navigator.of(context).pop(raw);
                        break;
                      }
                    }
                  },
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
                                : 'Không mở được camera. Thử lại hoặc quay về nhập BIB.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () => setState(() => _attempt++),
                            child: const Text('Thử lại camera'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Quay về nhập BIB'),
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
                      border: Border.all(color: Colors.white70, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Đưa QR trên vé RunnerMobile vào khung.\nGiữ máy ổn định để đọc mã.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.6),
            ),
          ),
        ],
      ),
    ),
  );
}
