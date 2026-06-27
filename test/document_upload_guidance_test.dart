import 'package:deliverex/core/document_upload_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tells en route drivers to mark arrived before uploading proof', () {
    expect(
      proofOfDeliveryGuidance('en_route'),
      'Proof of Delivery is submitted when completing the delivery. Mark this delivery as Arrived first, then tap Mark Complete to upload the proof.',
    );
    expect(
      proofOfDeliveryGuidance('in_progress'),
      'Proof of Delivery is submitted when completing the delivery. Mark this delivery as Arrived first, then tap Mark Complete to upload the proof.',
    );
  });

  test('guides pending and arrived deliveries to the correct completion flow', () {
    expect(
      proofOfDeliveryGuidance('assigned'),
      'Start the delivery first, then mark it as Arrived before uploading Proof of Delivery from Mark Complete.',
    );
    expect(
      proofOfDeliveryGuidance('arrived'),
      'Tap Mark Complete on the job details page to upload Proof of Delivery.',
    );
  });
}
