String? proofOfDeliveryGuidance(String status) {
  return switch (status.trim().toLowerCase()) {
    'assigned' || 'dispatched' =>
      'Start the delivery first, then mark it as Arrived before uploading Proof of Delivery from Mark Complete.',
    'en_route' || 'in_progress' =>
      'Proof of Delivery is submitted when completing the delivery. Mark this delivery as Arrived first, then tap Mark Complete to upload the proof.',
    'arrived' =>
      'Tap Mark Complete on the job details page to upload Proof of Delivery.',
    'completed' =>
      'This delivery is already completed. Proof of Delivery should be uploaded from the Mark Complete flow.',
    _ => null,
  };
}
