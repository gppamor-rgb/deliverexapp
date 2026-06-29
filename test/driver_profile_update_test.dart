import 'package:deliverex/services/driver_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('driver profile update payload sends phone only', () {
    final body = driverProfileUpdateBody(phone: '  +639171234567  ');

    expect(body, {'phone': '+639171234567'});
    expect(body.containsKey('name'), isFalse);
  });

  test('driver status update payload includes action timestamp', () {
    final body = driverStatusUpdateBody(
      assignmentId: '7',
      status: 'arrived',
      latitude: 14.6040792,
      longitude: 120.9885911,
      actionTakenAt: '2026-06-30T10:15:00.000',
    );

    expect(body, {
      'assignment_id': '7',
      'status': 'arrived',
      'action_timestamp': '2026-06-30T10:15:00.000',
      'action_taken_at': '2026-06-30T10:15:00.000',
      'latitude': 14.6040792,
      'longitude': 120.9885911,
    });
  });

  test('driver tracking update payload includes captured timestamp', () {
    final body = driverTrackingUpdateBody(
      assignmentId: '7',
      latitude: 14.6040792,
      longitude: 120.9885911,
      capturedAt: '2026-06-30T10:15:00.000',
    );

    expect(body, {
      'assignment_id': '7',
      'latitude': 14.6040792,
      'longitude': 120.9885911,
      'action_timestamp': '2026-06-30T10:15:00.000',
      'action_taken_at': '2026-06-30T10:15:00.000',
      'captured_at': '2026-06-30T10:15:00.000',
    });
  });
}
