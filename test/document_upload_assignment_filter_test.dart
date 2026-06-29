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

  test('identifies OCR Review document types', () {
    expect(isOcrReviewDocumentType('receipt'), isTrue);
    expect(isOcrReviewDocumentType('invoice'), isTrue);
    expect(isOcrReviewDocumentType('job_order'), isTrue);
    expect(isOcrReviewDocumentType('other'), isTrue);
    expect(isOcrReviewDocumentType('proof_of_delivery'), isFalse);
  });

  test('document upload type selector does not include proof of delivery', () {
    expect(documentUploadTypes.map((type) => type.$2), [
      'Delivery Receipt',
      'Invoice',
      'Job Order',
      'Other',
    ]);
    expect(
      documentUploadTypes.any((type) => type.$1 == 'proof_of_delivery'),
      isFalse,
    );
  });

  test('delivery receipt requires arrived or completed status', () {
    for (final status in [
      'assigned',
      'en_route_to_pickup',
      'arrived_at_pickup',
      'en_route_to_destination',
    ]) {
      expect(
        documentUploadPreflightMessage(type: 'receipt', status: status),
        contains('Document uploads are only available'),
        reason: '$status should be blocked for Delivery Receipt uploads.',
      );
    }

    expect(
      documentUploadPreflightMessage(type: 'receipt', status: 'arrived'),
      isNull,
    );
    expect(
      documentUploadPreflightMessage(type: 'receipt', status: 'completed'),
      isNull,
    );
  });

  test('invoice job order and other are not status-blocked', () {
    for (final status in [
      'assigned',
      'en_route_to_pickup',
      'arrived_at_pickup',
      'en_route_to_destination',
      'arrived',
      'completed',
    ]) {
      for (final type in ['invoice', 'job_order', 'other']) {
        expect(
          documentUploadPreflightMessage(type: type, status: status),
          isNull,
          reason: '$type should upload without status restriction at $status.',
        );
      }
    }
  });

  test('proof of delivery is status restricted when preflighted directly', () {
    expect(
      documentUploadPreflightMessage(
        type: 'proof_of_delivery',
        status: 'assigned',
      ),
      contains('Document uploads are only available'),
    );
  });

  test('upload response message reflects website review visibility', () {
    expect(
      documentUploadSuccessMessage({
        'document': {'id': 10},
        'ocr_result': {'id': 20},
      }),
      documentUploadSuccessReviewMessage,
    );
    expect(
      documentUploadSuccessMessage({
        'document': {'id': 10},
        'ocr_result': null,
      }),
      documentUploadSuccessReviewMessage,
    );

    expect(documentUploadSuccessReviewMessage, isNot(contains('OCR')));
    expect(documentUploadSuccessReviewMessage, isNot(contains('attachment')));
    expect(
      documentUploadSuccessReviewMessage,
      isNot(contains('not yet visible')),
    );
    expect(
      documentUploadSuccessReviewMessage,
      isNot(contains('administrator')),
    );
  });

  test('type help avoids OCR and attachment wording', () {
    final help = documentUploadTypeHelp('other', 'arrived');

    expect(
      help,
      'This document will be available for website review after upload.',
    );
    expect(help, isNot(contains('OCR')));
    expect(help, isNot(contains('attachment')));
  });

  test('invoice job order and other help avoids restriction wording', () {
    for (final type in ['invoice', 'job_order', 'other']) {
      final help = documentUploadTypeHelp(type, 'assigned');

      expect(
        help,
        'This document will be available for website review after upload.',
      );
      expect(help, isNot(contains('Arrived or Completed')));
    }
  });
}
