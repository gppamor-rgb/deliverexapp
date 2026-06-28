import 'package:deliverex/core/document_upload_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'tells destination-bound drivers to mark arrived before uploading proof',
    () {
      expect(
        proofOfDeliveryGuidance('en_route_to_destination'),
        'Proof of Delivery is submitted when completing the delivery. Mark this delivery as Arrived first, then tap Complete Delivery to upload the proof.',
      );
      expect(
        proofOfDeliveryGuidance('in_progress'),
        'Proof of Delivery is submitted when completing the delivery. Mark this delivery as Arrived first, then tap Complete Delivery to upload the proof.',
      );
    },
  );

  test('guides pickup flow statuses to the correct completion flow', () {
    expect(
      proofOfDeliveryGuidance('assigned'),
      'Start pickup first before uploading Proof of Delivery from Complete Delivery.',
    );
    expect(
      proofOfDeliveryGuidance('en_route_to_pickup'),
      'Mark this delivery as Arrived at Pickup first, then start delivery before uploading Proof of Delivery.',
    );
    expect(
      proofOfDeliveryGuidance('arrived_at_pickup'),
      'Start delivery first, then mark it as Arrived before uploading Proof of Delivery from Complete Delivery.',
    );
  });

  test('guides arrived and completed deliveries to completion proof flow', () {
    expect(
      proofOfDeliveryGuidance('arrived'),
      'Tap Complete Delivery on the job details page to upload Proof of Delivery.',
    );
    expect(
      proofOfDeliveryGuidance('completed'),
      'This delivery is already completed. Proof of Delivery should be uploaded from the Complete Delivery flow.',
    );
  });
}
