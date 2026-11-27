import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/errors/app_exceptions.dart';
import '../data/positioning_api.dart';

/// Staff report an incident to the organizer. Pops `true` once it is sent.
class StaffReportScreen extends StatefulWidget {
  final String eventName;
  final Future<void> Function(StaffReportDraft draft) onSubmit;

  const StaffReportScreen({
    super.key,
    required this.eventName,
    required this.onSubmit,
  });

  @override
  State<StaffReportScreen> createState() => _StaffReportScreenState();
}

class _StaffReportScreenState extends State<StaffReportScreen> {
  static const _maxDescription = 1000;
  static const _maxPhotoBytes = 5 * 1024 * 1024;
  static const _types = [
    (value: 'Logistics', label: 'Hậu cần, phương tiện', icon: Icons.local_shipping_outlined),
    (value: 'Medical', label: 'Y tế', icon: Icons.medical_services_outlined),
    (value: 'CourseHazard', label: 'Nguy hiểm trên đường chạy', icon: Icons.warning_amber_outlined),
    (value: 'Security', label: 'An ninh', icon: Icons.shield_outlined),
    (value: 'Weather', label: 'Thời tiết', icon: Icons.cloud_outlined),
    (value: 'Other', label: 'Khác', icon: Icons.more_horiz),
  ];

  final _description = TextEditingController();
  String? _type;
  Uint8List? _photo;
  String _photoName = 'su-co.jpg';
  Position? _position;
  bool _locating = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  /// Attaches the current GPS fix when location is already allowed; the
  /// report is still sent without it otherwise.
  Future<void> _locate() async {
    Position? position;
    try {
      final permission = await Geolocator.checkPermission();
      if ((permission == LocationPermission.always ||
              permission == LocationPermission.whileInUse) &&
          await Geolocator.isLocationServiceEnabled()) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
      }
    } catch (_) {
      // No fix in time: the report goes without a location.
    }
    if (!mounted) return;
    setState(() {
      _position = position;
      _locating = false;
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > _maxPhotoBytes) {
        setState(() => _error = 'Ảnh phải nhỏ hơn 5 MB.');
        return;
      }
      setState(() {
        _photo = bytes;
        _photoName = file.name.isEmpty ? 'su-co.jpg' : file.name;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Không mở được máy ảnh hoặc thư viện ảnh.');
    }
  }

  Future<void> _submit() async {
    final type = _type;
    final description = _description.text.trim();
    if (type == null) {
      setState(() => _error = 'Chọn loại sự cố.');
      return;
    }
    if (description.isEmpty) {
      setState(() => _error = 'Nhập mô tả sự cố.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(
        StaffReportDraft(
          incidentType: type,
          description: description,
          position: _position,
          photo: _photo,
          photoName: _photoName,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không gửi được báo cáo. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final position = _position;
    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo sự cố')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.eventName,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Báo cáo được gửi ngay tới Ban tổ chức.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Text('Loại sự cố', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in _types)
                ChoiceChip(
                  avatar: Icon(type.icon, size: 18),
                  label: Text(type.label),
                  selected: _type == type.value,
                  onSelected: _sending
                      ? null
                      : (_) => setState(() {
                          _type = type.value;
                          _error = null;
                        }),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _description,
            enabled: !_sending,
            minLines: 4,
            maxLines: 8,
            maxLength: _maxDescription,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              hintText: 'Ví dụ: Xe máy theo đoàn bị hư tại km 12, cần xe thay thế.',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text('Ảnh (không bắt buộc)', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_photo case final photo?)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    photo,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    tooltip: 'Bỏ ảnh',
                    onPressed: _sending ? null : () => setState(() => _photo = null),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sending ? null : () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Chụp ảnh'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sending ? null : () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Chọn ảnh'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                position == null ? Icons.location_off_outlined : Icons.location_on_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _locating
                      ? 'Đang lấy vị trí…'
                      : position == null
                      ? 'Không có vị trí GPS, báo cáo sẽ gửi không kèm vị trí.'
                      : 'Đính kèm vị trí hiện tại (±${position.accuracy.round()} m).',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 12),
            Text(error, style: const TextStyle(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(_sending ? 'Đang gửi…' : 'Gửi báo cáo'),
          ),
        ],
      ),
    );
  }
}
