String normalizeDocumentType(String type) {
  return switch (type.trim()) {
    'delivery_receipt' => 'receipt',
    'proof_of_delivery' => 'pod',
    final value => value,
  };
}
