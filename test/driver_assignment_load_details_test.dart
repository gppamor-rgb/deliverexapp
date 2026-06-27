import 'package:deliverex/models/driver_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats backend load volume cubic meters from job order', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'job_order': {'material_type': 'Gravel', 'load_volume_m3': '12.000'},
    });

    expect(assignment.loadVolume, '12.000 m³');
  });

  test('falls back to backend volume cubic meters from job order', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'job_order': {'material_type': 'Gravel', 'volume_m3': '12.500'},
    });

    expect(assignment.loadVolume, '12.500 m³');
  });

  test('formats whole number cubic meters with three decimals', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'job_order': {'material_type': 'Gravel', 'load_volume_m3': 14},
    });

    expect(assignment.loadVolume, '14.000 m³');
  });

  test('reads direct material type and load volume from job order', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'job_order': {
        'material_type': 'Gravel',
        'load_volume': '12 cubic meters',
      },
    });

    expect(assignment.materialType, 'Gravel');
    expect(assignment.loadVolume, '12 cubic meters');
  });

  test('reads nested material type and alternate load volume keys', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'job_order': {
        'material_type': {'name': 'Sand'},
        'quantity': '8 tons',
      },
    });

    expect(assignment.materialType, 'Sand');
    expect(assignment.loadVolume, '8 tons');
  });

  test('reads load field used by the website as mobile load volume', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'job_order': {'material_type': 'Sand', 'load': '10 truckloads'},
    });

    expect(assignment.loadVolume, '10 truckloads');
  });

  test('reads nested load value as mobile load volume', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'job_order': {
        'material_type': 'Gravel',
        'load': {'value': '15 cubic meters'},
      },
    });

    expect(assignment.loadVolume, '15 cubic meters');
  });

  test('falls back to placeholder when load details are missing', () {
    final assignment = DriverAssignment.fromJson({
      'id': 1,
      'job_order': <String, dynamic>{},
    });

    expect(assignment.materialType, '—');
    expect(assignment.loadVolume, '—');
  });
}
