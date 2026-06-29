Map<String, dynamic> actionTimestampFields(String? actionTakenAt) {
  if (actionTakenAt == null || actionTakenAt.isEmpty) {
    return const {};
  }
  return {'action_timestamp': actionTakenAt, 'action_taken_at': actionTakenAt};
}
