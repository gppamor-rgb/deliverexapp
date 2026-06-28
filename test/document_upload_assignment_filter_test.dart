import 'package:deliverex/screens/document_upload_screen.dart';
import 'package:deliverex/models/driver_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'document upload selector includes active pending and completed jobs',
    () {
      for (final status in [
        'assigned',
        'en_route_to_pickup',
        'arrived_at_pickup',
        'en_route_to_destination',
        'arrived',
        'completed',
      ]) {
        final assignment = DriverAssignment.fromJson({
          'id': 1,
          'status': status,
        });

        expect(
          isDocumentUploadSelectableAssignment(assignment),
          isTrue,
          reason: '$status should be selectable for non-POD uploads.',
        );
      }
    },
  );

  test('document upload selector excludes cancelled jobs', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'status': 'cancelled',
    });

    expect(isDocumentUploadSelectableAssignment(assignment), isFalse);
  });
}
