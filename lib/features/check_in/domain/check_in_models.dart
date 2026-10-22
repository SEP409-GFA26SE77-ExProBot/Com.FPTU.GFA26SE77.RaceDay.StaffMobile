typedef Json = Map<String, dynamic>;

class StaffAssignment {
  final Json data;
  StaffAssignment(Json data) : data = Map.unmodifiable(data);
  String get eventId => data['eventId'] as String;
  String get eventName => data['eventName'] as String? ?? 'Giải chạy';
  String get role => data['role'] as String? ?? 'volunteer';
  String get status => data['status'] as String? ?? '';
  String? get stationLabel => data['stationLabel'] as String?;
  String? get eventDate => data['eventDate'] as String?;
  String get roleLabel => switch (role) {
    'volunteer' => 'Tình nguyện viên',
    'coordinator' => 'Điều phối viên',
    'photographer' => 'Nhiếp ảnh gia',
    _ => role,
  };
}

class CheckInEntry {
  final Json data;
  CheckInEntry(Json data) : data = Map.unmodifiable(data);
  String get registrationId => data['registrationId'] as String;
  String get bibNumber => data['bibNumber'] as String? ?? '';
  String get fullName => data['fullName'] as String? ?? '';
  String get status => data['status'] as String? ?? '';
  bool get checkedIn => data['checkedIn'] == true;
  DateTime? get checkedInAt =>
      DateTime.tryParse(data['checkedInAtUtc']?.toString() ?? '');
  String get distanceLabel =>
      data['distanceLabel'] as String? ??
      (data['distanceKm'] != null
          ? '${data['distanceKm']} km'
          : 'Chưa có cự ly');
}

class CheckInResult extends CheckInEntry {
  CheckInResult(super.data);
  String get eventId => data['eventId'] as String;
  bool get alreadyCheckedIn => data['alreadyCheckedIn'] == true;
  bool get pendingSync => status == 'pending_sync';
  bool get fromCache => data['fromCache'] == true;
  @override
  bool get checkedIn => !pendingSync;
}

class PendingCheckIn {
  final Json data;
  PendingCheckIn(Json data) : data = Map.unmodifiable(data);
  String get registrationId => data['registrationId'] as String;
  String get eventId => data['eventId'] as String;
  String get bib => data['bib'] as String;
  String get fullName => data['fullName'] as String;
  String? get error => data['error'] as String?;
  Json get request => {
    'eventId': eventId,
    if (data['qrPayload'] != null)
      'qrPayload': data['qrPayload']
    else
      'bib': bib,
  };
}

class Loaded<T> {
  final T value;
  final bool offline;
  const Loaded(this.value, {this.offline = false});
}
