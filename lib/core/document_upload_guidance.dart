import 'delivery_status.dart';

String? proofOfDeliveryGuidance(String status) {
  return switch (canonicalDeliveryStatus(status)) {
    deliveryStatusAssigned =>
      'Start pickup first before uploading Proof of Delivery from Complete Delivery.',
    deliveryStatusEnRouteToPickup =>
      'Mark this delivery as Arrived at Pickup first, then start delivery before uploading Proof of Delivery.',
    deliveryStatusArrivedAtPickup =>
      'Start delivery first, then mark it as Arrived before uploading Proof of Delivery from Complete Delivery.',
    deliveryStatusEnRouteToDestination =>
      'Proof of Delivery is submitted when completing the delivery. Mark this delivery as Arrived first, then tap Complete Delivery to upload the proof.',
    deliveryStatusArrived =>
      'Tap Complete Delivery on the job details page to upload Proof of Delivery.',
    deliveryStatusCompleted =>
      'This delivery is already completed. Proof of Delivery should be uploaded from the Complete Delivery flow.',
    _ => null,
  };
}
