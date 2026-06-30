import 'package:deliverex/models/delivery_tracking_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads last location from approximate location lat lng', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'en_route_to_destination',
      'approximate_location': {'lat': 14.6, 'lng': 120.98},
    });

    expect(result.lastLocation?.latitude, 14.6);
    expect(result.lastLocation?.longitude, 120.98);
    expect(result.lastLocation?.displayText, '14.600000, 120.980000');
    expect(result.lastLocation?.hasCoordinates, isTrue);
  });

  test('reads last location from approximate location latitude longitude', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'en_route_to_destination',
      'approximate_location': {
        'latitude': '14.604079',
        'longitude': '120.988591',
      },
    });

    expect(result.lastLocation?.latitude, 14.604079);
    expect(result.lastLocation?.longitude, 120.988591);
    expect(result.lastLocation?.displayText, '14.604079, 120.988591');
  });

  test('reads latest location from tracking logs', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'en_route_to_destination',
      'tracking_logs': [
        {
          'latitude': 14.5,
          'longitude': 120.5,
          'address': 'Old location',
          'captured_at': '2026-06-28T09:00:00.000000Z',
        },
        {
          'lat': '14.604079',
          'lng': '120.988591',
          'current_location': 'FEU Tech',
          'captured_at': '2026-06-28T10:00:00.000000Z',
        },
      ],
    });

    expect(result.lastLocation?.address, 'FEU Tech');
    expect(result.lastLocation?.latitude, 14.604079);
    expect(result.lastLocation?.longitude, 120.988591);
    expect(result.lastLocation?.displayText, 'FEU Tech');
  });

  test('reads latest location from status logs', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'arrived_at_pickup',
      'status_logs': [
        {
          'current_latitude': 14.6,
          'current_longitude': 120.98,
          'formatted_address': 'Pickup site',
          'created_at': '2026-06-28T10:00:00.000000Z',
        },
      ],
    });

    expect(result.lastLocation?.displayText, 'Pickup site');
    expect(result.lastLocation?.hasCoordinates, isTrue);
  });

  test('falls back to coordinates when latest location has no address', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'en_route_to_destination',
      'tracking_logs': [
        {
          'latitude': 14.6040792,
          'longitude': 120.9885911,
          'captured_at': '2026-06-28T10:00:00.000000Z',
        },
      ],
    });

    expect(result.lastLocation?.displayText, '14.604079, 120.988591');
  });

  test('uses dash fallbacks for blank route values', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'assigned',
    });

    expect(result.pickupAddress, '—');
    expect(result.dropoffAddress, '—');
    expect(result.vehicleLabel, '—');
  });

  test('reads proof document from completion proof with absolute file url', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'completed',
      'completion_proof': {
        'id': 77,
        'document_type': 'receipt',
        'created_at': '2026-06-30T01:13:00',
        'status': 'processing',
        'file_url': 'https://deliverexapp.com/storage/proofs/77.jpg',
      },
    });

    expect(result.hasProof, isTrue);
    expect(result.proofDocument?.id, '77');
    expect(result.proofDocument?.typeLabel, 'Delivery Receipt Photo');
    expect(result.proofDocument?.submittedAt, 'June 30, 2026 1:13AM');
    expect(result.proofDocument?.statusLabel, 'Processing');
    expect(
      result.proofDocument?.fileUrl,
      'https://deliverexapp.com/storage/proofs/77.jpg',
    );
  });

  test('reads proof document from proof documents with relative file url', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'completed',
      'proof_documents': [
        {
          'document_id': 12,
          'type': 'proof_of_delivery',
          'uploaded_at': '2026-06-30T01:13:00',
          'processing_status': 'ready_for_review',
          'file_path': 'storage/proofs/12.jpg',
        },
      ],
    });

    expect(result.proofDocument?.id, '12');
    expect(result.proofDocument?.typeLabel, 'Proof of Delivery');
    expect(result.proofDocument?.statusLabel, 'Ready For Review');
    expect(
      result.proofDocument?.fileUrl,
      'https://deliverexapp.com/storage/proofs/12.jpg',
    );
  });

  test('falls back to document file endpoint when proof has id only', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'completed',
      'documents': [
        {'id': 55, 'document_type': 'pod', 'created_at': '2026-06-30T01:13:00'},
      ],
    });

    expect(
      result.proofDocument?.fileUrl,
      'https://deliverexapp.com/api/documents/55/file',
    );
  });

  test('ignores completion proof without attached document metadata', () {
    final result = DeliveryTrackingResult.fromJson({
      'tracking_code': 'T123',
      'status': 'completed',
      'completion_proof': {'receiver_name': 'Receiver'},
    });

    expect(result.hasProof, isFalse);
    expect(result.proofDocument, isNull);
  });
}
