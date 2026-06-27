import 'package:deliverex/core/document_type_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps legacy delivery receipt value to backend receipt value', () {
    expect(normalizeDocumentType('delivery_receipt'), 'receipt');
  });

  test('maps proof of delivery value to backend pod value', () {
    expect(normalizeDocumentType('proof_of_delivery'), 'pod');
  });

  test('keeps backend-supported document types unchanged', () {
    expect(normalizeDocumentType('invoice'), 'invoice');
    expect(normalizeDocumentType('job_order'), 'job_order');
    expect(normalizeDocumentType('other'), 'other');
  });
}
